const { Octokit } = require('@octokit/rest');

// Helper function to format date as Ngày/Tháng/Năm
function formatDateDMY(dateString) {
  const date = new Date(dateString);
  const day = String(date.getDate()).padStart(2, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const year = date.getFullYear();
  return `${day}/${month}/${year}`;
}

exports.handler = async (event) => {
    try {
        if (event.httpMethod !== 'POST') {
            return { statusCode: 405, body: JSON.stringify({ error: 'Method not allowed' }) };
        }

        const body = JSON.parse(event.body);
        const { year, semester, file, fileName, fileType } = body;

        if (!year || !semester || !file || !fileName) {
            return { statusCode: 400, body: JSON.stringify({ error: 'Missing required fields' }) };
        }

        const github = new Octokit({ auth: process.env.GITHUB_TOKEN });
        const branch = process.env.GITHUB_BRANCH || 'main';
        const timestamp = Date.now();
        const ext = fileName.split('.').pop() || 'pdf';
        const filePath = `data/scores/${timestamp}.${ext}`;

        // Extract base64 from data URL if needed
        let binaryData = file;
        if (file.startsWith('data:')) {
            const parts = file.split(',');
            if (parts.length === 2) {
                binaryData = parts[1];
            } else {
                throw new Error('Invalid file format');
            }
        }

        // Upload file to GitHub
        await github.repos.createOrUpdateFileContents({
            owner: process.env.GITHUB_USER,
            repo: process.env.GITHUB_REPO,
            path: filePath,
            message: `Upload scores: ${fileName} - ${year} - ${semester}`,
            content: binaryData,
            branch: branch,
        });

        // Determine score type
        const typeMap = {
            'mid1': 'Giữa HK1',
            'final1': 'Cuối HK1',
            'mid2': 'Giữa HK2',
            'final2': 'Cuối HK2',
            'survey': 'Điểm khảo sát'
        };

        // Get or create metadata file
        let metadataContent = '[]';
        try {
            const metadataFile = await github.repos.getContent({
                owner: process.env.GITHUB_USER,
                repo: process.env.GITHUB_REPO,
                path: 'data/scores.json',
                ref: branch,
            });
            metadataContent = Buffer.from(metadataFile.data.content, 'base64').toString('utf-8');
        } catch (err) {
            // File doesn't exist yet, use empty array
        }

        let scores = [];
        try {
            scores = JSON.parse(metadataContent);
        } catch (e) {
            scores = [];
        }

        // Add new score entry with formatted date
        const uploadDate = new Date();
        const scoreEntry = {
            id: timestamp.toString(),
            year: year,
            semester: semester,
            semesterText: typeMap[semester] || semester,
            fileName: fileName,
            url: `https://raw.githubusercontent.com/${process.env.GITHUB_USER}/${process.env.GITHUB_REPO}/${branch}/${filePath}`,
            uploadedAt: formatDateDMY(uploadDate.toISOString()),
        };

        scores.push(scoreEntry);

        // Update metadata file
        const metadataFileContent = JSON.stringify(scores, null, 2);
        const metadataFileExists = metadataContent !== '[]';

        if (metadataFileExists) {
            // Get SHA for update
            const metadataFileInfo = await github.repos.getContent({
                owner: process.env.GITHUB_USER,
                repo: process.env.GITHUB_REPO,
                path: 'data/scores.json',
                ref: branch,
            });
            await github.repos.createOrUpdateFileContents({
                owner: process.env.GITHUB_USER,
                repo: process.env.GITHUB_REPO,
                path: 'data/scores.json',
                message: 'Update scores metadata',
                content: Buffer.from(metadataFileContent).toString('base64'),
                branch: branch,
                sha: metadataFileInfo.data.sha,
            });
        } else {
            await github.repos.createOrUpdateFileContents({
                owner: process.env.GITHUB_USER,
                repo: process.env.GITHUB_REPO,
                path: 'data/scores.json',
                message: 'Create scores metadata',
                content: Buffer.from(metadataFileContent).toString('base64'),
                branch: branch,
            });
        }

        // Cache clearing is not needed for Netlify Functions

        return {
            statusCode: 200,
            body: JSON.stringify({ success: true, entry: scoreEntry }),
            headers: { 'Content-Type': 'application/json' },
        };
    } catch (err) {
        console.error('Error uploading score:', err);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Lỗi upload bảng điểm: ' + err.message }),
        };
    }
};