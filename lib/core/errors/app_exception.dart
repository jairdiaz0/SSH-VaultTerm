/// Domain error codes. The UI maps these to localized messages; no user-facing
/// string is ever built here, and no secret travels inside an exception.
enum AppErrorCode {
  invalidCredentials,
  accountLocked,
  secureStorageUnavailable,
  secretNotFound,
  databaseFailure,
  databaseKeyMissing,
  databaseKeyInvalid,
  schemaTooNew,
  notFound,
  conflict,
  validation,
  unsupported,
  unknown,
}

/// Base error for every failure the app deliberately models.
///
/// Deliberately keeps only the early [cause] type available through
/// [description]: stack traces and messages of lower layers can contain
/// secrets (a PEM, a password echoed by a driver), so they never reach logs or
/// the UI.
class AppException implements Exception {
  const AppException(this.code, {this.cause, this.stackTrace});

  final AppErrorCode code;
  final Object? cause;
  final StackTrace? stackTrace;

  /// Non-secret description safe for technical logs.
  String get description =>
      cause == null ? code.name : '${code.name} (${cause.runtimeType})';

  @override
  String toString() => 'AppException: $description';
}

/// Convenience throwers keep call sites short and consistent.
Never fail(AppErrorCode code, {Object? cause, StackTrace? stackTrace}) {
  throw AppException(code, cause: cause, stackTrace: stackTrace);
}
