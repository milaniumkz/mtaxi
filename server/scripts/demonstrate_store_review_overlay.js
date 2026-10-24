// Temporary, non-dispatchable fixture for the owner's store review emulator.
// Reserved driverId keeps it out of every available-order feed. No ride is
// accepted, no balance changes, and the only notification targets the test user.
const assert = require('node:assert/strict');
const { withStoreAsync, getPool } = require('../src/store');
const { recipientOrderNotification } = require('../src/driver_order_alerts');
const { sendPushBatch } = require('../src/push_transport');
const id = 'store_review_overlay_67';
async function closeFixture() {
  await withStoreAsync(store => {
    const order = store.orders.find(o => o.id === id);
    if (order) {
      assert.equal(order.storeReviewFixture, true);
      order.status = 6;
      order.updatedAt = new Date().toISOString();
    }
  });
}
async function main() {
  assert.equal(process.env.MTAXI_STORE, 'postgres');
  const delivery = await withStoreAsync(store => {
    const driver = store.users.find(u => u.phone === '+70000006525');
    const passenger = store.users.find(u => u.phone === '+70000006524');
    assert.equal(driver?.displayName, 'Store Review Driver');
    assert.equal(passenger?.displayName, 'Store Review');
    assert.equal(driver.statusDriver, 'approved');
    assert.equal(driver.driverOnLine, true);
    assert.notEqual(driver.hasActiveDriverOrder, true);
    assert.ok(driver.coords && Date.now() - Date.parse(driver.coordsUpdatedAt) < 30000);
    const token = store.fcmTokens.find(t => t.userId === driver.id && !t.disabled && t.supportsOrderOverlay && t.deviceType === 'Android');
    assert.ok(token, 'Review emulator must register its overlay capability');
    assert.ok(!store.orders.some(o => o.id === id), 'Fixture must be unique');
    const now = new Date().toISOString();
    const order = {
      id, userId: passenger.id, driverId: driver.id, status: 0,
      storeReviewFixture: true, city: driver.city, type: 'taxi',
      ot: 'Тестовая точка подачи', kuda: 'Тестовый адрес назначения',
      comment: 'Демонстрация для магазина. Поездка не выполняется.',
      price: 500, passengerPrice: 500, cashToDriver: 500, paymentMode: 'cash',
      offers: [], fromPoint: driver.coords, toPoint: driver.coords,
      customerName: 'Store Review', customerPhone: passenger.phone,
      createdAt: now, updatedAt: now,
    };
    store.orders.push(order);
    const notification = recipientOrderNotification(store, {
      orderId: id, type: 'ORDER_AVAILABLE', targetRole: 'driver',
      title: 'MTaxi · тестовый заказ', body: 'Демонстрация всплывающего окна',
      dataPayload: { orderDocPath: `order/${id}`, sentAtMs: String(Date.now()) },
    }, token);
    assert.equal(notification.dataPayload.overlayEligible, 'true');
    return { tokens: [token.fcmToken], notification };
  });
  try {
    const result = await sendPushBatch(delivery);
    assert.notEqual(result.mode, 'simulated-local');
    assert.equal(result.responses[0]?.success, true, 'Review push must reach Firebase');
    console.log('Dedicated review emulator notified. No other recipients.');
    await new Promise(resolve => setTimeout(resolve, 45000));
  } finally {
    await closeFixture();
    console.log('Review fixture closed. No ride or financial transaction performed.');
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; })
  .finally(async () => { if (typeof getPool === 'function') await getPool().end(); });
