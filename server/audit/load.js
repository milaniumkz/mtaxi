// Standalone Node VU generator: each VU has its own real bearer session and
// sequential actions with think times. No external providers are contacted.
const fs = require('node:fs');
const { performance, monitorEventLoopDelay } = require('node:perf_hooks');
const base = process.env.MTAXI_AUDIT_BASE || 'http://127.0.0.1:18080';
const url = new URL(base);
if (url.protocol !== 'http:' || !['127.0.0.1','localhost'].includes(url.hostname) || !['18080','18081','18083','18085'].includes(url.port)) throw Error('Local audit target required');
const actors = JSON.parse(fs.readFileSync(process.env.MTAXI_AUDIT_ACTORS));
if (actors.length !== 1000 || actors.some(x=>!x.id.startsWith('audit_'))) throw Error('Synthetic actors required');
const output = process.env.MTAXI_AUDIT_RESULT || 'load-results.json';
const diagnostic = process.argv.includes('--diagnostic');
require('./guard').guard();
const plan = diagnostic ? [{name:'diagnostic-50',vus:50,seconds:60}] : [
 {name:'smoke',vus:5,seconds:120}, ...[50,100,250,500,1000].map(vus=>({name:`stage-${vus}`,vus,seconds:180})),
 {name:'hold-1000',vus:1000,seconds:900},{name:'downshift',vus:100,seconds:30},
 {name:'spike-ramp',vus:1000,seconds:10,ramp:true},{name:'spike-hold',vus:1000,seconds:120},{name:'recovery',vus:5,seconds:120}];
const expected = new Set(['ORDER_ALREADY_EXISTS','ORDER_NOT_AVAILABLE','OFFER_FORBIDDEN','OFFER_TOO_FREQUENT','OFFER_EXPIRED','DRIVER_HAS_ACTIVE_ORDER','ORDER_ALREADY_ACCEPTED','ORDER_ALREADY_COMPLETED','ORDER_STATUS_SEQUENCE_REQUIRED','ORDER_STATUS_INVALID','ORDER_STATUS_UNCHANGED','ORDER_NOT_OPEN','ORDER_NOT_FOUND','ORDER_PRICE_CHANGED','DRIVER_UNAVAILABLE','ORDER_ALREADY_TAKEN','DRIVER_BUSY','OFFER_LIMIT']);
const hist = new Map(), stages=[], events=[], propagation=[], positions=[];
const mutations = new Map(), delivery = [], locationAge = [];
let stop=false,abortReason=null,target=0,live=0,maxLive=0,inflight=0,maxInflight=0,stageName='',requests=0,unexpected=0,business=0,completed=0;
const startedAt=new Date().toISOString();
const started=performance.now(); const sleeper=ms=>new Promise(r=>setTimeout(r,ms));
function record(name,ms,bad,code) {
 let h=hist.get(name);if(!h)hist.set(name,h={count:0,errors:0,business:0,bins:{},codes:{}});
 h.count++;h.errors+=bad?1:0;h.business+=expected.has(code)?1:0;h.codes[code]=(h.codes[code]||0)+1;
 const bucket=Math.ceil(ms);h.bins[bucket]=(h.bins[bucket]||0)+1;
 events.push({at:Date.now(),bad});while(events.length&&events[0].at<Date.now()-60000)events.shift();
 requests++;unexpected+=bad?1:0;business+=expected.has(code)?1:0;
}
async function call(actor,name,data={}) {
 const begin=performance.now();inflight++;maxInflight=Math.max(maxInflight,inflight);
 try {
  const r=await fetch(base+'/call/'+name,{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+actor.token},body:JSON.stringify(data),signal:AbortSignal.timeout(12000)});
  const body=await r.json();const code=body.code|| (body.success?'OK':'UNKNOWN');
   record(name,performance.now()-begin,!r.ok||(!body.success&&!expected.has(code)),code);
   const ref = data.orderDocPath || body.orderDocPath;
   if (body.success && ref && ['respondOrderOffer','acceptOrder','advanceDriverOrderStatus'].includes(name)) mutations.set(ref, {at:performance.now(),status:name==='advanceDriverOrderStatus'?data.nextStatus:2,actor:actor.id});
   if (body.success && name==='getSessionBootstrap') {
     for (const [ref,status] of [[body.activePassengerOrderRef,body.activePassengerOrderStatus],[body.activeDriverOrderRef,body.activeDriverOrderStatus]]) {
       const event=mutations.get(ref);
       if (event && event.actor!==actor.id && Number(status)===event.status) {delivery.push(performance.now()-event.at);mutations.delete(ref);}
     }
   }
   if(body.success&&name==='getTripTracking'&&body.driverPosition&&body.positionUpdatedAt)locationAge.push(Math.max(0,Date.now()-Date.parse(body.positionUpdatedAt)));
  return body;
 } catch(e) {record(name,performance.now()-begin,true,e.name);return {success:false,code:e.name};}
 finally{inflight--;}
}
// Interleave roles so even small stages contain all three roles. Full population
// remains exactly 600 passengers / 390 drivers / 10 administrators.
const groups={admin:actors.filter(x=>x.role==='admin'),driver:actors.filter(x=>x.isDriver),passenger:actors.filter(x=>!x.isDriver&&x.role!=='admin')};
const ordered=[];for(let i=0;i<600;i++){if(i%60===0)ordered.push(groups.admin.shift());ordered.push(groups.passenger.shift());if(i<390)ordered.push(groups.driver.shift());}
async function vu(actor,index) {
 live++;maxLive=Math.max(maxLive,live);let ticks=0,assignmentAt=0,phaseStatus=-1,phaseSince=0,lastGps=0;
 try {while(!stop&&index<target){
  const session=await call(actor,'getSessionBootstrap');ticks++;
  if(!diagnostic&&session.success){
   if(actor.role==='admin') {await call(actor,ticks%2?'adminListOrders':'getMoneyStats',{limit:30});}
   else if(actor.isDriver){
    const ref=session.activeDriverOrderRef;
    if(ref){
     const order=session.activeDriverOrder;const status=Number(order?.status??session.activeDriverOrderStatus);
     if(phaseStatus!==status){phaseStatus=status;phaseSince=Date.now();}
     if(assignmentAt){propagation.push(performance.now()-assignmentAt);assignmentAt=0;}
     if(Date.now()-lastGps>=3000){await call(actor,'updateUserPreferences',{coords:{latitude:53.53,longitude:76.68,accuracy:10}});lastGps=Date.now();}
     const dwell={2:30000,3:15000,4:90000}[status];
     if(status>=2&&status<5&&Date.now()-phaseSince>=dwell){const r=await call(actor,'advanceDriverOrderStatus',{orderDocPath:ref,nextStatus:status+1});if(r.success&&status===4)completed++;}
    }else{
     const feed=await call(actor,'listAvailableDriverOrders',{limit:30});const list=feed.orders||[];
     const order=list[index%Math.max(1,list.length)];
     if(order){const ref=order.orderDocPath||'order/'+order.id;
      if(Number(actor.id.split('_')[1])%2){const result=await call(actor,'submitOrderOffer',{orderDocPath:ref,price:Number(order.price)+100});if(result.success)assignmentAt=performance.now();}
      else await call(actor,'acceptOrder',{orderDocPath:ref});
     }
    }
   }else{
    const ref=session.activePassengerOrderRef;
    if(!ref){await call(actor,'createPassengerOrder',{type:'taxi',city:'Железинка',ot:'Тестовая 1',kuda:'Тестовая 10',fromPoint:{latitude:53.53,longitude:76.68},toPoint:{latitude:53.54,longitude:76.69},price:500,paymentMode:index%3?'wallet':'cash',usePassengerBonuses:true});}
    else if(Number(session.activePassengerOrderStatus)===0){const offers=await call(actor,'listOrderOffers',{orderDocPath:ref});if(offers.offers?.length)await call(actor,'respondOrderOffer',{orderDocPath:ref,offerId:offers.offers[0].id,accept:true});}
    else{const at=performance.now();await call(actor,'getTripTracking',{orderDocPath:ref});positions.push(performance.now()-at);}
    if(ticks%15===0)await call(actor,'listMyOrders',{limit:10});
   }
  }
  await sleeper(diagnostic?2000:2000+(index%5)*150);
 }}finally{live--;}
}
const running=new Map();
function setTarget(n){target=n;for(let i=0;i<n;i++)if(!running.has(i)){const task=vu(ordered[i],i).finally(()=>running.delete(i));running.set(i,task);}}
const loop=monitorEventLoopDelay();loop.enable();let cpu=process.cpuUsage(),sampleAt=performance.now();
function percentile(bins,q){const items=Object.entries(bins).map(([ms,n])=>[Number(ms),n]).sort((a,b)=>a[0]-b[0]);const total=items.reduce((s,x)=>s+x[1],0);let n=0;for(const [ms,count]of items){n+=count;if(n>=total*q)return ms;}return null;}
function distribution(values){if(!values.length)return {count:0,p50:null,p95:null,p99:null};const a=[...values].sort((a,b)=>a-b);return {count:a.length,p50:a[Math.floor((a.length-1)*.5)],p95:a[Math.floor((a.length-1)*.95)],p99:a[Math.floor((a.length-1)*.99)]};}
function snapshot(){return {startedAt,model:{passengers:600,drivers:390,admins:10,statusPollMs:2000,gpsMinIntervalMs:3000,tripDwellMs:{assigned:30000,arrived:15000,started:90000}},revision:process.env.MTAXI_AUDIT_REVISION||null,diagnostic,plan,stages,aborted:!!abortReason,abortReason,maxLive,maxInflight,requests,unexpected,business,completedTrips:completed,durationSeconds:(performance.now()-started)/1000,operations:Object.fromEntries([...hist].map(([name,h])=>[name,{...h,bins:undefined,p50:percentile(h.bins,.5),p95:percentile(h.bins,.95),p99:percentile(h.bins,.99)}])),realtimeDelivery:distribution(delivery),gpsPositionAge:distribution(locationAge),notes:['Realtime transport is HTTP polling, not WebSocket','Delivery measures mutation response to first matching poll by another user; overwritten intermediate transitions are omitted','GPS position age includes polling interval; synthetic foreground coordinates only','JWT sessions are seeded; password login tested separately','Map/geocoding adapters synthetic; FCM/SMS disabled; manual Kaspi not sent']};}
const timer=setInterval(()=>{
 if(!stop)setTarget(target);
 const current=process.cpuUsage(),now=performance.now();const progress={at:new Date().toISOString(),stage:stageName,target,live,inflight,requests,unexpected,rss:process.memoryUsage().rss,cpuPercent:((current.user-cpu.user)+(current.system-cpu.system))/(now-sampleAt)/10,eventLoopP95Ms:loop.percentile(95)/1e6};
 fs.appendFileSync(output+'.progress.jsonl',JSON.stringify(progress)+'\n');cpu=current;sampleAt=now;loop.reset();
 if(!diagnostic&&events.length>20&&performance.now()-started>60000&&events.filter(x=>x.bad).length/events.length>.05){abortReason='Unexpected error rate exceeded 5% over the last minute';stop=true;}
 fs.writeFileSync(output,JSON.stringify(snapshot(),null,2));
},5000);
let db, checking=false;
const dbTimer=setInterval(async()=>{
 if(diagnostic||checking||!db)return;checking=true;
 try{
  const metrics=await db.query("SELECT numbackends,xact_commit,xact_rollback,blks_read,blks_hit,temp_bytes,deadlocks FROM pg_stat_database WHERE datname=current_database()");
  const locks=await db.query("SELECT count(*)::int AS waiting FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock'");
  const integrity=await db.query("SELECT (SELECT count(*) FROM users WHERE balance<0) AS negative_balances,(SELECT count(*) FROM (SELECT driver_id FROM orders WHERE status IN (2,3,4) AND driver_id IS NOT NULL GROUP BY driver_id HAVING count(*)>1) t) AS duplicate_assignments,(SELECT count(*) FROM (SELECT order_id,type,user_id FROM ledger WHERE order_id IS NOT NULL AND type IN ('passenger_trip_payment','order_commission','passenger_cashback') GROUP BY order_id,type,user_id HAVING count(*)>1) t) AS duplicate_money");
  fs.appendFileSync(output+'.database.jsonl',JSON.stringify({at:new Date().toISOString(),...metrics.rows[0],...locks.rows[0],...integrity.rows[0]})+'\n');
  if(Object.values(integrity.rows[0]).some(n=>Number(n)>0)){abortReason='Database integrity invariant violated';stop=true;}
 }catch(e){fs.appendFileSync(output+'.database.jsonl',JSON.stringify({error:e.message})+'\n');}
 finally{checking=false;}
},5000);
(async()=>{if(!diagnostic){db=new(require('pg').Client)({connectionString:process.env.DATABASE_URL});await db.connect();}
 for(const stage of plan){if(stop)break;stageName=stage.name;const begin=performance.now(),before={requests,unexpected,completed};
 if(stage.ramp){for(let n=190;n<=1000&&!stop;n+=90){setTarget(n);await sleeper(1000);}}
 else{setTarget(stage.vus);const end=performance.now()+stage.seconds*1000;while(performance.now()<end&&!stop)await sleeper(500);}
 stages.push({...stage,actualSeconds:(performance.now()-begin)/1000,requests:requests-before.requests,unexpected:unexpected-before.unexpected,completedTrips:completed-before.completed,maxLive});console.log(JSON.stringify(stages.at(-1)));
 }stop=true;await Promise.allSettled([...running.values()]);
 if(abortReason){stageName='recovery-after-abort';const at=performance.now(),before={requests,unexpected};while(performance.now()-at<120000){await Promise.all(ordered.slice(0,5).map(actor=>call(actor,'getSessionBootstrap')));await sleeper(2000);}stages.push({name:stageName,actualSeconds:(performance.now()-at)/1000,requests:requests-before.requests,unexpected:unexpected-before.unexpected});}
 clearInterval(timer);clearInterval(dbTimer);if(db)await db.end();fs.writeFileSync(output,JSON.stringify(snapshot(),null,2));console.log(JSON.stringify({finished:true,aborted:!!abortReason,maxLive,requests,unexpected,completed}));})().catch(e=>{clearInterval(timer);clearInterval(dbTimer);console.error(e);process.exit(1);});
