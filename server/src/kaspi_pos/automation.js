// Internal worker only. No bank session or privileged actor is exposed to clients.
const storeDefault = require('../store');
const { kaspiService } = require('./index');
const paymentsDefault = require('../payments');
const system = { user: { id: 'system:kaspi-pay', role: 'admin' } };
function createKaspiAutomation({ env = process.env, store = storeDefault, service = kaspiService(), payments = paymentsDefault, now = Date.now } = {}) {
  const enabled = () => env.MTAXI_KASPI_POS_ENABLED === 'true' && (env.MTAXI_KASPI_POS_AUTO_INVOICES === 'true' || env.MTAXI_KASPI_POS_AUTO_LINKS === 'true');
  const running = new Map(); let ticking = false, heartbeatAfter = 0;
  async function processPayment(paymentId) {
    if (!enabled()) return;
    if (running.has(paymentId)) return running.get(paymentId);
    const work = (async () => {
      const snapshot = await store.readStoreAsync();
      let p = (snapshot.payments || []).find(p => p.paymentId === paymentId);
      if (!p || !['kaspi_manual','kaspi_qr_test','kaspi_qr'].includes(p.provider) || p.status !== 'pending' || p.applied || (!p.kaspiAuto && !p.kaspiPosOperationId)) return;
      if (Date.parse(p.kaspiAutoNextCheckAt || '') > now()) return;
      // Reserve the polling window before network I/O; survives restarts.
      await store.withStoreAsync(s => { const item = s.payments.find(x => x.paymentId === paymentId); if (item) item.kaspiAutoNextCheckAt = new Date(now() + 30000).toISOString(); });
      if (p.provider === 'kaspi_qr_test') {
        if (!p.kaspiPosOperationId) return;
        const checked = await service.checkTestLink({ paymentId }, system);
        await store.withStoreAsync(s => { const item = s.payments.find(x => x.paymentId === paymentId); if (item) { item.kaspiAutoError = checked.success ? null : checked.code; if (!checked.success) item.kaspiAutoNextCheckAt = new Date(now() + 60000).toISOString(); } });
        return; // Test payments never enter wallet confirmation.
      }
      let result;
      if (!p.kaspiPosOperationId) {
        if (p.kaspiPosAttemptId || p.invoiceStatus === 'sent') return; // Never retry uncertain or manually sent invoices.
        if (p.provider === 'kaspi_manual' && env.MTAXI_KASPI_POS_AUTO_INVOICES !== 'true') return;
        result = p.provider === 'kaspi_qr' ? await service.createPaymentLink({ paymentId }, system) : await service.sendInvoice({ paymentId, confirm: true }, system);
        if (result.success) {
          const fresh = await store.readStoreAsync(); p = fresh.payments.find(x => x.paymentId === paymentId);
        }
      }
      if (p.kaspiPosOperationId) {
        result = p.provider === 'kaspi_qr' ? await service.checkPaymentLink({ paymentId }, system) : await service.checkInvoice({ paymentId }, system);
        if (result.success && result.bankState === 'paid') {
          result = await payments.confirmDriverTopUpPaymentAsync({ paymentId }, system);
        } else if (result.success && ['cancelled', 'failed', 'expired'].includes(result.bankState)) {
          result = await payments.failDriverTopUpPaymentAsync({ paymentId }, system);
        }
      }
      await store.withStoreAsync(s => {
        const item = s.payments.find(x => x.paymentId === paymentId); if (!item) return;
        item.kaspiAutoError = result?.success === false ? result.code || 'KASPI_OPERATION_FAILED' : null;
        if (item.kaspiAutoError) item.kaspiAutoNextCheckAt = new Date(now() + 60000).toISOString();
      });
    })();
    running.set(paymentId, work); try { return await work; } finally { running.delete(paymentId); }
  }
  async function afterCreated(response, auth) {
    if (!enabled() || !response?.success || !response.paymentId) return response;
    // Caller may only trigger their own persisted request; ignore all client amount/status fields.
    const snapshot = await store.readStoreAsync();
    const p = snapshot.payments.find(x => x.paymentId === response.paymentId);
    if (!p || p.userId !== auth?.user?.id || !p.kaspiAuto) return response;
    try { await processPayment(p.paymentId); } catch { /* Persisted queue is retried by the worker. */ }
    return { ...response, ...(await payments.getDriverTopUpPaymentStatusAsync({ paymentId: p.paymentId }, auth)) };
  }
  async function tick() {
    if (!enabled() || ticking) return; ticking = true;
    try {
      const snapshot = await store.readStoreAsync();
      const pending = (snapshot.payments || []).filter(p => ['kaspi_manual','kaspi_qr_test','kaspi_qr'].includes(p.provider) && p.status === 'pending' && !p.applied &&
        (p.kaspiAuto || p.kaspiPosOperationId) && (!p.kaspiPosAttemptId || p.kaspiPosOperationId) &&
        !(Date.parse(p.kaspiAutoNextCheckAt || '') > now())).sort((a,b) => (Date.parse(a.kaspiAutoNextCheckAt || '') || 0) - (Date.parse(b.kaspiAutoNextCheckAt || '') || 0));
      for (const p of pending.slice(0, 10)) { try { await processPayment(p.paymentId); } catch { /* No secrets in worker logs. */ } }
      if (now() >= heartbeatAfter) {
        heartbeatAfter = now() + 6 * 60 * 60 * 1000;
        const status = await service.getStatus({}, system);
        if (status.status?.connected && now() - (Date.parse(status.status.lastCheckedAt || '') || 0) >= 6 * 60 * 60 * 1000)
          await service.checkConnection({}, system); // Read-only activity, not a guaranteed bank-side renewal.
      }
    } finally { ticking = false; }
  }
  return { enabled, processPayment, afterCreated, tick };
}
let singleton;
function kaspiAutomation() { return singleton ||= createKaspiAutomation(); }
function startKaspiAutomation() {
  const worker = kaspiAutomation(); if (!worker.enabled()) return { stop() {} };
  const timer = setInterval(() => worker.tick().catch(() => {}), 15000); timer.unref();
  const initial = setTimeout(() => worker.tick().catch(() => {}), 5000); initial.unref();
  return { stop() { clearInterval(timer); clearTimeout(initial); } };
}
module.exports = { createKaspiAutomation, kaspiAutomation, startKaspiAutomation };
