// Registers the three FCM clients idempotently and downloads their public config.
// Authentication stays in the injected environment; no private keys are written.
const fs = require('node:fs');
const path = require('node:path');
const { cert, applicationDefault } = require('firebase-admin/app');

async function main() {
  const projectId = process.env.FIREBASE_PROJECT_ID || 'mtaxi-52990';
  if (projectId !== 'mtaxi-52990') throw new Error('Expected Firebase project mtaxi-52990');
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  const account = raw ? JSON.parse(raw) : null;
  if (account && account.project_id !== projectId) throw new Error('Firebase credential project mismatch');
  const credential = account ? cert(account) : applicationDefault();
  const root = path.resolve(__dirname, '../..');
  async function request(resource, method = 'GET', body) {
    const token = await credential.getAccessToken();
    const response = await fetch(`https://firebase.googleapis.com/v1beta1/${resource}`, {
      method,
      headers: { Authorization: `Bearer ${token.access_token}`, 'Content-Type': 'application/json' },
      ...(body ? { body: JSON.stringify(body) } : {}),
      signal: AbortSignal.timeout(30000),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(`Firebase ${method} ${resource}: HTTP ${response.status} (${result.error?.status || 'failed'})`);
    return result;
  }
  for (const [kind, body, file] of [
    ['androidApps', { displayName: 'M Taxi Android', packageName: 'com.milanium.mtaxi' }, 'android/app/google-services.json'],
    ['iosApps', { displayName: 'M Taxi iOS', bundleId: 'com.milanium.mtaxi' }, 'ios/Runner/GoogleService-Info.plist'],
    ['webApps', { displayName: 'M Taxi Web Admin' }, '.firebase-web-config.local.json'],
  ]) {
    const parent = `projects/${projectId}/${kind}`;
    const apps = [];
    let pageToken;
    do {
      const page = await request(parent + (pageToken ? `?pageToken=${encodeURIComponent(pageToken)}` : ''));
      apps.push(...(page.apps || []));
      pageToken = page.nextPageToken;
    } while (pageToken);
    let app = apps.find(item => body.packageName ? item.packageName === body.packageName :
      body.bundleId ? item.bundleId === body.bundleId : item.displayName === body.displayName);
    if (!app) {
      let operation = await request(parent, 'POST', body);
      for (let attempt = 0; !operation.done && attempt < 60; attempt++) {
        await new Promise(resolve => setTimeout(resolve, 1000));
        operation = await request(operation.name);
      }
      if (!operation.done || operation.error) throw new Error(`Firebase registration failed for ${kind}`);
      app = operation.response;
    }
    const config = await request(`${app.name}/config`);
    const destination = path.join(root, file);
    // Preserve an existing VAPID key when refreshing the public web app config.
    if (kind === 'webApps' && fs.existsSync(destination)) {
      const existing = JSON.parse(fs.readFileSync(destination, 'utf8'));
      if (existing.projectId !== projectId || existing.appId !== config.appId) throw new Error('Existing web config does not match Firebase app');
      if (existing.vapidKey) config.vapidKey = existing.vapidKey;
    }
    let contents;
    if (kind === 'webApps') {
      contents = `${JSON.stringify(config, null, 2)}\n`;
    } else if (kind === 'androidApps') {
      const native = JSON.parse(Buffer.from(config.configFileContents, 'base64').toString('utf8'));
      delete native.project_info.storage_bucket;
      delete native.project_info.firebase_url;
      contents = `${JSON.stringify(native, null, 2)}\n`;
    } else {
      // Keep this repository's Firebase Core/Messaging-only configuration.
      contents = Buffer.from(config.configFileContents, 'base64').toString('utf8')
        .replace(/\s*<key>(?:STORAGE_BUCKET|DATABASE_URL)<\/key>\s*<string>[^<]*<\/string>/g, '')
        .replace(/(<key>IS_(?:SIGNIN|APPINVITE)_ENABLED<\/key>\s*)<true\s*(?:\/>|>\s*<\/true>)/g, '$1<false/>');
    }
    fs.writeFileSync(destination, contents, { mode: 0o600 });
    console.log(`${kind}: ${app.appId}; saved ${file}`);
  }
}

main().catch(error => {
  // Do not log SDK errors, which may carry request headers or credential JSON.
  console.error(error.message?.startsWith('Firebase ') || error.message?.startsWith('Expected ') ||
    error.message?.startsWith('Existing ') ? error.message : 'Firebase configuration failed; check credential and network access');
  process.exitCode = 1;
});
