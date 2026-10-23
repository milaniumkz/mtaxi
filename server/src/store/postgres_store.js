const crypto = require("crypto");
const { isDeepStrictEqual } = require("node:util");
const { Pool } = require("pg");

const databaseUrl = process.env.DATABASE_URL;
const STORE_WRITE_LOCK_KEY = "mtaxi_store_write";

function requireDatabaseUrl() {
  if (!databaseUrl) {
    throw new Error("DATABASE_URL is required when MTAXI_STORE=postgres");
  }
}

function createPool() {
  requireDatabaseUrl();
  return new Pool({ connectionString: databaseUrl });
}

let pool;

function getPool() {
  if (!pool) {
    pool = createPool();
  }
  return pool;
}

async function withPgClient(callback) {
  const client = await getPool().connect();
  try {
    return await callback(client);
  } finally {
    client.release();
  }
}

async function withPgTransaction(callback) {
  return withPgClient(async (client) => {
    await client.query("BEGIN");
    try {
      await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [STORE_WRITE_LOCK_KEY]);
      const result = await callback(client);
      await client.query("COMMIT");
      return result;
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    }
  });
}

function unsupportedSyncContract() {
  throw new Error(
    "PostgreSQL store is configured, but domain modules still use the old " +
      "synchronous store contract. Migrate calls to async repository methods " +
      "before enabling MTAXI_STORE=postgres.",
  );
}

function iso(value) {
  return value?.toISOString?.() || value || null;
}

function coords(value = {}) {
  if (!value || typeof value !== "object") return { lat: null, lng: null };
  return {
    lat: Number.isFinite(Number(value.latitude ?? value.lat))
      ? Number(value.latitude ?? value.lat)
      : null,
    lng: Number.isFinite(Number(value.longitude ?? value.lng ?? value.lon))
      ? Number(value.longitude ?? value.lng ?? value.lon)
      : null,
  };
}

function readStore() {
  return unsupportedSyncContract();
}

function writeStore() {
  return unsupportedSyncContract();
}

function withStore() {
  return unsupportedSyncContract();
}

function userFromRow(row) {
  return {
      ...(row.data || {}),
      id: row.id,
      phone: row.phone,
      passwordHash: row.password_hash || row.data?.passwordHash || row.data?.password || "",
      displayName: row.display_name,
      role: row.role,
      roleState: row.role_state,
      activeMode: row.active_mode,
      preferredClientMode: row.preferred_client_mode,
      isDriver: row.is_driver === true,
      statusDriver: row.status_driver,
      driverRegistrationStatus: row.driver_registration_status,
      driverOnLine: row.driver_online === true,
      blocked: row.blocked === true,
      vip: row.vip === true,
      balance: Number(row.balance) || 0,
      activePassengerOrderId: row.active_passenger_order_id,
      activeDriverOrderId: row.active_driver_order_id,
      hasActivePassengerOrder: row.has_active_passenger_order === true,
      hasActiveDriverOrder: row.has_active_driver_order === true,
      city: row.city,
      coords: row.lat == null || row.lng == null
        ? row.data?.coords
        : { latitude: Number(row.lat), longitude: Number(row.lng) },
      createdAt: iso(row.created_at),
      updatedAt: iso(row.updated_at),
  };
}

async function lookupUserByIdAsync(id) {
  return withPgClient(async client => {
    const result = await client.query("SELECT * FROM users WHERE id = $1", [String(id)]);
    return result.rows[0] ? userFromRow(result.rows[0]) : null;
  });
}

async function readStoreWithClient(client) {
  const [
    settingsResult,
    usersResult,
    smsCodesResult,
    ordersResult,
    paymentsResult,
    withdrawalsResult,
    ledgerResult,
    chatsResult,
    chatMessagesResult,
    fcmTokensResult,
    notificationsResult,
    notificationDeliveriesResult,
    pushDeliveryAcksResult,
    contentResult,
    cityResult,
    routeResult,
    genericResult,
    auditResult,
  ] = await Promise.all([
    client.query("SELECT key, value FROM app_settings"),
    client.query(
      `SELECT id, phone, password_hash, display_name, role, role_state,
              active_mode, preferred_client_mode, is_driver, status_driver,
              driver_registration_status, driver_online, blocked, vip, balance,
              active_passenger_order_id, active_driver_order_id,
              has_active_passenger_order, has_active_driver_order,
              city, lat, lng, data, created_at, updated_at
       FROM users
       ORDER BY created_at ASC`,
    ),
    client.query(
      `SELECT id, phone, sms_code, sms_code_hash, provider, status, data, created_at, expires_at
       FROM sms_codes
       ORDER BY created_at DESC`,
    ),
    client.query(
      `SELECT id, user_id, driver_id, type, status, ot, kuda,
              ot_lat, ot_lng, kuda_lat, kuda_lng, price, accepted_commission,
              comment, cancelled_by, data, created_at, updated_at,
              accepted_at, completed_at, cancelled_at
       FROM orders
       ORDER BY created_at DESC`,
    ),
    client.query(
      `SELECT id, user_id, payment_id, status, amount, idempotency_key,
              provider, data, created_at, updated_at
       FROM payments
       ORDER BY updated_at DESC, created_at DESC`,
    ),
    client.query(
      `SELECT id, user_id, status, amount, data, created_at, updated_at, resolved_at
       FROM withdrawals
       ORDER BY updated_at DESC, created_at DESC`,
    ),
    client.query(
      `SELECT id, user_id, order_id, payment_id, type, source, amount,
              balance_before, balance_after, data, created_at
       FROM ledger
       ORDER BY created_at DESC`,
    ),
    client.query(
      `SELECT id, user_id, admin_id, support_chat_key, last_message,
              unread_for_admin, unread_for_user, data, created_at, updated_at
       FROM support_chats
       ORDER BY updated_at DESC, created_at DESC`,
    ),
    client.query(
      `SELECT id, chat_id, user_id, text, image_url, data, created_at
       FROM support_messages
       ORDER BY created_at ASC`,
    ),
    client.query(
      `SELECT id, user_id, token, platform, enabled, data, created_at, updated_at
       FROM fcm_tokens
       ORDER BY updated_at DESC, created_at DESC`,
    ),
    client.query(
      `SELECT id, dedupe_key, event_type, title, body, data, created_at
       FROM notifications
       ORDER BY created_at DESC`,
    ),
    client.query(
      `SELECT id, notification_id, token_id, user_id, status, attempts,
              last_error, sent_at, created_at, updated_at
       FROM notification_deliveries
       ORDER BY created_at DESC`,
    ),
    client.query(
      `SELECT id, user_id, notification_id, event_type, order_id, data, created_at
       FROM push_delivery_acks
       ORDER BY created_at DESC`,
    ),
    client.query("SELECT collection, fields FROM content_documents"),
    client.query(
      `SELECT id, title, price_day, price_night, delivery_price, data, updated_at
       FROM city_prices
       ORDER BY title ASC`,
    ),
    client.query(
      `SELECT id, ot, kuda, tarif, com, data, updated_at
       FROM intercity_routes
       ORDER BY ot ASC, kuda ASC`,
    ),
    client.query(
      `SELECT collection, id, fields, created_at, updated_at
       FROM generic_documents
       ORDER BY collection ASC, updated_at DESC, id ASC`,
    ),
    client.query(
      `SELECT id, action, target, admin_id, admin_phone, before_data, after_data, extra, created_at
       FROM audit_logs
       ORDER BY created_at DESC
       LIMIT 1000`,
    ),
  ]);
  const settings = {};
  let intercityTariff = {};
  let paymentSequence = 0;
  for (const row of settingsResult.rows) {
    if (row.key === "intercityTariff") {
      intercityTariff = row.value || {};
    } else if (row.key === "paymentSequence") {
      paymentSequence = Number(row.value) || 0;
    } else {
      settings[row.key] = row.value;
    }
  }
  const content = {};
  for (const row of contentResult.rows) {
    content[row.collection] = row.fields || {};
  }
  const genericCollections = {};
  for (const row of genericResult.rows) {
    genericCollections[row.collection] ||= [];
    genericCollections[row.collection].push({
      ...(row.fields || {}),
      id: row.id,
      createdAt: row.created_at?.toISOString?.() || row.created_at,
      updatedAt: row.updated_at?.toISOString?.() || row.updated_at,
    });
  }
  return {
    users: usersResult.rows.map(userFromRow),
    orders: ordersResult.rows.map((row) => ({
      ...(row.data || {}),
      id: row.id,
      userId: row.user_id,
      driverId: row.driver_id || "",
      type: row.type,
      status: Number(row.status) || 0,
      ot: row.ot,
      kuda: row.kuda,
      fromPoint: row.ot_lat == null || row.ot_lng == null
        ? row.data?.fromPoint
        : { latitude: Number(row.ot_lat), longitude: Number(row.ot_lng) },
      toPoint: row.kuda_lat == null || row.kuda_lng == null
        ? row.data?.toPoint
        : { latitude: Number(row.kuda_lat), longitude: Number(row.kuda_lng) },
      price: Number(row.price) || 0,
      acceptedCommission: Number(row.accepted_commission) || 0,
      comment: row.comment,
      cancelledBy: row.cancelled_by,
      createdAt: iso(row.created_at),
      updatedAt: iso(row.updated_at),
      acceptedAt: iso(row.accepted_at),
      completedAt: iso(row.completed_at),
      cancelledAt: iso(row.cancelled_at),
    })),
    payments: paymentsResult.rows.map((row) => ({
      ...(row.data || {}),
      id: row.id,
      userId: row.user_id,
      paymentId: row.payment_id || row.data?.paymentId || row.id,
      status: row.status,
      amount: Number(row.amount) || 0,
      idempotencyKey: row.idempotency_key || "",
      provider: row.provider,
      createdAt: iso(row.created_at),
      updatedAt: iso(row.updated_at),
    })),
    withdrawals: withdrawalsResult.rows.map((row) => ({
      ...(row.data || {}),
      id: row.id,
      userId: row.user_id,
      status: row.status,
      amount: Number(row.amount) || 0,
      createdAt: iso(row.created_at),
      updatedAt: iso(row.updated_at),
      resolvedAt: iso(row.resolved_at),
    })),
    ledger: ledgerResult.rows.map((row) => ({
      ...(row.data || {}),
      id: row.id,
      userId: row.user_id,
      orderId: row.order_id,
      paymentId: row.payment_id,
      type: row.type,
      source: row.source,
      amount: Number(row.amount) || 0,
      balanceBefore: row.balance_before == null ? null : Number(row.balance_before),
      balanceAfter: row.balance_after == null ? null : Number(row.balance_after),
      createdAt: iso(row.created_at),
    })),
    chats: chatsResult.rows.map((row) => ({
      ...(row.data || {}),
      id: row.id,
      userId: row.user_id,
      adminId: row.admin_id,
      supportChatKey: row.support_chat_key,
      lastMessage: row.last_message,
      unreadForAdmin: Number(row.unread_for_admin) || 0,
      unreadForUser: Number(row.unread_for_user) || 0,
      createdAt: iso(row.created_at),
      updatedAt: iso(row.updated_at),
    })),
    chatMessages: chatMessagesResult.rows.map((row) => ({
      ...(row.data || {}),
      id: row.id,
      chatId: row.chat_id,
      userId: row.user_id,
      text: row.text,
      imageUrl: row.image_url,
      createdAt: iso(row.created_at),
    })),
    fcmTokens: fcmTokensResult.rows.map((row) => ({
      ...(row.data || {}),
      id: row.id,
      userId: row.user_id,
      fcmToken: row.token,
      deviceType: row.platform,
      disabled: row.enabled !== true,
      createdAt: iso(row.created_at),
      updatedAt: iso(row.updated_at),
    })),
    notifications: notificationsResult.rows.map((row) => ({
      ...(row.data || {}),
      id: row.id,
      dedupeKey: row.dedupe_key || row.data?.dedupeKey || "",
      type: row.event_type,
      title: row.title,
      body: row.body,
      createdAt: iso(row.created_at),
    })),
    notificationDeliveries: notificationDeliveriesResult.rows.map((row) => ({
      id: row.id,
      notificationId: row.notification_id,
      tokenId: row.token_id,
      userId: row.user_id,
      status: row.status,
      attempts: Number(row.attempts) || 0,
      error: row.last_error,
      sentAt: iso(row.sent_at),
      createdAt: iso(row.created_at),
      updatedAt: iso(row.updated_at),
    })),
    pushDeliveryAcks: pushDeliveryAcksResult.rows.map((row) => ({
      ...(row.data || {}),
      id: row.id,
      userId: row.user_id,
      notificationId: row.notification_id || row.data?.notificationId || "",
      eventType: row.event_type,
      orderId: row.order_id || row.data?.orderId || "",
      createdAt: iso(row.created_at),
    })),
    smsCodes: smsCodesResult.rows.map((row) => ({
      ...(row.data || {}),
      id: row.id,
      phone: row.phone,
      smsCode: row.sms_code,
      smsCodeHash: row.sms_code_hash || row.data?.smsCodeHash || "",
      provider: row.provider,
      status: row.status,
      createdAt: iso(row.created_at),
      expiresAt: iso(row.expires_at),
    })),
    auditLogs: auditResult.rows.map((row) => ({
      id: row.id,
      action: row.action,
      target: row.target,
      adminId: row.admin_id,
      adminPhone: row.admin_phone,
      before: row.before_data,
      after: row.after_data,
      extra: row.extra || {},
      createdAt: iso(row.created_at),
    })),
    genericCollections,
    settings,
    cityPrices: cityResult.rows.map((row) => ({
      ...(row.data || {}),
      id: row.id,
      title: row.title,
      priceDay: Number(row.price_day) || 0,
      priceNight: Number(row.price_night) || 0,
      deliveryPrice: Number(row.delivery_price) || 0,
      updatedAt: iso(row.updated_at),
    })),
    intercityTariff,
    paymentSequence,
    intercityRoutes: routeResult.rows.map((row) => ({
      ...(row.data || {}),
      id: row.id,
      ot: row.ot,
      kuda: row.kuda,
      tarif: Number(row.tarif) || 0,
      com: Number(row.com) || 0,
      updatedAt: iso(row.updated_at),
    })),
    content,
  };
}

function changedRows(rows, previous) {
  if (!previous) return rows;
  const old = new Map(previous.map(item => [item.id, item]));
  return rows.filter(item => !isDeepStrictEqual(item, old.get(item.id)));
}

function hasRemovedRows(rows, previous) {
  if (!previous) return true;
  const ids = new Set(rows.map(item => item.id));
  return previous.some(item => !ids.has(item.id));
}

async function writeStoreWithClient(client, store = {}, previous = null) {
  const users = Array.isArray(store.users) ? store.users : [];
  if (Array.isArray(store.users) && hasRemovedRows(users, previous?.users)) {
    await client.query(
      "DELETE FROM users WHERE NOT (id = ANY($1::text[]))",
      [users.map((user) => String(user.id || "").trim()).filter(Boolean)],
    );
  }
  for (const user of changedRows(users, previous?.users)) {
    const c = coords(user.coords);
    await client.query(
      `INSERT INTO users (
        id, phone, password_hash, display_name, role, role_state,
        active_mode, preferred_client_mode, is_driver, status_driver,
        driver_registration_status, driver_online, blocked, vip, balance,
        active_passenger_order_id, active_driver_order_id,
        has_active_passenger_order, has_active_driver_order,
        city, lat, lng, data, created_at, updated_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,
        COALESCE($24::timestamptz, now()), COALESCE($25::timestamptz, now())
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
        String(user.id || "").trim(),
        String(user.phone || "").trim(),
        String(user.passwordHash || user.password || "").trim() || null,
        String(user.displayName || user.display_name || "").trim(),
        String(user.role || (user.isDriver ? "driver" : "passenger")).trim(),
        String(user.roleState || "PASSENGER").trim(),
        String(user.activeMode || "passenger").trim(),
        String(user.preferredClientMode || "passenger").trim(),
        user.isDriver === true,
        String(user.statusDriver || "").trim(),
        String(user.driverRegistrationStatus || "").trim(),
        user.driverOnLine === true,
        user.blocked === true,
        user.vip === true,
        Number(user.balance) || 0,
        user.activePassengerOrderId || null,
        user.activeDriverOrderId || null,
        user.hasActivePassengerOrder === true,
        user.hasActiveDriverOrder === true,
        String(user.city || "").trim(),
        c.lat,
        c.lng,
        JSON.stringify(user),
        user.createdAt || user.created_time || null,
        user.updatedAt || null,
      ],
    );
  }

  if (!previous || !isDeepStrictEqual(store.smsCodes, previous.smsCodes)) {
  await client.query("DELETE FROM sms_codes");
  for (const sms of store.smsCodes || []) {
    await client.query(
      `INSERT INTO sms_codes (id, phone, sms_code, sms_code_hash, provider, status, data, created_at, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, COALESCE($8::timestamptz, now()), $9::timestamptz)
       ON CONFLICT (id) DO UPDATE SET
         phone = EXCLUDED.phone,
         sms_code = EXCLUDED.sms_code,
         sms_code_hash = EXCLUDED.sms_code_hash,
         provider = EXCLUDED.provider,
         status = EXCLUDED.status,
         data = EXCLUDED.data,
         expires_at = EXCLUDED.expires_at`,
      [
        String(sms.id || "").trim(),
        String(sms.phone || "").trim(),
        String(sms.smsCode || sms.code || "").trim(),
        String(sms.smsCodeHash || sms.codeHash || "").trim(),
        String(sms.provider || "local").trim(),
        String(sms.status || "sent").trim(),
        JSON.stringify(sms),
        sms.createdAt || null,
        sms.expiresAt || null,
      ],
    );
  }

  }
  const orders = Array.isArray(store.orders) ? store.orders : [];
  if (Array.isArray(store.orders) && hasRemovedRows(orders, previous?.orders)) {
    await client.query(
      "DELETE FROM orders WHERE NOT (id = ANY($1::text[]))",
      [orders.map((order) => String(order.id || "").trim()).filter(Boolean)],
    );
  }
  for (const order of changedRows(orders, previous?.orders)) {
    const from = coords(order.fromPoint || order.otCoords || order.fromCoords);
    const to = coords(order.toPoint || order.kudaCoords || order.toCoords);
    await client.query(
      `INSERT INTO orders (
        id, user_id, driver_id, type, status, ot, kuda,
        ot_lat, ot_lng, kuda_lat, kuda_lng, price, accepted_commission,
        comment, cancelled_by, data, created_at, updated_at,
        accepted_at, completed_at, cancelled_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,
        COALESCE($17::timestamptz, now()), COALESCE($18::timestamptz, now()),
        $19::timestamptz, $20::timestamptz, $21::timestamptz
      )
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
        updated_at = EXCLUDED.updated_at,
        accepted_at = EXCLUDED.accepted_at,
        completed_at = EXCLUDED.completed_at,
        cancelled_at = EXCLUDED.cancelled_at`,
      [
        String(order.id || "").trim(),
        order.userId || null,
        order.driverId || null,
        String(order.type || "taxi").trim(),
        Number.isInteger(order.status) ? order.status : Number(order.status) || 0,
        String(order.ot || order.otkuda || "").trim(),
        String(order.kuda || "").trim(),
        from.lat,
        from.lng,
        to.lat,
        to.lng,
        Number(order.price) || 0,
        Number(order.acceptedCommission) || 0,
        String(order.comment || "").trim(),
        String(order.cancelledBy || "").trim(),
        JSON.stringify(order),
        order.createdAt || order.date || null,
        order.updatedAt || null,
        order.acceptedAt || null,
        order.completedAt || null,
        order.cancelledAt || null,
      ],
    );
  }

  const payments = Array.isArray(store.payments) ? store.payments : [];
  if (Array.isArray(store.payments) && hasRemovedRows(payments, previous?.payments)) {
    await client.query(
      "DELETE FROM payments WHERE NOT (id = ANY($1::text[]))",
      [payments.map((payment) => String(payment.id || "").trim()).filter(Boolean)],
    );
  }
  for (const payment of changedRows(payments, previous?.payments)) {
    await client.query(
      `INSERT INTO payments (
        id, user_id, payment_id, status, amount, idempotency_key,
        provider, data, created_at, updated_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8::jsonb,
        COALESCE($9::timestamptz, now()), COALESCE($10::timestamptz, now())
      )
      ON CONFLICT (id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        payment_id = EXCLUDED.payment_id,
        status = EXCLUDED.status,
        amount = EXCLUDED.amount,
        idempotency_key = EXCLUDED.idempotency_key,
        provider = EXCLUDED.provider,
        data = EXCLUDED.data,
        updated_at = EXCLUDED.updated_at`,
      [
        String(payment.id || "").trim(),
        payment.userId || null,
        String(payment.paymentId || payment.payment_id || payment.id || "").trim(),
        String(payment.status || "pending").trim(),
        Number(payment.amount) || 0,
        String(payment.idempotencyKey || "").trim() || null,
        String(payment.provider || "local").trim(),
        JSON.stringify(payment),
        payment.createdAt || payment.created_at || null,
        payment.updatedAt || payment.updated_at || null,
      ],
    );
  }

  const withdrawals = Array.isArray(store.withdrawals) ? store.withdrawals : [];
  if (Array.isArray(store.withdrawals) && hasRemovedRows(withdrawals, previous?.withdrawals)) {
    await client.query(
      "DELETE FROM withdrawals WHERE NOT (id = ANY($1::text[]))",
      [withdrawals.map((withdrawal) => String(withdrawal.id || "").trim()).filter(Boolean)],
    );
  }
  for (const withdrawal of changedRows(withdrawals, previous?.withdrawals)) {
    await client.query(
      `INSERT INTO withdrawals (id, user_id, status, amount, data, created_at, updated_at, resolved_at)
       VALUES (
         $1,$2,$3,$4,$5::jsonb,
         COALESCE($6::timestamptz, now()), COALESCE($7::timestamptz, now()), $8::timestamptz
       )
       ON CONFLICT (id) DO UPDATE SET
         user_id = EXCLUDED.user_id,
         status = EXCLUDED.status,
         amount = EXCLUDED.amount,
         data = EXCLUDED.data,
         updated_at = EXCLUDED.updated_at,
         resolved_at = EXCLUDED.resolved_at`,
      [
        String(withdrawal.id || "").trim(),
        withdrawal.userId || null,
        String(withdrawal.status || "pending").trim(),
        Number(withdrawal.amount) || 0,
        JSON.stringify(withdrawal),
        withdrawal.createdAt || withdrawal.created_at || null,
        withdrawal.updatedAt || withdrawal.updated_at || null,
        withdrawal.resolvedAt || withdrawal.resolved_at || null,
      ],
    );
  }

  const ledger = Array.isArray(store.ledger) ? store.ledger : [];
  if (Array.isArray(store.ledger) && hasRemovedRows(ledger, previous?.ledger)) {
    await client.query(
      "DELETE FROM ledger WHERE NOT (id = ANY($1::text[]))",
      [ledger.map((entry) => String(entry.id || "").trim()).filter(Boolean)],
    );
  }
  const currentUserIds = new Set(users.map(user => user.id));
  const currentOrderIds = new Set((store.orders || []).map(order => order.id));
  for (const originalEntry of changedRows(ledger, previous?.ledger)) {
    // Account deletion may remove orders owned by another ledger user's passenger.
    // Preserve that ledger history without restoring references cleared by SQL.
    const entry = {
      ...originalEntry,
      userId: currentUserIds.has(originalEntry.userId) ? originalEntry.userId : null,
      orderId: currentOrderIds.has(originalEntry.orderId) ? originalEntry.orderId : null,
    };
    await client.query(
      `INSERT INTO ledger (
        id, user_id, order_id, payment_id, type, source, amount,
        balance_before, balance_after, data, created_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb, COALESCE($11::timestamptz, now())
      )
      ON CONFLICT (id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        order_id = EXCLUDED.order_id,
        payment_id = EXCLUDED.payment_id,
        type = EXCLUDED.type,
        source = EXCLUDED.source,
        amount = EXCLUDED.amount,
        balance_before = EXCLUDED.balance_before,
        balance_after = EXCLUDED.balance_after,
        data = EXCLUDED.data`,
      [
        String(entry.id || "").trim(),
        entry.userId || null,
        entry.orderId || null,
        entry.paymentId || null,
        String(entry.type || "unknown").trim(),
        String(entry.source || "backend").trim(),
        Number(entry.amount) || 0,
        entry.balanceBefore == null ? null : Number(entry.balanceBefore),
        entry.balanceAfter == null ? null : Number(entry.balanceAfter),
        JSON.stringify(entry),
        entry.createdAt || entry.created_at || null,
      ],
    );
  }

  const chats = Array.isArray(store.chats) ? store.chats : [];
  if (Array.isArray(store.chats) && hasRemovedRows(chats, previous?.chats)) {
    await client.query(
      "DELETE FROM support_chats WHERE NOT (id = ANY($1::text[]))",
      [chats.map((chat) => String(chat.id || "").trim()).filter(Boolean)],
    );
  }
  for (const chat of changedRows(chats, previous?.chats)) {
    await client.query(
      `INSERT INTO support_chats (
        id, user_id, admin_id, support_chat_key, last_message,
        unread_for_admin, unread_for_user, data, created_at, updated_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8::jsonb,
        COALESCE($9::timestamptz, now()), COALESCE($10::timestamptz, now())
      )
      ON CONFLICT (id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        admin_id = EXCLUDED.admin_id,
        support_chat_key = EXCLUDED.support_chat_key,
        last_message = EXCLUDED.last_message,
        unread_for_admin = EXCLUDED.unread_for_admin,
        unread_for_user = EXCLUDED.unread_for_user,
        data = EXCLUDED.data,
        updated_at = EXCLUDED.updated_at`,
      [
        String(chat.id || "").trim(),
        chat.userId || null,
        chat.adminId || null,
        String(chat.supportChatKey || "").trim() || null,
        String(chat.lastMessage || chat.last_message || "").trim(),
        Number(chat.unreadForAdmin ?? chat.unread_for_admin) || 0,
        Number(chat.unreadForUser ?? chat.unread_for_user) || 0,
        JSON.stringify(chat),
        chat.createdAt || chat.created_at || null,
        chat.updatedAt || chat.lastMessageTime || chat.updated_at || null,
      ],
    );
  }

  const chatMessages = Array.isArray(store.chatMessages) ? store.chatMessages : [];
  if (Array.isArray(store.chatMessages) && hasRemovedRows(chatMessages, previous?.chatMessages)) {
    await client.query(
      "DELETE FROM support_messages WHERE NOT (id = ANY($1::text[]))",
      [chatMessages.map((message) => String(message.id || "").trim()).filter(Boolean)],
    );
  }
  for (const message of changedRows(chatMessages, previous?.chatMessages)) {
    await client.query(
      `INSERT INTO support_messages (id, chat_id, user_id, text, image_url, data, created_at)
       VALUES ($1,$2,$3,$4,$5,$6::jsonb, COALESCE($7::timestamptz, now()))
       ON CONFLICT (id) DO UPDATE SET
         chat_id = EXCLUDED.chat_id,
         user_id = EXCLUDED.user_id,
         text = EXCLUDED.text,
         image_url = EXCLUDED.image_url,
         data = EXCLUDED.data`,
      [
        String(message.id || "").trim(),
        message.chatId || null,
        message.userId || null,
        String(message.text || "").trim(),
        String(message.imageUrl || message.image_url || "").trim(),
        JSON.stringify(message),
        message.createdAt || message.created_at || null,
      ],
    );
  }

  const fcmTokens = Array.isArray(store.fcmTokens) ? store.fcmTokens : [];
  if (Array.isArray(store.fcmTokens) && hasRemovedRows(fcmTokens, previous?.fcmTokens)) {
    await client.query(
      "DELETE FROM fcm_tokens WHERE NOT (id = ANY($1::text[]))",
      [fcmTokens.map((token) => String(token.id || "").trim()).filter(Boolean)],
    );
  }
  for (const token of changedRows(fcmTokens, previous?.fcmTokens)) {
    const fcmToken = String(token.fcmToken || token.token || "").trim();
    if (!fcmToken) continue;
    await client.query(
      `INSERT INTO fcm_tokens (id, user_id, token, platform, enabled, data, created_at, updated_at)
       VALUES (
         $1,$2,$3,$4,$5,$6::jsonb,
         COALESCE($7::timestamptz, now()), COALESCE($8::timestamptz, now())
       )
       ON CONFLICT (token) DO UPDATE SET
         user_id = EXCLUDED.user_id,
         platform = EXCLUDED.platform,
         enabled = EXCLUDED.enabled,
         data = EXCLUDED.data,
         updated_at = EXCLUDED.updated_at`,
      [
        String(token.id || "").trim(),
        token.userId || null,
        fcmToken,
        String(token.deviceType || token.platform || "").trim(),
        token.disabled !== true,
        JSON.stringify(token),
        token.createdAt || token.created_at || null,
        token.updatedAt || token.updated_at || null,
      ],
    );
  }

  const notifications = Array.isArray(store.notifications) ? store.notifications : [];
  if (Array.isArray(store.notifications) && hasRemovedRows(notifications, previous?.notifications)) {
    await client.query(
      "DELETE FROM notifications WHERE NOT (id = ANY($1::text[]))",
      [notifications.map((notification) => String(notification.id || "").trim()).filter(Boolean)],
    );
  }
  for (const notification of changedRows(notifications, previous?.notifications)) {
    await client.query(
      `INSERT INTO notifications (id, dedupe_key, event_type, title, body, data, created_at)
       VALUES ($1,$2,$3,$4,$5,$6::jsonb, COALESCE($7::timestamptz, now()))
       ON CONFLICT (id) DO UPDATE SET
         dedupe_key = EXCLUDED.dedupe_key,
         event_type = EXCLUDED.event_type,
         title = EXCLUDED.title,
         body = EXCLUDED.body,
         data = EXCLUDED.data`,
      [
        String(notification.id || "").trim(),
        String(notification.dedupeKey || "").trim() || null,
        String(notification.type || notification.eventType || "GENERAL").trim(),
        String(notification.title || "").trim(),
        String(notification.body || "").trim(),
        JSON.stringify(notification),
        notification.createdAt || notification.created_at || null,
      ],
    );
  }

  const notificationDeliveries = Array.isArray(store.notificationDeliveries)
    ? store.notificationDeliveries
    : [];
  if (Array.isArray(store.notificationDeliveries) && hasRemovedRows(notificationDeliveries, previous?.notificationDeliveries)) {
    await client.query(
      "DELETE FROM notification_deliveries WHERE NOT (id = ANY($1::text[]))",
      [notificationDeliveries.map((delivery) => String(delivery.id || "").trim()).filter(Boolean)],
    );
  }
  for (const delivery of changedRows(notificationDeliveries, previous?.notificationDeliveries)) {
    await client.query(
      `INSERT INTO notification_deliveries (
        id, notification_id, token_id, user_id, status, attempts,
        last_error, sent_at, created_at, updated_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8::timestamptz,
        COALESCE($9::timestamptz, now()), COALESCE($10::timestamptz, now())
      )
      ON CONFLICT (id) DO UPDATE SET
        notification_id = EXCLUDED.notification_id,
        token_id = EXCLUDED.token_id,
        user_id = EXCLUDED.user_id,
        status = EXCLUDED.status,
        attempts = EXCLUDED.attempts,
        last_error = EXCLUDED.last_error,
        sent_at = EXCLUDED.sent_at,
        updated_at = EXCLUDED.updated_at`,
      [
        String(delivery.id || "").trim(),
        delivery.notificationId || null,
        delivery.tokenId || null,
        delivery.userId || null,
        String(delivery.status || "queued").trim(),
        Number(delivery.attempts) || 0,
        String(delivery.error || delivery.lastError || "").trim(),
        delivery.sentAt || delivery.sent_at || null,
        delivery.createdAt || delivery.created_at || null,
        delivery.updatedAt || delivery.updated_at || null,
      ],
    );
  }

  const pushDeliveryAcks = Array.isArray(store.pushDeliveryAcks) ? store.pushDeliveryAcks : [];
  if (Array.isArray(store.pushDeliveryAcks) && hasRemovedRows(pushDeliveryAcks, previous?.pushDeliveryAcks)) {
    await client.query(
      "DELETE FROM push_delivery_acks WHERE NOT (id = ANY($1::text[]))",
      [pushDeliveryAcks.map((ack) => String(ack.id || "").trim()).filter(Boolean)],
    );
  }
  for (const ack of changedRows(pushDeliveryAcks, previous?.pushDeliveryAcks)) {
    await client.query(
      `INSERT INTO push_delivery_acks (id, user_id, notification_id, event_type, order_id, data, created_at)
       VALUES ($1,$2,$3,$4,$5,$6::jsonb, COALESCE($7::timestamptz, now()))
       ON CONFLICT (user_id, event_type, notification_id) DO UPDATE SET
         id = EXCLUDED.id,
         user_id = EXCLUDED.user_id,
         notification_id = EXCLUDED.notification_id,
         event_type = EXCLUDED.event_type,
         order_id = EXCLUDED.order_id,
         data = EXCLUDED.data`,
      [
        String(ack.id || "").trim(),
        ack.userId || null,
        String(ack.notificationId || ack.id || "").trim(),
        String(ack.eventType || "opened").trim(),
        String(ack.orderId || "").trim() || null,
        JSON.stringify(ack),
        ack.createdAt || ack.created_at || null,
      ],
    );
  }

  for (const [key, value] of Object.entries(store.settings || {})) {
    if (previous && isDeepStrictEqual(value, previous.settings?.[key])) continue;
    await client.query(
      `INSERT INTO app_settings (key, value, updated_at)
       VALUES ($1, $2::jsonb, now())
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
      [key, JSON.stringify(value)],
    );
  }
  if (store.intercityTariff && typeof store.intercityTariff === "object" &&
      (!previous || !isDeepStrictEqual(store.intercityTariff, previous.intercityTariff))) {
    await client.query(
      `INSERT INTO app_settings (key, value, updated_at)
       VALUES ('intercityTariff', $1::jsonb, now())
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
      [JSON.stringify(store.intercityTariff)],
    );
  }
  if (store.paymentSequence != null && (!previous || store.paymentSequence !== previous.paymentSequence)) {
    await client.query(
      `INSERT INTO app_settings (key, value, updated_at)
       VALUES ('paymentSequence', $1::jsonb, now())
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
      [JSON.stringify(Number(store.paymentSequence) || 0)],
    );
  }
  for (const [collection, fields] of Object.entries(store.content || {})) {
    if (previous && isDeepStrictEqual(fields, previous.content?.[collection])) continue;
    await client.query(
      `INSERT INTO content_documents (collection, fields, updated_at)
       VALUES ($1, $2::jsonb, now())
       ON CONFLICT (collection) DO UPDATE SET fields = EXCLUDED.fields, updated_at = now()`,
      [collection, JSON.stringify(fields || {})],
    );
  }
  for (const item of changedRows(store.cityPrices || [], previous?.cityPrices)) {
    await client.query(
      `INSERT INTO city_prices (id, title, price_day, price_night, delivery_price, data, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, now())
       ON CONFLICT (title) DO UPDATE SET
         id = EXCLUDED.id,
         price_day = EXCLUDED.price_day,
         price_night = EXCLUDED.price_night,
         delivery_price = EXCLUDED.delivery_price,
         data = EXCLUDED.data,
         updated_at = now()`,
      [
        String(item.id || item.title || "").trim(),
        String(item.title || "").trim(),
        Number(item.priceDay) || 0,
        Number(item.priceNight) || 0,
        Number(item.deliveryPrice) || 0,
        JSON.stringify(item),
      ],
    );
  }
  for (const item of changedRows(store.intercityRoutes || [], previous?.intercityRoutes)) {
    await client.query(
      `INSERT INTO intercity_routes (id, ot, kuda, tarif, com, data, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, now())
       ON CONFLICT (id) DO UPDATE SET
         ot = EXCLUDED.ot,
         kuda = EXCLUDED.kuda,
         tarif = EXCLUDED.tarif,
         com = EXCLUDED.com,
         data = EXCLUDED.data,
         updated_at = now()`,
      [
        String(item.id || "").trim(),
        String(item.ot || "").trim(),
        String(item.kuda || "").trim(),
        Number(item.tarif) || 0,
        Number(item.com) || 0,
        JSON.stringify(item),
      ],
    );
  }
  for (const [collection, documents] of Object.entries(store.genericCollections || {})) {
    if (previous && isDeepStrictEqual(documents, previous.genericCollections?.[collection])) continue;
    await client.query("DELETE FROM generic_documents WHERE collection = $1", [collection]);
    for (const item of documents || []) {
      await client.query(
        `INSERT INTO generic_documents (collection, id, fields, created_at, updated_at)
         VALUES ($1, $2, $3::jsonb, COALESCE($4::timestamptz, now()), COALESCE($5::timestamptz, now()))
         ON CONFLICT (collection, id) DO UPDATE SET
           fields = EXCLUDED.fields,
           updated_at = EXCLUDED.updated_at`,
        [
          collection,
          String(item.id || "").trim(),
          JSON.stringify(item),
          item.createdAt || null,
          item.updatedAt || null,
        ],
      );
    }
  }
  for (const item of changedRows(store.auditLogs || [], previous?.auditLogs)) {
    await client.query(
      `INSERT INTO audit_logs (id, action, target, admin_id, admin_phone, before_data, after_data, extra, created_at)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8::jsonb, COALESCE($9::timestamptz, now()))
       ON CONFLICT (id) DO NOTHING`,
      [
        String(item.id || "").trim(),
        String(item.action || "").trim(),
        String(item.target || "").trim(),
        currentUserIds.has(item.adminId) ? item.adminId : null,
        String(item.adminPhone || "").trim(),
        JSON.stringify(item.before ?? null),
        JSON.stringify(item.after ?? null),
        JSON.stringify(item.extra || {}),
        item.createdAt || null,
      ],
    );
  }
}

async function readStoreAsync() {
  return withPgClient(readStoreWithClient);
}

async function writeStoreAsync(store) {
  return withPgTransaction(async (client) => writeStoreWithClient(client, store));
}

async function withStoreAsync(mutator) {
  return withPgTransaction(async (client) => {
    const store = await readStoreWithClient(client);
    const previous = structuredClone(store);
    const result = await mutator(store);
    await writeStoreWithClient(client, store, previous);
    return result;
  });
}

function newId(prefix) {
  return `${prefix}_${crypto.randomUUID()}`;
}

async function storeHealth() {
  if (!databaseUrl) {
    return {
      ok: false,
      type: "postgres",
      error: "DATABASE_URL is required",
    };
  }
  try {
    const result = await withPgClient((client) =>
      client.query(
        `SELECT version, applied_at
         FROM schema_migrations
         ORDER BY applied_at DESC
         LIMIT 1`,
      ),
    );
    const latest = result.rows[0] || {};
    return {
      ok: true,
      type: "postgres",
      schemaVersion: latest.version || "",
      schemaAppliedAt: iso(latest.applied_at),
    };
  } catch (e) {
    return {
      ok: false,
      type: "postgres",
      error: e?.message || "PostgreSQL healthcheck failed",
    };
  }
}

module.exports = {
  lookupUserByIdAsync,
  storeHealth,
  createPool,
  getPool,
  withPgClient,
  withPgTransaction,
  readStore,
  writeStore,
  withStore,
  readStoreAsync,
  writeStoreAsync,
  withStoreAsync,
  newId,
};
