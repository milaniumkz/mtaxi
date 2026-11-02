import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtaxi/design/legal_documents_view.dart';

void main() {
  testWidgets(
      'legal documents include operator and can be read without backend',
      (tester) async {
    final source = await tester.runAsync(
        () => rootBundle.loadString('assets/jsons/legal_documents.json'));
    final data = jsonDecode(source!) as Map;
    expect(data['operator']['email'], 'milaniumkz@yandex.kz');
    expect(
        (data['documents'] as List).map((d) => d['id']),
        containsAll([
          'privacy',
          'terms',
          'offer',
          'payments',
          'delete-account',
          'consent'
        ]));
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LegalDocumentsView())));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Политика конфиденциальности'));
    await tester.pumpAndSettle();
    expect(find.text('1. Оператор и область применения'), findsOneWidget);
    expect(find.textContaining('ИИН 970905350621'), findsWidgets);
    expect(find.text('Открыть публичную копию на сайте'), findsOneWidget);
  });
}
