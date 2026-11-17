// Timers use server receipt times, never timestamps supplied by a phone.
const meters = (a, b) => {
  const r = (x) => (x * Math.PI) / 180;
  const h =
    Math.sin(r(b.latitude - a.latitude) / 2) ** 2 +
    Math.cos(r(a.latitude)) *
      Math.cos(r(b.latitude)) *
      Math.sin(r(b.longitude - a.longitude) / 2) ** 2;
  return 12742000 * Math.asin(Math.min(1, Math.sqrt(h)));
};
function observeDriverPosition(
  store,
  driver,
  sample,
  advance,
  now = Date.now(),
) {
  const settings = store.settings || {};
  const bounded = (key, fallback, min, max) => {
    const value = Number(settings[key]);
    return Number.isSafeInteger(value) && value >= min && value <= max ? value : fallback;
  };
  const arrivalRadius = bounded('autoArrivalRadiusM', 60, 20, 120);
  const arrivalDelay = bounded('autoArrivalDelaySec', 15, 5, 120) * 1000;
  const departureRadius = Math.max(arrivalRadius + 20, bounded('autoDepartureRadiusM', 100, 80, 500));
  const startDelay = bounded('autoStartDelaySec', 15, 5, 120) * 1000;
  const order = store.orders.find(
    (o) => o.id === driver.activeDriverOrderId && o.driverId === driver.id,
  );
  if (!order || ![2, 3].includes(Number(order.status))) return;
  const pickup = order.fromPoint;
  if (
    !pickup ||
    !Number.isFinite(pickup.latitude) ||
    !Number.isFinite(pickup.longitude)
  )
    return;
  // Poor accuracy or implausible movement breaks the continuity window.
  const previous = order.autoLastPosition;
  const elapsed = previous ? (now - previous.at) / 1000 : 0;
  const valid =
    Number.isFinite(sample.accuracy) &&
    sample.accuracy > 0 &&
    sample.accuracy <= 40 &&
    (!previous ||
      (elapsed > 0 &&
        elapsed <= 20 &&
        meters(previous, sample) / elapsed <= 55));
  order.autoLastPosition = { ...sample, at: now };
  if (!valid) {
    delete order.autoArrivalSince;
    delete order.autoDepartureSince;
    return;
  }
  const distance = meters(pickup, sample);
  if (Number(order.status) === 2) {
    if (distance > arrivalRadius) {
      delete order.autoArrivalSince;
      return;
    }
    order.autoArrivalSince ??= now;
    if (now - order.autoArrivalSince >= arrivalDelay) {
      const result = advance(3);
      if (result.success) {
        order.autoArrivedAt = new Date(now).toISOString();
        order.pickupPresenceVerified = true;
      }
    }
    return;
  }
  // A manual arrival far away must never permit an automatic start.
  if (distance <= arrivalRadius) order.pickupPresenceVerified = true;
  if (!order.pickupPresenceVerified || distance < departureRadius) {
    delete order.autoDepartureSince;
    return;
  }
  order.autoDepartureSince ??= now;
  if (now - order.autoDepartureSince >= startDelay) {
    const result = advance(4);
    if (result.success) order.autoStartedAt = new Date(now).toISOString();
  }
}
module.exports = { observeDriverPosition, meters };
