import 'package:flutter_test/flutter_test.dart';
import 'package:mtaxi/flutter_flow/custom_functions.dart' as functions;

void main() {
  test('isNightTariff works for night hours', () {
    final night = DateTime(2025, 1, 1, 2, 0);
    final day = DateTime(2025, 1, 1, 12, 0);
    expect(functions.isNightTariff(night), isTrue);
    expect(functions.isNightTariff(day), isFalse);
  });

  test('applyNightMultiplier applies 1.5x only at night', () {
    expect(functions.applyNightMultiplier(100, false), 100);
    expect(functions.applyNightMultiplier(100, true), 150);
  });

  test('calcLocalPrice uses city day/night prices if provided', () {
    final day = DateTime(2025, 1, 1, 10, 0);
    final night = DateTime(2025, 1, 1, 2, 0);
    final dayPrice = functions.calcLocalPrice(
      isDelivery: false,
      cityDayPrice: 900,
      cityNightPrice: 1200,
      time: day,
    );
    final nightPrice = functions.calcLocalPrice(
      isDelivery: false,
      cityDayPrice: 900,
      cityNightPrice: 1200,
      time: night,
    );
    expect(dayPrice, 900);
    expect(nightPrice, 1200);
  });

  test('calcLocalPrice falls back to base and night multiplier', () {
    final night = DateTime(2025, 1, 1, 3, 0);
    final taxi = functions.calcLocalPrice(
      isDelivery: false,
      time: night,
    );
    final delivery = functions.calcLocalPrice(
      isDelivery: true,
      time: night,
    );
    expect(taxi, 800 * 1.5);
    expect(delivery, 1200 * 1.5);
  });

  test('calcIntercityPrice has minimum 3000', () {
    final day = DateTime(2025, 1, 1, 12, 0);
    final price = functions.calcIntercityPrice(distanceKm: 5, time: day);
    expect(price, 3000);
  });

  test('calcIntercityPrice grows with distance', () {
    final day = DateTime(2025, 1, 1, 12, 0);
    final price = functions.calcIntercityPrice(distanceKm: 30, time: day);
    expect(price, greaterThan(3000));
  });

  test('calcCityFormulaPrice uses 500 + 60 per km after first', () {
    final day = DateTime(2025, 1, 1, 12, 0);
    expect(functions.calcCityFormulaPrice(distanceKm: 1, time: day), 500);
    expect(functions.calcCityFormulaPrice(distanceKm: 3, time: day), 620);
  });

  test('calcCommission by night', () {
    final day = DateTime(2025, 1, 1, 12, 0);
    final night = DateTime(2025, 1, 1, 2, 0);
    expect(functions.calcCommission(time: day), 100);
    expect(functions.calcCommission(time: night), 150);
  });
}
