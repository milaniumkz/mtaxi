import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:mtaxi/custom_code/widgets/delivery_taxi_map.dart';
import 'package:mtaxi/flutter_flow/internationalization.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      FFLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FallbackMaterialLocalizationDelegate(),
      FallbackCupertinoLocalizationDelegate(),
    ],
    supportedLocales: const [
      Locale('ru'),
      Locale('kk'),
    ],
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 800,
        child: child,
      ),
    ),
  );
}

const _routes = [
  IntercityRoute(
    ot: 'Усть-Каменогорск',
    kuda: 'Глубокое',
    price: 3500,
  ),
  IntercityRoute(
    ot: 'Семей',
    kuda: 'Павлодар',
    price: 7000,
  ),
];

void main() {
  testWidgets(
      'disabled intercity is hidden and a saved selection falls back to taxi',
      (tester) async {
    await tester.pumpWidget(_wrap(const DeliveryTaxiMap(
      intercityEnabled: false,
      initialServiceType: 'intercity',
      enableAutoLocation: false,
      enableRemoteGeocoding: false,
      enableTileLayer: false,
      intercityRoutesOverride: _routes,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Межгород'), findsNothing);
    expect(find.text('Такси'), findsOneWidget);
    expect(find.text('Доставка'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Куда (выбор маршрута)'),
        findsNothing);
  });

  testWidgets('intercity uses route selector and disables manual search',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const DeliveryTaxiMap(
          intercityEnabled: true,
          initialServiceType: 'intercity',
          enableAutoLocation: false,
          enableRemoteGeocoding: false,
          enableTileLayer: false,
          intercityRoutesOverride: _routes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toFieldFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Куда (выбор маршрута)',
    );
    expect(toFieldFinder, findsOneWidget);
    final toField = tester.widget<TextField>(toFieldFinder);
    expect(toField.readOnly, isFalse);

    final routePickerFinder = find.byWidgetPredicate((widget) {
      if (widget is! IconButton) return false;
      final icon = widget.icon;
      return widget.onPressed != null &&
          icon is Icon &&
          icon.icon == Icons.arrow_drop_down;
    });
    expect(routePickerFinder, findsOneWidget);
  });

  testWidgets('intercity to list filtered by from city and price updates',
      (tester) async {
    double? price;
    String? toAddress;

    await tester.pumpWidget(
      _wrap(
        DeliveryTaxiMap(
          intercityEnabled: true,
          initialServiceType: 'intercity',
          initialFromAddress: 'Усть-Каменогорск, Абая 1',
          enableAutoLocation: false,
          enableRemoteGeocoding: false,
          enableTileLayer: false,
          intercityRoutesOverride: _routes,
          onIntercityPriceChanged: (value) => price = value,
          onToAddressChanged: (value) => toAddress = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toFieldFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Куда (выбор маршрута)',
    );
    await tester.enterText(toFieldFinder, 'Глубокое');
    await tester.pump(const Duration(milliseconds: 400));

    expect(toAddress, 'Глубокое');
    expect(price, 3500);
  });

  testWidgets('intercity map tap on to is blocked', (tester) async {
    int toCoordsCalls = 0;
    Future<void> Function(latlng.LatLng)? tapHandler;

    await tester.pumpWidget(
      _wrap(
        DeliveryTaxiMap(
          intercityEnabled: true,
          initialServiceType: 'intercity',
          enableAutoLocation: false,
          enableRemoteGeocoding: false,
          enableTileLayer: false,
          intercityRoutesOverride: _routes,
          onToCoordsChanged: (_) => toCoordsCalls += 1,
          onTestMapTapHandler: (handler) => tapHandler = handler,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();

    expect(tapHandler, isNotNull);
    await tapHandler!(const latlng.LatLng(0, 0));
    await tester.pumpAndSettle();

    expect(toCoordsCalls, 0);
    expect(
      find.text('Пункт "Куда" выбирается из списка маршрутов'),
      findsOneWidget,
    );
  });

  testWidgets('intercity map tap on from sets from coords', (tester) async {
    int fromCoordsCalls = 0;
    Future<void> Function(latlng.LatLng)? tapHandler;

    await tester.pumpWidget(
      _wrap(
        DeliveryTaxiMap(
          intercityEnabled: true,
          initialServiceType: 'intercity',
          enableAutoLocation: false,
          enableRemoteGeocoding: false,
          enableTileLayer: false,
          intercityRoutesOverride: _routes,
          onFromCoordsChanged: (_) => fromCoordsCalls += 1,
          onTestMapTapHandler: (handler) => tapHandler = handler,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tapHandler, isNotNull);
    await tapHandler!(const latlng.LatLng(0, 0));
    await tester.pumpAndSettle();

    expect(fromCoordsCalls, 1);
  });
}
