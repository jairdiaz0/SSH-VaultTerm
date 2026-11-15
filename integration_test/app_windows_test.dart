import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/app/app.dart';
import 'package:ssh_client/app/app_services.dart';
import 'package:ssh_client/core/security/password_hasher.dart';
import 'package:ssh_client/core/storage/app_paths.dart';
import 'package:ssh_client/core/storage/secure_storage_secret_store.dart';
import 'package:ssh_client/features/sftp/presentation/sftp_panel.dart';
import 'package:xterm/xterm.dart';

import 'support/server_config.dart';

const _password = 'integration password 123';

/// Pumps real frames until [condition] holds. Uses real time because the app is
/// talking to a real server.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (!condition()) {
    throw TestFailure('condition not met within $timeout');
  }
}

Future<void> typeText(WidgetTester tester, String text) async {
  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    await tester.sendKeyEvent(
      LogicalKeyboardKey(character.toLowerCase().codeUnitAt(0)),
      character: character,
    );
  }
}

Future<void> createConnection(
  WidgetTester tester, {
  required String name,
  required String host,
  required int port,
  required String username,
  required String password,
  required bool sftp,
}) async {
  await tester.tap(find.byKey(const Key('new-connection-button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('connection-name-field')), name);
  await tester.enterText(find.byKey(const Key('connection-host-field')), host);
  await tester.enterText(
    find.byKey(const Key('connection-port-field')),
    '$port',
  );
  await tester.enterText(
    find.byKey(const Key('connection-user-field')),
    username,
  );
  await tester.enterText(
    find.byKey(const Key('connection-password-field')),
    password,
  );
  if (sftp) {
    await tester.tap(find.byKey(const Key('type-sftp-chip')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('connection-save-button')));
  await tester.pumpAndSettle();
}

Future<void> acceptHostKey(WidgetTester tester) async {
  await pumpUntil(
    tester,
    () => find.byKey(const Key('host-key-accept')).evaluate().isNotEmpty,
  );
  await tester.tap(find.byKey(const Key('host-key-accept')));
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final server = TestServerConfig.load();

  testWidgets('real app: profile, ssh typing, exit, and sftp browse', (
    tester,
  ) async {
    if (server == null) {
      markTestSkipped('SSH_TEST_* not configured');
      return;
    }

    // Isolated data directory and secret namespace: never the real profile.
    final temp = Directory.systemTemp.createTempSync('ssh_client_it_');
    final namespace = 'it_${DateTime.now().microsecondsSinceEpoch}';
    final secrets = SecureStorageSecretStore(namespace: namespace);
    expect(await secrets.isAvailable(), isTrue);

    final services = await AppServices.fromStorage(
      secrets: secrets,
      paths: AppPaths(temp.path),
      hasher: PasswordHasher(),
    );
    addTearDown(() async {
      // Unmount the app so its session closes the profile database.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      services.dispose();
      await secrets.deletePrefix('');
      for (var attempt = 0; attempt < 10; attempt++) {
        try {
          if (temp.existsSync()) temp.deleteSync(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
    });

    await tester.pumpWidget(SshClientApp(services: services));
    await tester.pumpAndSettle();

    // First run.
    await tester.enterText(
      find.byKey(const Key('first-run-name-field')),
      'Integration',
    );
    await tester.enterText(
      find.byKey(const Key('first-run-password-field')),
      _password,
    );
    await tester.enterText(
      find.byKey(const Key('first-run-confirmation-field')),
      _password,
    );
    await tester.tap(find.byKey(const Key('first-run-submit-button')));
    await pumpUntil(
      tester,
      () =>
          find.byKey(const Key('new-connection-button')).evaluate().isNotEmpty,
    );

    // SSH connection.
    await createConnection(
      tester,
      name: 'it-ssh',
      host: server.host,
      port: server.port,
      username: server.username,
      password: server.password,
      sftp: false,
    );
    await tester.tap(find.text('it-ssh'));
    await tester.pump();
    await acceptHostKey(tester);

    await pumpUntil(
      tester,
      () => find.byType(TerminalView).evaluate().isNotEmpty,
    );
    final terminal = tester
        .widget<TerminalView>(find.byType(TerminalView))
        .terminal;
    await pumpUntil(
      tester,
      () => terminal.buffer.getText().trim().isNotEmpty,
      timeout: const Duration(seconds: 20),
    );

    await tester.tap(find.byType(TerminalView));
    await tester.pump();
    await typeText(tester, 'echo INTEGRATION-OK');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await pumpUntil(
      tester,
      () => terminal.buffer.getText().contains('INTEGRATION-OK'),
    );

    await typeText(tester, 'exit');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await pumpUntil(
      tester,
      () => find.byKey(const Key('session-ended')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('session-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-ended')), findsNothing);

    // SFTP connection, separate one.
    await createConnection(
      tester,
      name: 'it-sftp',
      host: server.host,
      port: server.port,
      username: server.username,
      password: server.password,
      sftp: true,
    );
    await tester.tap(find.text('it-sftp'));
    await tester.pump();
    await acceptHostKey(tester);

    await pumpUntil(tester, () => find.byType(SftpPanel).evaluate().isNotEmpty);
    final panel = tester.widget<SftpPanel>(find.byType(SftpPanel));
    await pumpUntil(
      tester,
      () => panel.controller.entries.isNotEmpty,
      timeout: const Duration(seconds: 20),
    );
    final home = panel.controller.path;
    expect(home.startsWith('/'), isTrue);

    await tester.tap(find.byKey(const Key('sftp-path-free-space')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('sftp-path-field')),
      '$home/opencode_sandbox',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpUntil(
      tester,
      () => panel.controller.path.endsWith('/opencode_sandbox'),
    );
    expect(find.byType(SftpPanel), findsOneWidget);
  });
}
