require("dotenv").config();

const fs = require("fs");
const os = require("os");
const path = require("path");
const crypto = require("crypto");
const { spawnSync } = require("child_process");

function normalize(value) {
  return value == null ? "" : String(value).trim();
}

function fail(message) {
  console.error(`MTaxi backup failed: ${message}`);
  process.exit(1);
}

function run(command, args) {
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.error) {
    fail(`${command} is not available: ${result.error.message}`);
  }
  if (result.status !== 0) {
    fail(`${command} exited with code ${result.status}`);
  }
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, "-");
}

function sha256File(filePath) {
  const hash = crypto.createHash("sha256");
  const data = fs.readFileSync(filePath);
  hash.update(data);
  return hash.digest("hex");
}

function retentionDaysFromEnv(value) {
  const raw = normalize(value);
  if (!raw) return 30;
  if (!/^\d+$/.test(raw)) {
    throw new Error("MTAXI_BACKUP_RETENTION_DAYS must be a non-negative integer");
  }
  return Number(raw);
}

async function pruneOldBackups(outputDir, retentionDays) {
  if (retentionDays <= 0) return 0;
  const cutoff = Date.now() - retentionDays * 24 * 60 * 60 * 1000;
  const entries = await fs.promises.readdir(outputDir, { withFileTypes: true });
  let removed = 0;
  for (const entry of entries) {
    if (!entry.isFile()) continue;
    if (!/^mtaxi-(backup|db|uploads)-/.test(entry.name)) continue;
    const filePath = path.join(outputDir, entry.name);
    const stat = await fs.promises.stat(filePath);
    if (stat.mtimeMs >= cutoff) continue;
    await fs.promises.rm(filePath, { force: true });
    removed += 1;
  }
  return removed;
}

async function main() {
  process.umask(0o077);
  const databaseUrl = normalize(process.env.DATABASE_URL);
  if (!databaseUrl) {
    fail("DATABASE_URL is required");
  }
  const retentionDays = retentionDaysFromEnv(process.env.MTAXI_BACKUP_RETENTION_DAYS);
  const outputDir = path.resolve(
    normalize(process.env.MTAXI_BACKUP_DIR) || path.join(process.cwd(), "backups"),
  );
  const uploadDir = path.resolve(
    normalize(process.env.MTAXI_UPLOAD_DIR) || path.join(os.tmpdir(), "mtaxi-uploads"),
  );
  await fs.promises.mkdir(outputDir, { recursive: true });

  const stamp = timestamp();
  const dbDump = path.join(outputDir, `mtaxi-db-${stamp}.dump`);
  const uploadsArchive = path.join(outputDir, `mtaxi-uploads-${stamp}.tar.gz`);
  const manifestPath = path.join(outputDir, `mtaxi-backup-${stamp}.json`);

  run("pg_dump", [
    "--format=custom",
    "--no-owner",
    "--no-acl",
    "--file",
    dbDump,
    databaseUrl,
  ]);

  let uploadsIncluded = false;
  if (fs.existsSync(uploadDir)) {
    run("tar", [
      "-czf",
      uploadsArchive,
      "-C",
      path.dirname(uploadDir),
      path.basename(uploadDir),
    ]);
    uploadsIncluded = true;
  }

  await fs.promises.writeFile(
    manifestPath,
    JSON.stringify(
      {
        type: "mtaxi-backup",
        version: 1,
        createdAt: new Date().toISOString(),
        databaseDump: path.basename(dbDump),
        databaseDumpSha256: sha256File(dbDump),
        uploadsArchive: uploadsIncluded ? path.basename(uploadsArchive) : null,
        uploadsArchiveSha256: uploadsIncluded ? sha256File(uploadsArchive) : null,
        uploadDir,
      },
      null,
      2,
    ),
  );
  console.log(`MTaxi backup created: ${manifestPath}`);
  const removed = await pruneOldBackups(outputDir, retentionDays);
  if (removed > 0) {
    console.log(`MTaxi backup retention removed ${removed} old file(s)`);
  }
}

if (require.main === module) {
  main().catch((error) => fail(error?.message || String(error)));
}

module.exports = {
  pruneOldBackups,
  retentionDaysFromEnv,
  sha256File,
};
