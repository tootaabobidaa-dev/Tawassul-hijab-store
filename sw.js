/* Service Worker موحّد - متجر توسل ولوحة التحكم */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

// مطلوب ليُعتبر الموقع قابلاً للتثبيت كتطبيق (لا يغيّر سلوك الشبكة)
self.addEventListener('fetch', () => {});

function normUrl(u){
  if (!u || u === 'admin.html' || u === '/admin.html') return '/admin';
  return u;
}

self.addEventListener('push', event => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (e) { data = { body: event.data ? event.data.text() : '' }; }
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
    data: { url: normUrl(data.url) }
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const target = new URL(normUrl(event.notification.data && event.notification.data.url), self.registration.scope).href;
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      for (const c of list) {
        if (c.url.split('#')[0] === target.split('#')[0] && 'focus' in c) return c.focus();
      }
      return self.clients.openWindow(target);
    })
  );
});
