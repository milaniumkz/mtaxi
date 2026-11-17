const test = require('node:test');
const assert = require('node:assert/strict');
const {routeLookup,forwardGeocodeLookup} = require('../src/geocoding');
test('twenty route responses cannot replace a long journey with a short route in another place', async () => {
 const original=global.fetch;
 try {
  for(let i=0;i<20;i++){
   global.fetch=async()=>({ok:true,json:async()=>({routes:[{distance:300,duration:60,geometry:{coordinates:[[76.9,52.3],[76.901,52.301]]}}]})});
   const response=await routeLookup({fromLat:52.3,fromLng:76.9,toLat:52.5,toLng:77.1});
   assert.equal(response.success,false);assert.equal(response.code,'ROUTE_ENDPOINT_MISMATCH');
  }
  assert.equal((await routeLookup({fromLat:null,fromLng:76.9,toLat:52.5,toLng:77.1})).code,'COORDS_REQUIRED');
 } finally {global.fetch=original;}
});
test('a Jetekshi address never resolves to the same street in Pavlodar', async () => {
 const original=global.fetch;
 try {
  global.fetch=async()=>({ok:true,json:async()=>[
   {lat:'52.3',lon:'76.9',address:{city:'Павлодар',road:'Ауэзова',house_number:'8'}},
   {lat:'52.4',lon:'76.8',display_name:'Ауэзова, 8, Жетекші',address:{village:'Жетекші',road:'Ауэзова',house_number:'8'}}
  ]});
  const r=await forwardGeocodeLookup({query:'Жетекши Ауэзова 8',city:'Жетекши'});
  assert.equal(r.success,true);assert.equal(r.lat,52.4);
  global.fetch=async()=>({ok:true,json:async()=>[{lat:'52.3',lon:'76.9',address:{city:'Павлодар'}}]});
  assert.equal((await forwardGeocodeLookup({query:'Жетекши Ауэзова 30',city:'Жетекши'})).code,'ADDRESS_NOT_FOUND');
 } finally {global.fetch=original;}
});
