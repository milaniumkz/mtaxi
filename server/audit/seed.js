const fs = require('node:fs');
const crypto = require('node:crypto');
const { guard } = require('./guard');
guard();
const { withStoreAsync } = require('../src/store');
const { setUserPassword } = require('../src/passwords');
function createAccessToken(user) {
  const header = Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
  const payload = Buffer.from(JSON.stringify({sub:user.id,phone:user.phone,pv:'',exp:Math.floor(Date.now()/1000)+86400})).toString('base64url');
  const value = `${header}.${payload}`;
  return `${value}.${crypto.createHmac('sha256',process.env.MTAXI_TOKEN_SECRET).update(value).digest('base64url')}`;
}
const { configureLaunchDefaultsInStore } = require('../scripts/configure_launch_defaults');
(async () => {
  const password = 'SyntheticAudit2026!';
  const template = {}; setUserPassword(template, password);
  const actors = [];
  let p = 0, d = 0, a = 0;
  for (let i = 0; i < 1000; i++) {
    const role = i % 100 === 0 ? 'admin' : (i % 100 <= 39 ? 'driver' : 'passenger');
    const user = { id: `audit_${i}`, phone: `+7001${String(i).padStart(7,'0')}`,
      displayName: `Synthetic ${role} ${i}`, city: 'Железинка', passwordHash: template.passwordHash,
      roleState: role === 'admin' ? 'ADMIN' : role === 'driver' ? 'DRIVER_ONLINE' : 'PASSENGER',
      activeMode: role === 'driver' ? 'driver' : 'passenger',
      preferredClientMode: role === 'driver' ? 'driver' : 'passenger',
      isDriver: role === 'driver', role: role === 'admin' ? 'admin' : 'user',
      isAdmin: role === 'admin', statusDriver: role === 'driver' ? 'approved' : '',
      driverOnLine: role === 'driver', balance: 1000000, bonusBalance: role === 'driver' ? 1000 : 0,
      passengerBonusBalance: role === 'passenger' ? 1000 : 0,
      createdAt: new Date().toISOString() };
    actors.push({ ...user, token: createAccessToken(user) });
    if (role === 'passenger') p++; else if (role === 'driver') d++; else a++;
  }
  await withStoreAsync(s => {
    for (const key of ['orders','payments','withdrawals','ledger','chats','chatMessages','fcmTokens','notifications','notificationDeliveries','pushDeliveryAcks','auditLogs','smsCodes']) s[key] = [];
    s.users = actors.map(({ token, ...user }) => user);
    s.settings = {}; s.cityPrices = []; s.genericCollections = {};
    configureLaunchDefaultsInStore(s);
  });
  fs.writeFileSync(process.env.MTAXI_AUDIT_ACTORS, JSON.stringify(actors), { mode: 0o600 });
  console.log(JSON.stringify({ seeded: actors.length, passengers:p, drivers:d, admins:a }));
  process.exit(0);
})().catch(e => { console.error(e.message); process.exit(1); });
