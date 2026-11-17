import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:upgrader/upgrader.dart';

import '/backend/app_settings/app_settings.dart';
import '/flutter_flow/flutter_flow_util.dart';

const _mtaxiMint = Color(0xFF126E68);
const _mtaxiMuted = Color(0xFF5C6862);

class ForceUpdateGate extends StatefulWidget {
  const ForceUpdateGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _forceRequired = false;
  bool _showSoftPrompt = false;

  final Upgrader _storeChecker =
      Upgrader(debugLogging: false, countryCode: 'KZ', languageCode: 'ru');
  String _resolvedStoreUrl = '';
  DateTime? _storeCheckedAt;
  bool _storeHasUpdate = false;
  String _currentVersion = '';
  int _currentBuild = 0;
  AppVersionPolicy _policy = const AppVersionPolicy();

  int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final maxLen =
        aParts.length > bParts.length ? aParts.length : bParts.length;
    while (aParts.length < maxLen) {
      aParts.add(0);
    }
    while (bParts.length < maxLen) {
      bParts.add(0);
    }
    for (var i = 0; i < maxLen; i++) {
      if (aParts[i] == bParts[i]) {
        continue;
      }
      return aParts[i] < bParts[i] ? -1 : 1;
    }
    return 0;
  }

  Future<void> _openStore() async {
    final uri = Uri.tryParse(_resolvedStoreUrl);
    if (uri == null) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
        throw StateError('Store unavailable');
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Не удалось открыть магазин. Проверьте подключение и повторите.')));
    }
  }

  Future<void> _checkVersion() async {
    if (_checking || kIsWeb || !(isAndroid || isiOS)) {
      return;
    }
    _checking = true;
    try {
      await primeAppRuntimeSettings();
      final packageInfo = await PackageInfo.fromPlatform();
      final policy = currentAppVersionPolicy;
      final currentVersion = packageInfo.version.trim();
      final currentBuild = int.tryParse(packageInfo.buildNumber.trim()) ?? 0;
      if (_storeCheckedAt == null ||
          DateTime.now().difference(_storeCheckedAt!) >=
              const Duration(minutes: 15)) {
        try {
          await _storeChecker.initialize().timeout(const Duration(seconds: 8));
          if (_storeCheckedAt != null)
            await _storeChecker
                .updateVersionInfo()
                .timeout(const Duration(seconds: 8));
          _storeHasUpdate = _storeChecker.isUpdateAvailable();
          _storeCheckedAt = DateTime.now();
        } catch (_) {/* Store lookup errors are not evidence of an update. */}
      }
      String validStore(String raw) {
        final u = Uri.tryParse(raw.trim());
        if (u?.scheme != 'https') return '';
        return isAndroid && u!.host == 'play.google.com' ||
                isiOS && u!.host == 'apps.apple.com'
            ? u.toString()
            : '';
      }

      final detectedStore =
          validStore(_storeChecker.versionInfo?.appStoreListingURL ?? '');
      final storeUrl = detectedStore.isNotEmpty
          ? detectedStore
          : validStore(policy.storeUrl);
      final forceRequired = policy.forceUpdateEnabled &&
          ((policy.minSupportedBuildNumber > 0 &&
                  currentBuild < policy.minSupportedBuildNumber) ||
              (policy.minSupportedVersion.isNotEmpty &&
                  _compareVersions(currentVersion, policy.minSupportedVersion) <
                      0));
      final mandatoryUpdate =
          storeUrl.isNotEmpty && (forceRequired || _storeHasUpdate);
      if (!mounted) {
        return;
      }
      setState(() {
        _policy = policy;
        _currentVersion = currentVersion;
        _currentBuild = currentBuild;
        _resolvedStoreUrl = storeUrl;
        _forceRequired = mandatoryUpdate;
        _showSoftPrompt = false;
      });
    } catch (_) {
      // Keep app usable if settings are temporarily unavailable.
    } finally {
      _checking = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVersion());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVersion();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _buildUpdateCard({
    required bool blocking,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : const Color(0xFF1B242B);
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8EBE5);
    final updateMessage = _policy.updateMessage.isNotEmpty
        ? _policy.updateMessage
        : blocking
            ? FFLocalizations.of(context).getVariableText(
                ruText:
                    'Вышла новая версия приложения. Для продолжения обновите приложение.',
                kkText:
                    'Қолданбаның жаңа нұсқасы шықты. Жалғастыру үшін қолданбаны жаңартыңыз.',
              )
            : FFLocalizations.of(context).getVariableText(
                ruText:
                    'Доступна новая версия приложения. Рекомендуется обновиться.',
                kkText:
                    'Қолданбаның жаңа нұсқасы қолжетімді. Жаңарту ұсынылады.',
              );
    final targetLabel = _policy.latestVersion.isNotEmpty
        ? '${_policy.latestVersion} (${_policy.latestBuildNumber})'
        : _policy.minSupportedVersion.isNotEmpty
            ? '${_policy.minSupportedVersion} (${_policy.minSupportedBuildNumber})'
            : '';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        margin: const EdgeInsets.all(24),
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                blocking
                    ? FFLocalizations.of(context).getVariableText(
                        ruText: 'Требуется обновление',
                        kkText: 'Жаңарту қажет',
                      )
                    : FFLocalizations.of(context).getVariableText(
                        ruText: 'Доступно обновление',
                        kkText: 'Жаңарту қолжетімді',
                      ),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                updateMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: mutedColor),
              ),
              const SizedBox(height: 12),
              Text(
                '$_currentVersion ($_currentBuild) → $targetLabel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!blocking)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showSoftPrompt = false;
                        });
                      },
                      child: Text(
                        FFLocalizations.of(context).getVariableText(
                          ruText: 'Позже',
                          kkText: 'Кейін',
                        ),
                        style: TextStyle(color: mutedColor),
                      ),
                    ),
                  if (!blocking) const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mtaxiMint,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _openStore,
                    child: Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: 'Обновить',
                        kkText: 'Жаңарту',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !(isAndroid || isiOS)) {
      return widget.child;
    }

    if (_forceRequired) {
      return PopScope(
          canPop: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.72),
                child: Center(
                  child: _buildUpdateCard(
                    blocking: true,
                    context: context,
                  ),
                ),
              ),
            ],
          ));
    }

    if (_showSoftPrompt) {
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          IgnorePointer(
            ignoring: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: _buildUpdateCard(
                  blocking: false,
                  context: context,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return widget.child;
  }
}
