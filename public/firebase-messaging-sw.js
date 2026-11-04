/* SpeakMaster FCM service worker.
 * Handles Web Push delivered by Firebase Cloud Messaging without loading the
 * Firebase SDK: the FCM payload arrives as JSON ({ notification, data }).
 */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (err) {
    payload = { notification: { body: event.data ? event.data.text() : '' } };
  }

  const notification = payload.notification || {};
  const data = payload.data || {};
  const title = notification.title || data.title || 'SpeakMaster';
  const options = {
    body: notification.body || data.body || 'Đã đến giờ luyện phát âm hôm nay!',
    icon: notification.icon || '/favicon.ico',
    tag: data.tag || 'daily-reminder',
    renotify: true,
    data: { link: data.link || (payload.fcmOptions && payload.fcmOptions.link) || '/' }
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const link = (event.notification.data && event.notification.data.link) || '/';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if ('focus' in client) return client.focus();
      }
      return self.clients.openWindow(link);
    })
  );
});
