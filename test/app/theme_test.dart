import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/app/theme/app_palette.dart';
import 'package:ssh_client/app/theme/app_theme.dart';
import 'package:ssh_client/app/theme/app_tokens.dart';

void main() {
  test('light palette uses the agreed neutrals', () {
    expect(AppPalette.light.background, const Color(0xFFF8F9FA));
    expect(AppPalette.light.surface, const Color(0xFFFFFFFF));
    expect(AppPalette.light.surfaceVariant, const Color(0xFFF0F1F3));
    expect(AppPalette.light.border, const Color(0xFFD9DCE1));
    expect(AppPalette.light.textPrimary, const Color(0xFF24262B));
    expect(AppPalette.light.iconSecondary, const Color(0xFF858B95));
    expect(AppPalette.light.brightness, Brightness.light);
  });

  test('dark palette avoids pure black and keeps a soft carbon border', () {
    expect(AppPalette.dark.background, const Color(0xFF111318));
    expect(AppPalette.dark.surface, const Color(0xFF181A1F));
    expect(AppPalette.dark.surfaceElevated, const Color(0xFF24262B));
    expect(AppPalette.dark.border, const Color(0xFF2E3138));
    expect(AppPalette.dark.textPrimary, const Color(0xFFE8EAED));
    expect(AppPalette.dark.background, isNot(Colors.black));
    expect(AppPalette.dark.surface, isNot(Colors.black));
  });

  test('both themes carry tokens, radii, fonts and terminal palettes', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final tokens = theme.extension<AppTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.cardRadius, 18);
      expect(tokens.dialogRadius, 22);
      expect(tokens.buttonRadius, 14);
      expect(tokens.fieldRadius, 12);
      expect(tokens.chipRadius, 10);
      expect(tokens.fast, const Duration(milliseconds: 150));
      expect(tokens.normal, const Duration(milliseconds: 200));
      expect(tokens.slow, const Duration(milliseconds: 250));
      expect(tokens.terminalStyle.fontFamily, 'JetBrainsMono');
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.titleMedium?.fontWeight, FontWeight.w600);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.dialogTheme.shape, isNotNull);
      expect(theme.filledButtonTheme.style, isNotNull);
      expect(theme.inputDecorationTheme.border, isNotNull);
    }
  });

  test(
    'terminal palette follows the theme unless always-dark is requested',
    () {
      final light = AppTheme.light().extension<AppTokens>()!.terminalTheme;
      final dark = AppTheme.dark().extension<AppTokens>()!.terminalTheme;
      final alwaysDark = AppTheme.light(alwaysDarkTerminal: true)
          .extension<AppTokens>()!
          .terminalTheme;

      expect(light.background, AppPalette.light.surface);
      expect(dark.background, AppPalette.dark.background);
      expect(alwaysDark.background, AppPalette.dark.background);
      expect(light.foreground, AppPalette.light.textPrimary);
    },
  );

  testWidgets('theme applies colours and no elevation', (tester) async {
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppPalette.dark.background);
    expect(theme.colorScheme.primary, AppPalette.dark.accent);
    expect(theme.colorScheme.error, AppPalette.dark.error);
    expect(theme.colorScheme.surface, AppPalette.dark.background);
    expect(theme.colorScheme.surfaceContainerLow, AppPalette.dark.surface);
    expect(
      theme.colorScheme.surfaceContainerHigh,
      AppPalette.dark.surfaceElevated,
    );
  });
}
