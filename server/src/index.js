require("dotenv").config();

const cors = require("cors");
const express = require("express");
const { dispatchCall } = require("./call_router");
const {
  corsOriginForEnv,
  jsonBodyLimitForEnv,
  accessLogMiddleware,
  requestIdMiddleware,
  securityHeadersMiddleware,
  trustProxyForEnv,
  uploadStaticOptionsForEnv,
} = require("./http_config");
const { uploadDir } = require("./media");
const {
  handleDriverTopUpPaymentCallbackAsync,
  localPaymentPageEnabled,
} = require("./payments");
const { startMaintenanceScheduler } = require("./maintenance_scheduler");
const { storeHealth, withStoreAsync } = require("./store");
const { configureLaunchDefaultsInStore } = require('../scripts/configure_launch_defaults');
const { runPreflight } = require("../scripts/preflight");

const app = express();
const port = Number(process.env.PORT || 8080);

function legacyCreateTokenEnabled() {
  const raw = String(process.env.MTAXI_ENABLE_LEGACY_CREATE_TOKEN || "")
    .trim()
    .toLowerCase();
  return raw === "true" || raw === "1" || raw === "yes" ||
    process.env.NODE_ENV !== "production";
}

app.disable("x-powered-by");
app.set("trust proxy", trustProxyForEnv());
app.use(cors({ origin: corsOriginForEnv() }));
app.use(securityHeadersMiddleware);
app.use(requestIdMiddleware);
app.use(accessLogMiddleware());
app.use(express.json({ limit: jsonBodyLimitForEnv() }));
app.use("/uploads", express.static(uploadDir, uploadStaticOptionsForEnv()));

async function sendReadiness(res) {
  const store = await storeHealth();
  const ok = store.ok === true;
  res.status(ok ? 200 : 503).json({
    ok,
    service: "mtaxi-backend",
    store,
    time: new Date().toISOString(),
  });
}

app.get("/livez", (_req, res) => {
  res.json({
    ok: true,
    service: "mtaxi-backend",
    time: new Date().toISOString(),
  });
});

app.get("/readyz", async (_req, res) => {
  await sendReadiness(res);
});

app.get("/health", async (_req, res) => {
  await sendReadiness(res);
});

app.get("/local-payment/:paymentId", (req, res) => {
  if (!localPaymentPageEnabled()) {
    res.status(404).json({
      success: false,
      code: "LOCAL_PAYMENT_DISABLED",
      requestId: req.requestId,
      error: "Local payment page is disabled",
    });
    return;
  }
  const paymentId = String(req.params.paymentId || "");
  res.type("html").send(`<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MTaxi local payment</title>
  <style>
    body { margin: 0; font-family: system-ui, sans-serif; background: #101820; color: #fff; }
    main { min-height: 100vh; display: grid; place-items: center; padding: 24px; box-sizing: border-box; }
    section { max-width: 420px; width: 100%; background: #17232d; border: 1px solid #284052; border-radius: 12px; padding: 24px; }
    h1 { margin: 0 0 12px; font-size: 22px; }
    p { color: #c7d2da; line-height: 1.45; }
    code { color: #26d6cf; overflow-wrap: anywhere; }
  </style>
</head>
<body>
  <main>
    <section>
      <h1>Локальная оплата MTaxi</h1>
      <p>Платеж создан и ожидает подтверждения backend callback.</p>
      <p>ID платежа:<br><code>${paymentId}</code></p>
      <p>В локальном режиме баланс не зачисляется автоматически. Подтверждение идет через <code>confirmDriverTopUpPayment</code>.</p>
    </section>
  </main>
</body>
</html>`);
});

app.post("/payments/kassa24/callback", async (req, res) => {
  try {
    const result = await handleDriverTopUpPaymentCallbackAsync(req.body || {}, req);
    res.status(result.success ? 200 : 400).json(result);
  } catch (e) {
    console.error("payment callback failed", { requestId: req.requestId, error: e });
    res.status(500).json({
      success: false,
      code: "PAYMENT_CALLBACK_FAILED",
      requestId: req.requestId,
      error: "Не удалось обработать платеж",
    });
  }
});

app.get("/payments/kassa24/return", (req, res) => {
  res.type("html").send(`<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MTaxi payment return</title>
</head>
<body>
  <p>Проверяем оплату...</p>
</body>
</html>`);
});

app.post("/call/:name", async (req, res) => {
  try {
    const result = await dispatchCall(req.params.name, req.body || {}, req);
    res.json(result);
  } catch (e) {
    console.error("call failed", { requestId: req.requestId, call: req.params.name, error: e });
    res.status(500).json({
      success: false,
      code: "INTERNAL",
      requestId: req.requestId,
      error: "Сервис временно недоступен. Попробуйте еще раз.",
    });
  }
});

app.post("/create-token", async (req, res) => {
  if (!legacyCreateTokenEnabled()) {
    res.status(404).json({
      success: false,
      code: "LEGACY_ENDPOINT_DISABLED",
      requestId: req.requestId,
      error: "Legacy token endpoint is disabled",
    });
    return;
  }
  try {
    const result = await dispatchCall("passwordLogin", req.body || {}, req);
    res.json(result);
  } catch (e) {
    console.error("create-token failed", { requestId: req.requestId, error: e });
    res.status(500).json({
      success: false,
      code: "TOKEN_CREATE_FAILED",
      requestId: req.requestId,
      error: "Не удалось подготовить вход. Попробуйте еще раз.",
    });
  }
});

app.use((req, res) => {
  res.status(404).json({
    success: false,
    code: "NOT_FOUND",
    requestId: req.requestId,
    error: "Endpoint not found",
  });
});

app.use((err, req, res, _next) => {
  const status = err?.type === "entity.parse.failed"
    ? 400
    : Number(err?.status || err?.statusCode || 500);
  const safeStatus = Number.isFinite(status) && status >= 400 && status < 600 ? status : 500;
  const code = err?.type === "entity.parse.failed"
    ? "BAD_JSON"
    : safeStatus === 404
      ? "NOT_FOUND"
      : "HTTP_ERROR";
  const message = code === "BAD_JSON"
    ? "Некорректный JSON в запросе"
    : code === "NOT_FOUND"
      ? "Endpoint not found"
      : "Сервис временно недоступен. Попробуйте еще раз.";

  if (safeStatus >= 500) {
    console.error("http error", { requestId: req.requestId, error: err });
  }

  res.status(safeStatus).json({
    success: false,
    code,
    requestId: req.requestId,
    error: message,
  });
});

function startServer(options = {}) {
  const listenPort = Number(options.port === undefined ? port : options.port);
  const scheduler = options.scheduler === undefined
    ? startMaintenanceScheduler()
    : options.scheduler;
  const server = app.listen(listenPort, "0.0.0.0", () => {
    const address = server.address();
    const actualPort = address && typeof address === "object" ? address.port : listenPort;
    console.log(`MTaxi backend listening on http://127.0.0.1:${actualPort}`);
  });
  return { server, scheduler, shutdownStarted: false };
}

function stopServer(runtime, signal = "shutdown") {
  if (!runtime || runtime.shutdownStarted === true) {
    return;
  }
  runtime.shutdownStarted = true;
  runtime?.scheduler?.stop?.();
  runtime?.server?.close?.(() => {
    console.log(`MTaxi backend stopped after ${signal}`);
  });
}

async function startProductionEntrypoint() {
  if (process.env.NODE_ENV === "production") {
    const preflight = await runPreflight();
    if (!preflight.ok) {
      for (const check of preflight.checks.filter((item) => !item.ok)) {
        console.error(`Startup preflight failed: ${check.name}: ${check.message}`);
      }
      process.exit(1);
    }
  }
  await withStoreAsync(async store => configureLaunchDefaultsInStore(store));
  const runtime = startServer();
  process.on("SIGTERM", () => stopServer(runtime, "SIGTERM"));
  process.on("SIGINT", () => stopServer(runtime, "SIGINT"));
}

if (require.main === module) {
  startProductionEntrypoint().catch((error) => {
    console.error(error?.message || error);
    process.exit(1);
  });
}

module.exports = {
  app,
  legacyCreateTokenEnabled,
  startProductionEntrypoint,
  startServer,
  stopServer,
};
