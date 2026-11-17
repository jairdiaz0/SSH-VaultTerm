import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_vault_term/app/theme/theme_controller.dart';

import '../support/shell_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('without a saved preference the system theme is used', () async {
    final controller = await ThemeController.load();
    expect(controller.mode, ThemeMode.system);
    expect(controller.alwaysDarkTerminal, isFalse);
  });

  test('the chosen theme and terminal preference survive a restart', () async {
    final first = await ThemeController.load();
    await first.setMode(ThemeMode.light);
    await first.setAlwaysDarkTerminal(true);

    final restarted = await ThemeController.load();
    expect(restarted.mode, ThemeMode.light);
    expect(restarted.alwaysDarkTerminal, isTrue);

    await restarted.setMode(ThemeMode.system);
    final again = await ThemeController.load();
    expect(again.mode, ThemeMode.system);
  });

  testWidgets('system mode follows the platform brightness', (tester) async {
    final harness = await pumpShell(tester, mode: ThemeMode.system);
    addTearDown(harness.dispose);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const Key('sidebar-profile-name'))))
          .brightness,
      Brightness.dark,
    );

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const Key('sidebar-profile-name'))))
          .brightness,
      Brightness.light,
    );
  });

  testWidgets('the settings selector switches theme instantly', (tester) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Claro').last);
    await tester.pumpAndSettle();

    expect(harness.themeController.mode, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.text('Apariencia'))).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('Oscuro').last);
    await tester.pumpAndSettle();
    expect(harness.themeController.mode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Apariencia'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('terminal always-dark is a persisted switch', (tester) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('terminal-dark-switch')));
    await tester.pumpAndSettle();

    expect(harness.themeController.alwaysDarkTerminal, isTrue);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('terminal-dark-switch')))
          .value,
      isTrue,
    );
  });
}
