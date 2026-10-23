const crypto = require("crypto");
const { readStoreAsync, withStoreAsync, newId, lookupUserByIdAsync } = require("./store");
const { normalizePhone, normalizeString } = require("./utils/values");
const { publicUser } = require("./users");
const { isPasswordHash, setUserPassword, verifyPassword } = require("./passwords");


function tokenSecret() {
  return process.env.MTAXI_TOKEN_SECRET || "mtaxi-local-dev-secret";
}

function smsAuthDisabled() {
  return { success: false, code: "SMS_AUTH_DISABLED", error: "Вход по SMS отключён. Используйте номер телефона и пароль." };
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

function createAccessToken(user) {
  const header = base64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = base64url(JSON.stringify({
    sub: user.id,
    phone: user.phone,
    pv: user.authVersion || "",
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
  if (lookupUserByIdAsync) return lookupUserByIdAsync(id);
  const store = await readStoreAsync();
  return store.users.find((user) => user.id === id) || null;
}

async function passwordLogin(data = {}) {
  const phone = normalizePhone(data.phone || data.uid);
  const password = normalizeString(data.password || data.driverPassword);
  return withStoreAsync(async (store) => {
    const user = store.users.find((item) => normalizePhone(item.phone) === phone);
    if (!user) {
      return { success: false, code: "PASSWORD_INVALID", error: "Неверный номер телефона или пароль" };
    }
    if (!verifyPassword(password, user.passwordHash || user.password)) {
      return { success: false, code: "PASSWORD_INVALID", error: "Неверный номер телефона или пароль" };
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

  };
}

async function registerWithPassword(data = {}) {
  const phone = normalizePhone(data.phone);
  const password = normalizeString(data.password);
  if (!/^\+7\d{10}$/.test(phone)) {
    return { success: false, code: "PHONE_INVALID", error: "Введите номер телефона в формате +7 и 10 цифр" };
  }
  if (password.length < 8 || password.length > 128) {
    return { success: false, code: "PASSWORD_LENGTH_INVALID", error: "Пароль должен содержать от 8 до 128 символов" };
  }
  if (["+70000000000", normalizePhone(process.env.MTAXI_ADMIN_PHONE)].includes(phone)) {
    return { success: false, code: "PHONE_RESERVED", error: "Для доступа с этим номером обратитесь к администратору." };
  }
  return withStoreAsync(async store => {
    if (store.users.some(user => normalizePhone(user.phone) === phone)) {
      return { success: false, code: "ACCOUNT_EXISTS", error: "Номер уже зарегистрирован. Войдите с паролем или обратитесь к администратору." };
    }
    const now = new Date().toISOString();
    const user = {
      id: newId("user"), phone, displayName: "", city: "",
      role: "passenger", roleState: "PASSENGER", activeMode: "passenger",
      preferredClientMode: "passenger", isDriver: false, balance: 0,
      phoneVerified: false, profileCompleted: false, registrationDraft: false,
      createdAt: now, updatedAt: now,
    };
    setUserPassword(user, password);
    store.users.push(user);
    return { success: true, token: createAccessToken(user), userId: user.id,
      userDocPath: `users/${user.id}`, user: publicUser(user) };
  });
}

async function createSmsSession() { return smsAuthDisabled(); }
async function requestSmsCode() { return smsAuthDisabled(); }
async function verifySmsCode() { return smsAuthDisabled(); }

async function verifyBearerToken(req) {
  const header = normalizeString(req?.get?.("authorization"));
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) return null;
  const payload = verifyAccessToken(match[1]);
  if (!payload?.sub) return null;
  const user = await findUserByIdAsync(payload.sub);
  return user && (payload.pv || "") === (user.authVersion || "")
    ? { uid: user.id, phone: user.phone, user } : null;
}

module.exports = {
  registerWithPassword,
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
