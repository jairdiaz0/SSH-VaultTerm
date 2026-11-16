import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/app/session_controller.dart';
import 'package:ssh_client/features/shell/presentation/home_shell.dart';
import 'package:ssh_client/shared/models/connection.dart';

import '../../support/app_harness.dart';
import '../../support/fake_ssh_services.dart';
import '../../support/test_context.dart';

final _now = DateTime.utc(2026, 1, 1);

Connection _connection(String id) => Connection(
  id: id,
  name: 'srv-$id',
  hostname: 'host-$id',
  port: 22,
  username: 'deploy',
  authType: AuthenticationType.password,
  position: 0,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  testWidgets(
    'opening a connection from the dashboard shows the host key dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final harness = await AppHarness.create();
      addTearDown(harness.dispose);
      final services = FakeSshServices(harness.services);
      final controller = SessionController(
        services: services,
        createParams: testArgon2Params,
      );
      addTearDown(controller.dispose);
      await controller.createFirstProfile(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
      );
      controller.session!.connections.insert(_connection('c1'));

      await tester.pumpWidget(harness.wrap(HomeShell(controller: controller)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('connection-tile-c1')));
      // The card disappears as soon as the session tab is shown; the dialog is
      // requested later, when the handshake reaches the host key check.
      await tester.pump();
      expect(find.byKey(const Key('connection-tile-c1')), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // The card is gone, but the dialog must still be reachable: it is bound
      // to the navigator.
      expect(find.byKey(const Key('host-key-accept')), findsOneWidget);
      expect(find.byKey(const Key('host-key-fingerprint')), findsOneWidget);
      expect(find.textContaining('No has aceptado'), findsNothing);

      await tester.tap(find.byKey(const Key('host-key-accept')));
      await tester.pumpAndSettle();

      expect(services.connects, 1);
      expect(find.textContaining('No se pudo alcanzar'), findsOneWidget);
    },
  );

  testWidgets('cancelling the host key dialog refuses the connection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = await AppHarness.create();
    addTearDown(harness.dispose);
    final services = FakeSshServices(harness.services);
    final controller = SessionController(
      services: services,
      createParams: testArgon2Params,
    );
    addTearDown(controller.dispose);
    await controller.createFirstProfile(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
    );
    controller.session!.connections.insert(_connection('c2'));

    await tester.pumpWidget(harness.wrap(HomeShell(controller: controller)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('connection-tile-c2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('host-key-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('No has aceptado la huella'), findsOneWidget);
  });
}
