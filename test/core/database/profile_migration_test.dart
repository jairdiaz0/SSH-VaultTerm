import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ssh_vault_term/core/database/schemas.dart';

/// v1 had no connection_type column; migration v2 must add it with `ssh`.
const _v1Connections = '''
CREATE TABLE connections (
  id TEXT PRIMARY KEY,
  collection_id TEXT,
  name TEXT NOT NULL,
  hostname TEXT NOT NULL,
  port INTEGER NOT NULL,
  username TEXT NOT NULL,
  auth_type TEXT NOT NULL,
  credential_id TEXT,
  description TEXT,
  tags TEXT NOT NULL DEFAULT '[]',
  favorite INTEGER NOT NULL DEFAULT 0,
  position INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
) STRICT
''';

void main() {
  test('v2 adds connection_type and existing rows become ssh', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);

    db.execute(_v1Connections);
    db.execute('PRAGMA user_version = 1');
    db.execute(
      'INSERT INTO connections (id, name, hostname, port, username, auth_type, '
      'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      ['c1', 'legacy', 'host', 22, 'root', 'password', 1, 1],
    );

    final version = ProfileSchema.runner.apply(db);

    expect(version, 2);
    expect(ProfileSchema.runner.targetVersion, 2);
    final row = db.select('SELECT connection_type FROM connections').first;
    expect(row['connection_type'], 'ssh');
  });

  test('v2 rejects an unknown connection type through its check constraint', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    ProfileSchema.runner.apply(db);

    expect(
      () => db.execute(
        'INSERT INTO connections (id, name, hostname, port, username, auth_type, '
        "connection_type, created_at, updated_at) VALUES ('c2', 'x', 'h', 22, "
        "'u', 'password', 'telnet', 1, 1)",
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}
