import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtaxi/passenger/about/about_widget.dart';
import 'design_flow_test.dart' show wrap;

void main() {
  testWidgets('service explanation remains usable offline at large text size',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap(const AboutWidget(), scale: 2));
      await tester.pumpAndSettle();
      expect(find.text('Как работает MTaxi'), findsOneWidget);
      expect(find.text('Укажите маршрут и свою цену'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.text('Документы и контакты оператора'), 350);
      expect(find.text('Документы и контакты оператора').hitTestable(),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient(
            (_) async => throw http.ClientException('offline fixture')));
  });
}
