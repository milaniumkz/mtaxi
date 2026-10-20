const { withStoreAsync } = require("./store");
const { compactOrder, ORDER_STATUS } = require("./orders");
const { publicUser } = require("./users");

function isActiveOrder(order) {
  return order && [0, 1, 2, 3, 4].includes(Number(order.status));
}

async function getSessionBootstrapAsync(_data, auth) {
  if (!auth?.user) {
    return {
      success: false,
      code: "UNAUTHENTICATED",
      error: "Пользователь не авторизован",
    };
  }

  return withStoreAsync(async (store) => buildSessionBootstrap(store, auth.user));
}

function buildSessionBootstrap(store, authUser) {
  const user = store.users.find((item) => item.id === authUser.id);
  if (!user) {
    return {
      success: false,
      code: "USER_NOT_FOUND",
      error: "Пользователь не найден",
    };
  }

  const passengerOrder = store.orders.find(
    (order) => order.id === user.activePassengerOrderId && isActiveOrder(order),
  );
  const driverOrder = store.orders.find(
    (order) => order.id === user.activeDriverOrderId && isActiveOrder(order),
  );

  if (!passengerOrder && user.activePassengerOrderId) {
    user.activePassengerOrderId = null;
    user.hasActivePassengerOrder = false;
  }
  if (!driverOrder && user.activeDriverOrderId) {
    user.activeDriverOrderId = null;
    user.hasActiveDriverOrder = false;
  }

  if (!passengerOrder && !driverOrder && user.roleState === "DRIVER_ON_TRIP") {
    user.roleState = user.driverOnLine === false ? "DRIVER_OFFLINE" : "DRIVER_ONLINE";
  }
  if (!passengerOrder && !driverOrder && !user.isDriver) {
    user.roleState = "PASSENGER";
  }

  const publicSessionUser = publicUser(user);

  return {
    success: true,
    user: publicSessionUser,
    userDocPath: `users/${user.id}`,
    roleState: publicSessionUser.roleState || "PASSENGER",
    activePassengerOrderRef: passengerOrder ? `order/${passengerOrder.id}` : null,
    activeDriverOrderRef: driverOrder ? `order/${driverOrder.id}` : null,
    activePassengerOrder: compactOrder(passengerOrder),
    activeDriverOrder: compactOrder(driverOrder),
    activePassengerOrderStatus: passengerOrder ? Number(passengerOrder.status) : null,
    activeDriverOrderStatus: driverOrder ? Number(driverOrder.status) : null,
    hasActivePassengerOrder: Boolean(passengerOrder),
    hasActiveDriverOrder: Boolean(driverOrder),
    closedStatusThreshold: ORDER_STATUS.COMPLETED,
    userServerTime: Date.now(),
  };
}

module.exports = {
  getSessionBootstrapAsync,
};
