const { getCachedData } = require('./cache-helper');

exports.handler = async function(event) {
  try {
    const cacheKey = 'memories-data';
    
    const memoriesData = await getCachedData(cacheKey, async () => {
      const user = process.env.GITHUB_USER;
      const repo = process.env.GITHUB_REPO;
      const branch = process.env.GITHUB_BRANCH || "main";
      
      if (!user || !repo) {
        throw new Error('Missing required environment variables');
      }

      const url = `https://api.github.com/repos/${user}/${repo}/contents/data/memories.json?ref=${branch}`;
      const res = await fetch(url, {
        headers: { Authorization: `token ${process.env.GITHUB_TOKEN}` }
      });

      if (!res.ok) {
        const errorData = await res.json();
        throw new Error(errorData.message || "Failed to fetch memories.json");
      }

      const data = await res.json();
      try {
        return JSON.parse(Buffer.from(data.content, 'base64').toString('utf8'));
      } catch (e) {
        return [];
      }
    });

    return {
      statusCode: 200,
      headers: { 
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "public, max-age=300, s-maxage=300" // 5 phút
      },
      body: JSON.stringify({ 
        data: memoriesData, 
        total: memoriesData.length,
        cached: true
      })
    };
  } catch (err) {
    console.error('Fetch error:', err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: err.message || "Server error" })
    };
  }
}