// Bonuses never enter the withdrawable cash balance.
const { newId } = require('./store');

function campaignSettings(store) {
  const s = store.settings || {};
  return {
    enabled: s.driverBonusEnabled !== false,
    targetOrders: Number(s.driverBonusTargetOrders ?? 10),
    reward: Number(s.driverBonusReward ?? 1000),
  };
}

function dayKey(now = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Almaty', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(now);
}

function bonusStatus(store, driver, now = new Date()) {
  const config = campaignSettings(store);
  const day = dayKey(now);
  if (driver.bonusDay !== day) {
    driver.bonusDay = day;
    driver.bonusCompletedOrders = 0;
    driver.bonusAwarded = false;
  }
  return {
    ...config, day, timeZone: 'Asia/Almaty',
    balance: Number(driver.bonusBalance) || 0,
    completedOrders: Number(driver.bonusCompletedOrders) || 0,
    awarded: driver.bonusAwarded === true,
    withdrawable: false, expireDaily: false,
  };
}

function recordCompletedOrder(store, driver, order, now = new Date()) {
  const status = bonusStatus(store, driver, now);
  if (!status.enabled || status.targetOrders < 1 || status.reward <= 0 || order.bonusCounted) return;
  order.bonusCounted = true;
  driver.bonusCompletedOrders = status.completedOrders + 1;
  if (driver.bonusCompletedOrders < status.targetOrders || status.awarded) return;
  driver.bonusAwarded = true;
  driver.bonusBalance = status.balance + status.reward;
  store.ledger ||= [];
  store.ledger.push({
    id: newId('bonus'), type: 'daily_driver_bonus', userId: driver.id,
    orderId: order.id, amount: status.reward, balanceBefore: status.balance,
    balanceAfter: driver.bonusBalance, wallet: 'bonus', day: status.day,
    createdAt: now.toISOString(),
  });
}

function grantWelcomeBonus(store, driver, now = new Date()) {
  if (driver.driverWelcomeBonusGranted === true) return false;
  driver.driverWelcomeBonusGranted = true;
  driver.driverWelcomeBonusGrantedAt = now.toISOString();
  const before = Number(driver.bonusBalance) || 0;
  driver.bonusBalance = before + 1000;
  store.ledger ||= [];
  store.ledger.push({ id: newId('bonus'), type: 'driver_welcome_bonus',
    userId: driver.id, amount: 1000, wallet: 'bonus', balanceBefore: before,
    balanceAfter: driver.bonusBalance, createdAt: now.toISOString() });
  return true;
}

function debitCommission(driver, order, amount) {
  const bonus = Math.max(0, Number(driver.bonusBalance) || 0);
  const cash = Number(driver.balance) || 0;
  if (cash + bonus < amount) return false;
  order.acceptedBonusCommission = Math.min(bonus, amount);
  order.acceptedCashCommission = amount - order.acceptedBonusCommission;
  driver.bonusBalance = bonus - order.acceptedBonusCommission;
  driver.balance = cash - order.acceptedCashCommission;
  return true;
}

function refundCommission(driver, order) {
  if (order.commissionRefunded === true) return 0;
  const total = Number(order.acceptedCommission) || 0;
  const bonus = Math.min(total, Math.max(0, Number(order.acceptedBonusCommission) || 0));
  driver.bonusBalance = (Number(driver.bonusBalance) || 0) + bonus;
  driver.balance = (Number(driver.balance) || 0) + total - bonus;
  order.commissionRefunded = true;
  return total;
}

module.exports = { campaignSettings, dayKey, bonusStatus, recordCompletedOrder,
  grantWelcomeBonus, debitCommission, refundCommission };
