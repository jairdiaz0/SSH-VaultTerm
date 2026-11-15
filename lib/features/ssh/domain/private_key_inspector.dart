import 'package:dartssh2/dartssh2.dart';

import '../../../core/errors/app_exception.dart';

/// What the app knows about an imported private key.
///
/// Deliberately contains no key material: the PEM never leaves
/// [PrivateKeyInspector.inspect] except when it is handed to the SSH client at
/// connect time.
class PrivateKeyInfo {
  const PrivateKeyInfo({required this.keyType, required this.encrypted});

  /// OpenSSH algorithm name, e.g. `ssh-ed25519`, `ssh-rsa`,
  /// `ecdsa-sha2-nistp256`.
  final String keyType;

  /// Whether the PEM is protected by a passphrase.
  final bool encrypted;

  String get displayType => switch (keyType) {
    _ when keyType.startsWith('ssh-ed25519') => 'Ed25519',
    _ when keyType.startsWith('ssh-rsa') => 'RSA',
    _ when keyType.startsWith('ecdsa-') => 'ECDSA',
    _ => keyType,
  };
}

/// Validates private key files before they are stored in the secret store.
///
/// Supported formats are exactly the ones `dartssh2` 4.1.0 can decode:
/// `OPENSSH PRIVATE KEY`, `RSA PRIVATE KEY` (PKCS#1) and `EC PRIVATE KEY`
/// (SEC1). PKCS#8 (`PRIVATE KEY`), DSA and PuTTY `.ppk` are rejected with a
/// specific code instead of a generic failure, and nothing here logs or
/// echoes the key.
abstract final class PrivateKeyInspector {
  static final _header = RegExp(r'-----BEGIN ([A-Z0-9 ]+)-----');

  static const _supportedLabels = {
    'OPENSSH PRIVATE KEY',
    'RSA PRIVATE KEY',
    'EC PRIVATE KEY',
  };

  /// Validates [pemText] and returns its type, or throws an [AppException]
  /// with a code the UI can translate.
  static PrivateKeyInfo inspect(String pemText, {String? passphrase}) {
    final pem = pemText.trim();
    if (pem.isEmpty) {
      failWith(AppErrorCode.privateKeyInvalid, cause: 'empty key');
    }

    final label = _header.firstMatch(pem)?.group(1);
    if (label == null) {
      failWith(AppErrorCode.privateKeyInvalid, cause: 'no PEM header');
    }
    if (!_supportedLabels.contains(label)) {
      failWith(AppErrorCode.privateKeyUnsupportedFormat, cause: label);
    }

    final encrypted = _isEncrypted(pem);
    final secret = (passphrase?.isEmpty ?? true) ? null : passphrase;
    if (encrypted && secret == null) {
      failWith(AppErrorCode.privateKeyPassphraseRequired);
    }

    final keys = _decode(pem, secret);
    if (keys.isEmpty) {
      failWith(AppErrorCode.privateKeyInvalid, cause: 'no key pair');
    }
    return PrivateKeyInfo(keyType: keys.first.name, encrypted: encrypted);
  }

  /// Decodes the key pairs that [pemText] contains, or throws the same codes
  /// as [inspect].
  ///
  /// Used at connect time, where a key imported earlier may have been stored
  /// with a different passphrase.
  static List<SSHKeyPair> decode(String pemText, {String? passphrase}) {
    final pem = pemText.trim();
    final secret = (passphrase?.isEmpty ?? true) ? null : passphrase;
    final keys = _decode(pem, secret);
    if (keys.isEmpty) {
      failWith(AppErrorCode.privateKeyInvalid, cause: 'no key pair');
    }
    return keys;
  }

  /// True when [pemText] is a supported, passphrase-protected key.
  ///
  /// Used by the import UI to ask for a passphrase before validating; returns
  /// false for anything it cannot classify (the save path reports the error).
  static bool requiresPassphrase(String pemText) {
    final pem = pemText.trim();
    if (pem.isEmpty) return false;
    try {
      return SSHKeyPair.isEncryptedPem(pem);
    } on FormatException {
      return false;
    } on UnsupportedError {
      return false;
    } on SSHKeyDecodeError {
      return false;
    }
  }

  static bool _isEncrypted(String pem) {
    try {
      return SSHKeyPair.isEncryptedPem(pem);
    } on UnsupportedError {
      failWith(AppErrorCode.privateKeyUnsupportedFormat);
    } on FormatException catch (error) {
      failWith(AppErrorCode.privateKeyInvalid, cause: error);
    } on SSHKeyDecodeError catch (error) {
      failWith(AppErrorCode.privateKeyInvalid, cause: error);
    }
  }

  static List<SSHKeyPair> _decode(String pem, String? passphrase) {
    try {
      return SSHKeyPair.fromPem(pem, passphrase);
    } on SSHKeyDecryptError catch (error) {
      // Wrong passphrase, a missing one and a corrupt body share this type, so
      // the message only chooses which user-facing code to show; nothing of the
      // key ever reaches a log.
      final message = error.message.toLowerCase();
      final code = switch (message) {
        _ when message.contains('passphrase') =>
          AppErrorCode.privateKeyPassphraseInvalid,
        _ when message.contains('encrypted') =>
          AppErrorCode.privateKeyPassphraseRequired,
        _ => AppErrorCode.privateKeyInvalid,
      };
      failWith(code, cause: error);
    } on UnsupportedError catch (error) {
      failWith(AppErrorCode.privateKeyUnsupportedFormat, cause: error);
    } on FormatException catch (error) {
      failWith(AppErrorCode.privateKeyInvalid, cause: error);
    } on ArgumentError catch (error) {
      // dartssh2 rejects an empty passphrase for encrypted keys this way.
      failWith(AppErrorCode.privateKeyPassphraseRequired, cause: error);
    } on SSHKeyDecodeError catch (error) {
      failWith(AppErrorCode.privateKeyInvalid, cause: error);
    }
  }
}
