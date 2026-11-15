@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/features/terminal/data/remote_terminal.dart';

import '../../support/ssh_integration_harness.dart';
import '../../support/ssh_test_server.dart';

/// Polls the emulator buffer until [predicate] holds or the timeout expires.
Future<bool> waitFor(
  RemoteTerminal terminal,
  bool Function(String bufferText) predicate, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (predicate(terminal.terminal.buffer.getText())) return true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return predicate(terminal.terminal.buffer.getText());
}

void main() {
  final server = SshTestServer.load();

  group('Terminal integration (real pty)', () {
    final config = server;
    if (config == null) return;

    late SshIntegrationHarness harness;

    setUp(() => harness = SshIntegrationHarness.create(config));
    tearDown(() => harness.dispose());

    test('runs a real shell with bidirectional I/O and resize', () async {
      final connection = await harness.addConnection(password: config.password);
      final ssh = await harness.service.connect(
        connection,
        confirmHostKey: (_) async => true,
      );
      final remote = await RemoteTerminal.open(ssh, columns: 80, rows: 24);
      try {
        remote.terminal.textInput('stty size\r');
        expect(
          await waitFor(remote, (text) => text.contains('24 80')),
          isTrue,
          reason:
              'the pty must start at the size we requested\n'
              '${remote.terminal.buffer.getText()}',
        );

        remote.resize(100, 30);
        remote.terminal.textInput('stty size\r');
        expect(
          await waitFor(remote, (text) => text.contains('30 100')),
          isTrue,
          reason:
              'resize must reach the server\n'
              '${remote.terminal.buffer.getText()}',
        );

        remote.terminal.textInput('printf "MARK-%s\\n" 42\r');
        expect(
          await waitFor(remote, (text) => text.contains('MARK-42')),
          isTrue,
        );

        remote.terminal.textInput('printf "acentos: áéíóú\\n"\r');
        expect(
          await waitFor(remote, (text) => text.contains('acentos: áéíóú')),
          isTrue,
          reason: 'UTF-8 must survive the pty round trip',
        );
      } finally {
        await remote.close();
      }

      // Closing the terminal channel must not take the SSH session with it.
      final after = await ssh.execute('printf still-alive');
      expect(after.stdout.trim(), 'still-alive');
      await ssh.close();
    });
  }, skip: server == null ? 'SSH_TEST_* not configured (see .env.test)' : null);
}
