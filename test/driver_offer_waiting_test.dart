import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mtaxi/trips/driver_offer_waiting.dart';
import 'design_flow_test.dart' show wrap;

void main() {
  for (final outcome in ['accepted', 'declined', 'expired']) {
    testWidgets('driver waiting ends safely on $outcome', (tester) async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
          appName: 'MTaxi',
          packageName: 'test.mtaxi',
          version: '1',
          buildNumber: '1',
          buildSignature: '');
      bool? result;
      var calls = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(wrap(Scaffold(
            body: Builder(
                builder: (context) => FilledButton(
                    onPressed: () async {
                      result = await Navigator.of(context)
                          .push<bool>(MaterialPageRoute(
                              builder: (_) => DriverOfferWaiting(
                                  orderDocPath: 'order/test',
                                  offer: {
                                    'id': 'offer-1',
                                    'price': 700,
                                    'expiresAt': tester.binding.clock
                                        .now()
                                        .add(const Duration(seconds: 30))
                                        .toIso8601String()
                                  },
                                  now: () => tester.binding.clock.now())));
                    },
                    child: const Text('Лента заказов'))))));
        await tester.tap(find.text('Лента заказов'));
        await tester.pumpAndSettle();
        if (outcome == 'expired') {
          expect(find.text('Ожидаем ответ пассажира'), findsOneWidget);
          await tester.pump(const Duration(seconds: 29));
          await tester.pump();
          expect(result, isNull);
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
        }
        expect(result, outcome == 'accepted');
        expect(find.text('Лента заказов'), findsOneWidget);
        expect(calls, greaterThan(0));
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/listOrderOffers')) calls++;
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'orderStatus': outcome == 'accepted' ? 2 : 0,
                      'assignedToCurrentDriver': outcome == 'accepted',
                      'offers': [
                        {
                          'id': 'offer-1',
                          'status':
                              outcome == 'declined' ? 'declined' : 'pending'
                        }
                      ]
                    }),
                    200,
                    headers: {'content-type': 'application/json'});
              }));
    });
  }
}
