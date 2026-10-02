// Service worker لوحة تحكم توسل — يدعم التثبيت + إشعارات Push
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', () => {}); // مطلوب لبعض المتصفحات لعرض خيار التثبيت

self.addEventListener('push', event => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (e) { data = { body: event.data && event.data.text() }; }
  event.waitUntil(self.registration.showNotification(data.title || '🔔 طلب جديد - توسل', {
    body: data.body || '',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    vibrate: [250, 100, 250],
    tag: data.tag || 'order',
    renotify: true,
    data: { url: data.url || '/admin' }
  }));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/admin';
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
    for (const c of list) { if (c.url.includes('/admin') && 'focus' in c) return c.focus(); }
    return clients.openWindow(url);
  }));
});
