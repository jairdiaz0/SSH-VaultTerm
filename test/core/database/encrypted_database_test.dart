import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ssh_client/core/database/encrypted_database.dart';
import 'package:ssh_client/core/database/migrations.dart';
import 'package:ssh_client/core/database/schemas.dart';
import 'package:ssh_client/core/errors/app_exception.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('encrypted_db_test_');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('the linked sqlite is SQLCipher', () {
    final db = EncryptedDatabase.openInMemory(
      key: EncryptedDatabase.generateKey(),
      migrations: CatalogSchema.runner,
    );
    addTearDown(db.close);
    expect(EncryptedDatabase.cipherVersion(db), isNotEmpty);
  });

  test('catalog database round trips through a real file', () {
    final path = p.join(dir.path, 'catalog.db');
    final key = EncryptedDatabase.generateKey();

    final writer = EncryptedDatabase.open(
      path: path,
      key: key,
      migrations: CatalogSchema.runner,
    );
    writer.execute("INSERT INTO app_meta (key, value) VALUES ('schema', 'v1')");
    expect(
      MigrationRunner.userVersion(writer),
      CatalogSchema.runner.targetVersion,
    );
    writer.close();

    final reader = EncryptedDatabase.open(
      path: path,
      key: key,
      migrations: CatalogSchema.runner,
    );
    addTearDown(reader.close);
    expect(reader.select('SELECT value FROM app_meta').first['value'], 'v1');
  });

  test('a wrong key cannot open the database', () {
    final path = p.join(dir.path, 'catalog.db');
    final key = EncryptedDatabase.generateKey();
    EncryptedDatabase.open(
      path: path,
      key: key,
      migrations: CatalogSchema.runner,
    ).close();

    final otherKey = EncryptedDatabase.generateKey();
    expect(
      () => EncryptedDatabase.open(
        path: path,
        key: otherKey,
        migrations: CatalogSchema.runner,
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.databaseKeyInvalid,
        ),
      ),
    );
  });

  test('a key of the wrong length is rejected before touching the file', () {
    expect(
      () => EncryptedDatabase.open(
        path: p.join(dir.path, 'x.db'),
        key: Uint8List(16),
        migrations: CatalogSchema.runner,
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.databaseKeyInvalid,
        ),
      ),
    );
  });

  test('sensitive values do not appear in the file on disk', () {
    final path = p.join(dir.path, 'profile.db');
    const marker = 'LEAK_CANARY_9f7c1b2e44';
    final key = EncryptedDatabase.generateKey();

    final db = EncryptedDatabase.open(
      path: path,
      key: key,
      migrations: ProfileSchema.runner,
    );
    db.execute('INSERT INTO profile_settings (key, value) VALUES (?, ?)', [
      'canary',
      marker,
    ]);
    db.close();

    for (final entity in dir.listSync().whereType<File>()) {
      final bytes = entity.readAsBytesSync();
      expect(
        _containsAscii(bytes, marker),
        isFalse,
        reason: 'plaintext marker found in ${p.basename(entity.path)}',
      );
    }
  });

  test('migrations are applied once and reported by user_version', () {
    final db = EncryptedDatabase.openInMemory(
      key: EncryptedDatabase.generateKey(),
      migrations: ProfileSchema.runner,
    );
    addTearDown(db.close);

    expect(MigrationRunner.userVersion(db), ProfileSchema.runner.targetVersion);
    final tables = db
        .select(
          "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
        )
        .map((row) => row['name'] as String)
        .toList();
    expect(
      tables,
      containsAll([
        'collections',
        'connections',
        'known_hosts',
        'profile_settings',
      ]),
    );
  });

  test('a database newer than the app is refused, not downgraded', () {
    final path = p.join(dir.path, 'future.db');
    final key = EncryptedDatabase.generateKey();
    final db = EncryptedDatabase.open(
      path: path,
      key: key,
      migrations: CatalogSchema.runner,
    );
    db.execute(
      'PRAGMA user_version = ${CatalogSchema.runner.targetVersion + 5}',
    );
    db.close();

    expect(
      () => EncryptedDatabase.open(
        path: path,
        key: key,
        migrations: CatalogSchema.runner,
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.schemaTooNew,
        ),
      ),
    );
  });

  test('foreign keys cascade and nullify as declared', () {
    final db = EncryptedDatabase.openInMemory(
      key: EncryptedDatabase.generateKey(),
      migrations: ProfileSchema.runner,
    );
    addTearDown(db.close);

    final now = DateTime.now().millisecondsSinceEpoch;
    db.execute(
      'INSERT INTO collections (id, name, position, created_at, updated_at) '
      'VALUES (?, ?, 0, ?, ?)',
      ['c1', 'Work', now, now],
    );
    db.execute(
      'INSERT INTO connections (id, collection_id, name, hostname, port, username, '
      "auth_type, created_at, updated_at) VALUES (?, ?, ?, ?, 22, ?, 'password', ?, ?)",
      ['s1', 'c1', 'server', 'example.com', 'root', now, now],
    );
    db.execute(
      'INSERT INTO known_hosts (id, connection_id, hostname, port, key_type, '
      'fingerprint, created_at) VALUES (?, ?, ?, 22, ?, ?, ?)',
      ['h1', 's1', 'example.com', 'ssh-ed25519', 'SHA256:abc', now],
    );

    db.execute("DELETE FROM collections WHERE id = 'c1'");
    expect(
      db
          .select("SELECT collection_id FROM connections WHERE id = 's1'")
          .first['collection_id'],
      isNull,
    );

    db.execute("DELETE FROM connections WHERE id = 's1'");
    expect(db.select('SELECT COUNT(*) AS n FROM known_hosts').first['n'], 0);
  });
}

bool _containsAscii(Uint8List haystack, String needle) {
  final pattern = ascii.encode(needle);
  for (var i = 0; i + pattern.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < pattern.length; j++) {
      if (haystack[i + j] != pattern[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}
