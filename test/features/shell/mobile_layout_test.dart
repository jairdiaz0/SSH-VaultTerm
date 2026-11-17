import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_vault_term/features/shell/presentation/home_shell.dart';

import '../../support/shell_harness.dart';

void main() {
  testWidgets('narrow layouts use a drawer instead of the fixed sidebar', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.drawer, isNotNull);
    expect(
      find.byKey(const Key('sidebar-profile-name')),
      findsNothing,
      reason: 'the sidebar lives inside the closed drawer',
    );

    final state = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    state.openDrawer();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sidebar-profile-name')), findsOneWidget);
  });

  testWidgets('wide layouts keep the sidebar and no drawer', (tester) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.drawer, isNull);
    expect(find.byKey(const Key('sidebar-profile-name')), findsOneWidget);
    expect(find.byType(HomeShell), findsOneWidget);
  });
}
