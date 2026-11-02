/* Firebase SDK version matches firebase_core_web 2.23.0. */
'use strict';

self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.stopImmediatePropagation();
  const message = event.notification.data?.FCM_MSG;
  const data=message?.data||{};
  const route = data.targetRole === 'driver' ? '/homeDriver' : data.type === 'KASPI_TOPUP_REQUEST' ? '/admin/collection?collection=payments' : data.targetRole === 'passenger' ? '/homePage' : '/admin';
  const url = new URL(route, self.location.origin).href;
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true })
    .then(async windows => {
      const window = windows.find(item => new URL(item.url).origin === self.location.origin);
      if (window) { await window.navigate(url); return window.focus(); }
      return self.clients.openWindow(url);
    }));
});

importScripts('https://www.gstatic.com/firebasejs/11.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.7.0/firebase-messaging-compat.js');
// Generated from the public Firebase web app config, not from a private key.
importScripts('./firebase-config.js');
if (self.MTAXI_FIREBASE_CONFIG?.projectId !== 'mtaxi-52990') {
  throw new Error('Firebase service worker requires project mtaxi-52990');
}
firebase.initializeApp(self.MTAXI_FIREBASE_CONFIG);
// Firebase displays notification payloads in the background automatically.
firebase.messaging();
