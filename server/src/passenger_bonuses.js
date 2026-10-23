const { newId } = require("./store");
function reservePassengerBonus(store, order, user, requested) {
  const balance = Math.max(0, Number(user.passengerBonusBalance) || 0);
  const cap = Math.max(
    0,
    Math.min(100, Number(store.settings?.passengerBonusSpendPercent ?? 100)),
  );
  const used = requested
    ? Math.min(balance, Math.floor(order.price * cap) / 100)
    : 0;
  const cash =
    order.paymentMode === "wallet"
      ? Math.round((order.price - used) * 100) / 100
      : 0;
  if (cash > (Number(user.balance) || 0))
    return {
      success: false,
      code: "PASSENGER_BALANCE_INSUFFICIENT",
      error: "Недостаточно денег на личном счёте",
      required: cash,
    };
  user.passengerBonusBalance = Math.round((balance - used) * 100) / 100;
  user.balance = Math.round(((Number(user.balance) || 0) - cash) * 100) / 100;
  order.usePassengerBonuses = requested;
  order.passengerBonusUsed = used;
  order.passengerWalletUsed = cash;
  order.cashToDriver = Math.round((order.price - used - cash) * 100) / 100;
  if (used + cash > 0) {
    store.ledger ||= [];
    store.ledger.push({
      id: newId("ledger"),
      type: "passenger_trip_reserve",
      userId: user.id,
      orderId: order.id,
      amount: cash + used,
      cashAmount: cash,
      bonusAmount: used,
      createdAt: new Date().toISOString(),
    });
  }
}
function refundPassengerBonus(store, order) {
  if (order.passengerBonusSettled || order.passengerBonusRefunded) return;
  const user = store.users.find((u) => u.id === order.userId);
  if (user) {
    user.passengerBonusBalance =
      Math.round(
        ((Number(user.passengerBonusBalance) || 0) +
          (Number(order.passengerBonusUsed) || 0)) *
          100,
      ) / 100;
    user.balance =
      Math.round(
        ((Number(user.balance) || 0) +
          (Number(order.passengerWalletUsed) || 0)) *
          100,
      ) / 100;
    store.ledger ||= [];
    if ((order.passengerBonusUsed || 0) + (order.passengerWalletUsed || 0) > 0)
      store.ledger.push({
        id: newId("ledger"),
        type: "passenger_trip_refund",
        userId: user.id,
        orderId: order.id,
        amount:
          (order.passengerBonusUsed || 0) + (order.passengerWalletUsed || 0),
        createdAt: new Date().toISOString(),
      });
  }
  order.passengerBonusRefunded = true;
}
function settlePassengerBonus(store, order, driver) {
  if (
    order.passengerBonusSettled ||
    order.passengerBonusRefunded ||
    Number(order.status) !== 5
  )
    return;
  const user = store.users.find((u) => u.id === order.userId);
  const used =
    (Number(order.passengerBonusUsed) || 0) +
    (Number(order.passengerWalletUsed) || 0);
  const percent = Number(store.settings?.passengerBonusPercent ?? 2);
  const reward = Math.floor(order.price * percent) / 100;
  store.ledger ||= [];
  if (used > 0) {
    const before = Number(driver.balance) || 0;
    driver.balance = Math.round((before + used) * 100) / 100;
    store.ledger.push({
      id: newId("ledger"),
      type: "passenger_trip_payment",
      wallet: "cash",
      userId: driver.id,
      orderId: order.id,
      amount: used,
      balanceBefore: before,
      balanceAfter: driver.balance,
      createdAt: new Date().toISOString(),
    });
  }
  if (user && reward > 0) {
    user.passengerBonusBalance =
      Math.round(((Number(user.passengerBonusBalance) || 0) + reward) * 100) /
      100;
    store.ledger.push({
      id: newId("ledger"),
      type: "passenger_cashback",
      wallet: "passenger_bonus",
      userId: user.id,
      orderId: order.id,
      amount: reward,
      balanceAfter: user.passengerBonusBalance,
      createdAt: new Date().toISOString(),
    });
  }
  order.passengerBonusSettled = true;
  order.passengerBonusReward = reward;
  order.passengerBonusPercent = percent;
}
module.exports = {
  reservePassengerBonus,
  refundPassengerBonus,
  settlePassengerBonus,
};
