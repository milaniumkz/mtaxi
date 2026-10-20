require("dotenv").config();

const {
  callBackend,
  expectJson,
  assertBackendOnlyArchitecture,
  isLocalBaseUrl,
} = require("./smoke_backend");

function normalize(value) {
  return value == null ? "" : String(value).trim();
}

function fail(message) {
  throw new Error(message);
}

function orderIdFromPath(value) {
  return normalize(value).split("/").filter(Boolean).pop();
}

function assertOrderVisible(feed, orderDocPath) {
  const orderId = orderIdFromPath(orderDocPath);
  const orders = Array.isArray(feed.orders) ? feed.orders : [];
  const found = orders.find((order) => {
    const id = orderIdFromPath(order.orderDocPath || order.id || order.path);
    return id === orderId;
  });
  if (!found) {
    fail(`created order is not visible in driver feed: ${orderDocPath}`);
  }
  return found;
}

async function login(baseUrl, label, phone, password) {
  const result = await callBackend(baseUrl, "passwordLogin", { phone, password });
  const token = normalize(result.token);
  if (!token) fail(`${label} login did not return token`);
  await callBackend(baseUrl, "getSessionBootstrap", {}, token);
  return { token, user: result.user || null };
}

async function main() {
  const baseUrl =
    normalize(process.env.MTAXI_FUNCTIONAL_SMOKE_BASE_URL) ||
    normalize(process.env.MTAXI_SMOKE_BASE_URL) ||
    "http://127.0.0.1:8080";

  if (!isLocalBaseUrl(baseUrl) && process.env.MTAXI_FUNCTIONAL_SMOKE_ALLOW_REMOTE !== "true") {
    fail("functional smoke is destructive; use a local backend or set MTAXI_FUNCTIONAL_SMOKE_ALLOW_REMOTE=true");
  }

  await expectJson(`${baseUrl}/livez`);
  const ready = await expectJson(`${baseUrl}/readyz`);
  const storeType = normalize(ready.store?.type).toLowerCase();
  if (storeType && storeType !== "json") {
    fail(`local functional smoke expects disposable JSON store, got ${storeType}`);
  }

  const architecture = await callBackend(baseUrl, "getBackendArchitectureStatus");
  assertBackendOnlyArchitecture(architecture);

  const passenger = await login(baseUrl, "passenger", "7052597368", "123456");
  const driver = await login(baseUrl, "driver", "7086362153", "123456");
  const admin = await login(baseUrl, "admin", "70000000000", "A7059012671!");

  const order = await callBackend(baseUrl, "createPassengerOrder", {
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
    comment: "local functional smoke",
    distanceKm: 3,
    fromLatitude: 50.1305,
    fromLongitude: 82.5242,
    toLatitude: 50.135,
    toLongitude: 82.531,
  }, passenger.token);
  if (order.created !== true || !order.orderDocPath) {
    fail(`createPassengerOrder did not create order: ${JSON.stringify(order)}`);
  }

  const passengerDetails = await callBackend(
    baseUrl,
    "getOrderDetails",
    { orderDocPath: order.orderDocPath },
    passenger.token,
  );
  if (passengerDetails.order?.ot !== "Алтайская 12" || passengerDetails.order?.kuda !== "Переулок Степной 15") {
    fail("passenger order details lost route text");
  }

  const feed = await callBackend(baseUrl, "listAvailableDriverOrders", {
    limit: 20,
    radiusKm: 10,
    driverLatitude: 50.1306,
    driverLongitude: 82.5243,
  }, driver.token);
  const feedOrder = assertOrderVisible(feed, order.orderDocPath);
  if (feedOrder.type !== "taxi" || feedOrder.ot !== "Алтайская 12" || feedOrder.kuda !== "Переулок Степной 15") {
    fail("driver feed order lost type or route text");
  }

  const accepted = await callBackend(baseUrl, "acceptOrder", {
    orderDocPath: order.orderDocPath,
  }, driver.token);
  if (accepted.accepted !== true || Number(accepted.status) !== 2) {
    fail(`driver did not accept order: ${JSON.stringify(accepted)}`);
  }

  for (const nextStatus of [3, 4, 5]) {
    const advanced = await callBackend(baseUrl, "advanceDriverOrderStatus", {
      orderDocPath: order.orderDocPath,
      nextStatus,
    }, driver.token);
    if (Number(advanced.status) !== nextStatus) {
      fail(`order status did not advance to ${nextStatus}: ${JSON.stringify(advanced)}`);
    }
  }

  const passengerAfterComplete = await callBackend(baseUrl, "getSessionBootstrap", {}, passenger.token);
  if (passengerAfterComplete.user?.hasActivePassengerOrder === true) {
    fail("completed order did not clear passenger active order flag");
  }
  const driverAfterComplete = await callBackend(baseUrl, "getSessionBootstrap", {}, driver.token);
  if (driverAfterComplete.user?.hasActiveDriverOrder === true) {
    fail("completed order did not clear driver active order flag");
  }

  const payment = await callBackend(baseUrl, "createDriverTopUpPayment", {
    amount: 1000,
    idempotencyKey: `local-functional-smoke-${Date.now()}`,
  }, driver.token);
  if (!payment.paymentId || !payment.paymentUrl) {
    fail(`local top-up payment was not created: ${JSON.stringify(payment)}`);
  }
  const paymentStatus = await callBackend(baseUrl, "getDriverTopUpPaymentStatus", {
    paymentId: payment.paymentId,
  }, driver.token);
  if (paymentStatus.paymentStatus !== "pending") {
    fail(`local payment must remain pending before admin confirm: ${JSON.stringify(paymentStatus)}`);
  }
  const confirmed = await callBackend(baseUrl, "confirmDriverTopUpPayment", {
    paymentId: payment.paymentId,
  }, admin.token);
  if (confirmed.paymentStatus !== "success") {
    fail(`admin did not confirm local payment: ${JSON.stringify(confirmed)}`);
  }

  const supportChat = await callBackend(baseUrl, "ensureSupportChat", {}, passenger.token);
  if (!supportChat.chatPath) fail("support chat was not created");
  await callBackend(baseUrl, "sendSupportChatMessage", {
    chatDocPath: supportChat.chatPath,
    text: "local functional smoke",
  }, passenger.token);
  const chats = await callBackend(baseUrl, "listSupportChats", {}, admin.token);
  if (!Array.isArray(chats.chats) || chats.chats.length < 1) {
    fail("admin cannot see support chat");
  }

  console.log(`MTaxi local functional smoke passed: ${baseUrl}`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`MTaxi local functional smoke failed: ${error?.message || String(error)}`);
    process.exit(1);
  });
}

module.exports = { main };
