import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/shell_harness.dart';

void main() {
  testWidgets('reset needs the exact word and the profile password', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('reset-app-button')),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.tap(find.byKey(const Key('reset-app-button')));
    await tester.pumpAndSettle();

    final confirm = find.byKey(const Key('reset-confirm-word'));
    expect(
      tester.widget<FilledButton>(confirm).onPressed,
      isNull,
      reason: 'nothing is enabled before typing the word',
    );

    await tester.enterText(find.byKey(const Key('reset-word-field')), 'reset');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('reset-word-field')),
      'RESTABLECER',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-password-field')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-password-cancel')));
    await tester.pumpAndSettle();
    expect(harness.controller.isUnlocked, isTrue);
  });

  testWidgets('storage status opens without revealing secrets', (tester) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('storage-status-button')),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.tap(find.byKey(const Key('storage-status-button')));
    await tester.pumpAndSettle();

    expect(find.text('Estado del almacenamiento'), findsWidgets);
    expect(find.text('Catálogo cifrado'), findsOneWidget);
    expect(find.textContaining('abre correctamente'), findsWidgets);
  });
}
