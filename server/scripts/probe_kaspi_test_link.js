// Privileged, explicitly requested 100 KZT QR diagnostic. Never logs bank sessions.
const { createKaspiService } = require('./src/kaspi_pos');
const { KaspiProtocol } = require('./src/kaspi_pos/protocol');
const store = require('./src/store');
(async () => {
  if (process.env.MTAXI_QR_PROBE_CONFIRM !== '100') throw Error('Explicit 100 KZT probe confirmation required');
  const snapshot = await store.readStoreAsync();
  const user = snapshot.users.find(u => u.role === 'admin' && !u.blocked);
  if (!user) throw Error('Active admin required');
  const service = createKaspiService({ protocolFactory: identity => {
    const bank = new KaspiProtocol(identity), request = bank.request.bind(bank);
    bank.request = async (...args) => {
      const response = await request(...args);
      if (args[1] === '/v01/qr-token/create') {
        const d = response.body?.Data || {};
        const value = d.Amount;
        const amount = typeof value === 'number' || typeof value === 'string' && /^[-\d.,\s]{1,40}$/.test(value) ? value : null;
        console.log(JSON.stringify({ diagnostic: 'QR_RESPONSE_SHAPE', statusCode: Number(response.body?.StatusCode), dataKeys: Object.keys(d).filter(k => /^[a-zA-Z0-9_]{1,60}$/.test(k)), amountType: typeof value, amount,
          amountKeys: value && typeof value === 'object' ? Object.keys(value).filter(k => /^[a-zA-Z0-9_]{1,60}$/.test(k)) : [], hasQrToken: typeof d.QrToken === 'string' }));
      }
      return response;
    };
    return bank;
  }});
  const result = await service.testLink({ confirm: true, requestId: process.env.MTAXI_QR_PROBE_ID }, { user });
  console.log(JSON.stringify({ success: result.success, code: result.code, bankCode: result.bankCode, paymentUrl: result.paymentUrl, amount: result.amount }));
})().catch(() => { console.error('QR probe failed; secrets suppressed; do not automatically retry.'); process.exitCode = 1; }).finally(async () => { await store.closeStoreAsync?.(); });
