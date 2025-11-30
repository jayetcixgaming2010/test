// functions/cache-helper.js

// Thời gian cache: 5 phút
const CACHE_DURATION = 5 * 60 * 1000;

async function getCachedData(cacheKey, fetchFunction) {
  try {
    // Thử lấy dữ liệu từ cache
    const cachedResponse = await caches.match(cacheKey);
    if (cachedResponse) {
      const cachedData = await cachedResponse.json();
      const cacheTime = cachedResponse.headers.get('cache-time');
      
      // Kiểm tra xem cache có còn hợp lệ không
      if (cacheTime && (Date.now() - parseInt(cacheTime) < CACHE_DURATION)) {
        return cachedData;
      }
    }
  } catch (error) {
    console.log('Lỗi khi đọc cache:', error);
  }

  // Nếu không có cache hợp lệ hoặc cache đã hết hạn, lấy dữ liệu mới
  const freshData = await fetchFunction();

  try {
    // Lưu dữ liệu mới vào cache
    const cache = await caches.open('function-cache');
    const response = new Response(JSON.stringify(freshData), {
      headers: {
        'Content-Type': 'application/json',
        'cache-time': Date.now().toString()
      }
    });
    await cache.put(cacheKey, response.clone());
  } catch (error) {
    console.log('Lỗi khi ghi cache:', error);
  }

  return freshData;
}

module.exports = { getCachedData };