const { getCachedData } = require('./cache-helper');

exports.handler = async function(event) {
  const cacheKey = 'tkb-data';

  try {
    const tkbData = await getCachedData(cacheKey, async () => {
      const user = process.env.GITHUB_USER;
      const repo = process.env.GITHUB_REPO;
      const branch = process.env.GITHUB_BRANCH || "main";
      const token = process.env.GITHUB_TOKEN;

      const jsonPath = "data/tkb.json";
      const url = `https://api.github.com/repos/${user}/${repo}/contents/${jsonPath}?ref=${branch}`;
      
      const res = await fetch(url, {
        headers: { Authorization: `token ${token}` }
      });

      if (res.status === 404) {
        return []; // Trả về mảng rỗng nếu file chưa tồn tại
      }

      if (!res.ok) {
        throw new Error("Failed to fetch TKB files");
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
        "Cache-Control": "public, max-age=300, s-maxage=300"
      },
      body: JSON.stringify(tkbData)
    };
  } catch (err) {
    console.error('Error:', err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: err.message || "Server error" })
    };
  }
};