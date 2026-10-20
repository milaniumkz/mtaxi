const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { once } = require("events");
const { spawnSync } = require("child_process");

process.env.MTAXI_DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-backend-test-"));
process.env.MTAXI_UPLOAD_DIR = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-upload-test-"));
process.env.MTAXI_ACCESS_LOGS = "false";

const {
  passwordLogin,
  lookupUserByPhone,
  requestSmsCode,
  verifySmsCode,
  hashSmsCode,
  tokenSecret,
  createSmsSession,
  verifyBearerToken,
} = require("../src/auth");
const {
  withStore,
  readStore,
  writeStore,
  readStoreAsync,
  withStoreAsync,
  storeHealth,
} = require("../src/store");
const { handlerNames } = require("../src/call_router");
const { buildContract } = require("../scripts/export_api_contract");
const { buildContract: buildEnvContract } = require("../scripts/export_env_contract");
const { clearRateLimits } = require("../src/rate_limit");
const {
  accessLogEnabledForEnv,
  accessLogPath,
  accessLogMiddleware,
  corsOriginForEnv,
  jsonBodyLimitForEnv,
  requestIdMiddleware,
  securityHeadersMiddleware,
  trustProxyForEnv,
  uploadStaticOptionsForEnv,
} = require("../src/http_config");
const {
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
} = require("../scripts/preflight");
const {
  validateProductionDeploy,
} = require("../scripts/validate_production_deploy");
const {
  assertMigrationCounts,
  countPostgresRecords,
  countStoreRecords,
  formatMigrationReport,
} = require("../scripts/migrate_json_to_postgres");
const { seedAdmin } = require("../scripts/seed_admin");
const { sendSmsCode } = require("../src/sms_provider");
const { getSessionBootstrapAsync } = require("../src/session");
const {
  getRuntimeSettingsAsync,
  updateRuntimeSettingsAsync,
} = require("../src/settings");
const {
  getBackendArchitectureStatusAsync,
} = require("../src/architecture_status");
const {
  submitPassengerRegistrationAsync,
  submitDriverRegistrationAsync,
  updateUserPreferencesAsync,
  setPasswordAsync,
  deleteCurrentAccountDeepAsync,
} = require("../src/users");
const {
  adminListUsersAsync,
  adminListAuditLogsAsync,
  adminUpdateUserDocumentAsync,
  adminSavePolitikaAsync,
  approveVehiclePhotoDeletionAsync,
  rejectVehiclePhotoDeletionAsync,
  approveDriverAsync,
  blockDriverAsync,
  unblockDriverAsync,
  adminTopUpDriverBalanceAsync,
  adminManageOrderAsync,
  adminCreateDriverAsync,
  adminCreatePassengerAsync,
  adminUpdateDriverCityAsync,
  adminUpdateDriverOrderDelayAsync,
  listCityTariffsAsync,
  adminListCityTariffsAsync,
  adminUpsertCityTariffAsync,
  listIntercityRoutesAsync,
  adminListIntercityRoutesAsync,
  adminUpsertIntercityRouteAsync,
  getContentDocumentAsync,
  adminUpdateContentDocumentAsync,
  adminListGenericCollectionAsync,
  adminUpsertGenericDocumentAsync,
  adminDeleteGenericDocumentAsync,
} = require("../src/admin");
const { isPasswordHash, verifyPassword } = require("../src/passwords");
const postgresStore = require("../src/store/postgres_store");
const {
  createDriverTopUpPaymentAsync,
  getDriverTopUpPaymentStatusAsync,
  confirmDriverTopUpPaymentAsync,
  failDriverTopUpPaymentAsync,
  handleDriverTopUpPaymentCallbackAsync,
  createDriverWithdrawalAsync,
  adminListWithdrawalsAsync,
  adminResolveWithdrawalAsync,
  adminListPaymentsAsync,
  getMoneyStatsAsync,
} = require("../src/payments");
const {
  ensureSupportChatAsync,
  getMySupportChatAsync,
  sendSupportChatMessageAsync,
  markSupportChatReadAsync,
  listSupportChatsAsync,
  getSupportChatMessagesAsync,
  adminSendSupportChatMessageAsync,
  adminDeleteSupportChatAsync,
  adminClearSupportChatsAsync,
} = require("../src/support");
const {
  addFcmTokenAsync,
  updateFcmTokenStateAsync,
  createPushNotificationAsync,
  adminQueueBroadcastAsync,
  adminListPushNotificationsAsync,
  flushQueuedPushDeliveriesAsync,
  ackPushDeliveryAsync,
} = require("../src/push");
const {
  calculateOrderQuoteFromData,
  getOrderQuoteAsync,
  createPassengerOrderAsync,
  getOrderDetailsAsync,
  listAvailableDriverOrdersAsync,
  listMyOrdersAsync,
  adminListOrdersAsync,
  expirePendingOrderIfNeededAsync,
  acceptOrderAsync,
  cancelPassengerOrderAsync,
  advanceDriverOrderStatusAsync,
  adminCreateOrderAsync,
} = require("../src/orders");
const { publicBaseUrl, uploadFileAsync } = require("../src/media");
const {
  forwardGeocodeLookup,
  reverseGeocodeLookup,
  placesAutocomplete,
  placeDetails,
  suggestAddressesLookup,
  routeLookup,
} = require("../src/geocoding");
const { dispatchCall } = require("../src/call_router");
const {
  runMaintenanceTasksAsync,
  runMaintenanceTasksInternalAsync,
} = require("../src/maintenance");
const {
  maintenanceIntervalMsForEnv,
  startMaintenanceScheduler,
} = require("../src/maintenance_scheduler");

function freshSeed() {
  return {
    users: [
      {
        id: "u_driver_7086362153",
        phone: "+77086362153",
        password: "123456",
        displayName: "Данил Сельстьянов",
        city: "Белоусовка",
        roleState: "DRIVER_ONLINE",
        isDriver: true,
        statusDriver: "approved",
        balance: 10000,
      },
      {
        id: "u_passenger_7052597368",
        phone: "+77052597368",
        password: "123456",
        displayName: "Дмитрий Штрахов",
        city: "Белоусовка",
        roleState: "PASSENGER",
        isDriver: false,
        balance: 0,
      },
      {
        id: "u_admin_70000000000",
        phone: "+70000000000",
        password: "A7059012671!",
        displayName: "Администратор",
        city: "Белоусовка",
        roleState: "ADMIN",
        role: "admin",
        isDriver: false,
        balance: 0,
      },
    ],
    orders: [],
    payments: [],
    ledger: [],
    chats: [],
    chatMessages: [],
    fcmTokens: [],
    notifications: [],
    notificationDeliveries: [],
    pushDeliveryAcks: [],
    auditLogs: [],
    settings: {
      taxiFallbackPrice: 800,
      deliveryFallbackPrice: 1200,
      deliveryExtra: 400,
      nightMultiplier: 1.5,
      orderCommissionPercent: 10,
      pendingOrderLifetimeMin: 15,
    },
    cityPrices: [
      {
        title: "Белоусовка",
        priceDay: 1000,
        priceNight: 1500,
        deliveryPrice: 1500,
      },
    ],
    intercityTariff: {
      basePrice: 500,
      pricePerKm: 130,
      minPrice: 3000,
    },
    intercityRoutes: [
      {
        id: "route_belousovka_ust_kamenogorsk",
        ot: "Белоусовка",
        kuda: "Усть-Каменогорск",
        tarif: 5000,
        com: 10,
      },
    ],
    content: {
      politika: { text: "Политика" },
      about: { title: "Поддержка" },
      supportContacts: {
        whatsAppPhone: "+77000000000",
        callPhone: "+77000000001",
      },
      tariffsContent: {
        driverTariffs: "Тарифы водителя",
        passengerTariffs: "Тарифы пассажира",
      },
    },
  };
}

function bearerReq(token) {
  return {
    get: (name) => String(name).toLowerCase() === "authorization" ? `Bearer ${token}` : "",
  };
}

test.beforeEach(() => {
  writeStore(freshSeed());
});

test("passwordLogin returns backend token", async () => {
  const result = await passwordLogin({
    phone: "7052597368",
    password: "123456",
  });
  assert.equal(result.success, true);
  assert.match(result.token, /^[^.]+\.[^.]+\.[^.]+$/);
  assert.equal(result.user.password, undefined);
  assert.equal(result.user.hasPassword, true);
});

test("postgres store refuses old sync contract and requires DATABASE_URL for async", async () => {
  assert.throws(
    () => postgresStore.readStore(),
    /synchronous store contract/,
  );
  assert.rejects(
    () => postgresStore.withPgClient(async () => null),
    /DATABASE_URL is required/,
  );
  await assert.rejects(
    () => postgresStore.withStoreAsync(async () => null),
    /DATABASE_URL/,
  );
  assert.match(postgresStore.newId("test"), /^test_/);
});

test("runtime backend modules do not import the old sync store contract", () => {
  const srcDir = path.join(__dirname, "../src");
  const allowed = new Set([
    "store/index.js",
    "store/json_store.js",
    "store/postgres_store.js",
  ]);
  const offenders = [];

  function scan(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        scan(fullPath);
        continue;
      }
      if (!entry.name.endsWith(".js")) continue;
      const relative = path.relative(srcDir, fullPath);
      if (allowed.has(relative)) continue;
      const source = fs.readFileSync(fullPath, "utf8");
      if (/\b(readStore|writeStore|withStore)\b/.test(source)) {
        offenders.push(relative);
      }
    }
  }

  scan(srcDir);
  assert.deepEqual(offenders, []);
});

test("Firebase Admin is used only as FCM push transport", () => {
  const pkg = JSON.parse(
    fs.readFileSync(path.join(__dirname, "../package.json"), "utf8"),
  );
  const directDependencies = {
    ...(pkg.dependencies || {}),
    ...(pkg.devDependencies || {}),
  };
  const directFirebaseDependencies = Object.keys(directDependencies).filter(
    (name) =>
      name === "firebase" ||
      name.startsWith("@firebase/") ||
      name.startsWith("firebase-"),
  );
  assert.deepEqual(directFirebaseDependencies, ["firebase-admin"]);

  const srcDir = path.join(__dirname, "../src");
  const offenders = [];

  function scan(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        scan(fullPath);
        continue;
      }
      if (!entry.name.endsWith(".js")) continue;
      const relative = path.relative(srcDir, fullPath);
      const source = fs.readFileSync(fullPath, "utf8");
      if (source.includes("firebase-admin") && relative !== "push_transport.js") {
        offenders.push(`${relative}: firebase-admin`);
      }
      for (const forbidden of [
        "admin.firestore",
        "getFirestore",
        "admin.auth",
        "getAuth",
        "admin.storage",
        "getStorage",
      ]) {
        if (source.includes(forbidden)) {
          offenders.push(`${relative}: ${forbidden}`);
        }
      }
    }
  }

  scan(srcDir);
  assert.deepEqual(offenders, []);
});

test("backend auth router does not expose legacy Firebase custom token endpoint", () => {
  assert.equal(handlerNames.includes("createCustomAuthToken"), false);
  const routerSource = fs.readFileSync(
    path.join(__dirname, "../src/call_router.js"),
    "utf8",
  );
  assert.equal(routerSource.includes("createCustomAuthToken"), false);
});

test("shell Firebase guard enforces FCM-only architecture", () => {
  const guardPath = path.join(__dirname, "../../scripts/check_firebase_fcm_only.sh");
  const guardSource = fs.readFileSync(guardPath, "utf8");

  assert.match(guardSource, /cloud_firestore/);
  assert.match(guardSource, /firebase_auth/);
  assert.match(guardSource, /firebase_storage/);
  assert.match(guardSource, /FirebaseFirestore/);
  assert.match(guardSource, /FirebaseAuth/);
  assert.match(guardSource, /firebase-admin is allowed only in server\/src\/push_transport\.js/);
  assert.match(guardSource, /Firebase is limited to FCM push/);

  const result = spawnSync("bash", [guardPath], {
    cwd: path.join(__dirname, "../.."),
    encoding: "utf8",
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
});

test("architecture status points to MTaxi backend, not legacy Firebase functions", () => {
  const status = fs.readFileSync(
    path.join(__dirname, "../../ARCHITECTURE_STATUS.md"),
    "utf8",
  );

  assert.equal(handlerNames.includes("getBackendArchitectureStatus"), true);
  assert.match(status, /server\/src\/call_router\.js/);
  assert.match(status, /server\/src\/orders\.js/);
  assert.match(status, /server\/src\/users\.js/);
  assert.match(status, /server\/src\/push_transport\.js/);
  assert.match(status, /lib\/auth\/backend_auth\/auth_util\.dart/);
  assert.match(status, /lib\/backend\/backend_refs_compat\.dart/);
  assert.match(status, /Firebase is allowed only as FCM transport/);
  assert.doesNotMatch(status, /firebase\/functions/);
  assert.doesNotMatch(status, /lib\/auth\/firebase_auth\/auth_util\.dart/);
  assert.doesNotMatch(status, /lib\/backend\/firestore_compat\.dart/);
  assert.doesNotMatch(status, /FirebaseFirestore\.instance/);
  assert.doesNotMatch(status, /Primary backend entrypoints:[\s\S]*firebase\/functions/);
});

test("architecture status references existing source files", () => {
  const rootDir = path.join(__dirname, "../..");
  const status = fs.readFileSync(
    path.join(rootDir, "ARCHITECTURE_STATUS.md"),
    "utf8",
  );
  const referencedPaths = [
    ...status.matchAll(/`([^`\n]+\.[a-zA-Z0-9]+)`/g),
  ]
    .map((match) => match[1])
    .filter((value) => value.includes("/"))
    .filter((value) => !value.includes("..."));
  const missing = referencedPaths.filter(
    (relativePath) => !fs.existsSync(path.join(rootDir, relativePath)),
  );

  assert.deepEqual(missing, []);
});

test("getBackendArchitectureStatus reports backend-only runtime contract", async () => {
  const result = await getBackendArchitectureStatusAsync();

  assert.equal(result.success, true);
  assert.equal(result.architecture, "backend-only");
  assert.equal(result.backendAuthoritative, true);
  assert.equal(result.firebaseAllowedOnlyFor, "FCM transport");
  assert.ok(result.backendEntrypoints.includes("server/src/call_router.js"));
  assert.ok(result.backendAuthoritativeDomains.includes("orders"));
  assert.ok(result.firebaseForbiddenFor.includes("Firestore"));
  assert.ok(result.firebaseForbiddenFor.includes("Auth"));
});

test("all Flutter backend calls have server handlers", () => {
  const libDir = path.join(__dirname, "../../lib");
  const callNames = new Set();

  function scan(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        scan(fullPath);
        continue;
      }
      if (!entry.name.endsWith(".dart")) continue;
      const source = fs.readFileSync(fullPath, "utf8");
      const regex = /(?:makeCloudCall|mtaxiBackendCall)\(\s*['"]([^'"]+)['"]/g;
      let match;
      while ((match = regex.exec(source)) !== null) {
        callNames.add(match[1]);
      }
    }
  }

  scan(libDir);
  const handlers = new Set(handlerNames);
  const missing = [...callNames].filter((name) => !handlers.has(name)).sort();
  assert.deepEqual(missing, []);
});

test("backend API contract exports server handlers and client call coverage", () => {
  const contract = buildContract();
  assert.equal(contract.type, "mtaxi-backend-api-contract");
  assert.equal(contract.endpoint, "POST /call/:name");
  assert.equal(contract.firebaseUsage, "FCM push only");
  assert.deepEqual(contract.missingServerHandlers, []);
  assert.ok(contract.serverHandlerCount >= handlerNames.length);
  assert.ok(contract.clientCallCount > 0);
  assert.ok(contract.handlers.some((handler) =>
    handler.name === "requestSmsCode" &&
    handler.access === "public-rate-limited" &&
    handler.rateLimited === true));
  assert.ok(contract.handlers.some((handler) =>
    handler.name === "createPassengerOrder" &&
    handler.category === "orders" &&
    handler.access === "user-token"));
  assert.ok(contract.handlers.some((handler) =>
    handler.name === "adminManageOrder" &&
    handler.category === "admin" &&
    handler.access === "admin-token"));
});

test("backend env contract pins production backend-only settings", () => {
  const contract = buildEnvContract();
  assert.equal(contract.type, "mtaxi-backend-env-contract");
  assert.equal(contract.store, "PostgreSQL in production");
  assert.equal(contract.firebaseUsage, "FCM push only");
  assert.equal(
    contract.firebaseCredentialRequirement,
    "FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS",
  );
  assert.deepEqual(contract.missingInExample, []);
  assert.deepEqual(contract.mismatchedProductionDefaults, []);
  assert.deepEqual(contract.unsafeDevDefaults, []);
  assert.equal(contract.productionValues.NODE_ENV, "production");
  assert.equal(contract.productionValues.MTAXI_STORE, "postgres");
  assert.equal(contract.productionValues.MTAXI_SMS_PROVIDER, "http");
  assert.equal(contract.productionValues.MTAXI_PAYMENT_PROVIDER, "redirect");
  assert.equal(contract.productionValues.MTAXI_FCM_ENABLED, "true");
  assert.ok(contract.requiredProduction.includes("DATABASE_URL"));
  assert.ok(contract.requiredProduction.includes("MTAXI_PAYMENT_CALLBACK_SECRET"));
  assert.ok(contract.forbiddenTrueInProduction.includes("MTAXI_ALLOW_LOCAL_SMS"));
  assert.ok(contract.forbiddenTrueInProduction.includes("MTAXI_ALLOW_LOCAL_PAYMENT"));
  assert.ok(contract.forbiddenTrueInProduction.includes("MTAXI_ALLOW_SIMULATED_PUSH"));
  assert.ok(contract.forbiddenFirebaseDataEnvPatterns.includes("^FIREBASE_STORAGE_"));
});

test("public auth calls are rate limited by IP and phone", async () => {
  const previousWindow = process.env.MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC;
  const previousMax = process.env.MTAXI_AUTH_RATE_LIMIT_MAX;
  try {
    clearRateLimits();
    process.env.MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC = "60";
    process.env.MTAXI_AUTH_RATE_LIMIT_MAX = "2";
    const req = {
      headers: { "x-forwarded-for": "203.0.113.10" },
      get(name) {
        return name.toLowerCase() === "authorization" ? "" : "";
      },
    };

    const first = await dispatchCall("passwordLogin", {
      phone: "7052597368",
      password: "bad",
    }, req);
    const second = await dispatchCall("passwordLogin", {
      phone: "7052597368",
      password: "bad",
    }, req);
    const third = await dispatchCall("passwordLogin", {
      phone: "7052597368",
      password: "bad",
    }, req);

    assert.equal(first.code, "PASSWORD_INVALID");
    assert.equal(second.code, "PASSWORD_INVALID");
    assert.equal(third.code, "RATE_LIMITED");
    assert.ok(third.retryAfterSec > 0);

    const health = await dispatchCall("getStoreHealth", {}, req);
    assert.equal(health.success, true);
  } finally {
    clearRateLimits();
    if (previousWindow === undefined) {
      delete process.env.MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC;
    } else {
      process.env.MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC = previousWindow;
    }
    if (previousMax === undefined) {
      delete process.env.MTAXI_AUTH_RATE_LIMIT_MAX;
    } else {
      process.env.MTAXI_AUTH_RATE_LIMIT_MAX = previousMax;
    }
  }
});

test("router denies admin operations without authenticated admin", async () => {
  const req = { get: () => "" };
  const adminOnlyCalls = [
    "updateRuntimeSettings",
    "adminListUsers",
    "adminListAuditLogs",
    "adminUpdateUserDocument",
    "adminCreateDriver",
    "adminCreatePassenger",
    "adminCreateOrder",
    "approveDriver",
    "blockDriver",
    "unblockDriver",
    "adminTopUpDriverBalance",
    "adminManageOrder",
    "adminListCityTariffs",
    "adminUpsertCityTariff",
    "adminListIntercityRoutes",
    "adminUpsertIntercityRoute",
    "adminUpdateContentDocument",
    "adminListGenericCollection",
    "adminUpsertGenericDocument",
    "adminDeleteGenericDocument",
    "confirmDriverTopUpPayment",
    "failDriverTopUpPayment",
    "adminListWithdrawals",
    "adminResolveWithdrawal",
    "adminListPayments",
    "getMoneyStats",
    "listSupportChats",
    "adminSendSupportChatMessage",
    "adminDeleteSupportChat",
    "adminClearSupportChats",
    "createPushNotification",
    "adminQueueBroadcast",
    "adminListPushNotifications",
    "flushQueuedPushDeliveries",
    "runMaintenanceTasks",
  ];

  for (const name of adminOnlyCalls) {
    const result = await dispatchCall(name, {}, req);
    assert.equal(
      result.code,
      "UNAUTHENTICATED",
      `${name} must require authenticated admin`,
    );
  }
});

test("postgres push ack persistence uses notification id for idempotency", () => {
  const schema = fs.readFileSync(path.join(__dirname, "../db/schema.sql"), "utf8");
  const pgStore = fs.readFileSync(path.join(__dirname, "../src/store/postgres_store.js"), "utf8");
  const migration = fs.readFileSync(
    path.join(__dirname, "../scripts/migrate_json_to_postgres.js"),
    "utf8",
  );

  assert.match(schema, /notification_id text NOT NULL DEFAULT ''/);
  assert.match(schema, /COALESCE\(NULLIF\(data->>'notificationId', ''\), id\)/);
  assert.match(schema, /push_delivery_acks_user_notification_event_idx/);
  assert.match(pgStore, /ON CONFLICT \(user_id, event_type, notification_id\)/);
  assert.match(migration, /ON CONFLICT \(user_id, event_type, notification_id\)/);
});

test("postgres schema records applied migration version", () => {
  const schema = fs.readFileSync(path.join(__dirname, "../db/schema.sql"), "utf8");
  assert.match(schema, /CREATE TABLE IF NOT EXISTS schema_migrations/);
  assert.match(schema, /version text PRIMARY KEY/);
  assert.match(schema, /2026-07-22-backend-base/);
  assert.match(schema, /ON CONFLICT \(version\) DO NOTHING/);
});

test("postgres ledger payment id stores external payment identifier", () => {
  const schema = fs.readFileSync(path.join(__dirname, "../db/schema.sql"), "utf8");
  assert.match(schema, /payment_id text,\n  type text NOT NULL/);
  assert.match(schema, /DROP CONSTRAINT IF EXISTS ledger_payment_id_fkey/);
  assert.doesNotMatch(schema, /payment_id text REFERENCES payments\(id\)/);
});

test("postgres store serializes snapshot writes with advisory transaction lock", () => {
  const pgStore = fs.readFileSync(path.join(__dirname, "../src/store/postgres_store.js"), "utf8");
  assert.match(pgStore, /STORE_WRITE_LOCK_KEY = "mtaxi_store_write"/);
  assert.match(pgStore, /pg_advisory_xact_lock\(hashtext\(\$1\)\)/);
  assert.match(pgStore, /await client\.query\("BEGIN"\)/);
  assert.match(pgStore, /await client\.query\("COMMIT"\)/);
  assert.match(pgStore, /await client\.query\("ROLLBACK"\)/);
  assert.match(pgStore, /async function writeStoreAsync\(store\) \{\s+return withPgTransaction/s);
  assert.match(pgStore, /async function withStoreAsync\(mutator\) \{\s+return withPgTransaction/s);
});

test("store health reports selected local JSON store", async () => {
  const pgStoreSource = fs.readFileSync(path.join(__dirname, "../src/store/postgres_store.js"), "utf8");
  const health = await storeHealth();
  assert.equal(health.ok, true);
  assert.equal(health.type, "json");
  assert.match(health.dataFile, /local-db\.json$/);

  const pgHealth = await postgresStore.storeHealth();
  assert.equal(pgHealth.ok, false);
  assert.equal(pgHealth.type, "postgres");
  assert.match(pgHealth.error, /DATABASE_URL/);
  assert.match(pgStoreSource, /FROM schema_migrations/);
  assert.match(pgStoreSource, /schemaVersion/);
  assert.match(pgStoreSource, /schemaAppliedAt/);
});

test("getStoreHealth callable reports active backend store", async () => {
  const result = await dispatchCall("getStoreHealth", {}, { get: () => "" });
  assert.equal(result.success, true);
  assert.equal(result.store.ok, true);
  assert.equal(result.store.type, "json");
  assert.match(result.store.dataFile, /local-db\.json$/);
});

test("json store supports async compatibility contract", async () => {
  const before = await readStoreAsync();
  const result = await withStoreAsync(async (store) => {
    store.settings.asyncContractProbe = "ok";
    return store.settings.asyncContractProbe;
  });
  assert.equal(result, "ok");
  assert.equal(readStore().settings.asyncContractProbe, "ok");
  writeStore(before);
});

test("http config supports production CORS allow-list", async () => {
  assert.equal(corsOriginForEnv({}), true);
  assert.equal(jsonBodyLimitForEnv({}), "25mb");
  assert.equal(jsonBodyLimitForEnv({ MTAXI_JSON_BODY_LIMIT: "10mb" }), "10mb");

  const origin = corsOriginForEnv({
    MTAXI_CORS_ORIGINS: "https://mtaxi.example, https://admin.mtaxi.example",
  });
  assert.equal(typeof origin, "function");

  await new Promise((resolve, reject) => {
    origin("https://mtaxi.example", (error, allowed) => {
      if (error) reject(error);
      try {
        assert.equal(allowed, true);
        resolve();
      } catch (e) {
        reject(e);
      }
    });
  });
  await assert.rejects(
    () => new Promise((resolve, reject) => {
      origin("https://evil.example", (error, allowed) => {
        if (error) reject(error);
        else resolve(allowed);
      });
    }),
    /CORS origin is not allowed/,
  );
});

test("http config supports proxy trust and baseline security headers", () => {
  assert.equal(trustProxyForEnv({}), false);
  assert.equal(trustProxyForEnv({ MTAXI_TRUST_PROXY: "true" }), true);
  assert.equal(trustProxyForEnv({ MTAXI_TRUST_PROXY: "1" }), true);
  assert.equal(trustProxyForEnv({ MTAXI_TRUST_PROXY: "false" }), false);
  assert.equal(trustProxyForEnv({ MTAXI_TRUST_PROXY: "no" }), false);
  assert.equal(trustProxyForEnv({ MTAXI_TRUST_PROXY: "2" }), 2);

  const headers = {};
  securityHeadersMiddleware({}, {
    setHeader(name, value) {
      headers[name] = value;
    },
  }, () => {
    headers.next = true;
  });

  assert.equal(headers["X-Content-Type-Options"], "nosniff");
  assert.equal(headers["Referrer-Policy"], "no-referrer");
  assert.equal(headers["X-Frame-Options"], "DENY");
  assert.equal(headers.next, true);

  const uploadHeaders = {};
  const uploadOptions = uploadStaticOptionsForEnv({ MTAXI_UPLOAD_CACHE_MAX_AGE_SEC: "120" });
  uploadOptions.setHeaders({
    setHeader(name, value) {
      uploadHeaders[name] = value;
    },
  });
  assert.equal(uploadOptions.fallthrough, false);
  assert.equal(uploadOptions.maxAge, "120s");
  assert.equal(uploadOptions.immutable, true);
  assert.equal(uploadHeaders["X-Content-Type-Options"], "nosniff");
  assert.equal(uploadHeaders["Cross-Origin-Resource-Policy"], "cross-origin");
  assert.equal(uploadHeaders["Cache-Control"], "public, max-age=120, immutable");

  const noCacheOptions = uploadStaticOptionsForEnv({ MTAXI_UPLOAD_CACHE_MAX_AGE_SEC: "0" });
  const noCacheHeaders = {};
  noCacheOptions.setHeaders({
    setHeader(name, value) {
      noCacheHeaders[name] = value;
    },
  });
  assert.equal(noCacheOptions.immutable, false);
  assert.equal(noCacheHeaders["Cache-Control"], "no-store");
});

test("http config adds request ids and access logs without request body", () => {
  assert.equal(accessLogEnabledForEnv({ MTAXI_ACCESS_LOGS: "false" }), false);
  assert.equal(accessLogEnabledForEnv({ MTAXI_ACCESS_LOGS: "true" }), true);
  assert.equal(accessLogPath({ originalUrl: "/call/passwordLogin?token=secret" }), "/call/passwordLogin");
  const headers = {};
  const req = {
    method: "POST",
    originalUrl: "/call/passwordLogin?password=secret",
    ip: "127.0.0.1",
    body: { password: "secret" },
    get(name) {
      return name === "x-request-id" ? "req_test_12345678" : "agent";
    },
  };
  const res = {
    statusCode: 200,
    listeners: {},
    setHeader(name, value) {
      headers[name] = value;
    },
    on(event, callback) {
      this.listeners[event] = callback;
    },
  };
  requestIdMiddleware(req, res, () => {});
  assert.equal(req.requestId, "req_test_12345678");
  assert.equal(headers["X-Request-Id"], "req_test_12345678");

  const logs = [];
  accessLogMiddleware({
    env: { MTAXI_ACCESS_LOGS: "true" },
    logger: { info: (...args) => logs.push(args) },
  })(req, res, () => {});
  res.listeners.finish();
  assert.equal(logs.length, 1);
  assert.equal(logs[0][0], "mtaxi_http_access");
  assert.equal(logs[0][1].requestId, "req_test_12345678");
  assert.equal(logs[0][1].method, "POST");
  assert.equal(logs[0][1].path, "/call/passwordLogin");
  assert.equal(logs[0][1].password, undefined);
  assert.equal(JSON.stringify(logs[0][1]).includes("secret"), false);
});

test("production preflight validates required server env without database probe", async () => {
  assert.equal(validNodeVersion("20.0.0"), true);
  assert.equal(validNodeVersion("24.10.0"), true);
  assert.equal(validNodeVersion("18.20.0"), false);
  assert.equal(validNodeVersion("bad"), false);
  assert.equal(validPort("8080"), true);
  assert.equal(validPort("1"), true);
  assert.equal(validPort("65535"), true);
  assert.equal(validPort("0"), false);
  assert.equal(validPort("65536"), false);
  assert.equal(validPort("bad"), false);
  assert.equal(validPublicBaseUrl("https://api.mtaxi.example"), true);
  assert.equal(validPublicBaseUrl("http://127.0.0.1:8080"), true);
  assert.equal(isInsecurePublicBaseUrl("http://api.mtaxi.example"), true);
  assert.equal(isInsecurePublicBaseUrl("https://api.mtaxi.example"), false);
  assert.equal(isLocalPublicBaseUrl("http://localhost:8080"), true);
  assert.equal(isLocalPublicBaseUrl("http://127.0.0.1:8080"), true);
  assert.equal(isLocalPublicBaseUrl("http://0.0.0.0:8080"), true);
  assert.equal(isLocalPublicBaseUrl("https://10.0.2.2:8080"), true);
  assert.equal(isLocalPublicBaseUrl("https://100.64.0.1"), true);
  assert.equal(isLocalPublicBaseUrl("https://100.127.255.255"), true);
  assert.equal(isLocalPublicBaseUrl("https://100.128.0.1"), false);
  assert.equal(isLocalPublicBaseUrl("https://169.254.1.10"), true);
  assert.equal(isLocalPublicBaseUrl("http://192.168.1.10:8080"), true);
  assert.equal(isLocalPublicBaseUrl("https://172.16.0.10"), true);
  assert.equal(isLocalPublicBaseUrl("https://172.31.255.10"), true);
  assert.equal(isLocalPublicBaseUrl("https://172.32.0.10"), false);
  assert.equal(isLocalPublicBaseUrl("https://[::1]:8080"), true);
  assert.equal(isLocalPublicBaseUrl("https://[fd12::1]"), true);
  assert.equal(isLocalPublicBaseUrl("https://[fe80::1]"), true);
  assert.equal(isLocalPublicBaseUrl("https://api.mtaxi.example"), false);
  assert.equal(validPublicBaseUrl("ftp://api.mtaxi.example"), false);
  assert.equal(validPublicBaseUrl("https://api.example.kz"), false);
  assert.equal(validPublicBaseUrl("not-url"), false);
  assert.equal(validCorsOrigins("https://mtaxi.example,https://admin.mtaxi.example"), true);
  assert.equal(validCorsOrigins("http://localhost:3000"), true);
  assert.equal(validCorsOrigins("https://mtaxi.example/app"), false);
  assert.equal(validCorsOrigins("*"), false);
  assert.equal(validCorsOrigins("bad"), false);
  assert.equal(validPostgresUrl("postgres://user:pass@db.example:5432/mtaxi"), true);
  assert.equal(validPostgresUrl("postgresql://user:pass@db.example/mtaxi"), true);
  assert.equal(validPostgresUrl("mysql://user:pass@db.example/mtaxi"), false);
  assert.equal(validPostgresUrl("postgres://mtaxi:password@127.0.0.1:5432/mtaxi"), false);
  assert.equal(validPostgresUrl("postgres://mtaxi:mtaxi_change_me@postgres:5432/mtaxi"), false);
  assert.equal(validPostgresUrl("bad"), false);
  assert.equal(
    validPaymentUrlTemplate("https://pay.example/start?invoice={{paymentId}}&amount={{amount}}"),
    true,
  );
  assert.equal(
    validPaymentUrlTemplate("http://pay.example/start?invoice={{paymentId}}&amount={{amount}}"),
    true,
  );
  assert.equal(
    validProductionPaymentUrlTemplate("https://pay.example/start?invoice={{paymentId}}&amount={{amount}}"),
    true,
  );
  assert.equal(
    validProductionPaymentUrlTemplate("http://pay.example/start?invoice={{paymentId}}&amount={{amount}}"),
    false,
  );
  assert.equal(
    validProductionPaymentUrlTemplate("https://localhost/start?invoice={{paymentId}}&amount={{amount}}"),
    false,
  );
  assert.equal(
    validProductionPaymentUrlTemplate(
      "{{publicBaseUrl}}/payments/start?invoice={{paymentId}}&amount={{amount}}",
      "https://api.mtaxi.example",
    ),
    true,
  );
  assert.equal(
    validProductionPaymentUrlTemplate(
      "{{publicBaseUrl}}/payments/start?invoice={{paymentId}}&amount={{amount}}",
      "http://127.0.0.1:8080",
    ),
    false,
  );
  assert.equal(validPaymentUrlTemplate("https://pay.example/start?invoice={{paymentId}}"), false);
  assert.equal(validPaymentUrlTemplate("ftp://pay.example/start?invoice={{paymentId}}&amount={{amount}}"), false);
  assert.equal(validPaymentUrlTemplate("bad"), false);
  assert.equal(validHttpUrl("https://sms.example/send"), true);
  assert.equal(validProductionHttpUrl("https://sms.example/send"), true);
  assert.equal(validProductionHttpUrl("http://sms.example/send"), false);
  assert.equal(validProductionHttpUrl("https://localhost/send"), false);
  assert.equal(validHttpUrl("ftp://sms.example/send"), false);
  assert.equal(validSmsHttpMethod("POST"), true);
  assert.equal(validSmsHttpMethod("GET"), false);
  assert.equal(validSmsBodyTemplate('{"to":"{{phone}}","text":"{{message}}"}'), true);
  assert.equal(validSmsBodyTemplate('{"to":"{{phone}}"}'), false);
  assert.equal(validSmsBodyTemplate("not-json {{phone}} {{message}}"), false);
  assert.equal(validJsonBodyLimit("25mb"), true);
  assert.equal(validJsonBodyLimit("1048576b"), true);
  assert.equal(validJsonBodyLimit("0mb"), false);
  assert.equal(validJsonBodyLimit("bad"), false);
  assert.equal(validPhone("+77000000000"), true);
  assert.equal(validPhone("77000000000"), true);
  assert.equal(validPhone("87000000000"), true);
  assert.equal(validPhone("700 000-00-00"), true);
  assert.equal(validPhone("+70000000000"), false);
  assert.equal(validPhone("123"), false);
  assert.equal(validPhone("bad"), false);
  assert.ok(parseFirebaseServiceAccount(JSON.stringify({
    project_id: "mtaxi-test",
    client_email: "firebase-admin@test.example",
    private_key: "-----BEGIN PRIVATE KEY-----\\nkey\\n-----END PRIVATE KEY-----\\n",
  })));
  assert.equal(parseFirebaseServiceAccount(JSON.stringify({
    project_id: "mtaxi-test",
    client_email: "firebase-admin@test.example",
    private_key: "key",
  })), null);
  assert.equal(parseFirebaseServiceAccount(JSON.stringify({
    project_id: "mtaxi-test",
    client_email: "firebase-admin",
    private_key: "-----BEGIN PRIVATE KEY-----\\nkey\\n-----END PRIVATE KEY-----\\n",
  })), null);
  const validPreflightEnv = {
    PORT: "8080",
    MTAXI_PUBLIC_BASE_URL: "https://api.mtaxi.example",
    MTAXI_TOKEN_SECRET: "012345678901234567890123456789",
    MTAXI_CORS_ORIGINS: "https://mtaxi.example,https://admin.mtaxi.example",
    MTAXI_JSON_BODY_LIMIT: "25mb",
    MTAXI_TRUST_PROXY: "1",
    MTAXI_STORE: "postgres",
    DATABASE_URL: "postgres://mtaxi:secret@db.example:5432/mtaxi",
    MTAXI_PAYMENT_PROVIDER: "redirect",
    MTAXI_PAYMENT_URL_TEMPLATE: "https://pay.example/start?invoice={{paymentId}}&amount={{amount}}",
    MTAXI_PAYMENT_CALLBACK_SECRET: "payment-callback-secret-1",
    MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY: "false",
    MTAXI_MAINTENANCE_INTERVAL_SEC: "30",
    MTAXI_PENDING_ORDER_TTL_MIN: "15",
    MTAXI_MAINTENANCE_ORDER_LIMIT: "100",
    MTAXI_MAINTENANCE_PUSH_LIMIT: "100",
    MTAXI_MAX_UPLOAD_BYTES: "10485760",
    MTAXI_UPLOAD_CACHE_MAX_AGE_SEC: "2592000",
    MTAXI_BACKUP_RETENTION_DAYS: "30",
    MTAXI_SMS_CODE_TTL_SEC: "300",
    MTAXI_SMS_RESEND_COOLDOWN_SEC: "30",
    MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC: "60",
    MTAXI_AUTH_RATE_LIMIT_MAX: "20",
    MTAXI_SMS_PROVIDER: "http",
    MTAXI_SMS_HTTP_URL: "https://sms.mtaxi.example/send",
    MTAXI_SMS_HTTP_METHOD: "POST",
    MTAXI_SMS_HTTP_HEADERS: '{"X-Service":"mtaxi"}',
    MTAXI_SMS_HTTP_BODY_TEMPLATE: '{"to":"{{phone}}","text":"{{message}}"}',
    MTAXI_SEED_ADMIN_ON_START: "true",
    MTAXI_ADMIN_PHONE: "+77000000000",
    MTAXI_ADMIN_PASSWORD: "strong-admin-password",
    MTAXI_ADMIN_NAME: "Администратор",
    MTAXI_FCM_ENABLED: "true",
    FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({
      project_id: "mtaxi-test",
      client_email: "firebase-admin@test.example",
      private_key: "-----BEGIN PRIVATE KEY-----\\nkey\\n-----END PRIVATE KEY-----\\n",
    }),
    MTAXI_UPLOAD_DIR: process.env.MTAXI_UPLOAD_DIR,
  };
  const valid = await runPreflight({
    env: validPreflightEnv,
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(valid.ok, true);
  assert.deepEqual(forbiddenFirebaseDataEnvKeys({
    FIREBASE_SERVICE_ACCOUNT_JSON: validPreflightEnv.FIREBASE_SERVICE_ACCOUNT_JSON,
    GOOGLE_APPLICATION_CREDENTIALS: "/etc/mtaxi/firebase.json",
  }), []);

  const invalid = await runPreflight({
    env: {
      PORT: "bad",
      MTAXI_PUBLIC_BASE_URL: "http://127.0.0.1:8080",
      MTAXI_TOKEN_SECRET: "short",
      MTAXI_CORS_ORIGINS: "*,bad",
      MTAXI_JSON_BODY_LIMIT: "bad",
      MTAXI_TRUST_PROXY: "-1",
      MTAXI_STORE: "json",
      DATABASE_URL: "postgres://mtaxi:mtaxi_change_me@postgres:5432/mtaxi",
      MTAXI_PAYMENT_PROVIDER: "local",
      MTAXI_PAYMENT_URL_TEMPLATE: "https://pay.example/start?invoice={{paymentId}}",
      MTAXI_PAYMENT_CALLBACK_SECRET: "change-this-payment-callback-secret",
      MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY: "true",
      MTAXI_MAINTENANCE_INTERVAL_SEC: "-1",
      MTAXI_PENDING_ORDER_TTL_MIN: "0",
      MTAXI_MAINTENANCE_ORDER_LIMIT: "bad",
      MTAXI_MAINTENANCE_PUSH_LIMIT: "0",
      MTAXI_MAX_UPLOAD_BYTES: "0",
      MTAXI_UPLOAD_CACHE_MAX_AGE_SEC: "-1",
      MTAXI_BACKUP_RETENTION_DAYS: "bad",
      MTAXI_SMS_CODE_TTL_SEC: "0",
      MTAXI_SMS_RESEND_COOLDOWN_SEC: "-1",
      MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC: "0",
      MTAXI_AUTH_RATE_LIMIT_MAX: "bad",
      MTAXI_SMS_DEV_RETURN_CODE: "true",
      MTAXI_SMS_PROVIDER: "http",
      MTAXI_SMS_HTTP_URL: "ftp://sms.example/send",
      MTAXI_SMS_HTTP_METHOD: "GET",
      MTAXI_SMS_HTTP_HEADERS: "bad",
      MTAXI_SMS_HTTP_BODY_TEMPLATE: '{"to":"{{phone}}"}',
      MTAXI_SEED_ADMIN_ON_START: "true",
      MTAXI_ADMIN_PHONE: "bad-phone",
      MTAXI_ADMIN_PASSWORD: "123",
      MTAXI_ADMIN_NAME: "",
      MTAXI_FCM_ENABLED: "true",
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(invalid.ok, false);
  const failed = invalid.checks
    .filter((check) => !check.ok)
    .map((check) => check.name);
  assert.ok(failed.includes("PORT"));
  assert.ok(failed.includes("MTAXI_PUBLIC_BASE_URL"));
  assert.ok(failed.includes("MTAXI_TOKEN_SECRET"));
  assert.ok(failed.includes("MTAXI_CORS_ORIGINS"));
  assert.ok(failed.includes("MTAXI_JSON_BODY_LIMIT"));
  assert.ok(failed.includes("MTAXI_TRUST_PROXY"));
  assert.ok(failed.includes("MTAXI_STORE"));
  assert.ok(failed.includes("DATABASE_URL"));
  assert.ok(failed.includes("MTAXI_PAYMENT_PROVIDER"));
  assert.ok(failed.includes("MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY"));
  assert.ok(failed.includes("MTAXI_MAINTENANCE_INTERVAL_SEC"));
  assert.ok(failed.includes("MTAXI_PENDING_ORDER_TTL_MIN"));
  assert.ok(failed.includes("MTAXI_MAINTENANCE_ORDER_LIMIT"));
  assert.ok(failed.includes("MTAXI_MAINTENANCE_PUSH_LIMIT"));
  assert.ok(failed.includes("MTAXI_MAX_UPLOAD_BYTES"));
  assert.ok(failed.includes("MTAXI_UPLOAD_CACHE_MAX_AGE_SEC"));
  assert.ok(failed.includes("MTAXI_BACKUP_RETENTION_DAYS"));
  assert.ok(failed.includes("MTAXI_SMS_CODE_TTL_SEC"));
  assert.ok(failed.includes("MTAXI_SMS_RESEND_COOLDOWN_SEC"));
  assert.ok(failed.includes("MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC"));
  assert.ok(failed.includes("MTAXI_AUTH_RATE_LIMIT_MAX"));
  assert.ok(failed.includes("MTAXI_SMS_DEV_RETURN_CODE"));
  assert.ok(failed.includes("MTAXI_SMS_HTTP_URL"));
  assert.ok(failed.includes("MTAXI_SMS_HTTP_METHOD"));
  assert.ok(failed.includes("MTAXI_SMS_HTTP_HEADERS"));
  assert.ok(failed.includes("MTAXI_SMS_HTTP_BODY_TEMPLATE"));
  assert.ok(failed.includes("MTAXI_ADMIN_PHONE"));
  assert.ok(failed.includes("MTAXI_ADMIN_PASSWORD"));
  assert.ok(failed.includes("MTAXI_ADMIN_NAME"));
  assert.ok(failed.includes("FCM credentials"));

  const localSmsDevReturn = await runPreflight({
    env: {
      ...validPreflightEnv,
      MTAXI_SMS_PROVIDER: "local",
      MTAXI_ALLOW_LOCAL_SMS: "true",
      MTAXI_SMS_DEV_RETURN_CODE: "true",
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(localSmsDevReturn.ok, true);

  const insecurePaymentRedirect = await runPreflight({
    env: {
      ...validPreflightEnv,
      MTAXI_PAYMENT_URL_TEMPLATE: "http://pay.example/start?invoice={{paymentId}}&amount={{amount}}",
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(insecurePaymentRedirect.ok, false);
  assert.ok(
    insecurePaymentRedirect.checks
      .filter((check) => !check.ok)
      .some((check) => check.name === "MTAXI_PAYMENT_URL_TEMPLATE"),
  );

  const localPublicUrlPaymentRedirect = await runPreflight({
    env: {
      ...validPreflightEnv,
      MTAXI_PUBLIC_BASE_URL: "http://127.0.0.1:8080",
      MTAXI_PAYMENT_URL_TEMPLATE:
        "{{publicBaseUrl}}/payments/start?invoice={{paymentId}}&amount={{amount}}",
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(localPublicUrlPaymentRedirect.ok, false);
  assert.ok(
    localPublicUrlPaymentRedirect.checks
      .filter((check) => !check.ok)
      .some((check) => check.name === "MTAXI_PAYMENT_URL_TEMPLATE"),
  );

  const insecurePublicUrl = await runPreflight({
    env: {
      ...validPreflightEnv,
      MTAXI_PUBLIC_BASE_URL: "http://api.mtaxi.example",
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(insecurePublicUrl.ok, false);
  assert.ok(
    insecurePublicUrl.checks
      .filter((check) => !check.ok)
      .some((check) => check.name === "MTAXI_PUBLIC_BASE_URL"),
  );

  const insecureSmsUrl = await runPreflight({
    env: {
      ...validPreflightEnv,
      MTAXI_SMS_HTTP_URL: "http://sms.mtaxi.example/send",
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(insecureSmsUrl.ok, false);
  assert.ok(
    insecureSmsUrl.checks
      .filter((check) => !check.ok)
      .some((check) => check.name === "MTAXI_SMS_HTTP_URL"),
  );

  const missingCredentialFile = await runPreflight({
    env: {
      ...valid.checks.reduce((acc, _check) => acc, {}),
      PORT: "8080",
      MTAXI_PUBLIC_BASE_URL: "https://api.mtaxi.example",
      MTAXI_CORS_ORIGINS: "https://mtaxi.example,https://admin.mtaxi.example",
      MTAXI_JSON_BODY_LIMIT: "25mb",
      MTAXI_TOKEN_SECRET: "012345678901234567890123456789",
      MTAXI_STORE: "postgres",
      DATABASE_URL: "postgres://mtaxi:secret@db.example:5432/mtaxi",
      MTAXI_PAYMENT_PROVIDER: "redirect",
      MTAXI_PAYMENT_URL_TEMPLATE: "https://pay.example/start?invoice={{paymentId}}&amount={{amount}}",
      MTAXI_PAYMENT_CALLBACK_SECRET: "payment-callback-secret-1",
      MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY: "false",
      MTAXI_MAINTENANCE_INTERVAL_SEC: "30",
      MTAXI_PENDING_ORDER_TTL_MIN: "15",
      MTAXI_MAINTENANCE_ORDER_LIMIT: "100",
      MTAXI_MAINTENANCE_PUSH_LIMIT: "100",
      MTAXI_MAX_UPLOAD_BYTES: "10485760",
      MTAXI_UPLOAD_CACHE_MAX_AGE_SEC: "2592000",
      MTAXI_SMS_CODE_TTL_SEC: "300",
      MTAXI_SMS_RESEND_COOLDOWN_SEC: "30",
      MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC: "60",
      MTAXI_AUTH_RATE_LIMIT_MAX: "20",
      MTAXI_SMS_PROVIDER: "http",
      MTAXI_SMS_HTTP_URL: "https://sms.mtaxi.example/send",
      MTAXI_SMS_HTTP_METHOD: "POST",
      MTAXI_SMS_HTTP_HEADERS: '{"X-Service":"mtaxi"}',
      MTAXI_SMS_HTTP_BODY_TEMPLATE: '{"to":"{{phone}}","text":"{{message}}"}',
      MTAXI_FCM_ENABLED: "true",
      GOOGLE_APPLICATION_CREDENTIALS: path.join(os.tmpdir(), "mtaxi-missing-fcm.json"),
      MTAXI_UPLOAD_DIR: process.env.MTAXI_UPLOAD_DIR,
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(missingCredentialFile.ok, false);
  assert.ok(missingCredentialFile.checks.some((check) =>
    check.name === "GOOGLE_APPLICATION_CREDENTIALS" && check.ok === false));

  const invalidCredentialPath = path.join(os.tmpdir(), "mtaxi-invalid-fcm.json");
  fs.writeFileSync(invalidCredentialPath, JSON.stringify({
    project_id: "mtaxi-test",
    client_email: "firebase-admin@test.example",
    private_key: "key",
  }));
  const invalidCredentialFile = await runPreflight({
    env: {
      ...validPreflightEnv,
      FIREBASE_SERVICE_ACCOUNT_JSON: "",
      GOOGLE_APPLICATION_CREDENTIALS: invalidCredentialPath,
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(invalidCredentialFile.ok, false);
  assert.ok(invalidCredentialFile.checks.some((check) =>
    check.name === "GOOGLE_APPLICATION_CREDENTIALS" && check.ok === false));

  const validCredentialPath = path.join(os.tmpdir(), "mtaxi-valid-fcm.json");
  fs.writeFileSync(validCredentialPath, JSON.stringify({
    project_id: "mtaxi-test",
    client_email: "firebase-admin@test.example",
    private_key: "-----BEGIN PRIVATE KEY-----\\nkey\\n-----END PRIVATE KEY-----\\n",
  }));
  const validCredentialFile = await runPreflight({
    env: {
      ...validPreflightEnv,
      FIREBASE_SERVICE_ACCOUNT_JSON: "",
      GOOGLE_APPLICATION_CREDENTIALS: validCredentialPath,
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(validCredentialFile.ok, true);

  const disabledPush = await runPreflight({
    env: {
      ...valid.checks.reduce((acc, _check) => acc, {}),
      PORT: "8080",
      MTAXI_PUBLIC_BASE_URL: "https://api.mtaxi.example",
      MTAXI_TOKEN_SECRET: "012345678901234567890123456789",
      MTAXI_CORS_ORIGINS: "https://mtaxi.example,https://admin.mtaxi.example",
      MTAXI_STORE: "postgres",
      DATABASE_URL: "postgres://mtaxi:secret@db.example:5432/mtaxi",
      MTAXI_PAYMENT_PROVIDER: "redirect",
      MTAXI_PAYMENT_URL_TEMPLATE: "https://pay.example/start?invoice={{paymentId}}&amount={{amount}}",
      MTAXI_PAYMENT_CALLBACK_SECRET: "payment-callback-secret-1",
      MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY: "false",
      MTAXI_MAINTENANCE_INTERVAL_SEC: "30",
      MTAXI_PENDING_ORDER_TTL_MIN: "15",
      MTAXI_MAINTENANCE_ORDER_LIMIT: "100",
      MTAXI_MAINTENANCE_PUSH_LIMIT: "100",
      MTAXI_MAX_UPLOAD_BYTES: "10485760",
      MTAXI_SMS_CODE_TTL_SEC: "300",
      MTAXI_SMS_RESEND_COOLDOWN_SEC: "30",
      MTAXI_SMS_PROVIDER: "http",
      MTAXI_SMS_HTTP_URL: "https://sms.mtaxi.example/send",
      MTAXI_FCM_ENABLED: "false",
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(disabledPush.ok, false);
  assert.ok(disabledPush.checks.some((check) =>
    check.name === "MTAXI_FCM_ENABLED" && check.ok === false));

  const localCompose = await runPreflight({
    env: {
      NODE_ENV: "development",
      PORT: "8080",
      MTAXI_PUBLIC_BASE_URL: "http://localhost:8080",
      MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL: "true",
      MTAXI_TOKEN_SECRET: "012345678901234567890123456789",
      MTAXI_CORS_ORIGINS: "http://localhost:3000,http://localhost:8080",
      MTAXI_JSON_BODY_LIMIT: "25mb",
      MTAXI_TRUST_PROXY: "false",
      MTAXI_STORE: "postgres",
      DATABASE_URL: "postgres://mtaxi:secret@db.example:5432/mtaxi",
      MTAXI_PAYMENT_PROVIDER: "local",
      MTAXI_ALLOW_LOCAL_PAYMENT: "true",
      MTAXI_PAYMENT_CALLBACK_SECRET: "payment-callback-secret-1",
      MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY: "false",
      MTAXI_MAINTENANCE_INTERVAL_SEC: "30",
      MTAXI_PENDING_ORDER_TTL_MIN: "15",
      MTAXI_MAINTENANCE_ORDER_LIMIT: "100",
      MTAXI_MAINTENANCE_PUSH_LIMIT: "100",
      MTAXI_MAX_UPLOAD_BYTES: "10485760",
      MTAXI_UPLOAD_CACHE_MAX_AGE_SEC: "2592000",
      MTAXI_SMS_CODE_TTL_SEC: "300",
      MTAXI_SMS_RESEND_COOLDOWN_SEC: "30",
      MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC: "60",
      MTAXI_AUTH_RATE_LIMIT_MAX: "20",
      MTAXI_SMS_PROVIDER: "local",
      MTAXI_ALLOW_LOCAL_SMS: "true",
      MTAXI_FCM_ENABLED: "false",
      MTAXI_ALLOW_SIMULATED_PUSH: "true",
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(localCompose.ok, true);

  const productionDevFlags = await runPreflight({
    env: {
      ...validPreflightEnv,
      NODE_ENV: "production",
      MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL: "true",
      MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL: "true",
      MTAXI_ALLOW_LOCAL_SMS: "true",
      MTAXI_ALLOW_LOCAL_PAYMENT: "true",
      MTAXI_ENABLE_LEGACY_CREATE_TOKEN: "true",
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(productionDevFlags.ok, false);
  const productionDevFailed = productionDevFlags.checks
    .filter((check) => !check.ok)
    .map((check) => check.name);
  assert.ok(productionDevFailed.includes("MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL"));
  assert.ok(productionDevFailed.includes("MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL"));
  assert.ok(productionDevFailed.includes("MTAXI_ALLOW_LOCAL_SMS"));
  assert.ok(productionDevFailed.includes("MTAXI_ALLOW_LOCAL_PAYMENT"));
  assert.ok(productionDevFailed.includes("MTAXI_ENABLE_LEGACY_CREATE_TOKEN"));

  const simulatedPushInProduction = await runPreflight({
    env: {
      ...validPreflightEnv,
      NODE_ENV: "production",
      MTAXI_FCM_ENABLED: "false",
      MTAXI_ALLOW_SIMULATED_PUSH: "true",
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(simulatedPushInProduction.ok, false);
  assert.ok(simulatedPushInProduction.checks.some((check) =>
    check.name === "MTAXI_ALLOW_SIMULATED_PUSH" && check.ok === false));

  const firebaseDataEnvInProduction = await runPreflight({
    env: {
      ...validPreflightEnv,
      NODE_ENV: "production",
      FIREBASE_DATABASE_URL: "https://mtaxi.firebaseio.com",
      FIREBASE_STORAGE_BUCKET: "mtaxi.appspot.com",
      FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
    },
    checkDatabase: false,
    checkUploadDir: false,
  });
  assert.equal(firebaseDataEnvInProduction.ok, false);
  assert.ok(firebaseDataEnvInProduction.checks.some((check) =>
    check.name === "Firebase data env" &&
    check.ok === false &&
    check.message.includes("FIREBASE_DATABASE_URL") &&
    check.message.includes("FIREBASE_STORAGE_BUCKET") &&
    check.message.includes("FIRESTORE_EMULATOR_HOST")));
});

test("SMS HTTP provider renders and sends code through backend", async () => {
  const calls = [];
  const result = await sendSmsCode({
    phone: "+77052597368",
    code: "1234",
    env: {
      MTAXI_SMS_PROVIDER: "http",
      MTAXI_SMS_HTTP_URL: "https://sms.example/send",
      MTAXI_SMS_HTTP_BEARER_TOKEN: "sms-token",
      MTAXI_SMS_HTTP_HEADERS: '{"X-Service":"mtaxi"}',
      MTAXI_SMS_MESSAGE_TEMPLATE: "Код MTaxi: {{code}}",
      MTAXI_SMS_HTTP_BODY_TEMPLATE: '{"to":"{{phone}}","text":"{{message}}"}',
    },
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      return {
        ok: true,
        status: 200,
        text: async () => '{"id":"sms-1"}',
      };
    },
  });

  assert.equal(result.ok, true);
  assert.equal(result.provider, "http");
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, "https://sms.example/send");
  assert.equal(calls[0].options.headers.Authorization, "Bearer sms-token");
  assert.equal(calls[0].options.headers["X-Service"], "mtaxi");
  assert.equal(calls[0].options.body, '{"to":"+77052597368","text":"Код MTaxi: 1234"}');
});

test("server scripts load dotenv for copied .env files", () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, "../package.json"), "utf8"));
  const indexSource = fs.readFileSync(path.join(__dirname, "../src/index.js"), "utf8");
  const preflightSource = fs.readFileSync(path.join(__dirname, "../scripts/preflight.js"), "utf8");
  const smokeSource = fs.readFileSync(path.join(__dirname, "../scripts/smoke_backend.js"), "utf8");
  const applySchemaSource = fs.readFileSync(path.join(__dirname, "../scripts/apply_schema.js"), "utf8");
  const migrateSource = fs.readFileSync(path.join(__dirname, "../scripts/migrate_json_to_postgres.js"), "utf8");

  assert.ok(pkg.dependencies.dotenv);
  assert.equal(pkg.engines.node, ">=20");
  assert.match(pkg.scripts["db:apply-schema"], /scripts\/apply_schema\.js/);
  assert.equal(pkg.scripts.smoke, "node scripts/smoke_backend.js");
  assert.match(indexSource, /^require\("dotenv"\)\.config\(\);/);
  assert.match(indexSource, /runPreflight/);
  assert.match(indexSource, /NODE_ENV === "production"/);
  assert.match(indexSource, /Startup preflight failed/);
  assert.match(preflightSource, /^require\("dotenv"\)\.config\(\);/);
  assert.match(smokeSource, /^require\("dotenv"\)\.config\(\);/);
  assert.match(preflightSource, /simulated push is allowed only outside NODE_ENV=production/);
  assert.match(preflightSource, /legacy create-token endpoint is disabled in production/);
  assert.match(applySchemaSource, /^require\("dotenv"\)\.config\(\);/);
  assert.match(applySchemaSource, /BASE_SCHEMA_VERSION = "2026-07-22-backend-base"/);
  assert.match(applySchemaSource, /SELECT version FROM schema_migrations WHERE version = \$1/);
  assert.match(applySchemaSource, /PostgreSQL schema version was not applied/);
  assert.match(migrateSource, /^require\("dotenv"\)\.config\(\);/);
});

test("production Docker files cannot silently enable development backend mode", () => {
  const rootDir = path.join(__dirname, "../..");
  const dockerfile = fs.readFileSync(path.join(rootDir, "server/Dockerfile"), "utf8");
  const productionCompose = fs.readFileSync(path.join(rootDir, "docker-compose.production.yml"), "utf8");
  const localCompose = fs.readFileSync(path.join(rootDir, "docker-compose.backend.yml"), "utf8");

  assert.match(dockerfile, /ENV NODE_ENV=production/);
  assert.match(dockerfile, /npm run db:apply-schema && npm run preflight/);
  assert.match(productionCompose, /NODE_ENV:\s*"production"/);
  assert.match(productionCompose, /MTAXI_STORE:\s*"postgres"/);
  assert.doesNotMatch(productionCompose, /\$\{MTAXI_POSTGRES_PASSWORD/);
  assert.doesNotMatch(productionCompose, /NODE_ENV:\s*"development"/);
  assert.doesNotMatch(productionCompose, /MTAXI_ALLOW_LOCAL_SMS:\s*"true"/);
  assert.doesNotMatch(productionCompose, /MTAXI_ALLOW_LOCAL_PAYMENT:\s*"true"/);
  assert.doesNotMatch(productionCompose, /MTAXI_ALLOW_SIMULATED_PUSH:\s*"true"/);
  assert.match(localCompose, /NODE_ENV:\s*"development"/);
});

test("server entrypoint exports app lifecycle for graceful shutdown", () => {
  const index = require("../src/index");
  assert.equal(typeof index.app, "function");
  assert.equal(typeof index.startProductionEntrypoint, "function");
  assert.equal(typeof index.startServer, "function");
  assert.equal(typeof index.stopServer, "function");

  let stopped = false;
  let closed = false;
  const runtime = {
    scheduler: { stop: () => { stopped = true; } },
    server: { close: (callback) => { closed = true; callback(); } },
  };
  index.stopServer(runtime, "TEST");
  assert.equal(stopped, true);
  assert.equal(closed, true);
  stopped = false;
  closed = false;
  index.stopServer(runtime, "TEST_AGAIN");
  assert.equal(stopped, false);
  assert.equal(closed, false);
});

test("server exposes liveness and readiness endpoints", async () => {
  const index = require("../src/index");
  const runtime = index.startServer({ port: 0, scheduler: null });
  try {
    await once(runtime.server, "listening");
    const { port: listenPort } = runtime.server.address();
    const baseUrl = `http://127.0.0.1:${listenPort}`;

    const live = await fetch(`${baseUrl}/livez`);
    assert.equal(live.status, 200);
    assert.match(live.headers.get("x-request-id"), /[a-zA-Z0-9._:-]{8,}/);
    const liveBody = await live.json();
    assert.equal(liveBody.ok, true);
    assert.equal(liveBody.service, "mtaxi-backend");
    assert.equal(liveBody.store, undefined);

    const ready = await fetch(`${baseUrl}/readyz`);
    assert.equal(ready.status, 200);
    const readyBody = await ready.json();
    assert.equal(readyBody.ok, true);
    assert.equal(readyBody.store.type, "json");

    const health = await fetch(`${baseUrl}/health`);
    assert.equal(health.status, 200);
    const healthBody = await health.json();
    assert.equal(healthBody.store.type, "json");
  } finally {
    index.stopServer(runtime, "TEST");
    await once(runtime.server, "close");
  }
});

test("local payment page is hidden in production unless explicitly allowed", async () => {
  const index = require("../src/index");
  const previousNodeEnv = process.env.NODE_ENV;
  const previousProvider = process.env.MTAXI_PAYMENT_PROVIDER;
  const previousAllow = process.env.MTAXI_ALLOW_LOCAL_PAYMENT;
  process.env.NODE_ENV = "production";
  process.env.MTAXI_PAYMENT_PROVIDER = "redirect";
  delete process.env.MTAXI_ALLOW_LOCAL_PAYMENT;
  const runtime = index.startServer({ port: 0, scheduler: null });
  try {
    await once(runtime.server, "listening");
    const { port: listenPort } = runtime.server.address();
    const baseUrl = `http://127.0.0.1:${listenPort}`;

    const disabled = await fetch(`${baseUrl}/local-payment/kassa24_test`);
    assert.equal(disabled.status, 404);
    const disabledBody = await disabled.json();
    assert.equal(disabledBody.code, "LOCAL_PAYMENT_DISABLED");

    process.env.MTAXI_PAYMENT_PROVIDER = "local";
    process.env.MTAXI_ALLOW_LOCAL_PAYMENT = "true";
    const enabled = await fetch(`${baseUrl}/local-payment/kassa24_test`);
    assert.equal(enabled.status, 200);
    assert.match(await enabled.text(), /Локальная оплата MTaxi/);
  } finally {
    if (previousNodeEnv == null) {
      delete process.env.NODE_ENV;
    } else {
      process.env.NODE_ENV = previousNodeEnv;
    }
    if (previousProvider == null) {
      delete process.env.MTAXI_PAYMENT_PROVIDER;
    } else {
      process.env.MTAXI_PAYMENT_PROVIDER = previousProvider;
    }
    if (previousAllow == null) {
      delete process.env.MTAXI_ALLOW_LOCAL_PAYMENT;
    } else {
      process.env.MTAXI_ALLOW_LOCAL_PAYMENT = previousAllow;
    }
    index.stopServer(runtime, "TEST");
    await once(runtime.server, "close");
  }
});

test("legacy create-token endpoint is disabled in production unless explicitly allowed", async () => {
  const index = require("../src/index");
  const previousNodeEnv = process.env.NODE_ENV;
  const previousLegacy = process.env.MTAXI_ENABLE_LEGACY_CREATE_TOKEN;
  process.env.NODE_ENV = "production";
  delete process.env.MTAXI_ENABLE_LEGACY_CREATE_TOKEN;
  const runtime = index.startServer({ port: 0, scheduler: null });
  try {
    await once(runtime.server, "listening");
    const { port: listenPort } = runtime.server.address();
    const baseUrl = `http://127.0.0.1:${listenPort}`;

    const disabled = await fetch(`${baseUrl}/create-token`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{}",
    });
    assert.equal(disabled.status, 404);
    const disabledBody = await disabled.json();
    assert.equal(disabledBody.code, "LEGACY_ENDPOINT_DISABLED");

    process.env.MTAXI_ENABLE_LEGACY_CREATE_TOKEN = "true";
    const enabled = await fetch(`${baseUrl}/create-token`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ phone: "7052597368", password: "123456" }),
    });
    assert.equal(enabled.status, 200);
    const enabledBody = await enabled.json();
    assert.equal(enabledBody.success, true);
    assert.match(enabledBody.token, /^[^.]+\.[^.]+\.[^.]+$/);
  } finally {
    if (previousNodeEnv == null) {
      delete process.env.NODE_ENV;
    } else {
      process.env.NODE_ENV = previousNodeEnv;
    }
    if (previousLegacy == null) {
      delete process.env.MTAXI_ENABLE_LEGACY_CREATE_TOKEN;
    } else {
      process.env.MTAXI_ENABLE_LEGACY_CREATE_TOKEN = previousLegacy;
    }
    index.stopServer(runtime, "TEST");
    await once(runtime.server, "close");
  }
});

test("server returns JSON errors with request ids for bad HTTP input", async () => {
  const index = require("../src/index");
  const runtime = index.startServer({ port: 0, scheduler: null });
  try {
    await once(runtime.server, "listening");
    const { port: listenPort } = runtime.server.address();
    const baseUrl = `http://127.0.0.1:${listenPort}`;

    const missing = await fetch(`${baseUrl}/missing-endpoint`, {
      headers: { "x-request-id": "req_missing_12345678" },
    });
    assert.equal(missing.status, 404);
    assert.equal(missing.headers.get("x-request-id"), "req_missing_12345678");
    const missingBody = await missing.json();
    assert.equal(missingBody.success, false);
    assert.equal(missingBody.code, "NOT_FOUND");
    assert.equal(missingBody.requestId, "req_missing_12345678");

    const badJson = await fetch(`${baseUrl}/call/getStoreHealth`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-request-id": "req_badjson_12345678",
      },
      body: "{bad",
    });
    assert.equal(badJson.status, 400);
    assert.equal(badJson.headers.get("x-request-id"), "req_badjson_12345678");
    const badJsonBody = await badJson.json();
    assert.equal(badJsonBody.success, false);
    assert.equal(badJsonBody.code, "BAD_JSON");
    assert.equal(badJsonBody.requestId, "req_badjson_12345678");
  } finally {
    index.stopServer(runtime, "TEST");
    await once(runtime.server, "close");
  }
});

test("docker deployment runs backend with PostgreSQL and production preflight", () => {
  const dockerfile = fs.readFileSync(path.join(__dirname, "../Dockerfile"), "utf8");
  const dockerignore = fs.readFileSync(path.join(__dirname, "../.dockerignore"), "utf8");
  const compose = fs.readFileSync(
    path.join(__dirname, "../../docker-compose.backend.yml"),
    "utf8",
  );
  const productionCompose = fs.readFileSync(
    path.join(__dirname, "../../docker-compose.production.yml"),
    "utf8",
  );
  const localStartScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/start_local_backend.sh"),
    "utf8",
  );
  const localJsonStartScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/start_local_json_backend.sh"),
    "utf8",
  );
  const localJsonCheckScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_local_json_backend.sh"),
    "utf8",
  );
  const localFlutterCommandsScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/print_local_flutter_commands.sh"),
    "utf8",
  );
  const localFunctionalSmokeScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_local_functional_smoke.sh"),
    "utf8",
  );
  const localFunctionalSmokeNode = fs.readFileSync(
    path.join(__dirname, "../scripts/local_functional_smoke.js"),
    "utf8",
  );
  const localStopScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/stop_local_backend.sh"),
    "utf8",
  );

  assert.match(dockerfile, /FROM node:20-bookworm-slim/);
  assert.match(dockerfile, /postgresql-client/);
  assert.match(dockerfile, /npm ci --omit=dev/);
  assert.match(dockerfile, /npm run db:apply-schema/);
  assert.match(dockerfile, /npm run preflight/);
  assert.match(dockerfile, /HEALTHCHECK/);
  assert.match(dockerfile, /\/readyz/);
  assert.match(dockerfile, /MTAXI_SEED_ADMIN_ON_START/);
  assert.match(dockerfile, /npm run seed:admin/);
  assert.match(dockerfile, /npm run start/);
  assert.ok(dockerfile.indexOf("npm run db:apply-schema") < dockerfile.indexOf("npm run preflight"));
  assert.ok(dockerfile.indexOf("npm run preflight") < dockerfile.indexOf("npm run seed:admin"));
  assert.ok(dockerfile.indexOf("npm run seed:admin") < dockerfile.indexOf("npm run start"));
  assert.match(dockerignore, /^node_modules$/m);
  assert.match(dockerignore, /^data$/m);
  const packageJson = JSON.parse(
    fs.readFileSync(path.join(__dirname, "../package.json"), "utf8"),
  );
  assert.equal(
    packageJson.scripts["preflight:production"],
    "NODE_ENV=production node scripts/preflight.js",
  );
  assert.match(compose, /postgres:16-alpine/);
  assert.match(compose, /NODE_ENV: "development"/);
  assert.match(compose, /MTAXI_STORE: "postgres"/);
  assert.match(compose, /MTAXI_SEED_ADMIN_ON_START: "true"/);
  assert.match(compose, /MTAXI_ADMIN_PHONE: "\+77000000000"/);
  assert.match(compose, /MTAXI_ADMIN_PASSWORD: "local-compose-admin-password"/);
  assert.match(compose, /DATABASE_URL: "postgres:\/\/mtaxi:mtaxi_local_compose_secret@postgres:5432\/mtaxi"/);
  assert.match(compose, /MTAXI_SMS_PROVIDER: "local"/);
  assert.match(compose, /MTAXI_ALLOW_LOCAL_SMS: "true"/);
  assert.match(compose, /MTAXI_PAYMENT_PROVIDER: "local"/);
  assert.match(compose, /MTAXI_ALLOW_LOCAL_PAYMENT: "true"/);
  assert.match(compose, /MTAXI_FCM_ENABLED: "false"/);
  assert.match(compose, /MTAXI_ALLOW_SIMULATED_PUSH: "true"/);
  assert.match(compose, /healthcheck:/);
  assert.match(compose, /\/readyz/);
  assert.match(compose, /001_schema\.sql/);
  assert.match(compose, /mtaxi_uploads/);
  assert.match(localStartScript, /docker compose "\$\{compose_files\[@\]\}" up -d --build/);
  assert.match(localStartScript, /docker compose version/);
  assert.match(localStartScript, /curl is required/);
  assert.match(localStartScript, /MTAXI_LOCAL_BACKEND_URL:-http:\/\/127\.0\.0\.1:8080/);
  assert.match(localStartScript, /base_url_port=/);
  assert.match(localStartScript, /bind_host="127\.0\.0\.1"/);
  assert.match(localStartScript, /compose_override="\$\(mktemp\)"/);
  assert.match(localStartScript, /compose_files=\(-f docker-compose\.backend\.yml -f "\$compose_override"\)/);
  assert.match(localStartScript, /"\$\{bind_host\}:\$\{base_url_port\}:8080"/);
  assert.match(localStartScript, /MTAXI_PUBLIC_BASE_URL: "\$base_url"/);
  assert.match(localStartScript, /android_base_url="\$base_url"/);
  assert.match(localStartScript, /10\.0\.2\.2/);
  assert.match(localStartScript, /curl -fsS "\$base_url\/readyz"/);
  assert.match(localStartScript, /MTAXI_SMOKE_ADMIN_PHONE=\+77000000000/);
  assert.match(localStartScript, /MTAXI_SMOKE_ADMIN_PASSWORD=local-compose-admin-password/);
  assert.match(localStartScript, /check_local_backend_contract\.sh" "\$base_url" postgres/);
  assert.match(localStartScript, /phone: \+77000000000/);
  assert.match(localStartScript, /password: local-compose-admin-password/);
  assert.match(localStartScript, /print_local_flutter_commands\.sh" "\$base_url"/);
  assert.match(localFlutterCommandsScript, /--dart-define=MTAXI_BACKEND_URL=\$base_url/);
  assert.match(localFlutterCommandsScript, /--dart-define=MTAXI_BACKEND_URL=\$android_base_url/);
  assert.doesNotMatch(localStartScript, /docker compose .* down/);
  assert.doesNotMatch(localStartScript, /db:restore/);
  assert.match(localJsonStartScript, /MTAXI_STORE=json/);
  assert.match(localJsonStartScript, /base_url_port=/);
  assert.match(localJsonStartScript, /port="\$\{PORT:-\$base_url_port\}"/);
  assert.match(localJsonStartScript, /export PORT="\$port"/);
  assert.match(localJsonStartScript, /MTAXI_SMS_PROVIDER=local/);
  assert.match(localJsonStartScript, /MTAXI_PAYMENT_PROVIDER=kassa24/);
  assert.match(localJsonStartScript, /MTAXI_ALLOW_LOCAL_PAYMENT="\$\{MTAXI_ALLOW_LOCAL_PAYMENT:-false\}"/);
  assert.match(localJsonStartScript, /MTAXI_FCM_ENABLED=false/);
  assert.match(localJsonStartScript, /npm run start &/);
  assert.match(localJsonStartScript, /curl -fsS "\$base_url\/readyz"/);
  assert.match(localJsonStartScript, /check_local_backend_contract\.sh" "\$base_url" json/);
  assert.match(localJsonStartScript, /10\.0\.2\.2/);
  assert.match(localJsonStartScript, /print_local_flutter_commands\.sh" "\$base_url"/);
  assert.match(localJsonStartScript, /Press Ctrl\+C to stop backend/);
  assert.doesNotMatch(localJsonStartScript, /docker compose/);
  assert.doesNotMatch(localJsonStartScript, /MTAXI_SMOKE_EXPECT_STORE=postgres/);
  assert.doesNotMatch(localJsonStartScript, /db:restore/);
  assert.match(localJsonCheckScript, /MTAXI_STORE=json/);
  assert.match(localJsonCheckScript, /MTAXI_LOCAL_JSON_CHECK_PORT:-59630/);
  assert.match(localJsonCheckScript, /base_url_port=/);
  assert.match(localJsonCheckScript, /port="\$\{PORT:-\$base_url_port\}"/);
  assert.match(localJsonCheckScript, /createServer\(\)/);
  assert.match(localJsonCheckScript, /listen\(0,'127\.0\.0\.1'/);
  assert.match(localJsonCheckScript, /base_url="http:\/\/127\.0\.0\.1:\$port"/);
  assert.match(localJsonCheckScript, /mktemp -d/);
  assert.match(localJsonCheckScript, /cleanup\(\)/);
  assert.match(localJsonCheckScript, /npm run start &/);
  assert.match(localJsonCheckScript, /curl -fsS "\$base_url\/readyz"/);
  assert.match(localJsonCheckScript, /check_local_backend_contract\.sh" "\$base_url" json/);
  assert.match(localJsonCheckScript, /MTaxi local JSON backend check passed/);
  assert.doesNotMatch(localJsonCheckScript, /docker compose/);
  assert.doesNotMatch(localJsonCheckScript, /MTAXI_SMOKE_EXPECT_STORE=postgres/);
  assert.doesNotMatch(localJsonCheckScript, /db:restore/);
  assert.match(localFunctionalSmokeScript, /MTAXI_STORE=json/);
  assert.match(localFunctionalSmokeScript, /mktemp -d/);
  assert.match(localFunctionalSmokeScript, /npm run smoke:functional:local/);
  assert.match(localFunctionalSmokeNode, /createPassengerOrder/);
  assert.match(localFunctionalSmokeNode, /listAvailableDriverOrders/);
  assert.match(localFunctionalSmokeNode, /acceptOrder/);
  assert.match(localFunctionalSmokeNode, /advanceDriverOrderStatus/);
  assert.match(localFunctionalSmokeNode, /createDriverTopUpPayment/);
  assert.match(localFunctionalSmokeNode, /ensureSupportChat/);
  assert.match(localFunctionalSmokeNode, /getBackendArchitectureStatus/);
  assert.match(localStopScript, /docker compose -f docker-compose\.backend\.yml down/);
  assert.match(localStopScript, /docker compose version/);
  assert.match(localStopScript, /volumes were kept/);
  assert.doesNotMatch(localStopScript, /down -v/);
  assert.doesNotMatch(localStopScript, /docker volume rm/);
  assert.doesNotMatch(localStopScript, /db:restore/);
  assert.match(productionCompose, /env_file:/);
  assert.match(productionCompose, /\.\/server\/\.env/);
  assert.match(productionCompose, /NODE_ENV: "production"/);
  assert.match(productionCompose, /MTAXI_STORE: "postgres"/);
  assert.match(productionCompose, /\/var\/backups\/mtaxi:\/var\/backups\/mtaxi/);
  assert.doesNotMatch(productionCompose, /\$\{MTAXI_POSTGRES_PASSWORD/);
  assert.doesNotMatch(productionCompose, /DATABASE_URL: "postgres:\/\/mtaxi:\$\{/);
  assert.match(productionCompose, /127\.0\.0\.1:8080:8080/);
  assert.match(productionCompose, /healthcheck:/);
  assert.match(productionCompose, /\/readyz/);
  assert.doesNotMatch(productionCompose, /MTAXI_ALLOW_LOCAL_SMS: "true"/);
  assert.doesNotMatch(productionCompose, /MTAXI_ALLOW_LOCAL_PAYMENT: "true"/);
  assert.doesNotMatch(productionCompose, /MTAXI_ALLOW_SIMULATED_PUSH: "true"/);
});

test("deployment checklist documents production backend cutover", () => {
  const checklist = fs.readFileSync(
    path.join(__dirname, "../../docs/backend_deployment_checklist.md"),
    "utf8",
  );
  const releaseBuildScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/build_backend_release.sh"),
    "utf8",
  );
  const releaseReadyScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_release_ready.sh"),
    "utf8",
  );
  const webArtifactCheckScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_web_backend_artifact.sh"),
    "utf8",
  );
  const mobileArtifactCheckScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_mobile_backend_artifact.sh"),
    "utf8",
  );
  const releaseUrlGuardScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/remote_backend_url_guard.sh"),
    "utf8",
  );
  const productionCompose = fs.readFileSync(
    path.join(__dirname, "../../docker-compose.production.yml"),
    "utf8",
  );
  const predeployScript = fs.readFileSync(
    path.join(__dirname, "../../deploy/predeploy_check.sh"),
    "utf8",
  );
  const vpsPrereqScript = fs.readFileSync(
    path.join(__dirname, "../../deploy/vps_prereq_check.sh"),
    "utf8",
  );
  const installVpsUnitsScript = fs.readFileSync(
    path.join(__dirname, "../../deploy/install_vps_units.sh"),
    "utf8",
  );
  const opsCheckScript = fs.readFileSync(
    path.join(__dirname, "../../deploy/ops_check.sh"),
    "utf8",
  );
  const sourceArchiveScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/package_source_archive.sh"),
    "utf8",
  );
  const sourceArchiveVerifyScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/verify_source_archive.sh"),
    "utf8",
  );
  const backendTransferSteps = fs.readFileSync(
    path.join(__dirname, "../../docs/backend_transfer_steps.md"),
    "utf8",
  );
  const backendTransferStepsCheckScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_backend_transfer_steps.sh"),
    "utf8",
  );
  const backendSmallStepsCheckScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_backend_migration_small_steps.sh"),
    "utf8",
  );
  const migrationReadyScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_backend_migration_ready.sh"),
    "utf8",
  );
  const quickStatusScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_backend_migration_quick_status.sh"),
    "utf8",
  );
  const localBackendContractScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_local_backend_contract.sh"),
    "utf8",
  );
  const localBackendRunbook = fs.readFileSync(
    path.join(__dirname, "../../docs/local_backend_runbook.md"),
    "utf8",
  );
  const localBackendRunbookCheckScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_local_backend_runbook.sh"),
    "utf8",
  );
  const localFlutterCommandsCheckScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_local_flutter_commands.sh"),
    "utf8",
  );
  const localFlutterCommandsScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/print_local_flutter_commands.sh"),
    "utf8",
  );
  const vpsInputsScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_vps_inputs.sh"),
    "utf8",
  );
  const clientBackendOnlyStaticScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_client_backend_only_static.sh"),
    "utf8",
  );
  const productionEnvGeneratorScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/generate_production_env.sh"),
    "utf8",
  );
  const latestVpsHandoffScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/latest_vps_handoff.sh"),
    "utf8",
  );
  const latestHandoffCurrentScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_latest_vps_handoff_current.sh"),
    "utf8",
  );
  const latestHandoffPointerScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_latest_vps_handoff_pointer.sh"),
    "utf8",
  );
  const printVpsUploadCommandsScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/print_vps_upload_commands.sh"),
    "utf8",
  );
  const vpsHandoffScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/package_vps_handoff.sh"),
    "utf8",
  );
  const vpsHandoffVerifyScript = fs.readFileSync(
    path.join(__dirname, "../../scripts/verify_vps_handoff.sh"),
    "utf8",
  );
  const readme = fs.readFileSync(path.join(__dirname, "../README.md"), "utf8");
  const envExample = fs.readFileSync(path.join(__dirname, "../.env.example"), "utf8");
  const migrationPlan = fs.readFileSync(
    path.join(__dirname, "../../docs/backend_migration_plan.md"),
    "utf8",
  );
  const migrationSmallSteps = fs.readFileSync(
    path.join(__dirname, "../../docs/backend_migration_small_steps.md"),
    "utf8",
  );
  const vpsRequiredInputs = fs.readFileSync(
    path.join(__dirname, "../../docs/vps_required_inputs.md"),
    "utf8",
  );
  const vpsInputsTemplate = fs.readFileSync(
    path.join(__dirname, "../../docs/vps_inputs.template.env"),
    "utf8",
  );
  const nginxConfig = fs.readFileSync(
    path.join(__dirname, "../../deploy/nginx/mtaxi-api.conf"),
    "utf8",
  );
  const systemdBackend = fs.readFileSync(
    path.join(__dirname, "../../deploy/systemd/mtaxi-backend.service"),
    "utf8",
  );
  const systemdBackup = fs.readFileSync(
    path.join(__dirname, "../../deploy/systemd/mtaxi-backup.service"),
    "utf8",
  );
  const systemdBackupTimer = fs.readFileSync(
    path.join(__dirname, "../../deploy/systemd/mtaxi-backup.timer"),
    "utf8",
  );
  const systemdMonitor = fs.readFileSync(
    path.join(__dirname, "../../deploy/systemd/mtaxi-monitor.service"),
    "utf8",
  );
  const systemdMonitorTimer = fs.readFileSync(
    path.join(__dirname, "../../deploy/systemd/mtaxi-monitor.timer"),
    "utf8",
  );

  assert.match(readme, /docs\/backend_deployment_checklist\.md/);
  assert.match(checklist, /docs\/vps_required_inputs\.md/);
  assert.match(checklist, /docs\/vps_inputs\.template\.env/);
  assert.match(checklist, /check_vps_inputs\.sh/);
  assert.match(checklist, /Node\.js 20 .* `npm` нужны/);
  assert.match(migrationPlan, /docs\/backend_deployment_checklist\.md/);
  assert.match(migrationPlan, /docs\/backend_migration_small_steps\.md/);
  assert.match(migrationPlan, /docs\/backend_transfer_steps\.md/);
  assert.match(migrationPlan, /локальный Docker Compose и production работают через PostgreSQL/);
  assert.doesNotMatch(migrationPlan, /позже он заменяется на PostgreSQL/);
  assert.match(migrationPlan, /Firebase в новом backend больше не используется для Auth\/DB\/Functions\/SMS\/Storage/);
  assert.match(migrationPlan, /Backend auth\/session\/order слой работает через единый store layer/);
  assert.doesNotMatch(migrationPlan, /Локально начат backend auth\/session\/order слой на JSON store/);
  assert.match(migrationPlan, /backend и админка поддерживают `complete`, `cancel`, `reopen`, `setStatus`/);
  assert.match(migrationPlan, /`getMoneyStats`, ledger, `adminListAuditLogs`, `AdminMoneyStatsWidget`/);
  assert.doesNotMatch(migrationPlan, /Готово в локальном JSON store: `auditLogs`/);
  assert.match(checklist, /MTAXI_STORE=postgres/);
  assert.match(checklist, /DATABASE_URL=postgres/);
  assert.match(checklist, /POSTGRES_PASSWORD=strong-password/);
  assert.match(checklist, /MTAXI_PUBLIC_BASE_URL=https:\/\/api\.mtaxi\.kz/);
  assert.match(checklist, /100\.64\.0\.0\/10/);
  assert.match(checklist, /169\.254\.\*/);
  assert.match(checklist, /fe80::\/10/);
  assert.match(checklist, /MTAXI_SMS_PROVIDER=http/);
  assert.match(checklist, /MTAXI_SMS_HTTP_URL=https:\/\/sms-provider\.example\/send/);
  assert.match(checklist, /MTAXI_SMS_HTTP_METHOD/);
  assert.match(checklist, /MTAXI_SMS_HTTP_BODY_TEMPLATE/);
  assert.match(checklist, /MTAXI_ALLOW_LOCAL_SMS=false/);
  assert.match(checklist, /MTAXI_FCM_ENABLED=true/);
  assert.match(checklist, /MTAXI_ALLOW_SIMULATED_PUSH=false/);
  assert.match(checklist, /MTAXI_REQUIRE_REMOTE_BACKEND=true/);
  assert.match(checklist, /check_release_ready\.sh/);
  assert.match(checklist, /build_backend_release\.sh web/);
  assert.match(checklist, /build_backend_release\.sh apk/);
  assert.match(checklist, /build_backend_release\.sh ios/);
  assert.match(checklist, /package_source_archive\.sh/);
  assert.match(checklist, /verify_source_archive\.sh/);
  assert.match(checklist, /check_backend_migration_ready\.sh/);
  assert.match(checklist, /package_vps_handoff\.sh/);
  assert.match(checklist, /HANDOFF_MANIFEST\.json/);
  assert.match(checklist, /HANDOFF_STATUS\.md/);
  assert.match(checklist, /verify_vps_handoff\.sh/);
  assert.match(checklist, /generate_production_env\.sh/);
  assert.match(checklist, /MTAXI_SEED_ADMIN_ON_START/);
  assert.match(checklist, /MTAXI_ADMIN_PHONE/);
  assert.match(checklist, /vps_prereq_check\.sh/);
  assert.match(vpsRequiredInputs, /check_backend_migration_ready\.sh/);
  assert.match(vpsRequiredInputs, /docs\/backend_migration_small_steps\.md/);
  assert.match(vpsRequiredInputs, /check_backend_migration_small_steps\.sh/);
  assert.match(vpsRequiredInputs, /check_backend_transfer_steps\.sh/);
  assert.match(vpsRequiredInputs, /docs\/vps_inputs\.template\.env/);
  assert.match(vpsInputsTemplate, /MTAXI_CORS_ORIGINS=https:\/\/mtaxi-user-vzqw6a\.web\.app,https:\/\/mtaxi-controls\.web\.app/);
  assert.match(vpsRequiredInputs, /check_vps_inputs\.sh/);
  assert.match(vpsRequiredInputs, /package_vps_handoff\.sh/);
  assert.match(vpsRequiredInputs, /check_output_handoffs\.sh/);
  assert.match(vpsRequiredInputs, /verify_vps_handoff\.sh output\/mtaxi-vps-handoff-YYYYMMDD-HHMMSS/);
  assert.match(vpsRequiredInputs, /print_vps_upload_commands\.sh/);
  assert.match(vpsRequiredInputs, /HANDOFF_MANIFEST\.json/);
  assert.match(vpsRequiredInputs, /HANDOFF_STATUS\.md/);
  assert.match(vpsRequiredInputs, /HANDOFF_QUICK_COMMANDS\.md/);
  assert.match(vpsRequiredInputs, /короткого copy-paste сценария/);
  assert.match(vpsRequiredInputs, /Node\.js 20\+ и `npm`/);
  assert.match(vpsRequiredInputs, /chmod \+x verify_vps_handoff\.sh/);
  assert.match(vpsRequiredInputs, /shasum -a 256 -c mtaxi-source-\*\.tar\.gz\.sha256/);
  assert.match(vpsRequiredInputs, /\.\/verify_vps_handoff\.sh \./);
  assert.match(vpsRequiredInputs, /sudo mkdir -p \/opt\/mtaxi/);
  assert.match(vpsRequiredInputs, /sudo tar -xzf mtaxi-source-\*\.tar\.gz -C \/opt\/mtaxi/);
  assert.match(vpsRequiredInputs, /cd \/opt\/mtaxi/);
  assert.match(vpsRequiredInputs, /\.\/scripts\/check_vps_postdeploy\.sh/);
  assert.match(vpsRequiredInputs, /MTAXI_PUBLIC_BASE_URL.*server\/\.env/);
  assert.match(vpsRequiredInputs, /PostgreSQL store/);
  assert.match(vpsRequiredInputs, /Firebase .*FCM push/);
  assert.match(releaseBuildScript, /MTAXI_BACKEND_URL/);
  assert.match(releaseBuildScript, /MTAXI_REQUIRE_REMOTE_BACKEND=true/);
  assert.match(releaseBuildScript, /check_release_ready\.sh/);
  assert.match(releaseBuildScript, /remote_backend_url_guard\.sh/);
  assert.match(releaseBuildScript, /mtaxi_validate_remote_backend_url/);
  assert.match(releaseBuildScript, /MTAXI_BACKEND_URL="\$api_url"/);
  assert.match(releaseBuildScript, /flutter_bin.*build web --release/);
  assert.match(releaseBuildScript, /check_web_backend_artifact\.sh/);
  assert.match(releaseBuildScript, /flutter_bin.*build apk --release/);
  assert.match(releaseBuildScript, /check_mobile_backend_artifact\.sh" apk/);
  assert.match(releaseBuildScript, /flutter_bin.*build ipa --release/);
  assert.match(releaseBuildScript, /check_mobile_backend_artifact\.sh" ios/);
  assert.match(releaseReadyScript, /MTAXI_BACKEND_URL/);
  assert.match(releaseReadyScript, /remote_backend_url_guard\.sh/);
  assert.match(releaseReadyScript, /mtaxi_validate_remote_backend_url/);
  assert.match(releaseReadyScript, /check_firebase_fcm_only\.sh/);
  assert.match(releaseReadyScript, /check_client_backend_only_static\.sh/);
  assert.match(clientBackendOnlyStaticScript, /firebase_messaging import must stay scoped to push notifications/);
  assert.match(clientBackendOnlyStaticScript, /firebase_core import must stay scoped to Firebase init/);
  assert.match(clientBackendOnlyStaticScript, /lib\/backend\/push_notifications\/\*\.dart/);
  assert.match(clientBackendOnlyStaticScript, /lib\/backend\/firebase\/firebase_config\.dart/);
  assert.match(releaseUrlGuardScript, /https:\/\/\*/);
  assert.match(releaseUrlGuardScript, /MTAXI_BACKEND_URL must be an external https:\/\/ backend URL/);
  assert.match(releaseUrlGuardScript, /MTAXI_BACKEND_URL must not point to localhost, emulator or LAN/);
  assert.match(releaseUrlGuardScript, /10\.\*/);
  assert.match(releaseUrlGuardScript, /100 64 127/);
  assert.match(releaseUrlGuardScript, /169\.254\.\*/);
  assert.match(releaseUrlGuardScript, /fe8\*/);
  assert.match(releaseUrlGuardScript, /192\.168\.\*/);
  assert.match(releaseReadyScript, /Flutter SDK not found/);
  assert.match(releaseReadyScript, /command -v "\$flutter_bin"/);
  assert.ok(
    releaseReadyScript.indexOf('mtaxi_validate_remote_backend_url "$api_url"') <
      releaseReadyScript.indexOf('command -v "$flutter_bin"'),
    "release readiness must validate backend URL before checking local Flutter SDK",
  );
  assert.match(releaseReadyScript, /MTAXI_SMOKE_BASE_URL="\$api_url"/);
  assert.match(releaseReadyScript, /MTAXI_SMOKE_EXPECT_STORE=postgres/);
  assert.match(releaseReadyScript, /npm run smoke/);
  assert.match(releaseReadyScript, /test\/backend_only_guard_test\.dart/);
  assert.doesNotMatch(releaseReadyScript, /build apk --release/);
  assert.doesNotMatch(releaseReadyScript, /build web --release/);
  assert.doesNotMatch(releaseReadyScript, /build ipa --release/);
  assert.match(webArtifactCheckScript, /main\.dart\.js/);
  assert.match(webArtifactCheckScript, /expected MTAXI_BACKEND_URL is missing/);
  assert.match(webArtifactCheckScript, /web artifact contains local backend URL/);
  assert.match(webArtifactCheckScript, /localhost\|127/);
  assert.match(webArtifactCheckScript, /100\\\.\(6\[4-9\]/);
  assert.match(webArtifactCheckScript, /192\\\.168/);
  assert.match(mobileArtifactCheckScript, /app-release\.apk/);
  assert.match(mobileArtifactCheckScript, /build\/ios\/ipa/);
  assert.match(mobileArtifactCheckScript, /unzip -Z1/);
  assert.match(mobileArtifactCheckScript, /strings -a/);
  assert.match(mobileArtifactCheckScript, /expected MTAXI_BACKEND_URL is missing/);
  assert.match(mobileArtifactCheckScript, /mobile artifact contains local backend URL/);
  assert.match(mobileArtifactCheckScript, /100\\\.\(6\[4-9\]/);
  assert.match(mobileArtifactCheckScript, /192\\\.168/);
  assert.match(sourceArchiveScript, /MTAXI_SOURCE_ARCHIVE_MAX_MB:-500/);
  assert.match(sourceArchiveScript, /tar -czf/);
  assert.match(sourceArchiveScript, /--exclude='server\/\.env'/);
  assert.match(sourceArchiveScript, /--exclude='server\/\.env\.generated'/);
  assert.match(sourceArchiveScript, /--exclude='server\/node_modules'/);
  assert.match(sourceArchiveScript, /--exclude='ios\/Pods'/);
  assert.match(sourceArchiveScript, /--exclude='private_keys'/);
  assert.match(sourceArchiveScript, /--exclude='firebase'/);
  assert.match(sourceArchiveScript, /--exclude='firebase\.json'/);
  assert.match(sourceArchiveScript, /--exclude='\.firebaserc'/);
  assert.match(sourceArchiveScript, /--exclude='firestore\.rules'/);
  assert.match(sourceArchiveScript, /--exclude='storage\.rules'/);
  assert.match(sourceArchiveScript, /archive exceeds/);
  assert.match(sourceArchiveScript, /verify_source_archive\.sh/);
  assert.match(sourceArchiveScript, /shasum -a 256 "\$\(basename "\$archive_path"\)"/);
  assert.match(sourceArchiveScript, /Checksum: \$archive_path\.sha256/);
  assert.match(sourceArchiveVerifyScript, /cd "\$\(dirname "\$archive_path"\)"/);
  assert.match(sourceArchiveVerifyScript, /shasum -a 256 -c "\$\(basename "\$archive_path"\)\.sha256"/);
  assert.match(sourceArchiveVerifyScript, /server\/package\.json/);
  assert.match(sourceArchiveVerifyScript, /server\/db\/schema\.sql/);
  assert.match(sourceArchiveVerifyScript, /server\/scripts\/export_api_contract\.js/);
  assert.match(sourceArchiveVerifyScript, /server\/scripts\/export_env_contract\.js/);
  assert.match(sourceArchiveVerifyScript, /docker-compose\.production\.yml/);
  assert.match(sourceArchiveVerifyScript, /deploy\/vps_prereq_check\.sh/);
  assert.match(sourceArchiveVerifyScript, /docs\/vps_required_inputs\.md/);
  assert.match(sourceArchiveVerifyScript, /docs\/vps_inputs\.template\.env/);
  assert.match(sourceArchiveVerifyScript, /docs\/backend_migration_small_steps\.md/);
  assert.match(sourceArchiveVerifyScript, /docs\/backend_transfer_steps\.md/);
  assert.match(sourceArchiveVerifyScript, /docs\/local_backend_runbook\.md/);
  assert.match(sourceArchiveVerifyScript, /docs\/vps_cutover_runbook\.md/);
  assert.match(sourceArchiveVerifyScript, /scripts\/build_backend_release\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_backend_api_contract\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_backend_env_contract\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_backend_migration_ready\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_backend_migration_small_steps\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_backend_transfer_steps\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_vps_cutover_runbook\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_client_backend_config\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_client_backend_only_static\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_firebase_fcm_only\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_local_flutter_commands\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_local_app_backend_wiring\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_local_backend_runbook\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_local_functional_smoke\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_latest_vps_handoff_current\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_latest_vps_handoff_pointer\.sh/);
  assert.match(sourceArchiveVerifyScript, /server\/scripts\/local_functional_smoke\.js/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_output_handoffs\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/cleanup_output_handoffs\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_local_backend_contract\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_vps_inputs\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_local_json_backend\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_shell_script_permissions\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_vps_cutover_dry_run\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/check_vps_handoff_extract_smoke\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/generate_production_env\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/latest_vps_handoff\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/package_vps_handoff\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/print_local_flutter_commands\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/print_vps_upload_commands\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/remote_backend_url_guard\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/start_local_backend\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/start_local_json_backend\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/verify_vps_handoff\.sh/);
  assert.match(sourceArchiveVerifyScript, /scripts\/verify_backend_migration_status\.sh/);
  assert.match(sourceArchiveVerifyScript, /lib\/backend\/backend_session\.dart/);
  assert.match(sourceArchiveVerifyScript, /\^server\/node_modules\//);
  assert.match(latestHandoffCurrentScript, /server\/test/);
  assert.match(sourceArchiveVerifyScript, /\^server\/\\.env\$/);
  assert.match(sourceArchiveVerifyScript, /\^server\/\\.env\\\.generated\$/);
  assert.match(sourceArchiveVerifyScript, /\^private_keys\//);
  assert.match(sourceArchiveVerifyScript, /archive exceeds/);
  assert.match(sourceArchiveVerifyScript, /shasum -a 256 -c "\$\(basename "\$archive_path"\)\.sha256"/);
  assert.match(sourceArchiveVerifyScript, /sha256 checksum mismatch/);
  assert.match(latestHandoffPointerScript, /LATEST_MTAXI_VPS_HANDOFF\.txt/);
  assert.match(latestHandoffPointerScript, /pointer path is stale/);
  assert.match(latestHandoffPointerScript, /check_latest_vps_handoff_current\.sh/);
  assert.match(migrationReadyScript, /cd "\$root_dir\/server" && npm test/);
  assert.match(migrationReadyScript, /bash -n/);
  assert.match(migrationReadyScript, /check_shell_script_permissions\.sh/);
  assert.match(migrationReadyScript, /check_latest_vps_handoff_current\.sh/);
  assert.match(migrationReadyScript, /check_latest_vps_handoff_pointer\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: shell script permissions/);
  assert.match(migrationReadyScript, /check_client_backend_only_static\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: client backend-only static check/);
  assert.match(migrationReadyScript, /check_client_backend_config\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: client backend config/);
  assert.match(migrationReadyScript, /check_backend_api_contract\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: backend API contract/);
  assert.match(migrationReadyScript, /check_backend_env_contract\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: backend env contract/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: backend migration status report/);
  assert.match(migrationReadyScript, /backend_migration_status\.sh/);
  assert.match(migrationReadyScript, /verify_backend_migration_status\.sh/);
  assert.match(migrationReadyScript, /check_backend_transfer_steps\.sh/);
  assert.match(migrationReadyScript, /cleanup_output_handoffs\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: backend transfer steps/);
  assert.match(migrationReadyScript, /check_backend_migration_small_steps\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: backend migration small steps/);
  assert.match(migrationReadyScript, /check_vps_cutover_runbook\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: VPS cutover runbook/);
  assert.match(backendTransferStepsCheckScript, /check_local_backend_contract\.sh http:\/\/127\.0\.0\.1:8080/);
  assert.match(migrationReadyScript, /check_firebase_fcm_only\.sh/);
  assert.match(migrationReadyScript, /check_local_flutter_commands\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: local Flutter commands/);
  assert.match(migrationReadyScript, /check_local_app_backend_wiring\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: local app backend wiring/);
  assert.match(migrationReadyScript, /check_local_backend_runbook\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: local backend runbook/);
  assert.match(migrationReadyScript, /check_local_functional_smoke\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: local functional smoke/);
  assert.match(migrationReadyScript, /check_output_handoffs\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: output handoff inventory/);
  assert.match(migrationReadyScript, /check_local_backend_contract\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: Firebase FCM-only guard/);
  assert.match(migrationReadyScript, /check_backend_migration_quick_status\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: quick backend status/);
  assert.match(quickStatusScript, /MTAXI_QUICK_STATUS_REQUIRE_HANDOFF:-false/);
  assert.match(quickStatusScript, /latest_vps_handoff\.sh/);
  assert.match(quickStatusScript, /check_latest_vps_handoff_current\.sh/);
  assert.match(quickStatusScript, /check_latest_vps_handoff_pointer\.sh/);
  assert.match(quickStatusScript, /no verified output handoff yet/);
  assert.match(quickStatusScript, /run \.\/scripts\/package_vps_handoff\.sh/);
  assert.match(migrationReadyScript, /check_local_json_backend\.sh/);
  assert.match(migrationReadyScript, /check_vps_inputs\.sh/);
  assert.doesNotMatch(migrationReadyScript, /MTaxi migration readiness: VPS inputs/);
  assert.match(vpsInputsScript, /MTAXI_VPS_HOST/);
  assert.match(vpsInputsScript, /MTAXI_DNS_READY/);
  assert.match(vpsInputsScript, /MTAXI_HTTPS_READY/);
  assert.match(vpsInputsScript, /MTAXI_PAYMENT_URL_TEMPLATE must contain/);
  assert.match(vpsInputsScript, /FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS is required/);
  assert.match(vpsInputsScript, /MTAXI_ADMIN_PASSWORD must be at least 6 characters/);
  assert.match(migrationReadyScript, /"\$root_dir\/scripts\/check_local_json_backend\.sh"/);
  assert.match(migrationReadyScript, /"\$root_dir\/scripts\/check_local_functional_smoke\.sh"/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: local functional smoke/);
  assert.match(migrationReadyScript, /package_source_archive\.sh/);
  assert.match(migrationReadyScript, /package_vps_handoff\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: VPS handoff package/);
  assert.match(migrationReadyScript, /MTAXI_VPS_HANDOFF_SKIP_READY=true/);
  assert.match(migrationReadyScript, /"\$tmp_dir\/vps-handoff"/);
  assert.match(migrationReadyScript, /generate_production_env\.sh/);
  assert.match(migrationReadyScript, /latest_vps_handoff\.sh/);
  assert.match(migrationReadyScript, /print_local_flutter_commands\.sh/);
  assert.match(migrationReadyScript, /print_vps_upload_commands\.sh/);
  assert.match(printVpsUploadCommandsScript, /check_latest_vps_handoff_current\.sh" "\$handoff_dir"/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: VPS upload commands/);
  assert.match(migrationReadyScript, /check_vps_handoff_extract_smoke\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: VPS handoff extract smoke/);
  assert.match(migrationReadyScript, /check_vps_cutover_dry_run\.sh/);
  assert.match(migrationReadyScript, /MTaxi migration readiness: VPS cutover dry-run/);
  assert.match(migrationReadyScript, /start_local_json_backend\.sh/);
  assert.match(backendTransferSteps, /scripts\/start_local_backend\.sh/);
  assert.match(backendTransferSteps, /docs\/backend_migration_small_steps\.md/);
  assert.match(backendTransferSteps, /scripts\/check_backend_migration_small_steps\.sh/);
  assert.match(backendTransferSteps, /scripts\/latest_vps_handoff\.sh/);
  assert.match(backendTransferSteps, /scripts\/check_output_handoffs\.sh/);
  assert.match(backendTransferSteps, /scripts\/print_vps_upload_commands\.sh/);
  assert.match(backendTransferSteps, /scripts\/check_vps_handoff_extract_smoke\.sh/);
  assert.match(backendTransferSteps, /scripts\/check_vps_cutover_dry_run\.sh/);
  assert.match(backendTransferSteps, /scripts\/check_vps_cutover_runbook\.sh/);
  assert.match(backendTransferSteps, /scripts\/start_local_json_backend\.sh/);
  assert.match(backendTransferSteps, /scripts\/stop_local_backend\.sh/);
  assert.match(backendTransferSteps, /docker compose down -v/);
  assert.match(backendTransferSteps, /scripts\/print_local_flutter_commands\.sh http:\/\/127\.0\.0\.1:8080/);
  assert.match(backendTransferSteps, /scripts\/check_local_backend_contract\.sh http:\/\/127\.0\.0\.1:8080/);
  assert.match(backendTransferSteps, /MTAXI_BACKEND_URL=http:\/\/127\.0\.0\.1:8080/);
  assert.match(backendTransferSteps, /MTAXI_BACKEND_URL=http:\/\/10\.0\.2\.2:8080/);
  assert.match(backendTransferSteps, /MTAXI_REQUIRE_REMOTE_BACKEND=true/);
  assert.match(backendTransferSteps, /dev\/simulated/);
  assert.match(backendTransferStepsCheckScript, /docs\/backend_transfer_steps\.md/);
  assert.match(backendTransferStepsCheckScript, /docs\/backend_migration_small_steps\.md/);
  assert.match(backendTransferStepsCheckScript, /scripts\/check_backend_migration_small_steps\.sh/);
  assert.match(backendSmallStepsCheckScript, /docs\/backend_migration_small_steps\.md/);
  assert.match(backendSmallStepsCheckScript, /scripts\/check_local_backend_runbook\.sh/);
  assert.match(backendSmallStepsCheckScript, /Firebase разрешен только для FCM push/);
  assert.match(backendSmallStepsCheckScript, /MTAXI_BACKEND_URL=http:\/\/10\.0\.2\.2:8080/);
  assert.match(backendTransferStepsCheckScript, /scripts\/check_vps_cutover_runbook\.sh/);
  assert.match(backendTransferStepsCheckScript, /scripts\/latest_vps_handoff\.sh/);
  assert.match(backendTransferStepsCheckScript, /Firebase остается только для FCM push-уведомлений/);
  assert.match(backendTransferStepsCheckScript, /MTAXI_BACKEND_URL=http:\/\/10\.0\.2\.2:8080/);
  assert.match(backendTransferStepsCheckScript, /sudo tar -xzf mtaxi-source-\*\.tar\.gz -C \/opt\/mtaxi/);
  assert.match(backendTransferStepsCheckScript, /MTAXI_BACKEND_URL=https:\/\/api\.mtaxi\.kz .*build_backend_release\.sh apk/);
  assert.match(migrationSmallSteps, /Firebase разрешен только для FCM push/);
  assert.match(migrationSmallSteps, /Firebase Auth не использовать/);
  assert.match(migrationSmallSteps, /Firestore не использовать/);
  assert.match(migrationSmallSteps, /scripts\/check_backend_migration_ready\.sh/);
  assert.match(migrationSmallSteps, /scripts\/check_local_functional_smoke\.sh/);
  assert.match(migrationSmallSteps, /scripts\/check_vps_cutover_dry_run\.sh/);
  assert.match(migrationSmallSteps, /scripts\/check_vps_postdeploy\.sh/);
  assert.match(migrationSmallSteps, /MTAXI_BACKEND_URL=http:\/\/127\.0\.0\.1:8080/);
  assert.match(migrationSmallSteps, /MTAXI_BACKEND_URL=http:\/\/10\.0\.2\.2:8080/);
  assert.match(migrationSmallSteps, /Финальные 100% ставить только после реального VPS/);
  assert.match(localBackendRunbook, /Firebase в этом режиме разрешен только для FCM push/);
  assert.match(localBackendRunbook, /scripts\/check_backend_migration_quick_status\.sh/);
  assert.match(localBackendRunbook, /scripts\/start_local_backend\.sh/);
  assert.match(localBackendRunbook, /scripts\/start_local_json_backend\.sh/);
  assert.match(localBackendRunbook, /scripts\/check_local_backend_contract\.sh http:\/\/127\.0\.0\.1:8080/);
  assert.match(localBackendRunbook, /MTAXI_BACKEND_URL=http:\/\/127\.0\.0\.1:8080/);
  assert.match(localBackendRunbook, /MTAXI_BACKEND_URL=http:\/\/10\.0\.2\.2:8080/);
  assert.match(localBackendRunbook, /Восстановление активного заказа после обновления страницы/);
  assert.match(localBackendRunbookCheckScript, /docs\/local_backend_runbook\.md/);
  assert.match(localBackendRunbookCheckScript, /docker compose down -v/);
  assert.match(migrationReadyScript, /MTAXI_SOURCE_ARCHIVE_DIR="\$tmp_dir"/);
  assert.match(localBackendContractScript, /MTAXI_SMOKE_BASE_URL="\$base_url"/);
  assert.match(localBackendContractScript, /MTAXI_SMOKE_EXPECT_STORE="\$expected_store"/);
  assert.match(localBackendContractScript, /npm run smoke/);
  assert.match(localBackendContractScript, /expected store must be json or postgres/);
  assert.match(localFlutterCommandsScript, /MTAXI_LOCAL_BACKEND_URL:-\$\{1:-http:\/\/127\.0\.0\.1:8080\}/);
  assert.match(localFlutterCommandsScript, /10\.0\.2\.2/);
  assert.match(localFlutterCommandsScript, /check_local_backend_contract\.sh \$base_url/);
  assert.match(localFlutterCommandsScript, /flutter run -d chrome --dart-define=MTAXI_BACKEND_URL=\$base_url/);
  assert.match(localFlutterCommandsScript, /flutter run -d emulator --dart-define=MTAXI_BACKEND_URL=\$android_base_url/);
  assert.match(productionEnvGeneratorScript, /openssl rand -hex/);
  assert.match(productionEnvGeneratorScript, /mtaxi_validate_remote_backend_url "\$MTAXI_PUBLIC_BASE_URL"/);
  assert.match(productionEnvGeneratorScript, /MTAXI_PAYMENT_URL_TEMPLATE must contain/);
  assert.match(productionEnvGeneratorScript, /FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS is required/);
  assert.match(productionEnvGeneratorScript, /while IFS= read -r line/);
  assert.equal(productionEnvGeneratorScript.includes("  sed \\"), false);
  assert.match(productionEnvGeneratorScript, /DATABASE_URL=postgres:\/\/mtaxi:%s@postgres:5432\/mtaxi/);
  assert.match(productionEnvGeneratorScript, /server\/\.env\.generated/);
  assert.match(latestVpsHandoffScript, /mtaxi-vps-handoff-\*/);
  assert.match(latestVpsHandoffScript, /verify_vps_handoff\.sh/);
  assert.match(latestVpsHandoffScript, /Skipping broken MTaxi VPS handoff/);
  assert.match(latestVpsHandoffScript, /Latest verified MTaxi VPS handoff/);
  assert.match(latestVpsHandoffScript, /Source archive:/);
  assert.match(localFlutterCommandsCheckScript, /print_local_flutter_commands\.sh/);
  assert.match(localFlutterCommandsCheckScript, /http:\/\/127\.0\.0\.1:8080/);
  assert.match(localFlutterCommandsCheckScript, /http:\/\/localhost:8080/);
  assert.match(localFlutterCommandsCheckScript, /http:\/\/10\.0\.2\.2:8080/);
  assert.match(clientBackendOnlyStaticScript, /cloud_firestore/);
  assert.match(clientBackendOnlyStaticScript, /firebase_auth/);
  assert.match(clientBackendOnlyStaticScript, /firebase_storage/);
  assert.match(clientBackendOnlyStaticScript, /GeneratedPluginRegistrant/);
  assert.match(clientBackendOnlyStaticScript, /Podfile\.lock/);
  assert.match(clientBackendOnlyStaticScript, /android\/app\/google-services\.json/);
  assert.match(clientBackendOnlyStaticScript, /Firebase native config must stay FCM-only/);
  assert.match(clientBackendOnlyStaticScript, /\.snapshots\(\)/);
  assert.match(clientBackendOnlyStaticScript, /\.count\(\)/);
  assert.match(clientBackendOnlyStaticScript, /ref\\\.\(snapshots\|get\)/);
  assert.match(clientBackendOnlyStaticScript, /reference\.set\(/);
  assert.match(clientBackendOnlyStaticScript, /reference\.delete\(\)/);
  assert.match(vpsHandoffScript, /check_backend_migration_ready\.sh/);
  assert.match(vpsHandoffScript, /MTAXI_VPS_HANDOFF_SKIP_READY/);
  assert.match(vpsHandoffScript, /generate_production_env\.sh/);
  assert.match(vpsHandoffScript, /package_source_archive\.sh/);
  assert.match(vpsHandoffScript, /verify_vps_handoff\.sh/);
  assert.match(vpsHandoffScript, /DEPLOY_NEXT_STEPS\.md/);
  assert.match(vpsHandoffScript, /deploy\/vps_prereq_check\.sh/);
  assert.match(vpsHandoffScript, /shasum -a 256 -c/);
  assert.match(vpsHandoffScript, /deploy\/predeploy_check\.sh/);
  assert.match(vpsHandoffScript, /mtaxi-backend\.service/);
  assert.doesNotMatch(vpsHandoffVerifyScript, /node -e/);
  assert.doesNotMatch(vpsHandoffVerifyScript, /\bnode\s+[-"']/);
  assert.match(vpsHandoffVerifyScript, /awk -v key/);
  assert.match(vpsHandoffVerifyScript, /for required_command in awk basename find grep shasum wc/);
  assert.match(vpsHandoffVerifyScript, /command -v "\$required_command"/);
  assert.match(predeployScript, /deploy\/vps_prereq_check\.sh/);
  assert.match(predeployScript, /npm ci --omit=dev/);
  assert.match(predeployScript, /\.\/scripts\/check_backend_env_contract\.sh/);
  assert.match(predeployScript, /npm run validate:production-deploy/);
  assert.ok(
    predeployScript.indexOf("./deploy/vps_prereq_check.sh") <
      predeployScript.indexOf("npm ci --omit=dev"),
    "predeploy must check VPS prerequisites before installing dependencies",
  );
  assert.ok(
    predeployScript.indexOf("npm ci --omit=dev") <
      predeployScript.indexOf("./scripts/check_backend_env_contract.sh"),
    "predeploy must install production dependencies before env contract validation",
  );
  assert.ok(
    predeployScript.indexOf("./scripts/check_backend_env_contract.sh") <
      predeployScript.indexOf("npm run validate:production-deploy"),
    "predeploy must check env contract before production validation",
  );
  assert.match(vpsPrereqScript, /docker compose version/);
  assert.match(vpsPrereqScript, /systemctl list-unit-files/);
  assert.match(vpsPrereqScript, /command -v node/);
  assert.match(vpsPrereqScript, /command -v npm/);
  assert.match(vpsPrereqScript, /major >= 20/);
  assert.match(vpsPrereqScript, /MTAXI_MIN_FREE_DISK_GB:-10/);
  assert.match(vpsPrereqScript, /ports 80\/443 already have listeners/);
  assert.doesNotMatch(vpsPrereqScript, /systemctl enable/);
  assert.doesNotMatch(vpsPrereqScript, /docker compose .* up/);
  assert.match(envExample, /MTAXI_STORE=postgres/);
  assert.match(envExample, /POSTGRES_PASSWORD=replace-with-postgres-password/);
  assert.match(envExample, /DATABASE_URL=postgres:\/\/mtaxi:replace-with-postgres-password@postgres:5432\/mtaxi/);
  assert.match(envExample, /MTAXI_BACKUP_RETENTION_DAYS=30/);
  assert.match(envExample, /MTAXI_MAINTENANCE_INTERVAL_SEC=30/);
  assert.match(envExample, /MTAXI_SMS_PROVIDER=http/);
  assert.match(envExample, /MTAXI_SMS_HTTP_URL=https:\/\/sms-provider\.example\/send/);
  assert.match(envExample, /MTAXI_ALLOW_LOCAL_SMS=false/);
  assert.match(envExample, /MTAXI_PAYMENT_PROVIDER=redirect/);
  assert.match(envExample, /MTAXI_PAYMENT_URL_TEMPLATE=https:\/\/pay-provider\.example\/start\?invoice=\{\{paymentId\}\}&amount=\{\{amount\}\}/);
  assert.match(envExample, /MTAXI_ALLOW_LOCAL_PAYMENT=false/);
  assert.match(envExample, /MTAXI_FCM_ENABLED=true/);
  assert.match(envExample, /MTAXI_ALLOW_SIMULATED_PUSH=false/);
  assert.match(checklist, /docker compose -f docker-compose\.backend\.yml up -d --build/);
  assert.match(checklist, /sudo \.\/deploy\/install_vps_units\.sh/);
  assert.match(checklist, /deploy\/systemd\/mtaxi-backend\.service/);
  assert.match(checklist, /systemctl enable --now mtaxi-backend\.service/);
  assert.match(checklist, /systemctl enable --now mtaxi-backup\.timer/);
  assert.match(checklist, /systemctl enable --now mtaxi-monitor\.timer/);
  assert.match(checklist, /\.\/deploy\/ops_check\.sh/);
  assert.match(checklist, /npm run db:apply-schema/);
  assert.match(checklist, /npm run preflight/);
  assert.match(checklist, /npm run validate:production-deploy/);
  assert.match(checklist, /\.\/deploy\/predeploy_check\.sh/);
  assert.match(checklist, /scripts\/check_release_ready\.sh/);
  assert.match(checklist, /scripts\/build_backend_release\.sh/);
  assert.match(checklist, /scripts\/check_vps_postdeploy\.sh/);
  assert.match(checklist, /npm run preflight:production/);
  assert.match(checklist, /npm run seed:admin/);
  assert.match(checklist, /npm run db:migrate-json/);
  assert.match(checklist, /users=\.\.\., orders=\.\.\., payments=\.\.\./);
  assert.match(checklist, /npm run db:backup/);
  assert.match(checklist, /docker compose -f docker-compose\.production\.yml exec -T/);
  assert.match(checklist, /docker compose -f docker-compose\.production\.yml run --rm/);
  assert.match(checklist, /MTAXI_RESTORE_DRY_RUN=true/);
  assert.match(checklist, /MTAXI_RESTORE_CONFIRM=YES/);
  assert.match(checklist, /npm run db:restore/);
  assert.match(checklist, /npm run smoke/);
  assert.match(checklist, /curl http:\/\/127\.0\.0\.1:8080\/readyz/);
  assert.match(checklist, /Firebase остается только для FCM push/);
  assert.match(checklist, /deploy\/nginx\/mtaxi-api\.conf/);
  assert.match(productionCompose, /\/var\/backups\/mtaxi:\/var\/backups\/mtaxi/);
  assert.match(predeployScript, /server\/\.env/);
  assert.match(predeployScript, /docker-compose\.production\.yml/);
  assert.match(predeployScript, /deploy\/nginx\/mtaxi-api\.conf/);
  assert.match(predeployScript, /deploy\/install_vps_units\.sh/);
  assert.match(predeployScript, /deploy\/ops_check\.sh/);
  assert.match(predeployScript, /scripts\/check_release_ready\.sh/);
  assert.match(predeployScript, /scripts\/build_backend_release\.sh/);
  assert.match(predeployScript, /scripts\/check_vps_postdeploy\.sh/);
  assert.match(predeployScript, /scripts\/check_backend_transfer_steps\.sh/);
  assert.match(predeployScript, /scripts\/check_local_flutter_commands\.sh/);
  assert.match(predeployScript, /scripts\/check_backend_env_contract\.sh/);
  assert.match(predeployScript, /required script is not executable/);
  assert.match(predeployScript, /deploy\/systemd\/mtaxi-backend\.service/);
  assert.match(predeployScript, /deploy\/systemd\/mtaxi-backup\.service/);
  assert.match(predeployScript, /deploy\/systemd\/mtaxi-backup\.timer/);
  assert.match(predeployScript, /deploy\/systemd\/mtaxi-monitor\.service/);
  assert.match(predeployScript, /deploy\/systemd\/mtaxi-monitor\.timer/);
  assert.match(predeployScript, /npm run validate:production-deploy/);
  assert.match(predeployScript, /server\/scripts\/backup_backend\.js/);
  assert.match(predeployScript, /server\/scripts\/restore_backend\.js/);
  assert.match(predeployScript, /server\/scripts\/export_env_contract\.js/);
  assert.match(predeployScript, /server\/\.env must not set NODE_ENV to non-production value/);
  assert.match(predeployScript, /\.\/scripts\/check_backend_transfer_steps\.sh/);
  assert.match(predeployScript, /\.\/scripts\/check_local_flutter_commands\.sh/);
  assert.ok(
    predeployScript.indexOf("./scripts/check_local_flutter_commands.sh") <
      predeployScript.indexOf("npm ci --omit=dev"),
    "predeploy must verify local transfer helpers before production validation",
  );
  assert.match(predeployScript, /docker compose -f docker-compose\.production\.yml config/);
  assert.match(predeployScript, /nginx -t/);
  assert.match(nginxConfig, /server_name api\.mtaxi\.kz/);
  assert.match(nginxConfig, /return 301 https:\/\/\$host\$request_uri/);
  assert.match(nginxConfig, /proxy_pass http:\/\/127\.0\.0\.1:8080/);
  assert.match(nginxConfig, /proxy_set_header Host \$host/);
  assert.match(nginxConfig, /proxy_set_header X-Forwarded-Proto https/);
  assert.match(nginxConfig, /proxy_set_header X-Forwarded-Host \$host/);
  assert.match(nginxConfig, /proxy_set_header X-Request-Id \$request_id/);
  assert.match(nginxConfig, /client_max_body_size 25m/);
  assert.match(installVpsUnitsScript, /MTAXI_INSTALL_DIR:-\/opt\/mtaxi/);
  assert.match(installVpsUnitsScript, /MTAXI_SYSTEMD_DIR:-\/etc\/systemd\/system/);
  assert.match(installVpsUnitsScript, /MTAXI_NGINX_AVAILABLE_DIR:-\/etc\/nginx\/sites-available/);
  assert.match(installVpsUnitsScript, /MTAXI_BACKUP_DIR:-\/var\/backups\/mtaxi/);
  assert.match(installVpsUnitsScript, /service templates use \/opt\/mtaxi/);
  assert.match(installVpsUnitsScript, /install -d -m 0750 "\$backup_dir"/);
  assert.match(installVpsUnitsScript, /install -m 0644 .*mtaxi-backend\.service/);
  assert.match(installVpsUnitsScript, /install -m 0644 .*mtaxi-backup\.service/);
  assert.match(installVpsUnitsScript, /install -m 0644 .*mtaxi-backup\.timer/);
  assert.match(installVpsUnitsScript, /install -m 0644 .*mtaxi-monitor\.service/);
  assert.match(installVpsUnitsScript, /install -m 0644 .*mtaxi-monitor\.timer/);
  assert.match(installVpsUnitsScript, /install -m 0644 .*mtaxi-api\.conf/);
  assert.match(installVpsUnitsScript, /systemctl daemon-reload/);
  assert.match(installVpsUnitsScript, /systemctl enable --now mtaxi-backend\.service/);
  assert.match(installVpsUnitsScript, /systemctl enable --now mtaxi-backup\.timer/);
  assert.match(installVpsUnitsScript, /systemctl enable --now mtaxi-monitor\.timer/);
  assert.doesNotMatch(installVpsUnitsScript, /docker compose .* up/);
  assert.doesNotMatch(installVpsUnitsScript, /docker compose .* down/);
  assert.doesNotMatch(installVpsUnitsScript, /db:restore/);
  assert.match(opsCheckScript, /MTAXI_DEPLOY_DIR/);
  assert.match(opsCheckScript, /MTAXI_OPS_BASE_URL/);
  assert.match(opsCheckScript, /MTAXI_OPS_EXPECT_STORE/);
  assert.match(opsCheckScript, /MTAXI_OPS_BACKUP_DIR:-\/var\/backups\/mtaxi/);
  assert.match(opsCheckScript, /MTAXI_OPS_BACKUP_MAX_AGE_HOURS:-36/);
  assert.match(opsCheckScript, /must be a non-negative integer/);
  assert.match(opsCheckScript, /systemctl is-active --quiet mtaxi-backend\.service/);
  assert.match(opsCheckScript, /systemctl is-active --quiet mtaxi-backup\.timer/);
  assert.match(opsCheckScript, /systemctl is-active --quiet mtaxi-monitor\.timer/);
  assert.match(opsCheckScript, /mtaxi-backup-\*\.json/);
  assert.match(opsCheckScript, /latest backup manifest/);
  assert.match(opsCheckScript, /latest backup age/);
  assert.match(opsCheckScript, /latest backup is \$\{backup_age_hours\}h old/);
  assert.match(opsCheckScript, /backup manifest verification/);
  assert.match(opsCheckScript, /npm run db:verify-backup -- "\$latest_backup"/);
  assert.match(opsCheckScript, /docker compose version/);
  assert.match(opsCheckScript, /docker compose is required/);
  assert.match(opsCheckScript, /docker compose -f docker-compose\.production\.yml ps/);
  assert.match(opsCheckScript, /curl -fsS "\$base_url\/livez"/);
  assert.match(opsCheckScript, /curl -fsS "\$base_url\/readyz"/);
  assert.match(opsCheckScript, /"\$base_url\/call\/getStoreHealth"/);
  assert.match(opsCheckScript, /npm run monitor/);
  assert.doesNotMatch(opsCheckScript, /docker compose .* down/);
  assert.doesNotMatch(opsCheckScript, /db:restore/);
  assert.match(systemdBackend, /WorkingDirectory=\/opt\/mtaxi/);
  assert.match(systemdBackend, /docker compose -f \/opt\/mtaxi\/docker-compose\.production\.yml up -d --build/);
  assert.match(systemdBackend, /WantedBy=multi-user\.target/);
  assert.match(systemdBackup, /Requires=mtaxi-backend\.service/);
  assert.match(systemdBackup, /After=mtaxi-backend\.service/);
  assert.match(systemdBackup, /WorkingDirectory=\/opt\/mtaxi/);
  assert.match(systemdBackup, /EnvironmentFile=\/opt\/mtaxi\/server\/\.env/);
  assert.match(systemdBackup, /MTAXI_BACKUP_DIR=\/var\/backups\/mtaxi/);
  assert.match(systemdBackup, /MTAXI_BACKUP_RETENTION_DAYS=30/);
  assert.match(systemdBackup, /docker compose -f \/opt\/mtaxi\/docker-compose\.production\.yml exec -T/);
  assert.match(systemdBackup, /-e MTAXI_BACKUP_DIR="\$MTAXI_BACKUP_DIR"/);
  assert.match(systemdBackup, /npm run db:backup/);
  assert.doesNotMatch(systemdBackup, /db:restore/);
  assert.match(systemdBackupTimer, /OnCalendar=\*-\*-\* 03:30:00/);
  assert.match(systemdBackupTimer, /Persistent=true/);
  assert.match(systemdBackupTimer, /Unit=mtaxi-backup\.service/);
  assert.match(systemdBackupTimer, /WantedBy=timers\.target/);
  assert.match(systemdMonitor, /WorkingDirectory=\/opt\/mtaxi\/server/);
  assert.match(systemdMonitor, /EnvironmentFile=-\/opt\/mtaxi\/server\/\.env/);
  assert.doesNotMatch(systemdMonitor, /MTAXI_MONITOR_BASE_URL=https:\/\/api\.mtaxi\.kz/);
  assert.match(systemdMonitor, /MTAXI_MONITOR_BASE_URL="\$\{MTAXI_MONITOR_BASE_URL:-\$MTAXI_PUBLIC_BASE_URL\}"/);
  assert.match(systemdMonitor, /MTAXI_MONITOR_EXPECT_STORE=postgres/);
  assert.match(systemdMonitor, /npm run monitor/);
  assert.match(systemdMonitorTimer, /OnBootSec=2min/);
  assert.match(systemdMonitorTimer, /OnUnitActiveSec=5min/);
  assert.match(systemdMonitorTimer, /Unit=mtaxi-monitor\.service/);
  assert.match(systemdMonitorTimer, /WantedBy=timers\.target/);
});

test("release backend URL guard rejects non-production backend addresses", () => {
  const guardPath = path.join(__dirname, "../../scripts/remote_backend_url_guard.sh");
  const runGuard = (url) => spawnSync(
    "bash",
    [
      "-c",
      `. "${guardPath}"; mtaxi_validate_remote_backend_url "$1" "TEST"`,
      "mtaxi-url-guard-test",
      url,
    ],
    { encoding: "utf8" },
  );

  const valid = runGuard("https://api.mtaxi.example.kz");
  assert.equal(valid.status, 0, valid.stderr);
  assert.equal(valid.stdout.trim(), "https://api.mtaxi.example.kz");

  for (const url of [
    "",
    "http://api.mtaxi.example.kz",
    "https://localhost:8080",
    "https://127.0.0.1:8080",
    "https://10.0.2.2:8080",
    "https://192.168.1.10",
    "https://100.64.0.1",
    "https://172.31.255.10",
    "https://[::1]:8080",
    "https://[fd12::1]",
    "https://[fe80::1]",
  ]) {
    const invalid = runGuard(url);
    assert.notEqual(invalid.status, 0, `expected URL to be rejected: ${url}`);
    assert.match(invalid.stderr, /TEST: (usage: MTAXI_BACKEND_URL|MTAXI_BACKEND_URL)/);
  }
});

test("VPS inputs checker validates real cutover inputs", () => {
  const rootDir = path.join(__dirname, "../..");
  const scriptPath = path.join(rootDir, "scripts/check_vps_inputs.sh");
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-vps-inputs-"));
  const validPath = path.join(tmpDir, "valid.env");
  fs.writeFileSync(validPath, [
    "MTAXI_VPS_HOST=203.0.113.10",
    "MTAXI_VPS_USER=mtaxi",
    "MTAXI_API_DOMAIN=api.mtaxi.kz",
    "MTAXI_PUBLIC_BASE_URL=https://api.mtaxi.kz",
    "MTAXI_CORS_ORIGINS=https://mtaxi-user-vzqw6a.web.app,https://mtaxi-controls.web.app",
    "MTAXI_DNS_READY=true",
    "MTAXI_HTTPS_READY=true",
    "MTAXI_SMS_HTTP_URL=https://smsc.kz/send",
    "MTAXI_SMS_HTTP_METHOD=POST",
    "MTAXI_SMS_HTTP_BODY_TEMPLATE='{\"phone\":\"{{phone}}\",\"message\":\"{{message}}\",\"code\":\"{{code}}\"}'",
    "MTAXI_PAYMENT_URL_TEMPLATE='https://pay.kassa24.kz/start?invoice={{paymentId}}&amount={{amount}}'",
    "MTAXI_PAYMENT_CALLBACK_SECRET=payment-secret",
    "FIREBASE_SERVICE_ACCOUNT_JSON='{\"project_id\":\"mtaxi-test\",\"client_email\":\"firebase-admin@mtaxi.kz\",\"private_key\":\"-----BEGIN PRIVATE KEY-----\\nkey\\n-----END PRIVATE KEY-----\\n\"}'",
    "GOOGLE_APPLICATION_CREDENTIALS=",
    "MTAXI_ADMIN_PHONE=+77001112233",
    "MTAXI_ADMIN_PASSWORD=strong-admin-password",
    "MTAXI_ADMIN_NAME=Admin",
    "MTAXI_ADMIN_CITY=Belousovka",
    "",
  ].join("\n"));

  const valid = spawnSync("bash", [scriptPath, validPath], {
    cwd: rootDir,
    encoding: "utf8",
  });
  assert.equal(valid.status, 0, valid.stderr);
  assert.match(valid.stdout, /MTaxi VPS inputs check passed/);

  const template = spawnSync("bash", [scriptPath], {
    cwd: rootDir,
    encoding: "utf8",
  });
  assert.notEqual(template.status, 0);
  assert.match(template.stderr, /MTAXI_VPS_HOST is required/);

  const localPath = path.join(tmpDir, "local.env");
  fs.writeFileSync(localPath, fs.readFileSync(validPath, "utf8").replace(
    "https://api.mtaxi.kz",
    "http://127.0.0.1:8080",
  ));
  const local = spawnSync("bash", [scriptPath, localPath], {
    cwd: rootDir,
    encoding: "utf8",
  });
  assert.notEqual(local.status, 0);
  assert.match(local.stderr, /external https:\/\/ backend URL/);

  const mismatchDomainPath = path.join(tmpDir, "mismatch-domain.env");
  fs.writeFileSync(mismatchDomainPath, fs.readFileSync(validPath, "utf8").replace(
    "MTAXI_API_DOMAIN=api.mtaxi.kz",
    "MTAXI_API_DOMAIN=api.other.kz",
  ));
  const mismatchDomain = spawnSync("bash", [scriptPath, mismatchDomainPath], {
    cwd: rootDir,
    encoding: "utf8",
  });
  assert.notEqual(mismatchDomain.status, 0);
  assert.match(mismatchDomain.stderr, /MTAXI_API_DOMAIN must match MTAXI_PUBLIC_BASE_URL host/);

  const localCorsPath = path.join(tmpDir, "local-cors.env");
  fs.writeFileSync(localCorsPath, fs.readFileSync(validPath, "utf8").replace(
    "https://mtaxi-user-vzqw6a.web.app,https://mtaxi-controls.web.app",
    "http://localhost:3000,https://mtaxi-controls.web.app",
  ));
  const localCors = spawnSync("bash", [scriptPath, localCorsPath], {
    cwd: rootDir,
    encoding: "utf8",
  });
  assert.notEqual(localCors.status, 0);
  assert.match(localCors.stderr, /MTAXI_CORS_ORIGINS must contain only external https:\/\/ origins/);
});

test("release artifact guards validate embedded backend URL", () => {
  const rootDir = path.join(__dirname, "../..");
  const expectedUrl = "https://api.mtaxi.example.kz";
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-artifact-check-"));
  const webDir = path.join(tmpDir, "web");
  const apkWorkDir = path.join(tmpDir, "apk");
  const apkLibDir = path.join(apkWorkDir, "lib/arm64-v8a");
  fs.mkdirSync(webDir, { recursive: true });
  fs.mkdirSync(apkLibDir, { recursive: true });

  const runScript = (script, args, env = {}) => spawnSync(
    "bash",
    [path.join(rootDir, "scripts", script), ...args],
    {
      cwd: rootDir,
      env: { ...process.env, ...env },
      encoding: "utf8",
    },
  );

  fs.writeFileSync(
    path.join(webDir, "main.dart.js"),
    `const backend="${expectedUrl}"; const requireRemoteBackend=true;`,
  );
  const validWeb = runScript("check_web_backend_artifact.sh", [webDir], {
    MTAXI_BACKEND_URL: expectedUrl,
  });
  assert.equal(validWeb.status, 0, validWeb.stderr);

  fs.writeFileSync(path.join(webDir, "main.dart.js"), 'const backend="http://127.0.0.1:8080";');
  const localWeb = runScript("check_web_backend_artifact.sh", [webDir], {
    MTAXI_BACKEND_URL: expectedUrl,
  });
  assert.notEqual(localWeb.status, 0);
  assert.match(localWeb.stderr, /expected MTAXI_BACKEND_URL is missing|web artifact contains local backend URL/);

  fs.writeFileSync(
    path.join(webDir, "main.dart.js"),
    `const backend="${expectedUrl}"; const stale="https://192.168.1.10";`,
  );
  const privateWeb = runScript("check_web_backend_artifact.sh", [webDir], {
    MTAXI_BACKEND_URL: expectedUrl,
  });
  assert.notEqual(privateWeb.status, 0);
  assert.match(privateWeb.stderr, /web artifact contains local backend URL/);

  const makeApk = (name, payload) => {
    const artifactPath = path.join(tmpDir, name);
    fs.writeFileSync(path.join(apkLibDir, "libapp.so"), payload);
    const zipResult = spawnSync(
      "zip",
      ["-q", "-r", artifactPath, "lib"],
      { cwd: apkWorkDir, encoding: "utf8" },
    );
    assert.equal(zipResult.status, 0, zipResult.stderr);
    return artifactPath;
  };

  const validApk = runScript(
    "check_mobile_backend_artifact.sh",
    ["apk", makeApk("valid.apk", `backend=${expectedUrl}`)],
    { MTAXI_BACKEND_URL: expectedUrl },
  );
  assert.equal(validApk.status, 0, validApk.stderr);

  const localApk = runScript(
    "check_mobile_backend_artifact.sh",
    ["apk", makeApk("local.apk", "backend=http://10.0.2.2:8080")],
    { MTAXI_BACKEND_URL: expectedUrl },
  );
  assert.notEqual(localApk.status, 0);
  assert.match(localApk.stderr, /expected MTAXI_BACKEND_URL is missing|mobile artifact contains local backend URL/);

  const privateApk = runScript(
    "check_mobile_backend_artifact.sh",
    ["apk", makeApk("private.apk", `backend=${expectedUrl}\nstale=https://100.64.0.1`)],
    { MTAXI_BACKEND_URL: expectedUrl },
  );
  assert.notEqual(privateApk.status, 0);
  assert.match(privateApk.stderr, /mobile artifact contains local backend URL/);
});

test("source archive verifier executes against required and forbidden paths", () => {
  const rootDir = path.join(__dirname, "../..");
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-source-verify-"));
  const srcDir = path.join(tmpDir, "src");
  const requiredPaths = [
    "ARCHITECTURE_STATUS.md",
    "server/package.json",
    "server/package-lock.json",
    "server/.dockerignore",
    "server/db/schema.sql",
    "server/Dockerfile",
    "server/scripts/apply_schema.js",
    "server/scripts/backup_backend.js",
    "server/scripts/export_api_contract.js",
    "server/scripts/export_env_contract.js",
    "server/scripts/migrate_json_to_postgres.js",
    "server/scripts/monitor_backend.js",
    "server/scripts/preflight.js",
    "server/scripts/restore_backend.js",
    "server/scripts/seed_admin.js",
    "server/scripts/local_functional_smoke.js",
    "server/scripts/smoke_backend.js",
    "server/scripts/validate_production_deploy.js",
    "server/scripts/verify_backup_manifest.js",
    "docker-compose.production.yml",
    "deploy/nginx/mtaxi-api.conf",
    "deploy/ops_check.sh",
    "deploy/predeploy_check.sh",
    "deploy/systemd/mtaxi-backend.service",
    "deploy/systemd/mtaxi-backup.service",
    "deploy/systemd/mtaxi-backup.timer",
    "deploy/systemd/mtaxi-monitor.service",
    "deploy/systemd/mtaxi-monitor.timer",
    "deploy/vps_prereq_check.sh",
    "scripts/backend_migration_status.sh",
    "scripts/build_backend_release.sh",
    "scripts/check_backend_api_contract.sh",
    "scripts/check_backend_env_contract.sh",
    "scripts/check_backend_migration_ready.sh",
    "scripts/check_backend_migration_quick_status.sh",
    "scripts/check_backend_migration_small_steps.sh",
    "scripts/check_backend_transfer_steps.sh",
    "scripts/cleanup_output_handoffs.sh",
    "scripts/check_vps_cutover_runbook.sh",
    "scripts/check_client_backend_config.sh",
    "scripts/check_client_backend_only_static.sh",
    "scripts/check_firebase_fcm_only.sh",
    "scripts/check_local_flutter_commands.sh",
    "scripts/check_local_app_backend_wiring.sh",
    "scripts/check_local_backend_runbook.sh",
    "scripts/check_local_functional_smoke.sh",
    "scripts/check_latest_vps_handoff_current.sh",
    "scripts/check_latest_vps_handoff_pointer.sh",
    "scripts/check_output_handoffs.sh",
    "scripts/check_local_backend_contract.sh",
    "scripts/check_vps_inputs.sh",
    "scripts/check_local_json_backend.sh",
    "scripts/check_mobile_backend_artifact.sh",
    "scripts/check_release_ready.sh",
    "scripts/check_shell_script_permissions.sh",
    "scripts/check_vps_cutover_dry_run.sh",
    "scripts/check_vps_handoff_extract_smoke.sh",
    "scripts/check_vps_postdeploy.sh",
    "scripts/check_web_backend_artifact.sh",
    "scripts/generate_production_env.sh",
    "scripts/latest_vps_handoff.sh",
    "scripts/package_source_archive.sh",
    "scripts/package_vps_handoff.sh",
    "scripts/print_local_flutter_commands.sh",
    "scripts/print_vps_upload_commands.sh",
    "scripts/remote_backend_url_guard.sh",
    "scripts/start_local_backend.sh",
    "scripts/start_local_json_backend.sh",
    "scripts/stop_local_backend.sh",
    "scripts/verify_backend_migration_status.sh",
    "scripts/verify_source_archive.sh",
    "scripts/verify_vps_handoff.sh",
    "docs/backend_deployment_checklist.md",
    "docs/backend_migration_plan.md",
    "docs/backend_migration_small_steps.md",
    "docs/local_backend_runbook.md",
    "docs/backend_transfer_steps.md",
    "docs/vps_cutover_runbook.md",
    "docs/vps_inputs.template.env",
    "docs/vps_required_inputs.md",
    "lib/backend/backend_session.dart",
    "pubspec.yaml",
  ];

  const writeArchive = (name, extraPaths = []) => {
    fs.rmSync(srcDir, { recursive: true, force: true });
    for (const sourcePath of [...requiredPaths, ...extraPaths]) {
      const fullPath = path.join(srcDir, sourcePath);
      fs.mkdirSync(path.dirname(fullPath), { recursive: true });
      fs.writeFileSync(fullPath, `${sourcePath}\n`);
    }
    const archivePath = path.join(tmpDir, name);
    const tarResult = spawnSync(
      "tar",
      ["-czf", archivePath, "-C", srcDir, ...requiredPaths, ...extraPaths],
      { encoding: "utf8" },
    );
    assert.equal(tarResult.status, 0, tarResult.stderr);
    return archivePath;
  };

  const runVerifier = (archivePath) => spawnSync(
    "bash",
    [path.join(rootDir, "scripts/verify_source_archive.sh"), archivePath],
    { cwd: rootDir, encoding: "utf8" },
  );

  const valid = runVerifier(writeArchive("valid.tar.gz"));
  assert.equal(valid.status, 0, valid.stderr);
  assert.match(valid.stdout, /source archive verification passed/);

  const forbidden = runVerifier(writeArchive("with-env.tar.gz", ["server/.env"]));
  assert.notEqual(forbidden.status, 0);
  assert.match(forbidden.stderr, /archive contains forbidden path matching/);

  const forbiddenLog = runVerifier(writeArchive("with-log.tar.gz", ["docs/debug.log"]));
  assert.notEqual(forbiddenLog.status, 0);
  assert.match(forbiddenLog.stderr, /archive contains forbidden path matching/);

  const forbiddenFirebaseConfig = runVerifier(
    writeArchive("with-firebase-config.tar.gz", ["firebase.json"]),
  );
  assert.notEqual(forbiddenFirebaseConfig.status, 0);
  assert.match(forbiddenFirebaseConfig.stderr, /archive contains forbidden path matching/);

  const forbiddenFirestoreRules = runVerifier(
    writeArchive("with-firestore-rules.tar.gz", ["firestore.rules"]),
  );
  assert.notEqual(forbiddenFirestoreRules.status, 0);
  assert.match(forbiddenFirestoreRules.stderr, /archive contains forbidden path matching/);

  const forbiddenSigningKey = runVerifier(
    writeArchive("with-signing-key.tar.gz", ["android/app/upload-keystore.jks"]),
  );
  assert.notEqual(forbiddenSigningKey.status, 0);
  assert.match(forbiddenSigningKey.stderr, /archive contains forbidden path matching/);

  const forbiddenSigningProps = runVerifier(
    writeArchive("with-signing-props.tar.gz", ["android/key.properties"]),
  );
  assert.notEqual(forbiddenSigningProps.status, 0);
  assert.match(forbiddenSigningProps.stderr, /archive contains forbidden path matching/);

  const forbiddenMachineLocal = runVerifier(
    writeArchive("with-local-props.tar.gz", ["android/local.properties"]),
  );
  assert.notEqual(forbiddenMachineLocal.status, 0);
  assert.match(forbiddenMachineLocal.stderr, /archive contains forbidden path matching/);

  const forbiddenIosGenerated = runVerifier(
    writeArchive("with-ios-generated.tar.gz", ["ios/Flutter/Generated.xcconfig"]),
  );
  assert.notEqual(forbiddenIosGenerated.status, 0);
  assert.match(forbiddenIosGenerated.stderr, /archive contains forbidden path matching/);

  const missing = runVerifier(writeArchive("missing.tar.gz", []));
  assert.equal(missing.status, 0, missing.stderr);
  fs.rmSync(path.join(srcDir, "scripts/remote_backend_url_guard.sh"), { force: true });
  const missingArchivePath = path.join(tmpDir, "missing-required.tar.gz");
  const tarResult = spawnSync(
    "tar",
    [
      "-czf",
      missingArchivePath,
      "-C",
      srcDir,
      ...requiredPaths.filter((sourcePath) =>
        fs.existsSync(path.join(srcDir, sourcePath))
      ),
    ],
    { encoding: "utf8" },
  );
  assert.equal(tarResult.status, 0, tarResult.stderr);
  const missingRequired = runVerifier(missingArchivePath);
  assert.notEqual(missingRequired.status, 0);
  assert.match(missingRequired.stderr, /required source path is missing: scripts\/remote_backend_url_guard\.sh/);
});

test("backend migration status report is machine-verifiable", () => {
  const rootDir = path.join(__dirname, "../..");
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-readiness-report-"));
  const reportPath = path.join(tmpDir, "READINESS_REPORT.json");

  const generate = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/backend_migration_status.sh"), reportPath],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(generate.status, 0, generate.stderr);

  const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  assert.equal(report.type, "mtaxi-backend-migration-status");
  assert.equal(report.readinessPercent, 99);
  assert.equal(report.architecture, "backend-only");
  assert.equal(report.firebaseUsage, "FCM push only");
  assert.ok(report.localEvidence.includes("source archive verification"));
  assert.ok(report.localEvidence.includes("local backend contract check"));
  assert.ok(report.localEvidence.includes("client backend config check"));
  assert.ok(report.localEvidence.includes("local Flutter command helper"));
  assert.ok(report.localEvidence.includes("local functional smoke"));
  assert.ok(report.localEvidence.includes("backend migration status report verification"));
  assert.ok(report.localEvidence.includes("backend transfer steps verification"));
  assert.ok(report.localEvidence.includes("latest VPS handoff helper verification"));
  assert.ok(report.localEvidence.includes("Step-by-step transfer document"));
  assert.ok(report.remainingFor100Percent.includes("Production postdeploy smoke and monitor"));

  const verify = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/verify_backend_migration_status.sh"), reportPath],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(verify.status, 0, verify.stderr);
  assert.match(verify.stdout, /backend migration status verification passed/);

  fs.writeFileSync(
    reportPath,
    fs.readFileSync(reportPath, "utf8").replace('"readinessPercent": 99', '"readinessPercent": 100'),
  );
  const broken = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/verify_backend_migration_status.sh"), reportPath],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.notEqual(broken.status, 0);
  assert.match(broken.stderr, /readiness percent must stay 99/);
});

test("production env generator preserves external payment query templates", async () => {
  const rootDir = path.join(__dirname, "../..");
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-production-env-"));
  const envPath = path.join(tmpDir, ".env.generated");
  const paymentUrl =
    "https://pay.mtaxi.example/start?invoice={{paymentId}}&amount={{amount}}&source=mtaxi";
  const result = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/generate_production_env.sh"), envPath],
    {
      cwd: rootDir,
      encoding: "utf8",
      env: {
        ...process.env,
        MTAXI_PUBLIC_BASE_URL: "https://api.mtaxi.example",
        MTAXI_SMS_HTTP_URL: "https://sms.mtaxi.example/send",
        MTAXI_SMS_HTTP_METHOD: "PATCH",
        MTAXI_SMS_HTTP_BEARER_TOKEN: "sms-token",
        MTAXI_SMS_HTTP_HEADERS: '{"X-Service":"mtaxi"}',
        MTAXI_SMS_HTTP_BODY_TEMPLATE: '{"to":"{{phone}}","text":"{{message}}"}',
        MTAXI_PAYMENT_URL_TEMPLATE: paymentUrl,
        MTAXI_SEED_ADMIN_ON_START: "true",
        MTAXI_ADMIN_PHONE: "+77001112233",
        MTAXI_ADMIN_PASSWORD: "strong-admin-password",
        MTAXI_ADMIN_NAME: "Admin",
        MTAXI_ADMIN_CITY: "Belousovka",
        FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({
          project_id: "mtaxi-test",
          client_email: "firebase-admin@test.example",
          private_key: "-----BEGIN PRIVATE KEY-----\\nkey\\n-----END PRIVATE KEY-----\\n",
        }),
      },
    },
  );

  assert.equal(result.status, 0, result.stderr);
  const generated = fs.readFileSync(envPath, "utf8");
  assert.match(generated, /NODE_ENV=production/);
  assert.match(generated, /MTAXI_PUBLIC_BASE_URL=https:\/\/api\.mtaxi\.example/);
  assert.match(generated, /MTAXI_SMS_HTTP_URL=https:\/\/sms\.mtaxi\.example\/send/);
  assert.match(generated, /MTAXI_SMS_HTTP_METHOD=PATCH/);
  assert.match(generated, /MTAXI_SMS_HTTP_BEARER_TOKEN=sms-token/);
  assert.match(generated, /MTAXI_SMS_HTTP_HEADERS=\{"X-Service":"mtaxi"\}/);
  assert.match(generated, /MTAXI_SMS_HTTP_BODY_TEMPLATE=\{"to":"\{\{phone\}\}","text":"\{\{message\}\}"\}/);
  assert.match(generated, new RegExp(`MTAXI_PAYMENT_URL_TEMPLATE=${paymentUrl.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`));
  assert.match(generated, /MTAXI_SEED_ADMIN_ON_START=true/);
  assert.match(generated, /MTAXI_ADMIN_PHONE=\+77001112233/);
  assert.match(generated, /MTAXI_ADMIN_PASSWORD=strong-admin-password/);
  assert.match(generated, /MTAXI_ADMIN_NAME=Admin/);
  assert.match(generated, /MTAXI_ADMIN_CITY=Belousovka/);
  assert.match(generated, /DATABASE_URL=postgres:\/\/mtaxi:[a-f0-9]+@postgres:5432\/mtaxi/);
  assert.match(generated, /FIREBASE_SERVICE_ACCOUNT_JSON=\{"project_id":"mtaxi-test"/);
  assert.doesNotMatch(generated, /GOOGLE_APPLICATION_CREDENTIALS=/);

  const validation = await validateProductionDeploy({ envFilePath: envPath });
  assert.equal(validation.ok, true);
});

test("production env generator refuses seed admin without real admin inputs", () => {
  const rootDir = path.join(__dirname, "../..");
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-production-env-fail-"));
  const envPath = path.join(tmpDir, ".env.generated");
  const result = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/generate_production_env.sh"), envPath],
    {
      cwd: rootDir,
      encoding: "utf8",
      env: {
        ...process.env,
        MTAXI_PUBLIC_BASE_URL: "https://api.mtaxi.example",
        MTAXI_SMS_HTTP_URL: "https://sms.mtaxi.example/send",
        MTAXI_PAYMENT_URL_TEMPLATE:
          "https://pay.mtaxi.example/start?invoice={{paymentId}}&amount={{amount}}",
        MTAXI_SEED_ADMIN_ON_START: "true",
        GOOGLE_APPLICATION_CREDENTIALS: "/etc/mtaxi/firebase-service-account.json",
      },
    },
  );

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /MTAXI_ADMIN_PHONE is required/);
});

test("VPS handoff package contains source archive, checksum and next steps", () => {
  const rootDir = path.join(__dirname, "../..");
  const handoffDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-vps-handoff-"));
  const result = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/package_vps_handoff.sh"), handoffDir],
    {
      cwd: rootDir,
      encoding: "utf8",
      env: {
        ...process.env,
        MTAXI_VPS_HANDOFF_SKIP_READY: "true",
      },
    },
  );

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /MTaxi VPS handoff package ready/);
  const files = fs.readdirSync(handoffDir);
  const archiveName = files.find((name) => /^mtaxi-source-.*\.tar\.gz$/.test(name));
  assert.ok(archiveName, "handoff source archive is missing");
  assert.ok(files.includes(`${archiveName}.sha256`), "handoff checksum is missing");
  assert.ok(files.includes("DEPLOY_NEXT_STEPS.md"), "handoff next steps are missing");
  assert.ok(files.includes("HANDOFF_QUICK_COMMANDS.md"), "handoff quick commands are missing");
  assert.ok(files.includes("HANDOFF_STATUS.md"), "handoff status is missing");
  assert.ok(files.includes("HANDOFF_MANIFEST.json"), "handoff manifest is missing");
  assert.ok(files.includes("READINESS_REPORT.json"), "handoff readiness report is missing");
  assert.ok(files.includes("API_CONTRACT.json"), "handoff API contract is missing");
  assert.ok(files.includes("ENV_CONTRACT.json"), "handoff env contract is missing");
  assert.ok(files.includes("verify_vps_handoff.sh"), "handoff verifier is missing");
  assert.equal(
    fs.statSync(path.join(handoffDir, "verify_vps_handoff.sh")).mode & 0o111,
    0o111,
    "handoff verifier must be executable",
  );

  const checksum = spawnSync("shasum", ["-a", "256", "-c", `${archiveName}.sha256`], {
    cwd: handoffDir,
    encoding: "utf8",
  });
  assert.equal(checksum.status, 0, checksum.stderr);
  const checksumValue = fs
    .readFileSync(path.join(handoffDir, `${archiveName}.sha256`), "utf8")
    .trim()
    .split(/\s+/)[0];
  const manifest = JSON.parse(
    fs.readFileSync(path.join(handoffDir, "HANDOFF_MANIFEST.json"), "utf8"),
  );
  assert.equal(manifest.type, "mtaxi-vps-handoff");
  assert.equal(manifest.version, 1);
  assert.equal(manifest.sourceArchive, archiveName);
  assert.equal(manifest.sourceArchiveSha256, checksumValue);
  assert.equal(
    manifest.sourceArchiveSizeBytes,
    fs.statSync(path.join(handoffDir, archiveName)).size,
  );
  assert.equal(manifest.nextSteps, "DEPLOY_NEXT_STEPS.md");
  assert.equal(manifest.quickCommands, "HANDOFF_QUICK_COMMANDS.md");
  assert.equal(manifest.status, "HANDOFF_STATUS.md");
  assert.equal(manifest.readinessReport, "READINESS_REPORT.json");
  assert.equal(manifest.apiContract, "API_CONTRACT.json");
  assert.equal(manifest.envContract, "ENV_CONTRACT.json");
  assert.equal(manifest.verifier, "verify_vps_handoff.sh");
  assert.equal(manifest.firebaseUsage, "FCM push only");
  assert.equal(manifest.readinessPercent, 99);
  assert.equal(manifest.readinessRemaining, "real VPS/domain/env and production smoke");
  assert.deepEqual(manifest.verifiedChecks, [
    "backend tests",
    "shell syntax",
    "JavaScript syntax",
    "Firebase FCM-only guard",
    "client backend-only static check",
    "client backend config check",
    "backend API contract verification",
    "backend env contract verification",
    "local backend contract check",
    "local Flutter command helper",
    "local backend runbook verification",
    "local functional smoke",
    "local JSON backend smoke",
    "source archive verification",
    "backend migration status report verification",
    "backend migration small steps verification",
    "backend transfer steps verification",
    "VPS cutover runbook verification",
    "latest VPS handoff helper verification",
    "output handoff inventory verification",
    "VPS upload command helper verification",
    "VPS handoff extract smoke verification",
    "VPS cutover dry-run verification",
    "backup manifest verification script",
    "VPS postdeploy check script",
    "VPS handoff manifest/checksum verification",
  ]);

  const verifyHandoff = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/verify_vps_handoff.sh"), handoffDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(verifyHandoff.status, 0, verifyHandoff.stderr);
  assert.match(verifyHandoff.stdout, /VPS handoff verification passed/);

  const bundledVerifyHandoff = spawnSync(
    "bash",
    [path.join(handoffDir, "verify_vps_handoff.sh"), handoffDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(bundledVerifyHandoff.status, 0, bundledVerifyHandoff.stderr);
  assert.match(bundledVerifyHandoff.stdout, /VPS handoff verification passed/);

  const nextSteps = fs.readFileSync(path.join(handoffDir, "DEPLOY_NEXT_STEPS.md"), "utf8");
  assert.match(nextSteps, /verify_vps_handoff\.sh/);
  assert.match(nextSteps, /READINESS_REPORT\.json/);
  assert.match(nextSteps, /API_CONTRACT\.json/);
  assert.match(nextSteps, /ENV_CONTRACT\.json/);
  assert.match(nextSteps, /HANDOFF_QUICK_COMMANDS\.md/);
  assert.match(nextSteps, /\.\/verify_vps_handoff\.sh \./);
  assert.match(nextSteps, /\/tmp\/mtaxi-handoff/);
  assert.match(nextSteps, /chmod \+x verify_vps_handoff\.sh/);
  assert.match(nextSteps, /shasum -a 256 -c mtaxi-source-\*\.tar\.gz\.sha256/);
  assert.match(nextSteps, /sudo mkdir -p \/opt\/mtaxi/);
  assert.match(nextSteps, /sudo tar -xzf mtaxi-source-\*\.tar\.gz -C \/opt\/mtaxi/);
  assert.match(nextSteps, /cd \/opt\/mtaxi/);
  assert.match(nextSteps, /docs\/backend_transfer_steps\.md/);
  assert.match(nextSteps, /docs\/backend_migration_small_steps\.md/);
  assert.match(nextSteps, /scripts\/check_backend_migration_small_steps\.sh/);
  assert.match(nextSteps, /scripts\/check_backend_api_contract\.sh/);
  assert.match(nextSteps, /scripts\/check_backend_env_contract\.sh/);
  assert.match(nextSteps, /scripts\/check_backend_transfer_steps\.sh/);
  assert.match(nextSteps, /scripts\/check_vps_cutover_runbook\.sh/);
  assert.match(nextSteps, /scripts\/check_local_flutter_commands\.sh/);
  assert.match(nextSteps, /scripts\/check_local_backend_runbook\.sh/);
  assert.match(nextSteps, /scripts\/check_local_functional_smoke\.sh/);
  assert.match(nextSteps, /scripts\/check_output_handoffs\.sh output/);
  assert.match(nextSteps, /docs\/vps_inputs\.template\.env/);
  assert.match(nextSteps, /\/tmp\/mtaxi-vps-inputs\.env/);
  assert.match(nextSteps, /check_vps_inputs\.sh \/tmp\/mtaxi-vps-inputs\.env/);
  assert.match(nextSteps, /set -a/);
  assert.match(nextSteps, /\. \/tmp\/mtaxi-vps-inputs\.env/);
  assert.match(nextSteps, /set \+a/);
  assert.match(nextSteps, /HANDOFF_STATUS\.md/);
  assert.match(nextSteps, /deploy\/vps_prereq_check\.sh/);
  assert.match(nextSteps, /deploy\/predeploy_check\.sh/);
  assert.match(nextSteps, /generate_production_env\.sh/);
  assert.match(nextSteps, /check_vps_postdeploy\.sh/);
  assert.match(nextSteps, /MTAXI_POSTDEPLOY_BASE_URL=https:\/\/api\.mtaxi\.kz/);
  assert.match(nextSteps, /Firebase is allowed only for FCM push/);

  const quickCommands = fs.readFileSync(path.join(handoffDir, "HANDOFF_QUICK_COMMANDS.md"), "utf8");
  assert.match(quickCommands, /MTAXI_VPS_USER/);
  assert.match(quickCommands, /MTAXI_VPS_HOST/);
  assert.match(quickCommands, /MTAXI_API_URL=https:\/\/api\.mtaxi\.kz/);
  assert.match(quickCommands, /scripts\/latest_vps_handoff\.sh/);
  assert.match(quickCommands, /scp "\$LATEST_HANDOFF"\/\*/);
  assert.match(quickCommands, /\.\/verify_vps_handoff\.sh \./);
  assert.match(quickCommands, /sudo tar -xzf mtaxi-source-\*\.tar\.gz -C \/opt\/mtaxi/);
  assert.match(quickCommands, /check_vps_inputs\.sh \/tmp\/mtaxi-vps-inputs\.env/);
  assert.match(quickCommands, /check_vps_postdeploy\.sh/);
  assert.match(quickCommands, /MTAXI_BACKEND_URL="\$MTAXI_API_URL" \.\/scripts\/build_backend_release\.sh web\|apk\|ios/);
  assert.match(quickCommands, /Firebase is allowed only for FCM push/);

  const verifier = fs.readFileSync(path.join(handoffDir, "verify_vps_handoff.sh"), "utf8");
  assert.match(verifier, /manifest missing verified check/);
  assert.match(verifier, /Firebase FCM-only guard/);
  assert.match(verifier, /client backend-only static check/);
  assert.match(verifier, /client backend config check/);
  assert.match(verifier, /backend API contract verification/);
  assert.match(verifier, /backend env contract verification/);
  assert.match(verifier, /local backend contract check/);
  assert.match(verifier, /local Flutter command helper/);
  assert.match(verifier, /local backend runbook verification/);
  assert.match(verifier, /local functional smoke/);
  assert.match(verifier, /output handoff inventory verification/);
  assert.match(verifier, /VPS handoff manifest\/checksum verification/);
  assert.match(verifier, /backend migration status report verification/);
  assert.match(verifier, /backend migration small steps verification/);
  assert.match(verifier, /backend transfer steps verification/);
  assert.match(verifier, /latest VPS handoff helper verification/);
  assert.match(verifier, /quick commands do not select latest handoff/);
  assert.match(verifier, /VPS handoff extract smoke verification/);
  assert.match(verifier, /VPS cutover dry-run verification/);
  assert.match(verifier, /next steps do not verify VPS inputs/);
  assert.match(verifier, /next steps do not verify backend transfer steps/);
  assert.match(verifier, /next steps do not verify local Flutter commands/);
  assert.match(verifier, /next steps do not run postdeploy gate/);
  assert.match(verifier, /backup manifest verification script/);
  assert.match(verifier, /VPS postdeploy check script/);
  assert.match(verifier, /READINESS_REPORT\.json/);
  assert.match(verifier, /API_CONTRACT\.json/);
  assert.match(verifier, /ENV_CONTRACT\.json/);
  assert.match(verifier, /mtaxi-backend-api-contract/);
  assert.match(verifier, /mtaxi-backend-env-contract/);

  const readinessReport = JSON.parse(
    fs.readFileSync(path.join(handoffDir, "READINESS_REPORT.json"), "utf8"),
  );
  assert.equal(readinessReport.type, "mtaxi-backend-migration-status");
  assert.equal(readinessReport.readinessPercent, 99);
  assert.equal(readinessReport.architecture, "backend-only");
  assert.equal(readinessReport.firebaseUsage, "FCM push only");
  assert.ok(readinessReport.localEvidence.includes("backend API contract verification"));
  assert.ok(readinessReport.localEvidence.includes("local JSON backend smoke"));
  assert.ok(readinessReport.localEvidence.includes("client backend config check"));
  assert.ok(readinessReport.localEvidence.includes("local backend contract check"));
  assert.ok(readinessReport.localEvidence.includes("local backend runbook verification"));
  assert.ok(readinessReport.localEvidence.includes("local functional smoke"));
  assert.ok(readinessReport.localEvidence.includes("backend migration small steps verification"));
  assert.ok(readinessReport.localEvidence.includes("local Flutter command helper"));
  assert.ok(readinessReport.localEvidence.includes("backend migration status report verification"));
  assert.ok(readinessReport.localEvidence.includes("backend transfer steps verification"));
  assert.ok(readinessReport.localEvidence.includes("latest VPS handoff helper verification"));
  assert.ok(readinessReport.localEvidence.includes("Step-by-step transfer document"));
  assert.ok(readinessReport.remainingFor100Percent.includes("Production postdeploy smoke and monitor"));

  const apiContract = JSON.parse(
    fs.readFileSync(path.join(handoffDir, "API_CONTRACT.json"), "utf8"),
  );
  assert.equal(apiContract.type, "mtaxi-backend-api-contract");
  assert.equal(apiContract.endpoint, "POST /call/:name");
  assert.equal(apiContract.firebaseUsage, "FCM push only");
  assert.deepEqual(apiContract.missingServerHandlers, []);
  assert.ok(apiContract.handlers.some((handler) => handler.name === "createPassengerOrder"));
  assert.ok(apiContract.handlers.some((handler) => handler.name === "adminManageOrder"));

  const envContract = JSON.parse(
    fs.readFileSync(path.join(handoffDir, "ENV_CONTRACT.json"), "utf8"),
  );
  assert.equal(envContract.type, "mtaxi-backend-env-contract");
  assert.equal(envContract.store, "PostgreSQL in production");
  assert.equal(envContract.firebaseUsage, "FCM push only");
  assert.equal(envContract.productionValues.NODE_ENV, "production");
  assert.equal(envContract.productionValues.MTAXI_STORE, "postgres");
  assert.deepEqual(envContract.missingInExample, []);
  assert.deepEqual(envContract.mismatchedProductionDefaults, []);
  assert.deepEqual(envContract.unsafeDevDefaults, []);

  const status = fs.readFileSync(path.join(handoffDir, "HANDOFF_STATUS.md"), "utf8");
  assert.match(status, /ready for VPS cutover, pending real server inputs/);
  assert.match(status, /Readiness: 99% locally ready/);
  assert.match(status, /JavaScript syntax/);
  assert.match(status, /Firebase FCM-only guard/);
  assert.match(status, /Client backend-only static check/);
  assert.match(status, /Backend env contract verification/);
  assert.match(status, /Local backend contract check/);
  assert.match(status, /Local Flutter command helper/);
  assert.match(status, /Local JSON backend smoke without Docker/);
  assert.match(status, /Backend migration status report verification/);
  assert.match(status, /Backend transfer steps verification/);
  assert.match(status, /Latest VPS handoff helper verification/);
  assert.match(status, /Output handoff inventory verification/);
  assert.match(status, /Step-by-step transfer document/);
  assert.match(status, /VPS postdeploy check script/);
  assert.match(status, /Production smoke\/monitor after deployment/);
  assert.match(status, /Firebase must stay limited to FCM push/);

  fs.writeFileSync(
    path.join(handoffDir, "HANDOFF_STATUS.md"),
    status.replace("Firebase must stay limited to FCM push", "Firebase can be used broadly"),
  );
  const brokenStatusHandoff = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/verify_vps_handoff.sh"), handoffDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.notEqual(brokenStatusHandoff.status, 0);
  assert.match(
    brokenStatusHandoff.stderr,
    /status file does not keep Firebase limited to FCM push/,
  );
  fs.writeFileSync(path.join(handoffDir, "HANDOFF_STATUS.md"), status);

  fs.writeFileSync(
    path.join(handoffDir, "DEPLOY_NEXT_STEPS.md"),
    nextSteps.split("./scripts/check_vps_postdeploy.sh").join("./scripts/check_release_ready.sh"),
  );
  const brokenNextStepsHandoff = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/verify_vps_handoff.sh"), handoffDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.notEqual(brokenNextStepsHandoff.status, 0);
  assert.match(brokenNextStepsHandoff.stderr, /next steps do not run postdeploy gate/);
  fs.writeFileSync(path.join(handoffDir, "DEPLOY_NEXT_STEPS.md"), nextSteps);

  const originalManifestText = fs.readFileSync(
    path.join(handoffDir, "HANDOFF_MANIFEST.json"),
    "utf8",
  );
  fs.writeFileSync(
    path.join(handoffDir, "HANDOFF_MANIFEST.json"),
    originalManifestText.replace('"readinessPercent": 99', '"readinessPercent": 100'),
  );
  const brokenReadinessHandoff = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/verify_vps_handoff.sh"), handoffDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.notEqual(brokenReadinessHandoff.status, 0);
  assert.match(brokenReadinessHandoff.stderr, /unexpected readinessPercent/);
  fs.writeFileSync(path.join(handoffDir, "HANDOFF_MANIFEST.json"), originalManifestText);

  fs.writeFileSync(path.join(handoffDir, "old-file.txt"), "old handoff data\n");
  const extraFileHandoff = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/verify_vps_handoff.sh"), handoffDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.notEqual(extraFileHandoff.status, 0);
  assert.match(extraFileHandoff.stderr, /unexpected handoff file: old-file\.txt/);
  fs.rmSync(path.join(handoffDir, "old-file.txt"));

  fs.mkdirSync(path.join(handoffDir, "old-dir"));
  const extraDirHandoff = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/verify_vps_handoff.sh"), handoffDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.notEqual(extraDirHandoff.status, 0);
  assert.match(extraDirHandoff.stderr, /unexpected handoff file: old-dir/);
  fs.rmSync(path.join(handoffDir, "old-dir"), { recursive: true, force: true });

  fs.writeFileSync(path.join(handoffDir, `${archiveName}.sha256`), `bad  ${archiveName}\n`);
  const brokenHandoff = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/verify_vps_handoff.sh"), handoffDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.notEqual(brokenHandoff.status, 0);
  assert.match(brokenHandoff.stderr, /source archive checksum failed/);
});

test("VPS handoff package refuses non-empty output directory", () => {
  const rootDir = path.join(__dirname, "../..");
  const handoffDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-vps-handoff-dirty-"));
  fs.writeFileSync(path.join(handoffDir, "old-file.txt"), "old handoff data\n");

  const result = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/package_vps_handoff.sh"), handoffDir],
    {
      cwd: rootDir,
      encoding: "utf8",
      env: {
        ...process.env,
        MTAXI_VPS_HANDOFF_SKIP_READY: "true",
      },
    },
  );

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /handoff directory must be empty/);
});

test("VPS handoff package updates output latest pointer", () => {
  const rootDir = path.join(__dirname, "../..");
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-vps-pointer-"));
  const outputDir = path.join(tmpDir, "output");
  const handoffDir = path.join(outputDir, "mtaxi-vps-handoff-20260101-000000");
  fs.mkdirSync(outputDir);

  const result = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/package_vps_handoff.sh"), handoffDir],
    {
      cwd: rootDir,
      encoding: "utf8",
      env: {
        ...process.env,
        MTAXI_VPS_HANDOFF_SKIP_READY: "true",
      },
    },
  );

  assert.equal(result.status, 0, result.stderr);
  const pointerPath = path.join(outputDir, "LATEST_MTAXI_VPS_HANDOFF.txt");
  const pointer = fs.readFileSync(pointerPath, "utf8");
  assert.match(pointer, new RegExp(`Latest verified MTaxi VPS handoff: ${handoffDir}`));
  assert.match(pointer, /Source archive: mtaxi-source-.*\.tar\.gz/);

  const pointerCheck = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/check_latest_vps_handoff_pointer.sh"), outputDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(pointerCheck.status, 0, pointerCheck.stderr);
  assert.match(pointerCheck.stdout, /latest VPS handoff pointer is current/);

  fs.writeFileSync(pointerPath, pointer.replace(handoffDir, path.join(outputDir, "old")));
  const stalePointerCheck = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/check_latest_vps_handoff_pointer.sh"), outputDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.notEqual(stalePointerCheck.status, 0);
  assert.match(stalePointerCheck.stderr, /pointer path is stale/);
});

test("latest VPS handoff script verifies and prints newest package", () => {
  const rootDir = path.join(__dirname, "../..");
  const outputDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-vps-output-"));
  const olderDir = path.join(outputDir, "mtaxi-vps-handoff-20260101-000000");
  const newerDir = path.join(outputDir, "mtaxi-vps-handoff-20260101-000001");

  for (const handoffDir of [olderDir, newerDir]) {
    const packageResult = spawnSync(
      "bash",
      [path.join(rootDir, "scripts/package_vps_handoff.sh"), handoffDir],
      {
        cwd: rootDir,
        encoding: "utf8",
        env: {
          ...process.env,
          MTAXI_VPS_HANDOFF_SKIP_READY: "true",
        },
      },
    );
    assert.equal(packageResult.status, 0, packageResult.stderr);
  }

  const latest = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/latest_vps_handoff.sh"), outputDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(latest.status, 0, latest.stderr);
  assert.match(latest.stdout, new RegExp(`Latest verified MTaxi VPS handoff: ${newerDir}`));
  assert.match(latest.stdout, /Source archive: mtaxi-source-.*\.tar\.gz/);

  fs.rmSync(path.join(newerDir, "HANDOFF_MANIFEST.json"));
  const brokenLatest = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/latest_vps_handoff.sh"), outputDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(brokenLatest.status, 0, brokenLatest.stderr);
  assert.match(brokenLatest.stderr, new RegExp(`Skipping broken MTaxi VPS handoff: ${newerDir}`));
  assert.match(brokenLatest.stdout, new RegExp(`Latest verified MTaxi VPS handoff: ${olderDir}`));
  assert.match(brokenLatest.stdout, /Skipped broken newer packages: 1/);
});

test("output handoff inventory script verifies every package", () => {
  const rootDir = path.join(__dirname, "../..");
  const outputDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-vps-output-check-"));
  const firstDir = path.join(outputDir, "mtaxi-vps-handoff-20260101-000000");
  const secondDir = path.join(outputDir, "mtaxi-vps-handoff-20260101-000001");

  for (const handoffDir of [firstDir, secondDir]) {
    const packageResult = spawnSync(
      "bash",
      [path.join(rootDir, "scripts/package_vps_handoff.sh"), handoffDir],
      {
        cwd: rootDir,
        encoding: "utf8",
        env: {
          ...process.env,
          MTAXI_VPS_HANDOFF_SKIP_READY: "true",
        },
      },
    );
    assert.equal(packageResult.status, 0, packageResult.stderr);
  }

  const validInventory = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/check_output_handoffs.sh"), outputDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(validInventory.status, 0, validInventory.stderr);
  assert.match(validInventory.stdout, /output handoff check passed: 2 valid package/);

  fs.rmSync(path.join(firstDir, "HANDOFF_MANIFEST.json"));
  const brokenInventory = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/check_output_handoffs.sh"), outputDir],
    {
      cwd: rootDir,
      encoding: "utf8",
      env: {
        ...process.env,
        MTAXI_OUTPUT_HANDOFF_REQUIRE_ALL: "true",
      },
    },
  );
  assert.notEqual(brokenInventory.status, 0);
  assert.match(brokenInventory.stdout, new RegExp(`BROKEN ${firstDir}`));
  assert.match(brokenInventory.stderr, /1 of 2 handoff packages are broken/);
});

test("handoff cleanup helper removes only broken old packages after dry-run", () => {
  const rootDir = path.join(__dirname, "../..");
  const outputDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-vps-output-cleanup-"));
  const olderDir = path.join(outputDir, "mtaxi-vps-handoff-20260101-000000");
  const latestDir = path.join(outputDir, "mtaxi-vps-handoff-20260101-000001");

  for (const handoffDir of [olderDir, latestDir]) {
    const packageResult = spawnSync(
      "bash",
      [path.join(rootDir, "scripts/package_vps_handoff.sh"), handoffDir],
      {
        cwd: rootDir,
        encoding: "utf8",
        env: {
          ...process.env,
          MTAXI_VPS_HANDOFF_SKIP_READY: "true",
        },
      },
    );
    assert.equal(packageResult.status, 0, packageResult.stderr);
  }

  fs.rmSync(path.join(olderDir, "HANDOFF_MANIFEST.json"));
  const dryRun = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/cleanup_output_handoffs.sh"), outputDir, "--dry-run"],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(dryRun.status, 0, dryRun.stderr);
  assert.match(dryRun.stdout, new RegExp(`WOULD_DELETE broken-old ${olderDir}`));
  assert.match(dryRun.stdout, new RegExp(`KEEP valid ${latestDir}`));
  assert.ok(fs.existsSync(olderDir), "dry-run must not delete broken package");

  const deleteRun = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/cleanup_output_handoffs.sh"), outputDir, "--delete"],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(deleteRun.status, 0, deleteRun.stderr);
  assert.match(deleteRun.stdout, new RegExp(`DELETED broken-old ${olderDir}`));
  assert.ok(!fs.existsSync(olderDir), "delete mode must remove broken package");
  assert.ok(fs.existsSync(latestDir), "cleanup must keep latest valid package");
});

test("VPS upload command helper prints verified handoff upload commands", () => {
  const rootDir = path.join(__dirname, "../..");
  const outputDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-vps-upload-"));
  const handoffDir = path.join(outputDir, "mtaxi-vps-handoff-20260101-000000");
  const packageResult = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/package_vps_handoff.sh"), handoffDir],
    {
      cwd: rootDir,
      encoding: "utf8",
      env: {
        ...process.env,
        MTAXI_VPS_HANDOFF_SKIP_READY: "true",
      },
    },
  );
  assert.equal(packageResult.status, 0, packageResult.stderr);

  const uploadCommands = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/print_vps_upload_commands.sh"), handoffDir],
    {
      cwd: rootDir,
      encoding: "utf8",
      env: {
        ...process.env,
        MTAXI_VPS_USER: "deploy",
        MTAXI_VPS_HOST: "203.0.113.10",
      },
    },
  );
  assert.equal(uploadCommands.status, 0, uploadCommands.stderr);
  assert.match(uploadCommands.stdout, /export MTAXI_VPS_USER=deploy/);
  assert.match(uploadCommands.stdout, /export MTAXI_VPS_HOST=203\.0\.113\.10/);
  assert.match(uploadCommands.stdout, /ssh "\$MTAXI_VPS_USER@\$MTAXI_VPS_HOST"/);
  assert.match(uploadCommands.stdout, /scp ".+mtaxi-vps-handoff-20260101-000000"\/\*/);
  assert.match(uploadCommands.stdout, /shasum -a 256 -c mtaxi-source-\*\.tar\.gz\.sha256/);
  assert.match(uploadCommands.stdout, /\.\/verify_vps_handoff\.sh \./);
});

test("VPS handoff extract smoke verifies unpacked transfer helpers", () => {
  const rootDir = path.join(__dirname, "../..");
  const outputDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-vps-extract-"));
  const handoffDir = path.join(outputDir, "mtaxi-vps-handoff-20260101-000000");
  const packageResult = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/package_vps_handoff.sh"), handoffDir],
    {
      cwd: rootDir,
      encoding: "utf8",
      env: {
        ...process.env,
        MTAXI_VPS_HANDOFF_SKIP_READY: "true",
      },
    },
  );
  assert.equal(packageResult.status, 0, packageResult.stderr);

  const smoke = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/check_vps_handoff_extract_smoke.sh"), handoffDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(smoke.status, 0, smoke.stderr);
  assert.match(smoke.stdout, /VPS handoff extract smoke passed/);

  fs.rmSync(path.join(handoffDir, "HANDOFF_MANIFEST.json"));
  const broken = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/check_vps_handoff_extract_smoke.sh"), handoffDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.notEqual(broken.status, 0);
  assert.match(broken.stderr, /VPS handoff extract smoke failed/);
});

test("VPS cutover dry-run combines handoff, upload command and extract checks", () => {
  const rootDir = path.join(__dirname, "../..");
  const outputDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-vps-dry-run-"));
  const handoffDir = path.join(outputDir, "mtaxi-vps-handoff-20260101-000000");
  const packageResult = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/package_vps_handoff.sh"), handoffDir],
    {
      cwd: rootDir,
      encoding: "utf8",
      env: {
        ...process.env,
        MTAXI_VPS_HANDOFF_SKIP_READY: "true",
      },
    },
  );
  assert.equal(packageResult.status, 0, packageResult.stderr);

  const dryRun = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/check_vps_cutover_dry_run.sh"), handoffDir],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(dryRun.status, 0, dryRun.stderr);
  assert.match(dryRun.stdout, /VPS cutover dry-run passed/);
});

test("VPS cutover runbook is machine-verifiable", () => {
  const rootDir = path.join(__dirname, "../..");
  const result = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/check_vps_cutover_runbook.sh")],
    { cwd: rootDir, encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /VPS cutover runbook check passed/);
});

test("local Flutter command helper prints correct web and Android backend URLs", () => {
  const rootDir = path.join(__dirname, "../..");
  const result = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/check_local_flutter_commands.sh")],
    { cwd: rootDir, encoding: "utf8" },
  );

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /local Flutter command check passed/);
});

test("local app backend wiring is machine-verifiable", () => {
  const rootDir = path.join(__dirname, "../..");
  const result = spawnSync(
    "bash",
    [path.join(rootDir, "scripts/check_local_app_backend_wiring.sh")],
    { cwd: rootDir, encoding: "utf8" },
  );

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /local app backend wiring check passed/);
});

test("production deployment validator checks compose and server env before VPS launch", async () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-production-validate-"));
  const envPath = path.join(tmpDir, ".env");
  const validEnv = [
    "PORT=8080",
    "MTAXI_PUBLIC_BASE_URL=https://api.mtaxi.example",
    "MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL=false",
    "MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL=false",
    "MTAXI_CORS_ORIGINS=https://mtaxi-user-vzqw6a.web.app,https://mtaxi-controls.web.app",
    "MTAXI_JSON_BODY_LIMIT=25mb",
    "MTAXI_TRUST_PROXY=1",
    "MTAXI_ACCESS_LOGS=true",
    "MTAXI_ENABLE_LEGACY_CREATE_TOKEN=false",
    "MTAXI_MAINTENANCE_INTERVAL_SEC=30",
    "MTAXI_PENDING_ORDER_TTL_MIN=15",
    "MTAXI_MAINTENANCE_ORDER_LIMIT=100",
    "MTAXI_MAINTENANCE_PUSH_LIMIT=100",
    "MTAXI_TOKEN_SECRET=012345678901234567890123456789",
    "MTAXI_SMS_CODE_TTL_SEC=300",
    "MTAXI_SMS_RESEND_COOLDOWN_SEC=30",
    "MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC=60",
    "MTAXI_AUTH_RATE_LIMIT_MAX=20",
    "MTAXI_SMS_DEV_RETURN_CODE=false",
    "MTAXI_SMS_PROVIDER=http",
    "MTAXI_ALLOW_LOCAL_SMS=false",
    "MTAXI_SMS_HTTP_URL=https://sms.mtaxi.example/send",
    "MTAXI_SMS_HTTP_METHOD=POST",
    "MTAXI_SMS_HTTP_BODY_TEMPLATE={\"phone\":\"{{phone}}\",\"message\":\"{{message}}\"}",
    "MTAXI_SEED_ADMIN_ON_START=false",
    "MTAXI_STORE=postgres",
    "POSTGRES_PASSWORD=production-db-secret",
    "DATABASE_URL=postgres://mtaxi:production-db-secret@postgres:5432/mtaxi",
    "MTAXI_UPLOAD_DIR=/var/lib/mtaxi/uploads",
    "MTAXI_MAX_UPLOAD_BYTES=10485760",
    "MTAXI_UPLOAD_CACHE_MAX_AGE_SEC=2592000",
    "MTAXI_BACKUP_RETENTION_DAYS=30",
    "MTAXI_PAYMENT_PROVIDER=redirect",
    "MTAXI_ALLOW_LOCAL_PAYMENT=false",
    "MTAXI_PAYMENT_URL_TEMPLATE=https://pay.mtaxi.example/start?invoice={{paymentId}}&amount={{amount}}",
    "MTAXI_PAYMENT_CALLBACK_SECRET=payment-callback-secret-1",
    "MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY=false",
    "MTAXI_FCM_ENABLED=true",
    "MTAXI_ALLOW_SIMULATED_PUSH=false",
    "FIREBASE_SERVICE_ACCOUNT_JSON={\"project_id\":\"mtaxi-test\",\"client_email\":\"firebase-admin@test.example\",\"private_key\":\"-----BEGIN PRIVATE KEY-----\\nkey\\n-----END PRIVATE KEY-----\\n\"}",
    "",
  ].join("\n");
  fs.writeFileSync(envPath, validEnv);

  const valid = await validateProductionDeploy({ envFilePath: envPath });
  assert.equal(valid.ok, true);
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "VPS backup path"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "VPS backup service"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "VPS backend service"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "docker-compose.production.yml local binding"),
  );
  assert.ok(
    valid.checks.some((check) =>
      check.ok && check.name === "docker-compose.production.yml PostgreSQL persistence"
    ),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "docker-compose.production.yml upload volume"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "VPS monitor service"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "VPS backup timer"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "VPS monitor timer"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "VPS ops check"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "nginx reverse proxy"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "server.env.example production keys"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "server package production scripts"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "server package Node engine"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "server Dockerfile startup order"),
  );
  assert.ok(
    valid.checks.some((check) => check.ok && check.name === "server Docker build context"),
  );

  fs.writeFileSync(
    envPath,
    validEnv.replace(
      "DATABASE_URL=postgres://mtaxi:production-db-secret@postgres:5432/mtaxi",
      "DATABASE_URL=postgres://mtaxi:other-secret@postgres:5432/mtaxi",
    ),
  );
  const invalid = await validateProductionDeploy({ envFilePath: envPath });
  assert.equal(invalid.ok, false);
  assert.ok(
    invalid.checks.some((check) => !check.ok && check.name === "DATABASE_URL password"),
  );

  fs.writeFileSync(
    envPath,
    validEnv.replace(
      "DATABASE_URL=postgres://mtaxi:production-db-secret@postgres:5432/mtaxi",
      "DATABASE_URL=postgres://mtaxi:production-db-secret@localhost:5432/mtaxi",
    ),
  );
  const invalidDatabaseHost = await validateProductionDeploy({ envFilePath: envPath });
  assert.equal(invalidDatabaseHost.ok, false);
  assert.ok(
    invalidDatabaseHost.checks.some((check) => !check.ok && check.name === "DATABASE_URL host"),
  );

  fs.writeFileSync(envPath, `${validEnv}NODE_ENV=development\n`);
  const developmentNodeEnv = await validateProductionDeploy({ envFilePath: envPath });
  assert.equal(developmentNodeEnv.ok, false);
  assert.ok(
    developmentNodeEnv.checks.some((check) => !check.ok && check.name === "server.env NODE_ENV"),
  );

  const badBackupServicePath = path.join(tmpDir, "mtaxi-backup.service");
  fs.writeFileSync(
    badBackupServicePath,
    fs.readFileSync(
      path.join(__dirname, "../../deploy/systemd/mtaxi-backup.service"),
      "utf8",
    ).replace("/var/backups/mtaxi", "/tmp/mtaxi-backups"),
  );
  fs.writeFileSync(envPath, validEnv);
  const badBackupPath = await validateProductionDeploy({
    envFilePath: envPath,
    backupServicePath: badBackupServicePath,
  });
  assert.equal(badBackupPath.ok, false);
  assert.ok(
    badBackupPath.checks.some((check) => !check.ok && check.name === "VPS backup path"),
  );

  const badBackupCommandServicePath = path.join(tmpDir, "mtaxi-backup.bad-command.service");
  fs.writeFileSync(
    badBackupCommandServicePath,
    fs.readFileSync(
      path.join(__dirname, "../../deploy/systemd/mtaxi-backup.service"),
      "utf8",
    ).replace("backend npm run db:backup", "backend npm run monitor"),
  );
  const badBackupCommandService = await validateProductionDeploy({
    envFilePath: envPath,
    backupServicePath: badBackupCommandServicePath,
  });
  assert.equal(badBackupCommandService.ok, false);
  assert.ok(
    badBackupCommandService.checks.some((check) => !check.ok && check.name === "VPS backup service"),
  );

  const badBackendServicePath = path.join(tmpDir, "mtaxi-backend.service");
  fs.writeFileSync(
    badBackendServicePath,
    fs.readFileSync(
      path.join(__dirname, "../../deploy/systemd/mtaxi-backend.service"),
      "utf8",
    ).replace("/opt/mtaxi/docker-compose.production.yml", "/tmp/mtaxi/docker-compose.production.yml"),
  );
  const badBackendService = await validateProductionDeploy({
    envFilePath: envPath,
    backendServicePath: badBackendServicePath,
  });
  assert.equal(badBackendService.ok, false);
  assert.ok(
    badBackendService.checks.some((check) => !check.ok && check.name === "VPS backend service"),
  );

  fs.writeFileSync(
    envPath,
    validEnv.replace(
      "MTAXI_UPLOAD_DIR=/var/lib/mtaxi/uploads",
      "MTAXI_UPLOAD_DIR=/tmp/mtaxi-uploads",
    ),
  );
  const badUploadPath = await validateProductionDeploy({ envFilePath: envPath });
  assert.equal(badUploadPath.ok, false);
  assert.ok(
    badUploadPath.checks.some((check) =>
      !check.ok && check.name === "docker-compose.production.yml upload volume"
    ),
  );
  fs.writeFileSync(envPath, validEnv);

  const badComposePath = path.join(tmpDir, "docker-compose.production.yml");
  fs.writeFileSync(
    badComposePath,
    fs.readFileSync(path.join(__dirname, "../../docker-compose.production.yml"), "utf8")
      .replace('"127.0.0.1:8080:8080"', '"8080:8080"'),
  );
  const badComposeBinding = await validateProductionDeploy({
    envFilePath: envPath,
    composePath: badComposePath,
  });
  assert.equal(badComposeBinding.ok, false);
  assert.ok(
    badComposeBinding.checks.some((check) =>
      !check.ok && check.name === "docker-compose.production.yml local binding"
    ),
  );

  const badPostgresComposePath = path.join(tmpDir, "docker-compose.bad-postgres.yml");
  fs.writeFileSync(
    badPostgresComposePath,
    fs.readFileSync(path.join(__dirname, "../../docker-compose.production.yml"), "utf8")
      .replace("mtaxi_postgres_data:/var/lib/postgresql/data", "./tmp-pg:/var/lib/postgresql/data"),
  );
  const badPostgresCompose = await validateProductionDeploy({
    envFilePath: envPath,
    composePath: badPostgresComposePath,
  });
  assert.equal(badPostgresCompose.ok, false);
  assert.ok(
    badPostgresCompose.checks.some((check) =>
      !check.ok && check.name === "docker-compose.production.yml PostgreSQL persistence"
    ),
  );

  const badMonitorServicePath = path.join(tmpDir, "mtaxi-monitor.service");
  fs.writeFileSync(
    badMonitorServicePath,
    fs.readFileSync(
      path.join(__dirname, "../../deploy/systemd/mtaxi-monitor.service"),
      "utf8",
    ).replace(
      'MTAXI_MONITOR_BASE_URL="${MTAXI_MONITOR_BASE_URL:-$MTAXI_PUBLIC_BASE_URL}"',
      "MTAXI_MONITOR_BASE_URL=https://api.mtaxi.kz",
    ),
  );
  const badMonitorService = await validateProductionDeploy({
    envFilePath: envPath,
    monitorServicePath: badMonitorServicePath,
  });
  assert.equal(badMonitorService.ok, false);
  assert.ok(
    badMonitorService.checks.some((check) => !check.ok && check.name === "VPS monitor service"),
  );

  const badMonitorWorkdirPath = path.join(tmpDir, "mtaxi-monitor.bad-workdir.service");
  fs.writeFileSync(
    badMonitorWorkdirPath,
    fs.readFileSync(
      path.join(__dirname, "../../deploy/systemd/mtaxi-monitor.service"),
      "utf8",
    ).replace("WorkingDirectory=/opt/mtaxi/server", "WorkingDirectory=/opt/mtaxi"),
  );
  const badMonitorWorkdir = await validateProductionDeploy({
    envFilePath: envPath,
    monitorServicePath: badMonitorWorkdirPath,
  });
  assert.equal(badMonitorWorkdir.ok, false);
  assert.ok(
    badMonitorWorkdir.checks.some((check) => !check.ok && check.name === "VPS monitor service"),
  );

  const badBackupTimerPath = path.join(tmpDir, "mtaxi-backup.timer");
  fs.writeFileSync(
    badBackupTimerPath,
    fs.readFileSync(
      path.join(__dirname, "../../deploy/systemd/mtaxi-backup.timer"),
      "utf8",
    ).replace("OnCalendar=*-*-* 03:30:00", "OnCalendar=weekly"),
  );
  const badBackupTimer = await validateProductionDeploy({
    envFilePath: envPath,
    backupTimerPath: badBackupTimerPath,
  });
  assert.equal(badBackupTimer.ok, false);
  assert.ok(
    badBackupTimer.checks.some((check) => !check.ok && check.name === "VPS backup timer"),
  );

  const badMonitorTimerPath = path.join(tmpDir, "mtaxi-monitor.timer");
  fs.writeFileSync(
    badMonitorTimerPath,
    fs.readFileSync(
      path.join(__dirname, "../../deploy/systemd/mtaxi-monitor.timer"),
      "utf8",
    ).replace("OnUnitActiveSec=5min", "OnUnitActiveSec=60min"),
  );
  const badMonitorTimer = await validateProductionDeploy({
    envFilePath: envPath,
    monitorTimerPath: badMonitorTimerPath,
  });
  assert.equal(badMonitorTimer.ok, false);
  assert.ok(
    badMonitorTimer.checks.some((check) => !check.ok && check.name === "VPS monitor timer"),
  );

  const badOpsCheckPath = path.join(tmpDir, "ops_check.sh");
  fs.writeFileSync(
    badOpsCheckPath,
    `${fs.readFileSync(path.join(__dirname, "../../deploy/ops_check.sh"), "utf8")}\nnpm run db:restore\n`,
  );
  const badOpsCheck = await validateProductionDeploy({
    envFilePath: envPath,
    opsCheckPath: badOpsCheckPath,
  });
  assert.equal(badOpsCheck.ok, false);
  assert.ok(
    badOpsCheck.checks.some((check) => !check.ok && check.name === "VPS ops check"),
  );

  const badNginxConfigPath = path.join(tmpDir, "mtaxi-api.conf");
  fs.writeFileSync(
    badNginxConfigPath,
    fs.readFileSync(
      path.join(__dirname, "../../deploy/nginx/mtaxi-api.conf"),
      "utf8",
    ).replace("proxy_pass http://127.0.0.1:8080;", "proxy_pass http://127.0.0.1:9090;"),
  );
  const badNginxConfig = await validateProductionDeploy({
    envFilePath: envPath,
    nginxConfigPath: badNginxConfigPath,
  });
  assert.equal(badNginxConfig.ok, false);
  assert.ok(
    badNginxConfig.checks.some((check) => !check.ok && check.name === "nginx reverse proxy"),
  );

  const badEnvExamplePath = path.join(tmpDir, ".env.example");
  fs.writeFileSync(
    badEnvExamplePath,
    fs.readFileSync(path.join(__dirname, "../.env.example"), "utf8")
      .replace(/^MTAXI_FCM_ENABLED=.*\n/m, ""),
  );
  const badEnvExample = await validateProductionDeploy({
    envFilePath: envPath,
    envExamplePath: badEnvExamplePath,
  });
  assert.equal(badEnvExample.ok, false);
  assert.ok(
    badEnvExample.checks.some((check) =>
      !check.ok &&
      check.name === "server.env.example production keys" &&
      check.message.includes("MTAXI_FCM_ENABLED")
    ),
  );

  const packageJson = JSON.parse(fs.readFileSync(path.join(__dirname, "../package.json"), "utf8"));
  const badPackageJsonPath = path.join(tmpDir, "package.json");
  fs.writeFileSync(
    badPackageJsonPath,
    JSON.stringify({
      ...packageJson,
      engines: { node: ">=18" },
      scripts: {
        ...packageJson.scripts,
        "db:apply-schema": "psql \"$DATABASE_URL\" -f db/schema.sql",
      },
    }),
  );
  const badPackageJson = await validateProductionDeploy({
    envFilePath: envPath,
    packageJsonPath: badPackageJsonPath,
  });
  assert.equal(badPackageJson.ok, false);
  assert.ok(
    badPackageJson.checks.some((check) =>
      !check.ok &&
      check.name === "server package production scripts" &&
      check.message.includes("db:apply-schema")
    ),
  );
  assert.ok(
    badPackageJson.checks.some((check) => !check.ok && check.name === "server package Node engine"),
  );

  const badDockerfilePath = path.join(tmpDir, "Dockerfile");
  fs.writeFileSync(
    badDockerfilePath,
    fs.readFileSync(path.join(__dirname, "../Dockerfile"), "utf8")
      .replace(
        "npm run db:apply-schema && npm run preflight",
        "npm run preflight && npm run db:apply-schema",
      ),
  );
  const badDockerfile = await validateProductionDeploy({
    envFilePath: envPath,
    dockerfilePath: badDockerfilePath,
  });
  assert.equal(badDockerfile.ok, false);
  assert.ok(
    badDockerfile.checks.some((check) =>
      !check.ok && check.name === "server Dockerfile startup order"
    ),
  );

  const badDockerignorePath = path.join(tmpDir, ".dockerignore");
  fs.writeFileSync(
    badDockerignorePath,
    fs.readFileSync(path.join(__dirname, "../.dockerignore"), "utf8")
      .replace(/^\.env\n/m, ""),
  );
  const badDockerignore = await validateProductionDeploy({
    envFilePath: envPath,
    dockerignorePath: badDockerignorePath,
  });
  assert.equal(badDockerignore.ok, false);
  assert.ok(
    badDockerignore.checks.some((check) => !check.ok && check.name === "server Docker build context"),
  );
});

test("backend smoke script verifies core production endpoints", () => {
  const packageJson = JSON.parse(fs.readFileSync(path.join(__dirname, "../package.json"), "utf8"));
  const smokeScriptPath = path.join(__dirname, "../scripts/smoke_backend.js");
  const smokeScript = fs.readFileSync(smokeScriptPath, "utf8");
  const { isLocalBaseUrl } = require(smokeScriptPath);

  assert.equal(packageJson.scripts.smoke, "node scripts/smoke_backend.js");
  assert.match(smokeScript, /MTAXI_SMOKE_BASE_URL/);
  assert.match(smokeScript, /MTAXI_SMOKE_EXPECT_STORE/);
  assert.match(smokeScript, /MTAXI_SMOKE_ADMIN_PHONE/);
  assert.match(smokeScript, /MTAXI_SMOKE_PASSENGER_PHONE/);
  assert.match(smokeScript, /MTAXI_SMOKE_DRIVER_PHONE/);
  assert.match(smokeScript, /MTAXI_SMOKE_ALLOW_INSECURE_BASE_URL/);
  assert.match(smokeScript, /production smoke base URL must be HTTPS/);
  assert.match(smokeScript, /expected store/);
  assert.match(smokeScript, /postgres smoke requires applied schemaVersion/);
  assert.match(smokeScript, /\/livez/);
  assert.match(smokeScript, /\/readyz/);
  assert.match(smokeScript, /\/call\/getStoreHealth/);
  assert.match(smokeScript, /callBackend\(baseUrl, "getRuntimeSettings"/);
  assert.match(smokeScript, /callBackend\(baseUrl, "getBackendArchitectureStatus"/);
  assert.match(smokeScript, /backend architecture status must be backend-only/);
  assert.match(smokeScript, /backend architecture status must forbid Firebase/);
  assert.match(smokeScript, /callBackend\(baseUrl, "listCityTariffs"/);
  assert.match(smokeScript, /callBackend\(baseUrl, "listIntercityRoutes"/);
  assert.match(smokeScript, /callBackend\(baseUrl, "passwordLogin"/);
  assert.match(smokeScript, /callBackend\(baseUrl, "getSessionBootstrap"/);
  assert.match(smokeScript, /callBackend\(baseUrl, "adminListUsers"/);
  assert.match(smokeScript, /callBackend\(baseUrl, "getMoneyStats"/);
  assert.equal(isLocalBaseUrl("https://localhost:8080"), true);
  assert.equal(isLocalBaseUrl("https://127.0.0.1:8080"), true);
  assert.equal(isLocalBaseUrl("https://10.0.2.2:8080"), true);
  assert.equal(isLocalBaseUrl("https://100.64.0.1"), true);
  assert.equal(isLocalBaseUrl("https://100.127.255.255"), true);
  assert.equal(isLocalBaseUrl("https://100.128.0.1"), false);
  assert.equal(isLocalBaseUrl("https://169.254.1.10"), true);
  assert.equal(isLocalBaseUrl("https://172.16.0.10"), true);
  assert.equal(isLocalBaseUrl("https://172.31.255.10"), true);
  assert.equal(isLocalBaseUrl("https://172.32.0.10"), false);
  assert.equal(isLocalBaseUrl("https://[::1]:8080"), true);
  assert.equal(isLocalBaseUrl("https://[fd12::1]"), true);
  assert.equal(isLocalBaseUrl("https://[fe80::1]"), true);
  assert.equal(isLocalBaseUrl("https://api.mtaxi.example.kz"), false);
});

test("VPS postdeploy script uses server env URL and runs read-only gates", () => {
  const script = fs.readFileSync(
    path.join(__dirname, "../../scripts/check_vps_postdeploy.sh"),
    "utf8",
  );
  assert.match(script, /MTAXI_PUBLIC_BASE_URL/);
  assert.match(script, /server\/\.env/);
  assert.match(script, /env_public_base_url/);
  assert.match(script, /http:\/\/127\.0\.0\.1:8080/);
  assert.match(script, /MTAXI_POSTDEPLOY_BASE_URL/);
  assert.match(script, /MTAXI_POSTDEPLOY_EXPECT_STORE:-postgres/);
  assert.match(script, /mtaxi_validate_remote_backend_url/);
  assert.match(script, /deploy\/ops_check\.sh/);
  assert.match(script, /MTAXI_OPS_EXPECT_STORE="\$expect_store"/);
  assert.match(script, /npm run smoke/);
  assert.match(script, /MTAXI_SMOKE_EXPECT_STORE="\$expect_store"/);
  assert.doesNotMatch(script, /db:restore/);
  assert.doesNotMatch(script, /docker compose .* down/);
});

test("backend monitor script verifies production health without writes", () => {
  const packageJson = JSON.parse(fs.readFileSync(path.join(__dirname, "../package.json"), "utf8"));
  const monitorScript = fs.readFileSync(path.join(__dirname, "../scripts/monitor_backend.js"), "utf8");

  assert.equal(packageJson.scripts.monitor, "node scripts/monitor_backend.js");
  assert.match(monitorScript, /MTAXI_MONITOR_BASE_URL/);
  assert.match(monitorScript, /MTAXI_MONITOR_EXPECT_STORE/);
  assert.match(monitorScript, /MTAXI_MONITOR_ADMIN_PHONE/);
  assert.match(monitorScript, /MTAXI_MONITOR_ADMIN_PASSWORD/);
  assert.match(monitorScript, /MTAXI_MONITOR_ALLOW_INSECURE_BASE_URL/);
  assert.match(monitorScript, /isLocalBaseUrl/);
  assert.match(monitorScript, /production monitor base URL must be HTTPS/);
  assert.match(monitorScript, /postgres monitor requires applied schemaVersion/);
  assert.match(monitorScript, /\/livez/);
  assert.match(monitorScript, /\/readyz/);
  assert.match(monitorScript, /callBackend\(baseUrl, "getStoreHealth"/);
  assert.match(monitorScript, /callBackend\(baseUrl, "getRuntimeSettings"/);
  assert.match(monitorScript, /callBackend\(baseUrl, "getBackendArchitectureStatus"/);
  assert.match(monitorScript, /assertBackendOnlyArchitecture\(architecture\)/);
  assert.match(monitorScript, /callBackend\(baseUrl, "adminListUsers"/);
  assert.match(monitorScript, /callBackend\(baseUrl, "getMoneyStats"/);
  assert.match(monitorScript, /callBackend\(baseUrl, "adminListPushNotifications"/);
});

test("backend status script reports read-only backend-only summary", () => {
  const packageJson = JSON.parse(fs.readFileSync(path.join(__dirname, "../package.json"), "utf8"));
  const statusScript = fs.readFileSync(path.join(__dirname, "../scripts/backend_status.js"), "utf8");

  assert.equal(packageJson.scripts.status, "node scripts/backend_status.js");
  assert.match(statusScript, /MTAXI_STATUS_BASE_URL/);
  assert.match(statusScript, /\/livez/);
  assert.match(statusScript, /\/readyz/);
  assert.match(statusScript, /callBackend\(baseUrl, "getStoreHealth"/);
  assert.match(statusScript, /callBackend\(baseUrl, "getBackendArchitectureStatus"/);
  assert.match(statusScript, /assertBackendOnlyArchitecture\(architecture\)/);
  assert.match(statusScript, /firebaseAllowedOnlyFor/);
  assert.doesNotMatch(statusScript, /passwordLogin/);
  assert.doesNotMatch(statusScript, /adminListUsers/);
  assert.doesNotMatch(statusScript, /createPassengerOrder/);
});

test("backend status script runs against local server", async () => {
  const index = require("../src/index");
  const { main: runStatus } = require("../scripts/backend_status");
  const runtime = index.startServer({ port: 0, scheduler: null });
  const previousBaseUrl = process.env.MTAXI_STATUS_BASE_URL;
  try {
    await once(runtime.server, "listening");
    const { port: listenPort } = runtime.server.address();
    process.env.MTAXI_STATUS_BASE_URL = `http://127.0.0.1:${listenPort}`;
    await runStatus();
  } finally {
    if (previousBaseUrl === undefined) {
      delete process.env.MTAXI_STATUS_BASE_URL;
    } else {
      process.env.MTAXI_STATUS_BASE_URL = previousBaseUrl;
    }
    index.stopServer(runtime, "TEST");
    await once(runtime.server, "close");
  }
});

test("backend architecture smoke assertion forbids Firebase data domains", () => {
  const { assertBackendOnlyArchitecture } = require("../scripts/smoke_backend");

  assert.doesNotThrow(() => assertBackendOnlyArchitecture({
    architecture: "backend-only",
    firebaseAllowedOnlyFor: "FCM transport",
    firebaseForbiddenFor: ["Auth", "Firestore", "Cloud Functions", "Storage", "SMS"],
  }));
  assert.throws(
    () => assertBackendOnlyArchitecture({
      architecture: "backend-only",
      firebaseAllowedOnlyFor: "FCM transport",
      firebaseForbiddenFor: ["Auth", "Firestore", "Storage", "SMS"],
    }),
    /must forbid Firebase Cloud Functions/,
  );
  assert.throws(
    () => assertBackendOnlyArchitecture({
      architecture: "legacy-firebase",
      firebaseAllowedOnlyFor: "FCM transport",
      firebaseForbiddenFor: ["Auth", "Firestore", "Cloud Functions", "Storage", "SMS"],
    }),
    /backend-only/,
  );
});

test("backend smoke script runs against local server with auth checks", async () => {
  const index = require("../src/index");
  const { main: runSmoke } = require("../scripts/smoke_backend");
  const runtime = index.startServer({ port: 0, scheduler: null });
  const previousEnv = {
    MTAXI_SMOKE_BASE_URL: process.env.MTAXI_SMOKE_BASE_URL,
    MTAXI_SMOKE_EXPECT_STORE: process.env.MTAXI_SMOKE_EXPECT_STORE,
    MTAXI_SMOKE_ADMIN_PHONE: process.env.MTAXI_SMOKE_ADMIN_PHONE,
    MTAXI_SMOKE_ADMIN_PASSWORD: process.env.MTAXI_SMOKE_ADMIN_PASSWORD,
  };
  try {
    await once(runtime.server, "listening");
    const { port: listenPort } = runtime.server.address();
    const adminEnvForSmoke = {
      MTAXI_ADMIN_PHONE: "+77005550101",
      MTAXI_ADMIN_PASSWORD: "smoke-admin-password",
      MTAXI_ADMIN_NAME: "Smoke Admin",
      MTAXI_ADMIN_CITY: "Белоусовка",
    };
    const seeded = await seedAdmin({ env: adminEnvForSmoke });
    assert.equal(seeded.success, true);

    process.env.MTAXI_SMOKE_BASE_URL = `http://127.0.0.1:${listenPort}`;
    process.env.MTAXI_SMOKE_EXPECT_STORE = "json";
    process.env.MTAXI_SMOKE_ADMIN_PHONE = adminEnvForSmoke.MTAXI_ADMIN_PHONE;
    process.env.MTAXI_SMOKE_ADMIN_PASSWORD = adminEnvForSmoke.MTAXI_ADMIN_PASSWORD;

    await runSmoke();
  } finally {
    for (const [key, value] of Object.entries(previousEnv)) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
    index.stopServer(runtime, "TEST");
    await once(runtime.server, "close");
  }
});

test("backend monitor script runs against local server with admin checks", async () => {
  const index = require("../src/index");
  const { main: runMonitor } = require("../scripts/monitor_backend");
  const runtime = index.startServer({ port: 0, scheduler: null });
  const previousEnv = {
    MTAXI_MONITOR_BASE_URL: process.env.MTAXI_MONITOR_BASE_URL,
    MTAXI_MONITOR_EXPECT_STORE: process.env.MTAXI_MONITOR_EXPECT_STORE,
    MTAXI_MONITOR_ADMIN_PHONE: process.env.MTAXI_MONITOR_ADMIN_PHONE,
    MTAXI_MONITOR_ADMIN_PASSWORD: process.env.MTAXI_MONITOR_ADMIN_PASSWORD,
  };
  try {
    await once(runtime.server, "listening");
    const { port: listenPort } = runtime.server.address();
    const adminEnvForMonitor = {
      MTAXI_ADMIN_PHONE: "+77005550102",
      MTAXI_ADMIN_PASSWORD: "monitor-admin-password",
      MTAXI_ADMIN_NAME: "Monitor Admin",
      MTAXI_ADMIN_CITY: "Белоусовка",
    };
    const seeded = await seedAdmin({ env: adminEnvForMonitor });
    assert.equal(seeded.success, true);

    process.env.MTAXI_MONITOR_BASE_URL = `http://127.0.0.1:${listenPort}`;
    process.env.MTAXI_MONITOR_EXPECT_STORE = "json";
    process.env.MTAXI_MONITOR_ADMIN_PHONE = adminEnvForMonitor.MTAXI_ADMIN_PHONE;
    process.env.MTAXI_MONITOR_ADMIN_PASSWORD = adminEnvForMonitor.MTAXI_ADMIN_PASSWORD;

    await runMonitor();
  } finally {
    for (const [key, value] of Object.entries(previousEnv)) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
    index.stopServer(runtime, "TEST");
    await once(runtime.server, "close");
  }
});

test("backend backup and restore scripts are wired for production operations", () => {
  const packageJson = JSON.parse(fs.readFileSync(path.join(__dirname, "../package.json"), "utf8"));
  const backupScript = fs.readFileSync(path.join(__dirname, "../scripts/backup_backend.js"), "utf8");
  const restoreScript = fs.readFileSync(path.join(__dirname, "../scripts/restore_backend.js"), "utf8");
  const verifyScript = fs.readFileSync(path.join(__dirname, "../scripts/verify_backup_manifest.js"), "utf8");

  assert.equal(packageJson.scripts["db:backup"], "node scripts/backup_backend.js");
  assert.equal(packageJson.scripts["db:verify-backup"], "node scripts/verify_backup_manifest.js");
  assert.equal(packageJson.scripts["db:restore"], "node scripts/restore_backend.js");
  assert.match(backupScript, /pg_dump/);
  assert.match(backupScript, /MTAXI_BACKUP_DIR/);
  assert.match(backupScript, /MTAXI_UPLOAD_DIR/);
  assert.match(backupScript, /MTAXI_BACKUP_RETENTION_DAYS/);
  assert.match(backupScript, /pruneOldBackups/);
  assert.match(backupScript, /\^mtaxi-\(backup\|db\|uploads\)-/);
  assert.match(backupScript, /mtaxi-backup-\$\{stamp\}\.json/);
  assert.match(backupScript, /type: "mtaxi-backup"/);
  assert.match(backupScript, /version: 1/);
  assert.match(backupScript, /path\.basename\(dbDump\)/);
  assert.match(backupScript, /databaseDumpSha256: sha256File\(dbDump\)/);
  assert.match(backupScript, /path\.basename\(uploadsArchive\)/);
  assert.match(backupScript, /uploadsArchiveSha256: uploadsIncluded \? sha256File\(uploadsArchive\) : null/);
  assert.match(verifyScript, /MTaxi backup verification ok/);
  assert.match(verifyScript, /\$\{label\} sha256 mismatch/);
  assert.match(verifyScript, /\$\{fieldName\} must be a file name inside the backup directory/);
  assert.match(restoreScript, /pg_restore/);
  assert.match(restoreScript, /manifest is not a MTaxi backup/);
  assert.match(restoreScript, /MTAXI_RESTORE_DRY_RUN/);
  assert.match(restoreScript, /MTaxi restore dry run ok/);
  assert.match(restoreScript, /runQuiet\("pg_restore", \["--list", dbDump\]\)/);
  assert.match(restoreScript, /runQuiet\("tar", \["-tzf", resolvedArchive\]\)/);
  assert.match(restoreScript, /MTAXI_RESTORE_CONFIRM/);
  assert.match(restoreScript, /!dryRun && normalize\(process\.env\.MTAXI_RESTORE_CONFIRM\) !== "YES"/);
  assert.match(restoreScript, /MTAXI_RESTORE_DB_DUMP/);
  assert.match(restoreScript, /manifestDir: path\.dirname\(path\.resolve\(manifestPath\)\)/);
  assert.match(restoreScript, /resolveManifestPath\(dbDumpRaw, manifest\)/);
  assert.match(restoreScript, /fs\.promises\.rm\(uploadDir, \{ recursive: true, force: true \}\)/);
  assert.match(restoreScript, /"--strip-components=1"/);
  assert.match(restoreScript, /"-C", uploadDir/);
});

test("backup manifest verifier rejects corrupted or unsafe backup artifacts", () => {
  const { sha256File, verifyBackupManifest } = require("../scripts/verify_backup_manifest");
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-backup-verify-"));
  const dbDump = path.join(dir, "mtaxi-db-test.dump");
  const uploadsArchive = path.join(dir, "mtaxi-uploads-test.tar.gz");
  fs.writeFileSync(dbDump, "db");
  fs.writeFileSync(uploadsArchive, "uploads");
  const manifestPath = path.join(dir, "mtaxi-backup-test.json");
  fs.writeFileSync(
    manifestPath,
    JSON.stringify({
      type: "mtaxi-backup",
      version: 1,
      databaseDump: path.basename(dbDump),
      databaseDumpSha256: sha256File(dbDump),
      uploadsArchive: path.basename(uploadsArchive),
      uploadsArchiveSha256: sha256File(uploadsArchive),
    }),
  );

  const verified = verifyBackupManifest(manifestPath);
  assert.equal(verified.databaseDump, dbDump);
  assert.equal(verified.uploadsArchive, uploadsArchive);

  fs.writeFileSync(dbDump, "corrupted");
  assert.throws(() => verifyBackupManifest(manifestPath), /database dump sha256 mismatch/);

  fs.writeFileSync(
    manifestPath,
    JSON.stringify({
      type: "mtaxi-backup",
      version: 1,
      databaseDump: "../outside.dump",
      databaseDumpSha256: "0".repeat(64),
    }),
  );
  assert.throws(() => verifyBackupManifest(manifestPath), /databaseDump must be a file name/);
});

test("restore manifest helper accepts only MTaxi backup manifests", () => {
  const { readManifest, resolveManifestPath } = require("../scripts/restore_backend");
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-restore-manifest-"));
  const manifestPath = path.join(dir, "mtaxi-backup-test.json");
  fs.writeFileSync(
    manifestPath,
    JSON.stringify({
      type: "mtaxi-backup",
      version: 1,
      databaseDump: "mtaxi-db-test.dump",
      uploadsArchive: "mtaxi-uploads-test.tar.gz",
    }),
  );

  const manifest = readManifest(manifestPath);
  assert.equal(manifest.type, "mtaxi-backup");
  assert.equal(manifest.version, 1);
  assert.equal(resolveManifestPath(manifest.databaseDump, manifest), path.join(dir, "mtaxi-db-test.dump"));
  assert.equal(resolveManifestPath("/tmp/mtaxi-db.dump", manifest), "/tmp/mtaxi-db.dump");

  const wrongManifestPath = path.join(dir, "wrong.json");
  fs.writeFileSync(wrongManifestPath, JSON.stringify({ type: "other-backup" }));
  assert.throws(() => readManifest(wrongManifestPath), /not a MTaxi backup/);
});

test("backup retention removes only old MTaxi backup artifacts", async () => {
  const { pruneOldBackups, retentionDaysFromEnv } = require("../scripts/backup_backend");
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-backup-retention-"));
  const oldDate = new Date(Date.now() - 40 * 24 * 60 * 60 * 1000);
  const files = [
    "mtaxi-backup-old.json",
    "mtaxi-db-old.dump",
    "mtaxi-uploads-old.tar.gz",
    "mtaxi-backup-new.json",
    "other-old.txt",
  ];
  for (const file of files) {
    const filePath = path.join(dir, file);
    fs.writeFileSync(filePath, "x");
    if (file !== "mtaxi-backup-new.json") {
      fs.utimesSync(filePath, oldDate, oldDate);
    }
  }

  assert.equal(retentionDaysFromEnv(""), 30);
  assert.equal(retentionDaysFromEnv("7"), 7);
  assert.equal(retentionDaysFromEnv("0"), 0);
  assert.throws(() => retentionDaysFromEnv("0.5"), /non-negative integer/);
  assert.throws(() => retentionDaysFromEnv("-1"), /non-negative integer/);
  assert.throws(() => retentionDaysFromEnv("bad"), /non-negative integer/);
  const removed = await pruneOldBackups(dir, 30);

  assert.equal(removed, 3);
  assert.equal(fs.existsSync(path.join(dir, "mtaxi-backup-old.json")), false);
  assert.equal(fs.existsSync(path.join(dir, "mtaxi-db-old.dump")), false);
  assert.equal(fs.existsSync(path.join(dir, "mtaxi-uploads-old.tar.gz")), false);
  assert.equal(fs.existsSync(path.join(dir, "mtaxi-backup-new.json")), true);
  assert.equal(fs.existsSync(path.join(dir, "other-old.txt")), true);
});

test("JSON to PostgreSQL migration reports and verifies record counts without running on import", async () => {
  const migrateScript = fs.readFileSync(
    path.join(__dirname, "../scripts/migrate_json_to_postgres.js"),
    "utf8",
  );
  assert.match(migrateScript, /if \(require\.main === module\)/);
  assert.match(migrateScript, /module\.exports =/);
  assert.match(migrateScript, /countStoreRecords/);
  assert.match(migrateScript, /countPostgresRecords/);
  assert.match(migrateScript, /assertMigrationCounts/);
  assert.match(migrateScript, /PostgreSQL migration verification failed/);
  assert.match(migrateScript, /formatMigrationReport/);

  const counts = countStoreRecords({
    users: [{ id: "u1" }],
    smsCodes: [{ id: "s1" }],
    orders: [{ id: "o1" }, { id: "o2" }],
    payments: [{ id: "p1" }],
    withdrawals: [{ id: "w1" }],
    ledger: [{ id: "l1" }],
    chats: [{ id: "c1" }],
    chatMessages: [{ id: "m1" }],
    fcmTokens: [{ id: "t1" }],
    notifications: [{ id: "n1" }],
    notificationDeliveries: [{ id: "d1" }],
    pushDeliveryAcks: [{ id: "a1" }],
    cityPrices: [{ id: "city1" }],
    intercityRoutes: [{ id: "r1" }],
    settings: { orderRadiusKm: 10 },
    intercityTariff: { com: 10 },
    paymentSequence: 7,
    content: { about: { text: "ok" } },
    genericCollections: {
      bid: [{ id: "b1" }, { id: "b2" }],
      gruz: [{ id: "g1" }],
    },
    auditLogs: [{ id: "audit1" }],
  });
  assert.equal(counts.users, 1);
  assert.equal(counts.orders, 2);
  assert.equal(counts.settings, 3);
  assert.equal(counts.genericDocuments, 3);
  const report = formatMigrationReport(counts);
  assert.match(report, /users=1/);
  assert.match(report, /orders=2/);
  assert.match(report, /genericDocuments=3/);

  assert.doesNotThrow(() => assertMigrationCounts(counts, { ...counts, orders: 3 }));
  assert.throws(
    () => assertMigrationCounts(counts, { ...counts, orders: 1 }),
    /PostgreSQL migration verification failed: orders: source=2, postgres=1/,
  );

  const queriedSql = [];
  const postgresCounts = await countPostgresRecords({
    async query(sql) {
      queriedSql.push(sql);
      return { rows: [{ count: 7 }] };
    },
  });
  assert.equal(postgresCounts.users, 7);
  assert.equal(postgresCounts.orders, 7);
  assert.ok(queriedSql.some((sql) => sql.includes("FROM users")));
  assert.ok(queriedSql.some((sql) => sql.includes("FROM orders")));
});

test("seed admin creates or updates first administrator with hashed password", async () => {
  const result = await seedAdmin({
    env: {
      MTAXI_ADMIN_PHONE: "7012345678",
      MTAXI_ADMIN_PASSWORD: "secret123",
      MTAXI_ADMIN_NAME: "Первый Админ",
      MTAXI_ADMIN_CITY: "Белоусовка",
    },
    now: "2026-07-22T00:00:00.000Z",
  });
  assert.equal(result.success, true);
  assert.equal(result.phone, "+77012345678");

  const saved = readStore().users.find((user) => user.phone === "+77012345678");
  assert.ok(saved);
  assert.equal(saved.role, "admin");
  assert.equal(saved.roleState, "ADMIN");
  assert.equal(saved.password, undefined);
  assert.match(saved.passwordHash, /^scrypt\$/);

  const updated = await seedAdmin({
    env: {
      MTAXI_ADMIN_PHONE: "+77012345678",
      MTAXI_ADMIN_PASSWORD: "newsecret123",
      MTAXI_ADMIN_NAME: "Главный Админ",
    },
  });
  assert.equal(updated.code, "ADMIN_SEEDED_UPDATED");
  const users = readStore().users.filter((user) => user.phone === "+77012345678");
  assert.equal(users.length, 1);
  assert.equal(users[0].displayName, "Главный Админ");
});

test("passwordLogin upgrades legacy plain password to hash", async () => {
  withStore((store) => {
    const user = store.users.find((item) => item.id === "u_driver_7086362153");
    user.password = "123456";
    delete user.passwordHash;
  });

  const result = await passwordLogin({
    phone: "7086362153",
    password: "123456",
  });
  assert.equal(result.success, true);

  const stored = readStore().users.find((user) => user.id === "u_driver_7086362153");
  assert.equal(stored.password, undefined);
  assert.equal(isPasswordHash(stored.passwordHash), true);
  assert.equal(verifyPassword("123456", stored.passwordHash), true);
});

test("lookupUserByPhone returns safe public user without password", async () => {
  const found = await lookupUserByPhone({ phone: "7086362153" });
  assert.equal(found.success, true);
  assert.equal(found.found, true);
  assert.equal(found.user.id, "u_driver_7086362153");
  assert.equal(found.user.password, undefined);
  assert.equal(found.user.hasPassword, true);

  const missing = await lookupUserByPhone({ phone: "70000000999" });
  assert.equal(missing.success, true);
  assert.equal(missing.found, false);
  assert.equal(missing.user, null);
});

test("lookupUserByPhone normalizes legacy pending driver role state", async () => {
  await withStoreAsync(async (store) => {
    store.users.push({
      id: "u_legacy_pending_driver",
      phone: "+77051234567",
      password: "123456",
      displayName: "Legacy Driver",
      city: "Белоусовка",
      roleState: "DRIVER_PENDING_REVIEW",
      isDriver: true,
      statusDriver: "pending",
      driverRegistrationStatus: "pending_review",
    });
  });

  const found = await lookupUserByPhone({ phone: "7051234567" });
  assert.equal(found.success, true);
  assert.equal(found.found, true);
  assert.equal(found.user.roleState, "DRIVER_PENDING");
});

test("requestSmsCode creates local backend SMS code", async () => {
  const result = await requestSmsCode({ phone: "7052597368" });
  assert.equal(result.success, true);
  assert.equal(result.phone, "+77052597368");
  assert.match(result.smsCode, /^\d{4}$/);

  const stored = readStore().smsCodes || [];
  assert.equal(stored.length, 1);
  assert.equal(stored[0].phone, "+77052597368");
  assert.equal(stored[0].smsCode, undefined);
  assert.equal(stored[0].smsCodeHash, hashSmsCode("+77052597368", result.smsCode));
  assert.equal(stored[0].provider, "local");
});

test("verifySmsCode validates latest backend SMS code and marks it verified", async () => {
  process.env.MTAXI_SMS_RESEND_COOLDOWN_SEC = "0";
  const sent = await requestSmsCode({ phone: "7052597368" });
  const invalid = await verifySmsCode({
    phone: "7052597368",
    smsCode: "0000",
  });
  assert.equal(invalid.success, false);
  assert.equal(invalid.code, "SMS_CODE_INVALID");

  const verified = await verifySmsCode({
    phone: "7052597368",
    smsCode: sent.smsCode,
  });
  assert.equal(verified.success, true);
  assert.equal(verified.code, "SMS_CODE_VERIFIED");
  const stored = readStore().smsCodes || [];
  assert.equal(stored[0].status, "verified");
  delete process.env.MTAXI_SMS_RESEND_COOLDOWN_SEC;
});

test("verifySmsCode survives backend memory reset by using stored SMS record", async () => {
  const now = Date.now();
  await withStoreAsync(async (store) => {
    store.smsCodes = [{
      id: "sms_restart_test",
      phone: "+77051234567",
      smsCodeHash: hashSmsCode("+77051234567", "4321"),
      provider: "http",
      status: "sent",
      createdAt: new Date(now).toISOString(),
      expiresAt: new Date(now + 300000).toISOString(),
    }];
  });

  const result = await verifySmsCode({
    phone: "7051234567",
    smsCode: "4321",
  });
  assert.equal(result.success, true);
  assert.equal(result.code, "SMS_CODE_VERIFIED");

  const stored = readStore().smsCodes || [];
  assert.equal(stored[0].status, "verified");
  assert.match(stored[0].verifiedAt, /^\d{4}-\d{2}-\d{2}T/);
});

test("requestSmsCode rate limits immediate repeats", async () => {
  process.env.MTAXI_SMS_RESEND_COOLDOWN_SEC = "30";
  const first = await requestSmsCode({ phone: "7050001122" });
  const second = await requestSmsCode({ phone: "7050001122" });
  assert.equal(first.success, true);
  assert.equal(second.success, false);
  assert.equal(second.code, "SMS_RATE_LIMITED");
  assert.ok(second.retryAfterSec > 0);
  delete process.env.MTAXI_SMS_RESEND_COOLDOWN_SEC;
});

test("createSmsSession requires verified SMS and creates backend session for new phone", async () => {
  const blocked = await createSmsSession({ phone: "7011112233" });
  assert.equal(blocked.success, false);
  assert.equal(blocked.code, "SMS_CODE_NOT_VERIFIED");

  process.env.MTAXI_SMS_RESEND_COOLDOWN_SEC = "0";
  const sent = await requestSmsCode({ phone: "7011112233" });
  const verified = await verifySmsCode({
    phone: "7011112233",
    smsCode: sent.smsCode,
  });
  assert.equal(verified.success, true);
  const session = await createSmsSession({ phone: "7011112233" });
  assert.equal(session.success, true);
  assert.match(session.token, /^[^.]+\.[^.]+\.[^.]+$/);
  assert.equal(session.user.phone, "+77011112233");
  assert.equal(session.user.profileCompleted, false);
  assert.equal(session.user.hasPassword, false);
  assert.equal(
    readStore().smsCodes.find((item) => item.phone === "+77011112233").status,
    "consumed",
  );

  const reused = await createSmsSession({ phone: "7011112233" });
  assert.equal(reused.success, false);
  assert.equal(reused.code, "SMS_CODE_NOT_VERIFIED");

  const auth = await verifyBearerToken({
    get(name) {
      return name.toLowerCase() === "authorization"
        ? `Bearer ${session.token}`
        : "";
    },
  });
  const registered = await submitPassengerRegistrationAsync(
    {
      displayName: "Тест Пассажир",
      city: "Белоусовка",
      password: "123456",
    },
    auth,
  );
  assert.equal(registered.success, true);
  assert.equal(registered.user.hasPassword, true);
  assert.equal(registered.user.profileCompleted, true);
  delete process.env.MTAXI_SMS_RESEND_COOLDOWN_SEC;
});

test("verifyBearerToken resolves local user", async () => {
  const login = await passwordLogin({
    phone: "7052597368",
    password: "123456",
  });
  const auth = await verifyBearerToken({
    get(name) {
      return name.toLowerCase() === "authorization" ? `Bearer ${login.token}` : "";
    },
  });
  assert.equal(auth.user.phone, "+77052597368");
});

test("malformed bearer token is treated as unauthenticated", async () => {
  const req = {
    get(name) {
      return name.toLowerCase() === "authorization" ? "Bearer not-json.bad.sig" : "";
    },
  };
  const auth = await verifyBearerToken(req);
  assert.equal(auth, null);

  const result = await dispatchCall("me", {}, req);
  assert.equal(result.success, false);
  assert.equal(result.code, "UNAUTHENTICATED");
});

test("auth signatures use current MTAXI_TOKEN_SECRET", async () => {
  const previous = process.env.MTAXI_TOKEN_SECRET;
  try {
    process.env.MTAXI_TOKEN_SECRET = "first-secret-01234567890123456789";
    assert.equal(tokenSecret(), "first-secret-01234567890123456789");
    const firstHash = hashSmsCode("+77052597368", "1234");
    const login = await passwordLogin({
      phone: "7052597368",
      password: "123456",
    });

    process.env.MTAXI_TOKEN_SECRET = "second-secret-012345678901234567";
    assert.notEqual(hashSmsCode("+77052597368", "1234"), firstHash);
    const auth = await verifyBearerToken({
      get(name) {
        return name.toLowerCase() === "authorization" ? `Bearer ${login.token}` : "";
      },
    });
    assert.equal(auth, null);
  } finally {
    if (previous === undefined) {
      delete process.env.MTAXI_TOKEN_SECRET;
    } else {
      process.env.MTAXI_TOKEN_SECRET = previous;
    }
  }
});

test("calculateOrderQuoteFromData uses city tariff", () => {
  const result = calculateOrderQuoteFromData({
    type: "taxi",
    city: "Белоусовка",
    cityPrices: [{ title: "Белоусовка", priceDay: 1000, priceNight: 1500 }],
    intercityTariff: {},
    settings: { nightMultiplier: 1.5 },
    scheduledAt: "2026-07-22T08:00:00+05:00",
  });
  assert.equal(result.success, true);
  assert.equal(result.price, 1000);
});

test("getRuntimeSettings returns backend runtime settings aliases", async () => {
  const result = await getRuntimeSettingsAsync();
  assert.equal(result.success, true);
  assert.equal(result.settings.fallbackTaxiPrice, 800);
  assert.equal(result.settings.fallbackDeliveryPrice, 1200);
  assert.equal(result.settings.deliveryExtra, 400);
  assert.equal(result.settings.orderPendingTtlMin, 15);
  assert.equal(result.settings.intercityBasePrice, 500);
  assert.equal(result.settings.intercityPricePerKm, 130);
  assert.equal(result.settings.intercityMinPrice, 3000);
});

test("updateRuntimeSettings is admin-only and updates backend aliases", async () => {
  const passengerLogin = await passwordLogin({
    phone: "7052597368",
    password: "123456",
  });
  const denied = await updateRuntimeSettingsAsync(
    { fields: { orderCommissionPercent: 12 } },
    { user: passengerLogin.user },
  );
  assert.equal(denied.success, false);
  assert.equal(denied.code, "ADMIN_REQUIRED");

  const adminLogin = await passwordLogin({
    phone: "70000000000",
    password: "A7059012671!",
  });
  const updated = await updateRuntimeSettingsAsync(
    {
      fields: {
        orderCommissionPercent: "12",
        orderPendingTtlMin: "7",
        fallbackTaxiPrice: "900",
        intercityPricePerKm: "150",
      },
    },
    { user: adminLogin.user },
  );
  assert.equal(updated.success, true);
  assert.equal(updated.settings.orderCommissionPercent, 12);
  assert.equal(updated.settings.orderPendingTtlMin, 7);
  assert.equal(updated.settings.fallbackTaxiPrice, 900);
  assert.equal(updated.settings.intercityPricePerKm, 150);

  const store = readStore();
  assert.equal(store.settings.pendingOrderLifetimeMin, 7);
  assert.equal(store.settings.taxiFallbackPrice, 900);
  assert.equal(store.intercityTariff.pricePerKm, 150);
});

test("admin city tariff updates the price used by order quote", async () => {
  const adminLogin = await passwordLogin({
    phone: "70000000000",
    password: "A7059012671!",
  });
  const passengerLogin = await passwordLogin({
    phone: "7052597368",
    password: "123456",
  });

  const updated = await adminUpsertCityTariffAsync(
    {
      title: "Белоусовка",
      priceDay: "1350",
      priceNight: "1700",
      deliveryPrice: "1900",
    },
    { user: adminLogin.user },
  );
  assert.equal(updated.success, true);

  const list = await adminListCityTariffsAsync({}, { user: adminLogin.user });
  assert.equal(list.success, true);
  assert.equal(list.tariffs[0].priceDay, 1350);

  const passengerList = await listCityTariffsAsync({}, { user: passengerLogin.user });
  assert.equal(passengerList.success, true);
  assert.equal(passengerList.tariffs[0].title, "Белоусовка");

  const quote = await getOrderQuoteAsync(
    {
      type: "taxi",
      city: "Белоусовка",
      date: "2026-07-22T08:00:00+05:00",
    },
    { user: passengerLogin.user },
  );
  assert.equal(quote.success, true);
  assert.equal(quote.price, 1350);
});

test("admin intercity routes are listed and upserted from backend store", async () => {
  const adminLogin = await passwordLogin({
    phone: "70000000000",
    password: "A7059012671!",
  });
  const auth = { user: adminLogin.user };

  const initial = await adminListIntercityRoutesAsync({ query: "Усть" }, auth);
  assert.equal(initial.success, true);
  assert.equal(initial.routes.length, 1);
  assert.equal(initial.routes[0].tarif, 5000);

  const updated = await adminUpsertIntercityRouteAsync(
    {
      id: "route_belousovka_ust_kamenogorsk",
      ot: "Белоусовка",
      kuda: "Усть-Каменогорск",
      tarif: "5500",
      com: "11",
    },
    auth,
  );
  assert.equal(updated.success, true);
  assert.equal(updated.route.tarif, 5500);
  assert.equal(updated.route.com, 11);

  const store = readStore();
  assert.equal(store.intercityRoutes[0].tarif, 5500);
  assert.equal(store.auditLogs.at(-1).action, "adminUpsertIntercityRoute");
});

test("passenger can list intercity routes without admin permissions", async () => {
  const passengerLogin = await passwordLogin({
    phone: "7052597368",
    password: "123456",
  });
  const auth = { user: passengerLogin.user };

  const publicList = await listIntercityRoutesAsync({ query: "Усть" }, auth);
  assert.equal(publicList.success, true);
  assert.equal(publicList.routes.length, 1);
  assert.equal(publicList.routes[0].kuda, "Усть-Каменогорск");

  const adminList = await adminListIntercityRoutesAsync({}, auth);
  assert.equal(adminList.success, false);
  assert.equal(adminList.code, "ADMIN_REQUIRED");
});

test("admin generic collections are stored in backend only", async () => {
  const adminLogin = await passwordLogin({
    phone: "70000000000",
    password: "A7059012671!",
  });
  const auth = { user: adminLogin.user };

  const saved = await adminUpsertGenericDocumentAsync(
    {
      collection: "bid",
      fields: {
        price: 4500,
        status: 0,
        order: "order/test_order",
      },
    },
    auth,
  );
  assert.equal(saved.success, true);
  assert.equal(saved.document.price, 4500);
  assert.equal(saved.document.docPath.startsWith("bid/"), true);

  const listed = await adminListGenericCollectionAsync({ collection: "bid", query: "4500" }, auth);
  assert.equal(listed.success, true);
  assert.equal(listed.documents.length, 1);
  assert.equal(listed.documents[0].order, "order/test_order");

  const deleted = await adminDeleteGenericDocumentAsync(
    { collection: "bid", id: saved.document.id },
    auth,
  );
  assert.equal(deleted.success, true);
  const afterDelete = await adminListGenericCollectionAsync({ collection: "bid", query: "4500" }, auth);
  assert.equal(afterDelete.documents.length, 0);

  const passengerLogin = await passwordLogin({
    phone: "7052597368",
    password: "123456",
  });
  const denied = await adminListGenericCollectionAsync(
    { collection: "bid" },
    { user: passengerLogin.user },
  );
  assert.equal(denied.success, false);
  assert.equal(denied.code, "ADMIN_REQUIRED");
});

test("content documents are read publicly and updated by admin only", async () => {
  const publicDoc = await getContentDocumentAsync({ collection: "supportContacts" });
  assert.equal(publicDoc.success, true);
  assert.equal(publicDoc.document.whatsAppPhone, "+77000000000");

  const passengerLogin = await passwordLogin({
    phone: "7052597368",
    password: "123456",
  });
  const denied = await adminUpdateContentDocumentAsync(
    {
      collection: "tariffsContent",
      fields: { passengerTariffs: "Новый текст" },
    },
    { user: passengerLogin.user },
  );
  assert.equal(denied.success, false);
  assert.equal(denied.code, "ADMIN_REQUIRED");

  const adminLogin = await passwordLogin({
    phone: "70000000000",
    password: "A7059012671!",
  });
  const updated = await adminUpdateContentDocumentAsync(
    {
      collection: "tariffsContent",
      fields: {
        passengerTariffs: "Новый текст пассажира",
        ignored: "не сохранять",
      },
    },
    { user: adminLogin.user },
  );
  assert.equal(updated.success, true);
  assert.equal(updated.document.passengerTariffs, "Новый текст пассажира");
  assert.equal(updated.document.ignored, undefined);
});

test("adminSavePolitika saves politica content through backend alias", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const denied = await adminSavePolitikaAsync({ text: "Нет" }, { user: passenger });
  assert.equal(denied.success, false);
  assert.equal(denied.code, "ADMIN_REQUIRED");

  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const saved = await adminSavePolitikaAsync({ text: "Политика backend" }, { user: admin });
  assert.equal(saved.success, true);
  assert.equal(saved.document.text, "Политика backend");

  const loaded = await getContentDocumentAsync({ collection: "politika" });
  assert.equal(loaded.document.text, "Политика backend");
  assert.equal(readStore().auditLogs.at(-1).action, "adminUpdateContentDocument");
});

test("uploadFile stores authenticated media and returns public url", async () => {
  const login = await passwordLogin({
    phone: "7052597368",
    password: "123456",
  });
  const denied = await uploadFileAsync({ base64: Buffer.from("x").toString("base64") }, null);
  assert.equal(denied.success, false);
  assert.equal(denied.code, "UNAUTHENTICATED");

  const badType = await uploadFileAsync(
    {
      path: "profile/script.html",
      contentType: "text/html",
      base64: Buffer.from("<script>x</script>").toString("base64"),
    },
    { user: login.user },
  );
  assert.equal(badType.success, false);
  assert.equal(badType.code, "UPLOAD_TYPE_NOT_ALLOWED");

  const badSignature = await uploadFileAsync(
    {
      path: "profile/photo.jpg",
      contentType: "image/jpeg",
      base64: Buffer.from("not-a-jpeg").toString("base64"),
    },
    { user: login.user },
  );
  assert.equal(badSignature.success, false);
  assert.equal(badSignature.code, "UPLOAD_SIGNATURE_INVALID");

  const jpegBytes = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0xff, 0xd9]);
  const result = await uploadFileAsync(
    {
      path: "profile/photo.jpg",
      contentType: "image/jpeg",
      base64: jpegBytes.toString("base64"),
    },
    { user: login.user },
    { headers: { host: "localhost:8080" }, protocol: "http" },
  );
  assert.equal(result.success, true);
  assert.match(result.url, /^http:\/\/localhost:8080\/uploads\/.+\.jpg$/);
  const files = fs.readdirSync(process.env.MTAXI_UPLOAD_DIR);
  assert.equal(files.length, 1);
  assert.deepEqual(fs.readFileSync(path.join(process.env.MTAXI_UPLOAD_DIR, files[0])), jpegBytes);
});

test("publicBaseUrl uses configured URL or first forwarded proxy values", () => {
  const previous = process.env.MTAXI_PUBLIC_BASE_URL;
  try {
    process.env.MTAXI_PUBLIC_BASE_URL = "https://api.mtaxi.example/";
    assert.equal(
      publicBaseUrl({ headers: { host: "internal:8080" }, protocol: "http" }),
      "https://api.mtaxi.example",
    );

    delete process.env.MTAXI_PUBLIC_BASE_URL;
    assert.equal(
      publicBaseUrl({
        headers: {
          "x-forwarded-proto": "https,http",
          "x-forwarded-host": "api.mtaxi.kz,internal:8080",
          host: "internal:8080",
        },
        protocol: "http",
      }),
      "https://api.mtaxi.kz",
    );
  } finally {
    if (previous === undefined) {
      delete process.env.MTAXI_PUBLIC_BASE_URL;
    } else {
      process.env.MTAXI_PUBLIC_BASE_URL = previous;
    }
  }
});

test("geocoding proxies forward and reverse lookups", async () => {
  const originalFetch = global.fetch;
  const calls = [];
  global.fetch = async (url) => {
    calls.push(url.toString());
    if (url.toString().includes("/search?")) {
      return {
        ok: true,
        async json() {
          return [{ lat: "49.948", lon: "82.628", display_name: "Белоусовка" }];
        },
      };
    }
    return {
      ok: true,
      async json() {
        return {
          address: {
            village: "Белоусовка",
            road: "Ауэзова улица",
            house_number: "8",
          },
          display_name: "Белоусовка, Ауэзова улица, 8",
        };
      },
    };
  };
  try {
    const forward = await forwardGeocodeLookup({ query: "Белоусовка Ауэзова 8" });
    assert.equal(forward.success, true);
    assert.equal(forward.lat, 49.948);
    assert.equal(forward.lng, 82.628);

    const reverse = await reverseGeocodeLookup({ lat: 49.948, lng: 82.628 });
    assert.equal(reverse.success, true);
    assert.equal(reverse.address, "Ауэзова улица 8, Белоусовка");
    assert.equal(calls.length, 2);
  } finally {
    global.fetch = originalFetch;
  }
});

test("places autocomplete and details work without client API keys", async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: true,
    async json() {
      return [
        {
          lat: "49.948",
          lon: "82.628",
          display_name: "Белоусовка, Ауэзова улица, 8",
          place_id: "123",
        },
      ];
    },
  });
  try {
    const autocomplete = await placesAutocomplete({ input: "Ауэзова 8" });
    assert.equal(autocomplete.success, true);
    assert.equal(autocomplete.status, "OK");
    assert.equal(autocomplete.predictions[0].description, "Белоусовка, Ауэзова улица, 8");
    assert.equal(autocomplete.results[0].formatted_address, "Белоусовка, Ауэзова улица, 8");

    const details = await placeDetails({
      placeId: "123",
      address: "Белоусовка, Ауэзова улица, 8",
      lat: 49.948,
      lng: 82.628,
    });
    assert.equal(details.success, true);
    assert.equal(details.result.geometry.location.lat, 49.948);
    assert.equal(details.result.formatted_address, "Белоусовка, Ауэзова улица, 8");
  } finally {
    global.fetch = originalFetch;
  }
});

test("suggestAddressesLookup returns compact string items for Flutter web", async () => {
  const originalFetch = global.fetch;
  const calls = [];
  global.fetch = async (url) => {
    calls.push(url.toString());
    return {
      ok: true,
      async json() {
        return [
          {
            lat: "49.948",
            lon: "82.628",
            display_name: "Белоусовка, Ауэзова улица, 8",
            address: {
              village: "Белоусовка",
              road: "Ауэзова улица",
              house_number: "8",
            },
            place_id: "123",
          },
          {
            lat: "49.949",
            lon: "82.629",
            display_name: "Белоусовка, Ауэзова улица, 8",
            address: {
              village: "Белоусовка",
              road: "Ауэзова улица",
              house_number: "8",
            },
            place_id: "124",
          },
        ];
      },
    };
  };
  try {
    const result = await suggestAddressesLookup({
      query: "Ауэзова 8",
      city: "Белоусовка",
      limit: 5,
    });
    assert.equal(result.success, true);
    assert.deepEqual(result.items, ["Ауэзова улица 8, Белоусовка"]);
    assert.equal(result.results.length, 2);
    assert.match(calls[0], /%D0%90%D1%83%D1%8D%D0%B7%D0%BE%D0%B2%D0%B0/);
  } finally {
    global.fetch = originalFetch;
  }
});

test("routeLookup proxies OSRM route for mobile maps", async () => {
  const originalFetch = global.fetch;
  const calls = [];
  global.fetch = async (url) => {
    calls.push(url.toString());
    return {
      ok: true,
      async json() {
        return {
          routes: [
            {
              distance: 1250,
              duration: 180,
              geometry: {
                coordinates: [
                  [82.628, 49.948],
                  [82.629, 49.949],
                ],
              },
            },
          ],
        };
      },
    };
  };
  try {
    const result = await routeLookup({
      fromLat: 49.948,
      fromLng: 82.628,
      toLat: 49.949,
      toLng: 82.629,
    });
    assert.equal(result.success, true);
    assert.equal(result.distanceKm, 1.25);
    assert.equal(result.durationMinutes, 3);
    assert.deepEqual(result.coordinates[0], [82.628, 49.948]);
    assert.match(calls[0], /router\.project-osrm\.org\/route\/v1\/driving/);
  } finally {
    global.fetch = originalFetch;
  }
});

test("createPassengerOrder creates one active order and returns existing on second call", async () => {
  const login = await passwordLogin({
    phone: "7052597368",
    password: "123456",
  });
  const auth = { user: login.user };
  const first = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
  }, auth);
  assert.equal(first.success, true);
  assert.equal(first.created, true);
  const firstDetails = await getOrderDetailsAsync({ orderDocPath: first.orderDocPath }, auth);
  assert.equal(firstDetails.success, true);

  const second = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
  }, auth);
  assert.equal(second.success, true);
  assert.equal(second.existing, true);
  assert.equal(second.orderDocPath, first.orderDocPath);
});

test("createPassengerOrder accepts Flutter otCoords and kudaCoords", async () => {
  const login = await passwordLogin({
    phone: "7052597368",
    password: "123456",
  });
  const auth = { user: login.user };
  const created = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Ауэзова улица 8, Жетекши",
    kuda: "Ауэзова улица 12, Жетекши",
    otCoords: { lat: 52.3230675, lng: 77.1279019 },
    kudaCoords: { lat: 52.32385, lng: 77.12875 },
  }, auth);
  assert.equal(created.success, true);
  assert.equal(created.created, true);

  const details = await getOrderDetailsAsync({ orderDocPath: created.orderDocPath }, auth);
  assert.equal(details.success, true);
  assert.equal(details.order.fromPoint.latitude, 52.3230675);
  assert.equal(details.order.toPoint.longitude, 77.12875);
  assert.ok(details.order.distanceKm > 0);
});

test("acceptOrder rejects low balance and prevents second driver claim", async () => {
  withStore((store) => {
    store.users.push({
      id: "u_driver_low_balance",
      phone: "+77050000001",
      password: "123456",
      displayName: "Low Balance",
      city: "Белоусовка",
      roleState: "DRIVER_ONLINE",
      isDriver: true,
      statusDriver: "approved",
      balance: 250,
    });
    store.users.push({
      id: "u_driver_second",
      phone: "+77050000002",
      password: "123456",
      displayName: "Second Driver",
      city: "Белоусовка",
      roleState: "DRIVER_ONLINE",
      isDriver: true,
      statusDriver: "approved",
      balance: 10000,
    });
  });

  const passengerLogin = await passwordLogin({
    phone: "7052597368",
    password: "123456",
  });
  const passengerAuth = { user: passengerLogin.user };
  const order = await createPassengerOrderAsync({
    type: "intercity",
    city: "Белоусовка",
    ot: "Белоусовка",
    kuda: "Усть-Каменогорск",
    distanceKm: 35,
    date: "2026-07-22T06:00:00.000Z",
  }, passengerAuth);
  assert.equal(order.success, true);

  const lowBalance = await acceptOrderAsync(
    { orderDocPath: order.orderDocPath },
    { user: readStore().users.find((user) => user.id === "u_driver_low_balance") },
  );
  assert.equal(lowBalance.accepted, false);
  assert.equal(lowBalance.code, "INSUFFICIENT_DRIVER_BALANCE");
  assert.ok(lowBalance.requiredBalance > 250);

  const driverLogin = await passwordLogin({
    phone: "7086362153",
    password: "123456",
  });
  const accepted = await acceptOrderAsync({ orderDocPath: order.orderDocPath }, { user: driverLogin.user });
  assert.equal(accepted.success, true);
  assert.equal(accepted.accepted, true);
  assert.equal(accepted.status, 2);

  const second = await acceptOrderAsync(
    { orderDocPath: order.orderDocPath },
    { user: readStore().users.find((user) => user.id === "u_driver_second") },
  );
  assert.equal(second.accepted, false);
  assert.equal(second.code, "ORDER_ALREADY_ACCEPTED");
});

test("advanceDriverOrderStatus completes order and clears active flags", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const order = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
    date: "2026-07-22T06:00:00.000Z",
  }, { user: passenger });
  assert.equal(order.created, true);
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const accepted = await acceptOrderAsync({ orderDocPath: order.orderDocPath }, { user: driver });
  assert.equal(accepted.accepted, true);

  const activeOrderId = readStore().users.find((user) => user.id === "u_driver_7086362153").activeDriverOrderId;
  assert.ok(activeOrderId);

  const arrived = await advanceDriverOrderStatusAsync(
    { orderDocPath: `order/${activeOrderId}`, nextStatus: 3 },
    { user: driver },
  );
  assert.equal(arrived.success, true);
  assert.equal(arrived.status, 3);

  const completed = await advanceDriverOrderStatusAsync(
    { orderDocPath: `order/${activeOrderId}`, nextStatus: 5 },
    { user: readStore().users.find((user) => user.id === "u_driver_7086362153") },
  );
  assert.equal(completed.success, true);
  assert.equal(completed.status, 5);

  const store = readStore();
  assert.equal(store.users.find((user) => user.id === "u_driver_7086362153").hasActiveDriverOrder, false);
  assert.equal(store.users.find((user) => user.id === "u_passenger_7052597368").hasActivePassengerOrder, false);
});

test("cancelPassengerOrder closes order and refunds assigned driver commission", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const order = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
    date: "2026-07-22T06:00:00.000Z",
  }, { user: passenger });
  assert.equal(order.created, true);

  const beforeBalance = readStore().users.find((user) => user.id === driver.id).balance;
  const accepted = await acceptOrderAsync({ orderDocPath: order.orderDocPath }, { user: driver });
  assert.equal(accepted.accepted, true);
  assert.ok(accepted.chargedBalance > 0);

  const cancelled = await cancelPassengerOrderAsync({ orderDocPath: order.orderDocPath }, { user: passenger });
  assert.equal(cancelled.success, true);
  assert.equal(cancelled.status, 6);

  const store = readStore();
  assert.equal(store.users.find((user) => user.id === passenger.id).hasActivePassengerOrder, false);
  assert.equal(store.users.find((user) => user.id === driver.id).hasActiveDriverOrder, false);
  assert.equal(store.users.find((user) => user.id === driver.id).balance, beforeBalance);
});

test("cancelPassengerOrder refunds driver commission only once", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const order = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
    date: "2026-07-22T06:00:00.000Z",
  }, { user: passenger });
  assert.equal(order.created, true);

  const beforeBalance = readStore().users.find((user) => user.id === driver.id).balance;
  const accepted = await acceptOrderAsync({ orderDocPath: order.orderDocPath }, { user: driver });
  assert.equal(accepted.accepted, true);
  assert.ok(accepted.chargedBalance > 0);

  const firstCancel = await cancelPassengerOrderAsync({ orderDocPath: order.orderDocPath }, { user: passenger });
  const secondCancel = await cancelPassengerOrderAsync({ orderDocPath: order.orderDocPath }, { user: passenger });
  assert.equal(firstCancel.success, true);
  assert.equal(secondCancel.success, true);

  const store = readStore();
  const driverAfter = store.users.find((user) => user.id === driver.id);
  assert.equal(driverAfter.balance, beforeBalance);
  assert.equal(
    store.ledger.filter((entry) =>
      entry.orderId === order.orderDocPath.split("/").pop() &&
      entry.type === "order_commission_refund").length,
    1,
  );
});

test("expirePendingOrderIfNeeded expires stale open order and clears passenger state", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const order = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
  }, { user: passenger });
  assert.equal(order.created, true);

  withStore((store) => {
    const savedOrder = store.orders.find((item) => `order/${item.id}` === order.orderDocPath);
    savedOrder.createdAt = new Date(Date.now() - 16 * 60 * 1000).toISOString();
  });

  const expired = await expirePendingOrderIfNeededAsync(
    { orderDocPath: order.orderDocPath },
    { user: passenger },
  );
  assert.equal(expired.success, true);
  assert.equal(expired.expired, true);
  assert.equal(expired.status, 7);

  const store = readStore();
  assert.equal(store.orders.find((item) => `order/${item.id}` === order.orderDocPath).status, 7);
  assert.equal(store.users.find((user) => user.id === passenger.id).hasActivePassengerOrder, false);
});

test("getSessionBootstrap returns active compact order and clears stale refs", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const order = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
  }, { user: passenger });
  assert.equal(order.created, true);

  const active = await getSessionBootstrapAsync({}, { user: passenger });
  assert.equal(active.success, true);
  assert.equal(active.hasActivePassengerOrder, true);
  assert.equal(active.activePassengerOrder.orderDocPath, order.orderDocPath);
  assert.equal(active.activePassengerOrderStatus, 0);
  assert.equal(active.user.password, undefined);
  assert.equal(active.user.hasPassword, true);

  withStore((store) => {
    const savedOrder = store.orders.find((item) => `order/${item.id}` === order.orderDocPath);
    savedOrder.status = 6;
  });

  const cleared = await getSessionBootstrapAsync({}, { user: passenger });
  assert.equal(cleared.success, true);
  assert.equal(cleared.hasActivePassengerOrder, false);
  assert.equal(cleared.activePassengerOrderRef, null);
  assert.equal(readStore().users.find((user) => user.id === passenger.id).activePassengerOrderId, null);
});

test("session role scenarios are explicit for passenger, pending, approved and blocked users", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const approvedDriver = readStore().users.find((user) => user.id === "u_driver_7086362153");

  await withStoreAsync(async (store) => {
    store.users.push({
      id: "u_pending_driver",
      phone: "+77051230001",
      password: "123456",
      displayName: "Pending Driver",
      city: "Белоусовка",
      roleState: "DRIVER_PENDING_REVIEW",
      role: "driver",
      isDriver: true,
      statusDriver: "pending",
      driverRegistrationStatus: "pending_review",
      profileCompleted: true,
    });
    store.users.push({
      id: "u_blocked_passenger",
      phone: "+77051230002",
      password: "123456",
      displayName: "Blocked Passenger",
      city: "Белоусовка",
      roleState: "PASSENGER",
      role: "passenger",
      isDriver: false,
      blocked: true,
      profileCompleted: true,
    });
  });

  const store = readStore();
  const pendingDriver = store.users.find((user) => user.id === "u_pending_driver");
  const blockedPassenger = store.users.find((user) => user.id === "u_blocked_passenger");

  const passengerSession = await getSessionBootstrapAsync({}, { user: passenger });
  assert.equal(passengerSession.roleState, "PASSENGER");
  assert.equal(passengerSession.user.blocked, undefined);

  const pendingSession = await getSessionBootstrapAsync({}, { user: pendingDriver });
  assert.equal(pendingSession.roleState, "DRIVER_PENDING");
  assert.equal(pendingSession.user.driverRegistrationStatus, "pending_review");

  const driverSession = await getSessionBootstrapAsync({}, { user: approvedDriver });
  assert.equal(driverSession.roleState, "DRIVER_ONLINE");
  assert.equal(driverSession.user.statusDriver, "approved");

  const blockedLogin = await passwordLogin({ phone: "7051230002", password: "123456" });
  assert.equal(blockedLogin.success, true);
  assert.equal(blockedLogin.user.roleState, "BLOCKED");
  const blockedSession = await getSessionBootstrapAsync({}, { user: blockedPassenger });
  assert.equal(blockedSession.roleState, "BLOCKED");

  const blockedCreateOrder = await dispatchCall(
    "createPassengerOrder",
    { type: "taxi", city: "Белоусовка", ot: "Алтайская 12", kuda: "Переулок Степной 15" },
    bearerReq(blockedLogin.token),
  );
  assert.equal(blockedCreateOrder.success, false);
  assert.equal(blockedCreateOrder.code, "USER_BLOCKED");

  const blockedBootstrap = await dispatchCall(
    "getSessionBootstrap",
    {},
    bearerReq(blockedLogin.token),
  );
  assert.equal(blockedBootstrap.success, true);
  assert.equal(blockedBootstrap.roleState, "BLOCKED");
});

test("submitPassengerRegistration saves profile and password on backend", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const result = await submitPassengerRegistrationAsync({
    displayName: "Иван Пассажир",
    city: "Согра",
    photoUrl: "https://example.com/profile.jpg",
    phoneNumber: "7052597368",
    userId: "P-1",
    password: "7777",
  }, { user: passenger });

  assert.equal(result.success, true);
  assert.equal(result.user.password, undefined);
  const saved = readStore().users.find((user) => user.id === passenger.id);
  assert.equal(saved.displayName, "Иван Пассажир");
  assert.equal(saved.city, "Согра");
  assert.equal(saved.password, undefined);
  assert.equal(isPasswordHash(saved.passwordHash), true);
  assert.equal(verifyPassword("7777", saved.passwordHash), true);
  assert.equal(saved.profileCompleted, true);
  assert.equal(saved.roleState, "PASSENGER");
});

test("submitDriverRegistration stores pending driver profile", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const result = await submitDriverRegistrationAsync({
    firstName: "Иван",
    lastName: "Водитель",
    displayName: "Иван Водитель",
    phoneNumber: "7052597368",
    avtoImage: "https://example.com/car.jpg",
    techImage: "https://example.com/tech.jpg",
    birthDate: "1990-01-01T00:00:00.000Z",
    password: "8888",
    color: "Белый",
    gosNomer: "111AAA01",
    city: "Белоусовка",
    userId: "D-1",
  }, { user: passenger });

  assert.equal(result.success, true);
  assert.equal(result.driverRegistrationStatus, "pending_review");
  const saved = readStore().users.find((user) => user.id === passenger.id);
  assert.equal(saved.isDriver, true);
  assert.equal(saved.statusDriver, "pending");
  assert.equal(saved.driverOnLine, false);
  assert.equal(saved.gosNomer, "111AAA01");
  assert.equal(saved.roleState, "PASSENGER");
});

test("updateUserPreferences switches approved driver mode and rejects passenger driver mode", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const rejected = await updateUserPreferencesAsync({ targetRoleState: "DRIVER_ONLINE" }, { user: passenger });
  assert.equal(rejected.success, false);
  assert.equal(rejected.code, "DRIVER_PROFILE_REQUIRED");

  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const updated = await updateUserPreferencesAsync({
    targetRoleState: "DRIVER_ONLINE",
    city: "Согра",
    soundEnabled: false,
    themeMode: "dark",
    language: "kk",
    photoUrl: "https://example.test/profile.jpg",
    lastActiveAt: "2026-07-22T10:00:00.000Z",
    coords: {
      latitude: 49.948,
      longitude: 82.617,
    },
  }, { user: driver });
  assert.equal(updated.success, true);
  const saved = readStore().users.find((user) => user.id === driver.id);
  assert.equal(saved.roleState, "DRIVER_ONLINE");
  assert.equal(saved.driverOnLine, true);
  assert.equal(saved.city, "Согра");
  assert.equal(saved.soundEnabled, false);
  assert.equal(saved.themeMode, "dark");
  assert.equal(saved.language, "kk");
  assert.equal(saved.photoUrl, "https://example.test/profile.jpg");
  assert.equal(saved.lastActive, "2026-07-22T10:00:00.000Z");
  assert.deepEqual(saved.coords, { latitude: 49.948, longitude: 82.617 });
});

test("setPassword updates password with validation", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const short = await setPasswordAsync({ password: "123" }, { user: passenger });
  assert.equal(short.success, false);
  assert.equal(short.code, "PASSWORD_TOO_SHORT");

  const saved = await setPasswordAsync({ password: "1234567" }, { user: passenger });
  assert.equal(saved.success, true);
  assert.equal(saved.user.password, undefined);
  const stored = readStore().users.find((user) => user.id === passenger.id);
  assert.equal(stored.password, undefined);
  assert.equal(isPasswordHash(stored.passwordHash), true);
  assert.equal(verifyPassword("1234567", stored.passwordHash), true);
});

test("deleteCurrentAccountDeep removes user-owned backend data", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");

  const order = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
  }, { user: passenger });
  const accepted = await acceptOrderAsync({ orderDocPath: order.orderDocPath }, { user: driver });
  assert.equal(accepted.success, true);

  const payment = await createDriverTopUpPaymentAsync({ amount: 1000 }, { user: driver });
  assert.equal(payment.success, true);
  const withdrawal = await createDriverWithdrawalAsync({
    amount: 500,
    cardNumber: "4400430043004300",
  }, { user: driver });
  assert.equal(withdrawal.success, true);
  await requestSmsCode({ phone: driver.phone });
  await addFcmTokenAsync({
    userDocPath: `users/${driver.id}`,
    fcmToken: "token-delete-driver",
    deviceType: "Android",
  }, { user: driver });
  const chat = await ensureSupportChatAsync({}, { user: driver });
  await sendSupportChatMessageAsync({ chatDocPath: chat.chatPath, text: "Удалить меня" }, { user: driver });

  const deleted = await deleteCurrentAccountDeepAsync({}, { user: driver });
  assert.equal(deleted.success, true);
  assert.equal(deleted.removed.users, 1);
  assert.equal(deleted.removed.orders, 1);
  assert.equal(deleted.removed.payments, 1);
  assert.equal(deleted.removed.withdrawals, 1);
  assert.equal(deleted.removed.ledger, 3);
  assert.equal(deleted.removed.fcmTokens, 1);
  assert.equal(deleted.removed.chats, 1);
  assert.equal(deleted.removed.chatMessages, 1);
  assert.equal(deleted.removed.smsCodes, 1);

  const store = readStore();
  assert.equal(store.users.some((user) => user.id === driver.id), false);
  assert.equal(store.orders.some((item) => item.driverId === driver.id), false);
  assert.equal(store.withdrawals.some((item) => item.userId === driver.id), false);
  assert.equal(store.users.find((user) => user.id === passenger.id).hasActivePassengerOrder, false);
  assert.equal(store.auditLogs.some((log) => log.action === "deleteCurrentAccountDeep"), true);

  const denied = await deleteCurrentAccountDeepAsync({}, { user: admin });
  assert.equal(denied.success, true);
  assert.equal(readStore().users.some((user) => user.id === admin.id), false);
});

test("adminUpdateUserDocument requires admin and writes audit log", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const rejected = await adminUpdateUserDocumentAsync({
    userDocPath: "users/u_passenger_7052597368",
    fields: { firstName: "Не админ" },
  }, { user: passenger });
  assert.equal(rejected.success, false);
  assert.equal(rejected.code, "ADMIN_REQUIRED");

  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const updated = await adminUpdateUserDocumentAsync({
    userDocPath: "users/u_passenger_7052597368",
    fields: {
      firstName: "Петр",
      lastName: "Пассажир",
      phone_number: "7052597368",
      objectField: { __delete: true },
    },
  }, { user: admin });
  assert.equal(updated.success, true);
  assert.equal(updated.user.displayName, "Петр Пассажир");
  const store = readStore();
  assert.equal(store.auditLogs.length, 1);
  assert.equal(store.auditLogs[0].action, "adminUpdateUserDocument");
});

test("admin can approve and reject vehicle photo deletion", async () => {
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const driverPath = "users/u_driver_7086362153";

  withStore((store) => {
    const driver = store.users.find((user) => user.id === "u_driver_7086362153");
    driver.avtoImage = "https://example.test/car.jpg";
    driver.autoImage = "https://example.test/car-old.jpg";
    driver.photoUrl = "https://example.test/profile.jpg";
    driver.vehiclePhotoDeleteRequestStatus = "pending_admin_approval";
  });

  const denied = await approveVehiclePhotoDeletionAsync({ userDocPath: driverPath }, { user: passenger });
  assert.equal(denied.success, false);
  assert.equal(denied.code, "ADMIN_REQUIRED");

  const rejected = await rejectVehiclePhotoDeletionAsync({ userDocPath: driverPath }, { user: admin });
  assert.equal(rejected.success, true);
  assert.equal(rejected.user.vehiclePhotoDeleteRequestStatus, "rejected");
  assert.equal(rejected.user.avtoImage, "https://example.test/car.jpg");

  withStore((store) => {
    const driver = store.users.find((user) => user.id === "u_driver_7086362153");
    driver.vehiclePhotoDeleteRequestStatus = "pending_admin_approval";
  });

  const approved = await approveVehiclePhotoDeletionAsync({ userDocPath: driverPath }, { user: admin });
  assert.equal(approved.success, true);
  assert.equal(approved.user.vehiclePhotoDeleteRequestStatus, "approved");
  assert.equal(approved.user.avtoImage, "");
  assert.equal(approved.user.autoImage, "");
  assert.equal(approved.user.photoUrl, "https://example.test/profile.jpg");

  const actions = readStore().auditLogs.map((log) => log.action);
  assert.equal(actions.includes("rejectVehiclePhotoDeletion"), true);
  assert.equal(actions.includes("approveVehiclePhotoDeletion"), true);
});

test("adminListUsers returns public users with search", async () => {
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const denied = await adminListUsersAsync({}, { user: readStore().users.find((user) => user.id === "u_passenger_7052597368") });
  assert.equal(denied.success, false);
  assert.equal(denied.code, "ADMIN_REQUIRED");

  const result = await adminListUsersAsync({ query: "705259", role: "passenger" }, { user: admin });
  assert.equal(result.success, true);
  assert.equal(result.users.length, 1);
  assert.equal(result.users[0].id, "u_passenger_7052597368");
  assert.equal(result.users[0].password, undefined);
  assert.equal(result.users[0].hasPassword, true);
  assert.equal(result.users[0].userDocPath, "users/u_passenger_7052597368");
});

test("adminListAuditLogs is admin-only, searchable and newest first", async () => {
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const denied = await adminListAuditLogsAsync({}, { user: passenger });
  assert.equal(denied.success, false);
  assert.equal(denied.code, "ADMIN_REQUIRED");

  await adminUpdateUserDocumentAsync({
    userDocPath: "users/u_passenger_7052597368",
    fields: { firstName: "Аудит" },
  }, { user: admin });
  await adminTopUpDriverBalanceAsync({
    userDocPath: "users/u_driver_7086362153",
    targetBalance: 10500,
  }, { user: admin });

  const result = await adminListAuditLogsAsync({ limit: 10 }, { user: admin });
  assert.equal(result.success, true);
  assert.equal(result.logs.length, 2);
  assert.equal(result.logs[0].action, "adminTopUpDriverBalance");
  assert.equal(result.logs[1].action, "adminUpdateUserDocument");

  const filtered = await adminListAuditLogsAsync({
    action: "adminUpdateUserDocument",
    query: "705259",
  }, { user: admin });
  assert.equal(filtered.success, true);
  assert.equal(filtered.logs.length, 1);
  assert.equal(filtered.logs[0].target, "users/u_passenger_7052597368");
});

test("admin driver status, block, unblock and balance actions work", async () => {
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const driverPath = "users/u_driver_7086362153";

  const approved = await approveDriverAsync({ userDocPath: driverPath, statusDriver: "approved" }, { user: admin });
  assert.equal(approved.success, true);
  assert.equal(approved.user.statusDriver, "approved");

  const blocked = await blockDriverAsync({ userDocPath: driverPath }, { user: admin });
  assert.equal(blocked.success, true);
  assert.equal(blocked.user.blocked, true);

  const unblocked = await unblockDriverAsync({ userDocPath: driverPath }, { user: admin });
  assert.equal(unblocked.success, true);
  assert.equal(unblocked.user.blocked, false);

  const balance = await adminTopUpDriverBalanceAsync({ userDocPath: driverPath, targetBalance: 4500 }, { user: admin });
  assert.equal(balance.success, true);
  assert.equal(balance.balance, 4500);
  assert.equal(readStore().auditLogs.length, 4);
});

test("admin can create driver and update city and order delay", async () => {
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const created = await adminCreateDriverAsync({
    fields: {
      phone_number: "7057778899",
      firstName: "Иван",
      lastName: "Водитель",
      city: "Белоусовка",
      gosNomer: "111AAA16",
      color: "Белый",
      balance: 500,
    },
  }, { user: admin });
  assert.equal(created.success, true);
  assert.equal(created.user.isDriver, true);
  assert.equal(created.user.phone, "+77057778899");

  const city = await adminUpdateDriverCityAsync({
    userDocPath: created.userDocPath,
    city: "Согра",
  }, { user: admin });
  assert.equal(city.success, true);
  assert.equal(city.user.city, "Согра");

  const delay = await adminUpdateDriverOrderDelayAsync({
    userDocPath: created.userDocPath,
    orderDelaySeconds: 15,
  }, { user: admin });
  assert.equal(delay.success, true);
  assert.equal(delay.user.orderDelaySeconds, 15);
});

test("admin can create passenger through backend", async () => {
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const created = await adminCreatePassengerAsync({
    fields: {
      phone_number: "7051112233",
      firstName: "Анна",
      lastName: "Пассажир",
      city: "Согра",
      password: "123456",
      vip: true,
    },
  }, { user: admin });
  assert.equal(created.success, true);
  assert.equal(created.user.isDriver, false);
  assert.equal(created.user.role, "passenger");
  assert.equal(created.user.phone, "+77051112233");
  assert.equal(created.user.password, undefined);
  assert.equal(created.user.hasPassword, true);

  const saved = readStore().users.find((user) => user.id === "u_passenger_77051112233");
  assert.equal(saved.displayName, "Анна Пассажир");
  assert.equal(saved.city, "Согра");
  assert.equal(saved.vip, true);
  assert.equal(verifyPassword("123456", saved.passwordHash), true);
});

test("adminManageOrder completes, cancels and reopens orders with active refs", async () => {
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const order = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
    date: "2026-07-22T06:00:00.000Z",
  }, { user: passenger });
  assert.equal(order.created, true);
  const accepted = await acceptOrderAsync({ orderDocPath: order.orderDocPath }, { user: driver });
  assert.equal(accepted.accepted, true);

  const completed = await adminManageOrderAsync({ orderDocPath: order.orderDocPath, action: "complete" }, { user: admin });
  assert.equal(completed.success, true);
  assert.equal(completed.status, 5);
  assert.equal(readStore().users.find((user) => user.id === driver.id).hasActiveDriverOrder, false);

  const reopened = await adminManageOrderAsync({ orderDocPath: order.orderDocPath, action: "reopen" }, { user: admin });
  assert.equal(reopened.success, true);
  assert.equal(reopened.status, 0);
  assert.equal(readStore().users.find((user) => user.id === passenger.id).hasActivePassengerOrder, true);

  const cancelled = await adminManageOrderAsync({ orderDocPath: order.orderDocPath, action: "cancel" }, { user: admin });
  assert.equal(cancelled.success, true);
  assert.equal(cancelled.status, 6);
  assert.equal(readStore().users.find((user) => user.id === passenger.id).hasActivePassengerOrder, false);
});

test("driver top-up payment is created pending and confirmed idempotently", async () => {
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const before = driver.balance;

  const payment = await createDriverTopUpPaymentAsync({ amount: 2500 }, { user: driver });
  assert.equal(payment.success, true);
  assert.equal(payment.paymentStatus, "pending");
  assert.match(payment.paymentUrl, /local-payment/);

  const pending = await getDriverTopUpPaymentStatusAsync({ paymentId: payment.paymentId }, { user: driver });
  assert.equal(pending.success, true);
  assert.equal(pending.paymentStatus, "pending");

  const confirmed = await confirmDriverTopUpPaymentAsync({ paymentId: payment.paymentId }, { user: admin });
  assert.equal(confirmed.success, true);
  assert.equal(confirmed.paymentStatus, "success");
  assert.equal(confirmed.balance, before + 2500);

  const secondConfirm = await confirmDriverTopUpPaymentAsync({ paymentId: payment.paymentId }, { user: admin });
  assert.equal(secondConfirm.success, true);
  assert.equal(secondConfirm.code, "PAYMENT_ALREADY_APPLIED");
  assert.equal(readStore().users.find((user) => user.id === driver.id).balance, before + 2500);
});

test("driver top-up payment uses configured public backend url", async () => {
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const previous = process.env.MTAXI_PUBLIC_BASE_URL;
  process.env.MTAXI_PUBLIC_BASE_URL = "https://api.mtaxi.example/";
  try {
    const payment = await createDriverTopUpPaymentAsync({ amount: 1200 }, { user: driver });
    assert.equal(payment.success, true);
    assert.match(payment.paymentUrl, /^https:\/\/api\.mtaxi\.example\/local-payment\/kassa24_/);
  } finally {
    if (previous == null) {
      delete process.env.MTAXI_PUBLIC_BASE_URL;
    } else {
      process.env.MTAXI_PUBLIC_BASE_URL = previous;
    }
  }
});

test("driver top-up payment can use configured provider redirect url", async () => {
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const previousProvider = process.env.MTAXI_PAYMENT_PROVIDER;
  const previousTemplate = process.env.MTAXI_PAYMENT_URL_TEMPLATE;
  process.env.MTAXI_PAYMENT_PROVIDER = "redirect";
  process.env.MTAXI_PAYMENT_URL_TEMPLATE =
    "https://pay.example/start?invoice={{paymentId}}&amount={{amount}}&phone={{phone}}";
  try {
    const payment = await createDriverTopUpPaymentAsync({ amount: 1500 }, { user: driver });
    assert.equal(payment.success, true);
    assert.match(payment.paymentUrl, /^https:\/\/pay\.example\/start\?invoice=kassa24_/);
    assert.match(payment.paymentUrl, /amount=1500/);
    assert.match(payment.paymentUrl, /phone=%2B77086362153/);
    const saved = readStore().payments.find((item) => item.paymentId === payment.paymentId);
    assert.equal(saved.provider, "redirect");
  } finally {
    if (previousProvider == null) {
      delete process.env.MTAXI_PAYMENT_PROVIDER;
    } else {
      process.env.MTAXI_PAYMENT_PROVIDER = previousProvider;
    }
    if (previousTemplate == null) {
      delete process.env.MTAXI_PAYMENT_URL_TEMPLATE;
    } else {
      process.env.MTAXI_PAYMENT_URL_TEMPLATE = previousTemplate;
    }
  }
});

test("driver top-up payment can create Kassa24 payment through backend", async () => {
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const previousProvider = process.env.MTAXI_PAYMENT_PROVIDER;
  const previousLogin = process.env.MTAXI_KASSA24_LOGIN;
  const previousPassword = process.env.MTAXI_KASSA24_PASSWORD;
  const previousMerchantId = process.env.MTAXI_KASSA24_MERCHANT_ID;
  const previousFetch = global.fetch;
  let requestBody;
  let authHeader;
  process.env.MTAXI_PAYMENT_PROVIDER = "kassa24";
  process.env.MTAXI_KASSA24_LOGIN = "merchant-login";
  process.env.MTAXI_KASSA24_PASSWORD = "merchant-password";
  process.env.MTAXI_KASSA24_MERCHANT_ID = "12345";
  global.fetch = async (_url, options = {}) => {
    requestBody = JSON.parse(options.body);
    authHeader = options.headers.authorization;
    return {
      ok: true,
      status: 200,
      async json() {
        return {
          id: "pult-payment-1",
          url: "https://ecommerce.pult24.kz/payment/pult-payment-1",
        };
      },
    };
  };
  try {
    const payment = await createDriverTopUpPaymentAsync({ amount: 1500 }, { user: driver });
    assert.equal(payment.success, true);
    assert.equal(payment.paymentUrl, "https://ecommerce.pult24.kz/payment/pult-payment-1");
    assert.equal(requestBody.amount, 150000);
    assert.equal(requestBody.orderId, payment.paymentId);
    assert.equal(requestBody.merchantId, "12345");
    assert.match(requestBody.callbackUrl, /\/payments\/kassa24\/callback$/);
    assert.match(requestBody.returnUrl, /kassa24PaymentCallback=1/);
    assert.match(authHeader, /^Basic /);
    const saved = readStore().payments.find((item) => item.paymentId === payment.paymentId);
    assert.equal(saved.provider, "kassa24");
    assert.equal(saved.providerPaymentId, "pult-payment-1");
  } finally {
    global.fetch = previousFetch;
    if (previousProvider == null) delete process.env.MTAXI_PAYMENT_PROVIDER;
    else process.env.MTAXI_PAYMENT_PROVIDER = previousProvider;
    if (previousLogin == null) delete process.env.MTAXI_KASSA24_LOGIN;
    else process.env.MTAXI_KASSA24_LOGIN = previousLogin;
    if (previousPassword == null) delete process.env.MTAXI_KASSA24_PASSWORD;
    else process.env.MTAXI_KASSA24_PASSWORD = previousPassword;
    if (previousMerchantId == null) delete process.env.MTAXI_KASSA24_MERCHANT_ID;
    else process.env.MTAXI_KASSA24_MERCHANT_ID = previousMerchantId;
  }
});

test("driver top-up payment reuses idempotency key", async () => {
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const first = await createDriverTopUpPaymentAsync({
    amount: 1500,
    idempotencyKey: "topup-key-1",
  }, { user: driver });
  const repeated = await createDriverTopUpPaymentAsync({
    amount: 1500,
    idempotencyKey: "topup-key-1",
  }, { user: driver });
  const conflict = await createDriverTopUpPaymentAsync({
    amount: 2500,
    idempotencyKey: "topup-key-1",
  }, { user: driver });

  assert.equal(first.success, true);
  assert.equal(repeated.success, true);
  assert.equal(repeated.reused, true);
  assert.equal(repeated.paymentId, first.paymentId);
  assert.equal(conflict.success, false);
  assert.equal(conflict.code, "PAYMENT_IDEMPOTENCY_CONFLICT");
  assert.equal(readStore().payments.length, 1);
});

test("kassa24 callback applies top-up once and validates secret", async () => {
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const before = driver.balance;
  const payment = await createDriverTopUpPaymentAsync({ amount: 3000 }, { user: driver });
  assert.equal(payment.success, true);

  process.env.MTAXI_PAYMENT_CALLBACK_SECRET = "secret-1";
  const badSecret = await handleDriverTopUpPaymentCallbackAsync({
    paymentId: payment.paymentId,
    status: "paid",
  }, {
    get(name) {
      return name.toLowerCase() === "x-mtaxi-payment-secret" ? "wrong" : "";
    },
  });
  assert.equal(badSecret.success, false);
  assert.equal(badSecret.code, "PAYMENT_CALLBACK_FORBIDDEN");

  const confirmed = await handleDriverTopUpPaymentCallbackAsync({
    payment_id: payment.paymentId,
    status: "paid",
  }, {
    get(name) {
      return name.toLowerCase() === "x-mtaxi-payment-secret" ? "secret-1" : "";
    },
  });
  assert.equal(confirmed.success, true);
  assert.equal(confirmed.paymentStatus, "success");
  assert.equal(confirmed.balance, before + 3000);

  const second = await handleDriverTopUpPaymentCallbackAsync({
    paymentId: payment.paymentId,
    result: "success",
  }, {
    get(name) {
      return name.toLowerCase() === "x-kassa24-secret" ? "secret-1" : "";
    },
  });
  assert.equal(second.success, true);
  assert.equal(second.code, "PAYMENT_ALREADY_APPLIED");
  assert.equal(readStore().users.find((user) => user.id === driver.id).balance, before + 3000);
  delete process.env.MTAXI_PAYMENT_CALLBACK_SECRET;
});

test("payment callback body secret is disabled unless explicitly allowed", async () => {
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const payment = await createDriverTopUpPaymentAsync({ amount: 1000 }, { user: driver });
  process.env.MTAXI_PAYMENT_CALLBACK_SECRET = "secret-2";

  const blocked = await handleDriverTopUpPaymentCallbackAsync({
    paymentId: payment.paymentId,
    status: "paid",
    secret: "secret-2",
  });
  assert.equal(blocked.success, false);
  assert.equal(blocked.code, "PAYMENT_CALLBACK_FORBIDDEN");

  process.env.MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY = "true";
  const allowed = await handleDriverTopUpPaymentCallbackAsync({
    paymentId: payment.paymentId,
    status: "paid",
    secret: "secret-2",
  });
  assert.equal(allowed.success, true);
  assert.equal(allowed.paymentStatus, "success");

  delete process.env.MTAXI_PAYMENT_CALLBACK_SECRET;
  delete process.env.MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY;
});

test("failed payment is not applied and money stats aggregate ledger", async () => {
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const failedPayment = await createDriverTopUpPaymentAsync({ amount: 1000 }, { user: driver });
  assert.equal(failedPayment.success, true);
  const failed = await failDriverTopUpPaymentAsync({ paymentId: failedPayment.paymentId }, { user: admin });
  assert.equal(failed.success, true);
  assert.equal(failed.paymentStatus, "failed");

  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const order = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
    date: "2026-07-22T06:00:00.000Z",
  }, { user: passenger });
  assert.equal(order.created, true);
  const accepted = await acceptOrderAsync({ orderDocPath: order.orderDocPath }, { user: driver });
  assert.equal(accepted.accepted, true);
  const chargedBalance = accepted.chargedBalance;
  assert.ok(chargedBalance > 0);

  const payment = await createDriverTopUpPaymentAsync({ amount: 2000 }, { user: driver });
  await confirmDriverTopUpPaymentAsync({ paymentId: payment.paymentId }, { user: admin });

  const stats = await getMoneyStatsAsync({}, { user: admin });
  assert.equal(stats.success, true);
  assert.equal(stats.totals.topUps, 2000);
  assert.equal(stats.totals.orderCommissions, chargedBalance);
  assert.equal(stats.byType.payment_failed, 1000);
});

test("adminListPayments is admin-only, filtered and newest first", async () => {
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");

  const denied = await adminListPaymentsAsync({}, { user: passenger });
  assert.equal(denied.success, false);
  assert.equal(denied.code, "ADMIN_REQUIRED");

  const first = await createDriverTopUpPaymentAsync({ amount: 1000 }, { user: driver });
  const second = await createDriverTopUpPaymentAsync({ amount: 2000 }, { user: driver });
  await confirmDriverTopUpPaymentAsync({ paymentId: second.paymentId }, { user: admin });

  const listed = await adminListPaymentsAsync({ query: "708636", limit: 10 }, { user: admin });
  assert.equal(listed.success, true);
  assert.equal(listed.payments.length, 2);
  assert.equal(listed.payments[0].paymentId, second.paymentId);
  assert.equal(listed.payments[0].paymentDocPath.startsWith("payments/"), true);
  assert.equal(listed.payments[0].created_at, listed.payments[0].createdAt);
  assert.equal(listed.payments[1].paymentId, first.paymentId);

  const successful = await adminListPaymentsAsync({ status: "success" }, { user: admin });
  assert.equal(successful.payments.length, 1);
  assert.equal(successful.payments[0].paymentId, second.paymentId);
});

test("driver withdrawal is created and resolved by admin", async () => {
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");

  const passengerDenied = await createDriverWithdrawalAsync({
    amount: 1000,
    cardNumber: "4400430043004300",
  }, { user: passenger });
  assert.equal(passengerDenied.success, false);
  assert.equal(passengerDenied.code, "DRIVER_PROFILE_REQUIRED");

  const tooMuch = await createDriverWithdrawalAsync({
    amount: 100000,
    cardNumber: "4400430043004300",
  }, { user: driver });
  assert.equal(tooMuch.success, false);
  assert.equal(tooMuch.code, "BALANCE_NOT_ENOUGH");

  const created = await createDriverWithdrawalAsync({
    amount: 1500,
    cardNumber: "4400430043004300",
  }, { user: driver });
  assert.equal(created.success, true);
  assert.equal(created.withdraw_id, created.withdrawalId);
  assert.equal(created.status, "pending");

  const listed = await adminListWithdrawalsAsync({ query: "708636" }, { user: admin });
  assert.equal(listed.success, true);
  assert.equal(listed.withdrawals.length, 1);
  assert.equal(listed.withdrawals[0].withdrawalId, created.withdrawalId);

  const before = readStore().users.find((user) => user.id === driver.id).balance;
  const resolved = await adminResolveWithdrawalAsync({
    withdrawalId: created.withdrawalId,
    action: "approve",
  }, { user: admin });
  assert.equal(resolved.success, true);
  assert.equal(resolved.code, "WITHDRAWAL_APPROVED");
  assert.equal(resolved.balance, before - 1500);

  const stats = await getMoneyStatsAsync({}, { user: admin });
  assert.equal(stats.totals.withdrawals, 1500);
  assert.equal(stats.withdrawals.length, 1);
});

test("support chat creates chat, sends messages and tracks read state", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");

  const emptyChat = await getMySupportChatAsync({}, { user: passenger });
  assert.equal(emptyChat.success, true);
  assert.equal(emptyChat.chat, null);
  assert.equal(emptyChat.unreadForUser, 0);

  const ensured = await ensureSupportChatAsync({}, { user: passenger });
  assert.equal(ensured.success, true);
  assert.match(ensured.chatPath, /^chats\//);
  assert.match(ensured.supportChatKey, /users\/u_passenger_7052597368/);

  const sent = await sendSupportChatMessageAsync({
    chatDocPath: ensured.chatPath,
    text: "Здравствуйте",
  }, { user: passenger });
  assert.equal(sent.success, true);
  assert.match(sent.messagePath, /^chat_messages\//);

  const chats = await listSupportChatsAsync({}, { user: admin });
  assert.equal(chats.success, true);
  assert.equal(chats.chats.length, 1);
  assert.equal(chats.chats[0].unreadForAdmin, 1);
  assert.equal(chats.chats[0].user.id, passenger.id);
  assert.equal(chats.chats[0].user.phone, passenger.phone);

  const ensuredByAdmin = await ensureSupportChatAsync({
    targetUserDocPath: `users/${passenger.id}`,
  }, { user: admin });
  assert.equal(ensuredByAdmin.success, true);
  assert.equal(ensuredByAdmin.chatPath, ensured.chatPath);
  assert.match(ensuredByAdmin.supportChatKey, /users\/u_passenger_7052597368/);

  const messages = await getSupportChatMessagesAsync({ chatDocPath: ensured.chatPath }, { user: admin });
  assert.equal(messages.success, true);
  assert.equal(messages.messages.length, 1);
  assert.equal(messages.messages[0].text, "Здравствуйте");

  const read = await markSupportChatReadAsync({ chatDocPath: ensured.chatPath }, { user: admin });
  assert.equal(read.success, true);
  assert.equal(read.chat.unreadForAdmin, 0);

  const answer = await adminSendSupportChatMessageAsync({
    chatDocPath: ensured.chatPath,
    text: "Ответ поддержки",
  }, { user: admin });
  assert.equal(answer.success, true);
  assert.equal(readStore().chats[0].unreadForUser, 1);

  const myUnreadChat = await getMySupportChatAsync({}, { user: passenger });
  assert.equal(myUnreadChat.success, true);
  assert.equal(myUnreadChat.chatPath, ensured.chatPath);
  assert.equal(myUnreadChat.unreadForUser, 1);

  const userRead = await markSupportChatReadAsync({ chatDocPath: ensured.chatPath }, { user: passenger });
  assert.equal(userRead.success, true);
  assert.equal(userRead.chat.unreadForUser, 0);
});

test("support chat denies access to another passenger", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  withStore((store) => {
    store.users.push({
      id: "u_passenger_other",
      phone: "+77050000003",
      password: "123456",
      displayName: "Other",
      city: "Белоусовка",
      roleState: "PASSENGER",
      isDriver: false,
      balance: 0,
    });
  });
  const ensured = await ensureSupportChatAsync({}, { user: passenger });
  const other = readStore().users.find((user) => user.id === "u_passenger_other");
  const denied = await getSupportChatMessagesAsync({ chatDocPath: ensured.chatPath }, { user: other });
  assert.equal(denied.success, false);
  assert.equal(denied.code, "CHAT_FORBIDDEN");
});

test("admin can delete one or all support chats with audit logs", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const denied = await adminClearSupportChatsAsync({}, { user: passenger });
  assert.equal(denied.success, false);
  assert.equal(denied.code, "ADMIN_REQUIRED");

  const first = await ensureSupportChatAsync({}, { user: passenger });
  await sendSupportChatMessageAsync({ chatDocPath: first.chatPath, text: "Первый чат" }, { user: passenger });
  const deleted = await adminDeleteSupportChatAsync({ chatDocPath: first.chatPath }, { user: admin });
  assert.equal(deleted.success, true);
  assert.equal(deleted.removedChats, 1);
  assert.equal(deleted.removedMessages, 1);
  assert.equal(readStore().chats.length, 0);
  assert.equal(readStore().chatMessages.length, 0);
  assert.equal(readStore().users.find((user) => user.id === passenger.id).supportChatPath, undefined);

  const second = await ensureSupportChatAsync({}, { user: passenger });
  await sendSupportChatMessageAsync({ chatDocPath: second.chatPath, text: "Второй чат" }, { user: passenger });
  const cleared = await adminClearSupportChatsAsync({}, { user: admin });
  assert.equal(cleared.success, true);
  assert.equal(cleared.removedChats, 1);
  assert.equal(cleared.removedMessages, 1);
  assert.equal(readStore().chats.length, 0);
  assert.equal(readStore().chatMessages.length, 0);

  const audit = await adminListAuditLogsAsync({ action: "adminClearSupportChats" }, { user: admin });
  assert.equal(audit.success, true);
  assert.equal(audit.logs.length, 1);
  assert.equal(audit.logs[0].target, "chats");
});

test("push token is upserted and state is updated without duplicates", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const auth = { user: passenger };

  const first = await addFcmTokenAsync({
    userDocPath: `users/${passenger.id}`,
    fcmToken: "token-passenger-1",
    deviceType: "Android",
  }, auth);
  assert.equal(first.success, true);
  assert.equal(first.token.orderAlertsEnabled, true);

  const updated = await updateFcmTokenStateAsync({
    userDocPath: `users/${passenger.id}`,
    fcmToken: "token-passenger-1",
    deviceType: "Android",
    appState: "foreground",
    orderAlertsEnabled: false,
  }, auth);
  assert.equal(updated.success, true);
  assert.equal(updated.token.appState, "foreground");
  assert.equal(updated.token.orderAlertsEnabled, false);
  assert.equal(readStore().fcmTokens.length, 1);
});

test("push notification dedupes and creates deliveries for matching tokens", async () => {
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  await addFcmTokenAsync({
    userDocPath: `users/${driver.id}`,
    fcmToken: "token-driver-1",
    deviceType: "Android",
  }, { user: driver });

  const first = await createPushNotificationAsync({
    title: "Новый заказ",
    body: "Алтайская 12 -> Степной 15",
    type: "ORDER_CREATED",
    targetRole: "driver",
    orderAlert: true,
    dedupeKey: "order_1_CREATED_driver",
  }, { user: admin });
  assert.equal(first.success, true);
  assert.equal(first.numTargetTokens, 1);

  const second = await createPushNotificationAsync({
    title: "Новый заказ",
    body: "Дубликат",
    type: "ORDER_CREATED",
    targetRole: "driver",
    orderAlert: true,
    dedupeKey: "order_1_CREATED_driver",
  }, { user: admin });
  assert.equal(second.success, true);
  assert.equal(second.deduped, true);
  assert.equal(readStore().notifications.length, 1);
  assert.equal(readStore().notificationDeliveries.length, 1);
});

test("flushQueuedPushDeliveries sends queued pushes through local transport", async () => {
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  await addFcmTokenAsync({
    userDocPath: `users/${driver.id}`,
    fcmToken: "token-driver-flush",
    deviceType: "Android",
  }, { user: driver });
  const queued = await createPushNotificationAsync({
    title: "Новый заказ",
    body: "Алтайская 12",
    targetRole: "driver",
  }, { user: admin });
  assert.equal(queued.success, true);

  const flushed = await flushQueuedPushDeliveriesAsync({ limit: 10 }, { user: admin });
  assert.equal(flushed.success, true);
  assert.equal(flushed.mode, "simulated-local");
  assert.equal(flushed.numSent, 1);
  assert.equal(flushed.numFailed, 0);
  assert.equal(readStore().notificationDeliveries[0].status, "sent");
});

test("runMaintenanceTasks expires stale orders and flushes push queue", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  await addFcmTokenAsync({
    userDocPath: `users/${driver.id}`,
    fcmToken: "token-driver-maintenance",
    deviceType: "Android",
  }, { user: driver });
  const order = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
  }, { user: passenger });
  const orderId = order.orderDocPath.split("/").pop();
  withStore((store) => {
    const saved = store.orders.find((item) => item.id === orderId);
    saved.createdAt = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  });

  const result = await runMaintenanceTasksAsync({
    ttlMinutes: 15,
    orderLimit: 10,
    pushLimit: 10,
  }, { user: admin });
  assert.equal(result.success, true);
  assert.equal(result.expiredOrders.expiredCount, 1);
  assert.equal(result.push.numSent, 1);
  assert.equal(readStore().orders.find((item) => item.id === orderId).status, 7);
  assert.equal(readStore().users.find((user) => user.id === passenger.id).hasActivePassengerOrder, false);
});

test("internal maintenance runs without admin auth for local scheduler", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const order = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
  }, { user: passenger });
  const orderId = order.orderDocPath.split("/").pop();
  withStore((store) => {
    const saved = store.orders.find((item) => item.id === orderId);
    saved.createdAt = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  });

  const result = await runMaintenanceTasksInternalAsync({
    ttlMinutes: 15,
    orderLimit: 10,
    pushLimit: 10,
  });
  assert.equal(result.success, true);
  assert.equal(result.expiredOrders.expiredCount, 1);
  assert.equal(readStore().orders.find((item) => item.id === orderId).status, 7);
});

test("maintenance scheduler is disabled by default and configured by env", async () => {
  assert.equal(maintenanceIntervalMsForEnv({}), 0);
  assert.equal(maintenanceIntervalMsForEnv({ MTAXI_MAINTENANCE_INTERVAL_SEC: "1" }), 5000);
  assert.equal(maintenanceIntervalMsForEnv({ MTAXI_MAINTENANCE_INTERVAL_SEC: "30" }), 30000);

  let scheduledTick;
  let cleared = false;
  const calls = [];
  const scheduler = startMaintenanceScheduler({
    env: {
      MTAXI_MAINTENANCE_INTERVAL_SEC: "5",
      MTAXI_PENDING_ORDER_TTL_MIN: "15",
      MTAXI_MAINTENANCE_ORDER_LIMIT: "20",
      MTAXI_MAINTENANCE_PUSH_LIMIT: "30",
    },
    task: async (data) => calls.push(data),
    setIntervalFn: (tick, ms) => {
      scheduledTick = tick;
      return { ms, unref() {} };
    },
    clearIntervalFn: () => {
      cleared = true;
    },
  });

  assert.equal(scheduler.intervalMs, 5000);
  await scheduledTick();
  assert.deepEqual(calls, [{
    ttlMinutes: "15",
    orderLimit: "20",
    pushLimit: "30",
  }]);
  scheduler.stop();
  assert.equal(cleared, true);
});

test("admin broadcast queues local push notifications and lists history", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  await addFcmTokenAsync({
    userDocPath: `users/${passenger.id}`,
    fcmToken: "token-passenger-android",
    deviceType: "Android",
  }, { user: passenger });
  await addFcmTokenAsync({
    userDocPath: `users/${driver.id}`,
    fcmToken: "token-driver-ios",
    deviceType: "iOS",
  }, { user: driver });

  const queued = await adminQueueBroadcastAsync({
    title: "Проверка",
    body: "Текст рассылки",
    targetRole: "drivers",
    targetAudience: "iOS",
  }, { user: admin });
  assert.equal(queued.success, true);
  assert.equal(queued.numTargetUsers, 1);
  assert.equal(queued.numTargetTokens, 1);
  assert.equal(queued.numChatMessages, 1);

  const history = await adminListPushNotificationsAsync({ limit: 5 }, { user: admin });
  assert.equal(history.success, true);
  assert.equal(history.notifications[0].notification_title, "Проверка");
  assert.equal(history.notifications[0].target_role, "driver");
  assert.equal(history.notifications[0].target_audience, "iOS");
  assert.equal(history.notifications[0].num_sent, 1);
  assert.equal(history.notifications[0].num_chat_messages, 1);
  assert.equal(readStore().chatMessages.length, 1);
});

test("push ack is saved idempotently per user and event type", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const first = await ackPushDeliveryAsync({
    notificationId: "push_1",
    sentAtMs: 1000,
    receivedAtMs: 1600,
    openedAtMs: 1800,
    eventType: "opened",
    platform: "android",
    route: "homePage",
  }, { user: passenger });
  assert.equal(first.success, true);

  const second = await ackPushDeliveryAsync({
    notificationId: "push_1",
    sentAtMs: 1000,
    receivedAtMs: 2000,
    eventType: "opened",
    platform: "android",
  }, { user: passenger });
  assert.equal(second.success, true);
  assert.equal(readStore().pushDeliveryAcks.length, 1);
  assert.equal(readStore().pushDeliveryAcks[0].receivedAtMs, 2000);
});

test("order lifecycle queues push events with dedupe and correct recipients", async () => {
  withStore((store) => {
    store.users.push({
      id: "u_driver_second",
      phone: "+77050000002",
      password: "123456",
      displayName: "Second Driver",
      city: "Белоусовка",
      roleState: "DRIVER_ONLINE",
      isDriver: true,
      statusDriver: "approved",
      balance: 10000,
    });
  });
  const storeBefore = readStore();
  const passenger = storeBefore.users.find((user) => user.id === "u_passenger_7052597368");
  const driver = storeBefore.users.find((user) => user.id === "u_driver_7086362153");
  const secondDriver = storeBefore.users.find((user) => user.id === "u_driver_second");

  await addFcmTokenAsync({
    userDocPath: `users/${passenger.id}`,
    fcmToken: "token-passenger",
    deviceType: "Android",
  }, { user: passenger });
  await addFcmTokenAsync({
    userDocPath: `users/${driver.id}`,
    fcmToken: "token-driver",
    deviceType: "Android",
  }, { user: driver });
  await addFcmTokenAsync({
    userDocPath: `users/${secondDriver.id}`,
    fcmToken: "token-second-driver",
    deviceType: "Android",
  }, { user: secondDriver });

  const order = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
  }, { user: passenger });
  assert.equal(order.created, true);

  let store = readStore();
  const createdPush = store.notifications.find((item) => item.type === "ORDER_CREATED");
  assert.ok(createdPush);
  assert.equal(createdPush.numTargetTokens, 2);

  const accepted = await acceptOrderAsync({ orderDocPath: order.orderDocPath }, { user: driver });
  assert.equal(accepted.accepted, true);

  store = readStore();
  const passengerPush = store.notifications.find((item) => item.type === "ORDER_ACCEPTED");
  assert.ok(passengerPush);
  assert.equal(passengerPush.numTargetTokens, 1);
  const takenByOther = store.notifications.find((item) => item.type === "ORDER_TAKEN_BY_OTHER_DRIVER");
  assert.ok(takenByOther);
  const takenDeliveries = store.notificationDeliveries.filter(
    (item) => item.notificationId === takenByOther.id,
  );
  assert.deepEqual(takenDeliveries.map((item) => item.userId), ["u_driver_second"]);

  const duplicate = await createPushNotificationAsync({
    title: "Дубликат",
    targetRole: "driver",
    dedupeKey: createdPush.dedupeKey,
  }, { user: store.users.find((user) => user.id === "u_admin_70000000000") });
  assert.equal(duplicate.deduped, true);
});

test("driver order feed lists open orders by radius and ignores settlement mismatch", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  withStore((store) => {
    const savedDriver = store.users.find((user) => user.id === driver.id);
    savedDriver.city = "Другой поселок";
  });

  const nearOrder = await createPassengerOrderAsync({
    type: "taxi",
    city: "Согра",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
    fromLatitude: 50.0000,
    fromLongitude: 82.0000,
  }, { user: passenger });
  assert.equal(nearOrder.created, true);
  withStore((store) => {
    const user = store.users.find((item) => item.id === passenger.id);
    user.activePassengerOrderId = null;
    user.hasActivePassengerOrder = false;
  });
  const farOrder = await createPassengerOrderAsync({
    type: "delivery",
    city: "Город",
    ot: "Далеко",
    kuda: "Адрес",
    fromLatitude: 51.0000,
    fromLongitude: 83.0000,
  }, { user: passenger });
  assert.equal(farOrder.created, true);

  const feed = await listAvailableDriverOrdersAsync({
    driverLatitude: 50.0001,
    driverLongitude: 82.0001,
    radiusKm: 10,
  }, { user: readStore().users.find((user) => user.id === driver.id) });
  assert.equal(feed.success, true);
  assert.equal(feed.count, 1);
  assert.equal(feed.orders[0].orderDocPath, nearOrder.orderDocPath);
});

test("order read APIs return details, my orders and admin filtered orders", async () => {
  const passenger = readStore().users.find((user) => user.id === "u_passenger_7052597368");
  const driver = readStore().users.find((user) => user.id === "u_driver_7086362153");
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const order = await createPassengerOrderAsync({
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
  }, { user: passenger });
  assert.equal(order.created, true);

  const details = await getOrderDetailsAsync({ orderDocPath: order.orderDocPath }, { user: passenger });
  assert.equal(details.success, true);
  assert.equal(details.order.ot, "Алтайская 12");

  const accepted = await acceptOrderAsync({ orderDocPath: order.orderDocPath }, { user: driver });
  assert.equal(accepted.accepted, true);

  const myDriverOrders = await listMyOrdersAsync({}, { user: driver });
  assert.equal(myDriverOrders.success, true);
  assert.equal(myDriverOrders.orders.length, 1);
  assert.equal(myDriverOrders.orders[0].driverId, driver.id);

  const adminOrders = await adminListOrdersAsync({ status: 2, query: "Алтайская" }, { user: admin });
  assert.equal(adminOrders.success, true);
  assert.equal(adminOrders.orders.length, 1);
  assert.equal(adminOrders.orders[0].orderDocPath, order.orderDocPath);

  const hiddenByQuery = await adminListOrdersAsync({ status: 2, query: "не существует" }, { user: admin });
  assert.equal(hiddenByQuery.success, true);
  assert.equal(hiddenByQuery.orders.length, 0);
});

test("adminCreateOrder creates backend order for selected or phone passenger", async () => {
  const admin = readStore().users.find((user) => user.id === "u_admin_70000000000");
  const created = await adminCreateOrderAsync({
    customerPhone: "7051112233",
    customerName: "Новый пассажир",
    type: "taxi",
    city: "Белоусовка",
    ot: "Алтайская 12",
    kuda: "Переулок Степной 15",
    price: 2500,
  }, { user: admin });
  assert.equal(created.success, true);
  assert.match(created.userDocPath, /^users\/u_passenger_/);
  assert.equal(created.order.price, 2500);

  const listed = await adminListOrdersAsync({ userDocPath: created.userDocPath }, { user: admin });
  assert.equal(listed.success, true);
  assert.equal(listed.orders.length, 1);
  assert.equal(listed.orders[0].customerPhone, "+77051112233");
});
