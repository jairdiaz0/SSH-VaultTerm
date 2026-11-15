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

  static Future<AppPaths> resolve() async {
    final base = await getApplicationSupportDirectory();
    return AppPaths(p.join(base.path, appFolderName));
  }

  String get catalogDatabase => p.join(root, 'catalog.db');

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
