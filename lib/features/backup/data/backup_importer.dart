import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_key_store.dart';
import '../../../core/database/encrypted_database.dart';
import '../../../core/database/schemas.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/security/secure_random.dart';
import '../../../core/storage/app_paths.dart';
import '../../../core/storage/secret_store.dart';
import '../../../shared/models/profile.dart';
import '../../collections/data/collection_repository.dart';
import '../../connections/data/connection_repository.dart';
import '../../connections/data/credential_service.dart';
import '../../profiles/data/catalog_store.dart';
import '../../ssh/data/known_host_repository.dart';
import '../domain/backup_document.dart';

enum BackupImportMode { merge, replaceProfile, replaceAll }

class BackupImportSummary {
  const BackupImportSummary({
    required this.profiles,
    required this.collections,
    required this.connections,
    required this.knownHosts,
    required this.credentials,
    required this.conflicts,
  });

  final int profiles;
  final int collections;
  final int connections;
  final int knownHosts;
  final int credentials;
  final int conflicts;
}

/// Imports a backup with staging for the modes that replace files.
///
/// Merge only writes rows into existing databases (same keys, same files), so a
/// transaction plus a data snapshot is enough. Replacing profiles builds new
/// databases in `staging/<uuid>` with fresh keys, swaps directories and promotes
/// keys/credentials, then **reopens everything with the keys read from the secret
/// store** before deleting the backup copies. Any failure rolls files, keys,
/// credentials and catalog rows back.
class BackupImporter {
  BackupImporter({
    required this.catalog,
    required this.paths,
    required this.keys,
    required this.credentials,
    this.uuid = const Uuid(),
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;

  final CatalogStore catalog;
  final AppPaths paths;
  final DatabaseKeyStore keys;
  final CredentialService credentials;
  final Uuid uuid;
  final DateTime Function() now;

  BackupImportSummary summarize(BackupDocument document) {
    final localNames = {
      for (final profile in catalog.profiles.all())
        Profile.normalizeName(profile.name),
    };
    var conflicts = 0;
    for (final profile in document.profiles) {
      final sameId = catalog.profiles.byId(profile.id) != null;
      if (sameId || localNames.contains(Profile.normalizeName(profile.name))) {
        conflicts++;
      }
    }
    return BackupImportSummary(
      profiles: document.profiles.length,
      collections: document.profileData.fold(
        0,
        (sum, data) => sum + data.collections.length,
      ),
      connections: document.profileData.fold(
        0,
        (sum, data) => sum + data.connections.length,
      ),
      knownHosts: document.profileData.fold(
        0,
        (sum, data) => sum + data.knownHosts.length,
      ),
      credentials: document.credentials.length,
      conflicts: conflicts,
    );
  }

  Future<void> apply(
    BackupDocument document, {
    required BackupImportMode mode,
    String? targetProfileId,
  }) async {
    switch (mode) {
      case BackupImportMode.merge:
        await _merge(document);
      case BackupImportMode.replaceProfile:
        if (targetProfileId == null ||
            catalog.profiles.byId(targetProfileId) == null ||
            document.profiles.every((p) => p.id != targetProfileId)) {
          failWith(AppErrorCode.backupInvalid, cause: 'invalid target profile');
        }
        await _replace(
          document,
          toRemove: {targetProfileId},
          importIds: {targetProfileId},
        );
      case BackupImportMode.replaceAll:
        await _replace(
          document,
          toRemove: catalog.profiles.all().map((profile) => profile.id).toSet(),
          importIds: document.profiles.map((profile) => profile.id).toSet(),
        );
    }
  }

  // ---------------------------------------------------------------- merge

  Future<void> _merge(BackupDocument document) async {
    final existingIds = document.profiles
        .where((profile) => catalog.profiles.byId(profile.id) != null)
        .map((profile) => profile.id)
        .toList();
    final dataSnapshot = <String, BackupProfileData>{};
    final secretSnapshot = <String, List<BackupCredential>>{};
    for (final id in existingIds) {
      dataSnapshot[id] = await _readData(id);
      secretSnapshot[id] = await _readSecrets(id);
    }
    final created = <String>[];

    try {
      for (final profile in document.profiles) {
        final data = document.dataFor(profile.id);
        if (catalog.profiles.byId(profile.id) == null) {
          await _createProfile(
            profile,
            data,
            document.credentialsFor(profile.id),
          );
          created.add(profile.id);
        } else if (data != null) {
          await _mergeData(profile.id, data);
        }
      }
      for (final id in existingIds) {
        await _writeCredentials(document.credentialsFor(id));
      }
    } catch (_) {
      for (final id in created) {
        catalog.profiles.delete(id);
        await keys.forgetProfile(id);
        paths.deleteProfileFiles(id);
      }
      for (final id in existingIds) {
        await _replaceData(id, dataSnapshot[id]!);
        await _restoreCredentials(id, secretSnapshot[id]!);
      }
      rethrow;
    }
  }

  Future<void> _createProfile(
    Profile source,
    BackupProfileData? data,
    List<BackupCredential> secrets,
  ) async {
    final id = source.id;
    try {
      catalog.profiles.insert(
        source.copyWith(
          name: _uniqueName(source.name),
          isLastActive: catalog.profiles.count() == 0,
          failedAttempts: 0,
          clearLockout: true,
          updatedAt: now(),
        ),
      );
      await keys.createProfileKey(id);
      await _writeDataNew(id, data);
      await _writeCredentials(secrets);
    } catch (_) {
      catalog.profiles.delete(id);
      await keys.forgetProfile(id);
      paths.deleteProfileFiles(id);
      rethrow;
    }
  }

  Future<void> _mergeData(String profileId, BackupProfileData data) async {
    final db = await _openExisting(profileId);
    try {
      _transaction(db, () {
        final collections = CollectionRepository(db);
        for (final collection in data.collections) {
          if (collections.byId(collection.id) == null) {
            collections.insert(collection);
          } else {
            collections.update(collection);
          }
        }
        final connections = ConnectionRepository(db);
        for (final connection in data.connections) {
          if (connections.byId(connection.id) == null) {
            connections.insert(connection);
          } else {
            connections.update(connection);
          }
        }
        final knownHosts = KnownHostRepository(db);
        for (final knownHost in data.knownHosts) {
          try {
            knownHosts.accept(knownHost);
          } on AppException catch (error) {
            if (error.code != AppErrorCode.conflict) rethrow;
          }
        }
      });
    } finally {
      db.close();
    }
  }

  Future<void> _replaceData(String profileId, BackupProfileData data) async {
    final db = await _openExisting(profileId);
    try {
      _transaction(db, () {
        db.execute('DELETE FROM connections');
        db.execute('DELETE FROM collections');
        _insertData(db, data);
      });
    } finally {
      db.close();
    }
  }

  // -------------------------------------------------------------- replace

  Future<void> _replace(
    BackupDocument document, {
    required Set<String> toRemove,
    required Set<String> importIds,
  }) async {
    final stagingId = uuid.v4();
    final backupId = uuid.v4();
    final stagingPrefix = SecretKeys.stagingPrefix(stagingId);
    final backupPrefix = SecretKeys.backupPrefix(backupId);
    final stagingProfiles = Directory(
      '${paths.stagingRoot}/$stagingId/profiles',
    );
    final backupProfiles = Directory('${paths.backupRoot}/$backupId/profiles');
    final imported = document.profiles
        .where((profile) => importIds.contains(profile.id))
        .toList();

    final rows = <String, Profile>{};
    final oldKeys = <String, List<int>>{};
    final oldSecrets = <String, List<BackupCredential>>{};
    final staged = <String, _StagedProfile>{};
    final movedToBackup = <String>{};
    final promoted = <String>{};

    try {
      for (final id in toRemove) {
        rows[id] = catalog.profiles.byId(id)!;
        oldKeys[id] = await keys.loadProfileKey(id);
        oldSecrets[id] = await _readSecrets(id);
      }
      for (final profile in imported) {
        final key = EncryptedDatabase.generateKey();
        final dir = Directory('${stagingProfiles.path}/${profile.id}')
          ..createSync(recursive: true);
        final data = document.dataFor(profile.id);
        _buildDatabase('${dir.path}/data.db', key, data);
        _verifyDatabase('${dir.path}/data.db', key);
        staged[profile.id] = _StagedProfile(profile, key);
        final secrets = document.credentialsFor(profile.id);
        await _writeStagingSecrets(stagingPrefix, profile.id, key, secrets);
      }
    } catch (_) {
      _deleteDirectory(stagingProfiles.parent);
      _deleteDirectory(Directory(paths.stagingRoot));
      await _deletePrefix(stagingPrefix);
      rethrow;
    }

    try {
      // 1. Move current files aside and copy old keys/credentials to backup.
      for (final id in toRemove) {
        final dir = Directory(paths.profileDirectory(id));
        if (dir.existsSync()) {
          backupProfiles.createSync(recursive: true);
          dir.renameSync('${backupProfiles.path}/$id');
          movedToBackup.add(id);
        }
        await keys.secrets.write(
          SecretKeys.profileKeyIn(backupPrefix, id),
          toHex(Uint8List.fromList(oldKeys[id]!)),
        );
        for (final secret in oldSecrets[id] ?? const <BackupCredential>[]) {
          await keys.secrets.write(
            SecretKeys.credentialIn(backupPrefix, id, secret.credentialId),
            jsonEncode(secret.secret.toJson()),
          );
        }
      }

      // 2. Catalog rows. The repositories already run their own statements;
      //    the rollback path restores the previous rows if anything fails.
      for (final id in toRemove) {
        catalog.profiles.delete(id);
      }
      for (final profile in imported) {
        catalog.profiles.insert(
          profile.copyWith(
            name: _uniqueNameForReplace(profile.name, {
              ...toRemove,
              ...importIds,
            }),
            isLastActive: catalog.profiles.count() == 0,
            failedAttempts: 0,
            clearLockout: true,
            updatedAt: now(),
          ),
        );
      }

      // 3. Move staged databases into their final directories.
      for (final entry in staged.entries) {
        final finalDir = Directory(paths.profileDirectory(entry.key))
          ..createSync(recursive: true);
        final stagedDir = Directory('${stagingProfiles.path}/${entry.key}');
        for (final file in stagedDir.listSync()) {
          file.renameSync('${finalDir.path}/${file.uri.pathSegments.last}');
        }
      }

      // 4. Promote keys (old ones are in the backup namespace) and credentials.
      for (final entry in staged.entries) {
        await keys.saveProfileKey(entry.key, entry.value.key);
        promoted.add(entry.key);
        await _writeCredentials(document.credentialsFor(entry.key));
      }

      // 5. Cold verification: reopen catalog and every imported profile with
      //    the keys read back from the secret store.
      await _verifyCold(staged.keys, imported);

      // 6. Success: drop backups and staging secrets.
      _deleteDirectory(stagingProfiles.parent);
      _deleteDirectory(Directory(paths.stagingRoot));
      _deleteDirectory(backupProfiles.parent);
      _deleteDirectory(Directory(paths.backupRoot));
      await _deletePrefix(stagingPrefix);
      await _deletePrefix(backupPrefix);
    } catch (_) {
      try {
        await _rollbackReplace(
          toRemove: toRemove,
          importedIds: importIds,
          staged: staged,
          promoted: promoted,
          movedToBackup: movedToBackup,
          rows: rows,
          oldKeys: oldKeys,
          oldSecrets: oldSecrets,
          backupProfiles: backupProfiles,
          stagingProfiles: stagingProfiles,
          stagingPrefix: stagingPrefix,
          backupPrefix: backupPrefix,
        );
      } finally {
        _deleteDirectory(stagingProfiles.parent);
        _deleteDirectory(Directory(paths.stagingRoot));
        _deleteDirectory(backupProfiles.parent);
        _deleteDirectory(Directory(paths.backupRoot));
        await _deletePrefix(stagingPrefix);
        await _deletePrefix(backupPrefix);
      }
      rethrow;
    }
  }

  Future<void> _rollbackReplace({
    required Set<String> toRemove,
    required Set<String> importedIds,
    required Map<String, _StagedProfile> staged,
    required Set<String> promoted,
    required Set<String> movedToBackup,
    required Map<String, Profile> rows,
    required Map<String, List<int>> oldKeys,
    required Map<String, List<BackupCredential>> oldSecrets,
    required Directory backupProfiles,
    required Directory stagingProfiles,
    required String stagingPrefix,
    required String backupPrefix,
  }) async {
    // Remove promoted files and keys, then put the backups back.
    for (final id in promoted) {
      await keys.forgetProfile(id);
    }
    for (final id in {...toRemove, ...importedIds}) {
      _deleteDirectory(Directory(paths.profileDirectory(id)));
    }
    for (final id in movedToBackup) {
      final backupDir = Directory('${backupProfiles.path}/$id');
      if (backupDir.existsSync()) {
        backupDir.renameSync(paths.profileDirectory(id));
      }
    }
    // Restore catalog rows and old secrets.
    try {
      for (final id in {...toRemove, ...importedIds}) {
        catalog.profiles.delete(id);
      }
      for (final row in rows.values) {
        catalog.profiles.insert(row);
      }
    } catch (_) {
      // Original error wins; the storage screen reports leftovers.
    }
    for (final id in toRemove) {
      try {
        await keys.saveProfileKey(id, Uint8List.fromList(oldKeys[id]!));
        await _restoreCredentials(id, oldSecrets[id] ?? const []);
      } catch (_) {
        // The original failure wins; the storage screen reports the rest.
      }
    }
    _deleteDirectory(stagingProfiles.parent);
    _deleteDirectory(Directory(paths.stagingRoot));
    _deleteDirectory(backupProfiles.parent);
    _deleteDirectory(Directory(paths.backupRoot));
    await _deletePrefix(stagingPrefix);
    await _deletePrefix(backupPrefix);
  }

  Future<void> _verifyCold(Iterable<String> ids, List<Profile> profiles) async {
    final catalogKey = await keys.loadCatalogKey();
    final check = EncryptedDatabase.open(
      path: paths.catalogDatabase,
      key: catalogKey,
      migrations: CatalogSchema.runner,
    );
    try {
      for (final profile in profiles) {
        final found = check.select(
          'SELECT 1 AS ok FROM profiles WHERE id = ?',
          [profile.id],
        );
        if (found.isEmpty) {
          failWith(
            AppErrorCode.backupInvalid,
            cause: 'catalog row missing after import',
          );
        }
      }
    } finally {
      check.close();
    }

    for (final id in ids) {
      final key = await keys.loadProfileKey(id);
      final db = EncryptedDatabase.open(
        path: paths.profileDatabase(id),
        key: key,
        migrations: ProfileSchema.runner,
      );
      try {
        db.select('SELECT count(*) FROM collections');
        db.select('SELECT count(*) FROM connections');
      } finally {
        db.close();
      }
    }
  }

  // ------------------------------------------------------------- helpers

  void _buildDatabase(String path, List<int> key, BackupProfileData? data) {
    final db = EncryptedDatabase.open(
      path: path,
      key: Uint8List.fromList(key),
      migrations: ProfileSchema.runner,
    );
    try {
      _transaction(db, () {
        if (data != null) _insertData(db, data);
      });
    } finally {
      db.close();
    }
  }

  void _verifyDatabase(String path, List<int> key) {
    final db = EncryptedDatabase.open(
      path: path,
      key: Uint8List.fromList(key),
      migrations: ProfileSchema.runner,
    );
    try {
      db.select('SELECT count(*) FROM connections');
    } finally {
      db.close();
    }
  }

  void _insertData(Database db, BackupProfileData data) {
    for (final collection in data.collections) {
      CollectionRepository(db).insert(collection);
    }
    for (final connection in data.connections) {
      ConnectionRepository(db).insert(connection);
    }
    for (final knownHost in data.knownHosts) {
      KnownHostRepository(db).accept(knownHost);
    }
  }

  void _transaction(Database db, void Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      action();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<Database> _openExisting(String profileId) async {
    final key = await keys.loadProfileKey(profileId);
    return EncryptedDatabase.open(
      path: paths.profileDatabase(profileId),
      key: key,
      migrations: ProfileSchema.runner,
    );
  }

  Future<BackupProfileData> _readData(String profileId) async {
    final db = await _openExisting(profileId);
    try {
      return BackupProfileData(
        profileId: profileId,
        collections: CollectionRepository(db).all(),
        connections: ConnectionRepository(db).all(),
        knownHosts: KnownHostRepository(db).all(),
      );
    } finally {
      db.close();
    }
  }

  Future<void> _writeDataNew(String profileId, BackupProfileData? data) async {
    paths.ensureProfileDirectory(profileId);
    final key = await keys.loadProfileKey(profileId);
    final db = EncryptedDatabase.open(
      path: paths.profileDatabase(profileId),
      key: key,
      migrations: ProfileSchema.runner,
    );
    try {
      _transaction(db, () {
        if (data != null) _insertData(db, data);
      });
    } finally {
      db.close();
    }
  }

  Future<List<BackupCredential>> _readSecrets(String profileId) async {
    final result = <BackupCredential>[];
    for (final id in await credentials.listIds(profileId)) {
      final secret = await credentials.load(
        profileId: profileId,
        credentialId: id,
      );
      if (secret != null) {
        result.add(
          BackupCredential(
            profileId: profileId,
            credentialId: id,
            secret: secret,
          ),
        );
      }
    }
    return result;
  }

  Future<void> _writeStagingSecrets(
    String prefix,
    String profileId,
    List<int> key,
    List<BackupCredential> secrets,
  ) async {
    await keys.secrets.write(
      SecretKeys.profileKeyIn(prefix, profileId),
      toHex(Uint8List.fromList(key)),
    );
    for (final secret in secrets) {
      await keys.secrets.write(
        SecretKeys.credentialIn(prefix, profileId, secret.credentialId),
        jsonEncode(secret.secret.toJson()),
      );
    }
  }

  Future<void> _writeCredentials(List<BackupCredential> secrets) async {
    for (final secret in secrets) {
      await credentials.save(
        profileId: secret.profileId,
        credentialId: secret.credentialId,
        secret: secret.secret,
      );
    }
  }

  Future<void> _restoreCredentials(
    String profileId,
    List<BackupCredential> secrets,
  ) async {
    await credentials.deleteAll(profileId);
    for (final secret in secrets) {
      await credentials.save(
        profileId: profileId,
        credentialId: secret.credentialId,
        secret: secret.secret,
      );
    }
  }

  Future<void> _deletePrefix(String prefix) async {
    try {
      await keys.secrets.deletePrefix(prefix);
    } catch (_) {
      // Cleanup failures surface at the next startup storage check.
    }
  }

  void _deleteDirectory(Directory dir) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Same as above: never mask the original failure.
    }
  }

  String _uniqueName(String desired) =>
      _uniqueNameForReplace(desired, const {});

  String _uniqueNameForReplace(String desired, Set<String> ignoredIds) {
    final taken = {
      for (final profile in catalog.profiles.all())
        if (!ignoredIds.contains(profile.id))
          Profile.normalizeName(profile.name),
    };
    if (!taken.contains(Profile.normalizeName(desired))) return desired;
    var suffix = 1;
    while (true) {
      final candidate = '$desired (importado${suffix == 1 ? '' : ' $suffix'})';
      if (!taken.contains(Profile.normalizeName(candidate))) return candidate;
      suffix++;
    }
  }
}

class _StagedProfile {
  const _StagedProfile(this.profile, this.key);

  final Profile profile;
  final Uint8List key;
}
