const backendEntrypoints = Object.freeze([
  "server/src/call_router.js",
  "server/src/orders.js",
  "server/src/users.js",
  "server/src/admin.js",
  "server/src/session.js",
  "server/src/settings.js",
  "server/src/push.js",
  "server/src/maintenance.js",
]);

const backendAuthoritativeDomains = Object.freeze([
  "auth",
  "users",
  "orders",
  "payments",
  "withdrawals",
  "support",
  "settings",
  "media",
  "admin",
]);

const firebaseForbiddenFor = Object.freeze([
  "Auth",
  "Firestore",
  "Cloud Functions",
  "Storage",
  "SMS",
  "orders",
  "payments",
  "chats",
  "settings",
  "files",
  "admin data",
]);

async function getBackendArchitectureStatusAsync() {
  return {
    success: true,
    code: "BACKEND_ARCHITECTURE_STATUS",
    architecture: "backend-only",
    backendAuthoritative: true,
    firebaseAllowedOnlyFor: "FCM transport",
    firebaseForbiddenFor,
    backendEntrypoints,
    backendAuthoritativeDomains,
  };
}

module.exports = {
  backendAuthoritativeDomains,
  backendEntrypoints,
  firebaseForbiddenFor,
  getBackendArchitectureStatusAsync,
};
