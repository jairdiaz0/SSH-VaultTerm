import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';
import 'app_services.dart';
import 'localizations.dart';
import 'session_controller.dart';
import 'session_gate.dart';
import 'theme/app_theme.dart';

/// Root widget. Holds the session controller for the app's lifetime and
/// rebuilds the gate whenever the locked/unlocked state changes.
class SshClientApp extends StatefulWidget {
  const SshClientApp({super.key, required this.services});

  final AppServices services;

  @override
  State<SshClientApp> createState() => _SshClientAppState();
}

class _SshClientAppState extends State<SshClientApp> {
  late final SessionController _controller = SessionController(
    services: widget.services,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: const Locale('es'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SessionGate(controller: _controller),
    );
  }
}
