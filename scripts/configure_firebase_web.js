const fs = require('node:fs');
const path = require('node:path');

function prepareFirebaseWeb(input, backendUrl, vapidKey = input.vapidKey) {
  if (input.projectId !== 'mtaxi-52990') throw new Error('Firebase projectId must be mtaxi-52990');
  for (const key of ['apiKey', 'appId', 'messagingSenderId']) {
    if (typeof input[key] !== 'string' || !input[key].trim()) throw new Error(`Firebase web config missing: ${key}`);
  }
  if (!/^1:\d+:web:[a-z0-9]+$/i.test(input.appId) || input.appId.split(':')[1] !== input.messagingSenderId) {
    throw new Error('Use the Firebase WEB appId and matching messagingSenderId');
  }
  if (vapidKey && !/^[A-Za-z0-9_-]{80,}$/.test(vapidKey)) throw new Error('Firebase web public VAPID key is invalid');
  const url = new URL(backendUrl);
  if (!['http:', 'https:'].includes(url.protocol)) throw new Error('HTTP(S) backend URL required');
  const options = Object.fromEntries(['apiKey', 'appId', 'projectId', 'messagingSenderId'].map(key => [key, input[key]]));
  return {
    workerSource: `self.MTAXI_FIREBASE_CONFIG = ${JSON.stringify(options)};\n`,
    defines: { FIREBASE_PROJECT_ID: input.projectId, FIREBASE_WEB_API_KEY: input.apiKey,
      FIREBASE_WEB_APP_ID: input.appId, FIREBASE_MESSAGING_SENDER_ID: input.messagingSenderId,
      FIREBASE_WEB_VAPID_KEY: vapidKey || '', FIREBASE_WEB_PUSH_ENABLED: true, MTAXI_BACKEND_URL: backendUrl },
  };
}

if (require.main === module) {
  try {
    const [configPath, backendUrl, definesPath, workerPath] = process.argv.slice(2);
    if (!configPath || !backendUrl || !definesPath || !workerPath) {
      throw new Error('Usage: node configure_firebase_web.js config.json backend-url defines.json worker-config.js');
    }
    const input = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    const result = prepareFirebaseWeb(input, backendUrl, process.env.FIREBASE_WEB_VAPID_KEY || input.vapidKey);
    fs.mkdirSync(path.dirname(workerPath), { recursive: true });
    fs.writeFileSync(workerPath, result.workerSource, { mode: 0o600 });
    fs.writeFileSync(definesPath, JSON.stringify(result.defines), { mode: 0o600 });
    console.log('Firebase web config prepared for mtaxi-52990');
  } catch (error) { console.error(error.message); process.exit(1); }
}

module.exports = { prepareFirebaseWeb };
