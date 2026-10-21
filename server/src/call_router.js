const {
  passwordLogin,
  registerWithPassword,
  lookupUserByPhone,
  requestSmsCode,
  verifySmsCode,
  createSmsSession,
  verifyBearerToken,
} = require("./auth");
const { getSessionBootstrapAsync } = require("./session");
const { getRuntimeSettingsAsync, updateRuntimeSettingsAsync } = require("./settings");
const {
  getOrderQuoteAsync,
  getOrderDetailsAsync,
  listAvailableDriverOrdersAsync,
  listMyOrdersAsync,
  adminListOrdersAsync,
  createPassengerOrderAsync,
  adminCreateOrderAsync,
  expirePendingOrderIfNeededAsync,
  acceptOrderAsync,
  cancelPassengerOrderAsync,
  advanceDriverOrderStatusAsync,
} = require("./orders");
const {
  publicUser,
  submitPassengerRegistrationAsync,
  submitDriverRegistrationAsync,
  updateUserPreferencesAsync,
  setPasswordAsync,
  deleteCurrentAccountDeepAsync,
} = require("./users");
const {
  adminCreateDriverAsync,
  adminCreatePassengerAsync,
  adminSavePolitikaAsync,
  adminListUsersAsync,
  adminListAuditLogsAsync,
  adminUpdateUserDocumentAsync,
  approveVehiclePhotoDeletionAsync,
  rejectVehiclePhotoDeletionAsync,
  approveDriverAsync,
  adminUpdateDriverCityAsync,
  adminUpdateDriverOrderDelayAsync,
  blockDriverAsync,
  unblockDriverAsync,
  adminTopUpDriverBalanceAsync,
  adminManageOrderAsync,
  listCityTariffsAsync,
  adminListCityTariffsAsync,
  adminUpsertCityTariffAsync,
  listIntercityRoutesAsync,
  adminListIntercityRoutesAsync,
  adminUpsertIntercityRouteAsync,
  getContentDocumentAsync,
  adminUpdateContentDocumentAsync,
  adminListGenericCollectionAsync,
  adminUpsertGenericDocumentAsync,
  adminDeleteGenericDocumentAsync,
} = require("./admin");
const {
  createDriverTopUpPaymentAsync,
  getDriverTopUpPaymentStatusAsync,
  confirmDriverTopUpPaymentAsync,
  adminMarkKaspiInvoiceSentAsync,
  failDriverTopUpPaymentAsync,
  createDriverWithdrawalAsync,
  adminListWithdrawalsAsync,
  adminResolveWithdrawalAsync,
  adminListPaymentsAsync,
  getMoneyStatsAsync,
} = require("./payments");
const {
  ensureSupportChatAsync,
  getMySupportChatAsync,
  sendSupportChatMessageAsync,
  markSupportChatReadAsync,
  listSupportChatsAsync,
  getSupportChatMessagesAsync,
  adminSendSupportChatMessageAsync,
  adminDeleteSupportChatAsync,
  adminClearSupportChatsAsync,
} = require("./support");
const {
  addFcmTokenAsync,
  updateFcmTokenStateAsync,
  createPushNotificationAsync,
  adminQueueBroadcastAsync,
  adminListPushNotificationsAsync,
  flushQueuedPushDeliveriesAsync,
  ackPushDeliveryAsync,
} = require("./push");
const { uploadFileAsync } = require("./media");
const { runMaintenanceTasksAsync } = require("./maintenance");
const {
  forwardGeocodeLookup,
  reverseGeocodeLookup,
  placesAutocomplete,
  placeDetails,
  suggestAddressesLookup,
  routeLookup,
} = require("./geocoding");
const { getBackendArchitectureStatusAsync } = require("./architecture_status");
const { storeHealth } = require("./store");
const { checkRateLimit } = require("./rate_limit");

const blockedUserAllowedCalls = new Set([
  "me",
  "getSessionBootstrap",
  "getRuntimeSettings",
  "getBackendArchitectureStatus",
  "listCityTariffs",
  "listIntercityRoutes",
  "getContentDocument",
  "updateFcmTokenState",
  "ackPushDelivery",
  "deleteCurrentAccountDeep",
]);

const handlers = {
  registerWithPassword: async ({ data }) => registerWithPassword(data),
  passwordLogin: async ({ data }) => passwordLogin(data),
  lookupUserByPhone: async ({ data }) => lookupUserByPhone(data),
  requestSmsCode: async ({ data }) => requestSmsCode(data),
  verifySmsCode: async ({ data }) => verifySmsCode(data),
  createSmsSession: async ({ data }) => createSmsSession(data),
  me: async ({ auth }) => {
    if (!auth?.user) {
      return {
        success: false,
        code: "UNAUTHENTICATED",
        error: "Пользователь не авторизован",
      };
    }
    return {
      success: true,
      user: publicUser(auth.user),
      userDocPath: `users/${auth.user.id}`,
    };
  },
  getStoreHealth: async () => {
    const health = await storeHealth();
    return {
      success: health.ok === true,
      store: health,
    };
  },
  getSessionBootstrap: async ({ data, auth }) => getSessionBootstrapAsync(data, auth),
  getRuntimeSettings: async () => getRuntimeSettingsAsync(),
  getBackendArchitectureStatus: async () => getBackendArchitectureStatusAsync(),
  updateRuntimeSettings: async ({ data, auth }) => updateRuntimeSettingsAsync(data, auth),
  getOrderQuote: async ({ data, auth }) => getOrderQuoteAsync(data, auth),
  getOrderDetails: async ({ data, auth }) => getOrderDetailsAsync(data, auth),
  listAvailableDriverOrders: async ({ data, auth }) => listAvailableDriverOrdersAsync(data, auth),
  listMyOrders: async ({ data, auth }) => listMyOrdersAsync(data, auth),
  adminListOrders: async ({ data, auth }) => adminListOrdersAsync(data, auth),
  createPassengerOrder: async ({ data, auth }) => createPassengerOrderAsync(data, auth),
  adminCreateOrder: async ({ data, auth }) => adminCreateOrderAsync(data, auth),
  expirePendingOrderIfNeeded: async ({ data, auth }) => expirePendingOrderIfNeededAsync(data, auth),
  acceptOrder: async ({ data, auth }) => acceptOrderAsync(data, auth),
  cancelPassengerOrder: async ({ data, auth }) => cancelPassengerOrderAsync(data, auth),
  advanceDriverOrderStatus: async ({ data, auth }) => advanceDriverOrderStatusAsync(data, auth),
  submitPassengerRegistration: async ({ data, auth }) => submitPassengerRegistrationAsync(data, auth),
  submitDriverRegistration: async ({ data, auth }) => submitDriverRegistrationAsync(data, auth),
  updateUserPreferences: async ({ data, auth }) => updateUserPreferencesAsync(data, auth),
  setPassword: async ({ data, auth }) => setPasswordAsync(data, auth),
  deleteCurrentAccountDeep: async ({ data, auth }) => deleteCurrentAccountDeepAsync(data, auth),
  adminListUsers: async ({ data, auth }) => adminListUsersAsync(data, auth),
  adminListAuditLogs: async ({ data, auth }) => adminListAuditLogsAsync(data, auth),
  adminUpdateUserDocument: async ({ data, auth }) => adminUpdateUserDocumentAsync(data, auth),
  adminCreateDriver: async ({ data, auth }) => adminCreateDriverAsync(data, auth),
  adminSavePolitika: async ({ data, auth }) => adminSavePolitikaAsync(data, auth),
  approveVehiclePhotoDeletion: async ({ data, auth }) => approveVehiclePhotoDeletionAsync(data, auth),
  rejectVehiclePhotoDeletion: async ({ data, auth }) => rejectVehiclePhotoDeletionAsync(data, auth),
  approveDriver: async ({ data, auth }) => approveDriverAsync(data, auth),
  adminCreatePassenger: async ({ data, auth }) => adminCreatePassengerAsync(data, auth),
  adminUpdateDriverCity: async ({ data, auth }) => adminUpdateDriverCityAsync(data, auth),
  adminUpdateDriverOrderDelay: async ({ data, auth }) => adminUpdateDriverOrderDelayAsync(data, auth),
  blockDriver: async ({ data, auth }) => blockDriverAsync(data, auth),
  unblockDriver: async ({ data, auth }) => unblockDriverAsync(data, auth),
  adminTopUpDriverBalance: async ({ data, auth }) => adminTopUpDriverBalanceAsync(data, auth),
  adminManageOrder: async ({ data, auth }) => adminManageOrderAsync(data, auth),
  listCityTariffs: async ({ data, auth }) => listCityTariffsAsync(data, auth),
  adminListCityTariffs: async ({ data, auth }) => adminListCityTariffsAsync(data, auth),
  adminUpsertCityTariff: async ({ data, auth }) => adminUpsertCityTariffAsync(data, auth),
  listIntercityRoutes: async ({ data, auth }) => listIntercityRoutesAsync(data, auth),
  adminListIntercityRoutes: async ({ data, auth }) => adminListIntercityRoutesAsync(data, auth),
  adminUpsertIntercityRoute: async ({ data, auth }) => adminUpsertIntercityRouteAsync(data, auth),
  getContentDocument: async ({ data }) => getContentDocumentAsync(data),
  adminUpdateContentDocument: async ({ data, auth }) => adminUpdateContentDocumentAsync(data, auth),
  adminListGenericCollection: async ({ data, auth }) => adminListGenericCollectionAsync(data, auth),
  adminUpsertGenericDocument: async ({ data, auth }) => adminUpsertGenericDocumentAsync(data, auth),
  adminDeleteGenericDocument: async ({ data, auth }) => adminDeleteGenericDocumentAsync(data, auth),
  createDriverTopUpPayment: async ({ data, auth, req }) => createDriverTopUpPaymentAsync(data, auth, req),
  getDriverTopUpPaymentStatus: async ({ data, auth }) => getDriverTopUpPaymentStatusAsync(data, auth),
  confirmDriverTopUpPayment: async ({ data, auth }) => confirmDriverTopUpPaymentAsync(data, auth),
  adminMarkKaspiInvoiceSent: async ({ data, auth }) => adminMarkKaspiInvoiceSentAsync(data, auth),
  failDriverTopUpPayment: async ({ data, auth }) => failDriverTopUpPaymentAsync(data, auth),
  createDriverWithdrawal: async ({ data, auth }) => createDriverWithdrawalAsync(data, auth),
  adminListWithdrawals: async ({ data, auth }) => adminListWithdrawalsAsync(data, auth),
  adminResolveWithdrawal: async ({ data, auth }) => adminResolveWithdrawalAsync(data, auth),
  adminListPayments: async ({ data, auth }) => adminListPaymentsAsync(data, auth),
  getMoneyStats: async ({ data, auth }) => getMoneyStatsAsync(data, auth),
  ensureSupportChat: async ({ data, auth }) => ensureSupportChatAsync(data, auth),
  getMySupportChat: async ({ data, auth }) => getMySupportChatAsync(data, auth),
  sendSupportChatMessage: async ({ data, auth }) => sendSupportChatMessageAsync(data, auth),
  markSupportChatRead: async ({ data, auth }) => markSupportChatReadAsync(data, auth),
  listSupportChats: async ({ data, auth }) => listSupportChatsAsync(data, auth),
  getSupportChatMessages: async ({ data, auth }) => getSupportChatMessagesAsync(data, auth),
  adminSendSupportChatMessage: async ({ data, auth }) => adminSendSupportChatMessageAsync(data, auth),
  adminDeleteSupportChat: async ({ data, auth }) => adminDeleteSupportChatAsync(data, auth),
  adminClearSupportChats: async ({ data, auth }) => adminClearSupportChatsAsync(data, auth),
  addFcmToken: async ({ data, auth }) => addFcmTokenAsync(data, auth),
  updateFcmTokenState: async ({ data, auth }) => updateFcmTokenStateAsync(data, auth),
  createPushNotification: async ({ data, auth }) => createPushNotificationAsync(data, auth),
  adminQueueBroadcast: async ({ data, auth }) => adminQueueBroadcastAsync(data, auth),
  adminListPushNotifications: async ({ data, auth }) => adminListPushNotificationsAsync(data, auth),
  flushQueuedPushDeliveries: async ({ data, auth }) => flushQueuedPushDeliveriesAsync(data, auth),
  ackPushDelivery: async ({ data, auth }) => ackPushDeliveryAsync(data, auth),
  uploadFile: async ({ data, auth, req }) => uploadFileAsync(data, auth, req),
  runMaintenanceTasks: async ({ data, auth }) => runMaintenanceTasksAsync(data, auth),
  forwardGeocodeLookup: async ({ data }) => forwardGeocodeLookup(data),
  reverseGeocodeLookup: async ({ data }) => reverseGeocodeLookup(data),
  placesAutocomplete: async ({ data }) => placesAutocomplete(data),
  placeDetails: async ({ data }) => placeDetails(data),
  suggestAddressesLookup: async ({ data }) => suggestAddressesLookup(data),
  routeLookup: async ({ data }) => routeLookup(data),
};

const publicAuthRateLimitedCalls = new Set([
  "passwordLogin",
  "registerWithPassword",
  "lookupUserByPhone",
  "requestSmsCode",
  "verifySmsCode",
  "createSmsSession",
]);

async function dispatchCall(name, data, req) {
  const handler = handlers[name];
  if (!handler) {
    return {
      success: false,
      code: "NOT_IMPLEMENTED",
      error: `Backend endpoint ${name} еще не перенесен`,
    };
  }
  if (publicAuthRateLimitedCalls.has(name)) {
    const perIpLimit = checkRateLimit(`${name}:ip`, {}, req);
    const rateLimit = perIpLimit.limited ? perIpLimit : checkRateLimit(name, data || {}, req);
    if (rateLimit.limited) {
      return {
        success: false,
        code: "RATE_LIMITED",
        error: "Слишком много попыток. Попробуйте позже.",
        retryAfterSec: rateLimit.retryAfterSec,
      };
    }
  }
  const auth = await verifyBearerToken(req);
  if (auth?.user?.blocked === true && !blockedUserAllowedCalls.has(name)) {
    return {
      success: false,
      code: "USER_BLOCKED",
      error: "Аккаунт заблокирован",
      user: publicUser(auth.user),
      userDocPath: `users/${auth.user.id}`,
    };
  }
  return handler({ data: data || {}, auth, req });
}

module.exports = {
  dispatchCall,
  blockedUserAllowedCalls,
  handlerNames: Object.freeze(Object.keys(handlers)),
  publicAuthRateLimitedCalls,
};
