// Validates FCM credentials without delivering a notification to any device.
const { initializeApp, cert, applicationDefault } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

async function main() {
  const projectId = process.env.FIREBASE_PROJECT_ID || 'mtaxi-52990';
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  const account = raw ? JSON.parse(raw) : null;
  if (projectId !== 'mtaxi-52990' || (account && account.project_id !== projectId)) {
    throw new Error('Firebase project mismatch');
  }
  const app = initializeApp({ projectId, credential: account ? cert(account) : applicationDefault() });
  await getMessaging(app).send({
    topic: 'mtaxi-setup-validation-only',
    notification: { title: 'Setup validation', body: 'Dry run only' },
  }, true);
  console.log('FCM dry run passed for mtaxi-52990; no notification delivered');
}

main().catch(error => {
  console.error(`FCM dry run failed: ${error.code || 'configuration-or-credentials-error'}`);
  process.exitCode = 1;
});
