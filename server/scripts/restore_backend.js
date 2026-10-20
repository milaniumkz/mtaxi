require("dotenv").config();

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

function normalize(value) {
  return value == null ? "" : String(value).trim();
}

function fail(message) {
  console.error(`MTaxi restore failed: ${message}`);
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

function runQuiet(command, args) {
  const result = spawnSync(command, args, { stdio: "ignore" });
  if (result.error) {
    fail(`${command} is not available: ${result.error.message}`);
  }
  if (result.status !== 0) {
    fail(`${command} validation failed with code ${result.status}`);
  }
}

function readManifest(manifestPath) {
  if (!manifestPath) return {};
  const parsed = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  if (!parsed || typeof parsed !== "object") {
    return {};
  }
  if (parsed.type && parsed.type !== "mtaxi-backup") {
    throw new Error("manifest is not a MTaxi backup");
  }
  return {
    ...parsed,
    manifestDir: path.dirname(path.resolve(manifestPath)),
  };
}

function resolveManifestPath(filePath, manifest) {
  const value = normalize(filePath);
  if (!value) {
    return "";
  }
  return path.isAbsolute(value)
    ? value
    : path.resolve(manifest.manifestDir || process.cwd(), value);
}

async function main() {
  const dryRun = normalize(process.env.MTAXI_RESTORE_DRY_RUN).toLowerCase() === "true";
  if (!dryRun && normalize(process.env.MTAXI_RESTORE_CONFIRM) !== "YES") {
    fail("set MTAXI_RESTORE_CONFIRM=YES to restore and overwrite current data");
  }
  const databaseUrl = normalize(process.env.DATABASE_URL);
  if (!databaseUrl) {
    fail("DATABASE_URL is required");
  }

  const manifestPath = normalize(process.argv[2] || process.env.MTAXI_RESTORE_MANIFEST);
  const manifest = readManifest(manifestPath);
  const dbDumpRaw = normalize(process.env.MTAXI_RESTORE_DB_DUMP || manifest.databaseDump);
  if (!dbDumpRaw) {
    fail("database dump file is required; pass manifest path or MTAXI_RESTORE_DB_DUMP");
  }
  const dbDump = resolveManifestPath(dbDumpRaw, manifest);
  if (!fs.existsSync(dbDump) || !fs.statSync(dbDump).isFile()) {
    fail("database dump file is required; pass manifest path or MTAXI_RESTORE_DB_DUMP");
  }
  runQuiet("pg_restore", ["--list", dbDump]);

  const uploadsArchive = normalize(
    process.env.MTAXI_RESTORE_UPLOADS_ARCHIVE || manifest.uploadsArchive,
  );
  let resolvedArchive = "";
  let uploadDir = "";
  if (uploadsArchive) {
    resolvedArchive = resolveManifestPath(uploadsArchive, manifest);
    if (!fs.existsSync(resolvedArchive)) {
      fail(`uploads archive not found: ${resolvedArchive}`);
    }
    runQuiet("tar", ["-tzf", resolvedArchive]);
    uploadDir = path.resolve(
      normalize(process.env.MTAXI_UPLOAD_DIR || manifest.uploadDir) ||
        path.join(os.tmpdir(), "mtaxi-uploads"),
    );
  }

  if (dryRun) {
    console.log("MTaxi restore dry run ok");
    console.log(`Database dump: ${dbDump}`);
    if (resolvedArchive) {
      console.log(`Uploads archive: ${resolvedArchive}`);
      console.log(`Upload target: ${uploadDir}`);
    }
    return;
  }

  run("pg_restore", [
    "--clean",
    "--if-exists",
    "--no-owner",
    "--no-acl",
    "--dbname",
    databaseUrl,
    dbDump,
  ]);

  if (resolvedArchive) {
    await fs.promises.rm(uploadDir, { recursive: true, force: true });
    await fs.promises.mkdir(uploadDir, { recursive: true });
    run("tar", ["-xzf", resolvedArchive, "--strip-components=1", "-C", uploadDir]);
  }

  console.log("MTaxi restore completed");
}

if (require.main === module) {
  main().catch((error) => fail(error?.message || String(error)));
}

module.exports = {
  readManifest,
  resolveManifestPath,
};
