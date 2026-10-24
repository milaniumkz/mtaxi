const test=require('node:test');const assert=require('node:assert/strict');
const {recipientOrderNotification,onlineDriver}=require('../src/driver_order_alerts');
const now=Date.now();
function sample(latitude=53.538){return {users:[{id:'d',isDriver:true,statusDriver:'approved',driverOnLine:true,coords:{latitude,longitude:75.313},coordsAccuracy:10,coordsUpdatedAt:new Date(now).toISOString()}],orders:[{id:'o',status:0,price:500,ot:'Посадка',kuda:'Назначение',fromPoint:{latitude:53.538,longitude:75.313}}]};}
const n={targetRole:'driver',type:'ORDER_CREATED',orderId:'o',dataPayload:{type:'ORDER_AVAILABLE',sentAtMs:String(now)}};
const token={userId:'d',deviceType:'Android',supportsOrderOverlay:true};
test('only a fresh accurate driver within 1 km gets an Android data overlay',()=>{
 const store=sample();const r=recipientOrderNotification(store,n,token,now);
 assert.equal(r.dataPayload.overlayEligible,'true');assert.equal(r.deliveryPriority,'high');assert.equal(r.androidDataOnly,true);assert.equal(r.dataPayload.driverUserId,'d');assert.equal(r.dataPayload.orderPrice,'500');
 const far=recipientOrderNotification(sample(53.55),n,token,now);assert.equal(far.dataPayload.overlayEligible,'false');assert.equal(far.deliveryPriority,'normal');assert.equal(far.androidDataOnly,false);
});
test('stale, inaccurate or uncertain boundary positions never trigger an overlay',()=>{
 for(const patch of [{coordsUpdatedAt:new Date(now-31000).toISOString()},{coordsAccuracy:150},{coords:null},{coordsUpdatedAt:'invalid'}]){
  const store=sample();Object.assign(store.users[0],patch);assert.equal(recipientOrderNotification(store,n,token,now).dataPayload.overlayEligible,'false');
 }
 // Around 990 metres away, 30m accuracy could put the car outside the radius.
 const store=sample(53.5469);store.users[0].coordsAccuracy=30;assert.equal(recipientOrderNotification(store,n,token,now).dataPayload.overlayEligible,'false');
});
test('offline, unapproved, busy drivers and already assigned orders are rejected',()=>{
 for(const patch of [{driverOnLine:false},{statusDriver:'pending'},{blocked:true},{hasActiveDriverOrder:true}]){const store=sample();Object.assign(store.users[0],patch);assert.equal(onlineDriver(store.users[0]),false);assert.equal(recipientOrderNotification(store,n,token,now),null);}
 const store=sample();store.orders[0].status=2;assert.equal(recipientOrderNotification(store,n,token,now),null);
});
test('old Android clients and other platforms keep normal FCM presentation',()=>{
 assert.equal(recipientOrderNotification(sample(),n,{...token,supportsOrderOverlay:false},now).androidDataOnly,false);
 assert.equal(recipientOrderNotification(sample(),n,{...token,deviceType:'iOS'},now).androidDataOnly,false);
});
