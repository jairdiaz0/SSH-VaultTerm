import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/core/errors/app_exception.dart';
import 'package:ssh_client/features/settings/presentation/settings_dialog.dart';
import 'package:ssh_client/features/shell/presentation/shell_controller.dart';
import 'package:ssh_client/features/ssh/domain/ssh_connection_state.dart';
import 'package:ssh_client/features/workspace/presentation/workspace_panel.dart';
import 'package:ssh_client/shared/models/known_host.dart';

import '../../support/app_harness.dart';
import '../../support/shell_harness.dart';
import '../../support/test_context.dart';
import '../../support/workspace_harness.dart';

void main() {
  test('connecting to an unreachable server ends in a mapped error', () async {
    final harness = await AppHarness.create();
    addTearDown(harness.dispose);
    await harness.controller.createFirstProfile(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
    );

    final session = harness.controller.session!;
    final connection = await addUnreachableConnection(harness);
    final shell = ShellController(services: harness.services, session: session);
    addTearDown(shell.dispose);

    await shell.workspace.open(connection, confirmHostKey: (_) async => true);

    expect(shell.workspace.status, SshConnectionStatus.failed);
    expect(shell.workspace.errorCode, AppErrorCode.networkUnreachable);
    expect(shell.workspace.terminal, isNull);
  });

  testWidgets('the workspace shows the failure and offers a reconnect', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = await AppHarness.create();
    addTearDown(harness.dispose);
    await harness.controller.createFirstProfile(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
    );

    final session = harness.controller.session!;
    final connection = await addUnreachableConnection(harness);
    final shell = ShellController(services: harness.services, session: session);
    addTearDown(shell.dispose);
    // Real socket I/O needs the real event loop, not the fake-async test zone.
    await tester.runAsync(() async {
      await shell.workspace.open(connection, confirmHostKey: (_) async => true);
    });

    await tester.pumpWidget(
      harness.wrap(Scaffold(body: WorkspacePanel(controller: shell.workspace))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace-error')), findsOneWidget);
    expect(find.textContaining('No se pudo alcanzar'), findsOneWidget);
    expect(find.byKey(const Key('reconnect-button')), findsOneWidget);
    expect(find.text('bad-host'), findsWidgets);
  });

  testWidgets('settings lists and forgets a known host fingerprint', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);
    await createPasswordConnection(tester);

    final session = harness.controller.session!;
    final connection = session.connections.all().single;
    session.knownHosts.accept(
      KnownHost(
        id: 'known-1',
        connectionId: connection.id,
        hostname: '10.0.0.10',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprint: 'SHA256:abcdefghijklmnop',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsDialog), findsOneWidget);
    expect(
      find.text('SHA256:abcdefghijklmnop'),
      findsOneWidget,
      reason: 'the fingerprint must be visible to compare it out of band',
    );

    await tester.tap(find.byKey(const Key('forget-known-host-known-1')));
    await tester.pumpAndSettle();

    expect(session.knownHosts.count(), 0);
    expect(
      find.text('No hay huellas guardadas en este perfil.'),
      findsOneWidget,
    );
  });
}
