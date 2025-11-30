const { Octokit } = require('@octokit/rest');
const { getCachedData } = require('./cache-helper');

exports.handler = async (event) => {
  const cacheKey = 'survey-scores-data';

  try {
    const surveyScoresData = await getCachedData(cacheKey, async () => {
      const github = new Octokit({ auth: process.env.GITHUB_TOKEN });
      
      // Lấy nội dung file survey-scores.json từ GitHub
      const response = await github.repos.getContent({
        owner: process.env.GITHUB_USER,
        repo: process.env.GITHUB_REPO,
        path: 'data/survey-scores.json',
        ref: process.env.GITHUB_BRANCH || 'main'
      });

      // Nếu file tồn tại, parse nội dung và trả về
      if (response.status === 200) {
        const content = Buffer.from(response.data.content, 'base64').toString('utf-8');
        try {
          const metadata = JSON.parse(content);
          return metadata;
        } catch (e) {
          return [];
        }
      }

      // Nếu file không tồn tại, trả về mảng rỗng
      return [];
      
    });

    return {
      statusCode: 200,
      headers: { 
        'Content-Type': 'application/json',
        "Cache-Control": "public, max-age=300, s-maxage=300"
      },
      body: JSON.stringify(surveyScoresData)
    };

  } catch (error) {
    // Xử lý trường hợp file không tồn tại (404)
    if (error.status === 404) {
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify([])
      };
    }

    // Các lỗi khác
    console.error('Error fetching survey scores:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ 
        message: 'Error fetching survey scores data', 
        error: error.message 
      })
    };
  }
};