self.addEventListener('install', e => {
  e.waitUntil(
    caches.open('cache-v1').then(cache => cache.addAll([
      '/', '/style.css', '/main.js', // Thêm assets cần cache
    ])),
  );
});
self.addEventListener('fetch', e => {
  e.respondWith(caches.match(e.request).then(response => response || fetch(e.request)));
});
