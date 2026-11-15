import 'dart:typed_data';

import '../database/encrypted_database.dart';
import '../errors/app_exception.dart';
import '../security/secure_random.dart';
import '../storage/secret_store.dart';

/// Issues and loads database keys, which live only in the platform secret
/// store. Keys are never written to SQLite, files, logs or backups.
///
/// Creating and loading are deliberately separate: opening an existing database
/// must never mint a new key (that silently produces SQLCipher hmac failures on
/// the next read). Callers choose [createCatalogKey]/[createProfileKey] only when
/// they are creating the file, and [loadCatalogKey]/[loadProfileKey] otherwise.
class DatabaseKeyStore {
  DatabaseKeyStore({required this.secrets, CryptoRandom? random})
    : random = random ?? CryptoRandom();

  final SecretStore secrets;
  final CryptoRandom random;

  Future<Uint8List> createCatalogKey() =>
      _create(SecretKeys.catalogDatabaseKey);

  Future<Uint8List> loadCatalogKey() => _load(SecretKeys.catalogDatabaseKey);

  Future<bool> hasCatalogKey() async =>
      (await secrets.read(SecretKeys.catalogDatabaseKey)) != null;

  Future<void> saveCatalogKey(Uint8List key) =>
      _save(SecretKeys.catalogDatabaseKey, key);

  Future<Uint8List> createProfileKey(String profileId) =>
      _create(SecretKeys.profileDatabaseKey(profileId));

  Future<Uint8List> loadProfileKey(String profileId) =>
      _load(SecretKeys.profileDatabaseKey(profileId));

  Future<bool> hasProfileKey(String profileId) async =>
      (await secrets.read(SecretKeys.profileDatabaseKey(profileId))) != null;

  Future<void> saveProfileKey(String profileId, Uint8List key) =>
      _save(SecretKeys.profileDatabaseKey(profileId), key);

  /// Removes every secret owned by a profile (DB key and credentials).
  Future<int> forgetProfile(String profileId) =>
      secrets.deletePrefix(SecretKeys.profilePrefix(profileId));

  Future<Uint8List> _load(String storedKey) async {
    final existing = await secrets.read(storedKey);
    if (existing == null || existing.isEmpty) {
      throw AppException(
        AppErrorCode.databaseKeyMissing,
        cause: 'no stored key for $storedKey',
      );
    }
    return _decode(existing);
  }

  Future<Uint8List> _create(String storedKey) async {
    final existing = await secrets.read(storedKey);
    if (existing != null && existing.isNotEmpty) {
      throw AppException(
        AppErrorCode.databaseKeyOrphan,
        cause: 'key already exists for $storedKey',
      );
    }
    final key = random.bytes(EncryptedDatabase.keyLength);
    await secrets.write(storedKey, toHex(key));
    return key;
  }

  Future<void> _save(String storedKey, Uint8List key) async {
    if (key.length != EncryptedDatabase.keyLength) {
      throw AppException(
        AppErrorCode.databaseKeyInvalid,
        cause: 'key must be ${EncryptedDatabase.keyLength} bytes',
      );
    }
    await secrets.write(storedKey, toHex(key));
  }

  Uint8List _decode(String stored) {
    final Uint8List bytes;
    try {
      bytes = fromHex(stored);
    } catch (error) {
      throw AppException(AppErrorCode.databaseKeyInvalid, cause: error);
    }
    if (bytes.length != EncryptedDatabase.keyLength) {
      throw AppException(
        AppErrorCode.databaseKeyInvalid,
        cause: 'stored key has ${bytes.length} bytes',
      );
    }
    return bytes;
  }
}
