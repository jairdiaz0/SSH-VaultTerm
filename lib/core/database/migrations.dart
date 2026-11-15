import 'package:sqlite3/sqlite3.dart';

import '../errors/app_exception.dart';

/// Applies ordered schema migrations using `PRAGMA user_version`.
///
/// Each migration is a list of statements. Index `i` migrates version `i` to
/// `i + 1`, so [targetVersion] is simply the list length. Every migration runs
/// inside its own transaction: a partially applied schema never survives.
class MigrationRunner {
  const MigrationRunner({required this.migrations});

  final List<List<String>> migrations;

  int get targetVersion => migrations.length;

  /// Returns the schema version after applying pending migrations.
  int apply(Database db) {
    final current = userVersion(db);
    if (current > targetVersion) {
      throw AppException(
        AppErrorCode.schemaTooNew,
        cause: 'database version $current > app version $targetVersion',
      );
    }
    if (current == targetVersion) return current;

    for (var version = current; version < targetVersion; version++) {
      db.execute('BEGIN IMMEDIATE');
      try {
        for (final statement in migrations[version]) {
          db.execute(statement);
        }
        // Int, not user input: safe to interpolate.
        db.execute('PRAGMA user_version = ${version + 1}');
        db.execute('COMMIT');
      } catch (error, stackTrace) {
        try {
          db.execute('ROLLBACK');
        } catch (_) {
          // The transaction may already be gone; the original error wins.
        }
        throw AppException(
          AppErrorCode.databaseFailure,
          cause: error,
          stackTrace: stackTrace,
        );
      }
    }
    return targetVersion;
  }

  static int userVersion(Database db) {
    final rows = db.select('PRAGMA user_version;');
    return rows.first.columnAt(0) as int;
  }
}
