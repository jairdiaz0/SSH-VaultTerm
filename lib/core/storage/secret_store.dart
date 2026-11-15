/// Abstraction over the platform secret store.
///
/// The app never talks to `flutter_secure_storage` directly: unit tests use the
/// in-memory implementation, and the real one is exercised only where a
/// keychain/credential manager exists. There is no plaintext fallback: if the
/// platform store is unavailable, callers get [AppErrorCode.secureStorageUnavailable].
abstract interface class SecretStore {
  /// Probes the store with a write/read/delete cycle.
  Future<bool> isAvailable();

  Future<void> write(String key, String value);

  Future<String?> read(String key);

  Future<void> delete(String key);

  /// Keys currently stored that start with [prefix].
  Future<List<String>> keysWithPrefix(String prefix);

  /// Deletes every key that starts with [prefix] (profile deletion).
  Future<int> deletePrefix(String prefix);
}

/// Canonical key layout. Never invent ad-hoc keys elsewhere.
abstract final class SecretKeys {
  static const catalogDatabaseKey = 'catalog/dbKey';

  static String profileDatabaseKey(String profileId) =>
      'profile/$profileId/dbKey';

  static String credential(String profileId, String credentialId) =>
      'profile/$profileId/credential/$credentialId';

  /// Prefix covering every secret owned by a profile.
  static String profilePrefix(String profileId) => 'profile/$profileId/';

  static const probeKey = '__probe__/secret_store';
}
