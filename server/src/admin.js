const { readStoreAsync, withStoreAsync, newId } = require("./store");
const { asNumber, normalizePhone, normalizeString } = require("./utils/values");
const { publicUser } = require("./users");
const { addLedger } = require("./payments");
const { setUserPassword } = require("./passwords");

const ADMIN_PHONE = "+70000000000";
const ACTIVE_ORDER_STATUSES = new Set([0, 1, 2, 3, 4]);
const CONTENT_SCHEMAS = {
  politika: ["text"],
  about: ["title"],
  supportContacts: ["whatsAppPhone", "callPhone"],
  tariffsContent: ["driverTariffs", "passengerTariffs"],
};
const GENERIC_ADMIN_COLLECTIONS = new Set([
  "cityToCity",
  "CityToCityDriver",
  "gruz",
  "GruzDriver",
  "bid",
]);

function docId(value) {
  const text = normalizeString(value);
  return text.split("/").filter(Boolean).pop() || text;
}

function orderPath(order) {
  return `order/${order.id}`;
}

function userPath(user) {
  return `users/${user.id}`;
}

function isAdmin(auth) {
  const user = auth?.user;
  return user?.role === "admin" || normalizePhone(user?.phone) === ADMIN_PHONE;
}

function requireAdmin(auth) {
  if (!auth?.user) {
    return {
      success: false,
      code: "UNAUTHENTICATED",
      error: "Пользователь не авторизован",
    };
  }
  if (!isAdmin(auth)) {
    return {
      success: false,
      code: "ADMIN_REQUIRED",
      error: "Недостаточно прав администратора",
    };
  }
  return null;
}

function addAudit(store, auth, action, target, before, after, extra = {}) {
  store.auditLogs ||= [];
  store.auditLogs.push({
    id: newId("audit"),
    action,
    target,
    adminId: auth.user.id,
    adminPhone: auth.user.phone,
    before,
    after,
    extra,
    createdAt: new Date().toISOString(),
  });
}

function decodeValue(value) {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    if (value.__delete === true) return undefined;
    if (Number.isFinite(value.latitude) && Number.isFinite(value.longitude)) {
      return { latitude: value.latitude, longitude: value.longitude };
    }
    return Object.fromEntries(
      Object.entries(value)
        .map(([key, item]) => [key, decodeValue(item)])
        .filter(([, item]) => item !== undefined),
    );
  }
  if (Array.isArray(value)) return value.map(decodeValue).filter((item) => item !== undefined);
  return value;
}

function normalizeFieldName(key) {
  const text = normalizeString(key);
  const map = {
    display_name: "displayName",
    phone_number: "phone",
    photo_url: "photoUrl",
    avto_image: "avtoImage",
    tech_image: "techImage",
  };
  return map[text] || text;
}

function applyFields(target, fields = {}) {
  for (const [rawKey, rawValue] of Object.entries(fields || {})) {
    const key = normalizeFieldName(rawKey);
    const value = decodeValue(rawValue);
    if (value === undefined) {
      delete target[key];
    } else {
      target[key] = key === "phone" ? normalizePhone(value) : value;
    }
  }
  if (target.firstName || target.lastName) {
    const display = [target.firstName, target.lastName]
      .map(normalizeString)
      .filter(Boolean)
      .join(" ");
    if (display) target.displayName = display;
  }
  target.updatedAt = new Date().toISOString();
}

function findUser(store, userDocPath) {
  const id = docId(userDocPath);
  return store.users.find((user) => user.id === id);
}

function findOrder(store, orderDocPath) {
  const id = docId(orderDocPath);
  return store.orders.find((order) => order.id === id);
}

function clearOrderRefs(store, order, { refundCommission = false } = {}) {
  const passenger = store.users.find((user) => user.id === order.userId);
  const driver = store.users.find((user) => user.id === order.driverId);
  if (passenger?.activePassengerOrderId === order.id) {
    passenger.activePassengerOrderId = null;
    passenger.hasActivePassengerOrder = false;
    passenger.roleState = "PASSENGER";
  }
  if (driver?.activeDriverOrderId === order.id) {
    driver.activeDriverOrderId = null;
    driver.hasActiveDriverOrder = false;
    driver.roleState = driver.driverOnLine === false ? "DRIVER_OFFLINE" : "DRIVER_ONLINE";
    if (refundCommission) {
      const refund = asNumber(order.acceptedCommission) || 0;
      if (refund > 0 && order.adminCommissionRefunded !== true) {
        driver.balance = (asNumber(driver.balance) || 0) + refund;
        addLedger(store, {
          type: "order_commission_refund",
          source: "admin",
          userId: driver.id,
          orderId: order.id,
          amount: refund,
          balanceBefore: (asNumber(driver.balance) || 0) - refund,
          balanceAfter: driver.balance,
        });
        order.adminCommissionRefunded = true;
        order.adminActionRefundAmount = refund;
      }
    }
  }
}

function syncOrderRefsForStatus(store, order) {
  const status = asNumber(order.status);
  const passenger = store.users.find((user) => user.id === order.userId);
  const driver = store.users.find((user) => user.id === order.driverId);
  if (!ACTIVE_ORDER_STATUSES.has(status)) {
    clearOrderRefs(store, order, { refundCommission: status === 6 || status === 7 });
    return;
  }
  if (passenger) {
    passenger.activePassengerOrderId = order.id;
    passenger.hasActivePassengerOrder = true;
    passenger.roleState = "PASSENGER";
    passenger.updatedAt = new Date().toISOString();
  }
  if (driver && status >= 2) {
    driver.activeDriverOrderId = order.id;
    driver.hasActiveDriverOrder = true;
    driver.roleState = "DRIVER_ON_TRIP";
    driver.updatedAt = new Date().toISOString();
  }
  if (driver && status < 2 && driver.activeDriverOrderId === order.id) {
    driver.activeDriverOrderId = null;
    driver.hasActiveDriverOrder = false;
    driver.roleState = driver.driverOnLine === false ? "DRIVER_OFFLINE" : "DRIVER_ONLINE";
    driver.updatedAt = new Date().toISOString();
  }
}

async function adminUpdateUserDocumentAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => adminUpdateUserDocumentInStore(store, data, auth));
}

function adminUpdateUserDocumentInStore(store, data = {}, auth) {
  const user = findUser(store, data.userDocPath);
  if (!user) return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  const before = { ...user };
  const fields = data.fields || {};
  applyFields(user, fields);
  if (fields.vip === true) {
    user.orderDelaySeconds = 0;
  }
  addAudit(store, auth, "adminUpdateUserDocument", userPath(user), before, { ...user });
  return { success: true, code: "USER_UPDATED", user: publicUser(user), userDocPath: userPath(user) };
}

async function adminSavePolitikaAsync(data = {}, auth) {
  return adminUpdateContentDocumentAsync({
    collection: "politika",
    fields: { text: normalizeString(data.text) },
  }, auth);
}

async function approveVehiclePhotoDeletionAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => approveVehiclePhotoDeletionInStore(store, data, auth));
}

function approveVehiclePhotoDeletionInStore(store, data, auth) {
  const user = findUser(store, data.userDocPath);
  if (!user) return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  const before = { ...user };
  user.avtoImage = "";
  user.autoImage = "";
  user.photoUrl = normalizeString(user.photoUrl);
  user.vehiclePhotoDeleteRequestStatus = "approved";
  user.vehiclePhotoDeleteApprovedAt = new Date().toISOString();
  user.vehiclePhotoDeleteRejectedAt = "";
  user.updatedAt = new Date().toISOString();
  addAudit(store, auth, "approveVehiclePhotoDeletion", userPath(user), before, { ...user });
  return {
    success: true,
    code: "VEHICLE_PHOTO_DELETE_APPROVED",
    user: publicUser(user),
    userDocPath: userPath(user),
  };
}

async function rejectVehiclePhotoDeletionAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => rejectVehiclePhotoDeletionInStore(store, data, auth));
}

function rejectVehiclePhotoDeletionInStore(store, data, auth) {
  const user = findUser(store, data.userDocPath);
  if (!user) return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  const before = { ...user };
  user.vehiclePhotoDeleteRequestStatus = "rejected";
  user.vehiclePhotoDeleteRejectedAt = new Date().toISOString();
  user.updatedAt = new Date().toISOString();
  addAudit(store, auth, "rejectVehiclePhotoDeletion", userPath(user), before, { ...user });
  return {
    success: true,
    code: "VEHICLE_PHOTO_DELETE_REJECTED",
    user: publicUser(user),
    userDocPath: userPath(user),
  };
}

async function adminListUsersAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => adminListUsersInStore(store, data));
}

function adminListUsersInStore(store, data = {}) {
  const query = normalizeString(data.query).toLowerCase();
  const roleFilter = normalizeString(data.role).toLowerCase();
  const limit = Math.min(Math.max(Number(data.limit) || 100, 1), 500);
  const users = [...(store.users || [])]
    .filter((user) => {
      if (roleFilter === "admin" && user.role !== "admin") return false;
      if (roleFilter === "driver" && user.isDriver !== true) return false;
      if (roleFilter === "passenger" && user.role === "admin") return false;
      if (roleFilter === "passenger" && user.isDriver === true) return false;
      if (!query) return true;
      const haystack = [
        user.id,
        user.phone,
        user.displayName,
        user.firstName,
        user.lastName,
        user.city,
        user.role,
        user.statusDriver,
        user.driverRegistrationStatus,
      ].map(normalizeString).join(" ").toLowerCase();
      return haystack.includes(query);
    })
    .sort((a, b) => {
      const aName = normalizeString(a.displayName || a.phone || a.id);
      const bName = normalizeString(b.displayName || b.phone || b.id);
      return aName.localeCompare(bName, "ru");
    })
    .slice(0, limit)
    .map((user) => ({
      ...publicUser(user),
      userDocPath: userPath(user),
    }));
  return {
    success: true,
    code: "ADMIN_USERS",
    users,
  };
}

async function adminListAuditLogsAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => adminListAuditLogsInStore(store, data));
}

function adminListAuditLogsInStore(store, data = {}) {
  const query = normalizeString(data.query).toLowerCase();
  const action = normalizeString(data.action).toLowerCase();
  const target = normalizeString(data.target).toLowerCase();
  const limit = Math.min(Math.max(Number(data.limit) || 100, 1), 500);
  const logs = [...(store.auditLogs || [])]
    .map((log, index) => ({ log, index }))
    .filter(({ log }) => {
      if (action && normalizeString(log.action).toLowerCase() !== action) return false;
      if (target && !normalizeString(log.target).toLowerCase().includes(target)) return false;
      if (!query) return true;
      const haystack = [
        log.id,
        log.action,
        log.target,
        log.adminId,
        log.adminPhone,
        log.createdAt,
      ].map(normalizeString).join(" ").toLowerCase();
      return haystack.includes(query);
    })
    .sort((a, b) => {
      const byDate = normalizeString(b.log.createdAt).localeCompare(normalizeString(a.log.createdAt));
      return byDate || b.index - a.index;
    })
    .slice(0, limit)
    .map(({ log }) => log);
  return {
    success: true,
    code: "ADMIN_AUDIT_LOGS",
    logs,
  };
}

async function adminCreateDriverAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => adminCreateDriverInStore(store, data, auth));
}

function adminCreateDriverInStore(store, data, auth) {
  store.users ||= [];
  const fields = data.fields && typeof data.fields === "object" ? data.fields : data;
  const draft = {};
  applyFields(draft, fields);
  const phone = normalizePhone(draft.phone || fields.phoneNumber || fields.phone_number);
  const gosNomer = normalizeString(draft.gosNomer || fields.gosNomer);
  const id = normalizeString(draft.id) ||
    (phone ? `u_driver_${phone.replace(/\D/g, "")}` : "") ||
    (gosNomer ? `u_driver_${gosNomer.toLowerCase().replace(/[^a-zа-я0-9]+/giu, "_")}` : "");
  if (!id) {
    return { success: false, code: "DRIVER_ID_REQUIRED", error: "Укажите телефон или госномер водителя" };
  }
  const existing = store.users.find((user) => user.id === id || (phone && normalizePhone(user.phone) === phone));
  if (existing) {
    return { success: false, code: "DRIVER_ALREADY_EXISTS", error: "Водитель уже существует" };
  }
  const firstName = normalizeString(draft.firstName);
  const lastName = normalizeString(draft.lastName);
  const displayName = normalizeString(draft.displayName) ||
    [firstName, lastName].filter(Boolean).join(" ") ||
    phone ||
    gosNomer;
  const user = {
    id,
    phone,
    displayName,
    firstName,
    lastName,
    city: normalizeString(draft.city),
    role: "driver",
    roleState: "DRIVER_OFFLINE",
    activeMode: "driver",
    preferredClientMode: "driver",
    isDriver: true,
    statusDriver: normalizeString(draft.statusDriver) || "approved",
    driverRegistrationStatus: "approved",
    driverOnLine: false,
    profileCompleted: true,
    registrationDraft: false,
    balance: asNumber(draft.balance) || 0,
    gosNomer,
    color: normalizeString(draft.color),
    avtoImage: normalizeString(draft.avtoImage),
    techImage: normalizeString(draft.techImage),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  const password = normalizeString(draft.password);
  if (password) {
    setUserPassword(user, password);
  }
  store.users.push(user);
  addAudit(store, auth, "adminCreateDriver", userPath(user), null, { ...user });
  return { success: true, code: "DRIVER_CREATED", user: publicUser(user), userDocPath: userPath(user) };
}

async function adminCreatePassengerAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => adminCreatePassengerInStore(store, data, auth));
}

function adminCreatePassengerInStore(store, data, auth) {
  store.users ||= [];
  const fields = data.fields && typeof data.fields === "object" ? data.fields : data;
  const draft = {};
  applyFields(draft, fields);
  const phone = normalizePhone(draft.phone || fields.phoneNumber || fields.phone_number);
  const id = normalizeString(draft.id) ||
    (phone ? `u_passenger_${phone.replace(/\D/g, "")}` : "");
  if (!id) {
    return { success: false, code: "PASSENGER_ID_REQUIRED", error: "Укажите телефон пассажира" };
  }
  const existing = store.users.find((user) => user.id === id || (phone && normalizePhone(user.phone) === phone));
  if (existing) {
    return { success: false, code: "PASSENGER_ALREADY_EXISTS", error: "Пассажир уже существует" };
  }
  const firstName = normalizeString(draft.firstName);
  const lastName = normalizeString(draft.lastName);
  const displayName = normalizeString(draft.displayName || draft.display_name) ||
    [firstName, lastName].filter(Boolean).join(" ") ||
    phone;
  const user = {
    id,
    phone,
    displayName,
    firstName,
    lastName,
    city: normalizeString(draft.city),
    photoUrl: normalizeString(draft.photoUrl || draft.photo_url),
    role: "passenger",
    roleState: "PASSENGER",
    activeMode: "passenger",
    preferredClientMode: "passenger",
    isDriver: false,
    driverOnLine: false,
    profileCompleted: true,
    registrationDraft: false,
    balance: asNumber(draft.balance) || 0,
    blocked: draft.blocked === true,
    vip: draft.vip === true,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  const password = normalizeString(draft.password);
  if (password) {
    setUserPassword(user, password);
  }
  store.users.push(user);
  addAudit(store, auth, "adminCreatePassenger", userPath(user), null, { ...user });
  return { success: true, code: "PASSENGER_CREATED", user: publicUser(user), userDocPath: userPath(user) };
}

async function approveDriverAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => approveDriverInStore(store, data, auth));
}

function approveDriverInStore(store, data, auth) {
  const user = findUser(store, data.userDocPath);
  if (!user) return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  const before = { ...user };
  const status = normalizeString(data.statusDriver || "approved");
  user.isDriver = true;
  user.statusDriver = status;
  user.driverRegistrationStatus = status === "approved" ? "approved" : status;
  user.updatedAt = new Date().toISOString();
  addAudit(store, auth, "approveDriver", userPath(user), before, { ...user }, { statusDriver: status });
  return { success: true, code: "DRIVER_STATUS_UPDATED", user: publicUser(user), userDocPath: userPath(user) };
}

async function adminUpdateDriverCityAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => adminUpdateDriverCityInStore(store, data, auth));
}

function adminUpdateDriverCityInStore(store, data, auth) {
  const user = findUser(store, data.userDocPath);
  if (!user) return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  const city = normalizeString(data.city);
  if (!city) return { success: false, code: "CITY_REQUIRED", error: "Укажите поселок" };
  const before = { ...user };
  user.city = city;
  user.updatedAt = new Date().toISOString();
  addAudit(store, auth, "adminUpdateDriverCity", userPath(user), before, { ...user }, { city });
  return { success: true, code: "DRIVER_CITY_UPDATED", user: publicUser(user), userDocPath: userPath(user) };
}

async function adminUpdateDriverOrderDelayAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => adminUpdateDriverOrderDelayInStore(store, data, auth));
}

function adminUpdateDriverOrderDelayInStore(store, data, auth) {
  const user = findUser(store, data.userDocPath);
  if (!user) return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  const orderDelaySeconds = asNumber(data.orderDelaySeconds);
  if (orderDelaySeconds == null || orderDelaySeconds < 0) {
    return { success: false, code: "ORDER_DELAY_INVALID", error: "Некорректная задержка" };
  }
  const before = { ...user };
  user.orderDelaySeconds = Math.trunc(orderDelaySeconds);
  user.updatedAt = new Date().toISOString();
  addAudit(store, auth, "adminUpdateDriverOrderDelay", userPath(user), before, { ...user }, { orderDelaySeconds: user.orderDelaySeconds });
  return { success: true, code: "DRIVER_ORDER_DELAY_UPDATED", user: publicUser(user), userDocPath: userPath(user) };
}

async function setBlockedAsync(data, auth, blocked) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => setBlockedInStore(store, data, auth, blocked));
}

function blockDriverAsync(data = {}, auth) {
  return setBlockedAsync(data, auth, true);
}

function unblockDriverAsync(data = {}, auth) {
  return setBlockedAsync(data, auth, false);
}

function setBlockedInStore(store, data, auth, blocked) {
  const user = findUser(store, data.userDocPath);
  if (!user) return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  const before = { ...user };
  user.blocked = blocked;
  if (blocked) {
    user.driverOnLine = false;
    if (user.roleState === "DRIVER_ONLINE") user.roleState = "DRIVER_OFFLINE";
  }
  user.updatedAt = new Date().toISOString();
  addAudit(store, auth, blocked ? "blockDriver" : "unblockDriver", userPath(user), before, { ...user });
  return { success: true, code: blocked ? "USER_BLOCKED" : "USER_UNBLOCKED", user: publicUser(user), userDocPath: userPath(user) };
}

async function adminTopUpDriverBalanceAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => adminTopUpDriverBalanceInStore(store, data, auth));
}

function adminTopUpDriverBalanceInStore(store, data, auth) {
  const user = findUser(store, data.userDocPath);
  if (!user) return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  const targetBalance = asNumber(data.targetBalance);
  if (targetBalance == null) {
    return { success: false, code: "BALANCE_INVALID", error: "Некорректный баланс" };
  }
  const before = { ...user };
  const balanceBefore = asNumber(user.balance) || 0;
  user.balance = targetBalance;
  user.updatedAt = new Date().toISOString();
  addAudit(store, auth, "adminTopUpDriverBalance", userPath(user), before, { ...user }, { targetBalance });
  addLedger(store, {
    type: "admin_balance_set",
    source: "admin",
    userId: user.id,
    amount: targetBalance - balanceBefore,
    balanceBefore,
    balanceAfter: targetBalance,
  });
  return { success: true, code: "BALANCE_UPDATED", user: publicUser(user), userDocPath: userPath(user), balance: user.balance };
}

async function adminManageOrderAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => adminManageOrderInStore(store, data, auth));
}

function adminManageOrderInStore(store, data, auth) {
  const order = findOrder(store, data.orderDocPath);
  if (!order) return { success: false, code: "ORDER_NOT_FOUND", error: "Заказ не найден" };
  const before = { ...order };
  const action = normalizeString(data.action).toLowerCase();
  const now = new Date().toISOString();
  let message = "Заказ обновлен";

  if (action === "complete") {
    order.status = 5;
    order.completedAt = now;
    clearOrderRefs(store, order);
    message = "Заказ завершен";
  } else if (action === "cancel") {
    order.status = 6;
    order.cancelledAt = now;
    order.cancelledBy = "admin";
    clearOrderRefs(store, order, { refundCommission: true });
    message = "Заказ отменен";
  } else if (action === "reopen") {
    clearOrderRefs(store, order, { refundCommission: true });
    order.status = 0;
    order.driverId = "";
    order.driverName = "";
    order.driverPhone = "";
    order.reopenedAt = now;
    order.adminReopened = true;
    const passenger = store.users.find((user) => user.id === order.userId);
    if (passenger) {
      passenger.activePassengerOrderId = order.id;
      passenger.hasActivePassengerOrder = true;
      passenger.roleState = "PASSENGER";
    }
    message = "Заказ возвращен в очередь";
  } else if (action === "setstatus") {
    const targetStatus = Number(data.targetStatus);
    if (!Number.isInteger(targetStatus) || targetStatus < 0 || targetStatus > 7) {
      return { success: false, code: "ORDER_STATUS_INVALID", error: "Некорректный статус" };
    }
    order.status = targetStatus;
    syncOrderRefsForStatus(store, order);
    message = `Статус заказа изменен: ${targetStatus}`;
  } else {
    return { success: false, code: "ADMIN_ORDER_ACTION_INVALID", error: "Некорректное действие" };
  }

  order.adminAction = action;
  order.adminActionAt = now;
  order.updatedAt = now;
  addAudit(store, auth, "adminManageOrder", orderPath(order), before, { ...order }, { action, targetStatus: data.targetStatus });
  return {
    success: true,
    code: "ORDER_ADMIN_UPDATED",
    message,
    order,
    orderDocPath: orderPath(order),
    status: order.status,
  };
}

function publicCityTariff(item = {}) {
  return {
    id: normalizeString(item.id || item.title),
    title: normalizeString(item.title),
    priceDay: asNumber(item.priceDay) ?? 0,
    priceNight: asNumber(item.priceNight) ?? 0,
    deliveryPrice: asNumber(item.deliveryPrice) ?? 0,
    priceCity: asNumber(item.priceCity) ?? undefined,
  };
}

async function adminListCityTariffsAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return listCityTariffsAsync(data, auth);
}

async function listCityTariffsAsync(data = {}, auth) {
  if (!auth?.user) {
    return {
      success: false,
      code: "UNAUTHENTICATED",
      error: "Пользователь не авторизован",
    };
  }
  const store = await readStoreAsync();
  const query = normalizeString(data.query).toLowerCase();
  const tariffs = [...(store.cityPrices || [])]
    .map(publicCityTariff)
    .filter((item) => !query || item.title.toLowerCase().includes(query))
    .sort((a, b) => a.title.localeCompare(b.title, "ru"));
  return {
    success: true,
    code: "CITY_TARIFFS",
    tariffs,
  };
}

async function adminUpsertCityTariffAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => {
    store.cityPrices ||= [];
    const title = normalizeString(data.title);
    if (!title) {
      return { success: false, code: "CITY_TITLE_REQUIRED", error: "Укажите поселок" };
    }
    const priceDay = asNumber(data.priceDay);
    const priceNight = asNumber(data.priceNight);
    const deliveryPrice = asNumber(data.deliveryPrice);
    if (priceDay == null || priceNight == null || deliveryPrice == null) {
      return { success: false, code: "CITY_PRICE_INVALID", error: "Укажите корректные цены" };
    }
    const index = store.cityPrices.findIndex(
      (item) => normalizeString(item.title).toLowerCase() === title.toLowerCase(),
    );
    const before = index >= 0 ? { ...store.cityPrices[index] } : null;
    const tariff = {
      ...(index >= 0 ? store.cityPrices[index] : {}),
      id: normalizeString(data.id) || title,
      title,
      priceDay,
      priceNight,
      deliveryPrice,
      updatedAt: new Date().toISOString(),
    };
    if (index >= 0) {
      store.cityPrices[index] = tariff;
    } else {
      store.cityPrices.push(tariff);
    }
    addAudit(store, auth, "adminUpsertCityTariff", `City/${tariff.id}`, before, { ...tariff });
    return {
      success: true,
      code: "CITY_TARIFF_UPDATED",
      tariff: publicCityTariff(tariff),
    };
  });
}

function publicIntercityRoute(route = {}) {
  return {
    id: normalizeString(route.id),
    ot: normalizeString(route.ot || route.from || route.otkuda || route.fromCity),
    kuda: normalizeString(route.kuda || route.to || route.kudaCity || route.toCity),
    tarif: asNumber(route.tarif ?? route.price ?? route.cost) ?? 0,
    com: asNumber(route.com ?? route.commission) ?? 0,
  };
}

async function listIntercityRoutesAsync(data = {}, auth) {
  if (!auth?.user) {
    return {
      success: false,
      code: "UNAUTHENTICATED",
      error: "Пользователь не авторизован",
    };
  }
  const store = await readStoreAsync();
  const query = normalizeString(data.query).toLowerCase();
  const routes = [...(store.intercityRoutes || [])]
    .map(publicIntercityRoute)
    .filter((route) => {
      if (!query) return true;
      return `${route.ot} ${route.kuda} ${route.id}`.toLowerCase().includes(query);
    })
    .sort((a, b) => `${a.ot} ${a.kuda}`.localeCompare(`${b.ot} ${b.kuda}`, "ru"));
  return {
    success: true,
    code: "INTERCITY_ROUTES",
    routes,
  };
}

async function adminListIntercityRoutesAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  const store = await readStoreAsync();
  const query = normalizeString(data.query).toLowerCase();
  const routes = [...(store.intercityRoutes || [])]
    .map(publicIntercityRoute)
    .filter((route) => {
      if (!query) return true;
      return `${route.ot} ${route.kuda} ${route.id}`.toLowerCase().includes(query);
    })
    .sort((a, b) => `${a.ot} ${a.kuda}`.localeCompare(`${b.ot} ${b.kuda}`, "ru"));
  return {
    success: true,
    code: "ADMIN_INTERCITY_ROUTES",
    routes,
  };
}

async function adminUpsertIntercityRouteAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => {
    store.intercityRoutes ||= [];
    const ot = normalizeString(data.ot || data.from || data.otkuda || data.fromCity);
    const kuda = normalizeString(data.kuda || data.to || data.kudaCity || data.toCity);
    const tarif = asNumber(data.tarif ?? data.price ?? data.cost);
    const com = asNumber(data.com ?? data.commission) ?? 0;
    if (!ot || !kuda) {
      return { success: false, code: "ROUTE_POINTS_REQUIRED", error: "Укажите откуда и куда" };
    }
    if (tarif == null) {
      return { success: false, code: "ROUTE_PRICE_INVALID", error: "Укажите корректную цену" };
    }
    const id = normalizeString(data.id) ||
      `route_${ot}_${kuda}`.toLowerCase().replace(/[^a-zа-я0-9]+/giu, "_").replace(/^_+|_+$/g, "");
    const index = store.intercityRoutes.findIndex((route) => normalizeString(route.id) === id);
    const before = index >= 0 ? { ...store.intercityRoutes[index] } : null;
    const route = {
      ...(index >= 0 ? store.intercityRoutes[index] : {}),
      id,
      ot,
      kuda,
      tarif,
      com,
      updatedAt: new Date().toISOString(),
    };
    if (index >= 0) {
      store.intercityRoutes[index] = route;
    } else {
      store.intercityRoutes.push(route);
    }
    addAudit(store, auth, "adminUpsertIntercityRoute", `routerCityToCity/${id}`, before, { ...route });
    return {
      success: true,
      code: "INTERCITY_ROUTE_UPDATED",
      route: publicIntercityRoute(route),
    };
  });
}

function normalizeContentCollection(value) {
  const collection = normalizeString(value);
  return CONTENT_SCHEMAS[collection] ? collection : "";
}

function normalizeGenericCollection(value) {
  const collection = normalizeString(value);
  return GENERIC_ADMIN_COLLECTIONS.has(collection) ? collection : "";
}

function contentForStore(store, collection) {
  store.content ||= {};
  store.content[collection] ||= {};
  return store.content[collection];
}

function publicContentDocument(store, collection) {
  const data = contentForStore(store, collection);
  const allowed = CONTENT_SCHEMAS[collection] || [];
  return Object.fromEntries(allowed.map((key) => [key, normalizeString(data[key])]));
}

async function getContentDocumentAsync(data = {}) {
  const store = await readStoreAsync();
  const collection = normalizeContentCollection(data.collection);
  if (!collection) {
    return { success: false, code: "CONTENT_COLLECTION_INVALID", error: "Некорректный раздел" };
  }
  return {
    success: true,
    code: "CONTENT_DOCUMENT",
    collection,
    document: publicContentDocument(store, collection),
  };
}

async function adminUpdateContentDocumentAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => {
    const collection = normalizeContentCollection(data.collection);
    if (!collection) {
      return { success: false, code: "CONTENT_COLLECTION_INVALID", error: "Некорректный раздел" };
    }
    const target = contentForStore(store, collection);
    const before = { ...target };
    const fields = data.fields && typeof data.fields === "object" ? data.fields : {};
    for (const key of CONTENT_SCHEMAS[collection]) {
      if (Object.prototype.hasOwnProperty.call(fields, key)) {
        target[key] = normalizeString(fields[key]);
      }
    }
    target.updatedAt = new Date().toISOString();
    addAudit(store, auth, "adminUpdateContentDocument", `${collection}/main`, before, { ...target });
    return {
      success: true,
      code: "CONTENT_UPDATED",
      collection,
      document: publicContentDocument(store, collection),
    };
  });
}

function genericCollectionForStore(store, collection) {
  store.genericCollections ||= {};
  store.genericCollections[collection] ||= [];
  return store.genericCollections[collection];
}

function publicGenericDocument(collection, item = {}) {
  const id = normalizeString(item.id) || newId("doc");
  return {
    ...item,
    id,
    docPath: `${collection}/${id}`,
  };
}

async function adminListGenericCollectionAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  const collection = normalizeGenericCollection(data.collection);
  if (!collection) {
    return { success: false, code: "GENERIC_COLLECTION_INVALID", error: "Раздел не подключен к backend" };
  }
  const store = await readStoreAsync();
  const query = normalizeString(data.query).toLowerCase();
  const limit = Math.min(Math.max(Number(data.limit) || 100, 1), 500);
  const documents = genericCollectionForStore(store, collection)
    .map((item) => publicGenericDocument(collection, item))
    .filter((item) => {
      if (!query) return true;
      return JSON.stringify(item).toLowerCase().includes(query);
    })
    .sort((a, b) => {
      const byDate = normalizeString(b.updatedAt || b.createdAt).localeCompare(
        normalizeString(a.updatedAt || a.createdAt),
      );
      return byDate || normalizeString(a.id).localeCompare(normalizeString(b.id), "ru");
    })
    .slice(0, limit);
  return {
    success: true,
    code: "ADMIN_GENERIC_COLLECTION",
    collection,
    documents,
  };
}

async function adminUpsertGenericDocumentAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  const collection = normalizeGenericCollection(data.collection);
  if (!collection) {
    return { success: false, code: "GENERIC_COLLECTION_INVALID", error: "Раздел не подключен к backend" };
  }
  return withStoreAsync(async (store) => {
    const list = genericCollectionForStore(store, collection);
    const fields = data.fields && typeof data.fields === "object" ? decodeValue(data.fields) : {};
    const docIdRaw = normalizeString(data.id || data.docId || fields.id);
    const id = docIdRaw || newId(collection);
    const index = list.findIndex((item) => normalizeString(item.id) === id);
    const before = index >= 0 ? { ...list[index] } : null;
    const next = {
      ...(index >= 0 ? list[index] : {}),
      ...fields,
      id,
      updatedAt: new Date().toISOString(),
    };
    if (!next.createdAt) next.createdAt = next.updatedAt;
    if (index >= 0) {
      list[index] = next;
    } else {
      list.push(next);
    }
    addAudit(store, auth, "adminUpsertGenericDocument", `${collection}/${id}`, before, { ...next });
    return {
      success: true,
      code: "GENERIC_DOCUMENT_UPDATED",
      collection,
      document: publicGenericDocument(collection, next),
    };
  });
}

async function adminDeleteGenericDocumentAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  const collection = normalizeGenericCollection(data.collection);
  if (!collection) {
    return { success: false, code: "GENERIC_COLLECTION_INVALID", error: "Раздел не подключен к backend" };
  }
  return withStoreAsync(async (store) => {
    const list = genericCollectionForStore(store, collection);
    const id = normalizeString(data.id || data.docId);
    const index = list.findIndex((item) => normalizeString(item.id) === id);
    if (!id || index < 0) {
      return { success: false, code: "GENERIC_DOCUMENT_NOT_FOUND", error: "Документ не найден" };
    }
    const [removed] = list.splice(index, 1);
    addAudit(store, auth, "adminDeleteGenericDocument", `${collection}/${id}`, { ...removed }, null);
    return {
      success: true,
      code: "GENERIC_DOCUMENT_DELETED",
      collection,
      id,
    };
  });
}

module.exports = {
  requireAdmin,
  addAudit,
  adminCreateDriverAsync,
  adminCreatePassengerAsync,
  adminSavePolitikaAsync,
  adminListUsersAsync,
  adminListAuditLogsAsync,
  adminUpdateUserDocumentAsync,
  approveVehiclePhotoDeletionAsync,
  rejectVehiclePhotoDeletionAsync,
  approveDriverAsync,
  adminUpdateDriverCityAsync,
  adminUpdateDriverOrderDelayAsync,
  blockDriverAsync,
  unblockDriverAsync,
  adminTopUpDriverBalanceAsync,
  adminManageOrderAsync,
  listCityTariffsAsync,
  adminListCityTariffsAsync,
  adminUpsertCityTariffAsync,
  listIntercityRoutesAsync,
  adminListIntercityRoutesAsync,
  adminUpsertIntercityRouteAsync,
  getContentDocumentAsync,
  adminUpdateContentDocumentAsync,
  adminListGenericCollectionAsync,
  adminUpsertGenericDocumentAsync,
  adminDeleteGenericDocumentAsync,
};
