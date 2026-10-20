const fs = require("fs");
const path = require("path");

const {
  blockedUserAllowedCalls,
  handlerNames,
  publicAuthRateLimitedCalls,
} = require("../src/call_router");

const rootDir = path.resolve(__dirname, "../..");

const publicReadCalls = new Set([
  "getStoreHealth",
  "getRuntimeSettings",
  "getBackendArchitectureStatus",
  "listCityTariffs",
  "listIntercityRoutes",
  "getContentDocument",
  "forwardGeocodeLookup",
  "reverseGeocodeLookup",
  "placesAutocomplete",
  "placeDetails",
  "suggestAddressesLookup",
  "routeLookup",
]);

function categoryFor(name) {
  if (name.startsWith("admin")) return "admin";
  if (name.includes("Sms") || name.includes("Password") || name === "me") return "auth";
  if (name.includes("Order") || name.includes("DriverOrders")) return "orders";
  if (name.includes("Payment") || name.includes("Withdrawal") || name.includes("Money")) return "money";
  if (name.includes("SupportChat") || name.includes("Chat")) return "support";
  if (name.includes("Fcm") || name.includes("Push")) return "push";
  if (name.includes("Geocode") || name.includes("Place") || name.includes("Address") || name.includes("route")) {
    return "geo";
  }
  if (name.includes("Tariff") || name.includes("Route") || name.includes("Content") || name.includes("Settings")) {
    return "settings";
  }
  if (name.includes("Registration") || name.includes("Preferences") || name.includes("Account")) return "users";
  if (name.includes("upload")) return "media";
  return "system";
}

function accessFor(name) {
  if (publicAuthRateLimitedCalls.has(name)) return "public-rate-limited";
  if (publicReadCalls.has(name)) return "public-read";
  if (name.startsWith("admin") || name === "confirmDriverTopUpPayment" || name === "failDriverTopUpPayment") {
    return "admin-token";
  }
  if (name === "runMaintenanceTasks") return "internal-or-admin";
  return "user-token";
}

function scanClientCalls() {
  const calls = new Set();
  const libDir = path.join(rootDir, "lib");
  function scan(dir) {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        scan(fullPath);
        continue;
      }
      if (!entry.name.endsWith(".dart")) continue;
      const source = fs.readFileSync(fullPath, "utf8");
      const regex = /(?:makeCloudCall|mtaxiBackendCall)\(\s*['"]([^'"]+)['"]/g;
      let match;
      while ((match = regex.exec(source)) !== null) {
        calls.add(match[1]);
      }
    }
  }
  scan(libDir);
  return [...calls].sort();
}

function buildContract() {
  const serverHandlers = [...handlerNames].sort();
  const clientCallNames = scanClientCalls();
  const handlerSet = new Set(serverHandlers);
  const missingServerHandlers = clientCallNames.filter((name) => !handlerSet.has(name));
  return {
    type: "mtaxi-backend-api-contract",
    version: 1,
    endpoint: "POST /call/:name",
    transport: "HTTP JSON",
    authHeader: "Authorization: Bearer <backend-token>",
    firebaseUsage: "FCM push only",
    serverHandlerCount: serverHandlers.length,
    clientCallCount: clientCallNames.length,
    missingServerHandlers,
    handlers: serverHandlers.map((name) => ({
      name,
      category: categoryFor(name),
      access: accessFor(name),
      blockedUserAllowed: blockedUserAllowedCalls.has(name),
      rateLimited: publicAuthRateLimitedCalls.has(name),
    })),
    clientCalls: clientCallNames,
  };
}

function main() {
  const outputPath = process.argv[2] || "";
  const contract = buildContract();
  if (contract.missingServerHandlers.length > 0) {
    throw new Error(`Missing server handlers: ${contract.missingServerHandlers.join(", ")}`);
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
    console.error(`MTaxi API contract export failed: ${error?.message || String(error)}`);
    process.exit(1);
  }
}

module.exports = { buildContract };
