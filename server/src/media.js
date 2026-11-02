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
  fs.writeFileSync(`${diskPath}.owner.json`, JSON.stringify({ ownerId: auth.user.id, contentType: data.contentType }), { mode: 0o600 });
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
  await fs.promises.writeFile(`${diskPath}.owner.json`, JSON.stringify({ ownerId: auth.user.id, contentType: data.contentType }), { mode: 0o600 });
  const url = `${publicBaseUrl(req)}/uploads/${filename}`;
  return {
    success: true,
    code: "FILE_UPLOADED",
    url,
    path: `uploads/${filename}`,
    size: buffer.length,
  };
}

function mediaFilename(value) {
  try {
    const pathname = new URL(String(value), 'http://local.invalid').pathname;
    const match = /^\/uploads\/(\d+_[0-9a-f-]+\.(?:jpg|png|heic|heif|webp|pdf|mp4))$/.exec(pathname);
    return match?.[1] || null;
  } catch (_) { return null; }
}

async function authorizeMediaAsync(filename, auth) {
  if (!auth?.user || auth.user.blocked) return false;
  if (auth.user.role === 'admin') return true;
  let owner;
  try { owner = JSON.parse(await fs.promises.readFile(path.join(uploadDir, `${filename}.owner.json`), 'utf8')); }
  catch (_) { return false; } // Legacy unowned files require an explicit admin reconciliation.
  if (owner.ownerId === auth.user.id) return true;
  const { readStoreAsync } = require('./store');
  const store = await readStoreAsync();
  // A driver's published avatar is distinct from private registration files.
  const user = store.users.find(u => u.id === owner.ownerId);
  if (user?.statusDriver === 'approved' && mediaFilename(user.photoUrl) === filename) return true;
  return store.chatMessages.some(message =>
    message.userId === owner.ownerId && mediaFilename(message.imageUrl) === filename &&
    store.chats.some(chat => chat.id === message.chatId && chat.userId === auth.user.id));
}

async function downloadFileAsync(data, auth) {
  if (!auth?.user) return {success:false,code:'UNAUTHENTICATED',error:'Войдите в приложение'};
  const filename = mediaFilename(data.url);
  if (!filename || !await authorizeMediaAsync(filename, auth)) return {success:false,code:'MEDIA_FORBIDDEN',error:'Нет доступа к файлу'};
  try {
    const bytes = await fs.promises.readFile(path.join(uploadDir, filename));
    return {success:true,code:'MEDIA_DOWNLOADED',base64:bytes.toString('base64')};
  } catch (_) { return {success:false,code:'MEDIA_NOT_FOUND',error:'Файл не найден'}; }
}

module.exports = {
  mediaFilename,
  authorizeMediaAsync,
  downloadFileAsync,
  uploadFile,
  uploadFileAsync,
  uploadDir,
  publicBaseUrl,
  validateUploadContentType,
  validateUploadBuffer,
};
