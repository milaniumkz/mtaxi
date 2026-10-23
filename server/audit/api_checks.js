const fs=require('node:fs'),assert=require('node:assert/strict');
require('./guard').guard();
const actors=JSON.parse(fs.readFileSync(process.env.MTAXI_AUDIT_ACTORS));
const {readStoreAsync,withStoreAsync}=require('../src/store');
const {handlerNames}=require('../src/call_router');
const results=[];const output=process.env.MTAXI_AUDIT_API_RESULTS;
async function call(index,name,data={}){const r=await fetch('http://127.0.0.1:18084/call/'+name,{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+actors[index].token},body:JSON.stringify(data),signal:AbortSignal.timeout(20000)});assert.equal(r.status,200);return r.json();}
async function check(name,role,expected,run){try{const actual=await run();results.push({name,role,expected,actual,status:'passed',evidence:'real HTTP → isolated PostgreSQL; audit fixture IDs only'});}catch(e){results.push({name,role,expected,status:'failed',error:e.message});}fs.writeFileSync(output,JSON.stringify(results,null,2));}
const user=(s,i)=>s.users.find(u=>u.id===actors[i].id);
const create=(i,extra={})=>call(i,'createPassengerOrder',{type:'taxi',city:'Железинка',ot:'Тестовая 1',kuda:'Тестовая 10',fromPoint:{latitude:53.53,longitude:76.68},toPoint:{latitude:53.54,longitude:76.69},price:500,paymentMode:'cash',...extra});
(async()=>{
 const privileged=[...new Set([...handlerNames.filter(n=>n.startsWith('admin')), 'approveDriver','blockDriver','unblockDriver','getMoneyStats','updateRuntimeSettings','confirmDriverTopUpPayment','failDriverTopUpPayment','runMaintenanceTasks','flushQueuedPushDeliveries'])];
 for(const name of privileged)await check('API permission: '+name,'passenger','Administrative operation denied',async()=>{const r=await call(42,name,{});assert.equal(r.success,false);assert.match(r.code,/ADMIN|FORBIDDEN|UNAUTHENTICATED/);return {code:r.code};});
 let privacyOrder;
 await check('Foreign completed order and tracking','passenger','Other account cannot see completed order or GPS',async()=>{
  const own=await call(40,'listMyOrders',{includeClosed:true});privacyOrder=own.orders.find(o=>o.status===5).orderDocPath;
  const detail=await call(42,'getOrderDetails',{orderDocPath:privacyOrder});const tracking=await call(42,'getTripTracking',{orderDocPath:privacyOrder});assert.equal(detail.success,false);assert.equal(tracking.success,false);return {detail:detail.code,tracking:tracking.code};
 });
 await check('Concurrent wallet creation and double cancellation','passenger','One order, one500 reserve; cancellation returns exactly500 once',async()=>{
  const before=user(await readStoreAsync(),47).balance;
  const orders=await Promise.all([create(47,{paymentMode:'wallet'}),create(47,{paymentMode:'wallet'})]);assert.ok(orders.every(o=>o.success));assert.equal(orders[0].orderDocPath,orders[1].orderDocPath);
  assert.equal(user(await readStoreAsync(),47).balance,before-500);
  await Promise.all([call(47,'cancelPassengerOrder',{orderDocPath:orders[0].orderDocPath}),call(47,'cancelPassengerOrder',{orderDocPath:orders[0].orderDocPath})]);assert.equal(user(await readStoreAsync(),47).balance,before);return {uniqueOrders:1,reserved:500,finalBalance:before};
 });
 await check('Pending and blocked drivers','driver','Both direct acceptance and price offers are denied',async()=>{
  const order=await create(46);const before=await readStoreAsync();const originals=[2,3].map(i=>structuredClone(user(before,i)));
  await withStoreAsync(s=>{user(s,2).statusDriver='pending';user(s,3).blocked=true;});
  try{const codes=[];for(const i of [2,3])for(const name of ['acceptOrder','submitOrderOffer']){const r=await call(i,name,{orderDocPath:order.orderDocPath,price:600});assert.equal(r.success,false);codes.push(r.code);}return {codes};}
  finally{await withStoreAsync(s=>{for(const original of originals)s.users[s.users.findIndex(u=>u.id===original.id)]=original;});await call(46,'cancelPassengerOrder',{orderDocPath:order.orderDocPath});}
 });
 await check('Mass simultaneous order acceptance','driver/passenger','Exactly one assigned driver and one50 commission, refunded on cancellation',async()=>{
  const stale=(await readStoreAsync()).orders.find(o=>o.userId===actors[48].id&&[0,1,2,3].includes(Number(o.status)));if(stale)await call(48,'cancelPassengerOrder',{orderDocPath:'order/'+stale.id});
  const order=await create(48);const before=await readStoreAsync();const candidates=Array.from({length:20},(_,i)=>i+5);
  const accepted=await Promise.all(candidates.map(i=>call(i,'acceptOrder',{orderDocPath:order.orderDocPath})));assert.equal(accepted.filter(r=>r.accepted===true).length,1);
  const state=await readStoreAsync(),o=state.orders.find(o=>'order/'+o.id===order.orderDocPath);assert.equal(o.status,2);assert.ok(o.driverId);
  assert.equal(state.ledger.filter(l=>l.orderId===o.id&&l.type==='order_commission').length,1);
  await call(48,'cancelPassengerOrder',{orderDocPath:order.orderDocPath});const restored=await readStoreAsync();const winner=restored.users.find(u=>u.id===o.driverId),original=before.users.find(u=>u.id===o.driverId);
  assert.equal(winner.balance,original.balance);assert.equal(winner.bonusBalance,original.bonusBalance);return {attempts:20,assigned:1,commission:50,refunded:true};
 });
 await check('Manual Kaspi request, invoice mark, duplicate confirmation and idempotency','passenger/admin','Only admin confirmation adds1500, exactly once',async()=>{
  const before=user(await readStoreAsync(),45).balance;
  const data={amount:1500,kaspiPhone:actors[45].phone,idempotencyKey:'audit-manual-payment-'+Date.now()};
  const payment=await call(45,'createPassengerTopUpPayment',data);assert.equal(payment.success,true);
  const retry=await call(45,'createPassengerTopUpPayment',data);assert.equal(retry.paymentId,payment.paymentId);
  const conflict=await call(45,'createPassengerTopUpPayment',{...data,amount:1700});assert.equal(conflict.success,false);
  assert.equal((await call(42,'getDriverTopUpPaymentStatus',{paymentId:payment.paymentId})).success,false);
  assert.equal((await call(45,'confirmDriverTopUpPayment',{paymentId:payment.paymentId})).success,false);
  await call(0,'adminMarkKaspiInvoiceSent',{paymentId:payment.paymentId});assert.equal(user(await readStoreAsync(),45).balance,before);
  for(let i=0;i<2;i++)assert.equal((await call(0,'confirmDriverTopUpPayment',{paymentId:payment.paymentId})).success,true);
  assert.equal(user(await readStoreAsync(),45).balance,before+1500);
  return {manual:true,realBankContacted:false,before,after:before+1500,uniquePayment:true};
 });
 await check('Daily campaign at configured10 orders','driver/passenger','10 completed cash trips grant1000 bonus once; cancelled trips do not count',async()=>{
  const initial=await readStoreAsync();const driverIndex=actors.findIndex((actor,i)=>i>=30&&i<40&&actor.isDriver&&!user(initial,i).bonusAwarded&&!user(initial,i).hasActiveDriverOrder);assert.ok(driverIndex>=0);
  const before=user(initial,driverIndex);const initialBonus=Number(before.bonusBalance)||0;
  for(let i=0;i<10;i++){
   const order=await create(49);assert.equal(order.success,true);assert.equal((await call(driverIndex,'acceptOrder',{orderDocPath:order.orderDocPath})).accepted,true);
   await call(driverIndex,'updateUserPreferences',{coords:{latitude:53.53,longitude:76.68,accuracy:10}});
   for(const nextStatus of [3,4,5])assert.equal((await call(driverIndex,'advanceDriverOrderStatus',{orderDocPath:order.orderDocPath,nextStatus})).success,true);
  }
  const after=user(await readStoreAsync(),driverIndex);assert.equal(after.bonusBalance,initialBonus-500+1000);assert.equal(after.bonusCompletedOrders,10);assert.equal(after.bonusAwarded,true);
  const state=await readStoreAsync();assert.equal(state.ledger.filter(l=>l.type==='daily_driver_bonus'&&l.userId===after.id).length,1);
  return {completed:10,dailyAwards:1,bonusBefore:initialBonus,bonusAfter:after.bonusBalance,commissionTotal:500,reward:1000};
 });
 console.log(JSON.stringify({passed:results.filter(x=>x.status==='passed').length,failed:results.filter(x=>x.status==='failed').length,results:output}));process.exit(results.some(x=>x.status==='failed')?1:0);
})().catch(e=>{console.error(e.message);process.exit(1);});
