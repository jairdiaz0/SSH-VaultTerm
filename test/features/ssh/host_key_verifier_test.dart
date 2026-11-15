import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ssh_client/core/database/encrypted_database.dart';
import 'package:ssh_client/core/database/schemas.dart';
import 'package:ssh_client/features/connections/data/connection_repository.dart';
import 'package:ssh_client/features/ssh/data/known_host_repository.dart';
import 'package:ssh_client/features/ssh/domain/host_key_verifier.dart';
import 'package:ssh_client/shared/models/connection.dart';
import 'package:ssh_client/shared/models/known_host.dart';

Uint8List fingerprintOf(String value) => Uint8List.fromList(utf8.encode(value));

void main() {
  late Database db;
  late KnownHostRepository knownHosts;
  final now = DateTime.utc(2026, 1, 1);

  setUp(() {
    db = EncryptedDatabase.openInMemory(
      key: EncryptedDatabase.generateKey(),
      migrations: ProfileSchema.runner,
    );
    knownHosts = KnownHostRepository(db);
    final connections = ConnectionRepository(db);
    for (final id in ['conn-1', 'conn-a', 'conn-b']) {
      connections.insert(
        Connection(
          id: id,
          name: 'Server $id',
          hostname: 'example.com',
          port: 22,
          username: 'root',
          authType: AuthenticationType.password,
          position: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  });

  tearDown(() => db.close());

  TofuHostKeyVerifier verifier({
    required Future<bool> Function(HostKeyChallenge) confirm,
    String connectionId = 'conn-1',
    String hostname = 'example.com',
    int port = 22,
  }) => TofuHostKeyVerifier(
    connectionId: connectionId,
    hostname: hostname,
    port: port,
    knownHosts: knownHosts,
    confirm: confirm,
    clock: () => now,
  );

  KnownHost stored(String fingerprint, {String connectionId = 'conn-1'}) =>
      KnownHost(
        id: 'known-1',
        connectionId: connectionId,
        hostname: 'example.com',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprint: fingerprint,
        createdAt: now,
      );

  test('asks once for an unknown key and stores it when accepted', () async {
    final challenges = <HostKeyChallenge>[];
    final subject = verifier(
      confirm: (challenge) async {
        challenges.add(challenge);
        return true;
      },
    );

    final accepted = await subject.verify(
      'ssh-ed25519',
      fingerprintOf('SHA256:first'),
    );

    expect(accepted, isTrue);
    expect(challenges, hasLength(1));
    expect(challenges.single.status, HostKeyStatus.untrusted);
    expect(challenges.single.hostname, 'example.com');
    expect(challenges.single.port, 22);
    expect(challenges.single.keyType, 'ssh-ed25519');
    expect(challenges.single.fingerprint, 'SHA256:first');
    expect(subject.status, HostKeyStatus.trusted);

    final row = knownHosts.find(
      connectionId: 'conn-1',
      hostname: 'example.com',
      port: 22,
    );
    expect(row, isNotNull);
    expect(row!.fingerprint, 'SHA256:first');
    expect(row.keyType, 'ssh-ed25519');
  });

  test('does not ask again when the stored fingerprint matches', () async {
    knownHosts.accept(stored('SHA256:first'));
    var prompts = 0;
    final subject = verifier(
      confirm: (_) async {
        prompts++;
        return true;
      },
    );

    final accepted = await subject.verify(
      'ssh-ed25519',
      fingerprintOf('SHA256:first'),
    );

    expect(accepted, isTrue);
    expect(prompts, 0);
    expect(subject.status, HostKeyStatus.trusted);
    expect(knownHosts.count(), 1);
  });

  test('stores nothing when the user declines an unknown key', () async {
    final subject = verifier(confirm: (_) async => false);

    final accepted = await subject.verify(
      'ssh-rsa',
      fingerprintOf('SHA256:first'),
    );

    expect(accepted, isFalse);
    expect(subject.status, HostKeyStatus.untrusted);
    expect(knownHosts.count(), 0);
  });

  test('blocks a changed fingerprint without ever asking', () async {
    knownHosts.accept(stored('SHA256:old'));
    var prompts = 0;
    final subject = verifier(
      confirm: (_) async {
        prompts++;
        return true;
      },
    );

    final accepted = await subject.verify(
      'ssh-ed25519',
      fingerprintOf('SHA256:new'),
    );

    expect(accepted, isFalse);
    expect(
      prompts,
      0,
      reason: 'a changed key must never be offered as a choice',
    );
    expect(subject.status, HostKeyStatus.changed);
    expect(subject.lastChallenge!.isChanged, isTrue);
    expect(subject.lastChallenge!.trustedFingerprint, 'SHA256:old');
    expect(subject.lastChallenge!.fingerprint, 'SHA256:new');

    final row = knownHosts.find(
      connectionId: 'conn-1',
      hostname: 'example.com',
      port: 22,
    );
    expect(row!.fingerprint, 'SHA256:old', reason: 'stored key never replaced');
  });

  test('keeps separate entries per connection', () async {
    knownHosts.accept(stored('SHA256:a', connectionId: 'conn-a'));
    final subject = verifier(
      connectionId: 'conn-b',
      confirm: (_) async => true,
    );

    final accepted = await subject.verify(
      'ssh-ed25519',
      fingerprintOf('SHA256:b'),
    );

    expect(accepted, isTrue);
    expect(knownHosts.count(), 2);
    expect(knownHosts.byConnection('conn-a').single.fingerprint, 'SHA256:a');
    expect(knownHosts.byConnection('conn-b').single.fingerprint, 'SHA256:b');
  });

  test(
    'a changed fingerprint is blocked even after a previous acceptance',
    () async {
      final subject = verifier(confirm: (_) async => true);
      await subject.verify('ssh-ed25519', fingerprintOf('SHA256:first'));

      final second = TofuHostKeyVerifier(
        connectionId: 'conn-1',
        hostname: 'example.com',
        port: 22,
        knownHosts: knownHosts,
        confirm: (_) async => true,
        clock: () => now,
      );
      final accepted = await second.verify(
        'ssh-ed25519',
        fingerprintOf('SHA256:other'),
      );

      expect(accepted, isFalse);
      expect(second.status, HostKeyStatus.changed);
    },
  );
}
