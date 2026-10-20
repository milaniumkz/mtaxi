const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

function normalize(value) {
  return value == null ? "" : String(value).trim();
}

function fail(message) {
  console.error(`MTaxi backup verification failed: ${message}`);
  process.exit(1);
}

function sha256File(filePath) {
  const hash = crypto.createHash("sha256");
  hash.update(fs.readFileSync(filePath));
  return hash.digest("hex");
}

function resolveBackupFile(manifestDir, value, fieldName) {
  const raw = normalize(value);
  if (!raw) return "";
  if (path.isAbsolute(raw) || raw.includes("..") || raw.includes("/") || raw.includes("\\")) {
    throw new Error(`${fieldName} must be a file name inside the backup directory`);
  }
  return path.resolve(manifestDir, raw);
}

function assertFileWithSha(filePath, expectedSha, label) {
  if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
    throw new Error(`${label} not found: ${filePath}`);
  }
  const sha = normalize(expectedSha);
  if (!/^[a-f0-9]{64}$/i.test(sha)) {
    throw new Error(`${label} sha256 is missing or invalid`);
  }
  const actual = sha256File(filePath);
  if (actual.toLowerCase() !== sha.toLowerCase()) {
    throw new Error(`${label} sha256 mismatch`);
  }
}

function verifyBackupManifest(manifestPath) {
  const resolvedManifest = path.resolve(normalize(manifestPath));
  const manifestDir = path.dirname(resolvedManifest);
  const manifest = JSON.parse(fs.readFileSync(resolvedManifest, "utf8"));
  if (!manifest || typeof manifest !== "object") {
    throw new Error("manifest must be a JSON object");
  }
  if (manifest.type !== "mtaxi-backup") {
    throw new Error("manifest is not a MTaxi backup");
  }
  if (manifest.version !== 1) {
    throw new Error("unsupported backup manifest version");
  }

  const dbDump = resolveBackupFile(manifestDir, manifest.databaseDump, "databaseDump");
  if (!dbDump) {
    throw new Error("databaseDump is required");
  }
  assertFileWithSha(dbDump, manifest.databaseDumpSha256, "database dump");

  const uploadsArchive = resolveBackupFile(
    manifestDir,
    manifest.uploadsArchive,
    "uploadsArchive",
  );
  if (uploadsArchive) {
    assertFileWithSha(uploadsArchive, manifest.uploadsArchiveSha256, "uploads archive");
  } else if (manifest.uploadsArchiveSha256) {
    throw new Error("uploadsArchiveSha256 is set without uploadsArchive");
  }

  return {
    manifestPath: resolvedManifest,
    databaseDump: dbDump,
    uploadsArchive,
  };
}

async function main() {
  const manifestPath = normalize(process.argv[2] || process.env.MTAXI_BACKUP_MANIFEST);
  if (!manifestPath) {
    fail("pass backup manifest path or set MTAXI_BACKUP_MANIFEST");
  }
  const result = verifyBackupManifest(manifestPath);
  console.log("MTaxi backup verification ok");
  console.log(`Manifest: ${result.manifestPath}`);
  console.log(`Database dump: ${result.databaseDump}`);
  if (result.uploadsArchive) {
    console.log(`Uploads archive: ${result.uploadsArchive}`);
  }
}

if (require.main === module) {
  main().catch((error) => fail(error?.message || String(error)));
}

module.exports = {
  resolveBackupFile,
  sha256File,
  verifyBackupManifest,
};
