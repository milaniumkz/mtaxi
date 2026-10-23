import 'package:flutter/material.dart';

import '/admin/admin_utils.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';

const _mtaxiPageBg = Color(0xFFF4F7F8);
const _mtaxiSurface = Color(0xFFFFFFFF);
const _mtaxiMint = Color(0xFF126E68);

class AdminNotificationsWidget extends StatefulWidget {
  const AdminNotificationsWidget({super.key});

  static String routeName = 'adminNotifications';
  static String routePath = '/admin/notifications';

  @override
  State<AdminNotificationsWidget> createState() =>
      _AdminNotificationsWidgetState();
}

class _AdminNotificationsWidgetState extends State<AdminNotificationsWidget> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imageUrlController = TextEditingController();
  String _targetRole = 'all';
  String _targetAudience = 'All';
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  String _roleLabel(String value) {
    switch (value) {
      case 'drivers':
        return 'Все водители';
      case 'passengers':
        return 'Все пассажиры';
      default:
        return 'Все пассажиры и водители';
    }
  }

  String _audienceLabel(String value) {
    switch (value) {
      case 'Android':
        return 'Android';
      case 'iOS':
        return 'iPhone';
      default:
        return 'Все устройства';
    }
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status.trim().toLowerCase()) {
      case 'succeeded':
        return const Color(0xFF2E7D32);
      case 'partial':
        return const Color(0xFFEF6C00);
      case 'failed':
        return Colors.red.shade700;
      case 'started':
        return FlutterFlowTheme.of(context).primary;
      default:
        return FlutterFlowTheme.of(context).secondaryText;
    }
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'succeeded':
        return 'Готово';
      case 'partial':
        return 'Частично';
      case 'failed':
        return 'Ошибка';
      case 'started':
        return 'В обработке';
      default:
        return status.isEmpty ? 'Ожидание' : status;
    }
  }

  Future<void> _sendBroadcast() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final imageUrl = _imageUrlController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните заголовок и текст уведомления'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final response = await makeCloudCall(
        'adminQueueBroadcast',
        {
          'title': title,
          'body': body,
          'targetRole': _targetRole,
          'targetAudience': _targetAudience,
          'imageUrl': imageUrl,
        },
      );
      final success = response['success'] == true;
      if (!mounted) return;
      if (!success) {
        final error = (response['error'] ?? '').toString().trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.isNotEmpty
                  ? error
                  : 'Не удалось поставить рассылку в очередь',
            ),
          ),
        );
        return;
      }

      _titleController.clear();
      _bodyController.clear();
      _imageUrlController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Рассылка запущена: ${_roleLabel(_targetRole)}, ${_audienceLabel(_targetAudience)}. Текст уйдет в push и в чат поддержки.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _mtaxiSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = isAdminUser(currentUserDocument);
    return Scaffold(
      backgroundColor: _mtaxiPageBg,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF12051B),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Назад',
          color: Colors.white,
          onPressed: () => context.goNamed(AdminHomeWidget.routeName),
        ),
        title: Text(
          'Рассылка уведомлений',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                color: Colors.white,
                font: TextStyle(
                  fontFamily: 'Noto Sans',
                  fontWeight: FontWeight.w600,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
                letterSpacing: 0.0,
                fontWeight: FontWeight.w600,
                fontStyle:
                    FlutterFlowTheme.of(context).headlineMedium.fontStyle,
              ),
        ),
      ),
      body: SafeArea(
        child: !isAdmin
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Доступ только для администратора',
                    style: FlutterFlowTheme.of(context).bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionCard(
                    context: context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Новая рассылка',
                          style:
                              FlutterFlowTheme.of(context).bodyLarge.override(
                                    font: TextStyle(
                                      fontFamily: 'Noto Sans',
                                      fontWeight: FontWeight.w700,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyLarge
                                        .fontStyle,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Отправляет push и сразу дублирует такой же текст в чат поддержки от имени админа.',
                          style: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                font: TextStyle(
                                  fontFamily: 'Noto Sans',
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontStyle,
                              ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _targetRole,
                          decoration: const InputDecoration(
                            labelText: 'Кому',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('Все пассажиры и водители'),
                            ),
                            DropdownMenuItem(
                              value: 'passengers',
                              child: Text('Все пассажиры'),
                            ),
                            DropdownMenuItem(
                              value: 'drivers',
                              child: Text('Все водители'),
                            ),
                          ],
                          onChanged: _sending
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _targetRole = value);
                                },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _targetAudience,
                          decoration: const InputDecoration(
                            labelText: 'Устройства',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'All',
                              child: Text('Все устройства'),
                            ),
                            DropdownMenuItem(
                              value: 'Android',
                              child: Text('Android'),
                            ),
                            DropdownMenuItem(
                              value: 'iOS',
                              child: Text('iPhone'),
                            ),
                          ],
                          onChanged: _sending
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _targetAudience = value);
                                },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleController,
                          enabled: !_sending,
                          decoration: const InputDecoration(
                            labelText: 'Заголовок',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _bodyController,
                          enabled: !_sending,
                          minLines: 4,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Текст уведомления',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _imageUrlController,
                          enabled: !_sending,
                          decoration: const InputDecoration(
                            labelText: 'Ссылка на изображение (необязательно)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FFButtonWidget(
                          onPressed: _sending ? null : _sendBroadcast,
                          text:
                              _sending ? 'Отправляем...' : 'Запустить рассылку',
                          options: FFButtonOptions(
                            width: double.infinity,
                            height: 44,
                            color: _mtaxiMint,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: TextStyle(
                                    fontFamily: 'Noto Sans',
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                            elevation: 0,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Последние рассылки',
                    style: FlutterFlowTheme.of(context).bodyLarge.override(
                          font: TextStyle(
                            fontFamily: 'Noto Sans',
                            fontWeight: FontWeight.w700,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyLarge
                                .fontStyle,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w700,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                        ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, dynamic>>(
                    future: makeCloudCall(
                      'adminListPushNotifications',
                      {'limit': 20},
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final rows =
                          (snapshot.data?['notifications'] as List? ?? const [])
                              .whereType<Map>()
                              .map((item) => Map<String, dynamic>.from(item))
                              .toList();
                      return _buildNotificationsList(rows);
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildNotificationsList(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return _buildSectionCard(
        context: context,
        child: const Text('Рассылок пока нет'),
      );
    }

    return Column(
      children: rows.map(_buildNotificationCard).toList(),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data) {
    final createdAt = _asDateTime(data['created_at']);
    final status = (data['status'] ?? '').toString();
    final targetRole = (data['target_role'] ?? 'all').toString();
    final targetAudience = (data['target_audience'] ?? 'All').toString();
    final error = (data['error'] ?? '').toString().trim();
    final sentText = _numberText(data['num_sent']);
    final failedText = _numberText(data['num_failed']);
    final chatText = _numberText(data['num_chat_messages']);
    final usersText = _numberText(data['num_target_users']);
    final tokensText = _numberText(data['num_target_tokens']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _buildSectionCard(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (data['notification_title'] ?? '').toString(),
                    style: FlutterFlowTheme.of(context).bodyLarge.override(
                          font: TextStyle(
                            fontFamily: 'Noto Sans',
                            fontWeight: FontWeight.w700,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyLarge
                                .fontStyle,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w700,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _statusColor(context, status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: TextStyle(
                            fontFamily: 'Noto Sans',
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodySmall
                                .fontStyle,
                          ),
                          color: _statusColor(context, status),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              (data['notification_text'] ?? '').toString(),
              style: FlutterFlowTheme.of(context).bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaChip(context, Icons.groups, _roleLabel(targetRole)),
                _buildMetaChip(
                  context,
                  Icons.phone_android,
                  _audienceLabel(targetAudience),
                ),
                _buildMetaChip(context, Icons.groups, 'Получатели: $usersText'),
                _buildMetaChip(
                  context,
                  Icons.notifications_active,
                  'Push: $sentText',
                ),
                _buildMetaChip(
                  context,
                  Icons.error_outline,
                  'Push ошибки: $failedText',
                ),
                _buildMetaChip(
                  context,
                  Icons.chat_bubble_outline,
                  'В чат: $chatText',
                ),
                _buildMetaChip(
                  context,
                  Icons.phone_android,
                  'Токены: $tokensText',
                ),
                if (createdAt != null)
                  _buildMetaChip(
                    context,
                    Icons.schedule,
                    dateTimeFormat(
                      'd.MM HH:mm',
                      createdAt,
                      locale: FFLocalizations.of(context).languageCode,
                    ),
                  ),
              ],
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                error,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: TextStyle(
                        fontFamily: 'Noto Sans',
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                      color: Colors.red.shade700,
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).bodySmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _numberText(dynamic value) {
    if (value is num) return value.toString();
    return int.tryParse(value?.toString() ?? '')?.toString() ?? '0';
  }

  Widget _buildMetaChip(
    BuildContext context,
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _mtaxiPageBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: FlutterFlowTheme.of(context).secondaryText,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: FlutterFlowTheme.of(context).bodySmall,
          ),
        ],
      ),
    );
  }
}
