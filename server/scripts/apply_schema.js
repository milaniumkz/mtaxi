require("dotenv").config();

const fs = require("fs");
const path = require("path");
const { Client } = require("pg");

const BASE_SCHEMA_VERSION = "2026-07-22-backend-base";

async function applySchema({ databaseUrl = process.env.DATABASE_URL } = {}) {
  if (!databaseUrl) {
    throw new Error("DATABASE_URL is required");
  }
  const schema = fs.readFileSync(path.join(__dirname, "../db/schema.sql"), "utf8");
  const client = new Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    await client.query(schema);
    const version = await client.query(
      "SELECT version FROM schema_migrations WHERE version = $1",
      [BASE_SCHEMA_VERSION],
    );
    if (version.rowCount !== 1) {
      throw new Error(`PostgreSQL schema version was not applied: ${BASE_SCHEMA_VERSION}`);
    }
  } finally {
    await client.end();
  }
}

async function main() {
  await applySchema();
  console.log("PostgreSQL schema applied");
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error?.message || error);
    process.exit(1);
  });
}

module.exports = {
  BASE_SCHEMA_VERSION,
  applySchema,
};
