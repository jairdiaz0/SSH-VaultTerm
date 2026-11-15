import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../core/storage/app_reset_service.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_runtime.dart';
import 'app_services.dart';
import 'localizations.dart';
import 'session_controller.dart';
import 'session_gate.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

/// Root widget. Holds the session controller for the app's lifetime and can
/// rebuild the whole service graph after a full reset.
class SshClientApp extends StatefulWidget {
  const SshClientApp({
    super.key,
    required this.services,
    this.themeController,
    this.rebuildServices,
  });

  final AppServices services;

  /// Appearance preference loaded before the first frame. Tests may omit it.
  final ThemeController? themeController;

  /// Builds a fresh service graph after the application has been reset. When
  /// absent (unit/widget tests) the reset action is not offered.
  final Future<AppServices> Function()? rebuildServices;

  @override
  State<SshClientApp> createState() => _SshClientAppState();
}

class _SshClientAppState extends State<SshClientApp> {
  late AppServices _services = widget.services;
  late SessionController _controller = SessionController(services: _services);
  bool _resetting = false;

  late final ThemeController _theme =
      widget.themeController ?? ThemeController.memory();

  @override
  void dispose() {
    _controller.dispose();
    _services.dispose();
    super.dispose();
  }

  Future<void> _resetApplication() async {
    final rebuild = widget.rebuildServices;
    if (rebuild == null) {
      throw StateError('reset is not available without a services factory');
    }
    final paths = _services.paths;
    final keys = _services.keys;
    // Replace the tree first: no widget may touch the databases while they are
    // being closed and deleted.
    setState(() => _resetting = true);
    await WidgetsBinding.instance.endOfFrame;
    _controller.dispose();
    _services.dispose();
    await AppResetService(
      paths: paths,
      keys: keys,
      environment: Platform.environment,
    ).reset();
    await _theme.resetPreferences();
    final fresh = await rebuild();
    if (!mounted) {
      fresh.dispose();
      return;
    }
    setState(() {
      _services = fresh;
      _controller = SessionController(services: fresh);
      _resetting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canReset = widget.rebuildServices != null;
    if (_resetting) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return AppThemeScope(
      controller: _theme,
      child: AppRuntime(
        resetApplication: canReset
            ? _resetApplication
            : () async => throw StateError('reset unavailable'),
        child: ListenableBuilder(
          listenable: _theme,
          builder: (context, _) => MaterialApp(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(
              alwaysDarkTerminal: _theme.alwaysDarkTerminal,
            ),
            darkTheme: AppTheme.dark(
              alwaysDarkTerminal: _theme.alwaysDarkTerminal,
            ),
            themeMode: _theme.mode,
            themeAnimationDuration: const Duration(milliseconds: 220),
            themeAnimationCurve: Curves.easeOutCubic,
            builder: (context, child) =>
                SafeArea(child: child ?? const SizedBox.shrink()),
            locale: const Locale('es'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SessionGate(controller: _controller),
          ),
        ),
      ),
    );
  }
}
