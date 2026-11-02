const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'mtaxi-kaspi-pos-'));
process.env.MTAXI_STORE = 'json'; process.env.MTAXI_DATA_DIR = path.join(root, 'db'); process.env.MTAXI_FCM_ENABLED = 'false';
const store = require('../src/store');
const { createKaspiService } = require('../src/kaspi_pos');
const { KaspiVault } = require('../src/kaspi_pos/vault');
const { KaspiProtocol, KaspiError } = require('../src/kaspi_pos/protocol');
const { createIdentity } = require('../src/kaspi_pos/crypto');
const { Response } = require('node-fetch');
const { confirmDriverTopUpPaymentAsync, failDriverTopUpPaymentAsync } = require('../src/payments');
const admin = { user: { id: 'admin', role: 'admin' } };
const env = { MTAXI_KASPI_POS_ENABLED: 'true', MTAXI_KASPI_POS_EXPECTED_IIN: '970905350621' };
function fixture({ authenticated = true, iin = env.MTAXI_KASPI_POS_EXPECTED_IIN, bankFailure = false } = {}) {
  let state = { identity: createIdentity() };
  if (authenticated) state.session = { tokenSN: 'SECRET_BANK_TOKEN', secretB64: Buffer.alloc(32, 4).toString('base64'),
    profileId: '12', organizationId: '25', organizationIin: iin, orgName: 'Test merchant', organizations: [{ id: '25', name: 'Test merchant', iin }] };
  let calls = 0, details = { Id: 123, Amount: 500, ClientMobile: '77019990001', Status: 'RemotePaymentCreated' };
  const bank = {
    init: async phone => ({ processId: 'PRIVATE_BANK_PROCESS', userToken: 'PRIVATE_COOKIE', phone }), sendPhone: async () => {},
    verify: async () => ({ tokenSN: 'SECRET_BANK_TOKEN', secretB64: 'SECRET_BANK_KEY', profileId: '12', organizationId: '25', organizationIin: iin, orgName: 'Test merchant' }),
    check: async () => true,
    createInvoice: async (_, payment) => { assert.equal(payment.amount, 500); assert.equal(payment.kaspiPhone, '+77019990001'); assert.equal(payment.paymentId, 'topup'); calls++; if (bankFailure) throw new KaspiError('KASPI_NETWORK_UNCERTAIN', true); return { operationId: '123' }; },
    invoiceDetails: async () => details,
  };
  const vault = { load: () => structuredClone(state), save: value => { state = structuredClone(value); } };
  return { service: createKaspiService({ env, store, vault, protocolFactory: () => bank }), vault, bank,
    calls: () => calls, setDetails: value => { details = value; } };
}
test.beforeEach(() => store.withStoreAsync(s => {
  s.users = [{ id: 'p', balance: 100, role: 'passenger' }, admin.user];
  s.payments = [{ id: 'payment', paymentId: 'topup', userId: 'p', provider: 'kaspi_manual', status: 'pending', invoiceStatus: 'requested', amount: 500, kaspiPhone: '+77019990001' }];
  s.ledger = []; s.auditLogs = [];
}));
test.after(() => fs.rmSync(root, { recursive: true, force: true }));

test('every Kaspi operation rejects unauthenticated, passenger and blocked admin before accessing bank', async () => {
  const f = fixture();
  for (const auth of [null, { user: { id: 'p', role: 'passenger' } }, { user: { ...admin.user, blocked: true } }]) {
    for (const action of Object.values(f.service)) assert.equal((await action({}, auth)).code, 'ADMIN_REQUIRED');
  }
  assert.equal(f.calls(), 0);
});
test('disabled connection is visible but cannot request bank SMS', async () => {
  const s = createKaspiService({ env: {}, store });
  assert.equal((await s.getStatus({}, admin)).status.enabled, false);
  assert.equal((await s.startLogin({ phone: '+77019990001' }, admin)).code, 'KASPI_DISABLED');
});
test('SMS challenge is owner bound and bank secrets never enter public status or database', async () => {
  const f = fixture({ authenticated: false });
  const started = await f.service.startLogin({ phone: '+77019990001' }, admin);
  assert.equal(started.success, true);
  assert.ok(started.status.challengeId);
  assert.equal((await f.service.verifyLogin({ challengeId: started.status.challengeId, otp: '1234' }, { user: { id: 'other', role: 'admin' } })).code, 'KASPI_AUTH_EXPIRED');
  assert.equal((await f.service.getStatus({}, { user: { id: 'other', role: 'admin' } })).status.pendingAuth, false);
  const connected = await f.service.verifyLogin({ challengeId: started.status.challengeId, otp: '1234' }, admin);
  assert.equal(connected.status.connected, true);
  assert.equal(connected.status.merchantVerified, true);
  const publicData = JSON.stringify([started, connected, await store.readStoreAsync()]);
  for (const secret of ['SECRET_BANK_TOKEN', 'SECRET_BANK_KEY', 'PRIVATE_BANK_PROCESS', 'PRIVATE_COOKIE']) assert.ok(!publicData.includes(secret));
  assert.ok(!/"(?:otp|userOtp|userToken|processId|secretB64|tokenSN)"/.test(publicData));
});
test('invoice is explicit, uses stored amount/phone, and concurrent repeats create only one bank invoice', async () => {
  const f = fixture();
  assert.equal((await f.service.sendInvoice({ paymentId: 'topup' }, admin)).code, 'KASPI_INVOICE_CONFIRM_REQUIRED');
  const results = await Promise.all([1,2].map(() => f.service.sendInvoice({ paymentId: 'topup', confirm: true, amount: 9999, phone: '+77018888888' }, admin)));
  assert.ok(results.every(r => r.success)); assert.equal(f.calls(), 1);
  let db = await store.readStoreAsync(); assert.equal(db.users[0].balance, 100); assert.equal(db.ledger.length, 0);
  assert.equal((await confirmDriverTopUpPaymentAsync({ paymentId: 'topup' }, admin)).code, 'KASPI_PAYMENT_VERIFICATION_REQUIRED');
  assert.equal((await failDriverTopUpPaymentAsync({ paymentId: 'topup' }, admin)).code, 'KASPI_CANCEL_BEFORE_REJECT');
  const pending = await f.service.checkInvoice({ paymentId: 'topup' }, admin); assert.equal(pending.bankState, 'pending');
  f.setDetails({ Id: 123, Amount: 500, ClientMobile: '77019990001', Status: 'Processed' });
  assert.equal((await f.service.checkInvoice({ paymentId: 'topup' }, admin)).bankState, 'paid');
  db = await store.readStoreAsync(); assert.equal(db.users[0].balance, 100); assert.equal(db.ledger.length, 0);
  assert.equal((await confirmDriverTopUpPaymentAsync({ paymentId: 'topup' }, admin)).success, true);
  assert.equal((await confirmDriverTopUpPaymentAsync({ paymentId: 'topup' }, admin)).code, 'PAYMENT_ALREADY_APPLIED');
  db = await store.readStoreAsync(); assert.equal(db.users[0].balance, 600); assert.equal(db.ledger.length, 1);
});
test('unknown create result persists across service restart and blocks duplicate invoice or credit', async () => {
  const f = fixture({ bankFailure: true });
  assert.equal((await f.service.sendInvoice({ paymentId: 'topup', confirm: true }, admin)).code, 'KASPI_INVOICE_UNCERTAIN');
  const restarted = createKaspiService({ env, store, vault: f.vault, protocolFactory: () => f.bank });
  assert.equal((await restarted.sendInvoice({ paymentId: 'topup', confirm: true }, admin)).code, 'KASPI_INVOICE_UNCERTAIN');
  assert.equal(f.calls(), 1);
  assert.equal((await confirmDriverTopUpPaymentAsync({ paymentId: 'topup' }, admin)).success, false);
  assert.equal((await store.readStoreAsync()).users[0].balance, 100);
});
test('wrong merchant blocks invoices before reserving an attempt', async () => {
  const f = fixture({ iin: '111111111111' });
  assert.equal((await f.service.sendInvoice({ paymentId: 'topup', confirm: true }, admin)).code, 'KASPI_MERCHANT_MISMATCH');
  assert.equal(f.calls(), 0); assert.equal((await store.readStoreAsync()).payments[0].kaspiPosAttemptId, undefined);
});
test('wrong operation, amount or phone cannot verify payment and invalidates earlier paid state', async () => {
  const f = fixture(); await f.service.sendInvoice({ paymentId: 'topup', confirm: true }, admin);
  for (const changed of [{ Id: 456 }, { Amount: 501 }, { ClientMobile: '77012220000' }]) {
    f.setDetails({ Id: 123, Amount: 500, ClientMobile: '77019990001', Status: 'Processed', ...changed });
    await store.withStoreAsync(s => { s.payments[0].kaspiPosBankState = 'paid'; s.payments[0].kaspiPosCheckedAt = new Date().toISOString(); });
    assert.equal((await f.service.checkInvoice({ paymentId: 'topup' }, admin)).code, 'KASPI_PAYMENT_BINDING_MISMATCH');
    assert.equal((await store.readStoreAsync()).payments[0].kaspiPosBankState, 'unverified');
    assert.equal((await confirmDriverTopUpPaymentAsync({ paymentId: 'topup' }, admin)).success, false);
  }
});
test('vault encrypts session/private keys, survives restart, rejects tampering and permissive key files', () => {
  const dir = path.join(root, crypto.randomUUID()); fs.mkdirSync(dir, { mode: 0o700 });
  const key = path.join(dir, 'key'); fs.writeFileSync(key, crypto.randomBytes(32).toString('hex'), { mode: 0o600 });
  const vault = new KaspiVault(path.join(dir, 'state'), key);
  const data = { session: { tokenSN: 'VERY_SECRET_BANK_TOKEN', secretB64: 'PRIVATE_SECRET' }, identity: createIdentity() };
  vault.save(data); assert.deepEqual(new KaspiVault(path.join(dir, 'state'), key).load(), data);
  assert.ok(!fs.readFileSync(vault.file).includes(Buffer.from('VERY_SECRET_BANK_TOKEN')));
  assert.equal(fs.statSync(vault.file).mode & 0o777, 0o600);
  const tampered = fs.readFileSync(vault.file); tampered[30] ^= 1; fs.writeFileSync(vault.file, tampered); assert.throws(() => vault.load());
  fs.chmodSync(key, 0o644); assert.throws(() => vault.key());
});
test('wire transport rejects empty successful response and validates invoice fields, without returning bank session', async () => {
  let response = {};
  const protocol = new KaspiProtocol(createIdentity(), { env: {}, fetchImpl: async url => {
    assert.ok(url.startsWith('https://qrpay.kaspi.kz/')); return new Response(JSON.stringify(response), { status: 200 });
  } });
  const session = { tokenSN: 'synthetic-token', secretB64: Buffer.alloc(32).toString('base64'), profileId: '12' };
  await assert.rejects(protocol.check(session), { code: 'KASPI_BANK_REJECTED' });
  response = { StatusCode: 0, Data: { Id: 123, Amount: 500, ClientMobile: '77019990001' } };
  assert.deepEqual(await protocol.createInvoice(session, { amount: 500, kaspiPhone: '+77019990001', paymentId: 'topup' }), { operationId: '123' });
  response.Data.Amount = 999;
  await assert.rejects(protocol.createInvoice(session, { amount: 500, kaspiPhone: '+77019990001', paymentId: 'topup' }), { code: 'KASPI_INVOICE_RESPONSE_UNCERTAIN' });
});

test('rejected bank session cannot reserve or issue a new invoice', async () => {
  const f = fixture(); f.bank.check = async () => { throw new KaspiError('KASPI_BANK_REJECTED'); };
  assert.equal((await f.service.sendInvoice({ paymentId: 'topup', confirm: true }, admin)).code, 'KASPI_BANK_REJECTED');
  assert.equal(f.calls(), 0); assert.equal((await store.readStoreAsync()).payments[0].kaspiPosAttemptId, undefined);
});
test('one bank operation cannot credit two top-up requests', async () => {
  const f = fixture(); await f.service.sendInvoice({ paymentId: 'topup', confirm: true }, admin);
  f.setDetails({ Id: 123, Amount: 500, ClientMobile: '77019990001', Status: 'Processed' });
  await f.service.checkInvoice({ paymentId: 'topup' }, admin);
  assert.equal((await confirmDriverTopUpPaymentAsync({ paymentId: 'topup' }, admin)).success, true);
  await store.withStoreAsync(s => s.payments.push({ ...s.payments[0], id: 'duplicate', paymentId: 'duplicate', applied: false, status: 'pending' }));
  assert.equal((await confirmDriverTopUpPaymentAsync({ paymentId: 'duplicate' }, admin)).code, 'KASPI_OPERATION_ALREADY_CREDITED');
  assert.equal((await store.readStoreAsync()).users[0].balance, 600);
});
test('five rejected OTPs end the challenge without storing codes or making a connection', async () => {
  const f = fixture({ authenticated: false }); let tries = 0;
  f.bank.verify = async () => { tries++; throw new KaspiError('KASPI_OTP_REJECTED'); };
  const started = await f.service.startLogin({ phone: '+77019990001' }, admin);
  for (let n = 0; n < 5; n++) assert.equal((await f.service.verifyLogin({ challengeId: started.status.challengeId, otp: '1234' }, admin)).code, 'KASPI_OTP_REJECTED');
  assert.equal((await f.service.verifyLogin({ challengeId: started.status.challengeId, otp: '1234' }, admin)).code, 'KASPI_AUTH_EXPIRED');
  assert.equal(tries, 5);
  assert.equal((await f.service.getStatus({}, admin)).status.pendingAuth, false);
  assert.equal((await f.service.getStatus({}, admin)).status.connected, false);
});
test('full fixture bank login exchanges per-attempt ECDH and validates the returned organization', async () => {
  const identity = createIdentity();
  const bankPair = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  let shared;
  const requests = [];
  const protocol = new KaspiProtocol(identity, { env: {}, fetchImpl: async (url, opts) => {
    requests.push(url); const body = JSON.parse(opts.body);
    let response;
    if (url.endsWith('/entrance/step') && body.Data) {
      assert.equal(body.Data.appVersion, '26.1029');
      response = { meta: { pId: 'fixture-process' }, view: { code: 'EnterPhoneNumber' } };
    } else if (body.meta?.sn === 'EnterPhoneNumber') {
      assert.equal(body.data.phoneNumber, '7019990001'); response = { view: { code: 'EnterOtp' } };
    } else if (body.meta?.sn === 'ViewEnterOtp') {
      assert.equal(body.data.userOtp, '1234'); response = { data: { type: 'kpDeviceRegistration' } };
    } else if (url.endsWith('/kpentrance/finish')) {
      shared = crypto.diffieHellman({ privateKey: bankPair.privateKey, publicKey: crypto.createPublicKey({ key: Buffer.from(body.guard.x509, 'base64'), format: 'der', type: 'spki' }) });
      response = { success: true, data: { tokenSN: 'fixture-bank-token', x509: bankPair.publicKey.export({ format: 'der', type: 'spki' }).toString('base64') } };
    } else if (url.endsWith('/organizations/org-context-otp')) {
      assert.equal(opts.headers['X-Kb-TokenSn'], 'fixture-bank-token'); assert.match(opts.headers['X-Kb-TokenSnMac'], /^\d{6}$/);
      response = { StatusCode: 0, Data: { Current: { OrganizationId: 25, OrganizationName: 'Fixture merchant', OrganizationIdn: '970905350621', ProfileId: 12 }, Organizations: [] } };
    } else throw new Error('Unexpected bank request');
    return new Response(JSON.stringify(response), { status: 200, headers: { 'Set-Cookie': 'user_token=fixture-cookie; Path=/' } });
  } });
  const attempt = await protocol.init('+77019990001'); await protocol.sendPhone(attempt);
  const session = await protocol.verify(attempt, '1234');
  assert.equal(session.secretB64, shared.toString('base64')); assert.equal(session.organizationIin, '970905350621');
  assert.equal(session.profileId, '12'); assert.equal(requests.length, 5);
});
