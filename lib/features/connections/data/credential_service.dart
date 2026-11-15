import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/storage/secret_store.dart';

/// Secret payload of a credential. Lives only in the platform secret store.
class CredentialSecret {
  const CredentialSecret({this.password, this.privateKeyPem, this.passphrase});

  final String? password;
  final String? privateKeyPem;
  final String? passphrase;

  bool get isEmpty =>
      (password == null || password!.isEmpty) &&
      (privateKeyPem == null || privateKeyPem!.isEmpty);

  Map<String, Object?> toJson() => {
    'v': 1,
    if (password != null) 'password': password,
    if (privateKeyPem != null) 'privateKeyPem': privateKeyPem,
    if (passphrase != null) 'passphrase': passphrase,
  };

  static CredentialSecret fromJson(Map<String, Object?> json) =>
      CredentialSecret(
        password: json['password'] as String?,
        privateKeyPem: json['privateKeyPem'] as String?,
        passphrase: json['passphrase'] as String?,
      );
}

/// Credential CRUD restricted to one profile namespace.
///
/// Keys are `profile/{profileId}/credential/{credentialId}`; nothing here can
/// read another profile's secrets because the profile id is part of the key.
class CredentialService {
  CredentialService({required this.secrets, this.uuid = const Uuid()});

  final SecretStore secrets;
  final Uuid uuid;

  String newCredentialId() => uuid.v4();

  Future<void> save({
    required String profileId,
    required String credentialId,
    required CredentialSecret secret,
  }) async {
    if (secret.isEmpty) {
      fail(AppErrorCode.validation, cause: 'empty credential');
    }
    await secrets.write(
      SecretKeys.credential(profileId, credentialId),
      jsonEncode(secret.toJson()),
    );
  }

  /// Loads a credential. Returns null when it does not exist for this profile.
  Future<CredentialSecret?> load({
    required String profileId,
    required String credentialId,
  }) async {
    final raw = await secrets.read(
      SecretKeys.credential(profileId, credentialId),
    );
    if (raw == null) return null;
    return CredentialSecret.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  Future<bool> exists({
    required String profileId,
    required String credentialId,
  }) async =>
      await secrets.read(SecretKeys.credential(profileId, credentialId)) !=
      null;

  Future<void> delete({
    required String profileId,
    required String credentialId,
  }) => secrets.delete(SecretKeys.credential(profileId, credentialId));

  /// Ids of every credential stored for [profileId].
  Future<List<String>> listIds(String profileId) async {
    final prefix = '${SecretKeys.profilePrefix(profileId)}credential/';
    final keys = await secrets.keysWithPrefix(prefix);
    return keys.map((key) => key.substring(prefix.length)).toList()..sort();
  }

  /// Removes every credential of a profile. Used by profile deletion and by the
  /// "replace profile" import mode.
  Future<int> deleteAll(String profileId) =>
      secrets.deletePrefix('${SecretKeys.profilePrefix(profileId)}credential/');
}
