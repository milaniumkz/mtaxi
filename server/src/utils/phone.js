function normalizeString(value) {
  return value == null ? "" : String(value).trim();
}

function normalizeDigits(value) {
  return normalizeString(value).replace(/\D/g, "");
}

function normalizePhoneLocalDigits(value) {
  const digits = normalizeDigits(value);
  if (digits.length === 10) return digits;
  if (digits.length === 11 && (digits.startsWith("7") || digits.startsWith("8"))) {
    return digits.slice(1);
  }
  return "";
}

function phoneLookupValues(value) {
  const raw = normalizeString(value);
  const digits = normalizeDigits(raw);
  const local = normalizePhoneLocalDigits(raw);
  return Array.from(new Set([
    raw,
    digits,
    digits ? `+${digits}` : "",
    local ? `+7${local}` : "",
    local ? `7${local}` : "",
    local ? `8${local}` : "",
    local,
    local ? `+7 (${local.slice(0, 3)}) ${local.slice(3, 6)}-${local.slice(6, 8)}-${local.slice(8, 10)}` : "",
    local ? `+8 (${local.slice(0, 3)}) ${local.slice(3, 6)}-${local.slice(6, 8)}-${local.slice(8, 10)}` : "",
  ].filter(Boolean)));
}

module.exports = {
  normalizeString,
  normalizeDigits,
  normalizePhoneLocalDigits,
  phoneLookupValues,
};
