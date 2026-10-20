import '/backend/backend_calls/backend_calls.dart';

class AppCityTariff {
  const AppCityTariff({
    required this.title,
    this.dayPrice,
    this.nightPrice,
    this.deliveryPrice,
  });

  final String title;
  final double? dayPrice;
  final double? nightPrice;
  final double? deliveryPrice;
}

const _cityTariffCacheTtl = Duration(minutes: 10);
final Map<String, AppCityTariff> _cityTariffCache = {};
DateTime? _cityTariffCacheExpiresAt;
Future<List<AppCityTariff>>? _cityTariffInFlight;

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

AppCityTariff _cityTariffFromBackend(Map<String, dynamic> item) {
  var dayPrice = _asDouble(item['priceDay']);
  var nightPrice = _asDouble(item['priceNight']);
  final legacyPrice = _asDouble(item['priceCity']);
  if (dayPrice <= 0 && nightPrice <= 0 && legacyPrice > 0) {
    dayPrice = legacyPrice;
    nightPrice = legacyPrice;
  }
  final deliveryPrice = _asDouble(item['deliveryPrice']);
  return AppCityTariff(
    title: (item['title'] ?? '').toString().trim(),
    dayPrice: dayPrice > 0 ? dayPrice : null,
    nightPrice: nightPrice > 0 ? nightPrice : null,
    deliveryPrice: deliveryPrice > 0 ? deliveryPrice : null,
  );
}

Future<List<AppCityTariff>> loadAppCityTariffs({
  String query = '',
}) async {
  final now = DateTime.now();
  if (_cityTariffCache.isNotEmpty &&
      _cityTariffCacheExpiresAt != null &&
      now.isBefore(_cityTariffCacheExpiresAt!)) {
    return _filterCityTariffs(_cityTariffCache.values.toList(), query);
  }
  final inFlight = _cityTariffInFlight;
  if (inFlight != null) {
    return _filterCityTariffs(await inFlight, query);
  }

  final future = () async {
    final response = await makeCloudCall('listCityTariffs', {});
    final tariffs = (response['tariffs'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => _cityTariffFromBackend(Map<String, dynamic>.from(item)))
        .where((item) => item.title.isNotEmpty)
        .toList();
    tariffs
        .sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _cityTariffCache
      ..clear()
      ..addEntries(tariffs.map((item) => MapEntry(item.title, item)));
    _cityTariffCacheExpiresAt = DateTime.now().add(_cityTariffCacheTtl);
    return tariffs;
  }();

  _cityTariffInFlight = future;
  future.whenComplete(() {
    if (identical(_cityTariffInFlight, future)) {
      _cityTariffInFlight = null;
    }
  });
  return _filterCityTariffs(await future, query);
}

List<AppCityTariff> _filterCityTariffs(
  List<AppCityTariff> tariffs,
  String query,
) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return List<AppCityTariff>.unmodifiable(tariffs);
  }
  return List<AppCityTariff>.unmodifiable(
    tariffs.where((item) => item.title.toLowerCase().contains(normalizedQuery)),
  );
}

Future<List<String>> loadAppCityTitles() async {
  final tariffs = await loadAppCityTariffs();
  return List<String>.unmodifiable(tariffs.map((item) => item.title));
}

Future<AppCityTariff?> findAppCityTariff(String cityName) async {
  final normalizedCity = cityName.trim().toLowerCase();
  if (normalizedCity.isEmpty) {
    return null;
  }
  final tariffs = await loadAppCityTariffs();
  for (final tariff in tariffs) {
    if (tariff.title.toLowerCase() == normalizedCity) {
      return tariff;
    }
  }
  return null;
}
