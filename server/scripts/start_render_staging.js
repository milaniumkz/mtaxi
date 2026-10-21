const { spawn } = require('node:child_process');

function configureRenderStaging(env) {
  const url = new URL(env.RENDER_EXTERNAL_URL || '');
  if (url.protocol !== 'https:' || !url.hostname.endsWith('.onrender.com')) {
    throw new Error('A real HTTPS Render service URL is required');
  }
  env.MTAXI_PUBLIC_BASE_URL = url.origin;
  // Explicit web origin is set after Render allocates the static site's hostname.
  env.MTAXI_CORS_ORIGINS ||= url.origin;
}

async function bootstrap() {
  configureRenderStaging(process.env);
  const { applySchema } = require('./apply_schema');
  const { runPreflight } = require('./preflight');
  const { readStoreAsync } = require('../src/store');
  const { normalizePhone } = require('../src/utils/values');
  const { seedAdmin } = require('./seed_admin');
  await applySchema();
  const checks = await runPreflight();
  if (!checks.ok) {
    throw new Error(`Staging preflight failed: ${checks.checks.filter(c => !c.ok).map(c => c.name).join(', ')}`);
  }
  if (process.env.MTAXI_SEED_ADMIN_ON_START === 'true') {
    const store = await readStoreAsync();
    const phone = normalizePhone(process.env.MTAXI_ADMIN_PHONE);
    const existing = store.users.find(user => normalizePhone(user.phone) === phone);
    if (existing && existing.role !== 'admin') throw new Error('Staging admin phone already belongs to another account');
    if (!existing) {
      const seeded = await seedAdmin();
      if (!seeded.success) throw new Error('Staging administrator creation failed');
    }
  }
  const child = spawn(process.execPath, ['src/index.js'], { cwd: require('node:path').resolve(__dirname, '..'), env: process.env, stdio: 'inherit' });
  for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => child.kill(signal));
  child.on('exit', code => process.exit(code ?? 1));
  child.on('error', () => { console.error('Staging backend failed to start'); process.exit(1); });
}

if (require.main === module) bootstrap().catch(() => {
  // SDK/DB errors can include connection details. Do not log raw error objects.
  console.error('Render staging startup failed; verify database, public URL and secret configuration');
  process.exit(1);
});
module.exports = { configureRenderStaging };
