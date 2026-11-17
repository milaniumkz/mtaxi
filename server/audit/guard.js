const path = require('node:path');
function guard() {
  const db = new URL(process.env.DATABASE_URL || 'invalid:');
  if (!['127.0.0.1', 'localhost'].includes(db.hostname) || !/audit/.test(db.pathname)) {
    throw new Error('Audit requires an explicitly local audit PostgreSQL database');
  }
  if (process.env.MTAXI_FCM_ENABLED !== 'false' || process.env.MTAXI_PAYMENT_MODE !== 'kaspi_manual') {
    throw new Error('Audit requires disabled FCM and manual test payments');
  }
  return db;
}
module.exports = { guard };
