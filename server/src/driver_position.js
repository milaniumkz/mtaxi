const {meters}=require('./trip_automation');
// Keep the last trustworthy point; do not publish every fused/network fix.
function acceptDriverPosition(driver,sample,now=Date.now()){
 const accuracy=Number(sample.accuracy),measured=sample.timestamp==null?now:Date.parse(sample.timestamp);
 if(!Number.isFinite(accuracy)||accuracy<=0||accuracy>65||!Number.isFinite(measured)||now-measured>30000||measured-now>10000)return false;
 if(driver.coordsSampleAt&&measured<=Date.parse(driver.coordsSampleAt))return false;
 const previous=driver.coords,at=Date.parse(driver.coordsUpdatedAt||'');
 if(previous&&Number.isFinite(at)){
  const seconds=Math.max(0,(now-at)/1000),distance=meters(previous,sample);
  if(distance>Math.max(80,seconds*55+accuracy)){
   const candidate=driver.coordsCandidate;
   if(!candidate||meters(candidate,sample)>50||now-candidate.at>20000)driver.coordsCandidate={...sample,since:now,at:now,count:1};
   else driver.coordsCandidate={...sample,since:candidate.since,at:now,count:candidate.count+1};
   if(driver.coordsCandidate.count<3||now-driver.coordsCandidate.since<6000)return false;
  }else if(distance<Math.min(15,Math.max(4,accuracy/2))){sample={...sample,latitude:previous.latitude,longitude:previous.longitude};}
 }
 delete driver.coordsCandidate;
 driver.coords={latitude:sample.latitude,longitude:sample.longitude};driver.coordsAccuracy=accuracy;
 driver.coordsUpdatedAt=new Date(now).toISOString();driver.coordsSampleAt=new Date(measured).toISOString();
 return true;
}
module.exports={acceptDriverPosition};
