import 'package:sqlite3/sqlite3.dart';

import '../../../shared/models/server_collection.dart';

/// Collections inside one profile database. The file boundary is the profile
/// boundary: a repository instance only ever sees its own profile's rows.
class CollectionRepository {
  CollectionRepository(this._db);

  final Database _db;

  List<ServerCollection> all() => _db
      .select('SELECT * FROM collections ORDER BY position, name')
      .map(ServerCollection.fromRow)
      .toList();

  ServerCollection? byId(String id) {
    final rows = _db.select('SELECT * FROM collections WHERE id = ?', [id]);
    return rows.isEmpty ? null : ServerCollection.fromRow(rows.first);
  }

  int nextPosition() {
    final row = _db
        .select('SELECT COALESCE(MAX(position), -1) + 1 AS p FROM collections')
        .first;
    return row['p'] as int;
  }

  void insert(ServerCollection collection) {
    final row = collection.toRow();
    _db.execute(
      'INSERT INTO collections (${row.keys.join(', ')}) '
      'VALUES (${List.filled(row.length, '?').join(', ')})',
      row.values.toList(),
    );
  }

  void update(ServerCollection collection) {
    _db.execute(
      'UPDATE collections SET name = ?, description = ?, icon = ?, color = ?, '
      'position = ?, updated_at = ? WHERE id = ?',
      [
        collection.name,
        collection.description,
        collection.icon,
        collection.color,
        collection.position,
        collection.updatedAt.millisecondsSinceEpoch,
        collection.id,
      ],
    );
  }

  /// Deletes the collection. Its connections survive with `collection_id` NULL
  /// (declared ON DELETE SET NULL), which is the documented behaviour.
  void delete(String id) {
    _db.execute('DELETE FROM collections WHERE id = ?', [id]);
  }

  /// Applies [orderedIds] as the new positions, atomically.
  void reorder(List<String> orderedIds, {required DateTime now}) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final statement = _db.prepare(
        'UPDATE collections SET position = ?, updated_at = ? WHERE id = ?',
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
}
