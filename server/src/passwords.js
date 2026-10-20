const crypto = require("crypto");
const { normalizeString } = require("./utils/values");

const SCRYPT_PREFIX = "scrypt";
const KEY_LENGTH = 64;

function hashPassword(password) {
  const normalized = normalizeString(password);
  if (!normalized) return "";
  const salt = crypto.randomBytes(16).toString("base64url");
  const hash = crypto.scryptSync(normalized, salt, KEY_LENGTH).toString("base64url");
  return `${SCRYPT_PREFIX}$${salt}$${hash}`;
}

function isPasswordHash(value) {
  return normalizeString(value).startsWith(`${SCRYPT_PREFIX}$`);
}

function verifyPassword(password, stored) {
  const normalizedPassword = normalizeString(password);
  const normalizedStored = normalizeString(stored);
  if (!normalizedPassword || !normalizedStored) return false;
  if (!isPasswordHash(normalizedStored)) {
    return normalizedStored === normalizedPassword;
  }
  const [, salt, expectedHash] = normalizedStored.split("$");
  if (!salt || !expectedHash) return false;
  const actualHash = crypto.scryptSync(normalizedPassword, salt, KEY_LENGTH);
  const expected = Buffer.from(expectedHash, "base64url");
  return expected.length === actualHash.length && crypto.timingSafeEqual(actualHash, expected);
}

function setUserPassword(user, password) {
  user.passwordHash = hashPassword(password);
  delete user.password;
  user.passwordUpdatedAt = new Date().toISOString();
}

function hasUserPassword(user) {
  return Boolean(normalizeString(user?.passwordHash || user?.password));
}

module.exports = {
  hashPassword,
  isPasswordHash,
  verifyPassword,
  setUserPassword,
  hasUserPassword,
};
