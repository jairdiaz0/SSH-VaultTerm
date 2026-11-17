import 'package:path/path.dart' as p;

/// Location of the DPAPI file `flutter_secure_storage_windows` uses to keep the
/// app's keys.
///
/// It lives in the app-support folder (Roaming on Windows), not in
/// Credential Manager and not next to the LOCALAPPDATA databases. Deleting this
/// file removes every key of the app, so it is part of a full reset.
///
/// Kept as a pure function so the path can be asserted in tests: a wrongly
/// escaped path here once made the reset fail silently.
String? windowsSecretStoreFile(Map<String, String> environment) {
  final roaming = environment['APPDATA']?.trim();
  if (roaming == null || roaming.isEmpty) return null;
  return p.join(
    roaming,
    'dev.sshclient',
    'ssh_client',
    'flutter_secure_storage.dat',
  );
}
