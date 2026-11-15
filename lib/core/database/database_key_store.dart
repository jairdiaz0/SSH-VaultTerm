import 'dart:typed_data';

import '../database/encrypted_database.dart';
import '../errors/app_exception.dart';
import '../security/secure_random.dart';
import '../storage/secret_store.dart';

/// Issues and loads database keys, which live only in the platform secret
/// store. Keys are never written to SQLite, files, logs or backups.
class DatabaseKeyStore {
  DatabaseKeyStore({required this.secrets, CryptoRandom? random})
    : random = random ?? CryptoRandom();

  final SecretStore secrets;
  final CryptoRandom random;

  /// Returns the catalog key, creating it on first launch.
  Future<Uint8List> catalogKey() => _getOrCreate(SecretKeys.catalogDatabaseKey);

  /// Returns the key of [profileId], creating it on first launch.
  Future<Uint8List> profileKey(String profileId) =>
      _getOrCreate(SecretKeys.profileDatabaseKey(profileId));

  /// Removes every secret owned by a profile (DB key and credentials).
  Future<int> forgetProfile(String profileId) =>
      secrets.deletePrefix(SecretKeys.profilePrefix(profileId));

  Future<Uint8List> _getOrCreate(String storedKey) async {
    final existing = await secrets.read(storedKey);
    if (existing != null && existing.isNotEmpty) {
      final bytes = fromHex(existing);
      if (bytes.length != EncryptedDatabase.keyLength) {
        throw AppException(
          AppErrorCode.databaseKeyInvalid,
          cause: 'stored key has ${bytes.length} bytes',
        );
      }
      return bytes;
    }
    final key = random.bytes(EncryptedDatabase.keyLength);
    await secrets.write(storedKey, toHex(key));
    return key;
  }
}
