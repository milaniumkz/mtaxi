import 'package:flutter_test/flutter_test.dart';
import 'package:mtaxi/flutter_flow/custom_functions.dart' as functions;

void main() {
  test('generateUserId returns 5-digit string', () {
    final id = functions.generateUserId();
    expect(id.length, 5);
    expect(int.tryParse(id), isNotNull);
  });
}
