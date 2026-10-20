const crypto = require("crypto");

function normalizeList(value) {
  return String(value || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function corsOriginForEnv(env = process.env) {
  const allowedOrigins = normalizeList(env.MTAXI_CORS_ORIGINS);
  if (allowedOrigins.length === 0) {
    return true;
  }
  return (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
      return;
    }
    callback(new Error("CORS origin is not allowed"));
  };
}

function jsonBodyLimitForEnv(env = process.env) {
  return String(env.MTAXI_JSON_BODY_LIMIT || "25mb").trim() || "25mb";
}

function isFalseLike(value) {
  const raw = String(value || "").trim().toLowerCase();
  return raw === "false" || raw === "0" || raw === "no" || raw === "off";
}

function trustProxyForEnv(env = process.env) {
  const raw = String(env.MTAXI_TRUST_PROXY || "").trim().toLowerCase();
  if (!raw) {
    return false;
  }
  if (isFalseLike(raw)) {
    return false;
  }
  if (raw === "true" || raw === "1" || raw === "yes") {
    return true;
  }
  const numeric = Number(raw);
  return Number.isFinite(numeric) && numeric >= 0 ? numeric : raw;
}

function requestIdMiddleware(req, res, next) {
  const incoming = String(req.get?.("x-request-id") || "").trim();
  const requestId = /^[a-zA-Z0-9._:-]{8,128}$/.test(incoming)
    ? incoming
    : crypto.randomUUID();
  req.requestId = requestId;
  req.id = requestId;
  res.setHeader("X-Request-Id", requestId);
  next();
}

function accessLogEnabledForEnv(env = process.env) {
  return !isFalseLike(env.MTAXI_ACCESS_LOGS);
}

function accessLogPath(req) {
  const raw = String(req.path || req.originalUrl || req.url || "");
  return raw.split("?")[0] || "/";
}

function accessLogMiddleware({ env = process.env, logger = console } = {}) {
  if (!accessLogEnabledForEnv(env)) {
    return (_req, _res, next) => next();
  }
  return (req, res, next) => {
    const startedAt = process.hrtime.bigint();
    res.on("finish", () => {
      const durationMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
      logger.info?.("mtaxi_http_access", {
        requestId: req.requestId || req.id || "",
        method: req.method,
        path: accessLogPath(req),
        status: res.statusCode,
        durationMs: Math.round(durationMs),
        ip: req.ip,
        userAgent: String(req.get?.("user-agent") || "").slice(0, 200),
      });
    });
    next();
  };
}

function securityHeadersMiddleware(req, res, next) {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Referrer-Policy", "no-referrer");
  if (!String(req.path || "").startsWith("/local-payment/")) {
    res.setHeader("X-Frame-Options", "DENY");
  }
  next();
}

function uploadCacheMaxAgeSecForEnv(env = process.env) {
  const value = Number(env.MTAXI_UPLOAD_CACHE_MAX_AGE_SEC);
  return Number.isFinite(value) && value >= 0 ? Math.floor(value) : 60 * 60 * 24 * 30;
}

function uploadStaticOptionsForEnv(env = process.env) {
  const maxAgeSec = uploadCacheMaxAgeSecForEnv(env);
  return {
    fallthrough: false,
    maxAge: `${maxAgeSec}s`,
    immutable: maxAgeSec > 0,
    setHeaders(res) {
      res.setHeader("X-Content-Type-Options", "nosniff");
      res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
      res.setHeader(
        "Cache-Control",
        maxAgeSec > 0
          ? `public, max-age=${maxAgeSec}, immutable`
          : "no-store",
      );
    },
  };
}

module.exports = {
  accessLogEnabledForEnv,
  accessLogPath,
  accessLogMiddleware,
  corsOriginForEnv,
  jsonBodyLimitForEnv,
  requestIdMiddleware,
  trustProxyForEnv,
  securityHeadersMiddleware,
  uploadCacheMaxAgeSecForEnv,
  uploadStaticOptionsForEnv,
};
