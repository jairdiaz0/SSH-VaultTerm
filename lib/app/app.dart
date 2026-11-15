import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';
import 'app_services.dart';
import 'localizations.dart';
import 'session_controller.dart';
import 'session_gate.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

/// Root widget. Holds the session controller for the app's lifetime and
/// rebuilds the gate whenever the locked/unlocked state changes.
class SshClientApp extends StatefulWidget {
  const SshClientApp({super.key, required this.services, this.themeController});

  final AppServices services;

  /// Appearance preference loaded before the first frame. Tests may omit it.
  final ThemeController? themeController;

  @override
  State<SshClientApp> createState() => _SshClientAppState();
}

class _SshClientAppState extends State<SshClientApp> {
  late final SessionController _controller = SessionController(
    services: widget.services,
  );
  late final ThemeController _theme =
      widget.themeController ?? ThemeController.memory();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      controller: _theme,
      child: ListenableBuilder(
        listenable: _theme,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(alwaysDarkTerminal: _theme.alwaysDarkTerminal),
          darkTheme: AppTheme.dark(
            alwaysDarkTerminal: _theme.alwaysDarkTerminal,
          ),
          themeMode: _theme.mode,
          themeAnimationDuration: const Duration(milliseconds: 220),
          themeAnimationCurve: Curves.easeOutCubic,
          // Keeps content and dialogs clear of Android system insets.
          builder: (context, child) =>
              SafeArea(child: child ?? const SizedBox.shrink()),
          locale: const Locale('es'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SessionGate(controller: _controller),
        ),
      ),
    );
  }
}
