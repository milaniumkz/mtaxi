import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/backend_session.dart' show mtaxiBackendBaseUrl;

/// A bundled copy keeps the published terms readable without network access.
class LegalDocumentsView extends StatefulWidget {
  const LegalDocumentsView({super.key});
  @override
  State<LegalDocumentsView> createState() => _LegalDocumentsViewState();
}

class _LegalDocumentsViewState extends State<LegalDocumentsView> {
  late final Future<Map<String, dynamic>> _documents = rootBundle
      .loadString('assets/jsons/legal_documents.json')
      .then((text) => Map<String, dynamic>.from(jsonDecode(text) as Map));

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _documents,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Не удалось загрузить документы.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final operator = data['operator'] as Map;
          final documents = data['documents'] as List;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Правовая информация',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Редакция ${data['version']} · ${operator['name']}'),
              const SizedBox(height: 8),
              const Text('Откройте документ для чтения. Копии также доступны '
                  'на сайте без входа в аккаунт.'),
              const SizedBox(height: 16),
              for (final raw in documents)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text((raw as Map)['title'].toString()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => _LegalDocumentPage(
                      document: Map<String, dynamic>.from(raw),
                      version: data['version'].toString(),
                      operator: Map<String, dynamic>.from(operator),
                    ),
                  )),
                ),
              const Divider(),
              SelectableText('${operator['name']} · ИИН ${operator['iin']}\n'
                  '${operator['address']}\n'
                  '${operator['email']}\n${operator['phone']}'),
            ],
          );
        },
      );
}

class _LegalDocumentPage extends StatelessWidget {
  const _LegalDocumentPage({
    required this.document,
    required this.version,
    required this.operator,
  });
  final Map<String, dynamic> document, operator;
  final String version;

  Future<void> _openPublicCopy(BuildContext context) async {
    final configured = Uri.tryParse(mtaxiBackendBaseUrl);
    final base = configured?.scheme == 'https'
        ? configured!
        : Uri.parse('https://mtaxi.89.126.192.185.sslip.io');
    final url = base.resolve('/legal/${document['id']}.html');
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // The bundled document remains available if the OS cannot open a browser.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть браузер.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(document['title'].toString())),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text('Редакция $version'),
            TextButton.icon(
              onPressed: () => _openPublicCopy(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Открыть публичную копию на сайте'),
            ),
            for (final raw in document['sections'] as List) ...[
              const SizedBox(height: 18),
              Text((raw as Map)['title'].toString(),
                  style: Theme.of(context).textTheme.titleMedium),
              for (final paragraph in raw['paragraphs'] as List)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SelectableText(paragraph.toString(),
                      style: const TextStyle(height: 1.5)),
                ),
            ],
            const SizedBox(height: 24),
            SelectableText('${operator['name']} · ${operator['email']} · '
                '${operator['phone']}'),
          ]),
        ),
      );
}
