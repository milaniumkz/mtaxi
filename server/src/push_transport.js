const { normalizeString } = require("./utils/values");

let firebaseAppInitialized = false;

function fcmEnabled() {
  return normalizeString(process.env.MTAXI_FCM_ENABLED).toLowerCase() === "true";
}

function stringifyDataPayload(payload = {}) {
  const result = {};
  for (const [key, value] of Object.entries(payload || {})) {
    if (value == null) continue;
    result[key] = typeof value === "string" ? value : JSON.stringify(value);
  }
  return result;
}

function ensureFirebaseApp() {
  if (firebaseAppInitialized) return;
  const { getApps, initializeApp, cert, applicationDefault } = require("firebase-admin/app");
  if (getApps().length > 0) {
    firebaseAppInitialized = true;
    return;
  }
  const rawServiceAccount = normalizeString(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  if (rawServiceAccount) {
    initializeApp({
      credential: cert(JSON.parse(rawServiceAccount)),
    });
  } else {
    initializeApp({
      credential: applicationDefault(),
    });
  }
  firebaseAppInitialized = true;
}

async function sendPushBatch({
  tokens,
  notification,
}) {
  const cleanTokens = [...new Set((tokens || []).map(normalizeString).filter(Boolean))];
  if (cleanTokens.length === 0) {
    return { mode: "none", responses: [] };
  }
  if (!fcmEnabled()) {
    return {
      mode: "simulated-local",
      responses: cleanTokens.map((token) => ({ token, success: true })),
    };
  }

  ensureFirebaseApp();
  const { getMessaging } = require("firebase-admin/messaging");
  const response = await getMessaging().sendEachForMulticast({
    tokens: cleanTokens,
    notification: {
      title: normalizeString(notification.title || "MTaxi"),
      body: normalizeString(notification.body),
    },
    data: stringifyDataPayload(notification.dataPayload || notification.data || {}),
    android: {
      priority: "high",
      notification: {
        sound: "default",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  });

  return {
    mode: "firebase-fcm",
    responses: response.responses.map((item, index) => ({
      token: cleanTokens[index],
      success: item.success,
      messageId: item.messageId || "",
      error: item.error?.message || "",
      errorCode: item.error?.code || "",
    })),
  };
}

module.exports = {
  fcmEnabled,
  sendPushBatch,
};
