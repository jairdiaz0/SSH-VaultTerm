import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/shared/models/connection.dart';
import 'package:ssh_client/shared/models/known_host.dart';

import '../../support/shell_harness.dart';

final _now = DateTime.utc(2026, 1, 1);

Connection _connection(
  String id, {
  required String name,
  required List<String> tags,
}) => Connection(
  id: id,
  name: name,
  hostname: '$id.example.com',
  port: 22,
  username: 'deploy',
  authType: AuthenticationType.password,
  tags: tags,
  position: 0,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  testWidgets('the dashboard filters servers by text and tag', (tester) async {
    final harness = await pumpShell(
      tester,
      seed: (session) {
        session.connections.insert(
          _connection('alpha', name: 'Alpha', tags: const ['prod']),
        );
        session.connections.insert(
          _connection('beta', name: 'Beta', tags: const ['lab']),
        );
      },
    );
    addTearDown(harness.dispose);

    expect(find.byKey(const Key('connection-tile-alpha')), findsOneWidget);
    expect(find.byKey(const Key('connection-tile-beta')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('dashboard-search')), 'beta');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('connection-tile-alpha')), findsNothing);
    expect(find.byKey(const Key('connection-tile-beta')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('dashboard-search')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tag-filter-prod')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('connection-tile-alpha')), findsOneWidget);
    expect(find.byKey(const Key('connection-tile-beta')), findsNothing);
  });

  testWidgets('an unmatched search shows the empty result state', (
    tester,
  ) async {
    final harness = await pumpShell(
      tester,
      seed: (session) {
        session.connections.insert(
          _connection('alpha', name: 'Alpha', tags: const []),
        );
      },
    );
    addTearDown(harness.dispose);

    await tester.enterText(
      find.byKey(const Key('dashboard-search')),
      'nothing-here',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('connection-tile-alpha')), findsNothing);
    expect(find.byKey(const Key('dashboard-clear-search')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard-clear-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('connection-tile-alpha')), findsOneWidget);
  });

  testWidgets('the grid and list views show the same servers', (tester) async {
    final harness = await pumpShell(
      tester,
      seed: (session) {
        session.connections.insert(
          _connection('alpha', name: 'Alpha', tags: const []),
        );
      },
    );
    addTearDown(harness.dispose);

    expect(find.byKey(const Key('dashboard-view-grid')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-view-list')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('connection-tile-alpha')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sidebar collapses to the icon rail and comes back', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    expect(find.byKey(const Key('sidebar-profile-name')), findsOneWidget);
    expect(find.text('Huellas'), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle-sidebar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sidebar-profile-name')), findsNothing);
    expect(find.text('Huellas'), findsNothing);
    expect(find.byKey(const Key('nav-fingerprints')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('toggle-sidebar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sidebar-profile-name')), findsOneWidget);
  });

  testWidgets('the fingerprints view lists and forgets a known host', (
    tester,
  ) async {
    final harness = await pumpShell(
      tester,
      seed: (session) {
        session.connections.insert(
          _connection('alpha', name: 'Alpha', tags: const []),
        );
        session.knownHosts.accept(
          KnownHost(
            id: 'kh1',
            connectionId: 'alpha',
            hostname: 'alpha.example.com',
            port: 22,
            keyType: 'ssh-ed25519',
            fingerprint: 'SHA256:abcdef',
            createdAt: _now,
          ),
        );
      },
    );
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const Key('nav-fingerprints')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('known-host-kh1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('forget-known-host-kh1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('known-host-kh1')), findsNothing);
    expect(harness.controller.session!.knownHosts.count(), 0);
  });
}
