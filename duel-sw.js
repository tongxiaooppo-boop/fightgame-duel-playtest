self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));

// Always use the latest deployed build. The installed game still needs a connection.
self.addEventListener('fetch', event => {
  if (event.request.mode !== 'navigate') return;
  event.respondWith(fetch(event.request).catch(() => new Response('請連上網路後重新開啟選戰風雲S。', {
    status: 503,
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  })));
});
