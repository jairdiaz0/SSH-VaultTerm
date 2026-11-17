import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_vault_term/core/security/password_hasher.dart';

void main() {
  // Deliberately cheap parameters: these tests exercise correctness, not cost.
  const fast = Argon2Params(
    memoryKib: 1024,
    iterations: 1,
    parallelism: 1,
    hashLength: 32,
  );

  final hasher = PasswordHasher.direct();

  test('same password, salt and params derive the same tag', () async {
    final salt = Uint8List.fromList(List<int>.generate(16, (i) => i * 3));
    final a = await hasher.hash('correct horse', params: fast, salt: salt);
    final b = await hasher.hash('correct horse', params: fast, salt: salt);

    expect(a.verifier, equals(b.verifier));
    expect(await hasher.verify('correct horse', a), isTrue);
  });

  test(
    'hash produces distinct salts and verifies the right password',
    () async {
      final a = await hasher.hash('s3cret', params: fast);
      final b = await hasher.hash('s3cret', params: fast);

      expect(a.salt, isNot(equals(b.salt)));
      expect(a.verifier, isNot(equals(b.verifier)));
      expect(await hasher.verify('s3cret', a), isTrue);
      expect(await hasher.verify('S3cret', a), isFalse);
      expect(await hasher.verify('', a), isFalse);
    },
  );

  test('verifier length follows the hashLength parameter', () async {
    final record = await hasher.hash(
      'x',
      params: const Argon2Params(
        memoryKib: 1024,
        iterations: 1,
        parallelism: 1,
        hashLength: 24,
      ),
    );
    expect(record.verifier.length, 24);
    expect(record.salt.length, 16);
  });

  test('matches a reference Argon2id implementation (argon2-cffi)', () async {
    // Cross-implementation pin: reference output computed with argon2-cffi
    // (the reference Argon2 implementation) for
    // password='correct horse battery staple', salt=01..10, t=1, m=1024, p=1.
    final record = await hasher.hash(
      'correct horse battery staple',
      params: fast,
      salt: List<int>.generate(16, (i) => i + 1),
    );
    expect(
      record.verifier.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      'c4761aa67118802555059aed26a4670658e2b618125f87a11bd3cfb3d0422b5f',
    );
  });

  test('params survive a JSON round trip', () {
    final json = Argon2Params.baseline.toJson();
    expect(Argon2Params.fromJson(json), Argon2Params.baseline);
  });

  test('utf8 passwords with non-ASCII characters verify', () async {
    final record = await hasher.hash('contraseña-áéíóú-日本語', params: fast);
    expect(await hasher.verify('contraseña-áéíóú-日本語', record), isTrue);
    expect(await hasher.verify('contrasena-aeiou-日本語', record), isFalse);
  });
}
