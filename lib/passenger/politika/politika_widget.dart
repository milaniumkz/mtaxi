import 'package:flutter/material.dart';
import '/design/legal_documents_view.dart';
export 'politika_model.dart';

class PolitikaWidget extends StatelessWidget {
  const PolitikaWidget({super.key});
  static String routeName = 'politika';
  static String routePath = '/politika';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Документы MTaxi')),
        body: const SafeArea(child: LegalDocumentsView()),
      );
}
