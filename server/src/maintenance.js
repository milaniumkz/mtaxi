const { requireAdmin } = require("./admin");
const { expireStalePendingOrdersAsync } = require("./orders");
const {
  flushQueuedPushDeliveriesAsync,
  flushQueuedPushDeliveriesInternalAsync,
} = require("./push");

async function runMaintenanceTasks(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;
  return runMaintenanceTasksInternal(data, {
    flushPush: (pushData) => flushQueuedPushDeliveriesAsync(pushData, auth),
  });
}

async function runMaintenanceTasksInternal(data = {}, options = {}) {
  const flushPush = options.flushPush || flushQueuedPushDeliveriesInternalAsync;
  const expired = await expireStalePendingOrdersAsync({
    ttlMinutes: data.ttlMinutes,
    limit: data.orderLimit,
  });
  const push = await flushPush({
    limit: data.pushLimit,
  });
  return {
    success: true,
    code: "MAINTENANCE_DONE",
    expiredOrders: expired,
    push,
  };
}

const runMaintenanceTasksAsync = runMaintenanceTasks;
const runMaintenanceTasksInternalAsync = runMaintenanceTasksInternal;

module.exports = {
  runMaintenanceTasks,
  runMaintenanceTasksAsync,
  runMaintenanceTasksInternal,
  runMaintenanceTasksInternalAsync,
};
