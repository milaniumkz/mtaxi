const { withStoreAsync, readStoreAsync, newId } = require("./store");
const { asDate, asNumber, normalizePhone, normalizeString } = require("./utils/values");
const { publicUser } = require("./users");
const { publicBaseUrl } = require("./media");


function requireAuth(auth) {
  if (!auth?.user) {
    return {
      success: false,
      code: "UNAUTHENTICATED",
      error: "Пользователь не авторизован",
    };
  }
  return null;
}

function requireAdmin(auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  const user = auth.user;
  if (user.role !== "admin") {
    return {
      success: false,
      code: "ADMIN_REQUIRED",
      error: "Недостаточно прав администратора",
    };
  }
  return null;
}

function paymentDocPath(payment) {
  return `payments/${payment.id}`;
}

function publicPayment(payment) {
  return {
    ...payment,
    paymentDocPath: paymentDocPath(payment),
    created_at: payment.createdAt || payment.created_at || null,
    paid_at: payment.paidAt || payment.paid_at || null,
    user_id: payment.userId || payment.user_id || null,
    payment_id: payment.paymentId || payment.payment_id || null,
  };
}

function withdrawalDocPath(withdrawal) {
  return `withdrawals/${withdrawal.id}`;
}

function publicWithdrawal(withdrawal) {
  return {
    ...withdrawal,
    withdrawalDocPath: withdrawalDocPath(withdrawal),
    withdraw_id: withdrawal.withdrawalId || withdrawal.withdraw_id || null,
    user_id: withdrawal.userId || withdrawal.user_id || null,
    card_number: withdrawal.cardNumber || withdrawal.card_number || null,
    created_at: withdrawal.createdAt || withdrawal.created_at || null,
    resolved_at: withdrawal.resolvedAt || withdrawal.resolved_at || null,
  };
}

function paymentProviderName(env = process.env) {
  return normalizeString(env.MTAXI_PAYMENT_PROVIDER || "local").toLowerCase();
}

function truthy(value) {
  const raw = normalizeString(value).toLowerCase();
  return raw === "true" || raw === "1" || raw === "yes";
}

function localPaymentPageEnabled(env = process.env) {
  const provider = paymentProviderName(env);
  if (provider !== "local" && provider !== "dev") {
    return false;
  }
  return env.NODE_ENV !== "production" || truthy(env.MTAXI_ALLOW_LOCAL_PAYMENT);
}

function renderPaymentUrlTemplate(template, values) {
  return normalizeString(template).replace(
    /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g,
    (_match, key) => encodeURIComponent(normalizeString(values[key])),
  );
}

function kassa24Credentials(env = process.env) {
  const login = normalizeString(
    env.MTAXI_KASSA24_LOGIN || env.KASSA24_LOGIN || env.MTAXI_KASSA24_MERCHANT_ID,
  );
  const password = normalizeString(env.MTAXI_KASSA24_PASSWORD || env.KASSA24_PASSWORD);
  const merchantId = normalizeString(env.MTAXI_KASSA24_MERCHANT_ID || env.KASSA24_MERCHANT_ID || login);
  const apiUrl = normalizeString(env.MTAXI_KASSA24_CREATE_URL || env.KASSA24_CREATE_URL) ||
    "https://ecommerce.pult24.kz/payment/create";
  return { login, password, merchantId, apiUrl };
}

function buildPaymentUrl(payment, req, env = process.env) {
  const provider = paymentProviderName(env);
  if (provider === "redirect") {
    const template = normalizeString(env.MTAXI_PAYMENT_URL_TEMPLATE);
    if (!template) {
      return "";
    }
    return renderPaymentUrlTemplate(template, {
      paymentId: payment.paymentId,
      amount: payment.amount,
      phone: payment.userPhone,
      publicBaseUrl: publicBaseUrl(req),
    });
  }
  return `${publicBaseUrl(req)}/local-payment/${payment.paymentId}`;
}

function paymentReturnUrl(payment, req, result = "pending") {
  const base = publicBaseUrl(req);
  const query = new URLSearchParams({
    kassa24PaymentCallback: "1",
    paymentId: payment.paymentId,
    result,
  });
  return `${base}/payments/kassa24/return?${query.toString()}`;
}

async function createKassa24PaymentUrl(payment, user, req, env = process.env) {
  const { login, password, merchantId, apiUrl } = kassa24Credentials(env);
  if (!login || !password || !merchantId) {
    return {
      success: false,
      code: "PAYMENT_PROVIDER_NOT_CONFIGURED",
      error: "Kassa24 не настроен: нужны MTAXI_KASSA24_LOGIN, MTAXI_KASSA24_PASSWORD и MTAXI_KASSA24_MERCHANT_ID",
    };
  }

  const amountTiyin = Math.round((asNumber(payment.amount) || 0) * 100);
  if (!Number.isFinite(amountTiyin) || amountTiyin <= 0) {
    return { success: false, code: "PAYMENT_AMOUNT_INVALID", error: "Введите корректную сумму" };
  }

  const callbackUrl = `${publicBaseUrl(req)}/payments/kassa24/callback`;
  const payload = {
    merchantId,
    amount: amountTiyin,
    orderId: payment.paymentId,
    description: `Пополнение баланса MTaxi на ${payment.amount} ₸`,
    callbackUrl,
    returnUrl: paymentReturnUrl(payment, req),
    successUrl: paymentReturnUrl(payment, req, "success"),
    failUrl: paymentReturnUrl(payment, req, "failed"),
    customerData: {
      phone: normalizeString(user.phone).replace(/^\+/, ""),
    },
    metadata: {
      paymentId: payment.paymentId,
      paymentDocPath: paymentDocPath(payment),
      userId: user.id,
    },
  };
  if (truthy(env.MTAXI_KASSA24_DEMO || env.KASSA24_DEMO)) {
    payload.demo = true;
  }

  let response;
  try {
    response = await fetch(apiUrl, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Basic ${Buffer.from(`${login}:${password}`).toString("base64")}`,
      },
      body: JSON.stringify(payload),
    });
  } catch (error) {
    return {
      success: false,
      code: "PAYMENT_PROVIDER_UNAVAILABLE",
      error: "Kassa24 сейчас не отвечает",
      details: error?.message,
    };
  }

  let body;
  try {
    body = await response.json();
  } catch (_) {
    body = {};
  }
  const paymentUrl = normalizeString(body.url);
  const providerPaymentId = normalizeString(body.id);
  if (!response.ok || !paymentUrl) {
    return {
      success: false,
      code: "PAYMENT_PROVIDER_REJECTED",
      error: normalizeString(body.message || body.error) || "Kassa24 не создал ссылку оплаты",
      status: response.status,
      providerResponse: body,
    };
  }

  return {
    success: true,
    paymentUrl: paymentUrl.startsWith("http") ? paymentUrl : `https://${paymentUrl}`,
    providerPaymentId,
    providerRequest: payload,
    providerResponse: body,
  };
}

function findPayment(store, paymentId) {
  const id = normalizeString(paymentId).split("/").filter(Boolean).pop();
  return store.payments.find((payment) =>
    payment.id === id ||
    payment.paymentId === id ||
    normalizeString(payment.providerPaymentId) === id);
}

function findWithdrawal(store, withdrawalId) {
  const id = normalizeString(withdrawalId).split("/").filter(Boolean).pop();
  return (store.withdrawals || []).find((withdrawal) =>
    withdrawal.id === id || withdrawal.withdrawalId === id);
}

function addLedger(store, entry) {
  store.ledger ||= [];
  const saved = {
    id: newId("ledger"),
    createdAt: new Date().toISOString(),
    ...entry,
  };
  store.ledger.push(saved);
  return saved;
}

async function createDriverTopUpPaymentAsync(data = {}, auth, req) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  const amount = asNumber(data.amount);
  if (amount == null || amount <= 0) {
    return { success: false, code: "PAYMENT_AMOUNT_INVALID", error: "Введите корректную сумму" };
  }

  return withStoreAsync(async (store) => createDriverTopUpPaymentInStore(store, data, auth, amount, req));
}

async function createPassengerTopUpPaymentAsync(data = {}, auth, req) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  const amount = asNumber(data.amount);
  if (!Number.isSafeInteger(amount) || amount <= 0 || amount > 1000000) return { success: false, code: 'PAYMENT_AMOUNT_INVALID', error: 'Введите сумму от 1 до 1 000 000 ₸' };
  return withStoreAsync(store => createDriverTopUpPaymentInStore(store, { ...data, method: 'kaspi_manual' }, auth, amount, req, 'passenger'));
}

async function createDriverTopUpPaymentInStore(store, data, auth, amount, req, purpose = "driver") {
  const user = store.users.find((item) => item.id === auth.user.id);
  if (!user) return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  if (purpose === "driver" && user.isDriver !== true) {
    return { success: false, code: "DRIVER_PROFILE_REQUIRED", error: "Пополнение доступно только водителю" };
  }
  const manualKaspi = data.method === 'kaspi_manual' || paymentProviderName() === 'kaspi_manual';
  const kaspiPhone = manualKaspi ? normalizePhone(data.kaspiPhone) : '';
  if (manualKaspi && !/^\+7\d{10}$/.test(kaspiPhone)) {
    return { success: false, code: 'KASPI_PHONE_INVALID', error: 'Укажите номер Kaspi в формате +7XXXXXXXXXX' };
  }
  store.payments ||= [];
  const idempotencyKey = normalizeString(data.idempotencyKey);
  if (idempotencyKey) {
    const existing = store.payments.find((payment) =>
      payment.userId === user.id && normalizeString(payment.idempotencyKey) === idempotencyKey);
    if (existing) {
      if ((asNumber(existing.amount) || 0) !== amount ||
          (manualKaspi && (existing.provider !== 'kaspi_manual' || existing.kaspiPhone !== kaspiPhone))) {
        return {
          success: false,
          code: "PAYMENT_IDEMPOTENCY_CONFLICT",
          error: "Повторный платеж с этим ключом имеет другую сумму",
          paymentId: existing.paymentId,
          paymentDocPath: paymentDocPath(existing),
          paymentStatus: existing.status,
        };
      }
      return {
        success: true,
        code: "PAYMENT_REUSED",
        reused: true,
        paymentId: existing.paymentId,
        paymentDocPath: paymentDocPath(existing),
        paymentUrl: existing.paymentUrl,
        paymentStatus: existing.status,
        amount: existing.amount,
        manual: existing.provider === 'kaspi_manual',
      };
    }
  }
  store.paymentSequence = (asNumber(store.paymentSequence) || 0) + 1;
  const payment = {
    id: newId("payment"),
    paymentId: newId(manualKaspi ? 'kaspi' : 'kassa24'),
    sequence: store.paymentSequence,
    purpose,
    userId: user.id,
    userPhone: user.phone,
    amount,
    status: "pending",
    provider: manualKaspi ? 'kaspi_manual' : paymentProviderName(),
    ...(manualKaspi ? { kaspiPhone, invoiceStatus: 'requested' } : {}),
    idempotencyKey,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  if (manualKaspi) {
    payment.paymentUrl = '';
  } else if (payment.provider === "kassa24") {
    const created = await createKassa24PaymentUrl(payment, user, req);
    if (!created.success) {
      return created;
    }
    payment.paymentUrl = created.paymentUrl;
    payment.providerPaymentId = created.providerPaymentId || null;
    payment.providerRequest = created.providerRequest;
    payment.providerResponse = created.providerResponse;
  } else {
    payment.paymentUrl = buildPaymentUrl(payment, req);
  }
  if (!payment.paymentUrl && !manualKaspi) {
    return {
      success: false,
      code: "PAYMENT_PROVIDER_NOT_CONFIGURED",
      error: "Платежный провайдер не настроен",
    };
  }
  store.payments.push(payment);
  if (manualKaspi) {
    const { createPushNotificationInStore } = require('./push');
    const queued = createPushNotificationInStore(store, {
      type: 'KASPI_TOPUP_REQUEST', targetRole: 'admin',
      targetUserIds: store.users.filter(item => item.role === 'admin' || item.roleState === 'ADMIN').map(item => item.id),
      title: 'Новая заявка на пополнение Kaspi',
      body: `${kaspiPhone}: ${amount} ₸. Выставьте счёт и подтвердите после оплаты.`,
      dedupeKey: `kaspi-request:${payment.paymentId}`,
      dataPayload: { type: 'KASPI_TOPUP_REQUEST', targetRole: 'admin',
        initialPageName: 'adminHome', paymentId: payment.paymentId },
    });
    if (queued.notification) queued.notification.dataPayload.notificationId = queued.notificationId;
  }
  addLedger(store, {
    type: "payment_created",
    userId: user.id,
    paymentId: payment.paymentId,
    amount,
    balanceBefore: asNumber(user.balance) || 0,
    balanceAfter: asNumber(user.balance) || 0,
  });
  return {
    success: true,
    code: "PAYMENT_CREATED",
    paymentId: payment.paymentId,
    paymentDocPath: paymentDocPath(payment),
    paymentUrl: payment.paymentUrl,
    paymentStatus: payment.status,
    amount,
    manual: manualKaspi,
  };
}

function applySuccessfulPayment(store, payment, { source = "status" } = {}) {
  const user = store.users.find((item) => item.id === payment.userId);
  if (!user) {
    return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  }
  if (payment.status === "success" && payment.applied === true) {
    return { success: true, alreadyApplied: true, user };
  }
  const before = asNumber(user.balance) || 0;
  const amount = asNumber(payment.amount) || 0;
  user.balance = before + amount;
  user.balanceUpdatedAt = new Date().toISOString();
  payment.status = "success";
  payment.applied = true;
  payment.paidAt = new Date().toISOString();
  payment.updatedAt = new Date().toISOString();
  addLedger(store, {
    type: "driver_top_up",
    source,
    userId: user.id,
    paymentId: payment.paymentId,
    amount,
    balanceBefore: before,
    balanceAfter: user.balance,
  });
  return { success: true, alreadyApplied: false, user };
}

async function getDriverTopUpPaymentStatusAsync(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => getDriverTopUpPaymentStatusInStore(store, data, auth));
}

function getDriverTopUpPaymentStatusInStore(store, data, auth) {
  const payment = findPayment(store, data.paymentId);
  if (!payment) return { success: false, code: "PAYMENT_NOT_FOUND", error: "Платеж не найден" };
  if (payment.userId !== auth.user.id) {
    return { success: false, code: "PAYMENT_FORBIDDEN", error: "Нет доступа к платежу" };
  }
  const user = store.users.find((item) => item.id === auth.user.id);
  return {
    success: true,
    code: "PAYMENT_STATUS",
    paymentId: payment.paymentId,
    paymentStatus: payment.status,
    amount: payment.amount,
    paidAt: payment.paidAt || null,
    user: publicUser(user),
    balance: user ? asNumber(user.balance) || 0 : 0,
  };
}

async function confirmDriverTopUpPaymentAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => confirmDriverTopUpPaymentInStore(store, data, auth));
}

async function adminMarkKaspiInvoiceSentAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async store => {
    const payment = findPayment(store, data.paymentId);
    if (!payment || payment.provider !== 'kaspi_manual' || payment.status !== 'pending') {
      return { success: false, code: 'PAYMENT_NOT_PENDING', error: 'Заявка недоступна' };
    }
    payment.invoiceStatus = 'sent';
    payment.invoiceSentAt = payment.invoiceSentAt || new Date().toISOString();
    payment.invoiceSentBy = auth.user.id;
    payment.updatedAt = new Date().toISOString();
    return { success: true, code: 'KASPI_INVOICE_SENT', payment: publicPayment(payment) };
  });
}

function confirmDriverTopUpPaymentInStore(store, data, auth) {
  const payment = findPayment(store, data.paymentId);
  if (!payment) return { success: false, code: "PAYMENT_NOT_FOUND", error: "Платеж не найден" };
  if (payment.status === 'failed') return { success: false, code: 'PAYMENT_FAILED', error: 'Заявка отклонена' };
  const applied = applySuccessfulPayment(store, payment, { source: "admin_confirm" });
  if (!applied.success) return applied;
  if (!applied.alreadyApplied) {
    payment.confirmedBy = auth?.user?.id || null;
    store.auditLogs ||= [];
    store.auditLogs.push({ id: newId('audit'), action: 'confirmDriverTopUpPayment',
      target: paymentDocPath(payment), adminId: auth?.user?.id,
      after: { amount: payment.amount, status: payment.status }, createdAt: new Date().toISOString() });
  }
  return {
    success: true,
    code: applied.alreadyApplied ? "PAYMENT_ALREADY_APPLIED" : "PAYMENT_CONFIRMED",
    paymentId: payment.paymentId,
    paymentStatus: payment.status,
    user: publicUser(applied.user),
    balance: applied.user.balance,
  };
}

async function failDriverTopUpPaymentAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => failDriverTopUpPaymentInStore(store, data));
}

function failDriverTopUpPaymentInStore(store, data) {
  const payment = findPayment(store, data.paymentId);
  if (!payment) return { success: false, code: "PAYMENT_NOT_FOUND", error: "Платеж не найден" };
  if (payment.applied === true) {
    return { success: false, code: "PAYMENT_ALREADY_APPLIED", error: "Платеж уже зачислен" };
  }
  payment.status = "failed";
  payment.failedAt = new Date().toISOString();
  payment.updatedAt = new Date().toISOString();
  addLedger(store, {
    type: "payment_failed",
    userId: payment.userId,
    paymentId: payment.paymentId,
    amount: payment.amount,
    balanceBefore: null,
    balanceAfter: null,
  });
  return {
    success: true,
    code: "PAYMENT_FAILED",
    paymentId: payment.paymentId,
    paymentStatus: payment.status,
  };
}

function normalizePaymentCallbackStatus(data = {}) {
  const status = normalizeString(data.status || data.paymentStatus || data.result || data.state)
    .toLowerCase();
  if (["success", "paid", "approved", "completed", "ok", "1", "true"].includes(status)) {
    return "success";
  }
  if (["failed", "fail", "declined", "cancelled", "canceled", "error", "0", "false"].includes(status)) {
    return "failed";
  }
  return "";
}

function callbackSecretMatches(data = {}, req) {
  const expected = normalizeString(process.env.MTAXI_PAYMENT_CALLBACK_SECRET);
  if (!expected) return true;
  const allowBodySecret =
    normalizeString(process.env.MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY)
      .toLowerCase() === "true";
  const provided = normalizeString(
    req?.get?.("x-mtaxi-payment-secret") ||
      req?.get?.("x-kassa24-secret") ||
      (allowBodySecret ? data.secret || data.token || data.callbackSecret : ""),
  );
  return provided === expected;
}

async function handleDriverTopUpPaymentCallbackAsync(data = {}, req) {
  if (!callbackSecretMatches(data, req)) {
    return { success: false, code: "PAYMENT_CALLBACK_FORBIDDEN", error: "Неверная подпись платежа" };
  }
  const paymentId = normalizeString(
    data.paymentId ||
      data.payment_id ||
      data.invoiceId ||
      data.orderId ||
      data.order_id ||
      data.id ||
      data.transactionId ||
      data.transaction_id,
  );
  if (!paymentId) {
    return { success: false, code: "PAYMENT_ID_REQUIRED", error: "Не указан платеж" };
  }
  const normalizedStatus = normalizePaymentCallbackStatus(data);
  if (!normalizedStatus) {
    return { success: false, code: "PAYMENT_STATUS_INVALID", error: "Некорректный статус платежа" };
  }
  return withStoreAsync(async (store) => {
    const payment = findPayment(store, paymentId);
    if (!payment) return { success: false, code: "PAYMENT_NOT_FOUND", error: "Платеж не найден" };
    if (payment.provider === 'kaspi_manual') {
      return { success: false, code: 'MANUAL_PAYMENT_CONFIRMATION_REQUIRED', error: 'Ручную оплату Kaspi подтверждает администратор' };
    }
    if (data.amount != null && asNumber(data.amount) !== asNumber(payment.amount)) {
      return { success: false, code: 'PAYMENT_AMOUNT_MISMATCH', error: 'Сумма оплаты не совпадает со счётом' };
    }
    if (data.currency != null && normalizeString(data.currency).toUpperCase() !== 'KZT') {
      return { success: false, code: 'PAYMENT_CURRENCY_MISMATCH', error: 'Валюта оплаты не совпадает со счётом' };
    }
    if (data.userId != null && normalizeString(data.userId) !== payment.userId) {
      return { success: false, code: 'PAYMENT_USER_MISMATCH', error: 'Получатель платежа не совпадает со счётом' };
    }
    if (normalizedStatus === "success") {
      const applied = applySuccessfulPayment(store, payment, { source: "kassa24_callback" });
      if (!applied.success) return applied;
      return {
        success: true,
        code: applied.alreadyApplied ? "PAYMENT_ALREADY_APPLIED" : "PAYMENT_CONFIRMED",
        paymentId: payment.paymentId,
        paymentStatus: payment.status,
        user: publicUser(applied.user),
        balance: applied.user.balance,
      };
    }
    return failDriverTopUpPaymentInStore(store, { paymentId });
  });
}

async function createDriverWithdrawalAsync(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  const amount = asNumber(data.amount);
  const cardNumber = normalizeString(data.cardNumber || data.card_number || data.cart);
  if (amount == null || amount <= 0) {
    return { success: false, code: "WITHDRAWAL_AMOUNT_INVALID", error: "Введите корректную сумму" };
  }
  if (!cardNumber || cardNumber.replace(/\D/g, "").length < 12) {
    return { success: false, code: "WITHDRAWAL_CARD_INVALID", error: "Введите корректный номер карты" };
  }

  return withStoreAsync(async (store) => createDriverWithdrawalInStore(store, auth, amount, cardNumber));
}

function createDriverWithdrawalInStore(store, auth, amount, cardNumber) {
  const user = store.users.find((item) => item.id === auth.user.id);
  if (!user) return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  if (user.isDriver !== true) {
    return { success: false, code: "DRIVER_PROFILE_REQUIRED", error: "Вывод доступен только водителю" };
  }
  const before = asNumber(user.balance) || 0;
  if (before < amount) {
    return { success: false, code: "BALANCE_NOT_ENOUGH", error: "Недостаточно средств" };
  }
  store.withdrawals ||= [];
  const withdrawal = {
    id: newId("withdrawal"),
    withdrawalId: newId("wd"),
    userId: user.id,
    userPhone: user.phone,
    cardNumber,
    amount,
    status: "pending",
    provider: "local-kassa24",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  store.withdrawals.push(withdrawal);
  addLedger(store, {
    type: "withdrawal_requested",
    userId: user.id,
    withdrawalId: withdrawal.withdrawalId,
    amount,
    balanceBefore: before,
    balanceAfter: before,
  });
  return {
    success: true,
    code: "WITHDRAWAL_CREATED",
    withdrawalId: withdrawal.withdrawalId,
    withdraw_id: withdrawal.withdrawalId,
    withdrawalDocPath: withdrawalDocPath(withdrawal),
    status: withdrawal.status,
    message: "Заявка на вывод создана",
    withdrawal: publicWithdrawal(withdrawal),
  };
}

async function adminListWithdrawalsAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  const status = normalizeString(data.status).toLowerCase();
  const query = normalizeString(data.query).toLowerCase();
  const limit = Math.max(1, Math.min(asNumber(data.limit) || 200, 1000));
  return withStoreAsync(async (store) => {
    const withdrawals = [...(store.withdrawals || [])]
      .filter((withdrawal) => {
        if (status && normalizeString(withdrawal.status).toLowerCase() !== status) return false;
        if (!query) return true;
        return [
          withdrawal.id,
          withdrawal.withdrawalId,
          withdrawal.userId,
          withdrawal.userPhone,
          withdrawal.cardNumber,
          withdrawal.status,
          withdrawal.amount,
        ].some((value) => normalizeString(value).toLowerCase().includes(query));
      })
      .sort((a, b) => {
        const byDate =
          (asDate(b.resolvedAt || b.updatedAt || b.createdAt) || new Date(0)) -
          (asDate(a.resolvedAt || a.updatedAt || a.createdAt) || new Date(0));
        return byDate;
      })
      .slice(0, limit)
      .map(publicWithdrawal);
    return { success: true, code: "ADMIN_WITHDRAWALS", count: withdrawals.length, withdrawals };
  });
}

async function adminResolveWithdrawalAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  const action = normalizeString(data.action || data.status).toLowerCase();
  if (!["approve", "approved", "reject", "rejected", "fail", "failed"].includes(action)) {
    return { success: false, code: "WITHDRAWAL_ACTION_INVALID", error: "Неверное действие" };
  }
  return withStoreAsync(async (store) => {
    const withdrawal = findWithdrawal(store, data.withdrawalId || data.withdraw_id);
    if (!withdrawal) return { success: false, code: "WITHDRAWAL_NOT_FOUND", error: "Заявка не найдена" };
    if (normalizeString(withdrawal.status).toLowerCase() !== "pending") {
      return { success: true, code: "WITHDRAWAL_ALREADY_RESOLVED", withdrawal: publicWithdrawal(withdrawal) };
    }
    const user = store.users.find((item) => item.id === withdrawal.userId);
    if (!user) return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
    const approve = ["approve", "approved"].includes(action);
    const before = asNumber(user.balance) || 0;
    if (approve) {
      const amount = asNumber(withdrawal.amount) || 0;
      if (before < amount) {
        return { success: false, code: "BALANCE_NOT_ENOUGH", error: "Недостаточно средств" };
      }
      user.balance = before - amount;
      user.balanceUpdatedAt = new Date().toISOString();
      withdrawal.status = "success";
      addLedger(store, {
        type: "driver_withdrawal",
        userId: user.id,
        withdrawalId: withdrawal.withdrawalId,
        amount,
        balanceBefore: before,
        balanceAfter: user.balance,
      });
    } else {
      withdrawal.status = "rejected";
      addLedger(store, {
        type: "withdrawal_rejected",
        userId: user.id,
        withdrawalId: withdrawal.withdrawalId,
        amount: withdrawal.amount,
        balanceBefore: before,
        balanceAfter: before,
      });
    }
    withdrawal.resolvedAt = new Date().toISOString();
    withdrawal.updatedAt = withdrawal.resolvedAt;
    withdrawal.resolvedBy = auth.user.id;
    withdrawal.adminComment = normalizeString(data.comment);
    return {
      success: true,
      code: approve ? "WITHDRAWAL_APPROVED" : "WITHDRAWAL_REJECTED",
      withdrawal: publicWithdrawal(withdrawal),
      user: publicUser(user),
      balance: user.balance,
    };
  });
}

function paymentSortDate(payment) {
  return asDate(payment.paidAt || payment.paid_at || payment.updatedAt || payment.updated_at || payment.createdAt || payment.created_at) || new Date(0);
}

async function adminListPaymentsAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  const status = normalizeString(data.status).toLowerCase();
  const userId = normalizeString(data.userId || data.user_id);
  const query = normalizeString(data.query).toLowerCase();
  const limit = Math.max(1, Math.min(asNumber(data.limit) || 200, 1000));

  return withStoreAsync(async (store) => {
    const payments = [...(store.payments || [])]
      .filter((payment) => {
        if (status && normalizeString(payment.status).toLowerCase() !== status) return false;
        if (userId && normalizeString(payment.userId || payment.user_id) !== userId) return false;
        if (!query) return true;
        return [
          payment.id,
          payment.paymentId,
          payment.payment_id,
          payment.userId,
          payment.user_id,
          payment.userPhone,
          payment.kaspiPhone,
          payment.status,
          payment.provider,
          payment.amount,
        ].some((value) => normalizeString(value).toLowerCase().includes(query));
      })
      .sort((a, b) => {
        const byDate = paymentSortDate(b) - paymentSortDate(a);
        if (byDate !== 0) return byDate;
        return (asNumber(b.sequence) || 0) - (asNumber(a.sequence) || 0);
      })
      .slice(0, limit)
      .map(publicPayment);

    return {
      success: true,
      code: "ADMIN_PAYMENTS",
      pendingKaspiCount: (store.payments || []).filter(payment => payment.provider === 'kaspi_manual' && payment.status === 'pending').length,
      count: payments.length,
      payments,
    };
  });
}

async function getMoneyStatsAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  const from = asDate(data.from);
  const to = asDate(data.to);
  return readStoreAsync().then(async (store) => {
    const ledger = (store.ledger || []).filter((entry) => {
      const date = asDate(entry.createdAt);
      if (!date) return false;
      if (from && date < from) return false;
      if (to && date > to) return false;
      return true;
    });
    const byType = {};
    let topUps = 0;
    let orderCommissions = 0;
    let refunds = 0;
    let failedTopUps = 0;
    let pendingTopUps = 0;
    let withdrawals = 0;
    let pendingWithdrawals = 0;
    for (const entry of ledger) {
      const amount = asNumber(entry.amount) || 0;
      byType[entry.type] = (byType[entry.type] || 0) + amount;
      if (entry.type === "driver_top_up") topUps += amount;
      if (entry.type === "order_commission") orderCommissions += amount;
      if (entry.type.includes("refund")) refunds += amount;
      if (entry.type === "payment_failed") failedTopUps += amount;
      if (entry.type === "driver_withdrawal") withdrawals += amount;
    }
    for (const payment of store.payments || []) {
      const status = normalizeString(payment.status).toLowerCase();
      if (status === "pending") pendingTopUps += asNumber(payment.amount) || 0;
    }
    for (const withdrawal of store.withdrawals || []) {
      const status = normalizeString(withdrawal.status).toLowerCase();
      if (status === "pending") pendingWithdrawals += asNumber(withdrawal.amount) || 0;
    }
    const driverBalances = [...(store.users || [])]
      .filter((user) => user.isDriver === true || normalizeString(user.statusDriver))
      .map((user) => ({
        userId: user.id,
        name: normalizeString(user.displayName || `${normalizeString(user.firstName)} ${normalizeString(user.lastName)}`),
        phone: normalizeString(user.phone),
        balance: asNumber(user.balance) || 0,
      }))
      .sort((a, b) => b.balance - a.balance);
    const totalDriverBalance = driverBalances.reduce((sum, user) => sum + user.balance, 0);
    const negativeDriverBalance = driverBalances
      .filter((user) => user.balance < 0)
      .reduce((sum, user) => sum + user.balance, 0);
    return {
      success: true,
      code: "MONEY_STATS",
      period: {
        from: from ? from.toISOString() : null,
        to: to ? to.toISOString() : null,
      },
      totals: {
        ledgerCount: ledger.length,
        paymentsCount: (store.payments || []).length,
        topUps,
        pendingTopUps,
        failedTopUps,
        withdrawals,
        pendingWithdrawals,
        orderCommissions,
        refunds,
        totalDriverBalance,
        negativeDriverBalance,
        driversWithBalance: driverBalances.filter((user) => user.balance !== 0).length,
      },
      byType,
      ledger,
      payments: store.payments || [],
      withdrawals: store.withdrawals || [],
      driverBalances,
    };
  });
}

module.exports = {
  adminMarkKaspiInvoiceSentAsync,
  createDriverTopUpPaymentAsync,
  createPassengerTopUpPaymentAsync,
  getDriverTopUpPaymentStatusAsync,
  confirmDriverTopUpPaymentAsync,
  failDriverTopUpPaymentAsync,
  handleDriverTopUpPaymentCallbackAsync,
  createDriverWithdrawalAsync,
  adminListWithdrawalsAsync,
  adminResolveWithdrawalAsync,
  adminListPaymentsAsync,
  getMoneyStatsAsync,
  addLedger,
  buildPaymentUrl,
  localPaymentPageEnabled,
};
