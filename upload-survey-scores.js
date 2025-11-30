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
            return {
                statusCode: 400,
                body: JSON.stringify({ error: 'Missing required fields' })
            };
        }

        const user = process.env.GITHUB_USER;
        const repo = process.env.GITHUB_REPO;
        const branch = process.env.GITHUB_BRANCH || "main";
        const token = process.env.GITHUB_TOKEN;

        if (!user || !repo || !token) {
            throw new Error('Missing environment variables');
        }

        // Extract base64 from data URL if needed
        let base64Content = file;
        if (file.startsWith('data:')) {
            const parts = file.split(',');
            if (parts.length === 2) {
                base64Content = parts[1];
            } else {
                throw new Error('Invalid file format');
            }
        }

        // Create file path with timestamp
        const timestamp = Date.now();
        const ext = fileName.split('.').pop();
        const filePath = `data/survey-scores/${timestamp}.${ext}`;

        // Upload to GitHub
        const uploadUrl = `https://api.github.com/repos/${user}/${repo}/contents/${filePath}`;
        
        const uploadRes = await fetch(uploadUrl, {
            method: 'PUT',
            headers: {
                Authorization: `token ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: `Upload Survey Score - ${year} - ${semester}`,
                content: base64Content
            })
        });

        if (!uploadRes.ok) {
            throw new Error('Failed to upload file to GitHub');
        }

        // Now update survey-scores.json metadata file
        const surveyScoresJsonPath = "data/survey-scores.json";
        const surveyScoresUrl = `https://api.github.com/repos/${user}/${repo}/contents/${surveyScoresJsonPath}?ref=${branch}`;

        // Get current survey-scores.json
        let surveyScoresData = [];
        let fileSha = null;

        try {
            const getRes = await fetch(surveyScoresUrl, {
                headers: { Authorization: `token ${token}` }
            });

            if (getRes.ok) {
                const fileData = await getRes.json();
                fileSha = fileData.sha;
                surveyScoresData = JSON.parse(Buffer.from(fileData.content, 'base64').toString('utf8'));
            }
        } catch (e) {
            // File doesn't exist yet
            surveyScoresData = [];
        }

        // Determine file type
        let fileTypeCategory = 'file';
        if (fileType.includes('word') || fileType.includes('document')) {
            fileTypeCategory = 'docx';
        } else if (fileType.includes('pdf')) {
            fileTypeCategory = 'pdf';
        } else if (fileType.includes('image')) {
            fileTypeCategory = 'image';
        } else if (fileType.includes('sheet') || fileType.includes('excel')) {
            fileTypeCategory = 'xlsx';
        }

        // Add new survey score entry with formatted date
        const uploadDate = new Date();
        const newEntry = {
            id: `survey_${timestamp}`,
            year: year,
            semester: semester,
            fileName: fileName,
            type: fileTypeCategory,
            url: `https://raw.githubusercontent.com/${user}/${repo}/${branch}/${filePath}`,
            uploadedAt: formatDateDMY(uploadDate.toISOString())
        };

        surveyScoresData.push(newEntry);

        // Update survey-scores.json
        const updateRes = await fetch(surveyScoresUrl, {
            method: 'PUT',
            headers: {
                Authorization: `token ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: `Update survey scores metadata - ${year} - ${semester}`,
                content: Buffer.from(JSON.stringify(surveyScoresData, null, 2)).toString('base64'),
                ...(fileSha && { sha: fileSha })
            })
        });

        if (!updateRes.ok) {
            throw new Error('Failed to update survey scores metadata');
        }

        // Cache clearing is not needed for Netlify Functions

        return {
            statusCode: 200,
            headers: { "Content-Type": "application/json; charset=utf-8" },
            body: JSON.stringify({ success: true, entry: newEntry })
        };

    } catch (err) {
        console.error('Upload error:', err);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: err.message || 'Upload failed' })
        };
    }
};