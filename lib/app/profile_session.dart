import 'package:sqlite3/sqlite3.dart';

import '../core/database/database_key_store.dart';
import '../core/database/encrypted_database.dart';
import '../core/database/schemas.dart';
import '../core/storage/app_paths.dart';
import '../features/collections/data/collection_repository.dart';
import '../features/connections/data/connection_repository.dart';
import '../features/ssh/data/known_host_repository.dart';
import '../shared/models/profile.dart';

/// An unlocked profile: its own encrypted database and the repositories bound
/// to it.
///
/// One instance per unlocked profile. [close] is the only way to release the
/// database; the app calls it on lock, logout and profile switch.
///
/// Lives in `app/` and not in `core/` on purpose: it is the assembly of feature
/// repositories, and `core/` must stay feature-agnostic.
class ProfileSession {
  ProfileSession({
    required this.profile,
    required this.database,
    required this.paths,
  }) : collections = CollectionRepository(database),
       connections = ConnectionRepository(database),
       knownHosts = KnownHostRepository(database);

  final Profile profile;
  final Database database;
  final AppPaths paths;
  final CollectionRepository collections;
  final ConnectionRepository connections;
  final KnownHostRepository knownHosts;

  bool _closed = false;
  bool get isClosed => _closed;

  static Future<ProfileSession> open({
    required Profile profile,
    required AppPaths paths,
    required DatabaseKeyStore keys,
  }) async {
    paths.ensureProfileDirectory(profile.id);
    final key = await keys.profileKey(profile.id);
    final db = EncryptedDatabase.open(
      path: paths.profileDatabase(profile.id),
      key: key,
      migrations: ProfileSchema.runner,
    );
    return ProfileSession(profile: profile, database: db, paths: paths);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    database.close();
  }
}
