const { withStoreAsync, readStoreAsync, writeStoreAsync, newId } = require("./store");
const { requireAdmin } = require("./admin");
const { asNumber, normalizeString } = require("./utils/values");
const { sendPushBatch } = require("./push_transport");

function docId(value) {
  const text = normalizeString(value);
  return text.split("/").filter(Boolean).pop() || text;
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

function userPath(userId) {
  return `users/${userId}`;
}

function chatPath(chat) {
  return `chats/${chat.id}`;
}

function supportKeyFor(userId, adminId) {
  return `users/${userId}|users/${adminId}`;
}

function normalizeDeviceType(value) {
  const text = normalizeString(value).toLowerCase();
  if (text === "ios") return "iOS";
  if (text === "android") return "Android";
  return normalizeString(value) || "unknown";
}

function normalizeAudience(value) {
  const text = normalizeString(value).toLowerCase();
  return ["all", "foreground", "background", "terminated"].includes(text) ? text : "all";
}

function normalizeDeviceAudience(value) {
  const text = normalizeString(value).toLowerCase();
  if (text === "android") return "Android";
  if (text === "ios" || text === "iphone") return "iOS";
  return "All";
}

function normalizeRole(value) {
  const text = normalizeString(value).toLowerCase();
  if (text === "driver" || text === "drivers") return "driver";
  if (text === "passenger" || text === "passengers" || text === "user") return "passenger";
  return "all";
}

function publicToken(token) {
  return {
    id: token.id,
    userId: token.userId,
    userDocPath: userPath(token.userId),
    deviceType: token.deviceType,
    appState: token.appState || "",
    orderAlertsEnabled: token.orderAlertsEnabled !== false,
    updatedAt: token.updatedAt,
  };
}

function findUserForPath(store, userDocPath) {
  const id = docId(userDocPath);
  return store.users.find((user) => user.id === id);
}

function ensureTokenArrays(store) {
  store.fcmTokens ||= [];
  store.notifications ||= [];
  store.notificationDeliveries ||= [];
  store.pushDeliveryAcks ||= [];
}

function ensureBroadcastSupportChat(store, user, adminId) {
  store.chats ||= [];
  store.chatMessages ||= [];
  const supportChatKey = supportKeyFor(user.id, adminId);
  let chat = store.chats.find((item) => item.supportChatKey === supportChatKey);
  if (!chat) {
    chat = {
      id: newId("chat"),
      supportChatKey,
      userId: user.id,
      adminId,
      users: [`users/${user.id}`, `users/${adminId}`],
      lastMessage: "",
      lastMessageTime: null,
      unreadForUser: 0,
      unreadForAdmin: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    store.chats.push(chat);
  }
  user.supportChatKey = supportChatKey;
  user.supportChatPath = chatPath(chat);
  return chat;
}

function upsertToken(store, data, auth) {
  ensureTokenArrays(store);
  const user = findUserForPath(store, data.userDocPath);
  if (!user) {
    return { success: false, code: "USER_NOT_FOUND", error: "Пользователь не найден" };
  }
  if (auth?.user?.id !== user.id) {
    return { success: false, code: "TOKEN_USER_MISMATCH", error: "Нельзя изменить токен другого пользователя" };
  }
  const fcmToken = normalizeString(data.fcmToken);
  const deviceType = normalizeDeviceType(data.deviceType);
  if (!fcmToken || !deviceType) {
    return { success: false, code: "FCM_TOKEN_INVALID", error: "Некорректный FCM токен" };
  }

  const now = new Date().toISOString();
  let token = store.fcmTokens.find((item) => item.fcmToken === fcmToken);
  if (!token) {
    token = {
      id: newId("fcm"),
      fcmToken,
      userId: user.id,
      createdAt: now,
    };
    store.fcmTokens.push(token);
  }

  token.userId = user.id;
  token.deviceType = deviceType;
  token.apnsToken = normalizeString(data.apnsToken);
  token.appState = normalizeString(data.appState || token.appState);
  if (typeof data.orderAlertsEnabled === "boolean") {
    token.orderAlertsEnabled = data.orderAlertsEnabled;
  } else if (token.orderAlertsEnabled == null) {
    token.orderAlertsEnabled = true;
  }
  token.disabled = false;
  token.updatedAt = now;

  return {
    success: true,
    code: "FCM_TOKEN_SAVED",
    token: publicToken(token),
  };
}

async function addFcmTokenAsync(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => upsertToken(store, data, auth));
}

async function updateFcmTokenStateAsync(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => upsertToken(store, data, auth));
}

function tokenMatchesTarget(store, token, notification) {
  if (token.disabled) return false;
  const user = store.users.find((item) => item.id === token.userId);
  if (!user) return false;
  if (notification.orderAlert === true && token.orderAlertsEnabled === false) return false;

  const role = normalizeRole(notification.targetRole);
  if (role === "driver" && user.isDriver !== true) return false;
  if (role === "passenger" && user.isDriver === true && user.roleState !== "PASSENGER") return false;

  const audience = normalizeAudience(notification.targetAudience);
  if (audience !== "all" && normalizeString(token.appState).toLowerCase() !== audience) return false;
  const deviceAudience = normalizeDeviceAudience(notification.targetDeviceType);
  if (deviceAudience !== "All" && normalizeDeviceType(token.deviceType) !== deviceAudience) return false;
  const targetUserIds = Array.isArray(notification.targetUserIds) ? notification.targetUserIds : [];
  if (targetUserIds.length > 0 && !targetUserIds.includes(token.userId)) return false;
  const excludeUserIds = Array.isArray(notification.excludeUserIds) ? notification.excludeUserIds : [];
  if (excludeUserIds.includes(token.userId)) return false;
  return true;
}

function createPushNotificationInStore(store, data = {}, auth = null) {
  ensureTokenArrays(store);
  const nowMs = Date.now();
  const now = new Date(nowMs).toISOString();
  const dedupeKey = normalizeString(data.dedupeKey || data.eventKey);
  if (dedupeKey) {
    const existing = store.notifications.find((item) => item.dedupeKey === dedupeKey);
    if (existing) {
      return {
        success: true,
        code: "PUSH_ALREADY_QUEUED",
        deduped: true,
        notificationId: existing.id,
        deliveries: store.notificationDeliveries.filter((item) => item.notificationId === existing.id),
      };
    }
  }

  const targetUserIds = Array.isArray(data.targetUserIds)
    ? data.targetUserIds.map((item) => docId(item)).filter(Boolean)
    : normalizeString(data.userDocPath)
      ? [docId(data.userDocPath)]
      : [];
  const notification = {
    id: newId("push"),
    title: normalizeString(data.title || data.notificationTitle || "MTaxi"),
    body: normalizeString(data.body || data.notificationText),
    type: normalizeString(data.type || "GENERAL"),
    initialPageName: normalizeString(data.initialPageName),
    parameterData: data.parameterData || data.parameter_data || {},
    dataPayload: data.dataPayload || data.data || {},
    orderId: docId(data.orderDocPath || data.orderId),
    targetRole: normalizeRole(data.targetRole),
    targetAudience: normalizeAudience(data.targetAudience),
    targetDeviceType: normalizeDeviceAudience(data.targetDeviceType || data.deviceType),
    targetUserIds,
    excludeUserIds: Array.isArray(data.excludeUserIds)
      ? data.excludeUserIds.map((item) => docId(item)).filter(Boolean)
      : [],
    orderAlert: data.orderAlert === true,
    dedupeKey,
    createdBy: auth?.user?.id || null,
    createdAt: now,
    sentAtMs: nowMs,
    firebaseDeliveryMode: "simulated-local",
  };
  store.notifications.push(notification);

  const deliveries = store.fcmTokens
    .filter((token) => tokenMatchesTarget(store, token, notification))
    .map((token) => ({
      id: newId("delivery"),
      notificationId: notification.id,
      tokenId: token.id,
      userId: token.userId,
      status: "queued",
      createdAt: now,
    }));
  store.notificationDeliveries.push(...deliveries);

  notification.numTargetTokens = deliveries.length;
  return {
    success: true,
    code: "PUSH_QUEUED",
    notificationId: notification.id,
    notification,
    deliveries,
    numTargetTokens: deliveries.length,
  };
}

function publicNotification(store, notification) {
  const deliveries = (store.notificationDeliveries || [])
    .filter((item) => item.notificationId === notification.id);
  const failed = deliveries.filter((item) => item.status === "failed").length;
  const sent = deliveries.filter((item) => item.status !== "failed").length;
  return {
    id: notification.id,
    notification_title: notification.title || "",
    notification_text: notification.body || "",
    initial_page_name: notification.initialPageName || "",
    parameter_data: notification.parameterData || {},
    target_role: notification.targetRole || "all",
    target_audience: notification.targetDeviceType || "All",
    status: failed > 0 && sent > 0 ? "partial" : failed > 0 ? "failed" : "succeeded",
    created_at: notification.createdAt || null,
    error: notification.error || "",
    num_sent: sent,
    num_failed: failed,
    num_chat_messages: notification.numChatMessages || 0,
    num_target_users: notification.numTargetUsers || 0,
    num_target_tokens: notification.numTargetTokens || deliveries.length,
  };
}

async function adminQueueBroadcastAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  const title = normalizeString(data.title || data.notificationTitle);
  const body = normalizeString(data.body || data.notificationText);
  if (!title || !body) {
    return { success: false, code: "PUSH_BROADCAST_EMPTY", error: "Заполните заголовок и текст уведомления" };
  }

  return withStoreAsync(async (store) => adminQueueBroadcastInStore(store, data, auth, { title, body }));
}

function adminQueueBroadcastInStore(store, data, auth, { title, body }) {
    ensureTokenArrays(store);
    store.chats ||= [];
    store.chatMessages ||= [];
    const role = normalizeRole(data.targetRole);
    const targetUsers = (store.users || []).filter((user) => {
      if (user.role === "admin") return false;
      if (role === "driver") return user.isDriver === true;
      if (role === "passenger") return user.isDriver !== true || user.roleState === "PASSENGER";
      return true;
    });
    const queued = createPushNotificationInStore(store, {
      title,
      body,
      imageUrl: normalizeString(data.imageUrl),
      type: "ADMIN_BROADCAST",
      targetRole: role,
      targetAudience: "all",
      targetDeviceType: normalizeDeviceAudience(data.targetAudience),
      targetUserIds: targetUsers.map((user) => user.id),
      initialPageName: "supportChat",
      dataPayload: { type: "ADMIN_BROADCAST" },
    }, auth);
    const notification = store.notifications.find((item) => item.id === queued.notificationId);
    if (notification) {
      notification.imageUrl = normalizeString(data.imageUrl);
      notification.numTargetUsers = targetUsers.length;
    }
    const adminId = store.users.find((user) => user.role === "admin")?.id || auth.user.id;
    let numChatMessages = 0;
    for (const user of targetUsers) {
      const chat = ensureBroadcastSupportChat(store, user, adminId);
      const message = {
        id: newId("message"),
        chatId: chat.id,
        userId: adminId,
        userPath: `users/${adminId}`,
        text: body,
        imageUrl: normalizeString(data.imageUrl),
        createdAt: new Date().toISOString(),
        readByUser: false,
        readByAdmin: true,
      };
      store.chatMessages.push(message);
      chat.lastMessage = body || "Фото";
      chat.lastMessageTime = message.createdAt;
      chat.updatedAt = message.createdAt;
      chat.unreadForUser = (chat.unreadForUser || 0) + 1;
      numChatMessages += 1;
    }
    if (notification) {
      notification.numChatMessages = numChatMessages;
    }
    return {
      success: true,
      code: "PUSH_BROADCAST_QUEUED",
      notificationId: queued.notificationId,
      numTargetUsers: targetUsers.length,
      numTargetTokens: queued.numTargetTokens || 0,
      numSent: queued.numTargetTokens || 0,
      numFailed: 0,
      numChatMessages,
      notification: notification ? publicNotification(store, notification) : null,
    };
}

async function adminListPushNotificationsAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  const limit = Math.max(1, Math.min(100, Math.trunc(asNumber(data.limit) || 20)));
  return withStoreAsync(async (store) => {
    ensureTokenArrays(store);
    const notifications = [...store.notifications]
      .filter((item) => normalizeString(item.targetRole))
      .sort((a, b) => (asNumber(b.sentAtMs) || Date.parse(b.createdAt || "") || 0) -
        (asNumber(a.sentAtMs) || Date.parse(a.createdAt || "") || 0))
      .slice(0, limit)
      .map((item) => publicNotification(store, item));
    return {
      success: true,
      code: "PUSH_NOTIFICATIONS_LOADED",
      notifications,
      count: notifications.length,
    };
  });
}

async function flushQueuedPushDeliveriesAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return flushQueuedPushDeliveriesInternalAsync(data);
}

async function flushQueuedPushDeliveriesInternalAsync(data = {}) {
  const limit = Math.max(1, Math.min(500, Math.trunc(asNumber(data.limit) || 100)));
  const store = await readStoreAsync();
  return flushQueuedPushDeliveriesForStore(store, limit, writeStoreAsync);
}

async function flushQueuedPushDeliveriesForStore(store, limit, persistStore) {
  ensureTokenArrays(store);
  const queued = store.notificationDeliveries
    .filter((delivery) => normalizeString(delivery.status || "queued") === "queued")
    .slice(0, limit);
  if (queued.length === 0) {
    return {
      success: true,
      code: "PUSH_QUEUE_EMPTY",
      mode: "none",
      numSent: 0,
      numFailed: 0,
    };
  }

  let numSent = 0;
  let numFailed = 0;
  let mode = "none";
  for (const delivery of queued) {
    const notification = store.notifications.find((item) => item.id === delivery.notificationId);
    const token = store.fcmTokens.find((item) => item.id === delivery.tokenId);
    if (!notification || !token || token.disabled) {
      delivery.status = "failed";
      delivery.error = "Notification or token not found";
      delivery.updatedAt = new Date().toISOString();
      numFailed += 1;
      continue;
    }
    try {
      const sent = await sendPushBatch({
        tokens: [token.fcmToken],
        notification,
      });
      mode = sent.mode;
      const result = sent.responses[0] || {};
      delivery.status = result.success ? "sent" : "failed";
      delivery.messageId = result.messageId || "";
      delivery.error = result.error || "";
      delivery.errorCode = result.errorCode || "";
      delivery.sentAt = new Date().toISOString();
      delivery.updatedAt = delivery.sentAt;
      if (result.success) {
        numSent += 1;
      } else {
        numFailed += 1;
      }
    } catch (error) {
      delivery.status = "failed";
      delivery.error = error?.message || String(error);
      delivery.updatedAt = new Date().toISOString();
      numFailed += 1;
    }
  }
  await persistStore(store);
  return {
    success: true,
    code: "PUSH_QUEUE_FLUSHED",
    mode,
    numSent,
    numFailed,
  };
}

function orderTitle(type) {
  const normalized = normalizeString(type).toLowerCase();
  if (normalized === "delivery") return "Новая доставка";
  if (normalized === "intercity") return "Новый межгород";
  return "Новый заказ такси";
}

function orderRouteText(order) {
  const from = normalizeString(order?.ot);
  const to = normalizeString(order?.kuda);
  return [from, to].filter(Boolean).join(" -> ");
}

function queueOrderPushEventInStore(store, {
  order,
  eventType,
  targetRole,
  targetUserIds = [],
  excludeUserIds = [],
  title,
  body,
  orderAlert = false,
  initialPageName,
}) {
  if (!order?.id || !eventType) {
    return null;
  }
  const normalizedEvent = normalizeString(eventType).toUpperCase();
  const status = Number(order.status);
  const role = normalizeRole(targetRole);
  const sentAtMs = Date.now();
  const orderDocPath = `order/${order.id}`;
  const notification = createPushNotificationInStore(store, {
    title: title || orderTitle(order.type),
    body: body || orderRouteText(order) || "Откройте приложение",
    type: normalizedEvent,
    orderDocPath,
    orderId: order.id,
    targetRole: role,
    targetUserIds,
    excludeUserIds,
    orderAlert,
    initialPageName: initialPageName || (role === "driver" ? "homeDriver" : "seachDriver"),
    dedupeKey: `${order.id}:${normalizedEvent}:${role}:${targetUserIds.join(",")}`,
    dataPayload: {
      type: normalizedEvent,
      orderDocPath,
      orderId: order.id,
      orderStatus: String(status),
      targetRole: role,
      initialPageName: initialPageName || (role === "driver" ? "homeDriver" : "seachDriver"),
      sentAtMs: String(sentAtMs),
    },
  });
  if (notification.notification) {
    notification.notification.sentAtMs = sentAtMs;
    notification.notification.dataPayload.notificationId = notification.notificationId;
  }
  return notification;
}

async function createPushNotificationAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => createPushNotificationInStore(store, data, auth));
}

async function ackPushDeliveryAsync(data = {}, auth) {
  const authError = requireAuth(auth);
  if (authError) return authError;
  return withStoreAsync(async (store) => ackPushDeliveryInStore(store, data, auth));
}

function ackPushDeliveryInStore(store, data, auth) {
  ensureTokenArrays(store);
  const notificationId = normalizeString(data.notificationId);
  if (!notificationId) {
    return { success: false, code: "PUSH_ACK_INVALID", error: "Некорректное уведомление" };
  }
  const now = new Date().toISOString();
  const eventType = normalizeString(data.eventType).toLowerCase() || "opened";
  const existing = store.pushDeliveryAcks.find(
    (ack) => ack.notificationId === notificationId && ack.userId === auth.user.id && ack.eventType === eventType,
  );
  const ack = existing || {
    id: newId("ack"),
    notificationId,
    userId: auth.user.id,
    eventType,
    createdAt: now,
  };
  ack.sentAtMs = asNumber(data.sentAtMs);
  ack.receivedAtMs = asNumber(data.receivedAtMs) || Date.now();
  ack.openedAtMs = asNumber(data.openedAtMs) || ack.receivedAtMs;
  ack.platform = normalizeString(data.platform);
  ack.appVersion = normalizeString(data.appVersion);
  ack.buildNumber = normalizeString(data.buildNumber);
  ack.route = normalizeString(data.route);
  ack.updatedAt = now;
  if (!existing) store.pushDeliveryAcks.push(ack);
  return { success: true, code: "PUSH_ACK_SAVED", ack };
}

module.exports = {
  addFcmTokenAsync,
  updateFcmTokenStateAsync,
  createPushNotificationAsync,
  adminQueueBroadcastAsync,
  adminListPushNotificationsAsync,
  flushQueuedPushDeliveriesAsync,
  flushQueuedPushDeliveriesInternalAsync,
  flushQueuedPushDeliveriesForStore,
  createPushNotificationInStore,
  queueOrderPushEventInStore,
  ackPushDeliveryAsync,
};
