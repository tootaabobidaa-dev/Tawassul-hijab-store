/* توسل - Service Worker احتياطي/متوافق مع لوحة الإدارة */
const CACHE = 'tawassul-admin-pwa-v2';
const SHELL = ['/admin.html','/admin-manifest.json','/icon-192.png','/icon-512.png','/offline.html'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL).catch(()=>{})).then(()=>self.skipWaiting()));
});
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const u = new URL(e.request.url);
  if (u.origin !== self.location.origin) return;
  e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
});
self.addEventListener('push', event => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (_) {}
  event.waitUntil(self.registration.showNotification(data.title || '🔔 طلب جديد - توسل', {
    body: data.body || 'وصل طلب جديد إلى المتجر',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    tag: data.tag || 'new-order',
    renotify: true,
    requireInteraction: true,
    vibrate: [250,100,250,100,400],
    dir: 'rtl',
    lang: 'ar',
    data: {url:'/admin'}
  }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil(self.clients.openWindow(new URL('/admin', self.registration.scope).href));
});
