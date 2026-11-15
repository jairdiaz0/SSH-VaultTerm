@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/core/errors/app_exception.dart';
import 'package:ssh_client/features/ssh/data/ssh_connection.dart';
import 'package:ssh_client/features/ssh/domain/host_key_verifier.dart';
import 'package:ssh_client/features/ssh/domain/ssh_connection_state.dart';
import 'package:ssh_client/shared/models/known_host.dart';

import '../../support/ssh_integration_harness.dart';
import '../../support/ssh_test_server.dart';

void main() {
  final server = SshTestServer.load();

  group('SSH integration: authentication and host keys', () {
    final config = server;
    if (config == null) return;

    late SshIntegrationHarness harness;

    setUp(() => harness = SshIntegrationHarness.create(config));
    tearDown(() => harness.dispose());

    test(
      'connects with a password, accepts the host key and runs a command',
      () async {
        final connection = await harness.addConnection(
          password: config.password,
        );
        final dir = harness.newSandbox();
        final states = <SshConnectionState>[];
        HostKeyChallenge? challenge;
        SshConnection? ssh;
        try {
          ssh = await harness.service.connect(
            connection,
            confirmHostKey: (candidate) async {
              challenge = candidate;
              return true;
            },
            onProgress: states.add,
          );

          expect(ssh.isOpen, isTrue);
          expect(
            states.map((state) => state.status),
            containsAllInOrder([
              SshConnectionStatus.connecting,
              SshConnectionStatus.awaitingHostKey,
              SshConnectionStatus.authenticating,
              SshConnectionStatus.connected,
            ]),
          );

          expect(challenge, isNotNull);
          expect(challenge!.status, HostKeyStatus.untrusted);
          expect(
            challenge!.fingerprint,
            matches(RegExp(r'^SHA256:[A-Za-z0-9+/]+=*$')),
          );
          expect(challenge!.hostname, config.host);
          expect(challenge!.port, config.port);

          final stored = harness.knownHosts.find(
            connectionId: connection.id,
            hostname: connection.hostname,
            port: connection.port,
          );
          expect(stored, isNotNull);
          expect(stored!.fingerprint, challenge!.fingerprint);

          final result = await ssh.execute(
            'mkdir -p $dir && printf ok > $dir/probe.txt && cat $dir/probe.txt',
          );
          expect(result.exitCode, 0);
          expect(result.stdout.trim(), 'ok');
        } finally {
          if (ssh != null) {
            await ssh.execute('rm -rf $dir');
            await ssh.close();
          }
        }

        expect(harness.logs.join('\n'), isNot(contains(config.password)));
      },
    );

    test('does not ask again once the host key is trusted', () async {
      final connection = await harness.addConnection(password: config.password);
      final first = await harness.service.connect(
        connection,
        confirmHostKey: (_) async => true,
      );
      await first.close();

      var prompts = 0;
      final second = await harness.service.connect(
        connection,
        confirmHostKey: (_) async {
          prompts++;
          return true;
        },
      );
      addTearDown(second.close);

      expect(prompts, 0);
      expect(second.state.value.status, SshConnectionStatus.connected);
    });

    test('blocks a changed host key without offering to accept it', () async {
      final connection = await harness.addConnection(password: config.password);
      harness.knownHosts.accept(
        KnownHost(
          id: 'known-1',
          connectionId: connection.id,
          hostname: connection.hostname,
          port: connection.port,
          keyType: 'ssh-ed25519',
          fingerprint: 'SHA256:not-the-real-one',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      var prompts = 0;
      await expectLater(
        harness.service.connect(
          connection,
          confirmHostKey: (_) async {
            prompts++;
            return true;
          },
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.hostKeyChanged,
          ),
        ),
      );

      expect(prompts, 0, reason: 'a changed key is never a choice');
      final stored = harness.knownHosts.find(
        connectionId: connection.id,
        hostname: connection.hostname,
        port: connection.port,
      );
      expect(stored!.fingerprint, 'SHA256:not-the-real-one');
    });

    test('reports a rejected password as authFailed', () async {
      final connection = await harness.addConnection(
        password: 'wrong-password',
      );

      // Exactly two attempts: the test account must not trip fail2ban.
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          harness.service.connect(
            connection,
            confirmHostKey: (_) async => true,
          ),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppErrorCode.authFailed,
            ),
          ),
        );
      }
    });
  }, skip: server == null ? 'SSH_TEST_* not configured (see .env.test)' : null);
}
