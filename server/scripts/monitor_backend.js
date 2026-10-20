require("dotenv").config();

const {
  assertBackendOnlyArchitecture,
  callBackend,
  expectJson,
  isLocalBaseUrl,
} = require("./smoke_backend");

function normalize(value) {
  return value == null ? "" : String(value).trim();
}

function fail(message) {
  throw new Error(message);
}

function isTruthy(value) {
  const raw = normalize(value).toLowerCase();
  return raw === "true" || raw === "1" || raw === "yes";
}

function isInsecureBaseUrl(value) {
  try {
    return new URL(value).protocol === "http:";
  } catch (_) {
    return false;
  }
}

async function loginAdmin(baseUrl) {
  const phone = normalize(process.env.MTAXI_MONITOR_ADMIN_PHONE);
  const password = normalize(process.env.MTAXI_MONITOR_ADMIN_PASSWORD);
  if (!phone && !password) {
    return null;
  }
  if (!phone || !password) {
    fail("monitor admin check requires both MTAXI_MONITOR_ADMIN_PHONE and MTAXI_MONITOR_ADMIN_PASSWORD");
  }
  const login = await callBackend(baseUrl, "passwordLogin", { phone, password });
  const token = normalize(login.token);
  if (!token) {
    fail("monitor admin login did not return token");
  }
  await callBackend(baseUrl, "getSessionBootstrap", {}, token);
  return { token, user: login.user || null };
}

function assertExpectedStore(expectedStore, actualStore, ready, health) {
  if (expectedStore && actualStore !== expectedStore) {
    fail(`expected store ${expectedStore}, got ${actualStore || "unknown"}`);
  }
  if (expectedStore === "postgres") {
    const schemaVersion = normalize(
      ready.store?.schemaVersion || health.store?.schemaVersion,
    );
    if (!schemaVersion) {
      fail("postgres monitor requires applied schemaVersion");
    }
  }
}

async function main() {
  const baseUrl =
    normalize(process.env.MTAXI_MONITOR_BASE_URL) || "http://127.0.0.1:8080";
  const expectedStore = normalize(process.env.MTAXI_MONITOR_EXPECT_STORE).toLowerCase();
  if (
    expectedStore &&
    expectedStore !== "json" &&
    isInsecureBaseUrl(baseUrl) &&
    !isLocalBaseUrl(baseUrl) &&
    !isTruthy(process.env.MTAXI_MONITOR_ALLOW_INSECURE_BASE_URL)
  ) {
    fail("production monitor base URL must be HTTPS");
  }

  await expectJson(`${baseUrl}/livez`);
  const ready = await expectJson(`${baseUrl}/readyz`);
  const health = await callBackend(baseUrl, "getStoreHealth");
  await callBackend(baseUrl, "getRuntimeSettings");
  const architecture = await callBackend(baseUrl, "getBackendArchitectureStatus");
  assertBackendOnlyArchitecture(architecture);

  const actualStore = normalize(ready.store?.type || health.store?.type).toLowerCase();
  assertExpectedStore(expectedStore, actualStore, ready, health);

  const adminSession = await loginAdmin(baseUrl);
  if (adminSession) {
    await callBackend(baseUrl, "adminListUsers", { limit: 1 }, adminSession.token);
    await callBackend(baseUrl, "getMoneyStats", {}, adminSession.token);
    await callBackend(baseUrl, "adminListPushNotifications", { limit: 1 }, adminSession.token);
  }

  console.log(`MTaxi monitor ok: ${baseUrl} (${actualStore || "store"})`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`MTaxi monitor failed: ${error?.message || String(error)}`);
    process.exit(1);
  });
}

module.exports = {
  assertExpectedStore,
  loginAdmin,
  main,
};
