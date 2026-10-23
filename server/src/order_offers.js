const { trackingScope, offerReadScope, financialOrderScope } = require("./store/scopes");
const { withStoreAsync, readStoreAsync, newId } = require("./store");
const { acceptOrderInStore } = require("./orders");
const { routeLookup } = require("./geocoding");
const { queueOrderPushEventInStore } = require("./push");
const { reservePassengerBonus } = require("./passenger_bonuses");
const idOf = (data) =>
  String(data.orderDocPath || data.orderId || "")
    .split("/")
    .pop();
const fail = (code, error) => ({ success: false, code, error });
const point = (p) =>
  p &&
  Number.isFinite(Number(p.latitude ?? p.lat)) &&
  Number.isFinite(Number(p.longitude ?? p.lng))
    ? { lat: Number(p.latitude ?? p.lat), lng: Number(p.longitude ?? p.lng) }
    : null;
const freshPoint = (u) =>
  u?.coordsUpdatedAt && Date.now() - Date.parse(u.coordsUpdatedAt) < 120000
    ? point(u.coords)
    : null;
function driverDetails(store, user) {
  return {
    driverId: user.id,
    driverName: user.displayName || "Водитель",
    driverPhoto: user.photoUrl || "",
    driverCar: [user.carBrand || user.marka || user.Marka, user.carModel || user.model, user.color]
      .filter(Boolean)
      .join(" "),
    driverPlate: user.gosNomer || "",
    rating:
      Number(user.ratingCount) > 0
        ? Number(user.ratingTotal) / user.ratingCount
        : null,
    ratingCount: Number(user.ratingCount) || 0,
    completedTrips: store.orders.filter(
      (o) => o.driverId === user.id && Number(o.status) === 5,
    ).length,
  };
}
async function submitOrderOfferAsync(data, auth) {
  if (!auth?.user) return fail("UNAUTHENTICATED", "Войдите в приложение");
  const price = Number(data.price);
  if (!Number.isSafeInteger(price) || price < 500 || price > 10000000)
    return fail("PRICE_MINIMUM", "Цена — целое число от 500 ₸");
  const snapshot = await readStoreAsync(offerReadScope(idOf(data), auth.user.id));
  const order = snapshot.orders.find((o) => o.id === idOf(data));
  const driver = snapshot.users.find((u) => u.id === auth.user.id);
  if (
    !order ||
    order.status !== 0 ||
    order.userId === driver?.id ||
    driver?.isDriver !== true ||
    driver.statusDriver !== "approved"
  )
    return fail("OFFER_FORBIDDEN", "Нельзя предложить цену по этому заказу");
  let etaMinutes = null;
  const from = freshPoint(driver),
    to = point(order.fromPoint);
  if (from && to) {
    try {
      const route = await routeLookup({ from, to });
      if (route.success)
        etaMinutes = Math.max(1, Math.ceil(route.durationSeconds / 60));
    } catch (_) {}
  }
  return withStoreAsync((store) => {
    const o = store.orders.find((item) => item.id === order.id);
    const d = store.users.find((u) => u.id === driver.id);
    if (
      !o ||
      o.status !== 0 ||
      d?.statusDriver !== "approved" ||
      d.blocked ||
      d.hasActiveDriverOrder
    )
      return fail("ORDER_NOT_AVAILABLE", "Заказ уже недоступен");
    o.offers ||= [];
    const prior = o.offers.find((x) => x.driverId === d.id);
    if (prior && Date.now() - Date.parse(prior.createdAt) < 5000)
      return fail("OFFER_TOO_FREQUENT", "Подождите несколько секунд");
    o.offers = o.offers.filter(
      (x) => x.status === "pending" && Date.parse(x.expiresAt) > Date.now(),
    );
    if (o.offers.length >= 30)
      return fail("OFFER_LIMIT", "У пассажира уже много предложений");
    o.offers = o.offers.filter((x) => x.driverId !== d.id);
    const offer = {
      id: newId("offer"),
      ...driverDetails(store, d),
      price,
      etaMinutes,
      createdAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 120000).toISOString(),
      status: "pending",
    };
    o.offers.push(offer);
    queueOrderPushEventInStore(store, {
      order: o,
      eventId: offer.id,
      eventType: "DRIVER_PRICE_OFFER",
      targetRole: "passenger",
      targetUserIds: [o.userId],
      title: "Водитель предложил цену",
      body: `${offer.driverName}: ${price} ₸${etaMinutes ? ", подача " + etaMinutes + " мин" : ""}`,
      orderAlert: true,
      initialPageName: "seachDriver",
    });
    return { success: true, offer };
  }, financialOrderScope(order.id, driver.id));
}
async function listOrderOffersAsync(data, auth) {
  if (!auth?.user) return fail("UNAUTHENTICATED", "Войдите в приложение");
  const store = await readStoreAsync(offerReadScope(idOf(data)));
  const o = store.orders.find((x) => x.id === idOf(data));
  if (!o || o.userId !== auth.user.id)
    return fail("ORDER_FORBIDDEN", "Нет доступа к предложениям");
  return {
    success: true,
    offers:
      o.status === 0
        ? (o.offers || []).filter(
            (x) =>
              x.status === "pending" &&
              Date.parse(x.expiresAt) > Date.now() &&
              store.users.some(
                (d) =>
                  d.id === x.driverId &&
                  !d.blocked &&
                  d.statusDriver === "approved" &&
                  !d.hasActiveDriverOrder,
              ),
          )
        : [],
  };
}
async function respondOrderOfferAsync(data, auth) {
  if (!auth?.user) return fail("UNAUTHENTICATED", "Войдите в приложение");
  return withStoreAsync((store) => {
    const o = store.orders.find((x) => x.id === idOf(data));
    if (!o || o.userId !== auth.user.id)
      return fail("ORDER_FORBIDDEN", "Нет доступа к заказу");
    if (o.acceptedOfferId === data.offerId)
      return { success: true, accepted: true, alreadyAccepted: true };
    const offer = (o.offers || []).find((x) => x.id === data.offerId);
    if (
      o.status !== 0 ||
      !offer ||
      offer.status !== "pending" ||
      Date.parse(offer.expiresAt) <= Date.now()
    )
      return fail("OFFER_EXPIRED", "Предложение уже недоступно");
    if (data.accept !== true) {
      offer.status = "declined";
      return { success: true };
    }
    const driver = store.users.find((u) => u.id === offer.driverId);
    if (!driver || driver.blocked)
      return fail("DRIVER_UNAVAILABLE", "Водитель недоступен");
    const passenger = store.users.find((u) => u.id === o.userId);
    const previous = {
      price: o.price,
      passengerBonusUsed: o.passengerBonusUsed,
      passengerWalletUsed: o.passengerWalletUsed,
      cashToDriver: o.cashToDriver,
    };
    const balance = passenger.balance,
      bonus = passenger.passengerBonusBalance;
    const ledgerLength = (store.ledger || []).length;
    store.ledger ||= [];
    if ((o.passengerBonusUsed || 0) + (o.passengerWalletUsed || 0) > 0)
      store.ledger.push({
        id: newId("ledger"),
        type: "passenger_trip_reprice_release",
        userId: passenger.id,
        orderId: o.id,
        amount: (o.passengerBonusUsed || 0) + (o.passengerWalletUsed || 0),
        cashAmount: o.passengerWalletUsed || 0,
        bonusAmount: o.passengerBonusUsed || 0,
        createdAt: new Date().toISOString(),
      });
    passenger.balance =
      (Number(balance) || 0) + (Number(o.passengerWalletUsed) || 0);
    passenger.passengerBonusBalance =
      (Number(bonus) || 0) + (Number(o.passengerBonusUsed) || 0);
    o.price = offer.price;
    const reservation = reservePassengerBonus(
      store,
      o,
      passenger,
      o.usePassengerBonuses === true,
    );
    const result =
      reservation || acceptOrderInStore(store, { user: driver }, o.id);
    if (!result.accepted) {
      Object.assign(o, previous);
      passenger.balance = balance;
      passenger.passengerBonusBalance = bonus;
      store.ledger.length = ledgerLength;
      return result;
    }
    o.acceptedOfferId = offer.id;
    o.offers.forEach((x) => {
      x.status = x.id === offer.id ? "accepted" : "closed";
    });
    return result;
  }, financialOrderScope(idOf(data), auth.user.id));
}
async function getTripTrackingAsync(data, auth) {
  if (!auth?.user) return fail("UNAUTHENTICATED", "Войдите в приложение");
  const store = await readStoreAsync(trackingScope(idOf(data)));
  const o = store.orders.find((x) => x.id === idOf(data));
  if (!o || ![o.userId, o.driverId].includes(auth.user.id))
    return fail("ORDER_FORBIDDEN", "Нет доступа к маршруту");
  const driver = store.users.find((u) => u.id === o.driverId);
  const position = [2, 3, 4].includes(o.status) ? freshPoint(driver) : null;
  return {
    success: true,
    status: o.status,
    driver: driver ? driverDetails(store, driver) : null,
    driverPosition: position,
    positionUpdatedAt: driver?.coordsUpdatedAt || null,
    from: point(o.fromPoint),
    to: point(o.toPoint),
    price: o.price,
    cashToDriver: o.cashToDriver ?? o.price,
  };
}
async function rateTripDriverAsync(data, auth) {
  if (!auth?.user) return fail("UNAUTHENTICATED", "Войдите в приложение");
  const stars = Number(data.stars);
  if (!Number.isInteger(stars) || stars < 1 || stars > 5)
    return fail("RATING_INVALID", "Оценка от 1 до 5");
  return withStoreAsync((store) => {
    const o = store.orders.find((x) => x.id === idOf(data));
    if (!o || o.userId !== auth.user.id || o.status !== 5)
      return fail(
        "RATING_FORBIDDEN",
        "Оценить можно только свою завершённую поездку",
      );
    if (o.driverRating) return { success: true };
    const d = store.users.find((u) => u.id === o.driverId);
    if (!d) return fail("DRIVER_UNAVAILABLE", "Водитель недоступен");
    o.driverRating = stars;
    d.ratingCount = (Number(d.ratingCount) || 0) + 1;
    d.ratingTotal = (Number(d.ratingTotal) || 0) + stars;
    return { success: true };
  });
}
module.exports = {
  submitOrderOfferAsync,
  listOrderOffersAsync,
  respondOrderOfferAsync,
  getTripTrackingAsync,
  rateTripDriverAsync,
};
