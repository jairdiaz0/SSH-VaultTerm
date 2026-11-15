import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../errors/app_exception.dart';
import 'secret_store.dart';

/// Real [SecretStore] backed by the operating system keystore.
///
/// Platform requirements (see docs/DECISIONS.md):
/// - Windows: Credential Manager / DPAPI, no extra setup.
/// - macOS: Keychain access entitlement in the runner.
/// - Linux: libsecret and an unlocked keyring.
/// - Android: minSdk of the plugin; values are encrypted per namespace.
///
/// This class must never be used as the only implementation in tests: without
/// a running app its platform channel is unavailable.
class SecureStorageSecretStore implements SecretStore {
  SecureStorageSecretStore({FlutterSecureStorage? storage, String? namespace})
    : namespace = namespace ?? _environmentNamespace(),
      _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'ssh_client'),
          );

  /// Overrides the key namespace. Integration tests and development runs use a
  /// throwaway value so they never read or delete real secrets.
  static const namespaceEnvironment = 'SSH_CLIENT_SECRET_NAMESPACE';

  final String namespace;
  final FlutterSecureStorage _storage;

  static String _environmentNamespace() =>
      (Platform.environment[namespaceEnvironment] ?? '').trim();

  String _key(String key) => SecretKeys.namespaced(namespace, key);

  @override
  Future<bool> isAvailable() async {
    final probe = _key(SecretKeys.probeKey);
    try {
      await _storage.write(key: probe, value: 'ok');
      final value = await _storage.read(key: probe);
      await _storage.delete(key: probe);
      return value == 'ok';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: _key(key), value: value);
    } catch (error, stackTrace) {
      throw AppException(
        AppErrorCode.secureStorageUnavailable,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: _key(key));
    } catch (error, stackTrace) {
      throw AppException(
        AppErrorCode.secureStorageUnavailable,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: _key(key));
    } catch (error, stackTrace) {
      throw AppException(
        AppErrorCode.secureStorageUnavailable,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<String>> keysWithPrefix(String prefix) async {
    try {
      final all = await _storage.readAll();
      final namespaced = _key(prefix);
      final keys = <String>[];
      for (final key in all.keys) {
        final stripped = SecretKeys.unnamespace(namespace, key);
        if (stripped != null && key.startsWith(namespaced)) {
          keys.add(stripped);
        }
      }
      return keys..sort();
    } catch (error, stackTrace) {
      throw AppException(
        AppErrorCode.secureStorageUnavailable,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<int> deletePrefix(String prefix) async {
    final keys = await keysWithPrefix(prefix);
    for (final key in keys) {
      await delete(key);
    }
    return keys.length;
  }
}
