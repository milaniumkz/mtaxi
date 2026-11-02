const { reservePassengerBonus, refundPassengerBonus, settlePassengerBonus } = require('./passenger_bonuses');
const { readStoreAsync, withStoreAsync, newId } = require("./store");
const { orderScope, feedScope, historyScope, financialOrderScope } = require("./store/scopes");
const { asDate, asNumber, normalizePhone, normalizeString } = require("./utils/values");
const { addLedger } = require("./payments");
const { queueOrderPushEventInStore } = require("./push");
const { requireAdmin } = require("./admin");
const { recordCompletedOrder, debitCommission, refundCommission } = require("./driver_bonuses");

const ORDER_STATUS = Object.freeze({
  OPEN: 0,
  DRIVER_ASSIGNED: 2,
  DRIVER_ARRIVED: 3,
  TRIP_STARTED: 4,
  COMPLETED: 5,
  CANCELLED: 6,
  EXPIRED: 7,
});

function getOrderType({ type } = {}) {
  return normalizeString(type || "taxi").toLowerCase() || "taxi";
}

function isNightTariffTime(value) {
  const date = asDate(value) || new Date();
  const hourText = new Intl.DateTimeFormat("en-GB", {
    hour: "2-digit",
    hourCycle: "h23",
    timeZone: "Asia/Almaty",
  }).format(date);
  const hour = Number.parseInt(hourText, 10);
  return Number.isFinite(hour) && hour >= 0 && hour < 6;
}

function isActivePassengerOrder(order) {
  return order && [0, 1, 2, 3, 4].includes(Number(order.status));
}

function isOpenPendingOrder(order) {
  return order &&
    Number(order.status) === ORDER_STATUS.OPEN &&
    !normalizeString(order.driverId);
}

function docId(value) {
  const text = normalizeString(value);
  return text.split("/").filter(Boolean).pop() || text;
}

function orderDocPath(order) {
  return `order/${order.id}`;
}

function userDocPath(user) {
  return `users/${user.id}`;
}

function requiredDriverBalance(order, settings = {}) {
  const percent = asNumber(settings.orderCommissionPercent) ?? 10;
  return Math.ceil((asNumber(order.price) || 0) * percent / 100);
}

function geoPointFromData(data = {}, prefix = "") {
  const nestedCandidates = prefix
    ? [
        data[prefix],
        data[`${prefix}Point`],
        data[`${prefix}Coords`],
      ]
    : [data.point, data.coords, data.location];
  for (const candidate of nestedCandidates) {
    if (!candidate || typeof candidate !== "object") continue;
    const latitude = asNumber(candidate.latitude ?? candidate.lat);
    const longitude = asNumber(candidate.longitude ?? candidate.lng ?? candidate.lon);
    if (Number.isFinite(latitude) && Number.isFinite(longitude) && Math.abs(latitude)<=90 && Math.abs(longitude)<=180) {
      return { latitude, longitude };
    }
  }
  const latitude = asNumber(data[`${prefix}Latitude`] ?? data[`${prefix}Lat`]);
  const longitude = asNumber(data[`${prefix}Longitude`] ?? data[`${prefix}Lng`] ?? data[`${prefix}Lon`]);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude)>90 || Math.abs(longitude)>180) return null;
  return { latitude, longitude };
}

function distanceKmBetween(a, b) {
  if (!a || !b) return null;
  const toRad = (value) => value * Math.PI / 180;
  const earthKm = 6371;
  const dLat = toRad(b.latitude - a.latitude);
  const dLon = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);
  const hav =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * earthKm * Math.asin(Math.sqrt(hav));
}

function calculateOrderQuoteFromData({
  type,
  city,
  distanceKm,
  scheduledAt,
  cityPrices,
  intercityTariff,
  settings,
}) {
  const orderType = getOrderType({ type });
  const isNight = isNightTariffTime(scheduledAt);
  const nightMultiplier = settings.nightMultiplier || 1.5;

  if (orderType === "intercity") {
    if (!Number.isFinite(distanceKm) || distanceKm <= 0) {
      return { success: false, error: "Некорректное расстояние маршрута" };
    }
    const tariff = intercityTariff || {};
    const basePrice = asNumber(tariff.basePrice) ?? 500;
    const pricePerKm = asNumber(tariff.pricePerKm) ?? 130;
    const minPrice = asNumber(tariff.minPrice) ?? 3000;
    const base = basePrice + pricePerKm * distanceKm;
    const minApplied = base < minPrice ? minPrice : base;
    return {
      success: true,
      type: orderType,
      isNight,
      price: Math.max(500, isNight ? minApplied * nightMultiplier : minApplied),
      distanceKm,
      basePrice,
      pricePerKm,
      minPrice,
    };
  }

  const cityPricing =
    cityPrices.find((item) => normalizeString(item.title).toLowerCase() === normalizeString(city).toLowerCase()) ||
    {};
  let day = asNumber(cityPricing.priceDay);
  let night = asNumber(cityPricing.priceNight);
  const legacy = asNumber(cityPricing.priceCity);
  if ((day ?? 0) <= 0 && (night ?? 0) <= 0 && (legacy ?? 0) > 0) {
    day = legacy;
    night = legacy;
  }

  if (orderType === "delivery") {
    const deliveryPrice = asNumber(cityPricing.deliveryPrice);
    if (deliveryPrice && deliveryPrice > 0) {
      return {
        success: true,
        type: orderType,
        isNight,
        price: Math.max(500, isNight ? deliveryPrice * nightMultiplier : deliveryPrice),
        cityFound: Boolean(cityPricing.title),
      };
    }
  }

  const baseCity = isNight ? ((night ?? 0) > 0 ? night : (day ?? 0)) : ((day ?? 0) > 0 ? day : (night ?? 0));
  const taxiFallback = settings.taxiFallbackPrice || 800;
  const deliveryFallback = settings.deliveryFallbackPrice || 1200;
  const deliveryExtra = settings.deliveryExtra || 400;
  const taxi = baseCity > 0 ? baseCity : taxiFallback;
  const delivery = baseCity > 0 ? baseCity + deliveryExtra : deliveryFallback;
  let price = orderType === "delivery" ? delivery : taxi;
  if (isNight && baseCity === 0) price *= nightMultiplier;
  return {
    success: true,
    type: orderType,
    isNight,
    price: Math.max(500,price),
    cityFound: Boolean(cityPricing.title),
  };
}

async function calculateOrderQuoteAsync(data = {}) {
  const store = await readStoreAsync();
  if (getOrderType({ type: data.type }) === "intercity" && store.settings?.intercityEnabled !== true) return intercityDisabled();
  return calculateOrderQuoteFromStore(store, data);
}

function calculateOrderQuoteFromStore(store, data = {}) {
  return calculateOrderQuoteFromData({
    type: data.type,
    city: data.city,
    distanceKm: asNumber(data.distanceKm),
    scheduledAt: asDate(data.date),
    cityPrices: store.cityPrices || [],
    intercityTariff: store.intercityTariff || {},
    settings: store.settings || {},
  });
}

async function getOrderQuoteAsync(data = {}, auth) {
  if (!auth?.user) return { success: false, error: "Пользователь не авторизован" };
  const type = getOrderType({ type: data.type });
  if (!["taxi", "delivery", "intercity"].includes(type)) {
    return { success: false, error: "Некорректный тип заказа" };
  }
  if (!normalizeString(data.city)) return { success: false, error: "Не указан поселок" };
  return calculateOrderQuoteAsync(data);
}

async function createPassengerOrderAsync(data = {}, auth) {
  if (!auth?.user) {
    return { success: false, code: "UNAUTHENTICATED", error: "Пользователь не авторизован" };
  }
  const type = getOrderType({ type: data.type });
  let from = normalizeString(data.ot);
  let to = normalizeString(data.kuda);
  const city = normalizeString(data.city || auth.user.city);
  if ((type === "taxi" || type === "delivery") && !to) to = "Адрес уточняется";
  if (!["taxi", "delivery", "intercity"].includes(type)) {
    return { success: false, code: "ORDER_INVALID_TYPE", error: "Некорректный тип заказа" };
  }
  if (!from || !city || !to) {
    return { success: false, code: "ORDER_INVALID_ROUTE", error: "Заполните маршрут заказа" };
  }

  return withStoreAsync(async (store) => createPassengerOrderInStore(store, data, auth, { type, from, to, city }), financialOrderScope("", auth.user.id));
}

function createPassengerOrderInStore(store, data, auth, { type, from, to, city }) {
  if (type === "intercity" && store.settings?.intercityEnabled !== true) return intercityDisabled();
  const user = store.users.find((item) => item.id === auth.user.id);
  if (!user) return { success:false,code:"USER_NOT_FOUND",error:"Пользователь не найден" };
  const active = store.orders.find(
    (order) => order.id === user?.activePassengerOrderId && isActivePassengerOrder(order),
  );
  if (active) {
    return {
      success: true,
      created: false,
      existing: true,
      code: "ORDER_ALREADY_EXISTS",
      orderDocPath: orderDocPath(active),
      price: active.price,
    };
  }

  const fromPoint = geoPointFromData(data, "from") || geoPointFromData(data, "ot") || geoPointFromData(data);
  const toPoint = geoPointFromData(data, "to") || geoPointFromData(data, "kuda");
  const calculatedDistanceKm = asNumber(data.distanceKm) ?? distanceKmBetween(fromPoint, toPoint);
  const routeDistanceKm = type === "intercity" ? calculatedDistanceKm : (calculatedDistanceKm ?? 0);
  const explicitPrice = asNumber(data.price);
  if (data.price != null && (!Number.isSafeInteger(explicitPrice) || explicitPrice < 500 || explicitPrice > 10000000)) return { success: false, code: "PRICE_MINIMUM", error: "Минимальная цена — 500 ₸", minimumPrice: 500 };
  const quote = explicitPrice == null
    ? calculateOrderQuoteFromData({
      type,
      city,
      distanceKm: routeDistanceKm,
      scheduledAt: asDate(data.date),
      cityPrices: store.cityPrices || [],
      intercityTariff: store.intercityTariff || {},
      settings: store.settings || {},
    })
    : {
      success: true,
      type,
      isNight: isNightTariffTime(asDate(data.date)),
      price: explicitPrice,
    };
  if (!quote.success) {
    return {
      success: false,
      code: "ORDER_QUOTE_FAILED",
      error: quote.error || "Не удалось рассчитать цену",
    };
  }

  const order = {
    id: newId("order"),
    userId: user.id,
    status: ORDER_STATUS.OPEN,
    ot: from,
    kuda: to,
    city,
    type,
    comment: type === "delivery" ? "" : normalizeString(data.comment),
    deliveryItem: type === "delivery" ? normalizeString(data.deliveryItem) : "",
    price: Math.max(500, quote.price),
    passengerPrice: Math.max(500, quote.price),
    offers: [],
    distanceKm: routeDistanceKm,
    fromPoint,
    toPoint,
    isNight: quote.isNight,
    customerName: user.displayName || "",
    customerPhone: user.phone || "",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  order.paymentMode = data.paymentMode === 'wallet' ? 'wallet' : 'cash';
  const paymentError = reservePassengerBonus(store, order, user, data.usePassengerBonuses === true);
  if (paymentError) return paymentError;
  order.cashToDriver ??= order.price;
  store.orders.push(order);
  user.activePassengerOrderId = order.id;
  user.hasActivePassengerOrder = true;
  user.roleState = "PASSENGER";
  queueOrderPushEventInStore(store, {
    order,
    eventType: "ORDER_CREATED",
    targetRole: "driver",
    title: orderTitleForDriver(order),
    body: `${order.ot} -> ${order.kuda}`,
    orderAlert: true,
    initialPageName: "homeDriver",
  });
  return {
    success: true,
    created: true,
    existing: false,
    code: "ORDER_CREATED",
    orderDocPath: orderDocPath(order),
    price: order.price,
  };
}

function findOrCreateAdminPassenger(store, data = {}) {
  const userId = docId(data.userDocPath || data.userId || data.idUser);
  if (userId) {
    const existing = store.users.find((item) => item.id === userId);
    if (existing) return existing;
  }
  const phone = normalizePhone(data.customerPhone || data.phone || data.phoneNumber);
  if (phone) {
    const byPhone = store.users.find((item) => normalizePhone(item.phone) === phone);
    if (byPhone) return byPhone;
  }
  if (!phone) return null;
  const id = `u_passenger_${phone.replace(/\D/g, "")}`;
  const user = {
    id,
    phone,
    password: "",
    displayName: normalizeString(data.customerName || data.name) || phone,
    city: normalizeString(data.city),
    roleState: "PASSENGER",
    role: "passenger",
    isDriver: false,
    balance: 0,
    profileCompleted: true,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  store.users.push(user);
  return user;
}

async function adminCreateOrderAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  const type = getOrderType({ type: data.type });
  const from = normalizeString(data.ot);
  let to = normalizeString(data.kuda);
  const city = normalizeString(data.city || auth.user.city);
  if ((type === "taxi" || type === "delivery") && !to) to = "Адрес уточняется";
  if (!["taxi", "delivery", "intercity"].includes(type)) {
    return { success: false, code: "ORDER_INVALID_TYPE", error: "Некорректный тип заказа" };
  }
  if (!from || !city || !to) {
    return { success: false, code: "ORDER_INVALID_ROUTE", error: "Заполните маршрут заказа" };
  }

  return withStoreAsync(async (store) => adminCreateOrderInStore(store, data, auth, { type, from, to, city }));
}

function adminCreateOrderInStore(store, data, auth, { type, from, to, city }) {
  if (type === "intercity" && store.settings?.intercityEnabled !== true) return intercityDisabled();
  store.users ||= [];
  store.orders ||= [];
  const user = findOrCreateAdminPassenger(store, data);
  if (!user) {
    return { success: false, code: "ORDER_CUSTOMER_REQUIRED", error: "Укажите пассажира или номер телефона" };
  }
  const explicitPrice = asNumber(data.price);
  if (data.price != null && (!Number.isSafeInteger(explicitPrice) || explicitPrice < 500 || explicitPrice > 10000000)) return { success: false, code: "PRICE_MINIMUM", error: "Минимальная цена — 500 ₸", minimumPrice: 500 };
  const quote = explicitPrice == null ? calculateOrderQuoteFromData({
    type,
    city,
    distanceKm: asNumber(data.distanceKm),
    scheduledAt: asDate(data.date),
    cityPrices: store.cityPrices || [],
    intercityTariff: store.intercityTariff || {},
    settings: store.settings || {},
  }) : { success: true, price: explicitPrice, isNight: data.isNight === true };
  if (!quote.success) {
    return { success: false, code: "ORDER_QUOTE_FAILED", error: quote.error || "Не удалось рассчитать цену" };
  }

  const order = {
    id: newId("order"),
    userId: user.id,
    status: asNumber(data.status) ?? ORDER_STATUS.OPEN,
    ot: from,
    kuda: to,
    city,
    type,
    comment: type === "delivery" ? "" : normalizeString(data.comment),
    deliveryItem: type === "delivery" ? normalizeString(data.deliveryItem) : "",
    price: Math.max(500, quote.price),
    passengerPrice: Math.max(500, quote.price),
    offers: [],
    distanceKm: asNumber(data.distanceKm),
    fromPoint: geoPointFromData(data, "from") || geoPointFromData(data, "ot") || geoPointFromData(data),
    toPoint: geoPointFromData(data, "to") || geoPointFromData(data, "kuda"),
    isNight: quote.isNight === true,
    customerName: normalizeString(data.customerName) || user.displayName || "",
    customerPhone: normalizePhone(data.customerPhone || user.phone),
    createdByAdminId: auth.user.id,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  order.paymentMode = data.paymentMode === 'wallet' ? 'wallet' : 'cash';
  const paymentError = reservePassengerBonus(store, order, user, data.usePassengerBonuses === true);
  if (paymentError) return paymentError;
  order.cashToDriver ??= order.price;
  store.orders.push(order);
  if (isActivePassengerOrder(order)) {
    user.activePassengerOrderId = order.id;
    user.hasActivePassengerOrder = true;
    user.roleState = "PASSENGER";
  }
  if (Number(order.status) === ORDER_STATUS.OPEN) {
    queueOrderPushEventInStore(store, {
      order,
      eventType: "ORDER_CREATED",
      targetRole: "driver",
      title: orderTitleForDriver(order),
      body: `${order.ot} -> ${order.kuda}`,
      orderAlert: true,
      initialPageName: "homeDriver",
    });
  }
  return {
    success: true,
    code: "ADMIN_ORDER_CREATED",
    orderDocPath: orderDocPath(order),
    userDocPath: userDocPath(user),
    order: compactOrder(order),
  };
}

function compactOrder(order) {
  if (!order) return null;
  return {
    id: order.id,
    orderDocPath: orderDocPath(order),
    status: Number(order.status),
    type: order.type || "taxi",
    ot: order.ot || "",
    kuda: order.kuda || "",
    city: order.city || "",
    price: asNumber(order.price) || 0,
    passengerPrice: order.passengerPrice ?? order.price,
    passengerBonusUsed: order.passengerBonusUsed || 0,
    passengerWalletUsed: order.passengerWalletUsed || 0,
    paymentMode: order.paymentMode || "cash",
    cashToDriver: order.cashToDriver ?? order.price,
    distanceKm: asNumber(order.distanceKm),
    fromPoint: order.fromPoint || null,
    toPoint: order.toPoint || null,
    passengerId: order.userId || "",
    driverId: order.driverId || "",
    customerName: order.customerName || "",
    customerPhone: order.customerPhone || "",
    driverName: order.driverName || "",
    driverPhone: order.driverPhone || "",
    driverCar: order.driverCar || "",
    driverPlate: order.driverPlate || "",
    comment: order.comment || "",
    deliveryItem: order.deliveryItem || "",
    cancelledAt: order.cancelledAt || null,
    cancelledBy: order.cancelledBy || "",
    cancelStage: order.cancelStage || "",
    commissionRefunded: order.commissionRefunded === true ||
      order.adminCommissionRefunded === true,
    createdAt: order.createdAt || null,
    updatedAt: order.updatedAt || null,
    date: order.date || order.createdAt || null,
    dateAccept: order.acceptedAt || null,
  };
}

function canDriverSeeOrder(order, driver, { driverPoint = null, radiusKm = 10, passenger = null } = {}) {
  if (!order || Number(order.status) !== ORDER_STATUS.OPEN || normalizeString(order.driverId)) return false;
  if (!driver || driver.isDriver !== true || normalizeString(driver.statusDriver).toLowerCase() !== "approved") {
    return false;
  }
  const orderPoints = [
    order.fromPoint,
    order.otCoords,
    passenger?.coords,
  ].filter(Boolean);
  if (driverPoint && orderPoints.length > 0) {
    const distances = orderPoints
      .map((point) => distanceKmBetween(driverPoint, point))
      .filter(Number.isFinite);
    if (distances.length > 0 && !distances.some((distance) => distance <= radiusKm)) {
      return false;
    }
  }
  return true;
}

function sortOrdersNewestFirst(a, b) {
  return (asDate(b.createdAt)?.getTime() || 0) - (asDate(a.createdAt)?.getTime() || 0);
}

async function getOrderDetailsAsync(data = {}, auth) {
  if (!auth?.user) {
    return { success: false, code: "UNAUTHENTICATED", error: "Пользователь не авторизован" };
  }
  const orderId = docId(data.orderDocPath || data.orderId);
  return readStoreAsync(orderScope(orderId)).then(async (store) => {
    const order = store.orders.find((item) => item.id === orderId);
    if (!order) return { success: false, code: "ORDER_NOT_FOUND", error: "Заказ не найден" };
    const isOwner = order.userId === auth.user.id || order.driverId === auth.user.id;
    const isAdminUser = auth.user.role === "admin";
    if (!isOwner && !isAdminUser && !canDriverSeeOrder(order, auth.user)) {
      return { success: false, code: "ORDER_FORBIDDEN", error: "Нет доступа к заказу" };
    }
    return { success: true, order: compactOrder(order), orderDocPath: orderDocPath(order) };
  });
}

async function listAvailableDriverOrdersAsync(data = {}, auth) {
  if (!auth?.user) {
    return { success: false, code: "UNAUTHENTICATED", error: "Пользователь не авторизован" };
  }
  const radiusKm = asNumber(data.radiusKm) ?? 10;
  const driverPoint = geoPointFromData(data, "driver") || geoPointFromData(data);
  const limit = Math.max(1, Math.min(200, Math.trunc(asNumber(data.limit) || 100)));
  return readStoreAsync(feedScope(auth.user.id)).then(async (store) => {
    const driver = store.users.find((user) => user.id === auth.user.id);
    if (!driver) return { success: false, code: "DRIVER_NOT_FOUND", error: "Водитель не найден" };
    const orders = store.orders
      .filter((order) => canDriverSeeOrder(order, driver, {
        driverPoint,
        radiusKm,
        passenger: store.users.find((user) => user.id === order.userId),
      }))
      .sort(sortOrdersNewestFirst)
      .slice(0, limit)
      .map(compactOrder);
    return {
      success: true,
      code: "DRIVER_ORDERS_LOADED",
      orders,
      count: orders.length,
      radiusKm,
    };
  });
}

async function listMyOrdersAsync(data = {}, auth) {
  if (!auth?.user) {
    return { success: false, code: "UNAUTHENTICATED", error: "Пользователь не авторизован" };
  }
  const includeClosed = data.includeClosed === true;
  const limit = Math.max(1, Math.min(200, Math.trunc(asNumber(data.limit) || 50)));
  return readStoreAsync(historyScope(auth.user.id)).then(async (store) => {
    const orders = store.orders
      .filter((order) => order.userId === auth.user.id || order.driverId === auth.user.id)
      .filter((order) => includeClosed || isActivePassengerOrder(order))
      .sort(sortOrdersNewestFirst)
      .slice(0, limit)
      .map(compactOrder);
    return { success: true, code: "MY_ORDERS_LOADED", orders, count: orders.length };
  });
}

async function adminListOrdersAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  const statusFilter = data.status == null || data.status === "" ? null : Number(data.status);
  const userId = docId(data.userDocPath || data.userId);
  const driverId = docId(data.driverDocPath || data.driverId);
  const query = normalizeString(data.query).toLowerCase();
  const limit = Math.max(1, Math.min(500, Math.trunc(asNumber(data.limit) || 200)));
  return readStoreAsync({tables:{orders:true}}).then(async (store) => {
    const orders = store.orders
      .filter((order) => statusFilter == null || Number(order.status) === statusFilter)
      .filter((order) => !userId || order.userId === userId)
      .filter((order) => !driverId || order.driverId === driverId)
      .filter((order) => {
        if (!query) return true;
        return [
          order.id,
          order.type,
          order.city,
          order.ot,
          order.kuda,
          order.comment,
          order.customerName,
          order.customerPhone,
          order.driverName,
          order.driverPhone,
          order.userId,
          order.driverId,
          order.price,
          order.status,
        ].some((value) => normalizeString(value).toLowerCase().includes(query));
      })
      .sort(sortOrdersNewestFirst)
      .slice(0, limit)
      .map(compactOrder);
    return { success: true, code: "ADMIN_ORDERS_LOADED", orders, count: orders.length };
  });
}

function closeActiveOrderRefs(store, order) {
  if ([6, 7].includes(Number(order.status))) refundPassengerBonus(store, order);
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
  }
}

async function expirePendingOrderIfNeededAsync(data = {}, auth) {
  if (!auth?.user) {
    return { success: false, code: "UNAUTHENTICATED", error: "Пользователь не авторизован" };
  }
  const orderId = docId(data.orderDocPath || data.orderId);
  if (!orderId) {
    return { success: false, code: "ORDER_NOT_FOUND", error: "Заказ не найден" };
  }

  return withStoreAsync(async (store) => expirePendingOrderIfNeededInStore(store, data, orderId));
}

function expirePendingOrderIfNeededInStore(store, data, orderId) {
  const order = store.orders.find((item) => item.id === orderId);
  if (!order) {
    return { success: true, expired: true, code: "ORDER_NOT_FOUND", status: ORDER_STATUS.EXPIRED };
  }
  if (!isOpenPendingOrder(order)) {
    return {
      success: true,
      expired: false,
      code: "ORDER_NOT_PENDING",
      status: Number(order.status),
      order: compactOrder(order),
    };
  }

  const ttlMinutes =
    asNumber(data.ttlMinutes) ??
    asNumber(store.settings?.pendingOrderLifetimeMin) ??
    15;
  const createdAt = asDate(order.createdAt) || new Date();
  const ageMs = Date.now() - createdAt.getTime();
  const expired = ttlMinutes <= 0 || ageMs >= ttlMinutes * 60 * 1000;
  if (!expired) {
    return {
      success: true,
      expired: false,
      code: "ORDER_STILL_PENDING",
      status: Number(order.status),
      expiresAt: new Date(createdAt.getTime() + ttlMinutes * 60 * 1000).toISOString(),
      order: compactOrder(order),
    };
  }

  order.status = ORDER_STATUS.EXPIRED;
  order.expiredAt = new Date().toISOString();
  order.updatedAt = new Date().toISOString();
  closeActiveOrderRefs(store, order);
  return {
    success: true,
    expired: true,
    code: "ORDER_EXPIRED",
    status: order.status,
    orderDocPath: orderDocPath(order),
    order: compactOrder(order),
  };
}

async function expireStalePendingOrdersAsync(data = {}) {
  const ttlMinutes = asNumber(data.ttlMinutes);
  const limit = Math.max(1, Math.min(1000, Math.trunc(asNumber(data.limit) || 500)));
  return withStoreAsync(async (store) => expireStalePendingOrdersInStore(store, { ttlMinutes, limit }));
}

function expireStalePendingOrdersInStore(store, { ttlMinutes, limit }) {
  const effectiveTtlMinutes =
    ttlMinutes ??
    asNumber(store.settings?.pendingOrderLifetimeMin) ??
    15;
  const now = Date.now();
  const expiredOrders = [];
  for (const order of store.orders || []) {
    if (expiredOrders.length >= limit) break;
    if (!isOpenPendingOrder(order)) continue;
    const createdAt = asDate(order.createdAt) || new Date();
    const expired =
      effectiveTtlMinutes <= 0 ||
      now - createdAt.getTime() >= effectiveTtlMinutes * 60 * 1000;
    if (!expired) continue;
    order.status = ORDER_STATUS.EXPIRED;
    order.expiredAt = new Date(now).toISOString();
    order.updatedAt = order.expiredAt;
    closeActiveOrderRefs(store, order);
    expiredOrders.push(compactOrder(order));
  }
  return {
    success: true,
    code: "STALE_PENDING_ORDERS_EXPIRED",
    ttlMinutes: effectiveTtlMinutes,
    expiredCount: expiredOrders.length,
    expiredOrders,
  };
}

async function acceptOrderAsync(data = {}, auth) {
  if (!auth?.user) {
    return { success: false, accepted: false, code: "UNAUTHENTICATED", error: "Пользователь не авторизован" };
  }
  const orderId = docId(data.orderDocPath || data.orderId);
  if (!orderId) {
    return { success: false, accepted: false, code: "ORDER_NOT_FOUND", error: "Заказ не найден" };
  }

  return withStoreAsync(async (store) => acceptOrderInStore(store, auth, orderId), financialOrderScope(orderId, auth.user.id));
}

function acceptOrderInStore(store, auth, orderId) {
  const driver = store.users.find((user) => user.id === auth.user.id);
  if (!driver) {
    return { success: false, accepted: false, code: "DRIVER_NOT_FOUND", error: "Водитель не найден" };
  }
  if (driver.blocked === true) return { success:false,accepted:false,code:"DRIVER_BLOCKED",error:"Водитель заблокирован" };
  if (driver.isDriver !== true || normalizeString(driver.statusDriver).toLowerCase() !== "approved") {
    return { success: false, accepted: false, code: "DRIVER_NOT_APPROVED", error: "Водитель не подтвержден" };
  }
  const active = store.orders.find(
    (order) => order.id === driver.activeDriverOrderId && isActivePassengerOrder(order),
  );
  if (active) {
    return {
      success: false,
      accepted: false,
      code: "DRIVER_HAS_ACTIVE_ORDER",
      error: "У водителя уже есть активный заказ",
      orderDocPath: orderDocPath(active),
      driverDocPath: userDocPath(driver),
    };
  }

  const order = store.orders.find((item) => item.id === orderId);
  if (!order || !isActivePassengerOrder(order)) {
    return { success: false, accepted: false, code: "ORDER_NOT_AVAILABLE", error: "Заказ уже недоступен" };
  }
  if (Number(order.status) !== ORDER_STATUS.OPEN) {
    return { success: false, accepted: false, code: "ORDER_ALREADY_ACCEPTED", error: "Заказ взял другой водитель" };
  }

  if (order.userId === driver.id) return { success: false, code: "OWN_ORDER_FORBIDDEN", error: "Нельзя принять собственный заказ" };
  const isVipDriver = driver.vip === true;
  const requiredBalance = isVipDriver ? 0 : requiredDriverBalance(order, store.settings || {});
  const balance = asNumber(driver.balance) || 0;
  if (!debitCommission(driver, order, requiredBalance)) {
    return {
      success: false,
      accepted: false,
      code: "INSUFFICIENT_DRIVER_BALANCE",
      error: `Недостаточно баланса. Нужно минимум ${requiredBalance} ₸`,
      requiredBalance,
      balance,
    };
  }

  driver.activeDriverOrderId = order.id;
  driver.hasActiveDriverOrder = true;
  driver.roleState = "DRIVER_ON_TRIP";

  order.commissionRefunded = false;
  order.adminCommissionRefunded = false;
  order.status = ORDER_STATUS.DRIVER_ASSIGNED;
  order.driverId = driver.id;
  order.driverName = driver.displayName || "";
  order.driverPhone = driver.phone || "";
  order.driverCar = [driver.carBrand || driver.marka || driver.Marka, driver.carModel || driver.model, driver.color].filter(Boolean).join(" ");
  order.driverPlate = driver.gosNomer || "";
  order.acceptedAt = new Date().toISOString();
  order.acceptedCommission = requiredBalance;
  order.updatedAt = new Date().toISOString();
  if (requiredBalance > 0) {
    addLedger(store, {
      type: "order_commission",
      userId: driver.id,
      orderId: order.id,
      amount: requiredBalance,
      bonusAmount: order.acceptedBonusCommission,
      cashAmount: order.acceptedCashCommission,
      balanceBefore: balance,
      balanceAfter: driver.balance,
    });
  }
  queueOrderPushEventInStore(store, {
    order,
    eventType: "ORDER_ACCEPTED",
    targetRole: "passenger",
    targetUserIds: [order.userId],
    title: "Водитель назначен",
    body: driver.displayName || "Водитель принял заказ",
    orderAlert: false,
    initialPageName: "seachDriver",
  });
  queueOrderPushEventInStore(store, {
    order,
    eventType: "ORDER_TAKEN_BY_OTHER_DRIVER",
    targetRole: "driver",
    excludeUserIds: [driver.id],
    title: "Заказ взял другой водитель",
    body: `${order.ot} -> ${order.kuda}`,
    orderAlert: false,
    initialPageName: "homeDriver",
  });

  return {
    success: true,
    accepted: true,
    code: "ORDER_ACCEPTED",
    orderDocPath: orderDocPath(order),
    driverDocPath: userDocPath(driver),
    status: order.status,
    requiredBalance,
    chargedBalance: requiredBalance,
    balance: driver.balance,
  };
}

async function cancelPassengerOrderAsync(data = {}, auth) {
  if (!auth?.user) {
    return { success: false, code: "UNAUTHENTICATED", error: "Пользователь не авторизован" };
  }
  const orderId = docId(data.orderDocPath || data.orderId);
  return withStoreAsync(async (store) => cancelPassengerOrderInStore(store, auth, orderId), financialOrderScope(orderId, auth.user.id));
}

function cancelPassengerOrderInStore(store, auth, orderId) {
  const order = store.orders.find((item) => item.id === orderId);
  if (!order) {
    return { success: true, code: "ORDER_CANCELLED" };
  }
  if (order.userId !== auth.user.id) return { success: false, code: "ORDER_FORBIDDEN", error: "Нет доступа к заказу" };
  if (Number(order.status) >= 4 && Number(order.status) <= 5) return { success: false, code: "TRIP_ALREADY_STARTED", error: "После начала поездки отмена недоступна" };
  if (Number(order.status) === ORDER_STATUS.CANCELLED) {
    return { success: true, code: "ORDER_CANCELLED", orderDocPath: orderDocPath(order) };
  }
  if (!isActivePassengerOrder(order)) {
    return { success: false, code: "ORDER_NOT_ACTIVE", error: "Заказ уже закрыт" };
  }

  const driver = store.users.find((user) => user.id === order.driverId);
  if (driver?.activeDriverOrderId === order.id) {
    driver.activeDriverOrderId = null;
    driver.hasActiveDriverOrder = false;
    driver.roleState = driver.driverOnLine === false ? "DRIVER_OFFLINE" : "DRIVER_ONLINE";
    const refund = asNumber(order.acceptedCommission) || 0;
    if (refund > 0) {
      const before = asNumber(driver.balance) || 0;
      refundCommission(driver, order);
      addLedger(store, {
        type: "order_commission_refund",
        userId: driver.id,
        orderId: order.id,
        amount: refund,
        balanceBefore: before,
        balanceAfter: driver.balance,
      });
    }
  }
  closeActiveOrderRefs(store, order);
  refundPassengerBonus(store, order);
  order.status = ORDER_STATUS.CANCELLED;
  order.cancelledBy = auth.user.id === order.userId ? "passenger" : "system";
  order.cancelledAt = new Date().toISOString();
  order.updatedAt = new Date().toISOString();
  if (driver) {
    queueOrderPushEventInStore(store, {
      order,
      eventType: "ORDER_CANCELLED_BY_PASSENGER",
      targetRole: "driver",
      targetUserIds: [driver.id],
      title: "Заказ отменен пассажиром",
      body: `${order.ot} -> ${order.kuda}`,
      orderAlert: true,
      initialPageName: "homeDriver",
    });
  }
  return {
    success: true,
    code: "ORDER_CANCELLED",
    orderDocPath: orderDocPath(order),
    status: order.status,
  };
}

async function advanceDriverOrderStatusAsync(data = {}, auth) {
  if (!auth?.user) {
    return { success: false, code: "UNAUTHENTICATED", error: "Пользователь не авторизован" };
  }
  const orderId = docId(data.orderDocPath || data.orderId);
  const nextStatus = Number(data.nextStatus);
  if (![ORDER_STATUS.DRIVER_ARRIVED, ORDER_STATUS.TRIP_STARTED, ORDER_STATUS.COMPLETED].includes(nextStatus)) {
    return { success: false, code: "ORDER_INVALID_STATUS", error: "Некорректный статус заказа" };
  }

  return withStoreAsync(async (store) => advanceDriverOrderStatusInStore(store, auth, orderId, nextStatus), financialOrderScope(orderId, auth.user.id));
}

function advanceDriverOrderStatusInStore(store, auth, orderId, nextStatus) {
  const order = store.orders.find((item) => item.id === orderId);
  const driver = store.users.find((user) => user.id === auth.user.id);
  if (!order || !driver || order.driverId !== driver.id) {
    return { success: false, code: "ORDER_NOT_ASSIGNED_TO_DRIVER", error: "Заказ не назначен этому водителю" };
  }
  if (!isActivePassengerOrder(order)) {
    return { success: false, code: "ORDER_NOT_ACTIVE", error: "Заказ уже закрыт" };
  }
  if (nextStatus === Number(order.status)) return { success: true, code: "ORDER_STATUS_UNCHANGED", status: order.status };
  if (nextStatus !== Number(order.status) + 1) return { success: false, code: "ORDER_STATUS_SEQUENCE_REQUIRED", error: "Сначала отметьте прибытие, затем начало поездки" };
  if (nextStatus < Number(order.status)) {
    return { success: false, code: "ORDER_STATUS_ROLLBACK_DENIED", error: "Нельзя вернуть заказ на старый статус" };
  }

  if (nextStatus === 3 && order.fromPoint) {
    const { meters } = require('./trip_automation');
    const fresh = Date.now() - Date.parse(driver.coordsUpdatedAt || '') <= 30000;
    const accurate = Number(driver.coordsAccuracy) > 0 && Number(driver.coordsAccuracy) <= 40;
    if (!fresh || !accurate || !driver.coords || meters(order.fromPoint, driver.coords) > 120) return { success:false, code:"PICKUP_GPS_REQUIRED",error:"Для прибытия нужна свежая точная геопозиция рядом с местом посадки" };
    order.pickupPresenceVerified = true;
  }
  if (nextStatus === 4 && order.fromPoint && !order.pickupPresenceVerified) return { success:false,code:"PICKUP_NOT_VERIFIED",error:"Сначала подтвердите прибытие к месту посадки" };
  order.status = nextStatus;
  order.updatedAt = new Date().toISOString();
  if (nextStatus === ORDER_STATUS.DRIVER_ARRIVED) {
    order.driverArrivedAt = new Date().toISOString();
    queueOrderPushEventInStore(store, {
      order,
      eventType: "DRIVER_ARRIVED",
      targetRole: "passenger",
      targetUserIds: [order.userId],
      title: "Водитель приехал",
      body: orderRouteText(order),
      orderAlert: true,
      initialPageName: "seachDriver",
    });
  }
  if (nextStatus === ORDER_STATUS.TRIP_STARTED) {
    order.tripStartedAt = new Date().toISOString();
    queueOrderPushEventInStore(store, {
      order,
      eventType: "TRIP_STARTED",
      targetRole: "passenger",
      targetUserIds: [order.userId],
      title: "Поездка началась",
      body: orderRouteText(order),
      orderAlert: false,
      initialPageName: "seachDriver",
    });
  }
  if (nextStatus === ORDER_STATUS.COMPLETED) {
    order.completedAt = new Date().toISOString();
    recordCompletedOrder(store, driver, order);
    settlePassengerBonus(store, order, driver);
    closeActiveOrderRefs(store, order);
    queueOrderPushEventInStore(store, {
      order,
      eventType: "ORDER_COMPLETED",
      targetRole: "passenger",
      targetUserIds: [order.userId],
      title: "Заказ завершен",
      body: orderRouteText(order),
      orderAlert: false,
      initialPageName: "homePage",
    });
  }

  return {
    success: true,
    code: "ORDER_STATUS_UPDATED",
    orderDocPath: orderDocPath(order),
    driverDocPath: userDocPath(driver),
    status: order.status,
  };
}

function orderRouteText(order) {
  return [normalizeString(order?.ot), normalizeString(order?.kuda)].filter(Boolean).join(" -> ");
}

function orderTitleForDriver(order) {
  const type = normalizeString(order?.type).toLowerCase();
  if (type === "delivery") return "Новая доставка";
  if (type === "intercity") return "Новый межгород";
  return "Новый заказ такси";
}

module.exports = {
  ORDER_STATUS,
  calculateOrderQuoteFromData,
  calculateOrderQuoteAsync,
  getOrderQuoteAsync,
  createPassengerOrderAsync,
  adminCreateOrderAsync,
  compactOrder,
  getOrderDetailsAsync,
  listAvailableDriverOrdersAsync,
  listMyOrdersAsync,
  adminListOrdersAsync,
  expirePendingOrderIfNeededAsync,
  expireStalePendingOrdersAsync,
  acceptOrderAsync,
  acceptOrderInStore,
  cancelPassengerOrderAsync,
  advanceDriverOrderStatusAsync,
  advanceDriverOrderStatusInStore,
};

function intercityDisabled() {
  return { success: false, code: "INTERCITY_DISABLED", error: "Межгород временно отключён" };
}
