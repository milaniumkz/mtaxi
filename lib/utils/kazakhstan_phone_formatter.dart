import 'package:flutter/services.dart';

class KazakhstanPhoneFormatter extends TextInputFormatter {
  const KazakhstanPhoneFormatter();
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (!newValue.composing.isCollapsed) return newValue;
    // A browser may deliver deletion before its selection update. Deleting
    // everything must clear the old number even if the cached caret collapsed.
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
          text: '+7', selection: TextSelection.collapsed(offset: 2));
    }
    if (oldValue.text.startsWith('+7') &&
        oldValue.selection.isCollapsed &&
        newValue.text.length < oldValue.text.length &&
        newValue.selection.extentOffset >= 0 &&
        newValue.selection.extentOffset < 2) {
      return oldValue.copyWith(
          selection: const TextSelection.collapsed(offset: 2),
          composing: TextRange.empty);
    }
    final prefixed = newValue.text.startsWith('+7');
    var digits = (prefixed ? newValue.text.substring(2) : newValue.text)
        .replaceAll(RegExp(r'\D'), '');
    final pasted = newValue.text.length - oldValue.text.length > 1;
    if (digits.length > 10 &&
        (!prefixed || pasted) &&
        (digits.startsWith('7') || digits.startsWith('8')))
      digits = digits.substring(1);
    if (digits.length > 10) digits = digits.substring(0, 10);
    final text = '+7$digits';
    final cursor = text == newValue.text && newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(2, text.length).toInt()
        : text.length;
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: cursor));
  }
}
