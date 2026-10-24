const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mtaxi-private-media-'));
process.env.MTAXI_STORE='json';process.env.MTAXI_DATA_DIR=dir;process.env.MTAXI_UPLOAD_DIR=path.join(dir,'uploads');process.env.MTAXI_FCM_ENABLED='false';
const {withStoreAsync}=require('../src/store');
const {setUserPassword}=require('../src/passwords');
const {passwordLogin}=require('../src/auth');
const {startServer}=require('../src/index');
test('uploaded documents require owner or admin authentication over HTTP', async()=>{
 const users=['owner','other','admin'].map((id,i)=>{const u={id,phone:'+70000000'+(100+i),role:id==='admin'?'admin':'user'};setUserPassword(u,'SyntheticAudit2026!');return u;});
 await withStoreAsync(s=>{s.users=users;});
 const tokens={};for(const u of users)tokens[u.id]=(await passwordLogin({phone:u.phone,password:'SyntheticAudit2026!'})).token;
 const runtime=startServer({port:0,scheduler:{stop(){}}});await new Promise(r=>runtime.server.on('listening',r));
 const base='http://127.0.0.1:'+runtime.server.address().port;
 const call=async(name,data,token)=>{const r=await fetch(base+'/call/'+name,{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+token},body:JSON.stringify(data)});return r.json();};
 try{
  const image=Buffer.from('89504e470d0a1a0a','hex');
  const uploaded=await call('uploadFile',{path:'driver/doc.png',contentType:'image/png',base64:image.toString('base64')},tokens.owner);
  assert.equal(uploaded.success,true);
  const target=base+new URL(uploaded.url).pathname;
  assert.equal((await fetch(target)).status,401,'Anonymous document download must be denied');
  assert.equal((await fetch(target,{headers:{authorization:'Bearer '+tokens.other}})).status,403,'Other account must not read the document');
  for(const who of ['owner','admin']){
   const result=await call('downloadFile',{url:uploaded.url},tokens[who]);assert.equal(result.success,true);assert.equal(result.base64,image.toString('base64'));
  }
  assert.equal((await call('downloadFile',{url:uploaded.url},tokens.other)).success,false);
  assert.equal((await call('downloadFile',{url:base+'/uploads/../secret.env'},tokens.owner)).success,false);
  assert.notEqual((await fetch(target+'.owner.json',{headers:{authorization:'Bearer '+tokens.owner}})).status,200);
 }finally{await new Promise(r=>runtime.server.close(r));fs.rmSync(dir,{recursive:true,force:true});}
});
