const test = require('node:test');
const assert = require('node:assert/strict');
const {acceptDriverPosition} = require('../src/driver_position');
const {observeDriverPosition} = require('../src/trip_automation');
test('twenty outlier/stale sequences preserve the last trustworthy position', () => {
  for(let i=0;i<20;i++) {
    const t=1700000000000+i*100000;
    const d={};const base={latitude:52.3,longitude:76.9,accuracy:10};
    assert.equal(acceptDriverPosition(d,base,t),true);
    assert.equal(acceptDriverPosition(d,{...base,latitude:53,accuracy:10},t+1000),false);
    assert.equal(acceptDriverPosition(d,{...base,accuracy:500},t+2000),false);
    assert.equal(acceptDriverPosition(d,{...base,timestamp:new Date(t-31000).toISOString()},t+3000),false);
    assert.deepEqual(d.coords,{latitude:52.3,longitude:76.9});
    assert.equal(d.coordsUpdatedAt,new Date(t).toISOString());
  }
});
test('server automation settings change delays without a new client', () => {
 const now=1700000000000;const sample={latitude:52.3,longitude:76.9,accuracy:10};
 const o={id:'o',driverId:'d',status:2,fromPoint:sample};
 const store={orders:[o],settings:{autoArrivalDelaySec:5}};
 const d={id:'d',activeDriverOrderId:'o'};const actions=[];
 const advance=status=>{actions.push(status);o.status=status;return {success:true}};
 observeDriverPosition(store,d,sample,advance,now);
 observeDriverPosition(store,d,sample,advance,now+4000);assert.deepEqual(actions,[]);
 observeDriverPosition(store,d,sample,advance,now+5000);assert.deepEqual(actions,[3]);
});
