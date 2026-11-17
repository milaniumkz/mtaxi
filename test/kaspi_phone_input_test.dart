import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtaxi/component/select_balance/select_balance_widget.dart';
import 'design_flow_test.dart' show wrap;

void main() {
  testWidgets(
      'thirty full deletions and pastes never retain an old Kaspi number',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
        wrap(const Scaffold(body: SelectBalanceWidget(passenger: true))));
    await tester.pump();
    final formatter = tester
        .widget<TextField>(find.byType(TextField).first)
        .inputFormatters!
        .single;
    for (var i = 0; i < 30; i++) {
      final phone = '+7701${i.toString().padLeft(7, '0')}';
      final old = TextEditingValue(
          text: phone,
          selection: TextSelection.collapsed(offset: phone.length));
      final cleared = formatter.formatEditUpdate(old, TextEditingValue.empty);
      expect(cleared.text, '+7');
      expect(cleared.selection.extentOffset, 2);
      final pasted = formatter.formatEditUpdate(cleared,
          TextEditingValue(text: '8702${i.toString().padLeft(7, '0')}'));
      expect(pasted.text, '+7702${i.toString().padLeft(7, '0')}');
    }
    await tester.pumpWidget(const SizedBox());
  });
}
