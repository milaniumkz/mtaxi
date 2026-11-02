const test = require('node:test');
const assert = require('node:assert/strict');
const { Client } = require('pg');

test('PostgreSQL preserves complete ledger and does not rewrite unchanged users', {
  skip: !process.env.MTAXI_AUDIT_PG_URL,
}, async () => {
  const url = new URL(process.env.MTAXI_AUDIT_PG_URL);
  assert.ok(['127.0.0.1', 'localhost'].includes(url.hostname));
  assert.match(url.pathname, /audit/);
  process.env.MTAXI_STORE = 'postgres';
  process.env.DATABASE_URL = url.href;
  const db = new Client({ connectionString: url.href });
  await db.connect();
  try {
    await db.query("INSERT INTO users(id,phone,display_name) VALUES ('audit-retention','+70000000901','Synthetic retention fixture') ON CONFLICT(id) DO NOTHING");
    await db.query("INSERT INTO ledger(id,type,amount,created_at) SELECT 'audit-retention-'||i,'audit_fixture',0,now()-(i||' seconds')::interval FROM generate_series(1,5001) i ON CONFLICT(id) DO NOTHING");
    const before = await db.query("SELECT xmin::text FROM users WHERE id='audit-retention'");
    const store = require('../src/store/postgres_store');
    const snapshot = await store.readStoreAsync();
    assert.deepEqual(await store.lookupUserByIdAsync('audit-retention'), snapshot.users.find(u=>u.id==='audit-retention'));
    assert.equal(await store.lookupUserByIdAsync('missing-audit-user'), null);
    await store.withStoreAsync(s => { s.settings.auditRetentionProbe = true; });
    const count = await db.query("SELECT count(*)::int AS n FROM ledger WHERE id LIKE 'audit-retention-%'");
    assert.equal(count.rows[0].n, 5001, 'Ordinary mutations must not delete old financial entries');
    const after = await db.query("SELECT xmin::text FROM users WHERE id='audit-retention'");
    assert.equal(after.rows[0].xmin, before.rows[0].xmin, 'Unchanged users must not be rewritten');
    await store.withStoreAsync(s=>{s.users.find(u=>u.id==='audit-retention').roleState='PASSENGER';});
    await db.query('BEGIN');
    await db.query("SELECT pg_advisory_xact_lock(hashtext('mtaxi_store_write'))");
    try {
      const {getSessionBootstrapAsync}=require('../src/session');
      const result=await Promise.race([getSessionBootstrapAsync({}, {user:{id:'audit-retention'}}),new Promise(resolve=>setTimeout(()=>resolve('timeout'),1500))]);
      assert.notEqual(result,'timeout','An unchanged session read must not wait for the global write lock');
      assert.equal(result.success,true);
    } finally { await db.query('ROLLBACK'); }
  } finally {
    await db.query("DELETE FROM ledger WHERE id LIKE 'audit-retention-%'");
    await db.query("DELETE FROM users WHERE id='audit-retention'");
    await db.end();
  }
});
