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
  SecureStorageSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'ssh_client'),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<bool> isAvailable() async {
    try {
      await _storage.write(key: SecretKeys.probeKey, value: 'ok');
      final value = await _storage.read(key: SecretKeys.probeKey);
      await _storage.delete(key: SecretKeys.probeKey);
      return value == 'ok';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
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
      return await _storage.read(key: key);
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
      await _storage.delete(key: key);
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
      return all.keys.where((key) => key.startsWith(prefix)).toList()..sort();
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
