import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../core/storage/app_reset_service.dart';
import '../core/storage/secure_storage_secret_store.dart';
import '../core/storage/windows_secret_store_path.dart';
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
    required this.rebuildServices,
    this.themeController,
  });

  final AppServices services;

  /// Appearance preference loaded before the first frame. Tests may omit it.
  final ThemeController? themeController;

  /// Builds a fresh service graph after the application has been reset.
  ///
  /// Required on purpose: when it was optional, the production entry point
  /// forgot to pass it and "Restablecer la aplicación" failed with the generic
  /// reset message while deleting nothing.
  final Future<AppServices> Function() rebuildServices;

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
    final paths = _services.paths;
    final keys = _services.keys;
    // Replace the tree first: no widget may touch the databases while they are
    // being closed and deleted.
    setState(() => _resetting = true);
    await WidgetsBinding.instance.endOfFrame;
    _controller.dispose();
    _services.dispose();
    final secrets = _services.secrets;
    final secureStorageFile =
        secrets is SecureStorageSecretStore && secrets.namespace.isEmpty
        ? _windowsSecureStorageFile()
        : null;
    await AppResetService(
      paths: paths,
      keys: keys,
      environment: Platform.environment,
    ).reset(extraFiles: [?secureStorageFile]);
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

  static String? _windowsSecureStorageFile() {
    if (!Platform.isWindows) return null;
    return windowsSecretStoreFile(Platform.environment);
  }

  @override
  Widget build(BuildContext context) {
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
        resetApplication: _resetApplication,
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
