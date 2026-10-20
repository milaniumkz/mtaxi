// Store entrypoint. Local development uses JSON.
// PostgreSQL is selected explicitly through MTAXI_STORE=postgres.
const storeType = String(process.env.MTAXI_STORE || "json").trim().toLowerCase();

if (storeType === "postgres" || storeType === "pg") {
  module.exports = require("./postgres_store");
} else {
  module.exports = require("./json_store");
}
