const { Octokit } = require('@octokit/rest');
const { getCachedData } = require('./cache-helper');

exports.handler = async (event) => {
  const cacheKey = 'scores-data';

  try {
    const scoresData = await getCachedData(cacheKey, async () => {
      const github = new Octokit({ auth: process.env.GITHUB_TOKEN });
      const file = await github.repos.getContent({
        owner: process.env.GITHUB_USER,
        repo: process.env.GITHUB_REPO,
        path: 'data/scores.json',
        ref: process.env.GITHUB_BRANCH || 'main'
      });

      const content = Buffer.from(file.data.content, 'base64').toString('utf-8');
      try {
        return JSON.parse(content);
      } catch (e) {
        return [];
      }
    });

    return {
      statusCode: 200,
      headers: { 
        'Content-Type': 'application/json',
        "Cache-Control": "public, max-age=300, s-maxage=300"
      },
      body: JSON.stringify(scoresData)
    };
  } catch (err) {
    // Nếu file không tồn tại, trả về mảng rỗng
    if (err.status === 404) {
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify([])
      };
    }
    
    console.error('Error loading scores:', err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Không thể tải bảng điểm' })
    };
  }
};