import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../errors/app_exception.dart';
import 'secure_random.dart';

/// Argon2id parameters, persisted next to each verifier so they can be raised
/// later without invalidating existing profiles.
@immutable
class Argon2Params {
  const Argon2Params({
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
    required this.hashLength,
  });

  /// OWASP-aligned baseline (64 MiB, t=3, p=2).
  static const baseline = Argon2Params(
    memoryKib: 65536,
    iterations: 3,
    parallelism: 2,
    hashLength: 32,
  );

  final int memoryKib;
  final int iterations;
  final int parallelism;
  final int hashLength;

  Map<String, Object?> toJson() => {
    'memoryKib': memoryKib,
    'iterations': iterations,
    'parallelism': parallelism,
    'hashLength': hashLength,
  };

  static Argon2Params fromJson(Map<String, Object?> json) => Argon2Params(
    memoryKib: json['memoryKib'] as int,
    iterations: json['iterations'] as int,
    parallelism: json['parallelism'] as int,
    hashLength: json['hashLength'] as int,
  );

  @override
  bool operator ==(Object other) =>
      other is Argon2Params &&
      other.memoryKib == memoryKib &&
      other.iterations == iterations &&
      other.parallelism == parallelism &&
      other.hashLength == hashLength;

  @override
  int get hashCode =>
      Object.hash(memoryKib, iterations, parallelism, hashLength);
}

/// Stored password verifier: salt + derived tag + the parameters that produced
/// them. Never contains the password.
@immutable
class PasswordVerifier {
  const PasswordVerifier({
    required this.salt,
    required this.verifier,
    required this.params,
  });

  final Uint8List salt;
  final Uint8List verifier;
  final Argon2Params params;
}

typedef Argon2Request = ({
  String password,
  List<int> salt,
  Argon2Params params,
});

/// Argon2id password hashing.
///
/// By default the derivation runs in a separate isolate so a 64 MiB Argon2
/// never blocks the UI. Tests use [PasswordHasher.direct] to skip isolate
/// startup cost.
class PasswordHasher {
  PasswordHasher({
    CryptoRandom? random,
    Future<Uint8List> Function(Argon2Request)? derive,
  }) : _random = random ?? CryptoRandom(),
       _deriveRaw = derive ?? _deriveInIsolate;

  /// Runs derivation on the current isolate. Only for tests.
  PasswordHasher.direct({CryptoRandom? random})
    : _random = random ?? CryptoRandom(),
      _deriveRaw = _deriveOnThisIsolate;

  final CryptoRandom _random;
  final Future<Uint8List> Function(Argon2Request request) _deriveRaw;

  static Future<Uint8List> _deriveInIsolate(Argon2Request request) =>
      Isolate.run(() => _deriveOnThisIsolate(request));

  static Future<Uint8List> _deriveOnThisIsolate(Argon2Request request) async {
    final params = request.params;
    if (params.memoryKib < 8 * params.parallelism) {
      fail(AppErrorCode.validation, cause: 'invalid argon2 parameters');
    }
    final algorithm = Argon2id(
      memory: params.memoryKib,
      iterations: params.iterations,
      parallelism: params.parallelism,
      hashLength: params.hashLength,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(request.password)),
      nonce: request.salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// Creates a fresh salt and verifier for [password]. Pass [salt] only where a
  /// fixed salt is required (tests and deterministic re-derivation).
  Future<PasswordVerifier> hash(
    String password, {
    Argon2Params params = Argon2Params.baseline,
    List<int>? salt,
  }) async {
    final effectiveSalt = salt ?? _random.bytes(16);
    final verifier = await _deriveRaw((
      password: password,
      salt: effectiveSalt,
      params: params,
    ));
    return PasswordVerifier(
      salt: Uint8List.fromList(effectiveSalt),
      verifier: verifier,
      params: params,
    );
  }

  /// Verifies [password] against a stored verifier in constant time.
  Future<bool> verify(String password, PasswordVerifier stored) async {
    final candidate = await _deriveRaw((
      password: password,
      salt: stored.salt,
      params: stored.params,
    ));
    return constantTimeEquals(candidate, stored.verifier);
  }
}
