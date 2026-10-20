import 'dart:math' as math;

import '/backend/backend.dart';

int? phoneLength(String? phones) {
  return phones?.length;
}

String? formatCoordinates(LatLng? coords) {
  final point = coords!;
  final lat = point.latitude.toString();
  final lon = point.longitude.toString();

  return "$lat, $lon";
}

String? getAdres(String? str) {
  final adres = str!.split(',');

  return "${adres[1].trim()}, ${adres[2].trim()}";
}

bool isNightTariff([DateTime? time]) {
  final now = time ?? DateTime.now();
  final hour = now.hour;
  return hour >= 0 && hour < 6;
}

double applyNightMultiplier(
  double price,
  bool isNight, {
  double nightMultiplier = 1.5,
}) {
  if (!isNight) return price;
  return price * nightMultiplier;
}

double calcLocalPrice({
  required bool isDelivery,
  double? cityDayPrice,
  double? cityNightPrice,
  double fallbackTaxiPrice = 800,
  double fallbackDeliveryPrice = 1200,
  double deliveryExtra = 400,
  double nightMultiplier = 1.5,
  DateTime? time,
}) {
  final isNight = isNightTariff(time);
  final baseCity = isNight
      ? (cityNightPrice != null && cityNightPrice > 0
          ? cityNightPrice
          : cityDayPrice ?? 0)
      : (cityDayPrice != null && cityDayPrice > 0
          ? cityDayPrice
          : cityNightPrice ?? 0);
  final baseTaxi = baseCity > 0 ? baseCity : fallbackTaxiPrice;
  final baseDelivery =
      baseCity > 0 ? (baseCity + deliveryExtra) : fallbackDeliveryPrice;
  final base = isDelivery ? baseDelivery : baseTaxi;
  return isNight && baseCity == 0
      ? applyNightMultiplier(
          base,
          isNight,
          nightMultiplier: nightMultiplier,
        )
      : base;
}

double calcIntercityPrice({
  required double distanceKm,
  double basePrice = 500,
  double pricePerKm = 130,
  double minPrice = 3000,
  double nightMultiplier = 1.5,
  DateTime? time,
}) {
  final base = (basePrice + pricePerKm * distanceKm).toDouble();
  final price = base < minPrice ? minPrice : base;
  return applyNightMultiplier(
    price,
    isNightTariff(time),
    nightMultiplier: nightMultiplier,
  );
}

double calcCityFormulaPrice({
  required double distanceKm,
  double basePrice = 500,
  double pricePerKm = 60,
  double nightMultiplier = 1.5,
  DateTime? time,
}) {
  final extraKm = distanceKm - 1;
  final base =
      (basePrice + (extraKm > 0 ? extraKm * pricePerKm : 0)).toDouble();
  return applyNightMultiplier(
    base,
    isNightTariff(time),
    nightMultiplier: nightMultiplier,
  );
}

double calcCommission({DateTime? time}) {
  return isNightTariff(time) ? 150.0 : 100.0;
}

double calcCommissionByNight(bool isNight) {
  return isNight ? 150.0 : 100.0;
}

String generateUserId() {
  final rnd = math.Random();
  final value = rnd.nextInt(29999) + 1;
  return value.toString().padLeft(5, '0');
}
