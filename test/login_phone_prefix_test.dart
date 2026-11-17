import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtaxi/auth/login/login_widget.dart';
import 'design_flow_test.dart' show wrap;

void main() {
  testWidgets(
      'login and registration keep +7 through thirty edits and pasted formats',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap(const LoginWidget()));
    await tester.pump();
    final finder = find.byKey(const ValueKey('login-phone'));
    TextFormField field() => tester.widget<TextFormField>(finder);
    expect(field().controller!.text, '+7');
    for (var i = 0; i < 30; i++) {
      for (final pasted in [
        '7012345678',
        '+7 (701) 234-56-78',
        '8 (701) 234-56-78',
        '77012345678'
      ]) {
        await tester.enterText(finder, pasted);
        expect(field().controller!.text, '+77012345678');
      }
      await tester.enterText(finder, '');
      expect(field().controller!.text, '+7');
      await tester.enterText(finder, '7012345678');
      expect(field().controller!.text, '+77012345678');
    }
    await tester.ensureVisible(find.text('Создать аккаунт'));
    await tester.tap(find.text('Создать аккаунт'));
    await tester.pump();
    expect(field().controller!.text, '+77012345678');
    await tester.enterText(finder, '');
    expect(field().controller!.text, '+7');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
