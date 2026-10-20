const fs = require("fs");
const path = require("path");
const dotenv = require("dotenv");
const {
  isPlaceholder,
  runPreflight,
} = require("./preflight");
const { buildContract: buildEnvContract } = require("./export_env_contract");

function normalize(value) {
  return value == null ? "" : String(value).trim();
}

function addCheck(checks, ok, name, message) {
  checks.push({ ok: ok === true, name, message });
}

function readText(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function parsePostgresPassword(databaseUrl) {
  try {
    return decodeURIComponent(new URL(databaseUrl).password || "");
  } catch (_) {
    return "";
  }
}

function parsePostgresHost(databaseUrl) {
  try {
    return new URL(databaseUrl).hostname || "";
  } catch (_) {
    return "";
  }
}

async function validateProductionDeploy({
  rootDir = path.join(__dirname, "../.."),
  envFilePath = path.join(__dirname, "../.env"),
  envExamplePath = path.join(__dirname, "../.env.example"),
  packageJsonPath = path.join(__dirname, "../package.json"),
  packageLockPath = path.join(__dirname, "../package-lock.json"),
  composePath = path.join(rootDir, "docker-compose.production.yml"),
  dockerfilePath = path.join(__dirname, "../Dockerfile"),
  dockerignorePath = path.join(__dirname, "../.dockerignore"),
  backendServicePath = path.join(rootDir, "deploy/systemd/mtaxi-backend.service"),
  backupServicePath = path.join(rootDir, "deploy/systemd/mtaxi-backup.service"),
  backupTimerPath = path.join(rootDir, "deploy/systemd/mtaxi-backup.timer"),
  monitorServicePath = path.join(rootDir, "deploy/systemd/mtaxi-monitor.service"),
  monitorTimerPath = path.join(rootDir, "deploy/systemd/mtaxi-monitor.timer"),
  installScriptPath = path.join(rootDir, "deploy/install_vps_units.sh"),
  opsCheckPath = path.join(rootDir, "deploy/ops_check.sh"),
  nginxConfigPath = path.join(rootDir, "deploy/nginx/mtaxi-api.conf"),
} = {}) {
  const checks = [];
  const compose = readText(composePath);
  const dockerfile = readText(dockerfilePath);
  const dockerignore = readText(dockerignorePath);
  const backendService = readText(backendServicePath);
  const backupService = readText(backupServicePath);
  const backupTimer = readText(backupTimerPath);
  const monitorService = readText(monitorServicePath);
  const monitorTimer = readText(monitorTimerPath);
  const installScript = readText(installScriptPath);
  const opsCheckScript = readText(opsCheckPath);
  const nginxConfig = readText(nginxConfigPath);
  const envFile = readText(envFilePath);
  const envExample = readText(envExamplePath);
  const packageJson = JSON.parse(readText(packageJsonPath));
  const envContract = buildEnvContract({ envExamplePath });
  const parsedEnv = dotenv.parse(envFile);
  const parsedEnvExample = dotenv.parse(envExample);
  const env = {
    ...parsedEnv,
    NODE_ENV: "production",
  };

  addCheck(
    checks,
    /env_file:\s*\n\s*-\s*\.\/server\/\.env/.test(compose),
    "docker-compose.production.yml env_file",
    "production compose reads server/.env",
  );
  addCheck(
    checks,
    /NODE_ENV:\s*"production"/.test(compose),
    "docker-compose.production.yml NODE_ENV",
    "backend container runs in production mode",
  );
  addCheck(
    checks,
    /MTAXI_STORE:\s*"postgres"/.test(compose),
    "docker-compose.production.yml store",
    "backend container forces PostgreSQL store",
  );
  addCheck(
    checks,
    /mtaxi_postgres_data:\/var\/lib\/postgresql\/data/.test(compose) &&
      /\.\/server\/db\/schema\.sql:\/docker-entrypoint-initdb\.d\/001_schema\.sql:ro/.test(compose) &&
      /volumes:\s*[\s\S]*mtaxi_postgres_data:/.test(compose),
    "docker-compose.production.yml PostgreSQL persistence",
    "production PostgreSQL uses named data volume and schema init mount",
  );
  addCheck(
    checks,
    /ports:\s*\n\s*-\s*"127\.0\.0\.1:8080:8080"/.test(compose) &&
      !/["'](?:0\.0\.0\.0:)?8080:8080["']/.test(compose),
    "docker-compose.production.yml local binding",
    "production backend port is bound only to localhost behind reverse proxy",
  );
  addCheck(
    checks,
    !/\$\{[^}]+}/.test(compose),
    "docker-compose.production.yml interpolation",
    "production compose does not depend on shell interpolation before env_file",
  );
  addCheck(
    checks,
    !/MTAXI_ALLOW_LOCAL_SMS:\s*"true"/.test(compose) &&
      !/MTAXI_ALLOW_LOCAL_PAYMENT:\s*"true"/.test(compose) &&
      !/MTAXI_ALLOW_SIMULATED_PUSH:\s*"true"/.test(compose),
    "docker-compose.production.yml dev flags",
    "production compose does not enable local SMS/payment/simulated push",
  );
  addCheck(
    checks,
    /\/var\/backups\/mtaxi:\/var\/backups\/mtaxi/.test(compose),
    "docker-compose.production.yml backup volume",
    "production compose mounts VPS backup directory into backend container",
  );
  addCheck(
    checks,
    /mtaxi_uploads:\/var\/lib\/mtaxi\/uploads/.test(compose) &&
      normalize(parsedEnv.MTAXI_UPLOAD_DIR) === "/var/lib/mtaxi/uploads",
    "docker-compose.production.yml upload volume",
    "production compose persists uploads at MTAXI_UPLOAD_DIR",
  );
  addCheck(
    checks,
    /Environment=MTAXI_BACKUP_DIR=\/var\/backups\/mtaxi/.test(backupService) &&
      /MTAXI_BACKUP_DIR:-\/var\/backups\/mtaxi/.test(installScript),
    "VPS backup path",
    "backup service, install script and production compose use /var/backups/mtaxi",
  );
  addCheck(
    checks,
    /Requires=mtaxi-backend\.service/.test(backupService) &&
      /After=mtaxi-backend\.service/.test(backupService) &&
      /WorkingDirectory=\/opt\/mtaxi/.test(backupService) &&
      /EnvironmentFile=\/opt\/mtaxi\/server\/\.env/.test(backupService) &&
      /Environment=MTAXI_BACKUP_DIR=\/var\/backups\/mtaxi/.test(backupService) &&
      /Environment=MTAXI_BACKUP_RETENTION_DAYS=30/.test(backupService) &&
      /docker compose -f \/opt\/mtaxi\/docker-compose\.production\.yml exec -T/.test(backupService) &&
      /-e MTAXI_BACKUP_DIR="\$MTAXI_BACKUP_DIR"/.test(backupService) &&
      /-e MTAXI_BACKUP_RETENTION_DAYS="\$MTAXI_BACKUP_RETENTION_DAYS"/.test(backupService) &&
      /backend npm run db:backup/.test(backupService) &&
      !/db:restore/.test(backupService),
    "VPS backup service",
    "backup service runs db:backup inside production backend container with backup env",
  );
  addCheck(
    checks,
    /Requires=docker\.service/.test(backendService) &&
      /After=docker\.service network-online\.target/.test(backendService) &&
      /WorkingDirectory=\/opt\/mtaxi/.test(backendService) &&
      /docker compose -f \/opt\/mtaxi\/docker-compose\.production\.yml up -d --build/.test(backendService) &&
      /docker compose -f \/opt\/mtaxi\/docker-compose\.production\.yml down/.test(backendService) &&
      /RemainAfterExit=yes/.test(backendService) &&
      /WantedBy=multi-user\.target/.test(backendService),
    "VPS backend service",
    "backend systemd service starts production compose from /opt/mtaxi after Docker is ready",
  );
  addCheck(
    checks,
    /After=mtaxi-backend\.service network-online\.target/.test(monitorService) &&
      /Wants=network-online\.target/.test(monitorService) &&
      /Type=oneshot/.test(monitorService) &&
      /WorkingDirectory=\/opt\/mtaxi\/server/.test(monitorService) &&
      /EnvironmentFile=-\/opt\/mtaxi\/server\/\.env/.test(monitorService) &&
      /MTAXI_MONITOR_BASE_URL="\$\{MTAXI_MONITOR_BASE_URL:-\$MTAXI_PUBLIC_BASE_URL\}"/.test(monitorService) &&
      !/MTAXI_MONITOR_BASE_URL=https:\/\/api\.mtaxi\.kz/.test(monitorService) &&
      /MTAXI_MONITOR_EXPECT_STORE=postgres/.test(monitorService) &&
      /npm run monitor/.test(monitorService),
    "VPS monitor service",
    "monitor service runs read-only checks from /opt/mtaxi/server with public base URL and PostgreSQL guard",
  );
  addCheck(
    checks,
    /OnCalendar=\*-\*-\* 03:30:00/.test(backupTimer) &&
      /Persistent=true/.test(backupTimer) &&
      /RandomizedDelaySec=10min/.test(backupTimer) &&
      /Unit=mtaxi-backup\.service/.test(backupTimer) &&
      /WantedBy=timers\.target/.test(backupTimer),
    "VPS backup timer",
    "backup timer runs persistent daily backup with randomized delay",
  );
  addCheck(
    checks,
    /OnBootSec=2min/.test(monitorTimer) &&
      /OnUnitActiveSec=5min/.test(monitorTimer) &&
      /AccuracySec=30s/.test(monitorTimer) &&
      /Unit=mtaxi-monitor\.service/.test(monitorTimer) &&
      /WantedBy=timers\.target/.test(monitorTimer),
    "VPS monitor timer",
    "monitor timer runs health checks every 5 minutes after boot",
  );
  addCheck(
    checks,
    /MTAXI_OPS_BASE_URL/.test(opsCheckScript) &&
      /MTAXI_OPS_EXPECT_STORE/.test(opsCheckScript) &&
      /MTAXI_OPS_BACKUP_DIR:-\/var\/backups\/mtaxi/.test(opsCheckScript) &&
      /MTAXI_OPS_BACKUP_MAX_AGE_HOURS:-36/.test(opsCheckScript) &&
      /systemctl is-active --quiet mtaxi-backend\.service/.test(opsCheckScript) &&
      /systemctl is-active --quiet mtaxi-backup\.timer/.test(opsCheckScript) &&
      /systemctl is-active --quiet mtaxi-monitor\.timer/.test(opsCheckScript) &&
      /latest backup manifest/.test(opsCheckScript) &&
      /latest backup age/.test(opsCheckScript) &&
      /backup manifest verification/.test(opsCheckScript) &&
      /npm run db:verify-backup -- "\$latest_backup"/.test(opsCheckScript) &&
      /docker compose -f docker-compose\.production\.yml ps/.test(opsCheckScript) &&
      /curl -fsS "\$base_url\/livez"/.test(opsCheckScript) &&
      /curl -fsS "\$base_url\/readyz"/.test(opsCheckScript) &&
      /"\$base_url\/call\/getStoreHealth"/.test(opsCheckScript) &&
      /npm run monitor/.test(opsCheckScript) &&
      !/docker compose .* down/.test(opsCheckScript) &&
      !/db:restore/.test(opsCheckScript),
    "VPS ops check",
    "ops check is read-only and verifies systemd, backup age/hash, Docker, HTTP and monitor",
  );
  addCheck(
    checks,
    /postgresql-client/.test(dockerfile),
    "server Dockerfile PostgreSQL client",
    "backend image includes pg_dump/pg_restore for backup and rollback",
  );
  addCheck(
    checks,
    fs.existsSync(packageLockPath) &&
      /COPY package\*\.json \.\//.test(dockerfile) &&
      /npm ci --omit=dev/.test(dockerfile) &&
      /^node_modules$/m.test(dockerignore) &&
      /^\.env$/m.test(dockerignore) &&
      /^data$/m.test(dockerignore) &&
      /^uploads$/m.test(dockerignore),
    "server Docker build context",
    "Docker build uses package lock and excludes local secrets/data/uploads",
  );
  const schemaIndex = dockerfile.indexOf("npm run db:apply-schema");
  const preflightIndex = dockerfile.indexOf("npm run preflight");
  const seedAdminIndex = dockerfile.indexOf("npm run seed:admin");
  const startIndex = dockerfile.indexOf("npm run start");
  addCheck(
    checks,
    schemaIndex >= 0 &&
      preflightIndex > schemaIndex &&
      seedAdminIndex > preflightIndex &&
      startIndex > seedAdminIndex,
    "server Dockerfile startup order",
    "backend container applies schema, runs preflight, optionally seeds admin, then starts HTTP",
  );
  addCheck(
    checks,
    /listen\s+80;/.test(nginxConfig) &&
      /return\s+301\s+https:\/\/\$host\$request_uri;/.test(nginxConfig) &&
      /listen\s+443\s+ssl\s+http2;/.test(nginxConfig) &&
      /client_max_body_size\s+25m;/.test(nginxConfig) &&
      /proxy_pass\s+http:\/\/127\.0\.0\.1:8080;/.test(nginxConfig) &&
      /proxy_set_header\s+Host\s+\$host;/.test(nginxConfig) &&
      /proxy_set_header\s+X-Forwarded-For\s+\$proxy_add_x_forwarded_for;/.test(nginxConfig) &&
      /proxy_set_header\s+X-Forwarded-Host\s+\$host;/.test(nginxConfig) &&
      /proxy_set_header\s+X-Forwarded-Proto\s+https;/.test(nginxConfig) &&
      /proxy_set_header\s+X-Request-Id\s+\$request_id;/.test(nginxConfig),
    "nginx reverse proxy",
    "nginx template redirects HTTP to HTTPS and forwards API headers to backend",
  );
  addCheck(
    checks,
    !normalize(parsedEnv.NODE_ENV) ||
      normalize(parsedEnv.NODE_ENV).toLowerCase() === "production",
    "server.env NODE_ENV",
    "server/.env does not force development mode for production deploy",
  );
  const requiredExampleKeys = [
    "NODE_ENV",
    "MTAXI_PUBLIC_BASE_URL",
    "MTAXI_CORS_ORIGINS",
    "MTAXI_TOKEN_SECRET",
    "MTAXI_STORE",
    "POSTGRES_PASSWORD",
    "DATABASE_URL",
    "MTAXI_UPLOAD_DIR",
    "MTAXI_BACKUP_RETENTION_DAYS",
    "MTAXI_PAYMENT_PROVIDER",
    "MTAXI_PAYMENT_URL_TEMPLATE",
    "MTAXI_PAYMENT_CALLBACK_SECRET",
    "MTAXI_SMS_PROVIDER",
    "MTAXI_SMS_HTTP_URL",
    "MTAXI_FCM_ENABLED",
    "MTAXI_ALLOW_SIMULATED_PUSH",
    "FIREBASE_SERVICE_ACCOUNT_JSON",
    "MTAXI_MAINTENANCE_INTERVAL_SEC",
    "MTAXI_PENDING_ORDER_TTL_MIN",
  ];
  const missingExampleKeys = requiredExampleKeys.filter((key) => !(key in parsedEnvExample));
  addCheck(
    checks,
    missingExampleKeys.length === 0,
    "server.env.example production keys",
    missingExampleKeys.length === 0
      ? "server/.env.example contains required production backend keys"
      : `server/.env.example is missing: ${missingExampleKeys.join(", ")}`,
  );
  const requiredScripts = {
    start: "node src/index.js",
    preflight: "node scripts/preflight.js",
    "preflight:production": "NODE_ENV=production node scripts/preflight.js",
    "validate:production-deploy": "node scripts/validate_production_deploy.js",
    smoke: "node scripts/smoke_backend.js",
    "contract:api": "node scripts/export_api_contract.js",
    "contract:env": "node scripts/export_env_contract.js",
    monitor: "node scripts/monitor_backend.js",
    "db:apply-schema": "node scripts/apply_schema.js",
    "db:backup": "node scripts/backup_backend.js",
    "db:verify-backup": "node scripts/verify_backup_manifest.js",
    "db:restore": "node scripts/restore_backend.js",
    "seed:admin": "node scripts/seed_admin.js",
  };
  const missingScripts = Object.entries(requiredScripts)
    .filter(([name, command]) => normalize(packageJson.scripts?.[name]) !== command)
    .map(([name]) => name);
  addCheck(
    checks,
    missingScripts.length === 0,
    "server package production scripts",
    missingScripts.length === 0
      ? "server/package.json contains production lifecycle scripts"
      : `server/package.json script mismatch: ${missingScripts.join(", ")}`,
  );
  addCheck(
    checks,
    normalize(packageJson.engines?.node) === ">=20",
    "server package Node engine",
    "server/package.json requires Node.js 20 or newer",
  );
  addCheck(
    checks,
    envContract.type === "mtaxi-backend-env-contract" &&
      envContract.firebaseUsage === "FCM push only" &&
      envContract.store === "PostgreSQL in production" &&
      envContract.productionValues.NODE_ENV === "production" &&
      envContract.productionValues.MTAXI_STORE === "postgres" &&
      envContract.productionValues.MTAXI_SMS_PROVIDER === "http" &&
      envContract.productionValues.MTAXI_PAYMENT_PROVIDER === "redirect" &&
      envContract.productionValues.MTAXI_FCM_ENABLED === "true" &&
      envContract.missingInExample.length === 0 &&
      envContract.mismatchedProductionDefaults.length === 0 &&
      envContract.unsafeDevDefaults.length === 0,
    "backend env contract",
    "production env contract pins PostgreSQL, backend SMS/payment and FCM-only Firebase",
  );

  const postgresPassword = normalize(env.POSTGRES_PASSWORD);
  const databasePassword = parsePostgresPassword(env.DATABASE_URL);
  const databaseHost = parsePostgresHost(env.DATABASE_URL);
  addCheck(
    checks,
    Boolean(postgresPassword) && !isPlaceholder(postgresPassword),
    "POSTGRES_PASSWORD",
    "PostgreSQL container password is set in server/.env",
  );
  addCheck(
    checks,
    Boolean(databasePassword) && databasePassword === postgresPassword,
    "DATABASE_URL password",
    "DATABASE_URL uses the same PostgreSQL password as POSTGRES_PASSWORD",
  );
  addCheck(
    checks,
    databaseHost === "postgres",
    "DATABASE_URL host",
    "DATABASE_URL points to the PostgreSQL service host inside docker compose",
  );

  const preflight = await runPreflight({
    env,
    checkDatabase: false,
    checkUploadDir: false,
  });
  return {
    ok: checks.every((check) => check.ok) && preflight.ok,
    checks: [...checks, ...preflight.checks],
  };
}

async function main() {
  const result = await validateProductionDeploy();
  for (const check of result.checks) {
    const mark = check.ok ? "OK" : "FAIL";
    console.log(`${mark} ${check.name}: ${check.message}`);
  }
  if (!result.ok) {
    process.exitCode = 1;
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error?.message || error);
    process.exit(1);
  });
}

module.exports = {
  validateProductionDeploy,
};
