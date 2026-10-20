const { normalizeString } = require("./utils/values");

function smsProviderName(env = process.env) {
  return normalizeString(env.MTAXI_SMS_PROVIDER || "local").toLowerCase();
}

function renderTemplate(template, values) {
  return normalizeString(template).replace(/\{\{\s*(phone|code|message)\s*\}\}/g, (_, key) => {
    return values[key] || "";
  });
}

function parseJsonObject(raw, fallback = {}) {
  const text = normalizeString(raw);
  if (!text) return fallback;
  try {
    const parsed = JSON.parse(text);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : fallback;
  } catch (_) {
    return fallback;
  }
}

async function sendSmsCode({ phone, code, env = process.env, fetchImpl = globalThis.fetch } = {}) {
  const provider = smsProviderName(env);
  const message = renderTemplate(
    env.MTAXI_SMS_MESSAGE_TEMPLATE || "MTaxi code: {{code}}",
    { phone, code },
  );

  if (provider === "local" || provider === "console" || provider === "dev") {
    console.log(`MTaxi SMS ${phone}: ${code}`);
    return { ok: true, provider: "local", providerMessageId: null };
  }

  if (provider !== "http" && provider !== "vapi") {
    return { ok: false, provider, error: `Unknown SMS provider: ${provider}` };
  }

  const url = normalizeString(
    provider === "vapi"
      ? env.MTAXI_VAPI_SMS_URL || env.MTAXI_SMS_HTTP_URL
      : env.MTAXI_SMS_HTTP_URL,
  );
  if (!url) {
    return {
      ok: false,
      provider,
      error: provider === "vapi"
        ? "MTAXI_VAPI_SMS_URL or MTAXI_SMS_HTTP_URL is required"
        : "MTAXI_SMS_HTTP_URL is required",
    };
  }
  if (typeof fetchImpl !== "function") {
    return { ok: false, provider, error: "fetch is not available for SMS HTTP provider" };
  }

  const bodyTemplate = normalizeString(
    provider === "vapi"
      ? env.MTAXI_VAPI_SMS_BODY_TEMPLATE || env.MTAXI_SMS_HTTP_BODY_TEMPLATE
      : env.MTAXI_SMS_HTTP_BODY_TEMPLATE,
  ) ||
    '{"phone":"{{phone}}","message":"{{message}}","code":"{{code}}"}';
  const headers = {
    "Content-Type": "application/json",
    ...parseJsonObject(
      provider === "vapi"
        ? env.MTAXI_VAPI_SMS_HEADERS || env.MTAXI_SMS_HTTP_HEADERS
        : env.MTAXI_SMS_HTTP_HEADERS,
    ),
  };
  const token = normalizeString(
    provider === "vapi"
      ? env.MTAXI_VAPI_SMS_BEARER_TOKEN || env.MTAXI_SMS_HTTP_BEARER_TOKEN
      : env.MTAXI_SMS_HTTP_BEARER_TOKEN,
  );
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  const body = renderTemplate(bodyTemplate, { phone, code, message });

  try {
    const response = await fetchImpl(url, {
      method: normalizeString(
        provider === "vapi"
          ? env.MTAXI_VAPI_SMS_METHOD || env.MTAXI_SMS_HTTP_METHOD || "POST"
          : env.MTAXI_SMS_HTTP_METHOD || "POST",
      ).toUpperCase(),
      headers,
      body,
    });
    const responseText = await response.text().catch(() => "");
    return {
      ok: response.ok,
      provider,
      statusCode: response.status,
      responseText: responseText.slice(0, 1000),
      error: response.ok ? undefined : `SMS provider returned ${response.status}`,
    };
  } catch (error) {
    return {
      ok: false,
      provider,
      error: error?.message || "SMS provider request failed",
    };
  }
}

module.exports = {
  renderTemplate,
  sendSmsCode,
  smsProviderName,
};
