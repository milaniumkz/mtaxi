const test = require('node:test');
const assert = require('node:assert/strict');
const {Client} = require('pg');
test('Scoped PostgreSQL preserves finance, GPS automation and concurrency contracts', {skip:!process.env.MTAXI_AUDIT_PG_URL}, async t => {
  const url = new URL(process.env.MTAXI_AUDIT_PG_URL);
  assert.ok(['localhost','127.0.0.1'].includes(url.hostname)); assert.match(url.pathname,/audit/);
  process.env.MTAXI_STORE='postgres';process.env.DATABASE_URL=url.href;
  const db=new Client({connectionString:url.href}); await db.connect();
  const store=require('../src/store');
  const {sessionScope,preferencesScope,trackingScope,financialOrderScope,offerReadScope}=require('../src/store/scopes');
  const {updateUserPreferencesAsync}=require('../src/users');
  const prefix='audit-scope-';
  try {
    for(const [name,phone]of [['d','+70000000801'],['p','+70000000802'],['x','+70000000803'],['e','+70000000804'],['f','+70000000805']]) {
      await db.query('INSERT INTO users(id,phone,balance,is_driver,status_driver) VALUES($1,$2,1000,$3,$4)',[prefix+name,phone,['d','e','f'].includes(name),['d','e','f'].includes(name)?'approved':'']);
    }
    await db.query("INSERT INTO orders(id,user_id,driver_id,status,price,ot_lat,ot_lng) VALUES($1,$2,$3,2,500,53.53,76.68)",[prefix+'trip',prefix+'p',prefix+'d']);
    await db.query("INSERT INTO orders(id,user_id,driver_id,status,price) VALUES($1,$2,$3,5,500)",[prefix+'old',prefix+'p',prefix+'d']);
    await db.query('UPDATE users SET active_driver_order_id=$1,has_active_driver_order=true WHERE id=$2',[prefix+'trip',prefix+'d']);
    await t.test('reads select only relevant records and retain completed trip count',async()=>{
      const scoped=await store.readStoreAsync(sessionScope(prefix+'d'));
      assert.deepEqual(scoped.users.map(u=>u.id),[prefix+'d']);
      assert.deepEqual(scoped.orders.map(o=>o.id),[prefix+'trip']);assert.deepEqual(scoped.ledger,[]);
      const tracked=await store.readStoreAsync(trackingScope(prefix+'trip'));
      assert.equal(tracked.orders.filter(o=>o.status===5).length,1);
    });
    await t.test('partial financial writes preserve unrelated history and tolerate null offers',async()=>{
      await db.query("INSERT INTO ledger(id,user_id,order_id,type,amount) VALUES($1,$2,$3,'scope_probe',0)",[prefix+'history',prefix+'p',prefix+'old']);
      await db.query("UPDATE orders SET data=jsonb_build_object('offers',NULL) WHERE id=$1",[prefix+'trip']);
      const offers=await store.readStoreAsync(offerReadScope(prefix+'trip',prefix+'d'));
      assert.ok(offers.users.some(u=>u.id===prefix+'d'));
      await store.withStoreAsync(s=>{s.users.find(u=>u.id===prefix+'d').language='ru';},financialOrderScope(prefix+'trip',prefix+'d'));
      assert.equal((await db.query('SELECT count(*)::int AS n FROM ledger WHERE id=$1',[prefix+'history'])).rows[0].n,1);
      assert.equal((await db.query('SELECT count(*)::int AS n FROM orders WHERE id=$1',[prefix+'old'])).rows[0].n,1);
    });
    await t.test('shared user writers are concurrent across users and serialize same user',async()=>{
      let release;const gate=new Promise(r=>release=r);let entered;const ready=new Promise(r=>entered=r);
      const first=store.withStoreAsync(async s=>{entered();await gate;s.users.find(u=>u.id===prefix+'d').soundEnabled=false;},preferencesScope(prefix+'d'));
      await ready;
      let sameFinished=false;
      const same=store.withStoreAsync(s=>{sameFinished=true;s.users.find(u=>u.id===prefix+'d').language='kk';},preferencesScope(prefix+'d'));
      try {
        await Promise.race([store.withStoreAsync(s=>{s.users.find(u=>u.id===prefix+'x').language='ru';},preferencesScope(prefix+'x')),new Promise((_,reject)=>setTimeout(()=>reject(Error('Unrelated user blocked')),1500))]);
        assert.equal(sameFinished,false);
      } finally {release();await Promise.all([first,same]);}
      const user=await store.lookupUserByIdAsync(prefix+'d');assert.equal(user.soundEnabled,false);assert.equal(user.language,'kk');
    });
    await t.test('financial transactions wait for shared GPS transactions and preserve both updates',async()=>{
      let release,entered;const gate=new Promise(r=>release=r),ready=new Promise(r=>entered=r);
      const gps=store.withStoreAsync(async s=>{entered();await gate;s.users.find(u=>u.id===prefix+'d').coordsAccuracy=9;},preferencesScope(prefix+'d'));
      await ready;let wrote=false;
      const money=store.withStoreAsync(s=>{wrote=true;s.users.find(u=>u.id===prefix+'d').balance+=123;});
      try {await new Promise(r=>setTimeout(r,75));assert.equal(wrote,false);}finally{release();await Promise.all([gps,money]);}
      const user=await store.lookupUserByIdAsync(prefix+'d');assert.equal(user.balance,1123);assert.equal(user.coordsAccuracy,9);
    });
    await t.test('shared scope rejects deletion, foreign-user and monetary changes atomically',async()=>{
      for(const mutate of [s=>s.users=[],s=>s.users.find(u=>u.id===prefix+'d').balance++,s=>s.users.find(u=>u.id===prefix+'p').language='bad',s=>s.orders[0].cashToDriver=9999]) {
        await assert.rejects(store.withStoreAsync(mutate,preferencesScope(prefix+'d')));
      }
      assert.equal((await store.lookupUserByIdAsync(prefix+'d')).balance,1123);
      assert.notEqual((await store.lookupUserByIdAsync(prefix+'p')).language,'bad');
    });
    await t.test('independent financial writes overlap and cross-driver push FKs do not deadlock',async()=>{
      for(const id of ['e','f'])await db.query("INSERT INTO fcm_tokens(id,user_id,token,platform,enabled,data) VALUES($1,$2,$3,'android',true,'{}')",[prefix+id+'-token',prefix+id,prefix+id+'-token-value']);
      let entered=0,release,timedOut=false;const gate=new Promise(r=>release=r);
      const timer=setTimeout(()=>{timedOut=true;release();},2000);
      try {
        await Promise.all(['e','f'].map(id=>store.withStoreAsync(async s=>{
          if(++entered===2)release();await gate;
          const other=id==='e'?'f':'e',orderId=prefix+id+'-parallel';
          s.users.find(u=>u.id===prefix+id).balance-=1;
          s.orders.push({id:orderId,userId:prefix+id,status:0,price:500});
          s.notifications.push({id:prefix+id+'-push',type:'TEST',orderId});
          s.notificationDeliveries.push({id:prefix+id+'-delivery',notificationId:prefix+id+'-push',tokenId:prefix+other+'-token',userId:prefix+other,status:'queued'});
        },financialOrderScope('',prefix+id))));
        assert.equal(timedOut,false,'Independent orders must run concurrently');
        for(const id of ['e','f'])assert.equal((await store.lookupUserByIdAsync(prefix+id)).balance,999);
      }finally{clearTimeout(timer);release();}
    });
    await t.test('financial scope rejects modifying a user without its row lock',async()=>{
      await assert.rejects(store.withStoreAsync(s=>{s.users.find(u=>u.id===prefix+'f').balance++;},financialOrderScope('',prefix+'e')));
      assert.equal((await store.lookupUserByIdAsync(prefix+'f')).balance,999);
    });
    await t.test('GPS automatically advances arrival and queues passenger push with complete audience',async()=>{
      const now=Date.now();
      await db.query("UPDATE orders SET data=jsonb_build_object('autoArrivalSince',$2::bigint,'autoLastPosition',jsonb_build_object('latitude',53.53,'longitude',76.68,'accuracy',10,'at',$3::bigint)) WHERE id=$1",[prefix+'trip',now-16000,now-1000]);
      await db.query("INSERT INTO fcm_tokens(id,user_id,token,platform,enabled,data) VALUES($1,$2,'audit-scope-token','android',true,'{}')",[prefix+'token',prefix+'p']);
      const result=await updateUserPreferencesAsync({coords:{latitude:53.53,longitude:76.68,accuracy:10}},{user:{id:prefix+'d'}});
      assert.equal(result.success,true);
      const after=await store.readStoreAsync();assert.equal(after.orders.find(o=>o.id===prefix+'trip').status,3);
      const notification=after.notifications.find(n=>n.orderId===prefix+'trip'&&n.type==='DRIVER_ARRIVED');assert.ok(notification);
      assert.equal(after.notificationDeliveries.filter(n=>n.notificationId===notification.id).length,1);
      assert.equal(after.users.find(u=>u.id===prefix+'d').balance,1123);
      assert.ok(after.users.find(u=>u.id===prefix+'x'));
    });
    await t.test('GPS racing assignment and completion cannot deadlock or overwrite money',async()=>{
      const ordersApi=require('../src/orders');
      assert.equal((await ordersApi.cancelPassengerOrderAsync({orderDocPath:'order/'+prefix+'trip'},{user:{id:prefix+'p'}})).success,true);
      const before=(await store.lookupUserByIdAsync(prefix+'d')).balance;
      for(let i=0;i<10;i++) {
        const created=await ordersApi.createPassengerOrderAsync({type:'taxi',city:'Железинка',ot:'Тест1',kuda:'Тест10',price:500,fromPoint:{latitude:53.53,longitude:76.68},toPoint:{latitude:53.54,longitude:76.69}},{user:{id:prefix+'p'}});
        assert.equal(created.success,true);const request={orderDocPath:created.orderDocPath};
        const gps=()=>updateUserPreferencesAsync({coords:{latitude:53.53,longitude:76.68,accuracy:10}},{user:{id:prefix+'d'}});
        const assigned=await Promise.all([ordersApi.acceptOrderAsync(request,{user:{id:prefix+'d'}}),gps()]);
        assert.ok(assigned.every(r=>r.success));
        for(const nextStatus of [3,4])assert.equal((await ordersApi.advanceDriverOrderStatusAsync({...request,nextStatus},{user:{id:prefix+'d'}})).success,true);
        const done=await Promise.all([ordersApi.advanceDriverOrderStatusAsync({...request,nextStatus:5},{user:{id:prefix+'d'}}),gps()]);
        assert.ok(done.every(r=>r.success));
      }
      const driver=await store.lookupUserByIdAsync(prefix+'d');assert.equal(driver.balance,before-500);assert.equal(driver.activeDriverOrderId,null);
    });
  }finally{
    await db.query("DELETE FROM notification_deliveries WHERE notification_id IN (SELECT id FROM notifications WHERE data->>'orderId' IN (SELECT id FROM orders WHERE user_id LIKE 'audit-scope-%')) OR user_id LIKE 'audit-scope-%'");
    await db.query("DELETE FROM notifications WHERE data->>'orderId' IN (SELECT id FROM orders WHERE user_id LIKE 'audit-scope-%')");
    await db.query("DELETE FROM fcm_tokens WHERE id LIKE 'audit-scope-%'");
    await db.query("DELETE FROM ledger WHERE id LIKE 'audit-scope-%' OR user_id LIKE 'audit-scope-%'");
    await db.query("DELETE FROM orders WHERE id LIKE 'audit-scope-%' OR user_id LIKE 'audit-scope-%'");
    await db.query("DELETE FROM users WHERE id LIKE 'audit-scope-%'");await db.end();await store.getPool().end();await store.getReadPool().end();
  }
});
