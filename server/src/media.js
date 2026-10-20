const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { normalizeString } = require("./utils/values");

const uploadDir = process.env.MTAXI_UPLOAD_DIR || path.join(__dirname, "../uploads");
const maxUploadBytes = Number(process.env.MTAXI_MAX_UPLOAD_BYTES || 10 * 1024 * 1024);

const EXT_BY_MIME = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/heic": ".heic",
  "image/heif": ".heif",
  "image/webp": ".webp",
  "application/pdf": ".pdf",
  "video/mp4": ".mp4",
};

function safeExtension(pathValue, contentType) {
  const fromMime = EXT_BY_MIME[normalizeString(contentType).toLowerCase()];
  if (fromMime) return fromMime;
  const ext = path.extname(normalizeString(pathValue)).toLowerCase();
  return /^[.][a-z0-9]{1,8}$/.test(ext) ? ext : ".bin";
}

function validateUploadContentType(contentType) {
  const normalized = normalizeString(contentType).toLowerCase();
  if (!normalized || !EXT_BY_MIME[normalized]) {
    return {
      success: false,
      code: "UPLOAD_TYPE_NOT_ALLOWED",
      error: "Недопустимый тип файла",
    };
  }
  return null;
}

function bufferStartsWith(buffer, bytes) {
  return bytes.every((byte, index) => buffer[index] === byte);
}

function isIsoBaseMedia(buffer) {
  return buffer.length >= 12 &&
    buffer.toString("ascii", 4, 8) === "ftyp";
}

function validateUploadBuffer(buffer, contentType) {
  const normalized = normalizeString(contentType).toLowerCase();
  const isValid =
    (normalized === "image/jpeg" && bufferStartsWith(buffer, [0xff, 0xd8, 0xff])) ||
    (normalized === "image/png" && bufferStartsWith(buffer, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) ||
    (normalized === "image/webp" && buffer.length >= 12 &&
      buffer.toString("ascii", 0, 4) === "RIFF" &&
      buffer.toString("ascii", 8, 12) === "WEBP") ||
    ((normalized === "image/heic" || normalized === "image/heif" || normalized === "video/mp4") &&
      isIsoBaseMedia(buffer)) ||
    (normalized === "application/pdf" && bufferStartsWith(buffer, [0x25, 0x50, 0x44, 0x46]));
  if (!isValid) {
    return {
      success: false,
      code: "UPLOAD_SIGNATURE_INVALID",
      error: "Файл не соответствует заявленному типу",
    };
  }
  return null;
}

function publicBaseUrl(req) {
  const configured = normalizeString(process.env.MTAXI_PUBLIC_BASE_URL);
  if (configured) return configured.replace(/\/+$/, "");
  const firstHeaderValue = (value) =>
    normalizeString(value).split(",").map((item) => item.trim()).filter(Boolean)[0] || "";
  const proto = firstHeaderValue(req?.headers?.["x-forwarded-proto"]) ||
    normalizeString(req?.protocol) ||
    "http";
  const host = firstHeaderValue(req?.headers?.["x-forwarded-host"] || req?.headers?.host);
  return host ? `${proto}://${host}` : "http://127.0.0.1:8080";
}

function uploadFile(data = {}, auth, req) {
  if (!auth?.user) {
    return {
      success: false,
      code: "UNAUTHENTICATED",
      error: "Пользователь не авторизован",
    };
  }
  const base64 = normalizeString(data.base64);
  if (!base64) {
    return { success: false, code: "UPLOAD_EMPTY", error: "Файл пустой" };
  }
  const buffer = Buffer.from(base64, "base64");
  if (!buffer.length) {
    return { success: false, code: "UPLOAD_EMPTY", error: "Файл пустой" };
  }
  if (buffer.length > maxUploadBytes) {
    return { success: false, code: "UPLOAD_TOO_LARGE", error: "Файл слишком большой" };
  }
  const typeError = validateUploadContentType(data.contentType);
  if (typeError) return typeError;
  const signatureError = validateUploadBuffer(buffer, data.contentType);
  if (signatureError) return signatureError;

  fs.mkdirSync(uploadDir, { recursive: true });
  const ext = safeExtension(data.path || data.filename, data.contentType);
  const filename = `${Date.now()}_${crypto.randomUUID()}${ext}`;
  const diskPath = path.join(uploadDir, filename);
  fs.writeFileSync(diskPath, buffer);
  const url = `${publicBaseUrl(req)}/uploads/${filename}`;
  return {
    success: true,
    code: "FILE_UPLOADED",
    url,
    path: `uploads/${filename}`,
    size: buffer.length,
  };
}

async function uploadFileAsync(data = {}, auth, req) {
  if (!auth?.user) {
    return {
      success: false,
      code: "UNAUTHENTICATED",
      error: "Пользователь не авторизован",
    };
  }
  const base64 = normalizeString(data.base64);
  if (!base64) {
    return { success: false, code: "UPLOAD_EMPTY", error: "Файл пустой" };
  }
  const buffer = Buffer.from(base64, "base64");
  if (!buffer.length) {
    return { success: false, code: "UPLOAD_EMPTY", error: "Файл пустой" };
  }
  if (buffer.length > maxUploadBytes) {
    return { success: false, code: "UPLOAD_TOO_LARGE", error: "Файл слишком большой" };
  }
  const typeError = validateUploadContentType(data.contentType);
  if (typeError) return typeError;
  const signatureError = validateUploadBuffer(buffer, data.contentType);
  if (signatureError) return signatureError;

  await fs.promises.mkdir(uploadDir, { recursive: true });
  const ext = safeExtension(data.path || data.filename, data.contentType);
  const filename = `${Date.now()}_${crypto.randomUUID()}${ext}`;
  const diskPath = path.join(uploadDir, filename);
  await fs.promises.writeFile(diskPath, buffer);
  const url = `${publicBaseUrl(req)}/uploads/${filename}`;
  return {
    success: true,
    code: "FILE_UPLOADED",
    url,
    path: `uploads/${filename}`,
    size: buffer.length,
  };
}

module.exports = {
  uploadFile,
  uploadFileAsync,
  uploadDir,
  publicBaseUrl,
  validateUploadContentType,
  validateUploadBuffer,
};
