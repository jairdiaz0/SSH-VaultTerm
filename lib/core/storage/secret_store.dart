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

  /// Temporary namespace used while an import is being built.
  static String stagingPrefix(String stagingId) => 'staging/$stagingId/';

  /// Copy of the previous keys/credentials while an import can still fail.
  static String backupPrefix(String backupId) => 'backup/$backupId/';

  static String profileKeyIn(String prefix, String profileId) =>
      '${prefix}profile/$profileId/dbKey';

  static String credentialIn(
    String prefix,
    String profileId,
    String credentialId,
  ) => '${prefix}profile/$profileId/credential/$credentialId';

  /// Prefixes [key] with an isolated namespace.
  ///
  /// Integration tests and development runs set `SSH_CLIENT_SECRET_NAMESPACE`
  /// so they never read or delete the user's real secrets. An empty namespace
  /// keeps the production layout untouched.
  static String namespaced(String namespace, String key) =>
      namespace.isEmpty ? key : '$namespace/$key';

  /// Removes [namespace] from a full key, or returns null when it does not
  /// belong to it.
  static String? unnamespace(String namespace, String key) {
    if (namespace.isEmpty) return key;
    final prefix = '$namespace/';
    return key.startsWith(prefix) ? key.substring(prefix.length) : null;
  }
}
