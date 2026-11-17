import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../errors/app_exception.dart';
import '../security/secure_random.dart';
import 'migrations.dart';

/// Single entry point for opening SQLite databases.
///
/// Two invariants that must never be bypassed:
///  1. every database is encrypted with SQLCipher before any statement runs;
///  2. the binary is verified to be SQLCipher, not plain SQLite.
///
/// There is no plaintext mode on purpose: opening a database through this class
/// is the only supported way in the app.
abstract final class EncryptedDatabase {
  static const keyLength = 32;

  /// Generates a new 256-bit database key.
  static Uint8List generateKey([CryptoRandom? random]) =>
      (random ?? CryptoRandom()).bytes(keyLength);

  /// Opens (or creates) the encrypted database at [path].
  static Database open({
    required String path,
    required Uint8List key,
    required MigrationRunner migrations,
  }) {
    _validateKey(key);
    final Database db;
    try {
      db = sqlite3.open(path);
    } catch (error, stackTrace) {
      throw AppException(
        AppErrorCode.databaseFailure,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    try {
      _prepare(db);
      _applyKey(db, key);
      _verifyCipher(db);
      // Force a real read: SQLCipher only validates the key on first access.
      MigrationRunner.userVersion(db);
      _validateReadable(db);
      _configure(db);
      migrations.apply(db);
      return db;
    } catch (error, stackTrace) {
      try {
        db.close();
      } catch (_) {
        // Closing a database that never decrypted may fail; the open error wins.
      }
      if (error is AppException) rethrow;
      if (_isKeyMismatch(error)) {
        throw AppException(
          AppErrorCode.databaseKeyMismatch,
          cause: error,
          stackTrace: stackTrace,
        );
      }
      throw AppException(
        AppErrorCode.databaseFailure,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// In-memory encrypted database, for tests and short-lived operations.
  static Database openInMemory({
    required Uint8List key,
    MigrationRunner? migrations,
  }) {
    _validateKey(key);
    final db = sqlite3.openInMemory();
    try {
      _prepare(db);
      _applyKey(db, key);
      _verifyCipher(db);
      _configure(db);
      migrations?.apply(db);
      return db;
    } catch (error, stackTrace) {
      db.close();
      if (error is AppException) rethrow;
      throw AppException(
        AppErrorCode.databaseFailure,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// SQLCipher version reported by the linked library.
  static String cipherVersion(Database db) {
    final rows = db.select('PRAGMA cipher_version;');
    if (rows.isEmpty) return '';
    return (rows.first.columnAt(0) as String?) ?? '';
  }

  /// Cipher settings pinned so a library upgrade cannot change the defaults
  /// under an existing database.
  static void _prepare(Database db) {
    db.execute('PRAGMA cipher_compatibility = 4;');
    db.execute('PRAGMA cipher_page_size = 4096;');
  }

  /// Forces a real page read: SQLCipher validates the key on first access.
  static void _validateReadable(Database db) {
    db.select('SELECT count(*) FROM sqlite_master;');
  }

  static bool _isKeyMismatch(Object error) {
    if (error is! SqliteException) return false;
    final message = error.message.toLowerCase();
    return message.contains('hmac') ||
        message.contains('decrypt') ||
        message.contains('file is not a database') ||
        message.contains('file is encrypted');
  }

  static void _validateKey(Uint8List key) {
    if (key.length != keyLength) {
      throw AppException(
        AppErrorCode.databaseKeyInvalid,
        cause: 'key must be $keyLength bytes, got ${key.length}',
      );
    }
  }

  static void _applyKey(Database db, Uint8List key) {
    // Raw-key form: SQLCipher takes the 32 bytes directly (plus the per-file
    // salt from the header). No KDF is applied, which is correct and fast when
    // the key is already 256 bits of CSPRNG output.
    db.execute('PRAGMA key = "x\'${toHex(key)}\'";');
  }

  static void _verifyCipher(Database db) {
    final version = cipherVersion(db);
    if (version.isEmpty) {
      throw AppException(
        AppErrorCode.databaseFailure,
        cause: 'linked sqlite is not SQLCipher',
      );
    }
  }

  static void _configure(Database db) {
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA synchronous = NORMAL;');
  }
}
