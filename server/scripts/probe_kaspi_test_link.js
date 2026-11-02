// Read-only bank status diagnostic. No QR creation, invoices, debit or wallet credit.
const { createKaspiService } = require(process.cwd() + '/src/kaspi_pos');
const { KaspiProtocol } = require(process.cwd() + '/src/kaspi_pos/protocol');
const store = require(process.cwd() + '/src/store');
(async () => {
  if (process.env.MTAXI_QR_PROBE_READ_ONLY !== 'true') throw Error('Read-only diagnostic required');
  const snapshot = await store.readStoreAsync();
  const active = (snapshot.fcmTokens || []).filter(t => !t.disabled);
  console.log(JSON.stringify({ diagnostic: 'PUSH_RUNTIME_COUNTS', fcmEnabled: process.env.MTAXI_FCM_ENABLED === 'true', credentialConfigured: !!(process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.FIREBASE_SERVICE_ACCOUNT_JSON),
    activeDevices: active.reduce((counts,t) => { const kind = ['android','ios','web'].includes(String(t.deviceType).toLowerCase()) ? String(t.deviceType).toLowerCase() : 'other'; counts[kind] = (counts[kind] || 0) + 1; return counts; }, {}),
    deliveries: (snapshot.notificationDeliveries || []).reduce((counts,d) => { const key = ['queued','sent','received','failed','delivered','acknowledged'].includes(d.status) ? d.status : 'other'; counts[key]=(counts[key]||0)+1; return counts; }, {}) }));
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
    };
    let historyChecked = false;
    const readHistory = async session => {
      if (historyChecked) return; historyChecked = true;
      const unresolved = snapshot.payments.filter(p => p.provider === 'kaspi_manual' && p.status === 'pending' && p.kaspiPosAttemptId && !p.kaspiPosOperationId);
      if (!unresolved.length) return;
      const host = 'https://qrpay.kaspi.kz', path = '/v01/remote/history', body = JSON.stringify({ MaxResult: 20 });
      const reply = await bank.request(host, path, bank.headers(host, path, session, body), body);
      const candidates = [];
      const visit = (value, depth = 0) => {
        if (!value || typeof value !== 'object' || depth > 5) return;
        if (!Array.isArray(value)) for (const p of unresolved) {
          const matchedComment = Object.entries(value).some(([key,v]) => /comment|description/i.test(key) && typeof v === 'string' && v.includes(p.paymentId));
          if (matchedComment) candidates.push({ paymentId: p.paymentId, operationId: value.Id ?? value.QrOperationId, status: value.Status, amount: typeof value.Amount === 'number' ? value.Amount : String(value.Amount || '').replace(/[^0-9., +-]/g,''), phoneMatches: String(value.ClientMobile || '').replace(/\D/g,'').slice(-10) === String(p.kaspiPhone || '').replace(/\D/g,'').slice(-10) });
        }
        for (const child of Object.values(value)) if (child && typeof child === 'object') visit(child, depth + 1);
      };
      visit(reply.body?.Data);
      console.log(JSON.stringify({ diagnostic: 'UNRESOLVED_INVOICE_HISTORY', unresolvedCount: unresolved.length, historyKeys: reply.body?.Data && typeof reply.body.Data === 'object' ? Object.keys(reply.body.Data) : [], candidates }));
    };
    const status = bank.testLinkStatus.bind(bank);
    bank.testLinkStatus = async (session, id) => {
      const result = await status(session, id);
      await readHistory(session);
      if (result.Status === 'Processed') {
        const host = 'https://qrpay.kaspi.kz', path = '/v01/kaspi-qr/operations/details', body = JSON.stringify({ Id: Number(id), OperationMethod: 0 });
        const reply = await bank.request(host, path, bank.headers(host, path, session, body), body);
        const shape = (data, depth = 0) => {
          if (!data || typeof data !== 'object' || depth > 3) return null;
          const fields = {}, children = {};
          for (const [key,value] of Object.entries(data)) {
            if (/amount|sum/i.test(key)) fields[key + 'Format'] = { type: typeof value, numericPart: String(value ?? '').replace(/[^0-9., -]/g, ''), hasTengeSymbol: String(value).includes('₸'), hasKztCode: /KZT/i.test(String(value)), length: String(value ?? '').length };
            if (/amount|sum|^Id$|^Status$|^OperationMethod$/i.test(key) && (typeof value === 'number' || typeof value === 'string' && /^[a-zA-Z0-9_. ,:-]{0,80}$/.test(value))) fields[key] = value;
            if (value && typeof value === 'object' && !Array.isArray(value)) children[key] = shape(value, depth + 1);
          }
          return { keys: Object.keys(data), fields, children };
        };
        console.log(JSON.stringify({ diagnostic: 'QR_OPERATION_DETAILS_SHAPE', shape: shape(reply.body?.Data), statusCode: reply.body?.StatusCode }));
      }
      return result;
    };
    return bank;
  }});
  const selected = snapshot.payments.filter(p => p.provider === 'kaspi_qr_test' && p.kaspiPosOperationId).sort((a,b)=>Date.parse(b.createdAt)-Date.parse(a.createdAt)).slice(0,3);
  for (const p of selected) { const r = await service.checkTestLink({paymentId:p.paymentId}, {user}); console.log(JSON.stringify({ paymentId:p.paymentId, expectedOperationId:p.kaspiPosOperationId, success:r.success, code:r.code, bankState:r.bankState })); }
})().catch(() => { console.error('Read-only QR diagnostic failed; secrets suppressed.'); process.exitCode = 1; });
