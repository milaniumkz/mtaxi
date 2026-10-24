// Explicit owner-authorized approval of the dedicated store review account.
// Never changes credentials, availability, orders, or existing working accounts.
const assert = require('node:assert/strict');
const { readStoreAsync, getPool } = require('../src/store');
const { approveDriverAsync } = require('../src/admin');

async function main() {
  assert.equal(process.env.MTAXI_STORE, 'postgres');
  const store = await readStoreAsync();
  const target = store.users.find(user => user.phone === '+70000006525');
  assert.ok(target, 'Dedicated review driver must be registered first');
  assert.equal(target.displayName, 'Store Review Driver');
  assert.equal(target.driverOnLine, false);
  assert.equal(target.roleState, 'DRIVER_OFFLINE');
  const admin = store.users.find(user => user.role === 'admin' && !user.blocked);
  assert.ok(admin, 'An existing administrator is required');
  const result = await approveDriverAsync({ userDocPath: `users/${target.id}` }, { user: admin });
  assert.equal(result.success, true);
  const verified = (await readStoreAsync()).users.find(user => user.id === target.id);
  assert.equal(verified.statusDriver, 'approved');
  assert.equal(verified.driverOnLine, false);
  assert.equal(verified.roleState, 'DRIVER_OFFLINE');
  console.log('Dedicated store review driver approved; remains offline. No orders created.');
}
main().catch(error => { console.error(error.message); process.exitCode = 1; })
  .finally(async () => { if (typeof getPool === 'function') await getPool().end(); });
