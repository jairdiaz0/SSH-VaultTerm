import 'package:flutter/material.dart';

import '../core/errors/app_exception.dart';
import '../l10n/generated/app_localizations.dart';
import 'error_messages.dart';
import 'theme/app_theme.dart';

/// Shown when the app cannot even open its encrypted store (for example a
/// missing OS keyring). It never falls back to plaintext storage.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(
                          describeAppError(l10n, error),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Convenience for `main`: the startup failure surface for [AppErrorCode]s.
StartupFailureApp startupFailureFor(AppException error) =>
    StartupFailureApp(error: error);
