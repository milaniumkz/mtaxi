const { normalizePhone, normalizeString } = require("./utils/values");

const buckets = new Map();

function numericEnv(name, fallback, env = process.env) {
  const value = Number(env[name]);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

function authRateLimitConfig(env = process.env) {
  return {
    windowMs: numericEnv("MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC", 60, env) * 1000,
    max: numericEnv("MTAXI_AUTH_RATE_LIMIT_MAX", 20, env),
  };
}

function clientIp(req) {
  const forwarded = normalizeString(req?.headers?.["x-forwarded-for"] || req?.get?.("x-forwarded-for"));
  if (forwarded) return forwarded.split(",")[0].trim();
  return normalizeString(req?.ip || req?.socket?.remoteAddress || "unknown");
}

function rateLimitKey(name, data = {}, req) {
  const phone = normalizePhone(data.phone || data.uid || data.phoneNumber);
  return `${name}:${clientIp(req)}:${phone || "no-phone"}`;
}

function checkRateLimit(name, data = {}, req, env = process.env, nowMs = Date.now()) {
  const { windowMs, max } = authRateLimitConfig(env);
  const key = rateLimitKey(name, data, req);
  const current = buckets.get(key);
  if (!current || current.resetAt <= nowMs) {
    buckets.set(key, { count: 1, resetAt: nowMs + windowMs });
    return { limited: false };
  }
  current.count += 1;
  if (current.count <= max) {
    return { limited: false };
  }
  return {
    limited: true,
    retryAfterSec: Math.max(1, Math.ceil((current.resetAt - nowMs) / 1000)),
  };
}

function clearRateLimits() {
  buckets.clear();
}

module.exports = {
  authRateLimitConfig,
  checkRateLimit,
  clearRateLimits,
  rateLimitKey,
};
