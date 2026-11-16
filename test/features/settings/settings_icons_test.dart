import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/app/theme/app_icons.dart';

import '../../support/shell_harness.dart';

IconData _iconOf(WidgetTester tester, Key key) {
  final icon = tester.widget<Icon>(
    find.descendant(of: find.byKey(key), matching: find.byType(Icon)),
  );
  return icon.icon!;
}

void main() {
  testWidgets('export points out of the app and import points into it', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const Key('export-backup-button')),
      find.byType(ListView).last,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();

    expect(_iconOf(tester, const Key('export-backup-button')), AppIcons.upload);
    expect(
      _iconOf(tester, const Key('import-backup-button')),
      AppIcons.download,
    );
  });
}
