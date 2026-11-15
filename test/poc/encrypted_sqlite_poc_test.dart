import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Phase 0 proof of concept: the app must run against a really encrypted
/// SQLite. This test proves, with the exact dependency the app ships, that:
///  1. the bundled SQLite is SQLCipher (not plain SQLite),
///  2. a database created with a key does not contain plaintext markers,
///  3. the wrong key cannot read it,
///  4. the right key can, using the raw-key form the app stores.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sqlcipher_poc_');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test('bundled sqlite is compiled with SQLCipher', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);

    final version = db.select('PRAGMA cipher_version;');
    expect(
      version,
      isNotEmpty,
      reason: 'PRAGMA cipher_version returned no rows: this is NOT SQLCipher.',
    );
    final cipher = version.first['cipher_version'] as String;
    expect(cipher, isNotEmpty);
    // ignore: avoid_print
    print('SQLCipher version: $cipher');
  });

  test('database file does not contain plaintext markers', () {
    final path = p.join(dir.path, 'catalog.db');
    const marker = 'SUPER_SECRET_MARKER_1234';

    final db = sqlite3.open(path);
    db.execute("PRAGMA key = 'correct horse battery staple';");
    db.execute('CREATE TABLE secrets (value TEXT NOT NULL);');
    db.execute('INSERT INTO secrets (value) VALUES (?)', [marker]);
    db.close();

    final bytes = File(path).readAsBytesSync();
    expect(
      _containsAscii(bytes, marker),
      isFalse,
      reason: 'The marker is readable in the raw file: it is not encrypted.',
    );
    // A SQLCipher database does not start with the plain SQLite header.
    expect(
      utf8.decode(bytes.sublist(0, 15), allowMalformed: true),
      isNot(startsWith('SQLite format 3')),
    );
  });

  test('wrong key fails, right raw key succeeds', () {
    final path = p.join(dir.path, 'isolated.db');
    final rawKey = Uint8List.fromList(
      List<int>.generate(32, (i) => (i * 7 + 3) & 0xff),
    );
    final hex = rawKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final pragma = "x'$hex'";

    final writer = sqlite3.open(path);
    writer.execute('PRAGMA key = "$pragma";');
    writer.execute('CREATE TABLE t (v TEXT NOT NULL);');
    writer.execute('INSERT INTO t (v) VALUES (?)', ['hello']);
    writer.close();

    final wrong = sqlite3.open(path);
    wrong.execute("PRAGMA key = 'definitely-the-wrong-key';");
    expect(
      () => wrong.select('SELECT v FROM t;'),
      throwsA(isA<SqliteException>()),
      reason: 'Opening an encrypted database with the wrong key must fail.',
    );
    try {
      wrong.close();
    } on SqliteException {
      // Closing a database that failed to decrypt may itself fail.
    }

    final right = sqlite3.open(path);
    right.execute('PRAGMA key = "$pragma";');
    final rows = right.select('SELECT v FROM t;');
    expect(rows.first['v'], 'hello');
    right.close();
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
