/* توسل PWA Service Worker - Store + Admin */
const CACHE = 'tawassul-pwa-v2';
const APP_SHELL = [
  '/',
  '/index.html',
  '/admin.html',
  '/store-manifest.json',
  '/admin-manifest.json',
  '/icon-192.png',
  '/icon-512.png',
  '/offline.html'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll(APP_SHELL))
      .catch(() => {})
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

function targetUrl(dataUrl) {
  try {
    const raw = dataUrl || '/';
    if (raw === 'admin.html' || raw === '/admin.html') return '/admin';
    return raw;
  } catch (_) {
    return '/';
  }
}

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req)
        .then(res => {
          const copy = res.clone();
          caches.open(CACHE).then(cache => cache.put(req, copy));
          return res;
        })
        .catch(() =>
          caches.match(req).then(cached => cached || caches.match('/index.html'))
        )
    );
    return;
  }

  event.respondWith(
    fetch(req)
      .then(res => {
        if (res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then(cache => cache.put(req, copy));
        }
        return res;
      })
      .catch(() => caches.match(req))
  );
});

self.addEventListener('push', event => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }

  const title = data.title || '🔔 توسل';
  const options = {
    body: data.body || '',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    tag: data.tag || 'tawassul',
    renotify: true,
    requireInteraction: true,
    vibrate: [250, 100, 250, 100, 400],
    dir: 'rtl',
    lang: 'ar',
    timestamp: Date.now(),
    data: { url: targetUrl(data.url) }
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const target = new URL(
    targetUrl(event.notification.data && event.notification.data.url),
    self.registration.scope
  ).href;

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      for (const client of list) {
        if (client.url.split('#')[0] === target.split('#')[0] && 'focus' in client) {
          return client.focus();
        }
      }
      return self.clients.openWindow(target);
    })
  );
});
