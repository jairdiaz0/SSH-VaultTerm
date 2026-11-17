import 'dart:async';

import 'package:ssh_vault_term/core/storage/secret_store.dart';

/// Test double for [SecretStore]. Never used by the app.
class InMemorySecretStore implements SecretStore {
  InMemorySecretStore({this.available = true});

  final Map<String, String> _values = {};
  bool available;

  /// When true, every operation throws as an unavailable platform store would.
  bool failOnUse = false;

  int writeCount = 0;

  @override
  Future<bool> isAvailable() async {
    if (failOnUse) return false;
    return available;
  }

  @override
  Future<void> write(String key, String value) async {
    if (!available || failOnUse) {
      throw StateError('secure storage unavailable');
    }
    writeCount++;
    _values[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    if (!available || failOnUse) {
      throw StateError('secure storage unavailable');
    }
    return _values[key];
  }

  @override
  Future<void> delete(String key) async {
    if (!available || failOnUse) {
      throw StateError('secure storage unavailable');
    }
    _values.remove(key);
  }

  @override
  Future<List<String>> keysWithPrefix(String prefix) async {
    if (!available || failOnUse) {
      throw StateError('secure storage unavailable');
    }
    return _values.keys.where((k) => k.startsWith(prefix)).toList()..sort();
  }

  @override
  Future<int> deletePrefix(String prefix) async {
    final keys = await keysWithPrefix(prefix);
    for (final key in keys) {
      _values.remove(key);
    }
    return keys.length;
  }

  /// Snapshot for assertions.
  Map<String, String> get snapshot => Map.unmodifiable(_values);
}
