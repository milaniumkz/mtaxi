const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');
const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'mtaxi-bonus-integration-'));
process.env.MTAXI_DATA_DIR = dataDir;
process.env.MTAXI_STORE = 'json';
const { withStoreAsync, readStoreAsync } = require('../src/store');
const { approveDriverAsync, adminManageOrderAsync } = require('../src/admin');
const { acceptOrderAsync, advanceDriverOrderStatusAsync, cancelPassengerOrderAsync } = require('../src/orders');
const { createDriverWithdrawalAsync, createDriverTopUpPaymentAsync,
  getDriverTopUpPaymentStatusAsync, confirmDriverTopUpPaymentAsync,
  adminListPaymentsAsync, adminMarkKaspiInvoiceSentAsync, failDriverTopUpPaymentAsync } = require('../src/payments');
const { getSessionBootstrapAsync } = require('../src/session');
const { updateRuntimeSettingsAsync } = require('../src/settings');
test.after(() => fs.rmSync(dataDir, { recursive: true, force: true }));

test('approved driver receives one welcome reward, earns daily reward and cannot withdraw bonuses', async () => {
  const initial = await readStoreAsync();
  const driver = initial.users.find(user => user.isDriver);
  const passenger = initial.users.find(user => user.roleState === 'PASSENGER');
  const admin = initial.users.find(user => user.role === 'admin');
  const driverAuth = { user: driver };
  const adminAuth = { user: admin };
  await withStoreAsync(async store => {
    const user = store.users.find(user => user.id === driver.id);
    user.statusDriver = 'pending';
    user.balance = 0;
  });
  const data = { userDocPath: `users/${driver.id}` };
  assert.equal((await approveDriverAsync(data, adminAuth)).user.bonusBalance, 1000);
  assert.equal((await approveDriverAsync(data, adminAuth)).user.bonusBalance, 1000);
  for (let index = 0; index < 10; index++) {
    const id = `bonus-order-${index}`;
    await withStoreAsync(async store => {
      store.orders.push({ id, userId: passenger.id, status: 0, price: 500, type: 'taxi' });
    });
    assert.equal((await acceptOrderAsync({ orderId: id }, driverAuth)).success, true);
    for (const nextStatus of [3,4,5]) assert.equal((await advanceDriverOrderStatusAsync({ orderId: id, nextStatus }, driverAuth)).success, true);
  }
  const session = await getSessionBootstrapAsync({}, driverAuth);
  assert.equal(session.driverBonus.completedOrders, 10);
  assert.equal(session.driverBonus.awarded, true);
  assert.equal(session.driverBonus.balance, 1500);
  assert.equal(session.user.balance, 0);
  assert.equal((await advanceDriverOrderStatusAsync({ orderId: 'bonus-order-9', nextStatus: 5 }, driverAuth)).success, false);
  const withdrawal = await createDriverWithdrawalAsync({ amount: 100, cardNumber: '4400123456789012' }, driverAuth);
  assert.equal(withdrawal.code, 'BALANCE_NOT_ENOUGH');
  assert.equal((await updateRuntimeSettingsAsync({ fields: { driverBonusEnabled: false } }, driverAuth)).code, 'ADMIN_REQUIRED');
  assert.equal((await updateRuntimeSettingsAsync({ fields: { driverBonusEnabled: false } }, adminAuth)).success, true);
  assert.equal((await getSessionBootstrapAsync({}, driverAuth)).driverBonus.enabled, false);

  for (const adminCancel of [false, true]) {
    const id = `cancel-${adminCancel}`;
    await withStoreAsync(async store => {
      store.orders.push({ id, userId: passenger.id, status: 0, price: 500, type: 'taxi' });
    });
    assert.equal((await acceptOrderAsync({ orderId: id }, driverAuth)).success, true);
    const result = adminCancel
      ? await adminManageOrderAsync({ orderDocPath: `order/${id}`, action: 'cancel' }, adminAuth)
      : await cancelPassengerOrderAsync({ orderDocPath: `order/${id}` }, { user: passenger });
    assert.equal(result.success, true);
    const after = await getSessionBootstrapAsync({}, driverAuth);
    assert.equal(after.driverBonus.balance, 1500);
    assert.equal(after.user.balance, 0);
  }
});

test('Kaspi request notifies admin and credits cash only once after manual confirmation', async () => {
  const initial = await readStoreAsync();
  const driver = initial.users.find(user => user.isDriver);
  const admin = initial.users.find(user => user.role === 'admin');
  const auth = { user: driver };
  const adminAuth = { user: admin };
  const balanceBefore = driver.balance;
  const bonusBefore = driver.bonusBalance;
  await withStoreAsync(async store => {
    store.fcmTokens.push(
      { id: 'test-driver-token', userId: driver.id, token: 'local-driver-token', deviceType: 'Android' },
      { id: 'test-admin-token', userId: admin.id, token: 'local-admin-token', deviceType: 'Android' },
    );
  });
  const data = { amount: 2000, method: 'kaspi_manual', kaspiPhone: '87011234567', idempotencyKey: 'kaspi-request-test' };
  const invalid = await createDriverTopUpPaymentAsync({ ...data, kaspiPhone: '123' }, auth);
  assert.equal(invalid.code, 'KASPI_PHONE_INVALID');
  const created = await createDriverTopUpPaymentAsync(data, auth);
  assert.equal(created.success, true);
  assert.equal(created.manual, true);
  const repeated = await createDriverTopUpPaymentAsync(data, auth);
  assert.equal(repeated.paymentId, created.paymentId);
  const conflict = await createDriverTopUpPaymentAsync({ ...data, kaspiPhone: '+77019999999' }, auth);
  assert.equal(conflict.code, 'PAYMENT_IDEMPOTENCY_CONFLICT');
  let status = await getDriverTopUpPaymentStatusAsync({ paymentId: created.paymentId }, auth);
  assert.equal(status.balance, balanceBefore);
  assert.equal(status.paymentStatus, 'pending');
  const list = await adminListPaymentsAsync({}, adminAuth);
  assert.equal(list.pendingKaspiCount, 1);
  assert.equal(list.payments.find(item => item.paymentId === created.paymentId).kaspiPhone, '+77011234567');
  const store = await readStoreAsync();
  assert.equal(store.notifications.filter(item => item.type === 'KASPI_TOPUP_REQUEST').length, 1);
  const notification = store.notifications.find(item => item.type === 'KASPI_TOPUP_REQUEST');
  assert.equal(notification.targetRole, 'admin');
  assert.equal(notification.dataPayload.type, 'KASPI_TOPUP_REQUEST');
  assert.equal(notification.dataPayload.notificationId, notification.id);
  assert.deepEqual(store.notificationDeliveries.filter(item => item.notificationId === notification.id).map(item => item.userId), [admin.id]);
  assert.equal((await confirmDriverTopUpPaymentAsync({ paymentId: created.paymentId }, auth)).code, 'ADMIN_REQUIRED');
  assert.equal((await adminMarkKaspiInvoiceSentAsync({ paymentId: created.paymentId }, adminAuth)).success, true);
  const confirmations = await Promise.all([
    confirmDriverTopUpPaymentAsync({ paymentId: created.paymentId }, adminAuth),
    confirmDriverTopUpPaymentAsync({ paymentId: created.paymentId }, adminAuth),
  ]);
  assert.equal(confirmations.filter(result => result.code === 'PAYMENT_CONFIRMED').length, 1);
  status = await getDriverTopUpPaymentStatusAsync({ paymentId: created.paymentId }, auth);
  assert.equal(status.balance, balanceBefore + 2000);
  assert.equal(status.user.bonusBalance, bonusBefore);
  const declined = await createDriverTopUpPaymentAsync({ ...data, idempotencyKey: 'decline-test' }, auth);
  await failDriverTopUpPaymentAsync({ paymentId: declined.paymentId }, adminAuth);
  assert.equal((await confirmDriverTopUpPaymentAsync({ paymentId: declined.paymentId }, adminAuth)).code, 'PAYMENT_FAILED');
});
