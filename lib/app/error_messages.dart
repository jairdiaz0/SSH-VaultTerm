import 'package:flutter/widgets.dart';

import '../core/errors/app_exception.dart';
import '../features/profiles/domain/profile_rules.dart';
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
    AppErrorCode.hostKeyRejected => l10n.errorHostKeyRejected,
    AppErrorCode.hostKeyChanged => l10n.errorHostKeyChanged,
    AppErrorCode.authFailed => l10n.errorAuthFailed,
    AppErrorCode.networkUnreachable => l10n.errorNetworkUnreachable,
    AppErrorCode.connectionTimeout => l10n.errorConnectionTimeout,
    AppErrorCode.connectionFailed => l10n.errorConnectionFailed,
    AppErrorCode.connectionLost => l10n.errorConnectionLost,
    AppErrorCode.credentialMissing => l10n.errorCredentialMissing,
    AppErrorCode.privateKeyInvalid => l10n.errorPrivateKeyInvalid,
    AppErrorCode.privateKeyPassphraseRequired =>
      l10n.errorPrivateKeyPassphraseRequired,
    AppErrorCode.privateKeyPassphraseInvalid =>
      l10n.errorPrivateKeyPassphraseInvalid,
    AppErrorCode.databaseKeyMismatch => l10n.errorDatabaseKeyMismatch,
    AppErrorCode.databaseKeyOrphan => l10n.errorDatabaseKeyOrphan,
    AppErrorCode.privateKeyUnsupportedFormat =>
      l10n.errorPrivateKeyUnsupportedFormat,
    AppErrorCode.sftpPermissionDenied => l10n.errorSftpPermissionDenied,
    AppErrorCode.sftpNotFound => l10n.errorSftpNotFound,
    AppErrorCode.sftpFailure => l10n.errorSftpFailure,
    AppErrorCode.transferCancelled => l10n.errorTransferCancelled,
    AppErrorCode.transferFailed => l10n.errorTransferFailed,
    AppErrorCode.backupInvalid => l10n.errorBackupInvalid,
    AppErrorCode.backupVersionUnsupported => l10n.errorBackupVersionUnsupported,
    AppErrorCode.backupReadFailed => l10n.errorBackupReadFailed,
    AppErrorCode.backupWriteFailed => l10n.errorBackupWriteFailed,
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
int get profilePasswordMinLength => ProfileRules.minPasswordLength;

/// Builds a localized title for the app itself.
String appTitleOf(BuildContext context) =>
    AppLocalizations.of(context).appTitle;
