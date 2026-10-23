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
    if (distance > 60) {
      delete order.autoArrivalSince;
      return;
    }
    order.autoArrivalSince ??= now;
    if (now - order.autoArrivalSince >= 15000) {
      const result = advance(3);
      if (result.success) {
        order.autoArrivedAt = new Date(now).toISOString();
        order.pickupPresenceVerified = true;
      }
    }
    return;
  }
  // A manual arrival far away must never permit an automatic start.
  if (distance <= 60) order.pickupPresenceVerified = true;
  if (!order.pickupPresenceVerified || distance < 100) {
    delete order.autoDepartureSince;
    return;
  }
  order.autoDepartureSince ??= now;
  if (now - order.autoDepartureSince >= 15000) {
    const result = advance(4);
    if (result.success) order.autoStartedAt = new Date(now).toISOString();
  }
}
module.exports = { observeDriverPosition, meters };
