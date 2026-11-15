import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_key_store.dart';
import '../../../core/database/encrypted_database.dart';
import '../../../core/database/schemas.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/app_paths.dart';
import '../../../shared/models/profile.dart';
import '../../collections/data/collection_repository.dart';
import '../../connections/data/connection_repository.dart';
import '../../connections/data/credential_service.dart';
import '../../profiles/data/catalog_store.dart';
import '../../ssh/data/known_host_repository.dart';
import '../domain/backup_document.dart';

enum BackupImportMode { merge, replaceProfile, replaceAll }

/// What the user sees before confirming an import.
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

/// Applies a [BackupDocument] with a compensating snapshot.
///
/// The backup and the app state live in different stores (catalog, one database
/// per profile, platform secret store), so a single ACID transaction across all
/// of them does not exist. The strategy is: validate everything first, snapshot
/// the current state in memory, apply, and on any failure restore the snapshot.
/// That is tested with an injected secret-store failure.
class BackupImporter {
  BackupImporter({
    required this.catalog,
    required this.paths,
    required this.keys,
    required this.credentials,
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;

  final CatalogStore catalog;
  final AppPaths paths;
  final DatabaseKeyStore keys;
  final CredentialService credentials;
  final DateTime Function() now;

  BackupImportSummary summarize(BackupDocument document) {
    final localNames = {
      for (final profile in catalog.profiles.all())
        Profile.normalizeName(profile.name),
    };
    var conflicts = 0;
    for (final profile in document.profiles) {
      final sameId = catalog.profiles.byId(profile.id) != null;
      final sameName = localNames.contains(Profile.normalizeName(profile.name));
      if (sameId || sameName) conflicts++;
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
    final snapshot = await _snapshot();
    try {
      switch (mode) {
        case BackupImportMode.merge:
          await _merge(document);
        case BackupImportMode.replaceProfile:
          await _replaceProfile(document, targetProfileId);
        case BackupImportMode.replaceAll:
          await _wipeAll();
          for (final profile in document.profiles) {
            await _createProfile(profile, document);
          }
      }
    } catch (error, stackTrace) {
      await _restore(snapshot);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _merge(BackupDocument document) async {
    for (final profile in document.profiles) {
      final local = catalog.profiles.byId(profile.id);
      if (local == null) {
        await _createProfile(profile, document);
        continue;
      }
      final data = document.dataFor(profile.id);
      if (data != null) {
        await _mergeData(profile.id, data);
      }
      await _writeCredentials(document.credentialsFor(profile.id));
    }
  }

  Future<void> _replaceProfile(
    BackupDocument document,
    String? targetProfileId,
  ) async {
    if (targetProfileId == null) {
      failWith(AppErrorCode.backupInvalid, cause: 'no target profile');
    }
    final local = catalog.profiles.byId(targetProfileId);
    if (local == null) {
      failWith(AppErrorCode.backupInvalid, cause: 'target not local');
    }
    final source = document.profiles.where((p) => p.id == targetProfileId);
    if (source.isEmpty) {
      failWith(AppErrorCode.backupInvalid, cause: 'target not in backup');
    }

    await credentials.deleteAll(targetProfileId);
    final doc = source.first;
    catalog.profiles.update(
      local.copyWith(
        name: _uniqueName(doc.name, ignoreId: targetProfileId),
        settings: doc.settings,
        updatedAt: now(),
      ),
    );
    final data = document.dataFor(targetProfileId);
    await _clearData(targetProfileId);
    if (data != null) {
      await _replaceData(targetProfileId, data);
    }
    await _writeCredentials(document.credentialsFor(targetProfileId));
  }

  Future<void> _createProfile(Profile source, BackupDocument document) async {
    final profile = Profile(
      id: source.id,
      name: _uniqueName(source.name),
      passwordSalt: source.passwordSalt,
      passwordVerifier: source.passwordVerifier,
      kdf: source.kdf,
      kdfParams: source.kdfParams,
      settings: source.settings,
      isLastActive: catalog.profiles.count() == 0,
      failedAttempts: 0,
      lockoutUntil: null,
      createdAt: source.createdAt,
      updatedAt: now(),
    );
    catalog.profiles.insert(profile);
    await keys.profileKey(profile.id);
    final data = document.dataFor(profile.id);
    if (data != null) {
      await _replaceData(profile.id, data);
    }
    await _writeCredentials(document.credentialsFor(profile.id));
  }

  Future<void> _mergeData(String profileId, BackupProfileData data) async {
    final db = await _open(profileId);
    try {
      db.execute('BEGIN IMMEDIATE');
      try {
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
            // A differing fingerprint is a security conflict: keep the local
            // one instead of failing the whole import.
            if (error.code != AppErrorCode.conflict) rethrow;
          }
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.close();
    }
  }

  Future<void> _replaceData(String profileId, BackupProfileData data) async {
    final db = await _open(profileId);
    try {
      db.execute('BEGIN IMMEDIATE');
      try {
        for (final collection in data.collections) {
          CollectionRepository(db).insert(collection);
        }
        for (final connection in data.connections) {
          ConnectionRepository(db).insert(connection);
        }
        for (final knownHost in data.knownHosts) {
          KnownHostRepository(db).accept(knownHost);
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.close();
    }
  }

  Future<void> _clearData(String profileId) async {
    final db = await _open(profileId);
    try {
      db.execute('BEGIN IMMEDIATE');
      try {
        db.execute('DELETE FROM connections');
        db.execute('DELETE FROM collections');
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.close();
    }
  }

  Future<void> _writeCredentials(List<BackupCredential> secrets) async {
    for (final credential in secrets) {
      await credentials.save(
        profileId: credential.profileId,
        credentialId: credential.credentialId,
        secret: credential.secret,
      );
    }
  }

  Future<void> _wipeAll() async {
    for (final profile in catalog.profiles.all()) {
      await credentials.deleteAll(profile.id);
      await keys.forgetProfile(profile.id);
      catalog.profiles.delete(profile.id);
      paths.deleteProfileFiles(profile.id);
    }
  }

  Future<_Snapshot> _snapshot() async {
    final profiles = <String, Profile>{};
    final data = <String, BackupProfileData>{};
    final secrets = <String, List<BackupCredential>>{};

    for (final profile in catalog.profiles.all()) {
      profiles[profile.id] = profile;
      final db = await _open(profile.id);
      try {
        data[profile.id] = BackupProfileData(
          profileId: profile.id,
          collections: CollectionRepository(db).all(),
          connections: ConnectionRepository(db).all(),
          knownHosts: KnownHostRepository(db).all(),
        );
      } finally {
        db.close();
      }
      final ids = await credentials.listIds(profile.id);
      final loaded = <BackupCredential>[];
      for (final id in ids) {
        final secret = await credentials.load(
          profileId: profile.id,
          credentialId: id,
        );
        if (secret == null) continue;
        loaded.add(
          BackupCredential(
            profileId: profile.id,
            credentialId: id,
            secret: secret,
          ),
        );
      }
      secrets[profile.id] = loaded;
    }
    return _Snapshot(profiles: profiles, data: data, credentials: secrets);
  }

  Future<void> _restore(_Snapshot snapshot) async {
    await _wipeAll();
    for (final profile in snapshot.profiles.values) {
      await _insertProfileRow(profile);
      await _replaceData(profile.id, snapshot.data[profile.id]!);
      await _writeCredentials(snapshot.credentials[profile.id]!);
    }
  }

  /// Reinserts a profile row exactly as it was, including its last-active flag.
  Future<void> _insertProfileRow(Profile profile) async {
    catalog.profiles.insert(profile);
    await keys.profileKey(profile.id);
  }

  Future<Database> _open(String profileId) async {
    paths.ensureProfileDirectory(profileId);
    return EncryptedDatabase.open(
      path: paths.profileDatabase(profileId),
      key: await keys.profileKey(profileId),
      migrations: ProfileSchema.runner,
    );
  }

  String _uniqueName(String desired, {String? ignoreId}) {
    final taken = {
      for (final profile in catalog.profiles.all())
        if (profile.id != ignoreId) Profile.normalizeName(profile.name),
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

class _Snapshot {
  const _Snapshot({
    required this.profiles,
    required this.data,
    required this.credentials,
  });

  final Map<String, Profile> profiles;
  final Map<String, BackupProfileData> data;
  final Map<String, List<BackupCredential>> credentials;
}
