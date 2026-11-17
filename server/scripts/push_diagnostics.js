// Read only, aggregate metadata. Never print credentials, tokens or user details.
const { readStoreAsync } = require(process.cwd() + '/src/store');
(async () => {
  const s = await readStoreAsync();
  const tokens = s.fcmTokens || [];
  const platforms = {};
  for (const platform of ['ios', 'android', 'web']) {
    const all = tokens.filter(t => String(t.deviceType).toLowerCase() === platform);
    const active = all.filter(t => !t.disabled);
    const ids = new Set(all.map(t => t.id));
    const deliveries = (s.notificationDeliveries || []).filter(d => ids.has(d.tokenId)).slice(-100);
    platforms[platform] = {
      active: active.length,
      withApns: active.filter(t => !!t.apnsToken).length,
      adminDevices: active.filter(t => s.users.some(u => u.id === t.userId && (u.isAdmin || u.role === 'admin'))).length,
      recentSent: deliveries.filter(d => d.status === 'sent').length,
      recentFailed: deliveries.filter(d => d.status === 'failed').length,
      failureKinds: [...new Set(deliveries.filter(d=>d.status==='failed').map(d => {
        const text = String(d.errorCode || '')+' '+String(d.error || '');
        return /third.party|apns|apple/i.test(text) ? 'APNS_AUTH_OR_CONFIGURATION' : /vapid/i.test(text) ? 'WEB_VAPID' : /not.registered|UNREGISTERED|NotRegistered/i.test(text) ? 'EXPIRED_TOKEN' : /credential|authentication|permission/i.test(text) ? 'CREDENTIALS' : 'OTHER';
      }))]
    };
  }
  console.log(JSON.stringify({fcmEnabled:process.env.MTAXI_FCM_ENABLED==='true',platforms}));
})().catch(()=>{console.error('Push metadata diagnostic failed');process.exitCode=1;});
