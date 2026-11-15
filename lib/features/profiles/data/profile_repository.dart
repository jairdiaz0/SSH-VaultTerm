import 'package:sqlite3/sqlite3.dart';

import '../../../shared/models/profile.dart';

/// Catalog-level profile persistence. The catalog database never stores
/// credentials, keys or host data.
class ProfileRepository {
  ProfileRepository(this._db);

  final Database _db;

  List<Profile> all() => _db
      .select('SELECT * FROM profiles ORDER BY name_normalized')
      .map(Profile.fromRow)
      .toList();

  Profile? byId(String id) {
    final rows = _db.select('SELECT * FROM profiles WHERE id = ?', [id]);
    return rows.isEmpty ? null : Profile.fromRow(rows.first);
  }

  Profile? byName(String name) {
    final rows = _db.select(
      'SELECT * FROM profiles WHERE name_normalized = ?',
      [Profile.normalizeName(name)],
    );
    return rows.isEmpty ? null : Profile.fromRow(rows.first);
  }

  Profile? lastActive() {
    final rows = _db.select('SELECT * FROM profiles WHERE is_last_active = 1');
    return rows.isEmpty ? null : Profile.fromRow(rows.first);
  }

  int count() =>
      _db.select('SELECT COUNT(*) AS n FROM profiles').first['n'] as int;

  /// Inserts [profile]. If it is the last active one, the previous one is
  /// cleared first so the partial unique index can never be violated.
  void insert(Profile profile) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      if (profile.isLastActive) {
        _db.execute(
          'UPDATE profiles SET is_last_active = 0 WHERE is_last_active = 1',
        );
      }
      final row = profile.toRow();
      final columns = row.keys.join(', ');
      final placeholders = List.filled(row.length, '?').join(', ');
      _db.execute(
        'INSERT INTO profiles ($columns) VALUES ($placeholders)',
        row.values.toList(),
      );
      _db.execute('COMMIT');
    } catch (error) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void update(Profile profile) {
    final row = profile.toRow()
      ..remove('id')
      ..remove('created_at');
    final assignments = row.keys.map((key) => '$key = ?').join(', ');
    _db.execute('UPDATE profiles SET $assignments WHERE id = ?', [
      ...row.values,
      profile.id,
    ]);
  }

  /// Marks [id] as the last active profile and clears the previous one.
  void setLastActive(String id, {required DateTime now}) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'UPDATE profiles SET is_last_active = 0 WHERE is_last_active = 1',
      );
      _db.execute(
        'UPDATE profiles SET is_last_active = 1, updated_at = ? WHERE id = ?',
        [now.millisecondsSinceEpoch, id],
      );
      _db.execute('COMMIT');
    } catch (error) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Persists a failed local authentication attempt and its lockout deadline.
  void recordFailedAttempt(
    String id, {
    required int failedAttempts,
    required DateTime now,
    DateTime? lockoutUntil,
  }) {
    _db.execute(
      'UPDATE profiles SET failed_attempts = ?, lockout_until = ?, updated_at = ? '
      'WHERE id = ?',
      [
        failedAttempts,
        lockoutUntil?.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
        id,
      ],
    );
  }

  /// Clears attempts and lockout after a successful authentication.
  void clearFailures(String id, {required DateTime now}) {
    _db.execute(
      'UPDATE profiles SET failed_attempts = 0, lockout_until = NULL, updated_at = ? '
      'WHERE id = ?',
      [now.millisecondsSinceEpoch, id],
    );
  }

  void delete(String id) {
    _db.execute('DELETE FROM profiles WHERE id = ?', [id]);
  }
}
