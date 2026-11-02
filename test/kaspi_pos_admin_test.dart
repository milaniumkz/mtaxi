import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtaxi/admin/admin_home/kaspi_pos_connection_card.dart';
import 'package:mtaxi/admin/admin_collection/kaspi_payment_actions.dart';
import 'package:mtaxi/component/select_balance/select_balance_widget.dart';
import 'design_flow_test.dart' show wrap;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'MTaxi',
        packageName: 'test.mtaxi',
        version: '1',
        buildNumber: '1',
        buildSignature: '');
  });
  testWidgets(
      'customer invoice shows automatic payment and cancellation without admin confirmation',
      (tester) async {
    for (final terminal in ['success', 'failed']) {
      SharedPreferences.setMockInitialValues({});
      await http.runWithClient(() async {
        await tester.pumpWidget(
            wrap(const Scaffold(body: SelectBalanceWidget(passenger: true))));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(0), '+77019990001');
        await tester.enterText(find.byType(TextField).at(1), '500');
        await tester.ensureVisible(find.text('Выставить счёт Kaspi'));
        await tester.tap(find.text('Выставить счёт Kaspi'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Счёт выставлен'), findsOneWidget);
        await tester.tap(find.text('Проверить оплату'));
        await tester.pumpAndSettle();
        expect(
            find.textContaining(
                terminal == 'success' ? 'Деньги зачислены' : 'Счёт отменён'),
            findsOneWidget);
        expect(find.text('Новое пополнение'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
          () => MockClient((request) async {
                final create =
                    request.url.path.endsWith('createPassengerTopUpPayment');
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'paymentId': 'auto',
                      'automatic': true,
                      'invoiceStatus': 'sent',
                      'paymentStatus': create ? 'pending' : terminal,
                      'bankState': create
                          ? 'pending'
                          : terminal == 'success'
                              ? 'paid'
                              : 'cancelled'
                    }),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }));
    }
  });
  testWidgets(
      'admin SMS flow keeps OTP ephemeral and never creates an invoice on login/check',
      (tester) async {
    final calls = <String>[];
    var state = <String, dynamic>{
      'enabled': true,
      'configured': true,
      'connected': false
    };
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap(const Scaffold(
          body: SingleChildScrollView(child: KaspiPosConnectionCard()))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Касса Kaspi Pay'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('kaspi-pos-phone')), '+77019990001');
      await tester
          .ensureVisible(find.byKey(const ValueKey('kaspi-pos-send-sms')));
      await tester.tap(find.byKey(const ValueKey('kaspi-pos-send-sms')));
      await tester.pumpAndSettle();
      final otp = find.byKey(const ValueKey('kaspi-pos-otp'));
      expect(tester.widget<TextField>(otp).obscureText, true);
      await tester.enterText(otp, '1234');
      await tester
          .ensureVisible(find.byKey(const ValueKey('kaspi-pos-verify')));
      await tester.tap(find.byKey(const ValueKey('kaspi-pos-verify')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kaspi-pos-otp')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('kaspi-pos-check')));
      await tester.tap(find.byKey(const ValueKey('kaspi-pos-check')));
      await tester.pumpAndSettle();
      expect(find.text('Соединение проверено'), findsOneWidget);
      expect(calls.where((x) => x.contains('SendInvoice')), isEmpty);
      expect(
          (await SharedPreferences.getInstance())
              .getKeys()
              .where((k) => k.toLowerCase().contains('otp')),
          isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              final name = request.url.pathSegments.last;
              calls.add(name);
              final data = jsonDecode(request.body) as Map;
              if (name == 'adminKaspiPosStartLogin') {
                expect(data['phone'], '+77019990001');
                state = {
                  ...state,
                  'pendingAuth': true,
                  'challengeId': 'opaque-mtaxi-id',
                  'phoneHint': '+7 701 *** ** 01'
                };
              }
              if (name == 'adminKaspiPosVerifyLogin') {
                expect(data['challengeId'], 'opaque-mtaxi-id');
                expect(data['otp'], '1234');
                state = {
                  ...state,
                  'pendingAuth': false,
                  'connected': true,
                  'merchantVerified': true,
                  'organization': {
                    'id': '25',
                    'name': 'Test merchant',
                    'iin': '970905350621'
                  }
                };
              }
              if (name == 'adminKaspiPosCheckConnection')
                state = {...state, 'connectionActive': true};
              return http.Response(
                  jsonEncode({'success': true, 'status': state}), 200,
                  headers: {'content-type': 'application/json'});
            }));
  });
  testWidgets(
      'sending a Kaspi invoice requires explicit confirmation and blocks paid confirmation until verification',
      (tester) async {
    var sent = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap(Scaffold(
          body: SingleChildScrollView(
              child: KaspiPaymentActions(
        payment: {
          'paymentId': 'topup',
          'amount': 500,
          'kaspiPhone': '+77019990001',
          'invoiceStatus': 'requested'
        },
        onChanged: () {},
      )))));
      await tester.tap(find.text('Выставить счёт через Kaspi Pay'));
      await tester.pumpAndSettle();
      expect(sent, 0);
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(sent, 1);
      await tester.pumpWidget(wrap(Scaffold(
          body: SingleChildScrollView(
              child: KaspiPaymentActions(
        payment: {
          'paymentId': 'topup',
          'amount': 500,
          'kaspiPhone': '+77019990001',
          'invoiceStatus': 'sent',
          'kaspiPosAttemptId': 'attempt',
          'kaspiPosOperationId': '123',
          'kaspiPosBankState': 'pending'
        },
        onChanged: () {},
      )))));
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Подтвердить оплату'));
      expect(button.onPressed, isNull);
      expect(find.text('Выставить счёт через Kaspi Pay'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/adminKaspiPosSendInvoice')) {
                final data = jsonDecode(request.body) as Map;
                expect(data['confirm'], true);
                expect(data['paymentId'], 'topup');
                sent++;
              }
              return http.Response('{"success":true}', 200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
