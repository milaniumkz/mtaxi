// Explicit deployment migration. Only unambiguous database references establish ownership.
const fs = require('fs/promises');
const path = require('path');
const {readStoreAsync} = require('../src/store');
const {mediaFilename, uploadDir} = require('../src/media');
async function reconcile({store, directory = uploadDir}) {
  const refs = new Map();
  function add(url, owner) {
    const name = mediaFilename(url);
    if (!name || !owner) return;
    if (!refs.has(name)) refs.set(name, new Set());
    refs.get(name).add(owner);
  }
  for (const u of store.users) for (const key of ['photoUrl','avtoImage','techImage']) add(u[key], u.id);
  for (const m of store.chatMessages) add(m.imageUrl, m.userId);
  const counts = {created:0, existing:0, ambiguous:0, unreferenced:0};
  for (const name of await fs.readdir(directory)) {
    if (!mediaFilename('/uploads/' + name)) continue;
    try { await fs.access(path.join(directory, name + '.owner.json')); counts.existing++; continue; }
    catch (e) { if (e.code !== 'ENOENT') throw e; }
    const owners = refs.get(name);
    if (!owners) { counts.unreferenced++; continue; }
    if (owners.size !== 1) { counts.ambiguous++; continue; }
    await fs.writeFile(path.join(directory, name + '.owner.json'), JSON.stringify({ownerId:[...owners][0]}), {mode:0o600,flag:'wx'});
    counts.created++;
  }
  return counts;
}
module.exports = {reconcile};
if (require.main === module) readStoreAsync().then(store => reconcile({store})).then(counts => {
  console.log('Upload ownership reconciliation:', JSON.stringify(counts)); process.exit(0);
}).catch(() => {console.error('Upload ownership reconciliation failed'); process.exit(1);});
