const fs = require('node:fs');
const { performance, monitorEventLoopDelay } = require('node:perf_hooks');
const { guard } = require('./guard');
guard();
// Strict test adapters: no map, bank, SMS or FCM network calls may leave this process.
global.fetch = async input => {
  const url = String(input);
  if (url.includes('router.project-osrm.org')) return new Response(JSON.stringify({code:'Ok',routes:[{distance:1200,duration:240,geometry:{type:'LineString',coordinates:[[76.68,53.53],[76.69,53.54]]},legs:[]}]}));
  if (url.includes('nominatim.openstreetmap.org')) {
    const parsed=new URL(url),reverse=url.includes('/reverse');
    const second=reverse?Number(parsed.searchParams.get('lat'))>53.535:/10|20/.test(parsed.searchParams.get('q')||'');
    const result={place_id:second?'20':'10',lat:second?'53.54':'53.53',lon:second?'76.69':'76.68',display_name:'Synthetic audit address',address:{road:'Тестовая',house_number:second?'10':'1',village:'Железинка'}};
    return new Response(JSON.stringify(reverse?result:[result]));
  }
  throw new Error('AUDIT_EXTERNAL_NETWORK_DISABLED');
};
const root = process.env.MTAXI_AUDIT_SOURCE || require('node:path').resolve(__dirname, '..');
const { startServer } = require(root + '/src/index');
const runtime = startServer();
const delay = monitorEventLoopDelay(); delay.enable();
let previous = process.cpuUsage(), at = performance.now();
const timer = setInterval(() => {
  const now = performance.now(), current = process.cpuUsage();
  const data = {at:new Date().toISOString(),pid:process.pid,cpuPercent:((current.user-previous.user)+(current.system-previous.system))/(now-at)/10,rss:process.memoryUsage().rss,eventLoopP95Ms:delay.percentile(95)/1e6};
  fs.appendFileSync(process.env.MTAXI_AUDIT_METRICS,JSON.stringify(data)+'\n');
  previous=current;at=now;delay.reset();
},5000); timer.unref();
process.on('SIGTERM', () => {runtime.scheduler?.stop();runtime.server.close(()=>process.exit(0));});
