import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtaxi/backend/uploads/mtaxi_network_image.dart';

void main() {
  testWidgets('private media displays loading and authenticated bytes',
      (tester) async {
    final image = Completer<Uint8List>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: MTaxiNetworkImage('https://example.test/uploads/1_abc.png',
            privateLoader: (_) {
      calls++;
      return image.future;
    })));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    image.complete(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII='));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    await tester.pump();
    expect(calls, 1);
  });
  testWidgets('denied private media uses visible error fallback',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MTaxiNetworkImage('https://example.test/uploads/1_abc.png',
            privateLoader: (_) => Future.error(StateError('forbidden')),
            errorBuilder: (_, __, ___) => const Text('Нет доступа'))));
    await tester.pump();
    expect(find.text('Нет доступа'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
