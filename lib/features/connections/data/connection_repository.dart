import 'package:sqlite3/sqlite3.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/connection.dart';

/// Connections inside one profile database.
class ConnectionRepository {
  ConnectionRepository(this._db);

  final Database _db;

  List<Connection> all() => _db
      .select('SELECT * FROM connections ORDER BY position, name')
      .map(Connection.fromRow)
      .toList();

  List<Connection> favorites() => _db
      .select(
        'SELECT * FROM connections WHERE favorite = 1 ORDER BY position, name',
      )
      .map(Connection.fromRow)
      .toList();

  List<Connection> byCollection(String? collectionId) {
    final rows = collectionId == null
        ? _db.select(
            'SELECT * FROM connections WHERE collection_id IS NULL ORDER BY position, name',
          )
        : _db.select(
            'SELECT * FROM connections WHERE collection_id = ? ORDER BY position, name',
            [collectionId],
          );
    return rows.map(Connection.fromRow).toList();
  }

  Connection? byId(String id) {
    final rows = _db.select('SELECT * FROM connections WHERE id = ?', [id]);
    return rows.isEmpty ? null : Connection.fromRow(rows.first);
  }

  int nextPosition() {
    final row = _db
        .select('SELECT COALESCE(MAX(position), -1) + 1 AS p FROM connections')
        .first;
    return row['p'] as int;
  }

  /// Inserts a connection. A [Connection.collectionId] that does not exist in
  /// this profile is a hard error: membership is validated, not assumed.
  void insert(Connection connection) {
    _requireCollection(connection.collectionId);
    final row = connection.toRow();
    _db.execute(
      'INSERT INTO connections (${row.keys.join(', ')}) '
      'VALUES (${List.filled(row.length, '?').join(', ')})',
      row.values.toList(),
    );
  }

  void update(Connection connection) {
    _requireCollection(connection.collectionId);
    _db.execute(
      'UPDATE connections SET collection_id = ?, name = ?, hostname = ?, port = ?, '
      'username = ?, auth_type = ?, connection_type = ?, credential_id = ?, '
      'description = ?, tags = ?, favorite = ?, position = ?, updated_at = ? '
      'WHERE id = ?',
      [
        connection.collectionId,
        connection.name,
        connection.hostname,
        connection.port,
        connection.username,
        connection.authType.name,
        connection.connectionType.name,
        connection.credentialId,
        connection.description,
        connection.toRow()['tags'],
        connection.favorite ? 1 : 0,
        connection.position,
        connection.updatedAt.millisecondsSinceEpoch,
        connection.id,
      ],
    );
  }

  void setFavorite(String id, {required bool favorite, required DateTime now}) {
    _db.execute(
      'UPDATE connections SET favorite = ?, updated_at = ? WHERE id = ?',
      [favorite ? 1 : 0, now.millisecondsSinceEpoch, id],
    );
  }

  void delete(String id) {
    _db.execute('DELETE FROM connections WHERE id = ?', [id]);
  }

  void reorder(List<String> orderedIds, {required DateTime now}) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final statement = _db.prepare(
        'UPDATE connections SET position = ?, updated_at = ? WHERE id = ?',
      );
      try {
        for (var i = 0; i < orderedIds.length; i++) {
          statement.execute([i, now.millisecondsSinceEpoch, orderedIds[i]]);
        }
      } finally {
        statement.close();
      }
      _db.execute('COMMIT');
    } catch (error) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _requireCollection(String? collectionId) {
    if (collectionId == null) return;
    final rows = _db.select('SELECT 1 AS ok FROM collections WHERE id = ?', [
      collectionId,
    ]);
    if (rows.isEmpty) {
      throw AppException(
        AppErrorCode.validation,
        cause: 'collection not found in this profile',
      );
    }
  }
}
