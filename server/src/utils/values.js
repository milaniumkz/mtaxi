function normalizeString(value) {
  return value == null ? "" : String(value).trim();
}

function asNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value.replace(",", ".").trim());
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function asDate(value) {
  if (!value) return null;
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function normalizeDigits(value) {
  return normalizeString(value).replace(/\D/g, "");
}

function normalizePhone(value) {
  const digits = normalizeDigits(value);
  if (digits.length === 10) return `+7${digits}`;
  if (digits.length === 11 && (digits.startsWith("7") || digits.startsWith("8"))) {
    return `+7${digits.slice(1)}`;
  }
  return normalizeString(value);
}

module.exports = {
  normalizeString,
  asNumber,
  asDate,
  normalizeDigits,
  normalizePhone,
};
