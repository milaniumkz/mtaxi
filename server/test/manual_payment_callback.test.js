const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'mtaxi-payment-audit-'));
process.env.MTAXI_STORE='json';process.env.MTAXI_DATA_DIR=dir;process.env.MTAXI_PAYMENT_PROVIDER='kaspi_manual';process.env.MTAXI_FCM_ENABLED='false';process.env.MTAXI_PAYMENT_CALLBACK_SECRET='synthetic-callback-fixture';
const {withStoreAsync,readStoreAsync}=require('../src/store');
const {createDriverTopUpPaymentAsync,handleDriverTopUpPaymentCallbackAsync,confirmDriverTopUpPaymentAsync}=require('../src/payments');
test('manual Kaspi request cannot be credited by a bank callback',async()=>{
 const driver={id:'audit-driver',phone:'+70010000999',isDriver:true,balance:1000},admin={id:'audit-admin',role:'admin'};
 await withStoreAsync(s=>{s.users=[driver,admin];s.payments=[];s.ledger=[];});
 const request=await createDriverTopUpPaymentAsync({amount:3000,kaspiPhone:driver.phone},{user:driver});assert.equal(request.success,true);
 const result=await handleDriverTopUpPaymentCallbackAsync({paymentId:request.paymentId,status:'paid',amount:1,currency:'USD'},{get:name=>name.toLowerCase()==='x-mtaxi-payment-secret'?'synthetic-callback-fixture':''});
 assert.equal(result.success,false,'Manual payments require explicit administrator confirmation');
 assert.equal((await readStoreAsync()).users.find(u=>u.id===driver.id).balance,1000);
 const paid=await confirmDriverTopUpPaymentAsync({paymentId:request.paymentId},{user:admin});assert.equal(paid.success,true);
 assert.equal((await readStoreAsync()).users.find(u=>u.id===driver.id).balance,4000);
 fs.rmSync(dir,{recursive:true,force:true});
});
test('callback rejects mismatched amount, currency and user before crediting',async()=>{
 process.env.MTAXI_PAYMENT_PROVIDER='local';
 const driver={id:'audit-driver-2',phone:'+70010000888',isDriver:true,balance:1000};
 await withStoreAsync(s=>{s.users=[driver];s.payments=[];s.ledger=[];});
 const request=await createDriverTopUpPaymentAsync({amount:3000},{user:driver});assert.equal(request.success,true);
 const headers={get:name=>name.toLowerCase()==='x-mtaxi-payment-secret'?'synthetic-callback-fixture':''};
 for(const [extra,code] of [[{amount:1},'PAYMENT_AMOUNT_MISMATCH'],[{currency:'USD'},'PAYMENT_CURRENCY_MISMATCH'],[{userId:'other'},'PAYMENT_USER_MISMATCH']]){
  const result=await handleDriverTopUpPaymentCallbackAsync({paymentId:request.paymentId,status:'paid',...extra},headers);assert.equal(result.code,code);
  assert.equal((await readStoreAsync()).users[0].balance,1000);
 }
 for(let i=0;i<2;i++){const result=await handleDriverTopUpPaymentCallbackAsync({paymentId:request.paymentId,status:'paid',amount:3000,currency:'KZT',userId:driver.id},headers);assert.equal(result.success,true);}
 assert.equal((await readStoreAsync()).users[0].balance,4000);
 fs.rmSync(dir,{recursive:true,force:true});
});
