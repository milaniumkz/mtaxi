// Read-only bank status diagnostic. No QR creation, invoices, debit or wallet credit.
const { createKaspiService } = require(process.cwd() + '/src/kaspi_pos');
const { KaspiProtocol } = require(process.cwd() + '/src/kaspi_pos/protocol');
const store = require(process.cwd() + '/src/store');
(async () => {
  if (process.env.MTAXI_QR_PROBE_READ_ONLY !== 'true') throw Error('Read-only diagnostic required');
  const snapshot = await store.readStoreAsync();
  const user = snapshot.users.find(u => u.role === 'admin' && !u.blocked);
  if (!user) throw Error('Active admin required');
  const service = createKaspiService({ protocolFactory: identity => {
    const bank = new KaspiProtocol(identity), request = bank.request.bind(bank);
    bank.request = async (...args) => {
      const response = await request(...args);
      if (args[1].startsWith('/v02/kaspi-qr/status?')) {
        const d = response.body?.Data || {}, scalar = v => typeof v === 'number' || typeof v === 'string' && /^[a-zA-Z0-9_. ,:-]{0,80}$/.test(v) ? v : null;
        console.log(JSON.stringify({ diagnostic: 'QR_STATUS_SHAPE', dataKeys: Object.keys(d).filter(k => /^[a-zA-Z0-9_]{1,60}$/.test(k)),
          status: scalar(d.Status), amount: scalar(d.Amount), paymentAmount: scalar(d.PaymentAmount), operationId: scalar(d.QrOperationId), id: scalar(d.Id),
          amountType: typeof d.Amount, amountKeys: d.Amount && typeof d.Amount === 'object' ? Object.keys(d.Amount) : [] }));
      }
      return response;
    }; return bank;
  }});
  const selected = snapshot.payments.filter(p => p.provider === 'kaspi_qr_test' && p.kaspiPosOperationId).sort((a,b)=>Date.parse(b.createdAt)-Date.parse(a.createdAt)).slice(0,3);
  for (const p of selected) { const r = await service.checkTestLink({paymentId:p.paymentId}, {user}); console.log(JSON.stringify({ paymentId:p.paymentId, expectedOperationId:p.kaspiPosOperationId, success:r.success, code:r.code, bankState:r.bankState })); }
})().catch(() => { console.error('Read-only QR diagnostic failed; secrets suppressed.'); process.exitCode = 1; });
