require("dotenv").config();

const fs = require("fs");
const os = require("os");
const path = require("path");
const { Client } = require("pg");

function normalize(value) {
  return value == null ? "" : String(value).trim();
}

function isPlaceholder(value) {
  const normalized = normalize(value).toLowerCase();
  return !normalized ||
    normalized.includes("replace-with") ||
    normalized.includes("change-this") ||
    normalized.includes("mtaxi_change_me") ||
    normalized === "https://api.example.kz" ||
    normalized.includes("mtaxi:password@127.0.0.1") ||
    normalized.includes("password@127.0.0.1");
}

function addCheck(checks, ok, name, message) {
  checks.push({ ok: ok === true, name, message });
}

function optionalNumber(value, fallback) {
  const raw = normalize(value);
  if (!raw) {
    return fallback;
  }
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : NaN;
}

function optionalNonNegativeInteger(value, fallback) {
  const raw = normalize(value);
  if (!raw) {
    return fallback;
  }
  return /^\d+$/.test(raw) ? Number(raw) : NaN;
}

function parseFirebaseServiceAccount(raw) {
  const text = normalize(raw);
  if (!text) {
    return null;
  }
  try {
    const parsed = JSON.parse(text);
    const projectId = normalize(parsed.project_id);
    const clientEmail = normalize(parsed.client_email);
    const privateKey = normalize(parsed.private_key);
    if (
      projectId &&
      !isPlaceholder(projectId) &&
      /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(clientEmail) &&
      privateKey.includes("-----BEGIN PRIVATE KEY-----") &&
      privateKey.includes("-----END PRIVATE KEY-----")
    ) {
      return parsed;
    }
  } catch (_) {
    return null;
  }
  return null;
}

function isLocalSmsProvider(env) {
  const provider = normalize(env.MTAXI_SMS_PROVIDER || "disabled").toLowerCase();
  return provider === "local" || provider === "console" || provider === "dev";
}

function isLocalPaymentProvider(env) {
  const provider = normalize(env.MTAXI_PAYMENT_PROVIDER || "local").toLowerCase();
  return provider === "local" || provider === "dev";
}

function isTruthy(value) {
  const raw = normalize(value).toLowerCase();
  return raw === "true" || raw === "1" || raw === "yes";
}

function validTrustProxy(value) {
  const raw = normalize(value).toLowerCase();
  if (!raw) {
    return true;
  }
  if (["true", "false", "yes", "no", "on", "off"].includes(raw)) {
    return true;
  }
  const numeric = Number(raw);
  if (Number.isFinite(numeric)) {
    return numeric >= 0;
  }
  const allowedNames = new Set(["loopback", "linklocal", "uniquelocal"]);
  return raw
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean)
    .every((item) =>
      allowedNames.has(item) ||
      /^[0-9a-f:.]+(\/\d{1,3})?$/i.test(item)
    );
}

function validJsonBodyLimit(value) {
  const raw = normalize(value || "25mb").toLowerCase();
  return /^[1-9]\d*(b|kb|mb|gb)$/.test(raw);
}

function validPort(value) {
  const raw = normalize(value || "8080");
  if (!/^\d+$/.test(raw)) {
    return false;
  }
  const port = Number(raw);
  return Number.isInteger(port) && port >= 1 && port <= 65535;
}

function validNodeVersion(value = process.versions.node) {
  const major = Number(normalize(value).split(".")[0]);
  return Number.isInteger(major) && major >= 20;
}

function validPhone(value) {
  const raw = normalize(value);
  if (isPlaceholder(raw) || !/^\+?[\d\s().-]+$/.test(raw)) {
    return false;
  }
  const digits = raw.replace(/\D/g, "");
  if (digits === "70000000000") {
    return false;
  }
  if (digits.length === 10) {
    return true;
  }
  return digits.length === 11 && (digits.startsWith("7") || digits.startsWith("8"));
}

function validPublicBaseUrl(value) {
  const raw = normalize(value);
  if (isPlaceholder(raw)) {
    return false;
  }
  try {
    const url = new URL(raw);
    return ["http:", "https:"].includes(url.protocol) && Boolean(url.hostname);
  } catch (_) {
    return false;
  }
}

function isLocalPublicBaseUrl(value) {
  const raw = normalize(value);
  if (!raw) {
    return false;
  }
  try {
    const url = new URL(raw);
    const host = url.hostname.toLowerCase().replace(/^\[/, "").replace(/\]$/, "");
    if (
      host === "localhost" ||
      host === "127.0.0.1" ||
      host === "0.0.0.0" ||
      host === "::1"
    ) {
      return true;
    }
    if (
      /^10\./.test(host) ||
      /^169\.254\./.test(host) ||
      /^192\.168\./.test(host) ||
      /^fc/i.test(host) ||
      /^fd/i.test(host) ||
      /^fe[89ab]/i.test(host)
    ) {
      return true;
    }
    const cgnat100 = host.match(/^100\.(\d{1,3})\./);
    if (cgnat100 && Number(cgnat100[1]) >= 64 && Number(cgnat100[1]) <= 127) {
      return true;
    }
    const private172 = host.match(/^172\.(\d{1,2})\./);
    return private172 ? Number(private172[1]) >= 16 && Number(private172[1]) <= 31 : false;
  } catch (_) {
    return false;
  }
}

function isInsecurePublicBaseUrl(value) {
  const raw = normalize(value);
  if (!raw) {
    return false;
  }
  try {
    return new URL(raw).protocol === "http:";
  } catch (_) {
    return false;
  }
}

function validCorsOrigins(value) {
  const origins = normalize(value)
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  if (origins.length === 0) {
    return false;
  }
  return origins.every((origin) => {
    if (origin === "*") {
      return false;
    }
    try {
      const url = new URL(origin);
      return ["http:", "https:"].includes(url.protocol) &&
        Boolean(url.hostname) &&
        url.pathname === "/" &&
        !url.search &&
        !url.hash;
    } catch (_) {
      return false;
    }
  });
}

function validPostgresUrl(value) {
  const raw = normalize(value);
  if (isPlaceholder(raw)) {
    return false;
  }
  try {
    const url = new URL(raw);
    return ["postgres:", "postgresql:"].includes(url.protocol) &&
      Boolean(url.hostname) &&
      Boolean(url.pathname.replace("/", ""));
  } catch (_) {
    return false;
  }
}

function validPaymentUrlTemplate(value) {
  const raw = normalize(value);
  if (isPlaceholder(raw) || !raw.includes("{{paymentId}}") || !raw.includes("{{amount}}")) {
    return false;
  }
  try {
    const probe = raw
      .replaceAll("{{paymentId}}", "payment_1")
      .replaceAll("{{ amount }}", "1000")
      .replaceAll("{{amount}}", "1000")
      .replaceAll("{{ phone }}", "77000000000")
      .replaceAll("{{phone}}", "77000000000")
      .replaceAll("{{ publicBaseUrl }}", "https://api.mtaxi.example")
      .replaceAll("{{publicBaseUrl}}", "https://api.mtaxi.example");
    const url = new URL(probe);
    return ["http:", "https:"].includes(url.protocol) && Boolean(url.hostname);
  } catch (_) {
    return false;
  }
}

function renderPaymentUrlTemplateProbe(value, publicBaseUrl = "https://api.mtaxi.example") {
  return normalize(value)
    .replaceAll("{{paymentId}}", "payment_1")
    .replaceAll("{{ amount }}", "1000")
    .replaceAll("{{amount}}", "1000")
    .replaceAll("{{ phone }}", "77000000000")
    .replaceAll("{{phone}}", "77000000000")
    .replaceAll("{{ publicBaseUrl }}", publicBaseUrl)
    .replaceAll("{{publicBaseUrl}}", publicBaseUrl);
}

function validProductionPaymentUrlTemplate(value, publicBaseUrl) {
  if (!validPaymentUrlTemplate(value)) {
    return false;
  }
  const probe = renderPaymentUrlTemplateProbe(value, publicBaseUrl);
  return !isInsecurePublicBaseUrl(probe) && !isLocalPublicBaseUrl(probe);
}

function validHttpUrl(value) {
  const raw = normalize(value);
  if (isPlaceholder(raw)) {
    return false;
  }
  try {
    const url = new URL(raw);
    return ["http:", "https:"].includes(url.protocol) && Boolean(url.hostname);
  } catch (_) {
    return false;
  }
}

function validProductionHttpUrl(value) {
  return validHttpUrl(value) &&
    !isInsecurePublicBaseUrl(value) &&
    !isLocalPublicBaseUrl(value);
}

function validSmsHttpMethod(value) {
  const method = normalize(value || "POST").toUpperCase();
  return ["POST", "PUT", "PATCH"].includes(method);
}

function validJsonObjectText(value, { allowEmpty = true } = {}) {
  const raw = normalize(value);
  if (!raw) {
    return allowEmpty;
  }
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed);
  } catch (_) {
    return false;
  }
}

function validSmsBodyTemplate(value) {
  const raw = normalize(value) ||
    '{"phone":"{{phone}}","message":"{{message}}","code":"{{code}}"}';
  if (!raw.includes("{{phone}}") || (!raw.includes("{{message}}") && !raw.includes("{{code}}"))) {
    return false;
  }
  const probe = raw
    .replaceAll("{{ phone }}", "77000000000")
    .replaceAll("{{phone}}", "77000000000")
    .replaceAll("{{ message }}", "MTaxi code: 1234")
    .replaceAll("{{message}}", "MTaxi code: 1234")
    .replaceAll("{{ code }}", "1234")
    .replaceAll("{{code}}", "1234");
  return validJsonObjectText(probe, { allowEmpty: false });
}

async function checkPostgres(databaseUrl) {
  const client = new Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    await client.query("SELECT 1");
  } finally {
    await client.end();
  }
}

async function checkWritableDir(dir) {
  await fs.promises.mkdir(dir, { recursive: true });
  const probe = path.join(dir, `.mtaxi-preflight-${Date.now()}-${Math.random().toString(16).slice(2)}`);
  await fs.promises.writeFile(probe, "ok");
  await fs.promises.unlink(probe);
}

async function fileExists(filePath) {
  const stat = await fs.promises.stat(filePath);
  return stat.isFile();
}

async function readFirebaseServiceAccountFile(filePath) {
  const text = await fs.promises.readFile(filePath, "utf8");
  return parseFirebaseServiceAccount(text);
}

function forbiddenFirebaseDataEnvKeys(env) {
  return Object.keys(env || {})
    .filter((key) =>
      /^FIREBASE_(AUTH|DATABASE|FIRESTORE|FUNCTIONS|SMS|STORAGE)_/i.test(key) ||
      /^FIRESTORE_/i.test(key) ||
      /^GCLOUD_FIRESTORE_/i.test(key) ||
      /^CLOUD_FIRESTORE_/i.test(key) ||
      [
        "FIREBASE_AUTH_EMULATOR_HOST",
        "FIREBASE_DATABASE_EMULATOR_HOST",
        "FIREBASE_DATABASE_URL",
        "FIREBASE_FUNCTIONS_EMULATOR_HOST",
        "FIREBASE_STORAGE_BUCKET",
        "FIREBASE_STORAGE_EMULATOR_HOST",
        "FIRESTORE_EMULATOR_HOST",
      ].includes(key.toUpperCase())
    )
    .filter((key) => normalize(env[key]))
    .sort();
}

async function runPreflight({
  env = process.env,
  checkDatabase = true,
  checkUploadDir = true,
} = {}) {
  const checks = [];
  const store = normalize(env.MTAXI_STORE || "json").toLowerCase();
  const isPostgres = store === "postgres" || store === "pg";
  const allowLocalPublicBaseUrl =
    isTruthy(env.MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL);
  const allowInsecurePublicBaseUrl =
    allowLocalPublicBaseUrl || isTruthy(env.MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL);

  addCheck(
    checks,
    validNodeVersion(),
    "NODE_VERSION",
    "Node.js runtime is 20 or newer",
  );
  addCheck(
    checks,
    validPort(env.PORT),
    "PORT",
    "HTTP port is a number from 1 to 65535",
  );
  addCheck(
    checks,
    validPublicBaseUrl(env.MTAXI_PUBLIC_BASE_URL) &&
      (allowLocalPublicBaseUrl || !isLocalPublicBaseUrl(env.MTAXI_PUBLIC_BASE_URL)) &&
      (allowInsecurePublicBaseUrl || !isInsecurePublicBaseUrl(env.MTAXI_PUBLIC_BASE_URL)),
    "MTAXI_PUBLIC_BASE_URL",
    allowLocalPublicBaseUrl
      ? "local public backend URL explicitly allowed for development"
      : "public backend URL is a real HTTPS URL, not localhost/LAN",
  );
  addCheck(
    checks,
    !isPlaceholder(env.MTAXI_TOKEN_SECRET) && normalize(env.MTAXI_TOKEN_SECRET).length >= 24,
    "MTAXI_TOKEN_SECRET",
    "JWT secret is set and long enough",
  );
  addCheck(
    checks,
    validCorsOrigins(env.MTAXI_CORS_ORIGINS),
    "MTAXI_CORS_ORIGINS",
    "allowed frontend origins are valid http/https origins",
  );
  addCheck(
    checks,
    validJsonBodyLimit(env.MTAXI_JSON_BODY_LIMIT),
    "MTAXI_JSON_BODY_LIMIT",
    "JSON body limit uses a positive b/kb/mb/gb value",
  );
  addCheck(
    checks,
    validTrustProxy(env.MTAXI_TRUST_PROXY),
    "MTAXI_TRUST_PROXY",
    "trust proxy setting is boolean, hop count, or proxy subnet list",
  );
  addCheck(checks, isPostgres, "MTAXI_STORE", "production store is PostgreSQL");
  addCheck(
    checks,
    isPostgres && validPostgresUrl(env.DATABASE_URL),
    "DATABASE_URL",
    "PostgreSQL connection string is valid",
  );
  addCheck(
    checks,
    !isPlaceholder(env.MTAXI_PAYMENT_CALLBACK_SECRET) &&
      normalize(env.MTAXI_PAYMENT_CALLBACK_SECRET).length >= 16,
    "MTAXI_PAYMENT_CALLBACK_SECRET",
    "payment callback secret configured",
  );

  const maintenanceIntervalSec =
    optionalNumber(env.MTAXI_MAINTENANCE_INTERVAL_SEC, 0);
  const pendingOrderTtlMin = optionalNumber(env.MTAXI_PENDING_ORDER_TTL_MIN, 15);
  const maintenanceOrderLimit =
    optionalNumber(env.MTAXI_MAINTENANCE_ORDER_LIMIT, 100);
  const maintenancePushLimit =
    optionalNumber(env.MTAXI_MAINTENANCE_PUSH_LIMIT, 100);
  const maxUploadBytes = optionalNumber(env.MTAXI_MAX_UPLOAD_BYTES, 10 * 1024 * 1024);
  const uploadCacheMaxAgeSec = optionalNumber(
    env.MTAXI_UPLOAD_CACHE_MAX_AGE_SEC,
    2592000,
  );
  const backupRetentionDays = optionalNonNegativeInteger(
    env.MTAXI_BACKUP_RETENTION_DAYS,
    30,
  );
  const smsCodeTtlSec = optionalNumber(env.MTAXI_SMS_CODE_TTL_SEC, 300);
  const smsResendCooldownSec =
    optionalNumber(env.MTAXI_SMS_RESEND_COOLDOWN_SEC, 30);
  const authRateLimitWindowSec =
    optionalNumber(env.MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC, 60);
  const authRateLimitMax = optionalNumber(env.MTAXI_AUTH_RATE_LIMIT_MAX, 20);
  const fcmEnabled = normalize(env.MTAXI_FCM_ENABLED).toLowerCase() === "true";
  const allowSimulatedPush = isTruthy(env.MTAXI_ALLOW_SIMULATED_PUSH);
  const isProduction = normalize(env.NODE_ENV).toLowerCase() === "production";
  const smsProvider = normalize(env.MTAXI_SMS_PROVIDER || "disabled").toLowerCase();
  const allowLocalSms = isTruthy(env.MTAXI_ALLOW_LOCAL_SMS);
  const smsDevReturnCode = isTruthy(env.MTAXI_SMS_DEV_RETURN_CODE);
  const paymentProvider = normalize(env.MTAXI_PAYMENT_PROVIDER || "local").toLowerCase();
  const allowLocalPayment = isTruthy(env.MTAXI_ALLOW_LOCAL_PAYMENT);
  const enableLegacyCreateToken = isTruthy(env.MTAXI_ENABLE_LEGACY_CREATE_TOKEN);
  const allowPaymentCallbackSecretInBody =
    isTruthy(env.MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY);
  const seedAdminOnStart =
    normalize(env.MTAXI_SEED_ADMIN_ON_START).toLowerCase() === "true";
  const serviceAccount = parseFirebaseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  const credentialsPath = normalize(env.GOOGLE_APPLICATION_CREDENTIALS);
  const forbiddenFirebaseKeys = forbiddenFirebaseDataEnvKeys(env);
  addCheck(
    checks,
    !isProduction || !allowLocalPublicBaseUrl,
    "MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL",
    allowLocalPublicBaseUrl
      ? "local public URL flag is disabled in production"
      : "local public URL flag is disabled",
  );
  addCheck(
    checks,
    !isProduction || !isTruthy(env.MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL),
    "MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL",
    isTruthy(env.MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL)
      ? "insecure public URL flag is disabled in production"
      : "insecure public URL flag is disabled",
  );
  addCheck(
    checks,
    !isProduction || !allowLocalSms,
    "MTAXI_ALLOW_LOCAL_SMS",
    allowLocalSms
      ? "local SMS flag is disabled in production"
      : "local SMS flag is disabled",
  );
  addCheck(
    checks,
    !isProduction || !allowLocalPayment,
    "MTAXI_ALLOW_LOCAL_PAYMENT",
    allowLocalPayment
      ? "local payment flag is disabled in production"
      : "local payment flag is disabled",
  );
  addCheck(
    checks,
    !isProduction || !enableLegacyCreateToken,
    "MTAXI_ENABLE_LEGACY_CREATE_TOKEN",
    enableLegacyCreateToken
      ? "legacy create-token endpoint is disabled in production"
      : "legacy create-token endpoint is disabled",
  );
  addCheck(
    checks,
    Number.isFinite(maintenanceIntervalSec) && maintenanceIntervalSec >= 0,
    "MTAXI_MAINTENANCE_INTERVAL_SEC",
    "maintenance interval is disabled or non-negative",
  );
  addCheck(
    checks,
    Number.isFinite(pendingOrderTtlMin) && pendingOrderTtlMin > 0,
    "MTAXI_PENDING_ORDER_TTL_MIN",
    "pending order TTL is positive",
  );
  addCheck(
    checks,
    Number.isFinite(maintenanceOrderLimit) && maintenanceOrderLimit > 0,
    "MTAXI_MAINTENANCE_ORDER_LIMIT",
    "maintenance order limit is positive",
  );
  addCheck(
    checks,
    !allowPaymentCallbackSecretInBody,
    "MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY",
    "payment callback body secret is disabled for production",
  );
  addCheck(
    checks,
    ["local", "dev", "redirect", "kaspi_manual"].includes(paymentProvider),
    "MTAXI_PAYMENT_PROVIDER",
    "payment provider is known",
  );
  addCheck(
    checks,
    !isLocalPaymentProvider(env) || allowLocalPayment,
    "MTAXI_PAYMENT_PROVIDER",
    allowLocalPayment
      ? "local payment provider explicitly allowed for development"
      : "production payment provider is configured",
  );
  addCheck(
    checks,
    paymentProvider !== "redirect" ||
      validProductionPaymentUrlTemplate(
        env.MTAXI_PAYMENT_URL_TEMPLATE,
        env.MTAXI_PUBLIC_BASE_URL,
      ),
    "MTAXI_PAYMENT_URL_TEMPLATE",
    paymentProvider === "redirect"
      ? "payment URL template is external HTTPS and includes paymentId/amount"
      : "redirect payment provider disabled; URL template not required",
  );
  addCheck(
    checks,
    Number.isFinite(maintenancePushLimit) && maintenancePushLimit > 0,
    "MTAXI_MAINTENANCE_PUSH_LIMIT",
    "maintenance push limit is positive",
  );
  addCheck(
    checks,
    Number.isFinite(maxUploadBytes) && maxUploadBytes > 0,
    "MTAXI_MAX_UPLOAD_BYTES",
    "max upload bytes is positive",
  );
  addCheck(
    checks,
    Number.isFinite(uploadCacheMaxAgeSec) && uploadCacheMaxAgeSec >= 0,
    "MTAXI_UPLOAD_CACHE_MAX_AGE_SEC",
    "upload cache TTL is disabled or non-negative",
  );
  addCheck(
    checks,
    Number.isFinite(backupRetentionDays),
    "MTAXI_BACKUP_RETENTION_DAYS",
    "backup retention days is a non-negative integer",
  );
  addCheck(
    checks,
    Number.isFinite(smsCodeTtlSec) && smsCodeTtlSec > 0,
    "MTAXI_SMS_CODE_TTL_SEC",
    "SMS code TTL is positive",
  );
  addCheck(
    checks,
    Number.isFinite(smsResendCooldownSec) && smsResendCooldownSec >= 0,
    "MTAXI_SMS_RESEND_COOLDOWN_SEC",
    "SMS resend cooldown is disabled or non-negative",
  );
  addCheck(
    checks,
    Number.isFinite(authRateLimitWindowSec) && authRateLimitWindowSec > 0,
    "MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC",
    "auth rate limit window is positive",
  );
  addCheck(
    checks,
    Number.isFinite(authRateLimitMax) && authRateLimitMax > 0,
    "MTAXI_AUTH_RATE_LIMIT_MAX",
    "auth rate limit max is positive",
  );
  addCheck(
    checks,
    ["disabled", "local", "console", "dev", "http"].includes(smsProvider),
    "MTAXI_SMS_PROVIDER",
    "SMS provider is known",
  );
  addCheck(
    checks,
    !isLocalSmsProvider(env) || allowLocalSms,
    "MTAXI_SMS_PROVIDER",
    allowLocalSms
      ? "local SMS provider explicitly allowed for development"
      : "production SMS provider is configured",
  );
  addCheck(
    checks,
    !smsDevReturnCode || allowLocalSms,
    "MTAXI_SMS_DEV_RETURN_CODE",
    smsDevReturnCode
      ? "SMS code may be returned only in local development"
      : "SMS code is not returned to clients",
  );
  addCheck(
    checks,
    smsProvider !== "http" || validProductionHttpUrl(env.MTAXI_SMS_HTTP_URL),
    "MTAXI_SMS_HTTP_URL",
    smsProvider === "http"
      ? "HTTP SMS provider URL is external HTTPS"
      : "HTTP SMS provider disabled; URL not required",
  );
  addCheck(
    checks,
    smsProvider !== "http" || validSmsHttpMethod(env.MTAXI_SMS_HTTP_METHOD),
    "MTAXI_SMS_HTTP_METHOD",
    smsProvider === "http"
      ? "HTTP SMS method is POST, PUT or PATCH"
      : "HTTP SMS provider disabled; method not required",
  );
  addCheck(
    checks,
    smsProvider !== "http" || validJsonObjectText(env.MTAXI_SMS_HTTP_HEADERS),
    "MTAXI_SMS_HTTP_HEADERS",
    smsProvider === "http"
      ? "HTTP SMS headers are empty or JSON object"
      : "HTTP SMS provider disabled; headers not required",
  );
  addCheck(
    checks,
    smsProvider !== "http" || validSmsBodyTemplate(env.MTAXI_SMS_HTTP_BODY_TEMPLATE),
    "MTAXI_SMS_HTTP_BODY_TEMPLATE",
    smsProvider === "http"
      ? "HTTP SMS body template is JSON and includes phone/message or code"
      : "HTTP SMS provider disabled; body template not required",
  );
  addCheck(
    checks,
    fcmEnabled || allowSimulatedPush,
    "MTAXI_FCM_ENABLED",
    allowSimulatedPush
      ? "simulated push explicitly allowed for development"
      : "production FCM push transport is enabled",
  );
  addCheck(
    checks,
    !allowSimulatedPush || !isProduction,
    "MTAXI_ALLOW_SIMULATED_PUSH",
    allowSimulatedPush
      ? "simulated push is allowed only outside NODE_ENV=production"
      : "simulated push is disabled",
  );
  addCheck(
    checks,
    !isProduction || forbiddenFirebaseKeys.length === 0,
    "Firebase data env",
    forbiddenFirebaseKeys.length === 0
      ? "Firebase is reserved for FCM push transport only"
      : `remove Firebase data/auth/storage/functions env: ${forbiddenFirebaseKeys.join(", ")}`,
  );
  addCheck(
    checks,
    !fcmEnabled || Boolean(serviceAccount || credentialsPath),
    "FCM credentials",
    fcmEnabled
      ? "Firebase Admin credentials configured for FCM push"
      : "FCM transport disabled; Firebase credentials not required",
  );
  if (fcmEnabled && credentialsPath && !serviceAccount) {
    try {
      const credentialsFileValid =
        (await fileExists(credentialsPath)) &&
        Boolean(await readFirebaseServiceAccountFile(credentialsPath));
      addCheck(
        checks,
        credentialsFileValid,
        "GOOGLE_APPLICATION_CREDENTIALS",
        "Firebase Admin credentials file exists and contains a valid service account JSON",
      );
      const expectedProject = normalize(env.FIREBASE_PROJECT_ID);
      if (credentialsFileValid && expectedProject) {
        const account = await readFirebaseServiceAccountFile(credentialsPath);
        addCheck(checks, account.project_id === expectedProject,
          'FIREBASE_PROJECT_ID', 'FCM credentials belong to the configured Firebase project');
      }
    } catch (error) {
      addCheck(
        checks,
        false,
        "GOOGLE_APPLICATION_CREDENTIALS",
        error?.message || "Firebase Admin credentials file is not readable",
      );
    }
  }
  if (fcmEnabled && serviceAccount && normalize(env.FIREBASE_PROJECT_ID)) {
    addCheck(checks, serviceAccount.project_id === normalize(env.FIREBASE_PROJECT_ID),
      'FIREBASE_PROJECT_ID', 'FCM credentials belong to the configured Firebase project');
  }
  addCheck(
    checks,
    !seedAdminOnStart || validPhone(env.MTAXI_ADMIN_PHONE),
    "MTAXI_ADMIN_PHONE",
    seedAdminOnStart
      ? "first admin phone has valid format"
      : "admin auto seed disabled; phone not required",
  );
  addCheck(
    checks,
    !seedAdminOnStart ||
      (!isPlaceholder(env.MTAXI_ADMIN_PASSWORD) &&
        normalize(env.MTAXI_ADMIN_PASSWORD).length >= 6),
    "MTAXI_ADMIN_PASSWORD",
    seedAdminOnStart
      ? "first admin password configured"
      : "admin auto seed disabled; password not required",
  );
  addCheck(
    checks,
    !seedAdminOnStart || Boolean(normalize(env.MTAXI_ADMIN_NAME)),
    "MTAXI_ADMIN_NAME",
    seedAdminOnStart
      ? "first admin name configured"
      : "admin auto seed disabled; name not required",
  );

  const uploadDir = normalize(env.MTAXI_UPLOAD_DIR) ||
    path.join(os.tmpdir(), "mtaxi-uploads");
  if (checkUploadDir) {
    try {
      await checkWritableDir(uploadDir);
      addCheck(checks, true, "MTAXI_UPLOAD_DIR", `upload dir writable: ${uploadDir}`);
    } catch (error) {
      addCheck(checks, false, "MTAXI_UPLOAD_DIR", error?.message || "upload dir is not writable");
    }
  } else {
    addCheck(checks, true, "MTAXI_UPLOAD_DIR", `upload dir configured: ${uploadDir}`);
  }

  if (checkDatabase && isPostgres && !isPlaceholder(env.DATABASE_URL)) {
    try {
      await checkPostgres(env.DATABASE_URL);
      addCheck(checks, true, "PostgreSQL health", "database connection ok");
    } catch (error) {
      addCheck(checks, false, "PostgreSQL health", error?.message || "database connection failed");
    }
  }

  return {
    ok: checks.every((check) => check.ok),
    checks,
  };
}

async function main() {
  const result = await runPreflight();
  for (const check of result.checks) {
    const mark = check.ok ? "OK" : "FAIL";
    console.log(`${mark} ${check.name}: ${check.message}`);
  }
  if (!result.ok) {
    process.exitCode = 1;
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error?.message || error);
    process.exit(1);
  });
}

module.exports = {
  isPlaceholder,
  isInsecurePublicBaseUrl,
  isLocalPublicBaseUrl,
  runPreflight,
  validCorsOrigins,
  validHttpUrl,
  validJsonBodyLimit,
  validNodeVersion,
  validPaymentUrlTemplate,
  validPostgresUrl,
  validProductionHttpUrl,
  validProductionPaymentUrlTemplate,
  validPublicBaseUrl,
  validPhone,
  validSmsBodyTemplate,
  validSmsHttpMethod,
  validPort,
  forbiddenFirebaseDataEnvKeys,
  parseFirebaseServiceAccount,
  readFirebaseServiceAccountFile,
};
