require("dotenv").config();

const {
  assertBackendOnlyArchitecture,
  callBackend,
  expectJson,
} = require("./smoke_backend");

function normalize(value) {
  return value == null ? "" : String(value).trim();
}

async function main() {
  const baseUrl =
    normalize(process.env.MTAXI_STATUS_BASE_URL) ||
    normalize(process.env.MTAXI_SMOKE_BASE_URL) ||
    "http://127.0.0.1:8080";

  const live = await expectJson(`${baseUrl}/livez`);
  const ready = await expectJson(`${baseUrl}/readyz`);
  const health = await callBackend(baseUrl, "getStoreHealth");
  const architecture = await callBackend(baseUrl, "getBackendArchitectureStatus");
  assertBackendOnlyArchitecture(architecture);

  const summary = {
    ok: true,
    baseUrl,
    live: live.ok === true,
    ready: ready.ok === true,
    storeType: ready.store?.type || health.store?.type || null,
    schemaVersion: ready.store?.schemaVersion || health.store?.schemaVersion || null,
    architecture: architecture.architecture,
    firebaseAllowedOnlyFor: architecture.firebaseAllowedOnlyFor,
  };

  console.log(JSON.stringify(summary, null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`MTaxi backend status failed: ${error?.message || String(error)}`);
    process.exit(1);
  });
}

module.exports = {
  main,
};
