import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_key_store.dart';
import '../../../core/database/encrypted_database.dart';
import '../../../core/database/schemas.dart';
import '../../../core/storage/app_paths.dart';
import '../../profiles/data/profile_repository.dart';

/// The encrypted catalog database plus its repositories.
class CatalogStore {
  CatalogStore({required this.database})
    : profiles = ProfileRepository(database);

  final Database database;
  final ProfileRepository profiles;

  static Future<CatalogStore> open({
    required AppPaths paths,
    required DatabaseKeyStore keys,
  }) async {
    paths.ensureCreated();
    final key = await keys.catalogKey();
    final db = EncryptedDatabase.open(
      path: paths.catalogDatabase,
      key: key,
      migrations: CatalogSchema.runner,
    );
    return CatalogStore(database: db);
  }

  void close() => database.close();
}
