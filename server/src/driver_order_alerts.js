const {meters}=require('./trip_automation');
const NEW_ORDER_EVENTS=new Set(['ORDER_CREATED','ORDER_AVAILABLE']);
function newOrderNotification(n){return n.targetRole==='driver'&&NEW_ORDER_EVENTS.has(String(n.type||n.eventType||n.dataPayload?.type||'').toUpperCase());}
function onlineDriver(u){return u && u.isDriver===true && u.statusDriver==='approved' && !u.blocked && !u.hasActiveDriverOrder && (u.driverOnLine===true || u.roleState==='DRIVER_ONLINE');}
function recipientOrderNotification(store,notification,token,now=Date.now()){
 if(!newOrderNotification(notification))return notification;
 const driver=store.users.find(u=>u.id===token.userId);
 const order=store.orders.find(o=>o.id===notification.orderId);
 if(!onlineDriver(driver)||!order||Number(order.status)!==0)return null;
 const a=driver.coords,b=order.fromPoint;
 const age=now-Date.parse(driver.coordsUpdatedAt||'');
 const accuracy=Number(driver.coordsAccuracy);
 const valid=p=>p&&Number.isFinite(Number(p.latitude))&&Number.isFinite(Number(p.longitude));
 const distance=valid(a)&&valid(b)?meters(a,b):null;
 const near=distance!==null&&Number.isFinite(age)&&age>=-5000&&age<=30000&&accuracy>0&&accuracy<=100&&distance+accuracy<=1000;
 return {...notification,deliveryPriority:near?'high':'normal',androidDataOnly:near&&token.deviceType==='Android'&&token.supportsOrderOverlay===true,
  dataPayload:{...notification.dataPayload,type:'ORDER_AVAILABLE',driverUserId:driver.id,overlayEligible:String(near),distanceMeters:distance===null?'':String(Math.round(distance)),orderPrice:String(order.price),pickupAddress:order.ot||'',destinationAddress:order.kuda||'',pickupLat:String(b?.latitude??''),pickupLng:String(b?.longitude??''),offerLifetimeSeconds:'30'},
 };
}
module.exports={newOrderNotification,onlineDriver,recipientOrderNotification};
