const {readStoreAsync,withStoreAsync}=require('./store');
const {createPushNotificationInStore}=require('./push');
function access(store,data,auth){
  if(!auth?.user||auth.user.blocked)return {success:false,code:'UNAUTHENTICATED',error:'Войдите в приложение'};
  const id=String(data.orderDocPath||data.orderId||'').split('/').pop();
  const o=store.orders.find(o=>o.id===id);
  if(!o||![o.userId,o.driverId].includes(auth.user.id))return {success:false,code:'TRIP_CHAT_FORBIDDEN',error:'Чат доступен только участникам поездки'};
  if(!o.driverId||![2,3,4].includes(Number(o.status)))return {success:false,code:'TRIP_CHAT_CLOSED',error:'Чат доступен только во время активной поездки'};
  return {order:o};
}
function messages(store,o){return (store.notifications||[]).filter(n=>n.type==='TRIP_CHAT_MESSAGE'&&n.dataPayload?.orderId===o.id);}
async function listTripChatAsync(data={},auth){const store=await readStoreAsync();const a=access(store,data,auth);if(a.success===false)return a;
 return {success:true,messages:messages(store,a.order).sort((a,b)=>Date.parse(a.createdAt)-Date.parse(b.createdAt)).slice(-100).map(n=>({id:n.id,text:n.body,mine:n.dataPayload.senderId===auth.user.id,createdAt:n.createdAt}))};}
async function sendTripChatAsync(data={},auth){return withStoreAsync(store=>{
 const a=access(store,data,auth);if(a.success===false)return a;const o=a.order;
 const text=String(data.text||'').trim(),key=String(data.requestId||'');
 if(!text||text.length>1000)return {success:false,code:'TRIP_CHAT_TEXT_INVALID',error:'Введите сообщение до 1000 символов'};
 if(!/^[a-zA-Z0-9-]{16,100}$/.test(key))return {success:false,code:'TRIP_CHAT_REQUEST_INVALID',error:'Повторите отправку сообщения'};
 const dedupeKey=`trip-chat:${o.id}:${auth.user.id}:${key}`;
 const previous=(store.notifications||[]).find(n=>n.dedupeKey===dedupeKey);
 if(previous)return previous.body===text?{success:true,reused:true,messageId:previous.id}:{success:false,code:'TRIP_CHAT_CONFLICT',error:'Сообщение изменилось. Повторите отправку'};
 if(messages(store,o).filter(n=>n.dataPayload.senderId===auth.user.id&&Date.now()-Date.parse(n.createdAt)<10000).length>=5)return {success:false,code:'TRIP_CHAT_RATE_LIMIT',error:'Подождите несколько секунд перед следующим сообщением'};
 const driverRecipient=auth.user.id===o.userId,recipient=driverRecipient?o.driverId:o.userId;
 const queued=createPushNotificationInStore(store,{type:'TRIP_CHAT_MESSAGE',title:driverRecipient?'Сообщение от пассажира':'Сообщение от водителя',body:text,targetUserIds:[recipient],targetRole:driverRecipient?'driver':'passenger',
 initialPageName:driverRecipient?'homeDriverOrder':'seachDriver',dedupeKey,
 dataPayload:{type:'TRIP_CHAT_MESSAGE',orderId:o.id,orderDocPath:`order/${o.id}`,senderId:auth.user.id,targetRole:driverRecipient?'driver':'passenger',initialPageName:driverRecipient?'homeDriverOrder':'seachDriver'}} ,auth);
 if(queued.notification)queued.notification.dataPayload.notificationId=queued.notificationId;
 return {success:true,messageId:queued.notificationId};
 });}
module.exports={listTripChatAsync,sendTripChatAsync};
