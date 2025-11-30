// Helper function to format date as Ngày/Tháng/Năm
function formatDateDMY(dateString) {
  const date = new Date(dateString);
  const day = String(date.getDate()).padStart(2, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const year = date.getFullYear();
  return `${day}/${month}/${year}`;
}

exports.handler = async function(event, context) {
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: JSON.stringify({ error: "Method Not Allowed" })
    };
  }

  try {
    const { title, date, filename, contentBase64, password } = JSON.parse(event.body);
    
    // Get environment variables
    const CLASS_PASSWORD = process.env.CLASS_PASSWORD;
    const user = process.env.GITHUB_USER;
    const repo = process.env.GITHUB_REPO;
    const branch = process.env.GITHUB_BRANCH || "main";
    const token = process.env.GITHUB_TOKEN;

    // Validate required environment variables
    if (!CLASS_PASSWORD || !user || !repo || !token) {
      return { statusCode: 500, body: JSON.stringify({ error: 'Server misconfigured' }) };
    }

    // Validate password first
    if (password !== CLASS_PASSWORD) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Sai mật khẩu lớp!' }) };
    }

    // Validate input data
    if (!title || !date || !filename || !contentBase64) {
      throw new Error('Missing required fields: title, date, filename, contentBase64');
    }

    // Rough size check (base64 ~1.33x binary)
    const approxSize = Buffer.from(contentBase64, 'base64').length;
    if (approxSize > 5 * 1024 * 1024) {
      throw new Error('File too large: Max 5MB');
    }

    const timestamp = Date.now();
    const path = `img/memories/${timestamp}_${filename}`;

    // Upload image
    const imageUrl = `https://api.github.com/repos/${user}/${repo}/contents/${path}`;
    const imageRes = await fetch(imageUrl, {
      method: "PUT",
      headers: {
        Authorization: `token ${token}`,
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify({
        message: `Upload ảnh: ${title}`,
        content: contentBase64,
        branch,
      }),
    });

    const imageData = await imageRes.json();
    if (!imageRes.ok) {
      throw new Error(imageData.message || "Upload image failed");
    }

    const rawUrl = `https://raw.githubusercontent.com/${user}/${repo}/${branch}/${path}`;

    // Get current memories.json
    const jsonPath = "data/memories.json";
    const jsonUrl = `https://api.github.com/repos/${user}/${repo}/contents/${jsonPath}?ref=${branch}`;
    const jsonRes = await fetch(jsonUrl, {
      headers: { Authorization: `token ${token}` }
    });

    let memories = [];
    let jsonSha = null;
    if (jsonRes.ok) {
      const jsonData = await jsonRes.json();
      memories = JSON.parse(Buffer.from(jsonData.content, 'base64').toString('utf8'));
      jsonSha = jsonData.sha;
    }

    // Add new entry (unshift for newest first)
    // Format date as Ngày/Tháng/Năm
    const formattedDate = formatDateDMY(date);
    memories.unshift({ title, date: formattedDate, url: rawUrl, path });

    // Put updated json with explicit UTF-8
    const newContent = Buffer.from(JSON.stringify(memories, null, 2), 'utf8').toString('base64');
    const putJsonRes = await fetch(jsonUrl, {
      method: "PUT",
      headers: {
        Authorization: `token ${token}`,
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify({
        message: `Add memory: ${title}`,
        content: newContent,
        ...(jsonSha && { sha: jsonSha }),
        branch,
      }),
    });

    const putJsonData = await putJsonRes.json();
    if (!putJsonRes.ok) {
      throw new Error(putJsonData.message || "Update memories.json failed");
    }

    // Clear cache after successful upload
    // Note: Netlify Functions don't have access to browser caches

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: JSON.stringify({ url: rawUrl, title, date: formattedDate, path }),
    };
  } catch (err) {
    console.error('Upload error:', err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: err.message || "Unexpected server error" })
    };
  }
};