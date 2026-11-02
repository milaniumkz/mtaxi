const crypto = require('node:crypto');
const { KaspiVault } = require('./vault');
const { KaspiProtocol, KaspiError, phone10, bankAmount } = require('./protocol');
const { createIdentity } = require('./crypto');
const messages = {
  KASPI_OPERATION_FAILED: 'Операция не подтверждена. Обновите состояние и проверьте результат.',
  ADMIN_REQUIRED: 'Доступ разрешён только администратору.', KASPI_DISABLED: 'Подключение Kaspi Pay выключено на сервере.',
  KASPI_STORAGE_UNAVAILABLE: 'Не настроено защищённое хранилище Kaspi Pay.', KASPI_PHONE_INVALID: 'Введите номер кассира Kaspi Pay в формате +7XXXXXXXXXX.',
  KASPI_ALREADY_CONNECTED: 'Касса уже подключена. Для другого входа сначала отключите её здесь.',
  KASPI_AUTH_BUSY: 'Вход уже начат. Введите полученный код или дождитесь окончания попытки.',
  KASPI_AUTH_COOLDOWN: 'Подождите минуту перед новым запросом SMS.', KASPI_AUTH_EXPIRED: 'Попытка входа истекла. Начните заново.',
  KASPI_OTP_INVALID: 'Введите SMS-код из 4–8 цифр.', KASPI_OTP_REJECTED: 'Kaspi не подтвердил код или требует дополнительное действие в своём приложении.',
  KASPI_NOT_CONNECTED: 'Сначала подключите Kaspi Pay на главной странице админки.',
  KASPI_ORGANIZATION_INVALID: 'Выберите организацию из подтверждённого списка Kaspi.',
  KASPI_NETWORK_UNCERTAIN: 'Ответ Kaspi не получен. Не повторяйте финансовую операцию до проверки её результата.',
  KASPI_SMS_NOT_SENT: 'Kaspi не подтвердил отправку SMS. Проверьте номер кассира и код ошибки.',
  KASPI_BANK_REJECTED: 'Kaspi отклонил запрос. Проверьте доступ кассира и код ошибки.',
  KASPI_AUTH_NOT_FINISHED: 'Kaspi не завершил вход. Продолжите требуемое подтверждение в Kaspi Pay.',
  KASPI_AUTH_PROTOCOL: 'Kaspi вернул неподдерживаемый шаг входа.', KASPI_ORGANIZATION_UNCONFIRMED: 'Kaspi не подтвердил профиль организации.',
  KASPI_INVOICE_CONFIRM_REQUIRED: 'Подтвердите отправку счёта в Kaspi отдельным действием.',
  PAYMENT_NOT_PENDING: 'Заявка недоступна для выставления счёта.', KASPI_INVOICE_ALREADY_MANUAL: 'Эта заявка уже отмечена как выставленная вручную. Повторный счёт не создаётся.',
  KASPI_INVOICE_UNCERTAIN: 'Результат предыдущего выставления не подтверждён. Проверьте счёт в Kaspi Pay; повтор заблокирован.',
  KASPI_INVOICE_UNLINKED: 'У заявки нет подтверждённого номера операции Kaspi.', KASPI_PAYMENT_BINDING_MISMATCH: 'Номер операции, сумма или плательщик в Kaspi не совпали с заявкой.',
  KASPI_AMOUNT_INVALID: 'Для счёта нужна сумма от 1 до 1 000 000 ₸ с точностью до тиына.',
};
function fail(code, bankCode = '') { return { success: false, code, error: messages[code] || 'Операция Kaspi не выполнена.', ...(bankCode ? { bankCode } : {}) }; }
function admin(auth) { if (auth?.user?.role !== 'admin' || auth.user.blocked === true) throw new KaspiError('ADMIN_REQUIRED'); }
function audit(store, auth, action, payment, extra = {}) {
  store.auditLogs ||= []; store.auditLogs.push({ id: crypto.randomUUID(), action, adminId: auth.user.id,
    target: payment ? `payments/${payment.id}` : 'kaspi-pos/connection', after: extra, createdAt: new Date().toISOString() });
}
function createKaspiService(options = {}) {
  const env = options.env || process.env;
  const store = options.store || require('../store');
  const enabled = () => env.MTAXI_KASPI_POS_ENABLED === 'true';
  const vault = options.vault || new KaspiVault(env.MTAXI_KASPI_POS_STATE_DIR || '/var/lib/mtaxi/kaspi-pos', env.MTAXI_KASPI_POS_KEY_FILE || '/run/secrets/kaspi-pos.key');
  const protocol = identity => options.protocolFactory ? options.protocolFactory(identity) : new KaspiProtocol(identity, { env });
  const now = options.now || Date.now;
  let attempt = null, attemptTimer = null, queue = Promise.resolve();
  const clearAttempt = () => { attempt = null; clearTimeout(attemptTimer); attemptTimer = null; };
  const exclusive = fn => { const p = queue.then(fn); queue = p.catch(() => {}); return p; };
  const load = () => { if (!enabled()) throw new KaspiError('KASPI_DISABLED'); try { return vault.load(); } catch { throw new KaspiError('KASPI_STORAGE_UNAVAILABLE'); } };
  const save = state => { try { vault.save(state); } catch { throw new KaspiError('KASPI_STORAGE_UNAVAILABLE'); } };
  const sessionOf = state => { if (!state.session?.tokenSN || !state.session.secretB64) throw new KaspiError('KASPI_NOT_CONNECTED'); return state.session; };
  function status(state, auth) {
    if (attempt && (attempt.expiresAt <= now() || attempt.tries >= 5)) clearAttempt();
    const session = state?.session;
    return { enabled: enabled(), configured: !!state, connected: !!session?.tokenSN,
      organization: session ? { id: session.organizationId, name: session.orgName, iin: session.organizationIin } : null,
      organizations: session?.organizations || [], connectedAt: session?.connectedAt || null,
      lastCheckedAt: session?.lastCheckedAt || null, connectionActive: session?.connectionActive ?? null,
      ...(attempt?.actorId === auth.user.id ? { challengeId: attempt.id, pendingAuth: true, authExpiresAt: new Date(attempt.expiresAt).toISOString(),
        phoneHint: '+7 ' + attempt.phone.slice(0, 3) + ' *** ** ' + attempt.phone.slice(-2) } : { pendingAuth: false }) };
  }
  const guarded = fn => async (data = {}, auth) => {
    try { admin(auth); return await fn(data, auth); }
    catch (error) { return fail(error instanceof KaspiError ? error.code : 'KASPI_OPERATION_FAILED', error instanceof KaspiError ? error.bankCode : ''); }
  };
  return {
    getStatus: guarded(async (_, auth) => {
      if (!enabled()) return { success: true, status: status(null, auth) };
      const state = load(), view = status(state, auth);
      if (state.session) {
        const snapshot = await store.readStoreAsync();
        const latest = (snapshot.payments || []).filter(p => p.provider === 'kaspi_qr_test' && p.userId === auth.user.id && p.paymentUrl &&
          p.kaspiPosOrganizationId === state.session.organizationId && p.kaspiPosOrganizationIin === state.session.organizationIin)
          .sort((a,b) => Date.parse(b.createdAt) - Date.parse(a.createdAt))[0];
        if (latest) view.latestTestLink = { paymentId: latest.paymentId, paymentUrl: latest.paymentUrl, bankState: latest.kaspiPosBankState || 'pending', amount: latest.amount, checkedAt: latest.kaspiPosCheckedAt || null, expiresAt: latest.expiresAt };
      }
      return { success: true, status: view };
    }),
    startLogin: guarded((data, auth) => exclusive(async () => {
      const phone = phone10(data.phone);
      if (!/^7\d{9}$/.test(phone)) throw new KaspiError('KASPI_PHONE_INVALID');
      const state = load();
      if (state.session?.tokenSN) throw new KaspiError('KASPI_ALREADY_CONNECTED');
      if (attempt && attempt.expiresAt > now()) throw new KaspiError('KASPI_AUTH_BUSY');
      if (state.lastAuthStartedAt && now() - state.lastAuthStartedAt < 60000) throw new KaspiError('KASPI_AUTH_COOLDOWN');
      state.identity ||= createIdentity(); state.lastAuthStartedAt = now(); save(state);
      const client = protocol(state.identity);
      const internal = await client.init(phone);
      attempt = { ...internal, id: crypto.randomUUID(), actorId: auth.user.id, expiresAt: now() + 300000, tries: 0 };
      clearTimeout(attemptTimer); attemptTimer = setTimeout(clearAttempt, 300000); attemptTimer.unref();
      try { await client.sendPhone(attempt); }
      catch (error) { if (!error.uncertain) clearAttempt(); throw error; }
      return { success: true, status: status(state, auth) };
    })),
    verifyLogin: guarded((data, auth) => exclusive(async () => {
      if (!attempt || attempt.id !== data.challengeId || attempt.actorId !== auth.user.id || attempt.expiresAt <= now() || attempt.tries >= 5)
        throw new KaspiError('KASPI_AUTH_EXPIRED');
      if (!/^\d{4,8}$/.test(String(data.otp || ''))) throw new KaspiError('KASPI_OTP_INVALID');
      attempt.tries++;
      const state = load();
      const session = await protocol(state.identity).verify(attempt, String(data.otp));
      state.session = session; save(state); clearAttempt();
      await store.withStoreAsync(s => audit(s, auth, 'kaspiPosLogin', null, { organizationId: session.organizationId }));
      return { success: true, status: status(state, auth) };
    })),
    selectOrganization: guarded((data, auth) => exclusive(async () => {
      const state = load(), current = sessionOf(state);
      if (!(current.organizations || []).some(o => o.id === String(data.organizationId))) throw new KaspiError('KASPI_ORGANIZATION_INVALID');
      state.session = await protocol(state.identity).selectOrganization(current, String(data.organizationId)); save(state);
      return { success: true, status: status(state, auth) };
    })),
    checkConnection: guarded((_, auth) => exclusive(async () => {
      const state = load(), session = sessionOf(state);
      try { await protocol(state.identity).check(session); session.connectionActive = true; }
      catch (error) { session.connectionActive = false; session.lastCheckedAt = new Date(now()).toISOString(); save(state); throw error; }
      session.lastCheckedAt = new Date(now()).toISOString(); save(state);
      return { success: true, status: status(state, auth) };
    })),
    disconnect: guarded((_, auth) => exclusive(async () => {
      const state = load(); delete state.session; clearAttempt(); save(state);
      await store.withStoreAsync(s => audit(s, auth, 'kaspiPosDisconnect', null));
      return { success: true, status: status(state, auth) };
    })),
    testLink: guarded((data, auth) => exclusive(async () => {
      const state = load(), session = sessionOf(state);
      if (data.confirm !== true || !/^[a-zA-Z0-9-]{16,80}$/.test(data.requestId || '')) throw new KaspiError('KASPI_INVOICE_CONFIRM_REQUIRED');
      const id = 'kaspi-test-' + data.requestId;
      const reserved = await store.withStoreAsync(s => {
        s.payments ||= [];
        const existing = s.payments.find(p => p.paymentId === id);
        if (existing) {
          if (existing.kaspiPosOrganizationId !== session.organizationId || existing.kaspiPosOrganizationIin !== session.organizationIin) throw new KaspiError('KASPI_INVOICE_UNLINKED');
          if (existing.paymentUrl) return existing;
          throw new KaspiError('KASPI_INVOICE_UNCERTAIN');
        }
        if (s.payments.some(p => p.provider === 'kaspi_qr_test' && now() - Date.parse(p.createdAt) < 30000)) throw new KaspiError('KASPI_AUTH_COOLDOWN');
        const p = { id, paymentId: id, purpose: 'kaspi_link_test', provider: 'kaspi_qr_test', amount: 100, status: 'pending',
          userId: auth.user.id, kaspiPosOrganizationId: session.organizationId, kaspiPosOrganizationIin: session.organizationIin,
          kaspiPosCreateState: 'creating', createdAt: new Date(now()).toISOString() };
        s.payments.push(p); audit(s, auth, 'kaspiTestLinkRequested', p, { amount: 100 }); return p;
      });
      if (reserved.paymentUrl) return { success: true, paymentId: id, paymentUrl: reserved.paymentUrl, amount: 100, expiresAt: reserved.expiresAt };
      let result;
      try { result = await protocol(state.identity).createTestLink(session, data); }
      catch (error) { const diagnostic = error instanceof KaspiError ? error.bankCode || error.code : 'KASPI_OPERATION_FAILED'; await store.withStoreAsync(s => { const p = s.payments.find(p => p.paymentId === id); p.kaspiPosCreateState = 'unknown'; p.kaspiTestError = diagnostic; }); return fail('KASPI_INVOICE_UNCERTAIN', diagnostic); }
      await store.withStoreAsync(s => { const p = s.payments.find(p => p.paymentId === id); Object.assign(p, result, { kaspiPosOperationId: result.operationId, kaspiPosCreateState: 'sent' }); });
      return { success: true, paymentId: id, ...result, amount: 100 };
    })),
    checkTestLink: guarded((data, auth) => exclusive(async () => {
      const state = load(), session = sessionOf(state), snapshot = await store.readStoreAsync();
      const p = snapshot.payments.find(p => p.paymentId === data.paymentId && p.provider === 'kaspi_qr_test');
      if (!p?.kaspiPosOperationId || p.kaspiPosOrganizationId !== session.organizationId || p.kaspiPosOrganizationIin !== session.organizationIin) throw new KaspiError('KASPI_INVOICE_UNLINKED');
      const bank = protocol(state.identity);
      let bankState;
      try {
        const result = await bank.testLinkStatus(session, p.kaspiPosOperationId);
        const reportedId = result.QrOperationId ?? result.Id;
        if (reportedId != null && String(reportedId) !== '0' && String(reportedId) !== p.kaspiPosOperationId) throw new KaspiError('KASPI_PAYMENT_BINDING_MISMATCH');
        if (result.Status === 'Processed') {
          if (String(reportedId) !== p.kaspiPosOperationId) throw new KaspiError('KASPI_PAYMENT_BINDING_MISMATCH');
          let amount = bankAmount(result.Amount);
          if (result.Amount == null) {
            const details = await bank.qrOperationDetails(session, p.kaspiPosOperationId);
            if (String(details.QrOperationId ?? details.Id) !== p.kaspiPosOperationId || String(details.OrganizationIdn) !== session.organizationIin) throw new KaspiError('KASPI_PAYMENT_BINDING_MISMATCH');
            amount = bankAmount(details.Amount);
          }
          if (amount !== 100) throw new KaspiError('KASPI_PAYMENT_BINDING_MISMATCH');
        }
        bankState = ({ Processed: 'paid', QrTokenCreated: 'pending', Wait: 'pending', QrTokenDiscarded: 'expired', Expired: 'expired', Cancelled: 'cancelled',
          CancelledByUser: 'cancelled', NotConfirmedByUser: 'cancelled', CancelledByExternalSource: 'cancelled', ProcessingFailed: 'failed', Rejected: 'failed', InsufficientFunds: 'failed', InsufficientFundsError: 'failed', Error: 'failed' })[result.Status] || 'unknown';
      } catch (error) {
        await store.withStoreAsync(s => { const current = s.payments.find(x => x.paymentId === p.paymentId); current.kaspiPosBankState = 'unverified'; current.kaspiPosCheckedAt = new Date(now()).toISOString(); });
        throw error;
      }
      await store.withStoreAsync(s => {
        const current = s.payments.find(x => x.paymentId === p.paymentId);
        current.kaspiPosBankState = bankState; current.kaspiPosCheckedAt = new Date(now()).toISOString();
        if (bankState === 'paid') { current.status = 'success'; current.paidAt ||= current.kaspiPosCheckedAt; }
        if (['cancelled','failed','expired'].includes(bankState) && current.status !== 'success') current.status = 'failed';
      });
      return { success: true, bankState, amount: 100 };
    })),
    sendInvoice: guarded((data, auth) => exclusive(async () => {
      if (data.confirm !== true) throw new KaspiError('KASPI_INVOICE_CONFIRM_REQUIRED');
      const state = load(), session = sessionOf(state);
      // Verify session before reserving an invoice attempt: failed auth must not
      // turn a still-unsent top-up into an ambiguous financial operation.
      const bank = protocol(state.identity);
      try { await bank.check(session); session.connectionActive = true; }
      catch (error) { session.connectionActive = false; session.lastCheckedAt = new Date(now()).toISOString(); save(state); throw error; }
      session.lastCheckedAt = new Date(now()).toISOString(); save(state);
      const reserved = await store.withStoreAsync(s => {
        const p = (s.payments || []).find(x => x.paymentId === data.paymentId);
        if (!p || p.provider !== 'kaspi_manual' || p.status !== 'pending' || p.applied) throw new KaspiError('PAYMENT_NOT_PENDING');
        if (p.kaspiPosOperationId) return { existing: true, paymentId: p.paymentId };
        if (p.kaspiPosAttemptId) throw new KaspiError('KASPI_INVOICE_UNCERTAIN');
        if (p.invoiceStatus === 'sent') throw new KaspiError('KASPI_INVOICE_ALREADY_MANUAL');
        if (!Number.isFinite(p.amount) || p.amount < 1 || p.amount > 1000000 || Math.abs(p.amount * 100 - Math.round(p.amount * 100)) > 0.00001)
          throw new KaspiError('KASPI_AMOUNT_INVALID');
        if (!/^7\d{9}$/.test(phone10(p.kaspiPhone))) throw new KaspiError('KASPI_PHONE_INVALID');
        p.kaspiPosAttemptId = crypto.randomUUID(); p.kaspiPosCreateState = 'creating';
        p.kaspiPosOrganizationId = session.organizationId; p.kaspiPosOrganizationIin = session.organizationIin;
        p.kaspiPosCreatedBy = auth.user.id; p.updatedAt = new Date(now()).toISOString();
        audit(s, auth, 'kaspiPosInvoiceRequested', p, { amount: p.amount });
        return { paymentId: p.paymentId, amount: p.amount, kaspiPhone: p.kaspiPhone, attemptId: p.kaspiPosAttemptId };
      });
      if (reserved.existing) return { success: true, alreadySent: true };
      let result;
      try { result = await bank.createInvoice(session, reserved); }
      catch (error) {
        await store.withStoreAsync(s => {
          const p = s.payments.find(x => x.paymentId === reserved.paymentId);
          if (p?.kaspiPosAttemptId === reserved.attemptId) { p.kaspiPosCreateState = 'unknown'; p.updatedAt = new Date(now()).toISOString(); }
        });
        return fail('KASPI_INVOICE_UNCERTAIN', error.bankCode || '');
      }
      let duplicateOperation = false;
      await store.withStoreAsync(s => {
        const p = s.payments.find(x => x.paymentId === reserved.paymentId);
        if (!p || p.kaspiPosAttemptId !== reserved.attemptId) throw new KaspiError('KASPI_INVOICE_UNCERTAIN');
        if (s.payments.some(other => other.paymentId !== p.paymentId && other.kaspiPosOperationId === result.operationId && other.kaspiPosOrganizationId === session.organizationId)) {
          p.kaspiPosCreateState = 'unknown'; duplicateOperation = true; return;
        }
        p.kaspiPosOperationId = result.operationId; p.kaspiPosCreateState = 'sent'; p.kaspiPosBankState = 'pending';
        p.invoiceStatus = 'sent'; p.invoiceSentAt = new Date(now()).toISOString(); p.invoiceSentBy = auth.user.id; p.updatedAt = p.invoiceSentAt;
        audit(s, auth, 'kaspiPosInvoiceSent', p, { operationId: result.operationId, amount: p.amount });
      });
      if (duplicateOperation) return fail('KASPI_PAYMENT_BINDING_MISMATCH');
      return { success: true, operationId: result.operationId };
    })),
    checkInvoice: guarded((data, auth) => exclusive(async () => {
      const state = load(), session = sessionOf(state);
      const snapshot = await store.readStoreAsync();
      const p = (snapshot.payments || []).find(x => x.paymentId === data.paymentId);
      if (!p?.kaspiPosOperationId || p.kaspiPosOrganizationId !== session.organizationId || p.kaspiPosOrganizationIin !== session.organizationIin)
        throw new KaspiError('KASPI_INVOICE_UNLINKED');
      let details;
      try {
        details = await protocol(state.identity).invoiceDetails(session, p.kaspiPosOperationId);
        const id = details.QrOperationId ?? details.Id;
        if (String(id) !== p.kaspiPosOperationId || bankAmount(details.Amount) !== Number(p.amount) || phone10(details.ClientMobile) !== phone10(p.kaspiPhone))
          throw new KaspiError('KASPI_PAYMENT_BINDING_MISMATCH');
      } catch (error) {
        await store.withStoreAsync(s => {
          const current = s.payments.find(x => x.paymentId === p.paymentId);
          if (current?.kaspiPosOperationId === p.kaspiPosOperationId) {
            current.kaspiPosBankState = 'unverified'; current.kaspiPosCheckedAt = new Date(now()).toISOString();
          }
        });
        throw error;
      }
      const bankState = ({ Processed: 'paid', RemotePaymentCreated: 'pending', RemotePaymentCanceled: 'cancelled', RemotePaymentRejected: 'failed', Expired: 'expired' })[details.Status] || 'unknown';
      await store.withStoreAsync(s => {
        const current = s.payments.find(x => x.paymentId === p.paymentId);
        if (!current || current.kaspiPosOperationId !== p.kaspiPosOperationId) throw new KaspiError('KASPI_PAYMENT_BINDING_MISMATCH');
        current.kaspiPosBankState = bankState; current.kaspiPosCheckedAt = new Date(now()).toISOString();
        audit(s, auth, 'kaspiPosInvoiceChecked', current, { bankState });
      });
      // Money is credited only by the separate, existing admin-confirm action.
      return { success: true, bankState, paymentId: p.paymentId };
    })),
  };
}
let singleton;
function kaspiService() { return singleton ||= createKaspiService(); }
module.exports = { createKaspiService, kaspiService, fail };
