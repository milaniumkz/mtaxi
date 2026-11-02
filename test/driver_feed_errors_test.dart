import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtaxi/backend/backend_orders.dart';
import 'package:mtaxi/backend/backend_session.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {mtaxiBackendAccessTokenPrefsKey: 'synthetic'});
    PackageInfo.setMockInitialValues(
        appName: 'MTaxi',
        packageName: 'audit',
        version: '1',
        buildNumber: '1',
        buildSignature: '');
  });
  test('failed feed response is not a successful empty result', () async {
    await http.runWithClient(
        () => expectLater(
            loadAvailableDriverOrdersFromBackend(), throwsStateError),
        () => MockClient((_) async =>
            http.Response('{"success":false,"error":"Unavailable"}', 503)));
  });
  testWidgets('feed emits an error then recovers on the next poll',
      (tester) async {
    var healthy = false;
    final failures = <Object>[];
    final data = <Object>[];
    await http.runWithClient(() async {
      final subscription = availableDriverOrdersStreamFromBackend()
          .listen(data.add, onError: (Object error) => failures.add(error));
      for (var i = 0; i < 8; i++)
        await tester.pump(const Duration(milliseconds: 50));
      expect(failures, hasLength(1));
      expect(data, isEmpty);
      healthy = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(data, hasLength(1));
      expect(data.single, isEmpty);
      final cancellation = subscription.cancel();
      await tester.pump(const Duration(seconds: 2));
      await cancellation;
    },
        () => MockClient((_) async => http.Response(
            jsonEncode(healthy
                ? {'success': true, 'orders': []}
                : {'success': false, 'error': 'Unavailable'}),
            healthy ? 200 : 503)));
  });
}
