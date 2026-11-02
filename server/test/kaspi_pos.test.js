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
  s.ledger = []; s.auditLogs = []; s.notifications = []; s.notificationDeliveries = [];
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
  assert.equal(connected.status.organization.iin, '970905350621');
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
test('authorized merchant can issue and verify invoices despite a legacy operator IIN setting', async () => {
  const f = fixture({ iin: '981008450268' });
  assert.equal((await f.service.sendInvoice({ paymentId: 'topup', confirm: true }, admin)).success, true);
  assert.equal(f.calls(), 1);
  let db = await store.readStoreAsync();
  assert.equal(db.payments[0].kaspiPosOrganizationIin, '981008450268');
  assert.equal(db.users[0].balance, 100);
  f.setDetails({ Id: 123, Amount: 500, ClientMobile: '77019990001', Status: 'Processed' });
  assert.equal((await f.service.checkInvoice({ paymentId: 'topup' }, admin)).success, true);
  assert.equal((await confirmDriverTopUpPaymentAsync({ paymentId: 'topup' }, admin)).success, true);
  db = await store.readStoreAsync(); assert.equal(db.users[0].balance, 600);
});
test('switching cashier organization cannot verify an earlier organization invoice', async () => {
  const f = fixture();
  await f.service.sendInvoice({ paymentId: 'topup', confirm: true }, admin);
  const state = f.vault.load(); state.session.organizationId = '26'; state.session.organizationIin = '981008450268'; f.vault.save(state);
  assert.equal((await f.service.checkInvoice({ paymentId: 'topup' }, admin)).code, 'KASPI_INVOICE_UNLINKED');
  assert.equal((await confirmDriverTopUpPaymentAsync({ paymentId: 'topup' }, admin)).success, false);
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

test('automatic request creates once then credits confirmed payment while app is closed', async () => {
  const f = fixture({ iin: '981008450268' });
  const { createKaspiAutomation } = require('../src/kaspi_pos/automation');
  const payments = require('../src/payments');
  const config = { ...env, MTAXI_KASPI_POS_AUTO_INVOICES: 'true' };
  const worker = createKaspiAutomation({ env: config, store, service: f.service, payments });
  await store.withStoreAsync(s => { s.payments[0].kaspiAuto = true; });
  const user = { user: { id: 'p', role: 'passenger' } };
  const result = await worker.afterCreated({ success: true, paymentId: 'topup' }, user);
  assert.equal(result.automatic, true); assert.equal(result.invoiceStatus, 'sent'); assert.equal(result.paymentStatus, 'pending');
  assert.equal(f.calls(), 1); assert.equal((await store.readStoreAsync()).users[0].balance, 100);
  f.setDetails({ Id: 123, Amount: 500, ClientMobile: '77019990001', Status: 'Processed' });
  await store.withStoreAsync(s => { s.payments[0].kaspiAutoNextCheckAt = null; });
  const restarted = createKaspiAutomation({ env: config, store, service: f.service, payments });
  await Promise.all([restarted.tick(), restarted.tick(), worker.processPayment('topup')]);
  const db = await store.readStoreAsync(); assert.equal(db.users[0].balance, 600); assert.equal(db.payments[0].status, 'success'); assert.equal(f.calls(), 1);
  assert.equal(db.ledger.filter(x => x.type === 'driver_top_up').length, 1);
  await restarted.tick(); assert.equal((await store.readStoreAsync()).users[0].balance, 600);
});
test('automatic cancellation fails request without credit; uncertain create is never repeated', async () => {
  const { createKaspiAutomation } = require('../src/kaspi_pos/automation');
  let f = fixture();
  const config = { ...env, MTAXI_KASPI_POS_AUTO_INVOICES: 'true' };
  await store.withStoreAsync(s => { s.payments[0].kaspiAuto = true; });
  let worker = createKaspiAutomation({ env: config, store, service: f.service });
  await worker.processPayment('topup');
  f.setDetails({ Id: 123, Amount: 500, ClientMobile: '77019990001', Status: 'RemotePaymentCanceled' });
  await store.withStoreAsync(s => { s.payments[0].kaspiAutoNextCheckAt = null; });
  await worker.tick(); let db = await store.readStoreAsync();
  assert.equal(db.payments[0].status, 'failed'); assert.equal(db.payments[0].kaspiPosBankState, 'cancelled'); assert.equal(db.users[0].balance, 100);
  await store.withStoreAsync(s => { s.payments = [{ paymentId: 'topup', userId: 'p', amount: 500, kaspiPhone: '+77019990001', provider: 'kaspi_manual', kaspiAuto: true, status: 'pending' }]; });
  f = fixture({ bankFailure: true }); worker = createKaspiAutomation({ env: config, store, service: f.service });
  await worker.processPayment('topup');
  await store.withStoreAsync(s => { s.payments[0].kaspiAutoNextCheckAt = null; });
  await worker.tick(); assert.equal(f.calls(), 1); db = await store.readStoreAsync(); assert.equal(db.payments[0].kaspiPosCreateState, 'unknown'); assert.equal(db.users[0].balance, 100);
});
test('automatic requests enforce ownership, feature switch and strict bank amount verification', async () => {
  const f = fixture(); const { createKaspiAutomation } = require('../src/kaspi_pos/automation');
  await store.withStoreAsync(s => { s.payments[0].kaspiAuto = true; });
  const worker = createKaspiAutomation({ env: { ...env, MTAXI_KASPI_POS_AUTO_INVOICES: 'true' }, store, service: f.service });
  await worker.afterCreated({ success: true, paymentId: 'topup' }, { user: { id: 'other' } }); assert.equal(f.calls(), 0);
  const disabled = createKaspiAutomation({ env, store, service: f.service }); await disabled.tick(); assert.equal(f.calls(), 0);
  await worker.processPayment('topup');
  f.setDetails({ Id: 123, Amount: 50000, ClientMobile: '77019990001', Status: 'Processed' });
  await store.withStoreAsync(s => { s.payments[0].kaspiAutoNextCheckAt = null; });
  await worker.tick(); const db = await store.readStoreAsync(); assert.equal(db.payments[0].kaspiPosBankState, 'unverified'); assert.equal(db.users[0].balance, 100); assert.equal(db.payments[0].applied, undefined);
});
test('admin test link is fixed at 100, idempotent, isolated from wallet credit and status reads', async () => {
  const f = fixture(); let creates = 0;
  f.bank.createTestLink = async () => { creates++; return { operationId: '987', paymentUrl: 'https://pay.kaspi.kz/pay/fixture', expiresAt: null }; };
  f.bank.testLinkStatus = async () => ({ Status: 'Processed', QrOperationId: 987, Amount: 100 });
  const data = { confirm: true, requestId: 'test-request-100-unique', amount: 9999 };
  const first = await f.service.testLink(data, admin);
  assert.equal(first.success, true); assert.equal(first.amount, 100);
  assert.equal((await f.service.testLink(data, admin)).paymentUrl, first.paymentUrl); assert.equal(creates, 1);
  f.bank.testLinkStatus = async () => ({ Status: 'QrTokenCreated', QrOperationId: 987, Amount: 0 });
  assert.equal((await f.service.checkTestLink({ paymentId: first.paymentId }, admin)).bankState, 'pending');
  f.bank.testLinkStatus = async () => ({ Status: 'Processed', QrOperationId: 987, Amount: 0 });
  assert.equal((await f.service.checkTestLink({ paymentId: first.paymentId }, admin)).code, 'KASPI_PAYMENT_BINDING_MISMATCH');
  f.bank.testLinkStatus = async () => ({ Status: 'Processed', QrOperationId: 987, Amount: 100 });
  const checked = await f.service.checkTestLink({ paymentId: first.paymentId }, admin); assert.equal(checked.bankState, 'paid');
  assert.equal((await confirmDriverTopUpPaymentAsync({ paymentId: first.paymentId }, admin)).code, 'TEST_PAYMENT_NO_WALLET');
  assert.equal((await store.readStoreAsync()).users[0].balance, 100);
});
test('test link transport uses fixed amount and only returns a bank HTTPS payment URL', async () => {
  let body;
  const identity = createIdentity();
  const client = new KaspiProtocol(identity, { env: {}, fetchImpl: async (_, options) => { body = JSON.parse(options.body); return new Response(JSON.stringify({ StatusCode: 0, Data: { QrOperationId: 987, Amount: 100, QrToken: 'https://qr.kaspi.kz/fixture' } }), { status: 200 }); } });
  const session = { tokenSN: 'FIXTURE', secretB64: Buffer.alloc(32).toString('base64'), profileId: '12' };
  assert.equal((await client.createTestLink(session, { amount: 9999 })).paymentUrl, 'https://pay.kaspi.kz/pay/fixture'); assert.equal(body.PaymentAmount, 100); assert.equal(body.Latitude, undefined);
  client.fetchImpl = async () => new Response(JSON.stringify({ Data: { QrOperationId: 987, Amount: 0, QrToken: 'https://qr.kaspi.kz/fixture' } }), { status: 200 });
  assert.equal((await client.createTestLink(session)).paymentUrl, 'https://pay.kaspi.kz/pay/fixture');
  client.fetchImpl = async () => new Response(JSON.stringify({ Data: { QrOperationId: 987, Amount: 100, QrToken: 'https://untrusted.example/pay' } }), { status: 200 });
  await assert.rejects(() => client.createTestLink(session), /KASPI_QR_URL_INVALID/);
});
test('paid QR status without amount verifies formatted bank details, restores status and never credits a wallet', async () => {
  const f = fixture(); const { bankAmount } = require('../src/kaspi_pos/protocol');
  assert.equal(bankAmount('+100 ₸'), 100); assert.equal(bankAmount('1\u00a0000,50 ₸'), 1000.5); assert.ok(Number.isNaN(bankAmount('-100 ₸'))); assert.ok(Number.isNaN(bankAmount('100anything')));
  f.bank.createTestLink = async () => ({ operationId: '987', paymentUrl: 'https://pay.kaspi.kz/pay/fixture' });
  f.bank.testLinkStatus = async () => ({ Id: 987, Status: 'Processed' });
  let details = { Id: 987, Amount: '+100 ₸', OrganizationIdn: '970905350621' };
  f.bank.qrOperationDetails = async () => details;
  const created = await f.service.testLink({ confirm: true, requestId: 'paid-qr-formatted-amount' }, admin);
  assert.equal((await f.service.checkTestLink({ paymentId: created.paymentId }, admin)).bankState, 'paid');
  let db = await store.readStoreAsync(); assert.equal(db.payments.find(p=>p.paymentId===created.paymentId).status, 'success'); assert.equal(db.users[0].balance, 100);
  assert.equal((await f.service.getStatus({},admin)).status.latestTestLink.bankState, 'paid');
  for (const wrong of [{...details, Amount:'+10 ₸'}, {...details, Id:999}, {...details,OrganizationIdn:'981008450268'}]) {
    details=wrong; assert.equal((await f.service.checkTestLink({paymentId:created.paymentId},admin)).code, 'KASPI_PAYMENT_BINDING_MISMATCH');
  }
});
test('background test link check settles only test status and ordinary top-up emits one credit notification', async () => {
  const f = fixture(); const { createKaspiAutomation } = require('../src/kaspi_pos/automation');
  f.bank.createTestLink = async () => ({operationId:'987',paymentUrl:'https://pay.kaspi.kz/pay/fixture'});
  f.bank.testLinkStatus = async () => ({Id:987,Status:'Processed'});
  f.bank.qrOperationDetails = async () => ({Id:987,Amount:'+100 ₸',OrganizationIdn:'970905350621'});
  const created = await f.service.testLink({confirm:true,requestId:'background-qr-test-link'},admin);
  const worker = createKaspiAutomation({env:{...env,MTAXI_KASPI_POS_AUTO_INVOICES:'true'},store,service:f.service});
  await worker.tick(); let db=await store.readStoreAsync();assert.equal(db.payments.find(p=>p.paymentId===created.paymentId).status,'success');assert.equal(db.users[0].balance,100);
  await f.service.sendInvoice({paymentId:'topup',confirm:true},admin);
  f.setDetails({Id:123,Amount:'500 ₸',ClientMobile:'77019990001',Status:'Processed'});
  await f.service.checkInvoice({paymentId:'topup'},admin);
  await confirmDriverTopUpPaymentAsync({paymentId:'topup'},admin);await confirmDriverTopUpPaymentAsync({paymentId:'topup'},admin);
  db=await store.readStoreAsync();assert.equal(db.users[0].balance,600);assert.equal(db.notifications.filter(n=>n.type==='WALLET_TOPUP_PAID').length,1);
});
