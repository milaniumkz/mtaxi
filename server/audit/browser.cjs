const {chromium}=require('/opt/codex/runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs');const readline=require('node:readline');
global.actors=JSON.parse(fs.readFileSync(process.env.MTAXI_AUDIT_ACTORS));
global.errors=[];global.apiTrace=[];global.external=[];global.base='http://127.0.0.1:18665';
global.png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=','base64');
global.browser=undefined;
(async()=>{
 browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
 global.open=async(role,path,width=390)=>{
  const actor=role==='admin'?actors[0]:role==='driver'?actors[1]:actors[40];
  const ctx=await browser.newContext({viewport:{width,height:844},permissions:['geolocation'],geolocation:{latitude:53.53,longitude:76.68,accuracy:10}});
  await ctx.route('https://**/*',async r=>{external.push(new URL(r.request().url()).origin);await r.fulfill({status:200,contentType:'image/png',body:png});});
  await ctx.addInitScript(({actor})=>{const {token,passwordHash,...user}=actor;localStorage.setItem('flutter.mtaxi_backend_access_token',JSON.stringify(token));localStorage.setItem('flutter.mtaxi_backend_user_json',JSON.stringify(JSON.stringify(user)));},{actor});
  const p=await ctx.newPage();p.on('pageerror',e=>errors.push({role,error:e.message}));
  p.on('response',async r=>{if(r.url().includes('/call/'))try{const b=await r.json();apiTrace.push({role,path:new URL(r.url()).pathname,status:r.status(),code:b.code,success:b.success});}catch{}});
  await p.goto(base+path,{waitUntil:'networkidle'});await p.locator('flutter-view').waitFor();await p.waitForTimeout(1500);
  await p.locator('flt-semantics-placeholder').evaluateAll(es=>es.forEach(e=>e.click()));await p.waitForTimeout(300);return p;
 };
 global.shot=async(p,name)=>{await p.screenshot({path:'/workspace/mtaxi/output/full-audit/'+name+'.png'});};
 global.text=async(p)=>p.locator('flt-semantics-host').innerText();
 global.call=async(index,name,data={})=>{const r=await fetch('http://127.0.0.1:18080/call/'+name,{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+actors[index].token},body:JSON.stringify(data)});return r.json();};
 global.p=await open('passenger','/homePage');global.d=await open('driver','/homeDriver');global.a=await open('admin','/admin',1440);
 console.log('READY '+JSON.stringify({passenger:p.url(),driver:d.url(),admin:a.url()}));
 let queue=Promise.resolve();readline.createInterface({input:process.stdin}).on('line',line=>{queue=queue.then(async()=>{try{const result=await eval('(async()=>{'+line+'})()');console.log(JSON.stringify({result}));}catch(e){console.log(JSON.stringify({error:e.message}));}});});
})();
