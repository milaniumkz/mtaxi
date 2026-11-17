// Bank reads only. Optional, explicitly selected closing of a fully matched rejected legacy invoice; never issues, debits or credits.
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
  const selfTest = (snapshot.notifications || []).find(n => n.dedupeKey === 'paid-qr-delivery-test-0d719302');
  if (selfTest) {
    const deliveries = (snapshot.notificationDeliveries || []).filter(d => d.notificationId === selfTest.id);
    const permanent = d => d.status === 'failed' && /registration-token-not-registered|not a valid FCM registration token|^NotRegistered$/i.test(String(d.error || ''));
    if (process.env.MTAXI_DISABLE_INVALID_TOKENS === 'true') {
      let disabledCount = 0;
      await store.withStoreAsync(db => {
        for (const delivery of (db.notificationDeliveries || []).filter(d => d.notificationId === selfTest.id && permanent(d))) {
          const token = (db.fcmTokens || []).find(t => t.id === delivery.tokenId);
          if (token && !token.disabled && token.userId === delivery.userId) { token.disabled = true; token.disabledAt = new Date().toISOString(); token.disabledReason = 'permanent-fcm-registration-error'; disabledCount++; }
        }
      });
      console.log(JSON.stringify({diagnostic:'PERMANENT_INVALID_PUSH_REGISTRATIONS_DISABLED',disabledCount}));
    }
    const acks = (snapshot.pushDeliveryAcks || []).filter(a => a.notificationId === selfTest.id);
    console.log(JSON.stringify({ diagnostic: 'PAYMENT_SELF_PUSH_TEST', targetDevices: deliveries.length,
      states: deliveries.reduce((counts,d) => { const key = ['sent','queued','failed','cancelled'].includes(d.status) ? d.status : 'other'; counts[key]=(counts[key]||0)+1; return counts; }, {}),
      providerMessageIds: deliveries.filter(d => !!d.messageId).length,
      errorKinds: deliveries.filter(d=>d.status === 'failed').map(d=> { const message=String(d.error||''); return /not a valid FCM registration token|invalid registration token/i.test(message) ? 'invalid_registration' : /registration-token-not-registered|Requested entity was not found|not registered|notregistered/i.test(message) ? 'expired_registration' : /credential|authentication|unauthenticated|permission/i.test(message) ? 'credentials' : 'other'; }),
      failedMetadata: deliveries.filter(d => d.status === 'failed').map(d => {
        const token = (snapshot.fcmTokens || []).find(t => t.id === d.tokenId), message = String(d.error || '');
        return { hasToken: !!token, disabled: token?.disabled === true, ownerMatches: token?.userId === d.userId, platform: token?.deviceType,
          errorLength: message.length, knownError: ['NotRegistered','UNREGISTERED','InvalidToken','SENDER_ID_MISMATCH'].find(value => value === message) || null, errorFlags: ['registration','token','permission','entity','project','timeout','credential','unavailable','invalid','payload','auth','vapid','third-party','network'].filter(word => message.toLowerCase().includes(word)) };
      }),
      errorCodes: [...new Set(deliveries.map(d => d.errorCode).filter(v => typeof v === 'string' && /^[a-zA-Z0-9_/-]{1,100}$/.test(v)))],
      received: acks.filter(a => a.eventType === 'received').length, opened: acks.filter(a => a.eventType === 'opened').length }));
  }
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
          const matchedComment = Object.entries(value).some(([key,v]) => /comment|description/i.test(key) && typeof v === 'string' && v.trim() === 'MTaxi ' + p.paymentId);
          if (matchedComment) candidates.push({ paymentId: p.paymentId, operationId: value.Id ?? value.QrOperationId, status: value.Status, amount: typeof value.Amount === 'number' ? value.Amount : String(value.Amount || '').replace(/[^0-9., +-]/g,''), phoneMatches: String(value.ClientMobile || '').replace(/\D/g,'').slice(-10) === String(p.kaspiPhone || '').replace(/\D/g,'').slice(-10) });
        }
        for (const child of Object.values(value)) if (child && typeof child === 'object') visit(child, depth + 1);
      };
      visit(reply.body?.Data);
      for (const candidate of candidates) {
        const p = unresolved.find(p => p.paymentId === candidate.paymentId);
        if (!p || !candidate.operationId) continue;
        const details = await bank.invoiceDetails(session, String(candidate.operationId));
        const phone10 = value => String(value || '').replace(/\D/g,'').slice(-10);
        const { bankAmount } = require(process.cwd() + '/src/kaspi_pos/protocol');
        const verifiedDecline = candidates.filter(x => x.paymentId === p.paymentId).length === 1 && details.Status === 'RemotePaymentRejected' &&
          String(details.Id ?? details.QrOperationId) === String(candidate.operationId) && bankAmount(details.Amount) === Number(p.amount) &&
          !!details.ClientMobile && phone10(details.ClientMobile) === phone10(p.kaspiPhone) && p.kaspiPosOrganizationId === session.organizationId && p.kaspiPosOrganizationIin === session.organizationIin;
        if (process.env.MTAXI_RESOLVE_DECLINED === 'true' && verifiedDecline) {
          await store.withStoreAsync(db => {
            const current = db.payments.find(x => x.paymentId === p.paymentId);
            if (!current || current.status !== 'pending' || current.applied || current.kaspiPosOperationId || current.amount !== p.amount || current.kaspiPhone !== p.kaspiPhone || current.kaspiPosAttemptId !== p.kaspiPosAttemptId) throw Error('Request changed; resolution aborted');
            current.kaspiPosOperationId = String(candidate.operationId); current.kaspiPosCreateState = 'sent'; current.kaspiPosBankState = 'failed'; current.kaspiPosCheckedAt = new Date().toISOString();
            db.auditLogs ||= []; db.auditLogs.push({id:store.newId('audit'),action:'reconcileDeclinedKaspiInvoice',target:'payments/'+current.id,adminId:user.id,after:{bankState:'failed',amount:current.amount},createdAt:new Date().toISOString()});
          });
          const resolved = await require(process.cwd() + '/src/payments').failDriverTopUpPaymentAsync({paymentId:p.paymentId},{user});
          console.log(JSON.stringify({diagnostic:'LEGACY_DECLINE_RESOLVED',paymentId:p.paymentId,success:resolved.success,code:resolved.code}));
        }
        console.log(JSON.stringify({ diagnostic: 'UNRESOLVED_INVOICE_DETAILS', paymentId: p.paymentId, dataKeys: Object.keys(details),
          operationMatches: String(details.Id ?? details.QrOperationId) === String(candidate.operationId),
          status: details.Status, amount: typeof details.Amount === 'number' ? details.Amount : String(details.Amount || '').replace(/[^0-9., +-]/g,''),
          phoneMatches: !!details.ClientMobile && phone10(details.ClientMobile) === phone10(p.kaspiPhone),
          organizationMatches: p.kaspiPosOrganizationId === session.organizationId && p.kaspiPosOrganizationIin === session.organizationIin }));
      }
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
