const test = require('node:test');
const assert = require('node:assert/strict');
const { bonusStatus, recordCompletedOrder, dayKey, grantWelcomeBonus,
  debitCommission, refundCommission } = require('../src/driver_bonuses');
const { configureLaunchDefaultsInStore } = require('../scripts/configure_launch_defaults');

test('daily reward is granted once, stays separate from cash and survives midnight', () => {
  const store = { settings: {}, ledger: [] };
  const driver = { id: 'driver', balance: 50 };
  const beforeMidnight = new Date('2026-10-21T18:59:00Z');
  for (let i = 0; i < 9; i++) recordCompletedOrder(store, driver, { id: String(i) }, beforeMidnight);
  assert.equal(bonusStatus(store, driver, beforeMidnight).balance, 0);
  const tenth = { id: '10' };
  recordCompletedOrder(store, driver, tenth, beforeMidnight);
  recordCompletedOrder(store, driver, tenth, beforeMidnight);
  recordCompletedOrder(store, driver, { id: '11' }, beforeMidnight);
  assert.equal(driver.bonusBalance, 1000);
  assert.equal(driver.balance, 50);
  assert.equal(store.ledger.length, 1);
  const nextDay = bonusStatus(store, driver, new Date('2026-10-21T19:00:00Z'));
  assert.equal(nextDay.completedOrders, 0);
  assert.equal(nextDay.awarded, false);
  assert.equal(nextDay.balance, 1000);
  assert.equal(nextDay.withdrawable, false);
});

test('disabled campaign does not count orders; edited target and reward apply', () => {
  const store = { settings: { driverBonusEnabled: false, driverBonusTargetOrders: 2, driverBonusReward: 700 } };
  const driver = { id: 'driver' };
  const now = new Date('2026-10-21T10:00:00Z');
  recordCompletedOrder(store, driver, { id: 'disabled' }, now);
  assert.equal(driver.bonusCompletedOrders, 0);
  store.settings.driverBonusEnabled = true;
  recordCompletedOrder(store, driver, { id: '1' }, now);
  recordCompletedOrder(store, driver, { id: '2' }, now);
  assert.equal(driver.bonusBalance, 700);
  assert.equal(dayKey(now), '2026-10-21');
});

test('village rollout preserves other settlements and subsequent admin edits', () => {
  const store = { cityPrices: [{ title: 'Белоусовка', priceDay: 1000 }] };
  assert.equal(configureLaunchDefaultsInStore(store), true);
  assert.equal(store.cityPrices.length, 5);
  for (const title of ['Жетекши', 'Железинка', 'Теренколь', 'Иртышск']) {
    assert.equal(store.cityPrices.find(city => city.title === title).priceDay, 500);
    assert.equal(store.cityPrices.find(city => city.title === title).priceNight, 500);
  }
  store.cityPrices.find(city => city.title === 'Жетекши').priceDay = 600;
  assert.equal(configureLaunchDefaultsInStore(store), false);
  assert.equal(store.cityPrices.find(city => city.title === 'Жетекши').priceDay, 600);
  assert.equal(store.cityPrices[0].priceDay, 1000);
});

test('welcome reward is granted only once and cannot become withdrawable cash', () => {
  const store = {};
  const driver = { id: 'new-driver', balance: 0 };
  assert.equal(grantWelcomeBonus(store, driver), true);
  assert.equal(grantWelcomeBonus(store, driver), false);
  assert.equal(driver.bonusBalance, 1000);
  assert.equal(driver.balance, 0);
  assert.equal(store.ledger.length, 1);
  bonusStatus(store, driver, new Date('2026-10-22T00:00:00Z'));
  assert.equal(driver.bonusBalance, 1000);
});

test('commission uses bonuses first and cancellation returns each wallet exactly once', () => {
  const driver = { bonusBalance: 70, balance: 50 };
  const order = { acceptedCommission: 100 };
  assert.equal(debitCommission(driver, order, 100), true);
  assert.equal(driver.bonusBalance, 0);
  assert.equal(driver.balance, 20);
  assert.equal(order.acceptedBonusCommission, 70);
  assert.equal(order.acceptedCashCommission, 30);
  assert.equal(refundCommission(driver, order), 100);
  assert.equal(driver.balance, 50);
  assert.equal(driver.bonusBalance, 70);
  assert.equal(refundCommission(driver, order), 0);
  assert.equal(driver.balance, 50);
  const unavailable = {};
  assert.equal(debitCommission(driver, unavailable, 121), false);
  assert.deepEqual(unavailable, {});
});

test('legacy commission cancellation refunds cash only', () => {
  const driver = { balance: 0, bonusBalance: 500 };
  assert.equal(refundCommission(driver, { acceptedCommission: 100 }), 100);
  assert.equal(driver.balance, 100);
  assert.equal(driver.bonusBalance, 500);
});
