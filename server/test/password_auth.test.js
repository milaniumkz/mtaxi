const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');
const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'mtaxi-password-auth-'));
process.env.MTAXI_STORE = 'json';
process.env.MTAXI_DATA_DIR = dataDir;
const { registerWithPassword, passwordLogin, verifyBearerToken } = require('../src/auth');
const { readStoreAsync, withStoreAsync } = require('../src/store');
const { adminUpdateUserDocumentAsync, adminListUsersAsync } = require('../src/admin');
const { dispatchCall } = require('../src/call_router');
const { clearRateLimits } = require('../src/rate_limit');
const { runPreflight } = require('../scripts/preflight');
const bearer = token => ({ ip: '192.0.2.40', get: name => name === 'authorization' ? `Bearer ${token}` : '' });
test.after(() => fs.rmSync(dataDir, { recursive: true, force: true }));

test('registration rejects weak passwords and malformed numbers', async () => {
  assert.equal((await registerWithPassword({ phone: '7012223344', password: '1234567' })).success, false);
  assert.equal((await registerWithPassword({ phone: '7012223344', password: 'a'.repeat(129) })).success, false);
  assert.equal((await registerWithPassword({ phone: '123', password: 'a-valid-password' })).code, 'PHONE_INVALID');
  assert.equal((await registerWithPassword({ phone: '+70000000000', password: 'a-valid-password' })).code, 'PHONE_RESERVED');
});

test('concurrent registration of one normalized phone creates exactly one account', async () => {
  const attempts = await Promise.all(['+77012223344', '87012223344', '7012223344'].map(phone =>
    registerWithPassword({ phone, password: 'a-valid-password', role: 'admin', bonusBalance: 100000 })));
  assert.equal(attempts.filter(result => result.success).length, 1);
  const store = await readStoreAsync();
  const users = store.users.filter(user => user.phone === '+77012223344');
  assert.equal(users.length, 1);
  assert.equal(users[0].role, 'passenger');
  assert.equal(users[0].bonusBalance || 0, 0);
  assert.equal(users[0].password, undefined);
  assert.match(users[0].passwordHash, /^scrypt\$/);
  const login = await passwordLogin({ phone: '7012223344', password: 'a-valid-password' });
  assert.equal(login.success, true);
  assert.equal(login.user.passwordHash, undefined);
  assert.equal((await verifyBearerToken(bearer(login.token))).user.id, users[0].id);
});

test('an existing account without password cannot be claimed by public registration', async () => {
  await withStoreAsync(async store => store.users.push({ id: 'old-no-password', phone: '+77013334455', balance: 9000 }));
  assert.equal((await registerWithPassword({ phone: '7013334455', password: 'new-password' })).code, 'ACCOUNT_EXISTS');
  assert.equal((await passwordLogin({ phone: '7013334455', password: 'new-password' })).success, false);
  assert.equal((await readStoreAsync()).users.find(user => user.id === 'old-no-password').balance, 9000);
});

test('administrator password recovery hashes the password, revokes sessions and excludes hashes from audit', async () => {
  const signup = await registerWithPassword({ phone: '7014445566', password: 'old-password' });
  const admin = (await readStoreAsync()).users.find(user => user.role === 'admin');
  const params = { userDocPath: signup.userDocPath, fields: { password: 'new-password' } };
  assert.equal((await adminUpdateUserDocumentAsync(params, { user: signup.user })).success, false);
  assert.equal((await adminUpdateUserDocumentAsync(params, { user: admin })).success, true);
  assert.equal(await verifyBearerToken(bearer(signup.token)), null);
  assert.equal((await passwordLogin({ phone: '7014445566', password: 'old-password' })).success, false);
  const login = await passwordLogin({ phone: '7014445566', password: 'new-password' });
  assert.equal(login.success, true);
  assert.ok(await verifyBearerToken(bearer(login.token)));
  const store = await readStoreAsync();
  const audit = store.auditLogs.filter(log => log.action === 'adminUpdateUserDocument');
  assert.doesNotMatch(JSON.stringify(audit), /new-password|passwordHash|scrypt\$/);
});

test('the old administrator phone does not grant privileges without the admin role', async () => {
  const response = await adminListUsersAsync({}, { user: { id: 'impostor', phone: '+70000000000', role: 'passenger' } });
  assert.equal(response.success, false);
});

test('auth rate limits cannot be bypassed by rotating phones or spoofing forwarded headers', async () => {
  const oldMax = process.env.MTAXI_AUTH_RATE_LIMIT_MAX;
  process.env.MTAXI_AUTH_RATE_LIMIT_MAX = '2';
  clearRateLimits();
  try {
    const req = { ip: '192.0.2.90', headers: {}, get: () => '' };
    for (let index = 0; index < 2; index++) {
      req.headers['x-forwarded-for'] = `192.0.2.${index}`;
      assert.notEqual((await dispatchCall('passwordLogin', { phone: `701000000${index}`, password: 'bad' }, req)).code, 'RATE_LIMITED');
    }
    req.headers['x-forwarded-for'] = '192.0.2.200';
    assert.equal((await dispatchCall('passwordLogin', { phone: '7010000099', password: 'bad' }, req)).code, 'RATE_LIMITED');
  } finally {
    if (oldMax === undefined) delete process.env.MTAXI_AUTH_RATE_LIMIT_MAX;
    else process.env.MTAXI_AUTH_RATE_LIMIT_MAX = oldMax;
    clearRateLimits();
  }
});

test('production no longer requires paid SMS configuration', async () => {
  const result = await runPreflight({ env: { NODE_ENV: 'production', MTAXI_SMS_PROVIDER: 'disabled' }, checkDatabase: false, checkUploadDir: false });
  const checks = result.checks.filter(check => /SMS/.test(check.name));
  assert.ok(checks.length > 0);
  assert.deepEqual(checks.filter(check => !check.ok), []);
});
