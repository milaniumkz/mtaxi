const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {reconcile} = require('../scripts/reconcile_upload_owners');
test('legacy upload reconciliation only assigns unambiguous references and never replaces ownership', async () => {
 const directory = await fs.mkdtemp(path.join(os.tmpdir(),'mtaxi-owners-'));
 const names = ['1_abc.jpg','2_abc.png','3_abc.pdf','4_abc.jpg','5_abc.jpg'];
 try {
  for (const name of names) await fs.writeFile(path.join(directory,name),'test');
  await fs.writeFile(path.join(directory,names[3]+'.owner.json'),JSON.stringify({ownerId:'original'}));
  const url = i => '/uploads/'+names[i];
  const store={users:[{id:'a',photoUrl:url(0),avtoImage:url(1),techImage:url(3)},{id:'b',photoUrl:url(1)}],chatMessages:[{userId:'c',imageUrl:url(4)}]};
  assert.deepEqual(await reconcile({store,directory}),{created:2,existing:1,ambiguous:1,unreferenced:1});
  assert.equal(JSON.parse(await fs.readFile(path.join(directory,names[0]+'.owner.json'))).ownerId,'a');
  assert.equal(JSON.parse(await fs.readFile(path.join(directory,names[4]+'.owner.json'))).ownerId,'c');
  assert.equal(JSON.parse(await fs.readFile(path.join(directory,names[3]+'.owner.json'))).ownerId,'original');
  assert.equal((await fs.stat(path.join(directory,names[0]+'.owner.json'))).mode & 0o777,0o600);
  assert.deepEqual(await reconcile({store,directory}),{created:0,existing:3,ambiguous:1,unreferenced:1});
 } finally {await fs.rm(directory,{recursive:true,force:true});}
});
