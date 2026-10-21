import 'dart:async';

import '/backend/backend_session.dart';
import '/flutter_flow/flutter_flow_util.dart';

class AppRuntimeSettings {
  const AppRuntimeSettings({
    this.intercityEnabled = false,
    this.orderRadiusKm = 10,
    this.orderPendingTtlMin = 20,
    this.driverMinBalanceToTakeOrder = 100,
    this.passengerAcceptedCancelCooldownMin = 0,
    this.passengerAcceptedCancelDailyLimit = 3,
    this.driverLastActiveHeartbeatSec = 60,
    this.driverCoordsUpdateSec = 2,
    this.onlineDriverWindowMin = 2,
    this.cloudCallTimeoutSec = 20,
    this.deliveryExtra = 400,
    this.deliveryExtraNight,
    this.fallbackTaxiPrice = 800,
    this.fallbackDeliveryPrice = 1200,
    this.nightMultiplier = 1.5,
    this.maxOrderAlertTriggerDelaySec = 15,
    this.driverOrderMaxDelaySec = 10,
    this.intercityBasePrice = 500,
    this.intercityPricePerKm = 130,
    this.intercityMinPrice = 3000,
    this.cityFormulaBasePrice = 500,
    this.cityFormulaPerKm = 60,
  });

  final bool intercityEnabled;
  final double orderRadiusKm;
  final int orderPendingTtlMin;
  final double driverMinBalanceToTakeOrder;
  final int passengerAcceptedCancelCooldownMin;
  final int passengerAcceptedCancelDailyLimit;
  final int driverLastActiveHeartbeatSec;
  final int driverCoordsUpdateSec;
  final int onlineDriverWindowMin;
  final int cloudCallTimeoutSec;
  final double deliveryExtra;
  final double? deliveryExtraNight;
  final double fallbackTaxiPrice;
  final double fallbackDeliveryPrice;
  final double nightMultiplier;
  final int maxOrderAlertTriggerDelaySec;
  final int driverOrderMaxDelaySec;
  final double intercityBasePrice;
  final double intercityPricePerKm;
  final double intercityMinPrice;
  final double cityFormulaBasePrice;
  final double cityFormulaPerKm;

  static const AppRuntimeSettings defaults = AppRuntimeSettings();

  factory AppRuntimeSettings.fromMap(Map<String, dynamic>? data) {
    final defaults = AppRuntimeSettings.defaults;
    double asDouble(List<String> keys, double fallback) {
      for (final key in keys) {
        final value = data?[key];
        if (value is num) return value.toDouble();
        final parsed = double.tryParse(value?.toString() ?? '');
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    double? asNullableDouble(List<String> keys) {
      for (final key in keys) {
        final value = data?[key];
        if (value == null) continue;
        if (value is num) return value.toDouble();
        final parsed = double.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
      return null;
    }

    int asInt(List<String> keys, int fallback) {
      for (final key in keys) {
        final parsed = _asInt(data?[key]);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    return AppRuntimeSettings(
      intercityEnabled: data?['intercityEnabled'] == true,
      orderRadiusKm: asDouble(['orderRadiusKm'], defaults.orderRadiusKm),
      orderPendingTtlMin: asInt(
        ['orderPendingTtlMin', 'pendingOrderLifetimeMin'],
        defaults.orderPendingTtlMin,
      ),
      driverMinBalanceToTakeOrder: asDouble(
        ['driverMinBalanceToTakeOrder'],
        defaults.driverMinBalanceToTakeOrder,
      ),
      passengerAcceptedCancelCooldownMin: asInt(
          ['passengerAcceptedCancelCooldownMin'],
          defaults.passengerAcceptedCancelCooldownMin),
      passengerAcceptedCancelDailyLimit: asInt(
          ['passengerAcceptedCancelDailyLimit'],
          defaults.passengerAcceptedCancelDailyLimit),
      driverLastActiveHeartbeatSec: asInt(['driverLastActiveHeartbeatSec'],
          defaults.driverLastActiveHeartbeatSec),
      driverCoordsUpdateSec:
          asInt(['driverCoordsUpdateSec'], defaults.driverCoordsUpdateSec),
      onlineDriverWindowMin:
          asInt(['onlineDriverWindowMin'], defaults.onlineDriverWindowMin),
      cloudCallTimeoutSec:
          asInt(['cloudCallTimeoutSec'], defaults.cloudCallTimeoutSec),
      deliveryExtra: asDouble(['deliveryExtra'], defaults.deliveryExtra),
      deliveryExtraNight: asNullableDouble(['deliveryExtraNight']),
      fallbackTaxiPrice: asDouble(
        ['fallbackTaxiPrice', 'taxiFallbackPrice'],
        defaults.fallbackTaxiPrice,
      ),
      fallbackDeliveryPrice: asDouble(
        ['fallbackDeliveryPrice', 'deliveryFallbackPrice'],
        defaults.fallbackDeliveryPrice,
      ),
      nightMultiplier: asDouble(['nightMultiplier'], defaults.nightMultiplier),
      maxOrderAlertTriggerDelaySec: asInt(
        ['maxOrderAlertTriggerDelaySec'],
        defaults.maxOrderAlertTriggerDelaySec,
      ),
      driverOrderMaxDelaySec:
          asInt(['driverOrderMaxDelaySec'], defaults.driverOrderMaxDelaySec),
      intercityBasePrice:
          asDouble(['intercityBasePrice'], defaults.intercityBasePrice),
      intercityPricePerKm:
          asDouble(['intercityPricePerKm'], defaults.intercityPricePerKm),
      intercityMinPrice:
          asDouble(['intercityMinPrice'], defaults.intercityMinPrice),
      cityFormulaBasePrice:
          asDouble(['cityFormulaBasePrice'], defaults.cityFormulaBasePrice),
      cityFormulaPerKm:
          asDouble(['cityFormulaPerKm'], defaults.cityFormulaPerKm),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class AppVersionPolicy {
  const AppVersionPolicy({
    this.minSupportedVersion = '',
    this.minSupportedBuildNumber = 0,
    this.latestVersion = '',
    this.latestBuildNumber = 0,
    this.forceUpdateEnabled = false,
    this.updateMessage = '',
    this.storeUrl = '',
  });

  final String minSupportedVersion;
  final int minSupportedBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final bool forceUpdateEnabled;
  final String updateMessage;
  final String storeUrl;

  bool get hasConfig =>
      minSupportedVersion.isNotEmpty ||
      minSupportedBuildNumber > 0 ||
      latestVersion.isNotEmpty ||
      latestBuildNumber > 0;
}

const _settingsCacheTtl = Duration(seconds: 15);
AppRuntimeSettings _cachedRuntimeSettings = AppRuntimeSettings.defaults;
Map<String, dynamic> _cachedRuntimeSettingsRaw = const <String, dynamic>{};
DateTime? _runtimeSettingsExpiresAt;
bool _hasLoadedRuntimeSettings = false;
Future<AppRuntimeSettings>? _runtimeSettingsFetchInFlight;
StreamSubscription<AppRuntimeSettings>? _runtimeSettingsHotSyncSub;

Future<Map<String, dynamic>?> _fetchRuntimeSettingsMap() async {
  try {
    final response = await mtaxiBackendCall('getRuntimeSettings', {});
    final settings = response['settings'];
    if (response['success'] == true && settings is Map) {
      return Map<String, dynamic>.from(settings);
    }
  } catch (_) {}
  return null;
}

void _storeRuntimeSettings(AppRuntimeSettings settings) {
  _cachedRuntimeSettings = settings;
  _hasLoadedRuntimeSettings = true;
  _runtimeSettingsExpiresAt = DateTime.now().add(_settingsCacheTtl);
}

void _storeRuntimeSettingsRaw(Map<String, dynamic>? data) {
  _cachedRuntimeSettingsRaw = Map<String, dynamic>.from(
    data ?? const <String, dynamic>{},
  );
}

Future<AppRuntimeSettings> _refreshRuntimeSettingsInternal() {
  final inFlight = _runtimeSettingsFetchInFlight;
  if (inFlight != null) {
    return inFlight;
  }

  final future = () async {
    final data = await _fetchRuntimeSettingsMap();
    final settings = AppRuntimeSettings.fromMap(data);
    _storeRuntimeSettingsRaw(data);
    _storeRuntimeSettings(settings);
    return settings;
  }();

  _runtimeSettingsFetchInFlight = future;
  future.whenComplete(() {
    if (identical(_runtimeSettingsFetchInFlight, future)) {
      _runtimeSettingsFetchInFlight = null;
    }
  });
  return future;
}

Future<AppRuntimeSettings> getAppRuntimeSettings({
  bool forceRefresh = false,
}) async {
  final now = DateTime.now();
  final cacheExpired = _runtimeSettingsExpiresAt == null ||
      now.isAfter(_runtimeSettingsExpiresAt!);

  if (!forceRefresh && _hasLoadedRuntimeSettings) {
    if (!cacheExpired) {
      return _cachedRuntimeSettings;
    }
    unawaited(_refreshRuntimeSettingsInternal());
    return _cachedRuntimeSettings;
  }

  return _refreshRuntimeSettingsInternal();
}

Future<AppRuntimeSettings> updateAppRuntimeSettingsFromBackend(
  Map<String, dynamic> fields,
) async {
  final response = await mtaxiBackendCall('updateRuntimeSettings', {
    'fields': fields,
  });
  if (response['success'] != true) {
    throw Exception(response['error']?.toString() ?? 'Не удалось сохранить');
  }
  final rawSettings = response['settings'];
  final settingsMap = rawSettings is Map
      ? Map<String, dynamic>.from(rawSettings)
      : Map<String, dynamic>.from(fields);
  final settings = AppRuntimeSettings.fromMap(settingsMap);
  _storeRuntimeSettingsRaw(settingsMap);
  _storeRuntimeSettings(settings);
  return settings;
}

Future<void> ensureRuntimeSettingsSyncStarted() async {
  if (_runtimeSettingsHotSyncSub != null) {
    return;
  }
  _runtimeSettingsHotSyncSub = watchAppRuntimeSettings().listen(
    _storeRuntimeSettings,
    onError: (_) {},
  );
  if (!_hasLoadedRuntimeSettings) {
    await _refreshRuntimeSettingsInternal();
  }
}

Future<AppRuntimeSettings> primeAppRuntimeSettings({
  bool forceRefresh = false,
}) async {
  await ensureRuntimeSettingsSyncStarted();
  return getAppRuntimeSettings(forceRefresh: forceRefresh);
}

AppRuntimeSettings get currentAppRuntimeSettings => _cachedRuntimeSettings;

Map<String, dynamic> get currentAppRuntimeSettingsRaw =>
    Map<String, dynamic>.from(_cachedRuntimeSettingsRaw);

AppVersionPolicy get currentAppVersionPolicy {
  final map = _cachedRuntimeSettingsRaw;
  final isIosPlatform = isiOS;
  final isAndroidPlatform = isAndroid;
  final minVersion = (isIosPlatform
              ? map['minSupportedVersionIos']
              : isAndroidPlatform
                  ? map['minSupportedVersionAndroid']
                  : null)
          ?.toString()
          .trim() ??
      (map['minSupportedVersion']?.toString().trim() ?? '');
  final latestVersion = (isIosPlatform
              ? map['latestVersionIos']
              : isAndroidPlatform
                  ? map['latestVersionAndroid']
                  : null)
          ?.toString()
          .trim() ??
      (map['latestVersion']?.toString().trim() ?? '');
  final storeUrl = (isIosPlatform
              ? map['iosStoreUrl']
              : isAndroidPlatform
                  ? map['androidStoreUrl']
                  : null)
          ?.toString()
          .trim() ??
      '';
  final minBuild = AppRuntimeSettings._asInt(
        isIosPlatform
            ? map['minSupportedBuildNumberIos']
            : isAndroidPlatform
                ? map['minSupportedBuildNumberAndroid']
                : null,
      ) ??
      AppRuntimeSettings._asInt(map['minSupportedBuildNumber']) ??
      0;
  final latestBuild = AppRuntimeSettings._asInt(
        isIosPlatform
            ? map['latestBuildNumberIos']
            : isAndroidPlatform
                ? map['latestBuildNumberAndroid']
                : null,
      ) ??
      AppRuntimeSettings._asInt(map['latestBuildNumber']) ??
      0;
  final forceUpdateEnabled = (map['forceUpdateEnabled'] == true) ||
      (isIosPlatform && map['forceUpdateEnabledIos'] == true) ||
      (isAndroidPlatform && map['forceUpdateEnabledAndroid'] == true);
  return AppVersionPolicy(
    minSupportedVersion: minVersion,
    minSupportedBuildNumber: minBuild,
    latestVersion: latestVersion,
    latestBuildNumber: latestBuild,
    forceUpdateEnabled: forceUpdateEnabled,
    updateMessage: (map['updateMessage']?.toString().trim() ?? ''),
    storeUrl: storeUrl,
  );
}

Stream<AppRuntimeSettings> watchAppRuntimeSettings() {
  return (() async* {
    while (true) {
      yield await _refreshRuntimeSettingsInternal();
      await Future<void>.delayed(_settingsCacheTtl);
    }
  })();
}
