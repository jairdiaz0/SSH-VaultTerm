import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_key_store.dart';
import '../../../core/database/encrypted_database.dart';
import '../../../core/database/schemas.dart';
import '../../../core/storage/app_paths.dart';
import '../../../shared/models/profile.dart';
import '../../collections/data/collection_repository.dart';
import '../../connections/data/connection_repository.dart';
import '../../connections/data/credential_service.dart';
import '../../profiles/data/catalog_store.dart';
import '../../ssh/data/known_host_repository.dart';
import '../domain/backup_document.dart';

/// Builds a [BackupDocument] from the real state: catalog, every profile
/// database and the secrets of every referenced credential.
///
/// The document deliberately has no database master keys: they stay in the
/// platform secret store and are regenerated on import.
class BackupExporter {
  BackupExporter({
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

  Future<BackupDocument> build() async {
    final profiles = catalog.profiles.all();
    final data = <BackupProfileData>[];
    final secrets = <BackupCredential>[];

    for (final profile in profiles) {
      final db = await _open(profile);
      try {
        final collections = CollectionRepository(db).all();
        final connections = ConnectionRepository(db).all();
        final knownHosts = KnownHostRepository(db).all();
        data.add(
          BackupProfileData(
            profileId: profile.id,
            collections: collections,
            connections: connections,
            knownHosts: knownHosts,
          ),
        );
        for (final connection in connections) {
          final credentialId = connection.credentialId;
          if (credentialId == null || credentialId.isEmpty) continue;
          final secret = await credentials.load(
            profileId: profile.id,
            credentialId: credentialId,
          );
          if (secret == null) continue;
          secrets.add(
            BackupCredential(
              profileId: profile.id,
              credentialId: credentialId,
              secret: secret,
            ),
          );
        }
      } finally {
        db.close();
      }
    }

    return BackupDocument(
      formatVersion: BackupDocument.currentFormatVersion,
      exportedAt: now(),
      profiles: profiles,
      profileData: data,
      credentials: secrets,
    );
  }

  Future<Database> _open(Profile profile) async {
    paths.ensureProfileDirectory(profile.id);
    return EncryptedDatabase.open(
      path: paths.profileDatabase(profile.id),
      key: await keys.profileKey(profile.id),
      migrations: ProfileSchema.runner,
    );
  }
}
