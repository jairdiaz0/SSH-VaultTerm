import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Filesystem layout of the app's private data. Every path here is local and
/// app-owned; remote paths never use this.
class AppPaths {
  AppPaths(this.root);

  /// `<application support>/ssh_client` in production.
  final String root;

  static const appFolderName = 'ssh_client';

  /// Overrides [root] completely. Integration tests and development runs use it
  /// so they never touch the real profile data.
  static const dataDirEnvironment = 'SSH_CLIENT_DATA_DIR';

  static Future<AppPaths> resolve() => resolveFrom(
    environment: Platform.environment,
    applicationSupport: () async => getApplicationSupportDirectory(),
  );

  /// Same as [resolve] with injected environment and platform directory, so the
  /// override can be tested without mutating real process environment.
  static Future<AppPaths> resolveFrom({
    bool? isWindows,
    required Map<String, String> environment,
    required Future<Directory> Function() applicationSupport,
  }) async {
    final override = environment[dataDirEnvironment]?.trim();
    if (override != null && override.isNotEmpty) {
      return AppPaths(p.normalize(p.absolute(override)));
    }
    // Windows: LOCALAPPDATA, not Roaming. A roaming folder would be synced to
    // another machine without the keys stored in Credential Manager.
    final windows = isWindows ?? Platform.isWindows;
    final localAppData = environment['LOCALAPPDATA']?.trim();
    if (windows && localAppData != null && localAppData.isNotEmpty) {
      return AppPaths(p.join(localAppData, 'dev.sshclient', appFolderName));
    }
    final base = await applicationSupport();
    return AppPaths(p.join(base.path, appFolderName));
  }

  /// Old Windows location (Roaming). Never opened; only reported by the
  /// storage status so the user can reset deliberately.
  static String? legacyWindowsRoot(Map<String, String> environment) {
    final roaming = environment['APPDATA']?.trim();
    if (roaming == null || roaming.isEmpty) return null;
    return p.join(roaming, 'dev.sshclient', appFolderName);
  }

  String get catalogDatabase => p.join(root, 'catalog.db');

  /// Temporary builds during import. Never opened by the app at startup.
  String get stagingRoot => p.join(root, 'staging');

  /// Pre-swap copies of databases and keys during import.
  String get backupRoot => p.join(root, 'backup');

  /// Created by a reset when the catalog cannot be deleted while open; the
  /// next startup removes the catalog before opening it.
  String get resetMarker => p.join(root, 'reset.pending');

  String profileDirectory(String profileId) =>
      p.join(root, 'profiles', profileId);

  String profileDatabase(String profileId) =>
      p.join(profileDirectory(profileId), 'data.db');

  /// Creates the directories needed before opening any database.
  void ensureCreated() {
    Directory(root).createSync(recursive: true);
    Directory(p.join(root, 'profiles')).createSync(recursive: true);
  }

  void ensureProfileDirectory(String profileId) {
    Directory(profileDirectory(profileId)).createSync(recursive: true);
  }

  bool profileDirectoryExists(String profileId) =>
      Directory(profileDirectory(profileId)).existsSync();

  /// Deletes the profile database files (main + WAL/SHM) after its secrets have
  /// been removed. Best effort: a failure leaves files that no key can read.
  void deleteProfileFiles(String profileId) {
    final dir = Directory(profileDirectory(profileId));
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }
}
