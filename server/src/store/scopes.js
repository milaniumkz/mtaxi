// Internal SQL selections only. Client-provided objects must never be used as scopes.
const filter = (where, ...values) => ({ where, values });
const activeTrip = 'SELECT active_driver_order_id FROM users WHERE id = $1';
function sessionScope(userId) {
  return { tables: {
    users: filter('id = $1', userId),
    orders: filter('id IN (SELECT active_passenger_order_id FROM users WHERE id=$1 UNION SELECT active_driver_order_id FROM users WHERE id=$1)', userId),
    app_settings: true,
  }};
}
function preferencesScope(userId) {
  return { userLockId: userId, tables: {
    users: filter(`id=$1 OR id IN (SELECT user_id FROM orders WHERE id IN (${activeTrip}))`, userId),
    orders: filter(`id IN (${activeTrip})`, userId),
    app_settings: true,
    notifications: filter(`data->>'orderId' IN (${activeTrip})`, userId),
    notification_deliveries: filter(`notification_id IN (SELECT id FROM notifications WHERE data->>'orderId' IN (${activeTrip}))`, userId),
    fcm_tokens: filter(`user_id IN (SELECT user_id FROM orders WHERE id IN (${activeTrip}))`, userId),
  }};
}
function orderScope(orderId) {
  return { tables: {
    orders: filter('id=$1', orderId),
    users: filter('id IN (SELECT user_id FROM orders WHERE id=$1 UNION SELECT driver_id FROM orders WHERE id=$1)', orderId),
    app_settings: true,
  }};
}
function trackingScope(orderId) {
  const scope = orderScope(orderId);
  scope.tables.orders = filter('id=$1 OR (status=5 AND driver_id IN (SELECT driver_id FROM orders WHERE id=$1))',orderId);
  return scope;
}
function historyScope(userId) {
  return {tables: {orders:filter('user_id=$1 OR driver_id=$1',userId)}};
}
function feedScope(userId) {
  return {tables: {
    orders:filter('status=0 AND (driver_id IS NULL OR driver_id=\'\')'),
    users:filter("id=$1 OR id IN (SELECT user_id FROM orders WHERE status=0 AND (driver_id IS NULL OR driver_id=''))",userId),
    app_settings:true,
  }};
}
function offerReadScope(orderId, actorId = '') {
  return {tables: {
    orders:filter('id=$1',orderId),
    users:filter("id=$2 OR id IN (SELECT user_id FROM orders WHERE id=$1) OR id IN (SELECT item->>'driverId' FROM orders CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(data->'offers')='array' THEN data->'offers' ELSE '[]'::jsonb END) AS item WHERE orders.id=$1)",orderId,actorId),
  }};
}
function financialOrderScope(orderId = '', actorId = '', offerId = '') {
  // The transaction locks this order and its current participants; broadcasts
  // read minimal token-owner role flags without modifying their accounts.
  return {financial:{orderId,actorId,offerId},tables: {
    users:true,
    orders:filter('id=$1',orderId),
    ledger:filter('order_id=$1',orderId),
    app_settings:true, city_prices:true, intercity_routes:true, fcm_tokens:true,
    notifications:filter("data->>'orderId'=$1",orderId),
    notification_deliveries:filter("notification_id IN (SELECT id FROM notifications WHERE data->>'orderId'=$1)",orderId),
  }};
}
function moneyStatsScope() {
  return {tables:{users:true,ledger:true,payments:true,withdrawals:true}};
}
module.exports = {sessionScope,preferencesScope,orderScope,trackingScope,historyScope,feedScope,offerReadScope,financialOrderScope,moneyStatsScope};
