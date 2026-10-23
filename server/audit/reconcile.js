// Exact post-run balance reconciliation for the synthetic load fixture only.
const fs=require('node:fs');
require('./guard').guard();
const {Client}=require('pg');
const cents=v=>Math.round((Number(v)||0)*100);
(async()=>{
 const db=new Client({connectionString:process.env.DATABASE_URL});await db.connect();
 try{
  await db.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
  const users=(await db.query('SELECT id,balance,is_driver,data FROM users')).rows;
  if(users.length!==1000||users.some(u=>!/^audit_\d+$/.test(u.id)))throw Error('Only untouched1000-user synthetic load fixtures supported');
  const entries=(await db.query('SELECT id,user_id,order_id,type,amount,data FROM ledger')).rows;
  const orders=(await db.query('SELECT id,user_id,driver_id,status,data FROM orders')).rows;
  const byOrder=new Map(orders.map(o=>[o.id,o]));
  const expected=new Map(users.map(u=>[u.id,{cash:100000000,driverBonus:u.is_driver?100000:0,passengerBonus:u.is_driver||Number(u.id.split('_')[1])%100===0?0:100000}]));
  const supported=new Set(['order_commission','order_commission_refund','passenger_trip_reserve','passenger_trip_reprice_release','passenger_trip_refund','passenger_trip_payment','passenger_cashback','daily_driver_bonus']);
  const unknown=[];
  for(const e of entries){
   const u=expected.get(e.user_id),d=e.data||{},o=byOrder.get(e.order_id)?.data||{};
   if(!supported.has(e.type)||!u){unknown.push({id:e.id,type:e.type});continue;}
   if(e.type==='order_commission'){u.cash-=cents(d.cashAmount);u.driverBonus-=cents(d.bonusAmount);}
   if(e.type==='order_commission_refund'){u.cash+=cents(o.acceptedCashCommission);u.driverBonus+=cents(o.acceptedBonusCommission);}
   if(e.type==='passenger_trip_reserve'){u.cash-=cents(d.cashAmount);u.passengerBonus-=cents(d.bonusAmount);}
   if(e.type==='passenger_trip_reprice_release'){u.cash+=cents(d.cashAmount);u.passengerBonus+=cents(d.bonusAmount);}
   if(e.type==='passenger_trip_refund'){u.cash+=cents(o.passengerWalletUsed);u.passengerBonus+=cents(o.passengerBonusUsed);}
   if(e.type==='passenger_trip_payment')u.cash+=cents(e.amount);
   if(e.type==='passenger_cashback')u.passengerBonus+=cents(e.amount);
   if(e.type==='daily_driver_bonus')u.driverBonus+=cents(e.amount);
  }
  const mismatches=[];
  for(const u of users){const actual={cash:cents(u.balance),driverBonus:cents(u.data.bonusBalance),passengerBonus:cents(u.data.passengerBonusBalance)},want=expected.get(u.id);if(Object.keys(actual).some(k=>actual[k]!==want[k]))mismatches.push({id:u.id,actual,expected:want});}
  const integrity=(await db.query("SELECT (SELECT count(*) FROM users WHERE balance<0 OR COALESCE((data->>'bonusBalance')::numeric,0)<0 OR COALESCE((data->>'passengerBonusBalance')::numeric,0)<0) AS negative_wallets,(SELECT count(*) FROM (SELECT user_id,type,COALESCE(data->>'day','') FROM ledger WHERE type IN ('daily_driver_bonus','driver_welcome_bonus') GROUP BY user_id,type,COALESCE(data->>'day','') HAVING count(*)>1) d) AS duplicate_bonus_awards")).rows[0];
  await db.query('COMMIT');
  const result={at:new Date().toISOString(),users:users.length,ledgerEntries:entries.length,orders:orders.length,completedTrips:orders.filter(o=>o.status===5).length,unknownEntries:unknown,mismatches,integrity,passed:unknown.length===0&&mismatches.length===0&&Object.values(integrity).every(v=>Number(v)===0)};
  fs.writeFileSync(process.env.MTAXI_AUDIT_RECONCILIATION,JSON.stringify(result,null,2));
  console.log(JSON.stringify(result));if(!result.passed)process.exitCode=1;
 }finally{await db.end();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
