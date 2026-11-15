import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/features/shell/presentation/shell_controller.dart';
import 'package:ssh_client/features/shell/presentation/top_bar.dart';
import 'package:ssh_client/shared/models/connection.dart';

import '../../support/app_harness.dart';
import '../../support/test_context.dart';

Connection _connection(String id) => Connection(
  id: id,
  name: 'srv-$id',
  hostname: 'host-$id',
  port: 22,
  username: 'deploy',
  authType: AuthenticationType.password,
  position: 0,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Future<ShellController> _shell(AppHarness harness) async {
  await harness.controller.createFirstProfile(
    name: 'Work',
    password: testPassword,
    passwordConfirmation: testPassword,
  );
  final controller = ShellController(
    services: harness.services,
    session: harness.controller.session!,
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test('opening the same connection twice reuses its tab', () async {
    final harness = await AppHarness.create();
    addTearDown(harness.dispose);
    final shell = await _shell(harness);

    final connection = _connection('c1');
    final first = shell.openTab(connection);
    final second = shell.openTab(connection);

    expect(second, same(first));
    expect(shell.tabs, hasLength(1));
    expect(shell.view, ShellView.session);
    expect(shell.activeTab!.id, 'c1');
    expect(shell.workspace, same(first.workspace));
  });

  test('switching tabs keeps every session alive', () async {
    final harness = await AppHarness.create();
    addTearDown(harness.dispose);
    final shell = await _shell(harness);

    final first = shell.openTab(_connection('c1'));
    final second = shell.openTab(_connection('c2'));
    expect(shell.tabs, hasLength(2));
    expect(shell.activeTab!.id, 'c2');

    shell.activateTab(first);
    expect(shell.activeTab!.id, 'c1');
    expect(shell.tabs, hasLength(2));
    expect(shell.tabs.last, same(second));
  });

  test(
    'closing the active tab falls back to the neighbour, then home',
    () async {
      final harness = await AppHarness.create();
      addTearDown(harness.dispose);
      final shell = await _shell(harness);

      final first = shell.openTab(_connection('c1'));
      shell.openTab(_connection('c2'));

      await shell.closeTab('c2');
      expect(shell.tabs, hasLength(1));
      expect(shell.activeTab!.id, 'c1');
      expect(shell.view, ShellView.session);

      await shell.closeTab(first.id);
      expect(shell.tabs, isEmpty);
      expect(shell.activeTab, isNull);
      expect(shell.view, ShellView.dashboard);
    },
  );

  test(
    'pinned views and sidebar sections are independent of sessions',
    () async {
      final harness = await AppHarness.create();
      addTearDown(harness.dispose);
      final shell = await _shell(harness);

      shell.openTab(_connection('c1'));
      shell.showSftp();
      expect(shell.view, ShellView.sftp);
      expect(shell.section, ShellSection.connections);
      expect(shell.tabs, hasLength(1));

      shell.selectSection(ShellSection.fingerprints);
      expect(shell.section, ShellSection.fingerprints);
      expect(shell.view, ShellView.dashboard);
      expect(shell.sidebarCollapsed, isFalse);
      shell.toggleSidebar();
      expect(shell.sidebarCollapsed, isTrue);
    },
  );

  testWidgets('the top bar lists a tab per session and closes them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = await AppHarness.create();
    addTearDown(harness.dispose);
    final shell = await _shell(harness);
    final connection = _connection('c1');
    shell.openTab(connection);
    shell.showDashboard();

    await tester.pumpWidget(
      harness.wrap(
        Scaffold(
          body: ListenableBuilder(
            listenable: shell,
            builder: (context, _) => TopBar(controller: shell),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tab-dashboard')), findsOneWidget);
    expect(find.byKey(const Key('tab-sftp')), findsOneWidget);
    expect(find.byKey(const Key('tab-session-c1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-session-c1')));
    await tester.pumpAndSettle();
    expect(shell.view, ShellView.session);

    await tester.tap(find.byKey(const Key('close-tab-c1')));
    await tester.pumpAndSettle();
    expect(shell.tabs, isEmpty);
    expect(find.byKey(const Key('tab-session-c1')), findsNothing);
  });
}
