require("dotenv").config();

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

function hostHasSecondOctetInRange(host, firstOctet, min, max) {
  const parts = host.split(".");
  if (parts.length < 2 || parts[0] !== firstOctet) {
    return false;
  }
  const second = Number(parts[1]);
  return Number.isInteger(second) && second >= min && second <= max;
}

function isLocalBaseUrl(value) {
  try {
    const host = new URL(value).hostname.toLowerCase().replace(/^\[/, "").replace(/\]$/, "");
    return host === "localhost" ||
      host === "127.0.0.1" ||
      host === "0.0.0.0" ||
      host === "::1" ||
      host.startsWith("10.") ||
      host.startsWith("169.254.") ||
      host.startsWith("192.168.") ||
      host.startsWith("fc") ||
      host.startsWith("fd") ||
      host.startsWith("fe8") ||
      host.startsWith("fe9") ||
      host.startsWith("fea") ||
      host.startsWith("feb") ||
      hostHasSecondOctetInRange(host, "100", 64, 127) ||
      hostHasSecondOctetInRange(host, "172", 16, 31);
  } catch (_) {
    return false;
  }
}

function isInsecureBaseUrl(value) {
  try {
    return new URL(value).protocol === "http:";
  } catch (_) {
    return false;
  }
}

function assertBackendOnlyArchitecture(architecture) {
  if (
    architecture.architecture !== "backend-only" ||
    architecture.firebaseAllowedOnlyFor !== "FCM transport"
  ) {
    fail("backend architecture status must be backend-only with Firebase only as FCM transport");
  }
  const forbidden = Array.isArray(architecture.firebaseForbiddenFor)
    ? architecture.firebaseForbiddenFor
    : [];
  for (const domain of ["Auth", "Firestore", "Cloud Functions", "Storage", "SMS"]) {
    if (!forbidden.includes(domain)) {
      fail(`backend architecture status must forbid Firebase ${domain}`);
    }
  }
}

async function expectJson(url, options = {}) {
  const response = await fetch(url, options);
  let body = null;
  try {
    body = await response.json();
  } catch (_) {
    fail(`${url} did not return JSON`);
  }
  if (!response.ok || (body?.ok !== true && body?.success !== true)) {
    fail(`${url} returned status ${response.status}: ${JSON.stringify(body)}`);
  }
  return body;
}

async function callBackend(baseUrl, name, data = {}, token = "") {
  const headers = { "Content-Type": "application/json" };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  return expectJson(`${baseUrl}/call/${name}`, {
    method: "POST",
    headers,
    body: JSON.stringify(data),
  });
}

async function loginForSmoke(baseUrl, label, phoneEnv, passwordEnv) {
  const phone = normalize(process.env[phoneEnv]);
  const password = normalize(process.env[passwordEnv]);
  if (!phone && !password) {
    return null;
  }
  if (!phone || !password) {
    fail(`${label} smoke requires both ${phoneEnv} and ${passwordEnv}`);
  }
  const login = await callBackend(baseUrl, "passwordLogin", { phone, password });
  const token = normalize(login.token);
  if (!token) {
    fail(`${label} smoke login did not return token`);
  }
  await callBackend(baseUrl, "getSessionBootstrap", {}, token);
  return { token, user: login.user || null };
}

async function main() {
  const baseUrl =
    normalize(process.env.MTAXI_SMOKE_BASE_URL) || "http://127.0.0.1:8080";
  const expectedStore = normalize(process.env.MTAXI_SMOKE_EXPECT_STORE).toLowerCase();
  if (
    expectedStore &&
    expectedStore !== "json" &&
    isInsecureBaseUrl(baseUrl) &&
    !isLocalBaseUrl(baseUrl) &&
    !isTruthy(process.env.MTAXI_SMOKE_ALLOW_INSECURE_BASE_URL)
  ) {
    fail("production smoke base URL must be HTTPS");
  }
  await expectJson(`${baseUrl}/livez`);
  const ready = await expectJson(`${baseUrl}/readyz`);
  const health = await expectJson(`${baseUrl}/call/getStoreHealth`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  });
  const actualStore = normalize(ready.store?.type || health.store?.type).toLowerCase();
  if (expectedStore && actualStore !== expectedStore) {
    fail(`expected store ${expectedStore}, got ${actualStore || "unknown"}`);
  }
  if (expectedStore === "postgres") {
    const schemaVersion = normalize(
      ready.store?.schemaVersion || health.store?.schemaVersion,
    );
    if (!schemaVersion) {
      fail("postgres smoke requires applied schemaVersion");
    }
  }
  await callBackend(baseUrl, "getRuntimeSettings");
  const architecture = await callBackend(baseUrl, "getBackendArchitectureStatus");
  assertBackendOnlyArchitecture(architecture);
  const adminSession = await loginForSmoke(
    baseUrl,
    "admin",
    "MTAXI_SMOKE_ADMIN_PHONE",
    "MTAXI_SMOKE_ADMIN_PASSWORD",
  );
  if (adminSession) {
    await callBackend(baseUrl, "adminListUsers", { limit: 1 }, adminSession.token);
    await callBackend(baseUrl, "getMoneyStats", {}, adminSession.token);
  }
  const passengerSession = await loginForSmoke(
    baseUrl,
    "passenger",
    "MTAXI_SMOKE_PASSENGER_PHONE",
    "MTAXI_SMOKE_PASSENGER_PASSWORD",
  );
  const driverSession = await loginForSmoke(
    baseUrl,
    "driver",
    "MTAXI_SMOKE_DRIVER_PHONE",
    "MTAXI_SMOKE_DRIVER_PASSWORD",
  );
  const readSession = passengerSession || driverSession || adminSession;
  if (readSession) {
    await callBackend(baseUrl, "listCityTariffs", { limit: 1 }, readSession.token);
    await callBackend(baseUrl, "listIntercityRoutes", { limit: 1 }, readSession.token);
  }
  console.log(
    `MTaxi smoke passed: ${baseUrl} (${actualStore || "store"})`,
  );
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`MTaxi smoke failed: ${error?.message || String(error)}`);
    process.exit(1);
  });
}

module.exports = {
  callBackend,
  expectJson,
  assertBackendOnlyArchitecture,
  isLocalBaseUrl,
  loginForSmoke,
  main,
};
