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
  const projectId = normalizeString(process.env.FIREBASE_PROJECT_ID) || 'mtaxi-52990';
  const rawServiceAccount = normalizeString(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  const serviceAccount = rawServiceAccount ? JSON.parse(rawServiceAccount) : null;
  if (serviceAccount && projectId && serviceAccount.project_id !== projectId) {
    throw new Error('FCM_SERVICE_ACCOUNT_PROJECT_MISMATCH');
  }
  const { getApps, initializeApp, cert, applicationDefault } = require("firebase-admin/app");
  if (getApps().length > 0) {
    if (projectId && getApps()[0].options.projectId !== projectId) {
      throw new Error('FCM_INITIALIZED_PROJECT_MISMATCH');
    }
    firebaseAppInitialized = true;
    return;
  }
  if (rawServiceAccount) {
    initializeApp({
      credential: cert(serviceAccount),
      ...(projectId ? { projectId } : {}),
    });
  } else {
    initializeApp({
      credential: applicationDefault(),
      ...(projectId ? { projectId } : {}),
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
