import 'package:flutter/material.dart';
import '/design/legal_documents_view.dart';
export 'politik_model.dart';

class PolitikWidget extends StatelessWidget {
  const PolitikWidget({super.key});

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(children: [
                const Expanded(child: Text('Документы MTaxi')),
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ]),
            ),
            const Expanded(child: LegalDocumentsView()),
          ]),
        ),
      );
}
