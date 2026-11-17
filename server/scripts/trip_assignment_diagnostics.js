// Aggregate read-only diagnosis. Never print IDs, addresses, phones or balances.
(async () => {
  const { readStoreAsync } = require(process.cwd() + '/src/store');
  const store = await readStoreAsync();
  const active = store.orders.filter(o => [2, 3, 4].includes(Number(o.status)));
  const user = id => store.users.find(u => u.id === id);
  const counts = new Map();
  for (const order of active) if (order.driverId) counts.set(order.driverId, (counts.get(order.driverId) || 0) + 1);
  console.log(JSON.stringify({
    diagnostic: 'TRIP_ASSIGNMENT_CONSISTENCY',
    activeAssignedOrders: active.length,
    missingDriver: active.filter(o => !o.driverId || !user(o.driverId)).length,
    driverReferenceMismatch: active.filter(o => user(o.driverId)?.activeDriverOrderId !== o.id).length,
    passengerReferenceMismatch: active.filter(o => user(o.userId)?.activePassengerOrderId !== o.id).length,
    driversWithMultipleActiveOrders: [...counts.values()].filter(n => n > 1).length,
    acceptedOffersWithoutDriver: store.orders.filter(o => o.acceptedOfferId && !o.driverId).length,
  }));
})().catch(() => { console.error('Read-only assignment diagnostic failed'); process.exitCode = 1; });
