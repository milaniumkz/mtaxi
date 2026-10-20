const { readStoreAsync, withStoreAsync } = require("./store");
const { requireAdmin } = require("./admin");
const { asNumber } = require("./utils/values");

const NUMERIC_SETTING_FIELDS = new Set([
  "orderRadiusKm",
  "orderPendingTtlMin",
  "pendingOrderLifetimeMin",
  "driverMinBalanceToTakeOrder",
  "passengerAcceptedCancelCooldownMin",
  "passengerAcceptedCancelDailyLimit",
  "driverLastActiveHeartbeatSec",
  "driverCoordsUpdateSec",
  "onlineDriverWindowMin",
  "cloudCallTimeoutSec",
  "deliveryExtra",
  "deliveryExtraNight",
  "fallbackTaxiPrice",
  "taxiFallbackPrice",
  "fallbackDeliveryPrice",
  "deliveryFallbackPrice",
  "nightMultiplier",
  "maxOrderAlertTriggerDelaySec",
  "driverOrderMaxDelaySec",
  "intercityBasePrice",
  "intercityPricePerKm",
  "intercityMinPrice",
  "cityFormulaBasePrice",
  "cityFormulaPerKm",
  "orderCommissionPercent",
  "commissionDay",
  "commissionNight",
]);

function runtimeSettingsFromStore(store) {
  const settings = store.settings || {};
  const intercity = store.intercityTariff || {};
  return {
    orderRadiusKm: asNumber(settings.orderRadiusKm) ?? 10,
    orderPendingTtlMin:
      asNumber(settings.orderPendingTtlMin) ??
      asNumber(settings.pendingOrderLifetimeMin) ??
      15,
    driverMinBalanceToTakeOrder:
      asNumber(settings.driverMinBalanceToTakeOrder) ?? 100,
    passengerAcceptedCancelCooldownMin:
      asNumber(settings.passengerAcceptedCancelCooldownMin) ?? 0,
    passengerAcceptedCancelDailyLimit:
      asNumber(settings.passengerAcceptedCancelDailyLimit) ?? 3,
    driverLastActiveHeartbeatSec:
      asNumber(settings.driverLastActiveHeartbeatSec) ?? 60,
    driverCoordsUpdateSec: asNumber(settings.driverCoordsUpdateSec) ?? 2,
    onlineDriverWindowMin: asNumber(settings.onlineDriverWindowMin) ?? 2,
    cloudCallTimeoutSec: asNumber(settings.cloudCallTimeoutSec) ?? 20,
    deliveryExtra: asNumber(settings.deliveryExtra) ?? 400,
    deliveryExtraNight: asNumber(settings.deliveryExtraNight),
    fallbackTaxiPrice:
      asNumber(settings.fallbackTaxiPrice) ??
      asNumber(settings.taxiFallbackPrice) ??
      800,
    fallbackDeliveryPrice:
      asNumber(settings.fallbackDeliveryPrice) ??
      asNumber(settings.deliveryFallbackPrice) ??
      1200,
    nightMultiplier: asNumber(settings.nightMultiplier) ?? 1.5,
    maxOrderAlertTriggerDelaySec:
      asNumber(settings.maxOrderAlertTriggerDelaySec) ?? 15,
    driverOrderMaxDelaySec: asNumber(settings.driverOrderMaxDelaySec) ?? 10,
    intercityBasePrice:
      asNumber(settings.intercityBasePrice) ??
      asNumber(intercity.basePrice) ??
      500,
    intercityPricePerKm:
      asNumber(settings.intercityPricePerKm) ??
      asNumber(intercity.pricePerKm) ??
      130,
    intercityMinPrice:
      asNumber(settings.intercityMinPrice) ??
      asNumber(intercity.minPrice) ??
      3000,
    cityFormulaBasePrice: asNumber(settings.cityFormulaBasePrice) ?? 500,
    cityFormulaPerKm: asNumber(settings.cityFormulaPerKm) ?? 60,
    orderCommissionPercent: asNumber(settings.orderCommissionPercent) ?? 10,
  };
}

async function getRuntimeSettingsAsync() {
  const store = await readStoreAsync();
  return {
    success: true,
    code: "RUNTIME_SETTINGS",
    settings: runtimeSettingsFromStore(store),
  };
}

async function updateRuntimeSettingsAsync(data = {}, auth) {
  const authError = requireAdmin(auth);
  if (authError) return authError;

  const fields =
    data.fields && typeof data.fields === "object" ? data.fields : data;
  return withStoreAsync(async (store) => updateRuntimeSettingsInStore(store, fields));
}

function updateRuntimeSettingsInStore(store, fields = {}) {
  store.settings ||= {};
  const updated = {};

  Object.entries(fields || {}).forEach(([key, value]) => {
    if (!NUMERIC_SETTING_FIELDS.has(key)) return;
    if (value === null || value === undefined || value === "") return;
    const parsed = asNumber(value);
    if (parsed == null) {
      throw new Error(`SETTING_INVALID:${key}`);
    }
    updated[key] = parsed;
    store.settings[key] = parsed;
  });

  if (updated.orderPendingTtlMin !== undefined) {
    store.settings.pendingOrderLifetimeMin = updated.orderPendingTtlMin;
  }
  if (updated.pendingOrderLifetimeMin !== undefined) {
    store.settings.orderPendingTtlMin = updated.pendingOrderLifetimeMin;
  }
  if (updated.fallbackTaxiPrice !== undefined) {
    store.settings.taxiFallbackPrice = updated.fallbackTaxiPrice;
  }
  if (updated.taxiFallbackPrice !== undefined) {
    store.settings.fallbackTaxiPrice = updated.taxiFallbackPrice;
  }
  if (updated.fallbackDeliveryPrice !== undefined) {
    store.settings.deliveryFallbackPrice = updated.fallbackDeliveryPrice;
  }
  if (updated.deliveryFallbackPrice !== undefined) {
    store.settings.fallbackDeliveryPrice = updated.deliveryFallbackPrice;
  }

  store.intercityTariff ||= {};
  if (updated.intercityBasePrice !== undefined) {
    store.intercityTariff.basePrice = updated.intercityBasePrice;
  }
  if (updated.intercityPricePerKm !== undefined) {
    store.intercityTariff.pricePerKm = updated.intercityPricePerKm;
  }
  if (updated.intercityMinPrice !== undefined) {
    store.intercityTariff.minPrice = updated.intercityMinPrice;
  }

  return {
    success: true,
    code: "RUNTIME_SETTINGS_UPDATED",
    settings: runtimeSettingsFromStore(store),
  };
}

module.exports = {
  getRuntimeSettingsAsync,
  updateRuntimeSettingsAsync,
};
