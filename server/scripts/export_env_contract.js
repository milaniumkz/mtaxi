const fs = require("fs");
const path = require("path");
const dotenv = require("dotenv");

const rootDir = path.resolve(__dirname, "../..");

const requiredProduction = [
  "NODE_ENV",
  "MTAXI_PUBLIC_BASE_URL",
  "MTAXI_TOKEN_SECRET",
  "MTAXI_STORE",
  "DATABASE_URL",
  "MTAXI_SMS_PROVIDER",
  "MTAXI_PAYMENT_PROVIDER",
  "MTAXI_PAYMENT_URL_TEMPLATE",
  "MTAXI_PAYMENT_CALLBACK_SECRET",
  "MTAXI_FCM_ENABLED",
];

const productionValues = {
  NODE_ENV: "production",
  MTAXI_STORE: "postgres",
  MTAXI_SMS_PROVIDER: "disabled",
  MTAXI_PAYMENT_PROVIDER: "redirect",
  MTAXI_FCM_ENABLED: "true",
};

const forbiddenTrueInProduction = [
  "MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL",
  "MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL",
  "MTAXI_ENABLE_LEGACY_CREATE_TOKEN",
  "MTAXI_SMS_DEV_RETURN_CODE",
  "MTAXI_ALLOW_LOCAL_SMS",
  "MTAXI_ALLOW_LOCAL_PAYMENT",
  "MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY",
  "MTAXI_ALLOW_SIMULATED_PUSH",
];

const forbiddenFirebaseDataEnvPatterns = [
  "^FIREBASE_AUTH_",
  "^FIREBASE_DATABASE_",
  "^FIREBASE_FIRESTORE_",
  "^FIREBASE_FUNCTIONS_",
  "^FIREBASE_STORAGE_",
  "^FIREBASE_SMS_",
  "^FIREBASE_DATABASE_URL$",
  "^FIREBASE_STORAGE_BUCKET$",
];

function buildContract({ envExamplePath = path.join(rootDir, "server/.env.example") } = {}) {
  const envExample = dotenv.parse(fs.readFileSync(envExamplePath, "utf8"));
  const envExampleKeys = Object.keys(envExample).sort();
  const missingInExample = requiredProduction.filter((name) => !(name in envExample));
  const mismatchedProductionDefaults = Object.entries(productionValues)
    .filter(([name, expected]) => String(envExample[name] || "") !== expected)
    .map(([name, expected]) => ({ name, expected, actual: String(envExample[name] || "") }));
  const unsafeDevDefaults = forbiddenTrueInProduction
    .filter((name) => String(envExample[name] || "").toLowerCase() === "true");

  return {
    type: "mtaxi-backend-env-contract",
    version: 1,
    runtime: "Node.js HTTP backend",
    store: "PostgreSQL in production",
    firebaseUsage: "FCM push only",
    firebaseCredentialRequirement: "FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS",
    requiredProduction,
    productionValues,
    forbiddenTrueInProduction,
    forbiddenFirebaseDataEnvPatterns,
    envExampleKeys,
    missingInExample,
    mismatchedProductionDefaults,
    unsafeDevDefaults,
  };
}

function main() {
  const outputPath = process.argv[2] || "";
  const contract = buildContract();
  if (contract.missingInExample.length > 0) {
    throw new Error(`Missing env example keys: ${contract.missingInExample.join(", ")}`);
  }
  if (contract.mismatchedProductionDefaults.length > 0) {
    throw new Error(`Wrong production defaults: ${JSON.stringify(contract.mismatchedProductionDefaults)}`);
  }
  if (contract.unsafeDevDefaults.length > 0) {
    throw new Error(`Unsafe dev defaults enabled: ${contract.unsafeDevDefaults.join(", ")}`);
  }
  const json = `${JSON.stringify(contract, null, 2)}\n`;
  if (outputPath) {
    fs.mkdirSync(path.dirname(path.resolve(outputPath)), { recursive: true });
    fs.writeFileSync(outputPath, json);
  } else {
    process.stdout.write(json);
  }
}

if (require.main === module) {
  try {
    main();
  } catch (error) {
    console.error(`MTaxi env contract export failed: ${error?.message || String(error)}`);
    process.exit(1);
  }
}

module.exports = { buildContract };
