import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/core/errors/app_exception.dart';
import 'package:ssh_client/features/ssh/domain/private_key_inspector.dart';

String key(String name) => File('test/fixtures/keys/$name').readAsStringSync();

void main() {
  group('PrivateKeyInspector.inspect', () {
    test('accepts an unencrypted OpenSSH Ed25519 key', () {
      final info = PrivateKeyInspector.inspect(key('ed25519_test'));

      expect(info.keyType, 'ssh-ed25519');
      expect(info.encrypted, isFalse);
      expect(info.displayType, 'Ed25519');
    });

    test('accepts a PKCS#1 RSA key', () {
      final info = PrivateKeyInspector.inspect(key('rsa_test'));

      expect(info.keyType, 'ssh-rsa');
      expect(info.encrypted, isFalse);
      expect(info.displayType, 'RSA');
    });

    test('accepts a SEC1 EC key', () {
      final info = PrivateKeyInspector.inspect(key('ec_test'));

      expect(info.keyType, startsWith('ecdsa-sha2-'));
      expect(info.displayType, 'ECDSA');
    });

    test('accepts an encrypted key with its passphrase', () {
      final info = PrivateKeyInspector.inspect(
        key('ed25519_test_encrypted'),
        passphrase: 'test-passphrase-123',
      );

      expect(info.keyType, 'ssh-ed25519');
      expect(info.encrypted, isTrue);
    });

    test('requires a passphrase for an encrypted key', () {
      expect(
        () => PrivateKeyInspector.inspect(key('ed25519_test_encrypted')),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.privateKeyPassphraseRequired,
          ),
        ),
      );
    });

    test('treats an empty passphrase as missing', () {
      expect(
        () => PrivateKeyInspector.inspect(
          key('ed25519_test_encrypted'),
          passphrase: '',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.privateKeyPassphraseRequired,
          ),
        ),
      );
    });

    test('reports a wrong passphrase', () {
      expect(
        () => PrivateKeyInspector.inspect(
          key('ed25519_test_encrypted'),
          passphrase: 'wrong-passphrase',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.privateKeyPassphraseInvalid,
          ),
        ),
      );
    });

    test('rejects a PKCS#8 key with a specific code', () {
      const pkcs8 =
          '-----BEGIN PRIVATE KEY-----\n'
          'AAAA\n'
          '-----END PRIVATE KEY-----\n';

      expect(
        () => PrivateKeyInspector.inspect(pkcs8),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.privateKeyUnsupportedFormat,
          ),
        ),
      );
    });

    test('rejects text that is not a PEM file', () {
      expect(
        () => PrivateKeyInspector.inspect('ssh-rsa AAAAB3NzaC1yc2E='),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.privateKeyInvalid,
          ),
        ),
      );
    });

    test('rejects an empty input', () {
      expect(
        () => PrivateKeyInspector.inspect('   \n'),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.privateKeyInvalid,
          ),
        ),
      );
    });

    test('never leaks key material in the error description', () {
      final pem = key('ed25519_test_encrypted');
      try {
        PrivateKeyInspector.inspect(pem);
        fail('expected a failure');
      } on AppException catch (error) {
        expect(error.description, isNot(contains('BEGIN')));
        expect(error.toString(), isNot(contains('OPENSSH')));
      }
    });
  });

  group('PrivateKeyInspector.decode', () {
    test('returns the key pair for authentication', () {
      final keys = PrivateKeyInspector.decode(key('ed25519_test'));

      expect(keys, hasLength(1));
      expect(keys.first.name, 'ssh-ed25519');
    });

    test('throws the passphrase code when the stored key needs one', () {
      expect(
        () => PrivateKeyInspector.decode(key('ed25519_test_encrypted')),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.privateKeyPassphraseRequired,
          ),
        ),
      );
    });
  });
}
