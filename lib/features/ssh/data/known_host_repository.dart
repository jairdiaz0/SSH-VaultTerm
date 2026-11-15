import 'package:sqlite3/sqlite3.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/known_host.dart';

/// Accepted host keys (TOFU) inside one profile database.
class KnownHostRepository {
  KnownHostRepository(this._db);

  final Database _db;

  List<KnownHost> byConnection(String connectionId) => _db
      .select(
        'SELECT * FROM known_hosts WHERE connection_id = ? ORDER BY created_at',
        [connectionId],
      )
      .map(KnownHost.fromRow)
      .toList();

  KnownHost? find({
    required String connectionId,
    required String hostname,
    required int port,
  }) {
    final rows = _db.select(
      'SELECT * FROM known_hosts WHERE connection_id = ? AND hostname = ? AND port = ?',
      [connectionId, hostname, port],
    );
    return rows.isEmpty ? null : KnownHost.fromRow(rows.first);
  }

  /// Stores a newly accepted fingerprint. Refuses to silently replace an
  /// existing different fingerprint: a changed host key must go through an
  /// explicit user decision (delete first).
  void accept(KnownHost knownHost) {
    final existing = find(
      connectionId: knownHost.connectionId,
      hostname: knownHost.hostname,
      port: knownHost.port,
    );
    if (existing != null) {
      if (existing.fingerprint != knownHost.fingerprint) {
        throw AppException(
          AppErrorCode.conflict,
          cause: 'host key changed for an existing entry',
        );
      }
      return;
    }
    final row = knownHost.toRow();
    _db.execute(
      'INSERT INTO known_hosts (${row.keys.join(', ')}) '
      'VALUES (${List.filled(row.length, '?').join(', ')})',
      row.values.toList(),
    );
  }

  void delete(String id) {
    _db.execute('DELETE FROM known_hosts WHERE id = ?', [id]);
  }

  void deleteForConnection(String connectionId) {
    _db.execute('DELETE FROM known_hosts WHERE connection_id = ?', [
      connectionId,
    ]);
  }

  int count() =>
      _db.select('SELECT COUNT(*) AS n FROM known_hosts').first['n'] as int;
}
