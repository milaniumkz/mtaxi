import '/flutter_flow/internationalization.dart';
import 'package:flutter/material.dart';

/// Approved MTaxi light palette. Dark mode keeps semantic, readable surfaces.
abstract final class MTaxiDesign {
  static const ink = Color(0xFF1B242B);
  static const canvas = Color(0xFFFCFCFA);
  static const gold = Color(0xFFE6BD63);
  static const teal = Color(0xFF188B83);
  static const surface = Color(0xFFF0F3EC);
  static const border = Color(0xFFE8EBE5);
  static const muted = Color(0xFF5C6862);
  static const font = 'Noto Sans';

  static ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: brightness,
      primary: gold,
      onPrimary: ink,
      secondary: dark ? const Color(0xFF75D1C7) : const Color(0xFF126E68),
      surface: dark ? const Color(0xFF202A30) : canvas,
      onSurface: dark ? Colors.white : ink,
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFF993F32),
    );
    final base = ThemeData(
      useMaterial3: false,
      brightness: brightness,
      fontFamily: font,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      disabledColor: dark ? Colors.white38 : const Color(0xFF737B76),
      visualDensity: VisualDensity.standard,
    );
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    return base.copyWith(
      textTheme: base.textTheme
          .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontFamily: font,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF2C383D) : surface,
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
            borderSide: const BorderSide(color: teal, width: 2)),
        errorBorder:
            outline.copyWith(borderSide: BorderSide(color: scheme.error)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        labelStyle:
            TextStyle(color: dark ? Colors.white70 : muted, fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: ink,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(
            fontFamily: font, fontWeight: FontWeight.w700, fontSize: 14),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(48, 48),
      )),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
      checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? teal : null)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: teal),
      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(
            fontFamily: font, fontSize: 14, color: Colors.white),
      ),
      dividerTheme: DividerThemeData(color: dark ? Colors.white12 : border),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: scheme.surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
    );
  }
}

class MTaxiBrand extends StatelessWidget {
  const MTaxiBrand({super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
        Image.asset('assets/design/logo.png',
            width: 48, height: 48, semanticLabel: 'MTaxi'),
        const SizedBox(width: 12),
        const Text('MTaxi',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
      ]);
}

class MTaxiCard extends StatelessWidget {
  const MTaxiCard(
      {super.key,
      required this.child,
      this.color,
      this.padding = const EdgeInsets.all(17)});
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ??
              (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF202A30)
                  : Colors.white),
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
}

class MTaxiFeedback extends StatelessWidget {
  const MTaxiFeedback(
      {super.key,
      required this.title,
      required this.message,
      this.onRetry,
      this.loading = false,
      this.icon = Icons.info_outline});
  final String title, message;
  final VoidCallback? onRetry;
  final bool loading;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (loading)
            const CircularProgressIndicator()
          else
            Icon(icon,
                size: 40, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 20),
          Semantics(
              liveRegion: true,
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700))),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            FilledButton(
                onPressed: onRetry,
                child: Text(FFLocalizations.of(context)
                    .getVariableText(ruText: 'Повторить', kkText: 'Қайталау')))
          ],
        ]),
      ));
}

class MTaxiUploadError extends StatelessWidget {
  const MTaxiUploadError(
      {super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l10n = FFLocalizations.of(context);
    return Semantics(
        liveRegion: true,
        child: MTaxiCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Icon(Icons.file_upload_outlined,
                  color: Theme.of(context).colorScheme.error, size: 32),
              const SizedBox(height: 12),
              Text(
                  l10n.getVariableText(
                      ruText: 'Проверьте фото', kkText: 'Фотоны тексеріңіз'),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(message),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: onRetry,
                  child: Text(l10n.getVariableText(
                      ruText: 'Повторить загрузку', kkText: 'Қайта жүктеу'))),
            ])));
  }
}
