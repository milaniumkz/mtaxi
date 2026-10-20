const crypto = require("crypto");
const { readStoreAsync, withStoreAsync, newId } = require("./store");
const { normalizePhone, normalizeString } = require("./utils/values");
const { publicUser } = require("./users");
const { isPasswordHash, setUserPassword, verifyPassword } = require("./passwords");
const { sendSmsCode } = require("./sms_provider");

const smsSessions = new Map();

function tokenSecret() {
  return process.env.MTAXI_TOKEN_SECRET || "mtaxi-local-dev-secret";
}

function smsCodeTtlMs() {
  const value = Number(process.env.MTAXI_SMS_CODE_TTL_SEC);
  return Number.isFinite(value) && value > 0 ? value * 1000 : 5 * 60 * 1000;
}

function smsResendCooldownMs() {
  const value = Number(process.env.MTAXI_SMS_RESEND_COOLDOWN_SEC);
  return Number.isFinite(value) && value >= 0 ? value * 1000 : 30 * 1000;
}

function shouldReturnDevSmsCode() {
  const raw = normalizeString(process.env.MTAXI_SMS_DEV_RETURN_CODE).toLowerCase();
  if (raw) {
    return raw === "true" || raw === "1" || raw === "yes";
  }
  return process.env.NODE_ENV !== "production";
}

function smsFallbackCodeOnFailureEnabled() {
  const raw = normalizeString(process.env.MTAXI_SMS_FALLBACK_CODE_ON_FAILURE).toLowerCase();
  if (raw) {
    return raw === "true" || raw === "1" || raw === "yes";
  }
  return process.env.NODE_ENV !== "production";
}

function queueSmsFallbackPushInStore(store, user, smsCode, delivery) {
  if (!user?.id) return { notificationId: null, numTargetTokens: 0 };
  store.fcmTokens ||= [];
  store.notifications ||= [];
  store.notificationDeliveries ||= [];

  const tokens = store.fcmTokens.filter((token) => token.userId === user.id && token.disabled !== true);
  const now = new Date().toISOString();
  const notification = {
    id: newId("push"),
    title: "MTaxi SMS-код",
    body: `Ваш код: ${smsCode}`,
    type: "SMS_CODE_FALLBACK",
    initialPageName: "smsVirefication",
    parameterData: {},
    dataPayload: {
      type: "SMS_CODE_FALLBACK",
      smsCode,
      phone: user.phone,
      provider: delivery?.provider || "",
      providerError: delivery?.error || "",
    },
    targetRole: "all",
    targetAudience: "all",
    targetDeviceType: "All",
    targetUserIds: [user.id],
    excludeUserIds: [],
    orderAlert: false,
    dedupeKey: `sms:${user.id}:${smsCode}`,
    createdBy: null,
    createdAt: now,
    sentAtMs: Date.now(),
    firebaseDeliveryMode: "simulated-local",
    numTargetTokens: tokens.length,
  };
  store.notifications.push(notification);
  const deliveries = tokens.map((token) => ({
    id: newId("delivery"),
    notificationId: notification.id,
    tokenId: token.id,
    userId: user.id,
    status: "queued",
    createdAt: now,
  }));
  store.notificationDeliveries.push(...deliveries);
  return { notificationId: notification.id, numTargetTokens: deliveries.length };
}

function base64url(input) {
  return Buffer.from(input).toString("base64url");
}

function sign(payload) {
  return crypto
    .createHmac("sha256", tokenSecret())
    .update(payload)
    .digest("base64url");
}

function hashSmsCode(phone, code) {
  return crypto
    .createHmac("sha256", tokenSecret())
    .update(`${normalizePhone(phone)}:${normalizeString(code)}`)
    .digest("hex");
}

function smsCodeMatches(record, phone, code) {
  const storedHash = normalizeString(record?.smsCodeHash || record?.codeHash);
  if (storedHash) {
    return storedHash === hashSmsCode(phone, code);
  }
  return normalizeString(record?.smsCode || record?.code) === normalizeString(code);
}

function createAccessToken(user) {
  const header = base64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = base64url(JSON.stringify({
    sub: user.id,
    phone: user.phone,
    exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30,
  }));
  return `${header}.${body}.${sign(`${header}.${body}`)}`;
}

function verifyAccessToken(token) {
  try {
    const parts = normalizeString(token).split(".");
    if (parts.length !== 3) return null;
    const [header, body, signature] = parts;
    if (sign(`${header}.${body}`) !== signature) return null;
    const payload = JSON.parse(Buffer.from(body, "base64url").toString("utf8"));
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) return null;
    return payload;
  } catch (_) {
    return null;
  }
}

async function findUserByPhoneAsync(phone) {
  const normalized = normalizePhone(phone);
  const store = await readStoreAsync();
  return store.users.find((user) => normalizePhone(user.phone) === normalized) || null;
}

async function findUserByIdAsync(id) {
  const store = await readStoreAsync();
  return store.users.find((user) => user.id === id) || null;
}

async function passwordLogin(data = {}) {
  const phone = normalizePhone(data.phone || data.uid);
  const password = normalizeString(data.password || data.driverPassword);
  return withStoreAsync(async (store) => {
    const user = store.users.find((item) => normalizePhone(item.phone) === phone);
    if (!user) {
      return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
    }
    if (!verifyPassword(password, user.passwordHash || user.password)) {
      return { success: false, code: "PASSWORD_INVALID", error: "Неверный пароль" };
    }
    if (!user.passwordHash || !isPasswordHash(user.passwordHash)) {
      setUserPassword(user, password);
      user.updatedAt = new Date().toISOString();
    }
    return {
      success: true,
      token: createAccessToken(user),
      userId: user.id,
      userDocPath: `users/${user.id}`,
      user: publicUser(user),
    };
  });
}

async function lookupUserByPhone(data = {}) {
  const phone = normalizePhone(data.phone || data.uid || data.phoneNumber);
  if (!phone) {
    return { success: false, code: "PHONE_REQUIRED", error: "Введите номер телефона" };
  }
  const user = await findUserByPhoneAsync(phone);
  return {
    success: true,
    code: user ? "USER_FOUND" : "USER_NOT_FOUND",
    found: Boolean(user),
    userId: user?.id || null,
    userDocPath: user ? `users/${user.id}` : null,
    user: publicUser(user),
  };
}

async function createSmsSession(data = {}) {
  const phone = normalizePhone(data.phone || data.uid || data.phoneNumber);
  if (!phone) {
    return { success: false, code: "PHONE_REQUIRED", error: "Введите номер телефона" };
  }
  return withStoreAsync(async (store) => {
    const nowMs = Date.now();
    const verifiedCode = (store.smsCodes || [])
      .filter((item) => normalizePhone(item.phone) === phone)
      .sort((a, b) => new Date(b.verifiedAt || b.createdAt || 0) - new Date(a.verifiedAt || a.createdAt || 0))
      .find((item) => item.status === "verified");
    if (!verifiedCode) {
      return {
        success: false,
        code: "SMS_CODE_NOT_VERIFIED",
        error: "Подтвердите SMS-код",
      };
    }
    if (new Date(verifiedCode.expiresAt || 0).getTime() < nowMs) {
      verifiedCode.status = "expired";
      return {
        success: false,
        code: "SMS_CODE_EXPIRED",
        error: "SMS-код истек. Отправьте новый код.",
      };
    }
    let user = store.users.find((item) => normalizePhone(item.phone) === phone);
    if (!user) {
      const digits = phone.replace(/\D/g, "");
      const now = new Date().toISOString();
      user = {
        id: `u_passenger_${digits}`,
        phone,
        password: "",
        displayName: "",
        city: "",
        role: "passenger",
        roleState: "PASSENGER",
        activeMode: "passenger",
        preferredClientMode: "passenger",
        isDriver: false,
        balance: 0,
        profileCompleted: false,
        registrationDraft: false,
        createdAt: now,
        updatedAt: now,
      };
      store.users.push(user);
    }
    verifiedCode.status = "consumed";
    verifiedCode.consumedAt = new Date(nowMs).toISOString();
    return {
      success: true,
      code: "SMS_SESSION_CREATED",
      token: createAccessToken(user),
      userId: user.id,
      userDocPath: `users/${user.id}`,
      user: publicUser(user),
    };
  });
}

async function requestSmsCode(data = {}) {
  const phone = normalizePhone(data.phone || data.uid || data.phoneNumber);
  if (!phone) {
    return { success: false, code: "PHONE_REQUIRED", error: "Введите номер телефона" };
  }
  const nowMs = Date.now();
  const existing = smsSessions.get(phone);
  const cooldownMs = smsResendCooldownMs();
  if (existing && cooldownMs > 0 && nowMs - existing.createdAt < cooldownMs) {
    return {
      success: false,
      code: "SMS_RATE_LIMITED",
      error: "Код уже отправлен. Попробуйте позже.",
      retryAfterSec: Math.ceil((cooldownMs - (nowMs - existing.createdAt)) / 1000),
    };
  }

  const smsCode = String(crypto.randomInt(1000, 10000));
  const expiresAtMs = nowMs + smsCodeTtlMs();
  const delivery = await sendSmsCode({ phone, code: smsCode });
  const fallbackEnabled = smsFallbackCodeOnFailureEnabled();
  if (!delivery.ok && !fallbackEnabled) {
    return {
      success: false,
      code: "SMS_DELIVERY_FAILED",
      error: "Не удалось отправить SMS-код. Попробуйте позже.",
    };
  }
  smsSessions.set(phone, {
    code: smsCode,
    createdAt: nowMs,
    expiresAt: expiresAtMs,
  });
  return withStoreAsync(async (store) => {
    store.smsCodes = (store.smsCodes || [])
      .filter((item) => normalizePhone(item.phone) !== phone);
    const fallbackUser = delivery.ok
      ? null
      : (store.users || []).find((user) => normalizePhone(user.phone) === phone);
    const fallbackPush = delivery.ok
      ? { notificationId: null, numTargetTokens: 0 }
      : queueSmsFallbackPushInStore(store, fallbackUser, smsCode, delivery);
    store.smsCodes.push({
      id: `sms_${phone.replace(/\D/g, "")}_${nowMs}`,
      phone,
      smsCodeHash: hashSmsCode(phone, smsCode),
      provider: delivery.provider || "local",
      status: delivery.ok ? "sent" : "fallback",
      providerMessageId: delivery.providerMessageId || null,
      providerStatusCode: delivery.statusCode || null,
      providerError: delivery.error || "",
      fallbackUsed: !delivery.ok,
      fallbackPushNotificationId: fallbackPush.notificationId,
      createdAt: new Date(nowMs).toISOString(),
      expiresAt: new Date(expiresAtMs).toISOString(),
    });
    const response = {
      success: true,
      code: delivery.ok ? "SMS_CODE_CREATED" : "SMS_CODE_CREATED_FALLBACK",
      phone,
      smsDeliveryFallback: !delivery.ok,
      smsDeliveryProvider: delivery.provider || "",
      smsFallbackPushQueued: fallbackPush.numTargetTokens > 0,
      smsFallbackPushTokens: fallbackPush.numTargetTokens,
    };
    if (shouldReturnDevSmsCode() || !delivery.ok) {
      response.smsCode = smsCode;
      response.devCode = smsCode;
      response.devOnly = true;
    }
    return response;
  });
}

async function verifySmsCode(data = {}) {
  const phone = normalizePhone(data.phone || data.uid || data.phoneNumber);
  const smsCode = normalizeString(data.smsCode || data.code);
  if (!phone) {
    return { success: false, code: "PHONE_REQUIRED", error: "Введите номер телефона" };
  }
  if (!smsCode) {
    return { success: false, code: "SMS_CODE_REQUIRED", error: "Введите SMS-код" };
  }
  const nowMs = Date.now();
  return withStoreAsync(async (store) => {
    const latest = (store.smsCodes || [])
      .filter((item) => normalizePhone(item.phone) === phone)
      .sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0))[0];
    if (!latest || latest.status === "verified") {
      return { success: false, code: "SMS_CODE_EXPIRED", error: "SMS-код истек. Отправьте новый код." };
    }
    if (new Date(latest.expiresAt || 0).getTime() < nowMs) {
      latest.status = "expired";
      return { success: false, code: "SMS_CODE_EXPIRED", error: "SMS-код истек. Отправьте новый код." };
    }
    if (!smsCodeMatches(latest, phone, smsCode)) {
      return { success: false, code: "SMS_CODE_INVALID", error: "Неверный SMS-код" };
    }
    latest.status = "verified";
    latest.verifiedAt = new Date(nowMs).toISOString();
    smsSessions.delete(phone);
    return {
      success: true,
      code: "SMS_CODE_VERIFIED",
      phone,
    };
  });
}

async function verifyBearerToken(req) {
  const header = normalizeString(req?.get?.("authorization"));
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) return null;
  const payload = verifyAccessToken(match[1]);
  if (!payload?.sub) return null;
  const user = await findUserByIdAsync(payload.sub);
  return user ? { uid: user.id, phone: user.phone, user } : null;
}

module.exports = {
  passwordLogin,
  lookupUserByPhone,
  requestSmsCode,
  verifySmsCode,
  createSmsSession,
  verifyBearerToken,
  findUserByIdAsync,
  findUserByPhoneAsync,
  hashSmsCode,
  tokenSecret,
};
