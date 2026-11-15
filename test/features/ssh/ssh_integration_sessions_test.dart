@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/features/ssh/data/ssh_connection.dart';
import 'package:ssh_client/features/ssh/domain/ssh_connection_state.dart';
import 'package:ssh_client/shared/models/connection.dart';
import 'package:uuid/uuid.dart';

import '../../support/ssh_integration_harness.dart';
import '../../support/ssh_test_server.dart';

void main() {
  final server = SshTestServer.load();

  group('SSH integration: keys and concurrent sessions', () {
    final config = server;
    if (config == null) return;

    late SshIntegrationHarness harness;

    setUp(() => harness = SshIntegrationHarness.create(config));
    tearDown(() => harness.dispose());

    test('connects with an imported Ed25519 key', () async {
      final setupConnection = await harness.addConnection(
        id: 'conn-setup',
        password: config.password,
      );
      final comment = 'opencode-test-${const Uuid().v4()}';
      final keys = Directory.systemTemp.createTempSync('ssh_client_key_');
      final privateKeyFile = File('${keys.path}${Platform.pathSeparator}id');
      final generated = await Process.run('ssh-keygen', [
        '-q',
        '-t',
        'ed25519',
        '-N',
        '',
        '-C',
        comment,
        '-f',
        privateKeyFile.path,
      ]);
      expect(generated.exitCode, 0, reason: 'ssh-keygen must be available');
      final publicKey = File('${privateKeyFile.path}.pub')
          .readAsStringSync()
          .trim();

      final setup = await harness.service.connect(
        setupConnection,
        confirmHostKey: (_) async => true,
      );
      try {
        final added = await setup.execute(
          "mkdir -p ~/.ssh && chmod 700 ~/.ssh && printf '%s\\n' '$publicKey' "
          '>> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys',
        );
        expect(added.exitCode, 0, reason: added.stderr);

        final keyConnection = await harness.addConnection(
          id: 'conn-key',
          authType: AuthenticationType.privateKey,
          privateKeyPem: privateKeyFile.readAsStringSync(),
        );

        SshConnection? keySession;
        final dir = harness.newSandbox();
        try {
          keySession = await harness.service.connect(
            keyConnection,
            confirmHostKey: (_) async => true,
          );
          final result = await keySession.execute('mkdir -p $dir && whoami');
          expect(result.exitCode, 0);
          expect(result.stdout.trim(), config.username);
        } finally {
          if (keySession != null) {
            await keySession.execute('rm -rf $dir');
            await keySession.close();
          }
        }
      } finally {
        await setup.execute(
          "grep -v '$comment' ~/.ssh/authorized_keys > ~/.ssh/keys.tmp; "
          'mv ~/.ssh/keys.tmp ~/.ssh/authorized_keys; true',
        );
        await setup.close();
        keys.deleteSync(recursive: true);
      }
    });

    test(
      'keeps concurrent sessions independent and closes them in order',
      () async {
        final firstConnection = await harness.addConnection(
          id: 'conn-a',
          password: config.password,
        );
        final secondConnection = await harness.addConnection(
          id: 'conn-b',
          password: config.password,
        );
        final dir = harness.newSandbox();

        final first = await harness.service.connect(
          firstConnection,
          confirmHostKey: (_) async => true,
        );
        final second = await harness.service.connect(
          secondConnection,
          confirmHostKey: (_) async => true,
        );
        addTearDown(first.close);
        addTearDown(second.close);

        final a = await first.execute(
          'mkdir -p $dir && printf a > $dir/a.txt && cat $dir/a.txt',
        );
        final b = await second.execute(
          'mkdir -p $dir && printf b > $dir/b.txt && cat $dir/b.txt',
        );
        expect(a.stdout.trim(), 'a');
        expect(b.stdout.trim(), 'b');

        await first.close();
        expect(first.state.value.status, SshConnectionStatus.disconnected);
        expect(first.isOpen, isFalse);

        final stillWorks = await second.execute('cat $dir/b.txt');
        expect(stillWorks.stdout.trim(), 'b');

        await second.execute('rm -rf $dir');
      },
    );

    test('reports an unexpected transport loss', () async {
      final connection = await harness.addConnection(password: config.password);
      final ssh = await harness.service.connect(
        connection,
        confirmHostKey: (_) async => true,
      );

      ssh.client.socket.destroy();
      for (var i = 0; i < 50 && !ssh.state.value.isTerminal; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      expect(
        ssh.state.value.status,
        SshConnectionStatus.disconnectedUnexpectedly,
      );
      ssh.dispose();
    });
  }, skip: server == null ? 'SSH_TEST_* not configured (see .env.test)' : null);
}
