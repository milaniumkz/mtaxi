const test = require('node:test');
const assert = require('node:assert/strict');
const { sendPushBatch } = require('../src/push_transport');
const { runPreflight } = require('../scripts/preflight');
const { prepareFirebaseWeb } = require('../../scripts/configure_firebase_web');
const { flushQueuedPushDeliveriesForStore } = require('../src/push');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

test('FCM refuses credentials from another Firebase project before sending', async () => {
  const names = ['MTAXI_FCM_ENABLED', 'FIREBASE_PROJECT_ID', 'FIREBASE_SERVICE_ACCOUNT_JSON'];
  const previous = Object.fromEntries(names.map(name => [name, process.env[name]]));
  try {
    process.env.MTAXI_FCM_ENABLED = 'true';
    process.env.FIREBASE_PROJECT_ID = 'mtaxi-52990';
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON = JSON.stringify({ project_id: 'different-project' });
    await assert.rejects(sendPushBatch({ tokens: ['synthetic-test-token'], notification: { title: 'Test' } }),
      /FCM_SERVICE_ACCOUNT_PROJECT_MISMATCH/);
  } finally {
    for (const name of names) {
      if (previous[name] === undefined) delete process.env[name];
      else process.env[name] = previous[name];
    }
  }
});

test('web worker and Flutter configuration use the same Firebase project and sender', () => {
  const config = { projectId: 'mtaxi-52990', appId: '1:123456:web:abcdef',
    messagingSenderId: '123456', apiKey: 'public-config-test-fixture', vapidKey: 'A'.repeat(87) };
  const result = prepareFirebaseWeb(config, 'https://api.example.test');
  assert.equal(result.defines.FIREBASE_PROJECT_ID, 'mtaxi-52990');
  assert.equal(result.defines.FIREBASE_WEB_PUSH_ENABLED, true);
  assert.ok(result.workerSource.includes('"projectId":"mtaxi-52990"'));
  assert.throws(() => prepareFirebaseWeb({ ...config, projectId: 'old-project' }, 'https://api.example.test'), /projectId/);
  assert.throws(() => prepareFirebaseWeb({ ...config, messagingSenderId: '999' }, 'https://api.example.test'), /matching/);
  assert.equal(prepareFirebaseWeb({...config,vapidKey:''},'https://api.example.test').defines.FIREBASE_WEB_PUSH_ENABLED,true);
  assert.throws(() => prepareFirebaseWeb({...config,vapidKey:'invalid'},'https://api.example.test'), /VAPID/);
});

test('queued admin push cannot be delivered after its browser token moves to another account', async () => {
  const store = {
    users: [{ id: 'admin', role: 'admin' }, { id: 'driver', isDriver: true }],
    notifications: [{ id: 'notification', targetRole: 'admin', targetUserIds: ['admin'] }],
    fcmTokens: [{ id: 'browser-token', userId: 'driver', deviceType: 'Web', fcmToken: 'synthetic-token' }],
    notificationDeliveries: [{ id: 'delivery', notificationId: 'notification', tokenId: 'browser-token', userId: 'admin', status: 'queued' }],
  };
  const result = await flushQueuedPushDeliveriesForStore(store, 100, async () => {});
  assert.equal(result.numSent, 0);
  assert.equal(result.numFailed, 1);
  assert.equal(store.notificationDeliveries[0].status, 'failed');
});

test('preflight identifies a Firebase project mismatch', async () => {
  const result = await runPreflight({ checkDatabase: false, env: {
    MTAXI_FCM_ENABLED: 'true', FIREBASE_PROJECT_ID: 'mtaxi-52990',
    FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({ project_id: 'different-project',
      client_email: 'test@different-project.iam.gserviceaccount.com',
      private_key: '-----BEGIN PRIVATE KEY-----\nunit-test-fixture\n-----END PRIVATE KEY-----' }),
    MTAXI_UPLOAD_DIR: '/tmp/mtaxi-fcm-preflight-test',
  } });
  assert.ok(result.checks.some(check => check.name === 'FIREBASE_PROJECT_ID' && !check.ok));
});

test('web notification click opens the same-origin Kaspi admin page', async () => {
  const listeners = {};
  let initialized = false;
  let opened;
  let pending;
  const context = {
    URL,
    self: {
      location: { origin: 'https://admin.example.test' },
      MTAXI_FIREBASE_CONFIG: { projectId: 'mtaxi-52990' },
      addEventListener(name, handler) { listeners[name] = handler; },
      clients: { matchAll: async () => [], openWindow: async url => { opened = url; } },
    },
    importScripts() {},
    firebase: { initializeApp() { initialized = true; }, messaging() {} },
  };
  const source = fs.readFileSync(path.join(__dirname, '../../web/firebase-messaging-sw.js'), 'utf8');
  vm.runInNewContext(source, context);
  assert.equal(initialized, true);
  listeners.notificationclick({
    notification: { close() {}, data: { FCM_MSG: { data: { type: 'KASPI_TOPUP_REQUEST', url: 'https://untrusted.example' } } } },
    stopImmediatePropagation() {}, waitUntil(promise) { pending = promise; },
  });
  await pending;
  assert.equal(opened, 'https://admin.example.test/admin/collection?collection=payments');
  context.self.MTAXI_FIREBASE_CONFIG.projectId = 'wrong-project';
  assert.throws(() => vm.runInNewContext(source, context), /requires project/);
});
