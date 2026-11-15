import 'dart:io';

import 'package:path/path.dart' as p;

import '../database/database_key_store.dart';
import '../database/encrypted_database.dart';
import '../database/schemas.dart';
import '../errors/app_exception.dart';
import '../storage/app_paths.dart';
import '../storage/secret_store.dart';

/// Result of inspecting the local storage, without revealing any secret.
class StorageStatus {
  const StorageStatus({
    required this.catalogExists,
    required this.catalogKeyExists,
    required this.catalogOpens,
    required this.profiles,
    required this.pendingReset,
    required this.stagingLeftovers,
    required this.legacyWindowsData,
    this.profileError,
  });

  final bool catalogExists;
  final bool catalogKeyExists;
  final bool catalogOpens;
  final List<ProfileStorageStatus> profiles;
  final bool pendingReset;
  final bool stagingLeftovers;
  final bool legacyWindowsData;
  final String? profileError;
}

class ProfileStorageStatus {
  const ProfileStorageStatus({
    required this.id,
    required this.fileExists,
    required this.keyExists,
    required this.opens,
    this.errorCode,
  });

  final String id;
  final bool fileExists;
  final bool keyExists;
  final bool opens;
  final AppErrorCode? errorCode;
}

/// Deletes every trace of the app's data so the next start is a fresh install.
///
/// It only ever deletes files under [AppPaths.root] and keys that match SSH
/// Client's own prefixes inside the secret-store namespace. It never calls
/// `deletePrefix('')`, never touches other apps and never copies keys anywhere.
class AppResetService {
  AppResetService({
    required this.paths,
    required this.keys,
    this.environment = const {},
  });

  final AppPaths paths;
  final DatabaseKeyStore keys;
  final Map<String, String> environment;

  static const _allowedSecretPrefixes = <String>[
    SecretKeys.catalogDatabaseKey,
    'profile/',
    'staging/',
    'backup/',
    SecretKeys.probeKey,
  ];

  Future<StorageStatus> inspectAsync() async {
    var catalogKeyExists = false;
    var catalogOpens = false;
    String? error;
    final profiles = <ProfileStorageStatus>[];
    try {
      catalogKeyExists = await keys.hasCatalogKey();
    } catch (_) {
      catalogKeyExists = false;
    }
    if (File(paths.catalogDatabase).existsSync() && catalogKeyExists) {
      try {
        final key = await keys.loadCatalogKey();
        final db = EncryptedDatabase.open(
          path: paths.catalogDatabase,
          key: key,
          migrations: CatalogSchema.runner,
        );
        try {
          final rows = db.select('SELECT id FROM profiles ORDER BY name');
          for (final row in rows) {
            final id = row['id'] as String;
            final hasKey = await keys.hasProfileKey(id);
            final fileExists = File(paths.profileDatabase(id)).existsSync();
            var opens = false;
            AppErrorCode? profileError;
            if (fileExists && hasKey) {
              try {
                final profileKey = await keys.loadProfileKey(id);
                final profileDb = EncryptedDatabase.open(
                  path: paths.profileDatabase(id),
                  key: profileKey,
                  migrations: ProfileSchema.runner,
                );
                try {
                  profileDb.select('SELECT count(*) FROM connections');
                  opens = true;
                } finally {
                  profileDb.close();
                }
              } on AppException catch (failure) {
                profileError = failure.code;
              }
            }
            profiles.add(
              ProfileStorageStatus(
                id: id,
                fileExists: fileExists,
                keyExists: hasKey,
                opens: opens,
                errorCode: profileError,
              ),
            );
          }
          catalogOpens = true;
        } finally {
          db.close();
        }
      } on AppException catch (failure) {
        error = failure.code.name;
      } catch (_) {
        error = AppErrorCode.databaseFailure.name;
      }
    }
    return StorageStatus(
      catalogExists: File(paths.catalogDatabase).existsSync(),
      catalogKeyExists: catalogKeyExists,
      catalogOpens: catalogOpens,
      profiles: profiles,
      pendingReset: File(paths.resetMarker).existsSync(),
      stagingLeftovers: Directory(paths.stagingRoot).existsSync(),
      legacyWindowsData: _legacyExists(),
      profileError: error,
    );
  }

  bool _legacyExists() {
    final legacy = AppPaths.legacyWindowsRoot(environment);
    return legacy != null && Directory(legacy).existsSync();
  }

  /// Removes databases, sidecars, staging/backup directories and this app's
  /// secrets. Call it with every database handle already closed.
  Future<void> reset({List<String> extraFiles = const []}) async {
    for (final file in extraFiles) {
      _deleteFile(file);
    }
    _deleteFile(paths.catalogDatabase);
    _deleteFile('${paths.catalogDatabase}-wal');
    _deleteFile('${paths.catalogDatabase}-shm');
    _deleteFile('${paths.catalogDatabase}-journal');
    _deleteDirectory(Directory(p.join(paths.root, 'profiles')));
    _deleteDirectory(Directory(paths.stagingRoot));
    _deleteDirectory(Directory(paths.backupRoot));
    await _deleteOwnSecrets();
    _deleteFile(paths.resetMarker);
  }

  /// Deletes only keys that match this app's own prefixes. Enumerates exact
  /// keys (never a bare prefix delete of the whole store).
  Future<void> _deleteOwnSecrets() async {
    List<String> keysInNamespace;
    try {
      keysInNamespace = await keys.secrets.keysWithPrefix('');
    } catch (_) {
      // A corrupted platform store must not abort the file cleanup.
      return;
    }
    for (final key in keysInNamespace) {
      if (!_isOurs(key)) continue;
      try {
        await keys.secrets.delete(key);
      } catch (_) {
        // Best effort per key; the storage stays consistent for files.
      }
    }
  }

  static bool _isOurs(String key) => _allowedSecretPrefixes.any(
    (prefix) => key == prefix || key.startsWith(prefix),
  );

  /// Applies a reset that could not delete everything while a handle was open.
  static Future<void> applyPendingReset({
    required AppPaths paths,
    required DatabaseKeyStore keys,
    Map<String, String> environment = const {},
  }) async {
    if (!File(paths.resetMarker).existsSync()) return;
    await AppResetService(
      paths: paths,
      keys: keys,
      environment: environment,
    ).reset();
  }

  void _deleteFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return;
    try {
      file.deleteSync();
    } on FileSystemException {
      _markPendingReset();
    }
  }

  void _deleteDirectory(Directory directory) {
    if (!directory.existsSync()) return;
    try {
      directory.deleteSync(recursive: true);
    } on FileSystemException {
      _markPendingReset();
    }
  }

  void _markPendingReset() {
    try {
      File(paths.resetMarker).writeAsStringSync('pending');
    } on FileSystemException {
      // If even the marker cannot be written, the UI reports partial failure.
    }
  }
}
