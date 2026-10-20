const { runMaintenanceTasksInternalAsync } = require("./maintenance");

function maintenanceIntervalMsForEnv(env = process.env) {
  const raw = Number(env.MTAXI_MAINTENANCE_INTERVAL_SEC || 0);
  if (!Number.isFinite(raw) || raw <= 0) {
    return 0;
  }
  return Math.max(5, raw) * 1000;
}

function startMaintenanceScheduler(options = {}) {
  const env = options.env || process.env;
  const intervalMs = maintenanceIntervalMsForEnv(env);
  if (intervalMs <= 0) {
    return null;
  }

  const task = options.task || runMaintenanceTasksInternalAsync;
  const logger = options.logger || console;
  const setIntervalFn = options.setIntervalFn || setInterval;
  const clearIntervalFn = options.clearIntervalFn || clearInterval;
  let running = false;

  const tick = async () => {
    if (running) {
      return;
    }
    running = true;
    try {
      await task({
        ttlMinutes: env.MTAXI_PENDING_ORDER_TTL_MIN,
        orderLimit: env.MTAXI_MAINTENANCE_ORDER_LIMIT,
        pushLimit: env.MTAXI_MAINTENANCE_PUSH_LIMIT,
      });
    } catch (error) {
      logger.error?.("maintenance scheduler failed", error);
    } finally {
      running = false;
    }
  };

  const timer = setIntervalFn(tick, intervalMs);
  if (typeof timer?.unref === "function") {
    timer.unref();
  }
  return {
    intervalMs,
    tick,
    stop: () => clearIntervalFn(timer),
  };
}

module.exports = {
  maintenanceIntervalMsForEnv,
  startMaintenanceScheduler,
};
