import 'package:flutter/widgets.dart';

import '../core/errors/app_exception.dart';
import '../features/profiles/data/profile_service.dart';
import '../l10n/generated/app_localizations.dart';

/// Maps a domain error to a localized, secret-free message.
///
/// Unknown errors collapse into a generic message on purpose: internal details
/// (SQL text, driver messages, PEM fragments) must never reach the screen.
String describeAppError(
  AppLocalizations l10n,
  Object error, {
  Duration lockoutRemaining = Duration.zero,
}) {
  final code = error is AppException ? error.code : AppErrorCode.unknown;
  return switch (code) {
    AppErrorCode.invalidCredentials => l10n.errorInvalidCredentials,
    AppErrorCode.accountLocked => l10n.errorAccountLocked(
      _seconds(lockoutRemaining),
    ),
    AppErrorCode.secureStorageUnavailable => l10n.errorSecureStorageUnavailable,
    AppErrorCode.databaseFailure ||
    AppErrorCode.databaseKeyMissing ||
    AppErrorCode.databaseKeyInvalid ||
    AppErrorCode.schemaTooNew => l10n.errorDatabaseFailure,
    AppErrorCode.validation => l10n.errorValidation,
    AppErrorCode.conflict => l10n.errorConflict,
    AppErrorCode.notFound ||
    AppErrorCode.secretNotFound ||
    AppErrorCode.unsupported ||
    AppErrorCode.unknown => l10n.errorUnknown,
  };
}

int _seconds(Duration remaining) {
  final seconds = remaining.inSeconds;
  if (remaining > Duration.zero && seconds < 1) return 1;
  return seconds;
}

/// Shortcut for the shared minimum profile password length.
int get profilePasswordMinLength => ProfileService.minPasswordLength;

/// Builds a localized title for the app itself.
String appTitleOf(BuildContext context) =>
    AppLocalizations.of(context).appTitle;
