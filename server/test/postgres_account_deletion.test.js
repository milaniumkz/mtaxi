const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

// This integration check requires a disposable PostgreSQL database, never live data.
test('PostgreSQL account deletion preserves another driver ledger without dangling foreign keys', {
  skip: !process.env.MTAXI_TEST_POSTGRES_URL,
}, async () => {
  process.env.MTAXI_STORE = 'postgres';
  process.env.DATABASE_URL = process.env.MTAXI_TEST_POSTGRES_URL;
  const { applySchema } = require('../scripts/apply_schema');
  const { withStoreAsync, readStoreAsync } = require('../src/store');
  const { deleteCurrentAccountDeepAsync } = require('../src/users');
  await applySchema();
  const suffix = crypto.randomUUID();
  const passenger = { id: `pg-passenger-${suffix}`, phone: `p-${suffix}`, role: 'passenger' };
  const driver = { id: `pg-driver-${suffix}`, phone: `d-${suffix}`, role: 'driver', isDriver: true };
  const orderId = `pg-order-${suffix}`;
  const ledgerId = `pg-ledger-${suffix}`;
  await withStoreAsync(async store => {
    store.users.push(passenger, driver);
    store.orders.push({ id: orderId, userId: passenger.id, driverId: driver.id, status: 5, price: 500, type: 'taxi' });
    store.ledger.push({ id: ledgerId, userId: driver.id, orderId, type: 'order_commission', amount: 50 });
  });
  const deleted = await deleteCurrentAccountDeepAsync({}, { user: passenger });
  assert.equal(deleted.success, true);
  let store = await readStoreAsync();
  assert.equal(store.users.some(u => u.id === passenger.id), false);
  assert.equal(store.orders.some(o => o.id === orderId), false);
  const entry = store.ledger.find(e => e.id === ledgerId);
  assert.equal(entry.userId, driver.id);
  assert.equal(entry.orderId, null);
  assert.equal(entry.amount, 50);
  assert.equal(store.auditLogs.find(a => a.target === `users/${passenger.id}` && a.action === 'deleteCurrentAccountDeep').adminId, null);
  assert.equal((await deleteCurrentAccountDeepAsync({}, { user: driver })).success, true);
  store = await readStoreAsync();
  assert.equal(store.ledger.some(e => e.id === ledgerId), false);
});
