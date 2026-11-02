const { withStoreAsync, newId } = require("./store");
const { preferencesScope } = require("./store/scopes");
const { asNumber, normalizePhone, normalizeString } = require("./utils/values");
const { hasUserPassword, setUserPassword } = require("./passwords");

const ALLOWED_ROLE_STATES = new Set([
  "PASSENGER",
  "DRIVER_PENDING",
  "DRIVER_OFFLINE",
  "DRIVER_ONLINE",
  "DRIVER_ON_TRIP",
  "DRIVER_PENDING_REVIEW",
  "BLOCKED",
]);

function normalizeRoleState(value) {
  const normalized = normalizeString(value).toUpperCase();
  if (normalized === "DRIVER_PENDING_REVIEW") return "DRIVER_PENDING";
  return normalized;
}

function publicUser(user) {
  if (!user) return null;
  const { password: _password, passwordHash: _passwordHash, ...safe } = user;
  if (safe.roleState) safe.roleState = normalizeRoleState(safe.roleState);
  if (safe.blocked === true) safe.roleState = "BLOCKED";
  safe.hasPassword = hasUserPassword(user);
  return safe;
}

function splitName(displayName) {
  const parts = normalizeString(displayName).split(/\s+/).filter(Boolean);
  return {
    firstName: parts[0] || "",
    lastName: parts.slice(1).join(" "),
  };
}

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

function findCurrentUser(store, auth) {
  return store.users.find((user) => user.id === auth.user.id);
}

function validatePassengerRegistration(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;

  const displayName = normalizeString(data.displayName);
  const city = normalizeString(data.city);
  const password = normalizeString(data.password);
  if (!displayName) {
    return { success: false, code: "PROFILE_NAME_REQUIRED", error: "Введите имя и фамилию" };
  }
  if (!city) {
    return { success: false, code: "PROFILE_CITY_REQUIRED", error: "Выберите населенный пункт" };
  }
  if (!password && !hasUserPassword(auth.user)) {
    return { success: false, code: "PASSWORD_REQUIRED", error: "Придумайте пароль" };
  }
  return null;
}

function validateDriverRegistration(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;

  const firstName = normalizeString(data.firstName);
  const lastName = normalizeString(data.lastName);
  const city = normalizeString(data.city);
  const password = normalizeString(data.password);
  const gosNomer = normalizeString(data.gosNomer);
  if (!firstName || !lastName) {
    return { success: false, code: "DRIVER_NAME_REQUIRED", error: "Введите имя и фамилию" };
  }
  if (!city) {
    return { success: false, code: "DRIVER_CITY_REQUIRED", error: "Выберите населенный пункт" };
  }
  if (!password && !hasUserPassword(auth.user)) {
    return { success: false, code: "PASSWORD_REQUIRED", error: "Придумайте пароль" };
  }
  if (!gosNomer) {
    return { success: false, code: "DRIVER_PLATE_REQUIRED", error: "Введите госномер" };
  }
  return null;
}

function validatePasswordUpdate(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  const password = normalizeString(data.password);
  if (password.length < 8 || password.length > 128) {
    return { success: false, code: "PASSWORD_TOO_SHORT", error: "Пароль должен содержать от 8 до 128 символов" };
  }
  return null;
}

function savePassengerProfileInStore(store, data, auth) {
  const user = findCurrentUser(store, auth);
  if (!user) {
    return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  }
  const displayName = normalizeString(data.displayName);
  const name = splitName(displayName);
  user.displayName = displayName;
  user.firstName = name.firstName;
  user.lastName = name.lastName;
  user.city = normalizeString(data.city);
  user.photoUrl = normalizeString(data.photoUrl);
  // The login identifier cannot be changed through a profile submission.
  user.userId = normalizeString(data.userId || user.userId);
  if (normalizeString(data.password)) setUserPassword(user, normalizeString(data.password));
  user.role = "passenger";
  user.isDriver = user.isDriver === true;
  user.activeMode = "passenger";
  user.preferredClientMode = "passenger";
  user.roleState = "PASSENGER";
  user.profileCompleted = true;
  user.registrationDraft = false;
  user.updatedAt = new Date().toISOString();
  return {
    success: true,
    code: "PASSENGER_PROFILE_SAVED",
    user: publicUser(user),
    userDocPath: `users/${user.id}`,
    roleState: user.roleState,
  };
}

function saveDriverProfileInStore(store, data, auth) {
  const user = findCurrentUser(store, auth);
  if (!user) {
    return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  }
  const firstName = normalizeString(data.firstName);
  const lastName = normalizeString(data.lastName);
  const displayName = normalizeString(data.displayName || `${firstName} ${lastName}`);
  user.firstName = firstName;
  user.lastName = lastName;
  user.displayName = displayName;
  // The login identifier cannot be changed through a profile submission.
  user.city = normalizeString(data.city);
  user.userId = normalizeString(data.userId || user.userId);
  if (normalizeString(data.password)) setUserPassword(user, normalizeString(data.password));
  user.isDriver = true;
  user.role = "driver";
  user.statusDriver = "pending";
  user.driverRegistrationStatus = "pending_review";
  user.driverOnLine = false;
  user.activeMode = "passenger";
  user.preferredClientMode = "passenger";
  user.roleState = "PASSENGER";
  user.profileCompleted = true;
  user.registrationDraft = false;
  user.avtoImage = normalizeString(data.avtoImage);
  user.techImage = normalizeString(data.techImage);
  user.birthDate = normalizeString(data.birthDate);
  user.color = normalizeString(data.color);
  user.gosNomer = normalizeString(data.gosNomer);
  user.updatedAt = new Date().toISOString();
  return {
    success: true,
    code: "DRIVER_PROFILE_SUBMITTED",
    user: publicUser(user),
    userDocPath: `users/${user.id}`,
    roleState: user.roleState,
    driverRegistrationStatus: user.driverRegistrationStatus,
  };
}

function updatePreferencesInStore(store, data, auth) {
  const user = findCurrentUser(store, auth);
  if (!user) {
    return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  }
  const targetRoleState = normalizeRoleState(data.targetRoleState);
  if (targetRoleState) {
    if (!ALLOWED_ROLE_STATES.has(targetRoleState)) {
      return { success: false, code: "ROLE_STATE_INVALID", error: "Некорректный режим пользователя" };
    }
    if (targetRoleState.startsWith("DRIVER") && user.isDriver !== true) {
      return { success: false, code: "DRIVER_PROFILE_REQUIRED", error: "Профиль водителя не заполнен" };
    }
    if (targetRoleState === 'DRIVER_ONLINE' && (user.statusDriver !== 'approved' || user.blocked)) return {success:false,code:'DRIVER_APPROVAL_REQUIRED',error:'Для выхода на линию дождитесь подтверждения водителя'};
    user.roleState = targetRoleState;
    if (targetRoleState === "PASSENGER") {
      user.activeMode = "passenger";
      user.preferredClientMode = "passenger";
    }
    if (targetRoleState === "DRIVER_ONLINE" || targetRoleState === "DRIVER_OFFLINE") {
      user.activeMode = "driver";
      user.preferredClientMode = "driver";
      user.driverOnLine = targetRoleState === "DRIVER_ONLINE";
    }
  }
  if (data.city != null) user.city = normalizeString(data.city);
  if (data.soundEnabled != null) user.soundEnabled = data.soundEnabled === true;
  if (data.themeMode != null) user.themeMode = normalizeString(data.themeMode);
  if (data.language != null) user.language = normalizeString(data.language);
  if (data.photoUrl != null) user.photoUrl = normalizeString(data.photoUrl);
  if (data.lastActive === true || data.lastActiveAt != null) {
    user.lastActive = data.lastActiveAt
      ? normalizeString(data.lastActiveAt)
      : new Date().toISOString();
  }
  if (data.coords && typeof data.coords === "object") {
    const latitude = asNumber(data.coords.latitude ?? data.coords.lat);
    const longitude = asNumber(data.coords.longitude ?? data.coords.lng);
    if (latitude != null && longitude != null && Math.abs(latitude) <= 90 && Math.abs(longitude) <= 180) {
      user.coords = { latitude, longitude };
      user.coordsUpdatedAt = new Date().toISOString();
      user.coordsAccuracy = asNumber(data.coords.accuracy);
      const { observeDriverPosition } = require('./trip_automation');
      const { advanceDriverOrderStatusInStore } = require('./orders');
      observeDriverPosition(store, user, { latitude, longitude, accuracy: asNumber(data.coords.accuracy) },
        status => advanceDriverOrderStatusInStore(store, { user }, user.activeDriverOrderId, status));
    }
  }
  user.updatedAt = new Date().toISOString();
  return {
    success: true,
    code: "USER_PREFERENCES_UPDATED",
    user: publicUser(user),
    userDocPath: `users/${user.id}`,
    roleState: user.roleState,
  };
}

function setPasswordInStore(store, data, auth) {
  const user = findCurrentUser(store, auth);
  if (!user) {
    return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  }
  if (normalizeString(data.password)) setUserPassword(user, normalizeString(data.password));
  user.updatedAt = new Date().toISOString();
  return {
    success: true,
    code: "PASSWORD_UPDATED",
    user: publicUser(user),
    userDocPath: `users/${user.id}`,
  };
}

async function submitPassengerRegistrationAsync(data = {}, auth) {
  const validationError = validatePassengerRegistration(data, auth);
  if (validationError) return validationError;
  return withStoreAsync(async (store) => savePassengerProfileInStore(store, data, auth));
}

async function submitDriverRegistrationAsync(data = {}, auth) {
  const validationError = validateDriverRegistration(data, auth);
  if (validationError) return validationError;
  return withStoreAsync(async (store) => saveDriverProfileInStore(store, data, auth));
}

async function updateUserPreferencesAsync(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => updatePreferencesInStore(store, data, auth), preferencesScope(auth.user.id));
}

async function setPasswordAsync(data = {}, auth) {
  const validationError = validatePasswordUpdate(data, auth);
  if (validationError) return validationError;
  return withStoreAsync(async (store) => setPasswordInStore(store, data, auth));
}

function countRemoved(before, after) {
  return Math.max(0, before - after);
}

function deleteCurrentAccountDeepInStore(store, _data, auth) {
  const user = findCurrentUser(store, auth);
  if (!user) {
    return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  }
  if ((store.orders || []).some(o => (o.userId === user.id || o.driverId === user.id) && [2,3,4].includes(Number(o.status)))) return { success:false,code:"ACTIVE_TRIP_ACCOUNT_DELETE_DENIED",error:"Завершите или отмените активную поездку перед удалением аккаунта" };
  const userId = user.id;
  const userPath = `users/${userId}`;
  const phone = normalizePhone(user.phone);
  const chatIds = new Set(
    (store.chats || [])
      .filter((chat) =>
        chat.userId === userId ||
        chat.adminId === userId ||
        (chat.users || []).includes(userPath))
      .map((chat) => chat.id),
  );
  const removedOrderIds = new Set(
    (store.orders || [])
      .filter((order) => order.userId === userId || order.driverId === userId)
      .map((order) => order.id),
  );

  const before = {
    users: (store.users || []).length,
    orders: (store.orders || []).length,
    payments: (store.payments || []).length,
    withdrawals: (store.withdrawals || []).length,
    ledger: (store.ledger || []).length,
    chats: (store.chats || []).length,
    chatMessages: (store.chatMessages || []).length,
    fcmTokens: (store.fcmTokens || []).length,
    notificationDeliveries: (store.notificationDeliveries || []).length,
    pushDeliveryAcks: (store.pushDeliveryAcks || []).length,
    smsCodes: (store.smsCodes || []).length,
  };

  store.users = (store.users || []).filter((item) => item.id !== userId);
  store.orders = (store.orders || []).filter((order) =>
    order.userId !== userId && order.driverId !== userId);
  store.payments = (store.payments || []).filter((payment) => payment.userId !== userId);
  store.withdrawals = (store.withdrawals || []).filter((withdrawal) => withdrawal.userId !== userId);
  store.ledger = (store.ledger || []).filter((entry) => entry.userId !== userId);
  store.chats = (store.chats || []).filter((chat) => !chatIds.has(chat.id));
  store.chatMessages = (store.chatMessages || []).filter((message) => !chatIds.has(message.chatId));
  store.fcmTokens = (store.fcmTokens || []).filter((token) => token.userId !== userId);
  store.notificationDeliveries = (store.notificationDeliveries || [])
    .filter((delivery) => delivery.userId !== userId);
  store.pushDeliveryAcks = (store.pushDeliveryAcks || []).filter((ack) => ack.userId !== userId);
  store.smsCodes = (store.smsCodes || []).filter((sms) => normalizePhone(sms.phone) !== phone);

  for (const item of store.users || []) {
    if (removedOrderIds.has(item.activePassengerOrderId)) {
      item.activePassengerOrderId = null;
      item.hasActivePassengerOrder = false;
    }
    if (removedOrderIds.has(item.activeDriverOrderId)) {
      item.activeDriverOrderId = null;
      item.hasActiveDriverOrder = false;
    }
  }

  const removed = {
    users: countRemoved(before.users, store.users.length),
    orders: countRemoved(before.orders, store.orders.length),
    payments: countRemoved(before.payments, store.payments.length),
    withdrawals: countRemoved(before.withdrawals, store.withdrawals.length),
    ledger: countRemoved(before.ledger, store.ledger.length),
    chats: countRemoved(before.chats, store.chats.length),
    chatMessages: countRemoved(before.chatMessages, store.chatMessages.length),
    fcmTokens: countRemoved(before.fcmTokens, store.fcmTokens.length),
    notificationDeliveries: countRemoved(before.notificationDeliveries, store.notificationDeliveries.length),
    pushDeliveryAcks: countRemoved(before.pushDeliveryAcks, store.pushDeliveryAcks.length),
    smsCodes: countRemoved(before.smsCodes, store.smsCodes.length),
  };

  store.auditLogs ||= [];
  store.auditLogs.push({
    id: newId("audit"),
    action: "deleteCurrentAccountDeep",
    target: userPath,
    adminId: userId,
    adminPhone: user.phone,
    before: publicUser(user),
    after: null,
    extra: { removed },
    createdAt: new Date().toISOString(),
  });

  return {
    success: true,
    code: "ACCOUNT_DELETED",
    userDocPath: userPath,
    removed,
  };
}

async function deleteCurrentAccountDeepAsync(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => deleteCurrentAccountDeepInStore(store, data, auth));
}

module.exports = {
  publicUser,
  submitPassengerRegistrationAsync,
  submitDriverRegistrationAsync,
  updateUserPreferencesAsync,
  setPasswordAsync,
  deleteCurrentAccountDeepAsync,
};
