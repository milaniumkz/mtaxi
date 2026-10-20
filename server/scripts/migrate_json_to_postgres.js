require("dotenv").config();

const fs = require("fs");
const path = require("path");
const { Client } = require("pg");

function jsonString(value) {
  return JSON.stringify(value ?? {});
}

function iso(value) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function coords(value) {
  if (!value || typeof value !== "object") return { lat: null, lng: null };
  return {
    lat: Number.isFinite(value.latitude) ? value.latitude : Number.isFinite(value.lat) ? value.lat : null,
    lng: Number.isFinite(value.longitude) ? value.longitude : Number.isFinite(value.lng) ? value.lng : null,
  };
}

function dataFilePath() {
  const dataDir = process.env.MTAXI_DATA_DIR || path.join(__dirname, "../data");
  return process.env.MTAXI_JSON_FILE || path.join(dataDir, "local-db.json");
}

function countStoreRecords(store = {}) {
  const genericCollections = Object.values(store.genericCollections || {})
    .reduce((sum, items) => sum + (Array.isArray(items) ? items.length : 0), 0);
  return {
    users: (store.users || []).length,
    smsCodes: (store.smsCodes || []).length,
    orders: (store.orders || []).length,
    payments: (store.payments || []).length,
    withdrawals: (store.withdrawals || []).length,
    ledger: (store.ledger || []).length,
    chats: (store.chats || []).length,
    chatMessages: (store.chatMessages || []).length,
    fcmTokens: (store.fcmTokens || []).length,
    notifications: (store.notifications || []).length,
    notificationDeliveries: (store.notificationDeliveries || []).length,
    pushDeliveryAcks: (store.pushDeliveryAcks || []).length,
    cityPrices: (store.cityPrices || []).length,
    intercityRoutes: (store.intercityRoutes || []).length,
    settings: Object.keys(store.settings || {}).length +
      (store.intercityTariff ? 1 : 0) +
      (store.paymentSequence != null ? 1 : 0),
    contentDocuments: Object.keys(store.content || {}).length,
    genericDocuments: genericCollections,
    auditLogs: (store.auditLogs || []).length,
  };
}

function formatMigrationReport(counts) {
  return Object.entries(counts)
    .map(([key, value]) => `${key}=${value}`)
    .join(", ");
}

const POSTGRES_COUNT_QUERIES = {
  users: "SELECT count(*)::int AS count FROM users",
  smsCodes: "SELECT count(*)::int AS count FROM sms_codes",
  orders: "SELECT count(*)::int AS count FROM orders",
  payments: "SELECT count(*)::int AS count FROM payments",
  withdrawals: "SELECT count(*)::int AS count FROM withdrawals",
  ledger: "SELECT count(*)::int AS count FROM ledger",
  chats: "SELECT count(*)::int AS count FROM support_chats",
  chatMessages: "SELECT count(*)::int AS count FROM support_messages",
  notifications: "SELECT count(*)::int AS count FROM notifications",
  notificationDeliveries: "SELECT count(*)::int AS count FROM notification_deliveries",
  pushDeliveryAcks: "SELECT count(*)::int AS count FROM push_delivery_acks",
  contentDocuments: "SELECT count(*)::int AS count FROM content_documents",
  genericDocuments: "SELECT count(*)::int AS count FROM generic_documents",
  auditLogs: "SELECT count(*)::int AS count FROM audit_logs",
};

async function countPostgresRecords(client) {
  const counts = {};
  for (const [key, sql] of Object.entries(POSTGRES_COUNT_QUERIES)) {
    const result = await client.query(sql);
    counts[key] = Number(result.rows?.[0]?.count) || 0;
  }
  return counts;
}

function assertMigrationCounts(sourceCounts, targetCounts) {
  const mismatches = [];
  for (const key of Object.keys(POSTGRES_COUNT_QUERIES)) {
    const source = Number(sourceCounts[key]) || 0;
    const target = Number(targetCounts[key]) || 0;
    if (target < source) {
      mismatches.push(`${key}: source=${source}, postgres=${target}`);
    }
  }
  if (mismatches.length > 0) {
    throw new Error(`PostgreSQL migration verification failed: ${mismatches.join("; ")}`);
  }
}

async function upsert(client, sql, values) {
  await client.query(sql, values);
}

async function migrate() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error("DATABASE_URL is required");
  }
  const file = dataFilePath();
  if (!fs.existsSync(file)) {
    throw new Error(`JSON store not found: ${file}`);
  }

  const store = JSON.parse(fs.readFileSync(file, "utf8"));
  const counts = countStoreRecords(store);
  const client = new Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    await client.query("BEGIN");
    const schema = fs.readFileSync(path.join(__dirname, "../db/schema.sql"), "utf8");
    await client.query(schema);

    for (const user of store.users || []) {
      const c = coords(user.coords);
      await upsert(
        client,
        `INSERT INTO users (
          id, phone, password_hash, display_name, role, role_state,
          active_mode, preferred_client_mode, is_driver, status_driver,
          driver_registration_status, driver_online, blocked, vip, balance,
          active_passenger_order_id, active_driver_order_id,
          has_active_passenger_order, has_active_driver_order,
          city, lat, lng, data, created_at, updated_at
        ) VALUES (
          $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25
        )
        ON CONFLICT (id) DO UPDATE SET
          phone = EXCLUDED.phone,
          password_hash = EXCLUDED.password_hash,
          display_name = EXCLUDED.display_name,
          role = EXCLUDED.role,
          role_state = EXCLUDED.role_state,
          active_mode = EXCLUDED.active_mode,
          preferred_client_mode = EXCLUDED.preferred_client_mode,
          is_driver = EXCLUDED.is_driver,
          status_driver = EXCLUDED.status_driver,
          driver_registration_status = EXCLUDED.driver_registration_status,
          driver_online = EXCLUDED.driver_online,
          blocked = EXCLUDED.blocked,
          vip = EXCLUDED.vip,
          balance = EXCLUDED.balance,
          active_passenger_order_id = EXCLUDED.active_passenger_order_id,
          active_driver_order_id = EXCLUDED.active_driver_order_id,
          has_active_passenger_order = EXCLUDED.has_active_passenger_order,
          has_active_driver_order = EXCLUDED.has_active_driver_order,
          city = EXCLUDED.city,
          lat = EXCLUDED.lat,
          lng = EXCLUDED.lng,
          data = EXCLUDED.data,
          updated_at = EXCLUDED.updated_at`,
        [
          user.id,
          user.phone || "",
          user.passwordHash || user.password || null,
          user.displayName || user.display_name || "",
          user.role || (user.isDriver ? "driver" : "passenger"),
          user.roleState || "PASSENGER",
          user.activeMode || "passenger",
          user.preferredClientMode || "passenger",
          user.isDriver === true,
          user.statusDriver || "",
          user.driverRegistrationStatus || "",
          user.driverOnLine === true,
          user.blocked === true,
          user.vip === true,
          Number(user.balance) || 0,
          user.activePassengerOrderId || null,
          user.activeDriverOrderId || null,
          user.hasActivePassengerOrder === true,
          user.hasActiveDriverOrder === true,
          user.city || "",
          c.lat,
          c.lng,
          jsonString(user),
          iso(user.createdAt || user.created_time) || new Date().toISOString(),
          iso(user.updatedAt) || new Date().toISOString(),
        ],
      );
    }

    for (const sms of store.smsCodes || []) {
      await upsert(
        client,
        `INSERT INTO sms_codes (id, phone, sms_code, sms_code_hash, provider, status, data, created_at, expires_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
         ON CONFLICT (id) DO UPDATE SET
           phone = EXCLUDED.phone,
           sms_code = EXCLUDED.sms_code,
           sms_code_hash = EXCLUDED.sms_code_hash,
           provider = EXCLUDED.provider,
           status = EXCLUDED.status,
           data = EXCLUDED.data,
           expires_at = EXCLUDED.expires_at`,
        [
          sms.id,
          sms.phone || "",
          sms.smsCode || sms.code || "",
          sms.smsCodeHash || sms.codeHash || "",
          sms.provider || "local",
          sms.status || "sent",
          jsonString(sms),
          iso(sms.createdAt) || new Date().toISOString(),
          iso(sms.expiresAt),
        ],
      );
    }

    for (const order of store.orders || []) {
      const from = coords(order.otCoords || order.fromCoords);
      const to = coords(order.kudaCoords || order.toCoords);
      await upsert(
        client,
        `INSERT INTO orders (
          id, user_id, driver_id, type, status, ot, kuda,
          ot_lat, ot_lng, kuda_lat, kuda_lng, price, accepted_commission,
          comment, cancelled_by, data, created_at, updated_at,
          accepted_at, completed_at, cancelled_at
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21)
        ON CONFLICT (id) DO UPDATE SET
          user_id = EXCLUDED.user_id,
          driver_id = EXCLUDED.driver_id,
          type = EXCLUDED.type,
          status = EXCLUDED.status,
          ot = EXCLUDED.ot,
          kuda = EXCLUDED.kuda,
          ot_lat = EXCLUDED.ot_lat,
          ot_lng = EXCLUDED.ot_lng,
          kuda_lat = EXCLUDED.kuda_lat,
          kuda_lng = EXCLUDED.kuda_lng,
          price = EXCLUDED.price,
          accepted_commission = EXCLUDED.accepted_commission,
          comment = EXCLUDED.comment,
          cancelled_by = EXCLUDED.cancelled_by,
          data = EXCLUDED.data,
          updated_at = EXCLUDED.updated_at`,
        [
          order.id,
          order.userId || null,
          order.driverId || null,
          order.type || "taxi",
          Number.isInteger(order.status) ? order.status : Number(order.status) || 0,
          order.ot || order.otkuda || "",
          order.kuda || "",
          from.lat,
          from.lng,
          to.lat,
          to.lng,
          Number(order.price) || 0,
          Number(order.acceptedCommission) || 0,
          order.comment || "",
          order.cancelledBy || "",
          jsonString(order),
          iso(order.createdAt || order.date) || new Date().toISOString(),
          iso(order.updatedAt) || new Date().toISOString(),
          iso(order.acceptedAt),
          iso(order.completedAt),
          iso(order.cancelledAt),
        ],
      );
    }

    for (const payment of store.payments || []) {
      await upsert(
        client,
        `INSERT INTO payments (id, user_id, payment_id, status, amount, idempotency_key, provider, data, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
         ON CONFLICT (id) DO UPDATE SET
           status = EXCLUDED.status,
           amount = EXCLUDED.amount,
           data = EXCLUDED.data,
           updated_at = EXCLUDED.updated_at`,
        [
          payment.id,
          payment.userId || null,
          payment.paymentId || payment.id,
          payment.status || "pending",
          Number(payment.amount) || 0,
          payment.idempotencyKey || null,
          payment.provider || "local",
          jsonString(payment),
          iso(payment.createdAt) || new Date().toISOString(),
          iso(payment.updatedAt) || new Date().toISOString(),
        ],
      );
    }

    for (const withdrawal of store.withdrawals || []) {
      await upsert(
        client,
        `INSERT INTO withdrawals (id, user_id, status, amount, data, created_at, updated_at, resolved_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
         ON CONFLICT (id) DO UPDATE SET
           status = EXCLUDED.status,
           amount = EXCLUDED.amount,
           data = EXCLUDED.data,
           updated_at = EXCLUDED.updated_at,
           resolved_at = EXCLUDED.resolved_at`,
        [
          withdrawal.id,
          withdrawal.userId || null,
          withdrawal.status || "pending",
          Number(withdrawal.amount) || 0,
          jsonString(withdrawal),
          iso(withdrawal.createdAt) || new Date().toISOString(),
          iso(withdrawal.updatedAt) || new Date().toISOString(),
          iso(withdrawal.resolvedAt),
        ],
      );
    }

    for (const entry of store.ledger || []) {
      await upsert(
        client,
        `INSERT INTO ledger (id, user_id, order_id, payment_id, type, source, amount, balance_before, balance_after, data, created_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
         ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data`,
        [
          entry.id,
          entry.userId || null,
          entry.orderId || null,
          entry.paymentId || null,
          entry.type || "unknown",
          entry.source || "backend",
          Number(entry.amount) || 0,
          entry.balanceBefore == null ? null : Number(entry.balanceBefore),
          entry.balanceAfter == null ? null : Number(entry.balanceAfter),
          jsonString(entry),
          iso(entry.createdAt) || new Date().toISOString(),
        ],
      );
    }

    for (const chat of store.chats || []) {
      await upsert(
        client,
        `INSERT INTO support_chats (id, user_id, admin_id, support_chat_key, last_message, unread_for_admin, unread_for_user, data, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
         ON CONFLICT (id) DO UPDATE SET
           last_message = EXCLUDED.last_message,
           unread_for_admin = EXCLUDED.unread_for_admin,
           unread_for_user = EXCLUDED.unread_for_user,
           data = EXCLUDED.data,
           updated_at = EXCLUDED.updated_at`,
        [
          chat.id,
          chat.userId || null,
          chat.adminId || null,
          chat.supportChatKey || null,
          chat.lastMessage || chat.last_message || "",
          Number(chat.unreadForAdmin ?? chat.unread_for_admin) || 0,
          Number(chat.unreadForUser ?? chat.unread_for_user) || 0,
          jsonString(chat),
          iso(chat.createdAt) || new Date().toISOString(),
          iso(chat.updatedAt || chat.lastMessageTime) || new Date().toISOString(),
        ],
      );
    }

    for (const message of store.chatMessages || []) {
      await upsert(
        client,
        `INSERT INTO support_messages (id, chat_id, user_id, text, image_url, data, created_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7)
         ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data`,
        [
          message.id,
          message.chatId || null,
          message.userId || null,
          message.text || "",
          message.imageUrl || "",
          jsonString(message),
          iso(message.createdAt) || new Date().toISOString(),
        ],
      );
    }

    for (const token of store.fcmTokens || []) {
      const fcmToken = token.fcmToken || token.token;
      if (!fcmToken) continue;
      await upsert(
        client,
        `INSERT INTO fcm_tokens (id, user_id, token, platform, enabled, data, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
         ON CONFLICT (token) DO UPDATE SET
           user_id = EXCLUDED.user_id,
           platform = EXCLUDED.platform,
           enabled = EXCLUDED.enabled,
           data = EXCLUDED.data,
           updated_at = EXCLUDED.updated_at`,
        [
          token.id,
          token.userId || null,
          fcmToken,
          token.platform || "",
          token.enabled !== false,
          jsonString(token),
          iso(token.createdAt) || new Date().toISOString(),
          iso(token.updatedAt) || new Date().toISOString(),
        ],
      );
    }

    for (const item of store.notifications || []) {
      await upsert(
        client,
        `INSERT INTO notifications (id, dedupe_key, event_type, title, body, data, created_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7)
         ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data`,
        [
          item.id,
          item.dedupeKey || null,
          item.eventType || "unknown",
          item.title || "",
          item.body || "",
          jsonString(item),
          iso(item.createdAt) || new Date().toISOString(),
        ],
      );
    }

    for (const item of store.notificationDeliveries || []) {
      await upsert(
        client,
        `INSERT INTO notification_deliveries (id, notification_id, token_id, user_id, status, attempts, last_error, sent_at, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
         ON CONFLICT (id) DO UPDATE SET
           status = EXCLUDED.status,
           attempts = EXCLUDED.attempts,
           last_error = EXCLUDED.last_error,
           sent_at = EXCLUDED.sent_at,
           updated_at = EXCLUDED.updated_at`,
        [
          item.id,
          item.notificationId || null,
          item.tokenId || null,
          item.userId || null,
          item.status || "queued",
          Number(item.attempts) || 0,
          item.lastError || "",
          iso(item.sentAt),
          iso(item.createdAt) || new Date().toISOString(),
          iso(item.updatedAt) || new Date().toISOString(),
        ],
      );
    }

    for (const item of store.pushDeliveryAcks || []) {
      await upsert(
        client,
        `INSERT INTO push_delivery_acks (id, user_id, notification_id, event_type, order_id, data, created_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7)
         ON CONFLICT (user_id, event_type, notification_id) DO UPDATE SET
           id = EXCLUDED.id,
           order_id = EXCLUDED.order_id,
           data = EXCLUDED.data`,
        [
          item.id,
          item.userId || null,
          item.notificationId || item.id || "",
          item.eventType || "unknown",
          item.orderId || "",
          jsonString(item),
          iso(item.createdAt) || new Date().toISOString(),
        ],
      );
    }

    for (const item of store.cityPrices || []) {
      await upsert(
        client,
        `INSERT INTO city_prices (id, title, price_day, price_night, delivery_price, data, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7)
         ON CONFLICT (title) DO UPDATE SET
           price_day = EXCLUDED.price_day,
           price_night = EXCLUDED.price_night,
           delivery_price = EXCLUDED.delivery_price,
           data = EXCLUDED.data,
           updated_at = EXCLUDED.updated_at`,
        [
          item.id || item.title,
          item.title,
          Number(item.priceDay) || 0,
          Number(item.priceNight) || 0,
          Number(item.deliveryPrice) || 0,
          jsonString(item),
          iso(item.updatedAt) || new Date().toISOString(),
        ],
      );
    }

    for (const item of store.intercityRoutes || []) {
      await upsert(
        client,
        `INSERT INTO intercity_routes (id, ot, kuda, tarif, com, data, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7)
         ON CONFLICT (id) DO UPDATE SET
           ot = EXCLUDED.ot,
           kuda = EXCLUDED.kuda,
           tarif = EXCLUDED.tarif,
           com = EXCLUDED.com,
           data = EXCLUDED.data,
           updated_at = EXCLUDED.updated_at`,
        [
          item.id,
          item.ot || "",
          item.kuda || "",
          Number(item.tarif) || 0,
          Number(item.com) || 0,
          jsonString(item),
          iso(item.updatedAt) || new Date().toISOString(),
        ],
      );
    }

    for (const [key, value] of Object.entries(store.settings || {})) {
      await upsert(
        client,
        `INSERT INTO app_settings (key, value, updated_at)
         VALUES ($1,$2,now())
         ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
        [key, jsonString(value)],
      );
    }
    if (store.intercityTariff) {
      await upsert(
        client,
        `INSERT INTO app_settings (key, value, updated_at)
         VALUES ('intercityTariff', $1, now())
         ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
        [jsonString(store.intercityTariff)],
      );
    }
    if (store.paymentSequence != null) {
      await upsert(
        client,
        `INSERT INTO app_settings (key, value, updated_at)
         VALUES ('paymentSequence', $1, now())
         ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
        [jsonString(Number(store.paymentSequence) || 0)],
      );
    }

    for (const [collection, fields] of Object.entries(store.content || {})) {
      await upsert(
        client,
        `INSERT INTO content_documents (collection, fields, updated_at)
         VALUES ($1,$2,now())
         ON CONFLICT (collection) DO UPDATE SET fields = EXCLUDED.fields, updated_at = now()`,
        [collection, jsonString(fields)],
      );
    }

    for (const [collection, items] of Object.entries(store.genericCollections || {})) {
      for (const item of items || []) {
        await upsert(
          client,
          `INSERT INTO generic_documents (collection, id, fields, created_at, updated_at)
           VALUES ($1,$2,$3,$4,$5)
           ON CONFLICT (collection, id) DO UPDATE SET fields = EXCLUDED.fields, updated_at = EXCLUDED.updated_at`,
          [
            collection,
            item.id,
            jsonString(item),
            iso(item.createdAt) || new Date().toISOString(),
            iso(item.updatedAt) || new Date().toISOString(),
          ],
        );
      }
    }

    for (const log of store.auditLogs || []) {
      await upsert(
        client,
        `INSERT INTO audit_logs (id, action, target, admin_id, admin_phone, before_data, after_data, extra, created_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
         ON CONFLICT (id) DO UPDATE SET extra = EXCLUDED.extra`,
        [
          log.id,
          log.action || "unknown",
          log.target || "",
          log.adminId || null,
          log.adminPhone || "",
          log.before == null ? null : jsonString(log.before),
          log.after == null ? null : jsonString(log.after),
          jsonString(log.extra),
          iso(log.createdAt) || new Date().toISOString(),
        ],
      );
    }

    const targetCounts = await countPostgresRecords(client);
    assertMigrationCounts(counts, targetCounts);

    await client.query("COMMIT");
    console.log(
      `Migrated ${file} to PostgreSQL: ${formatMigrationReport(counts)}; ` +
      `verified: ${formatMigrationReport(targetCounts)}`,
    );
    return counts;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    await client.end();
  }
}

if (require.main === module) {
  migrate().catch((error) => {
    console.error(error.message || error);
    process.exit(1);
  });
}

module.exports = {
  assertMigrationCounts,
  countPostgresRecords,
  countStoreRecords,
  formatMigrationReport,
  migrate,
};
