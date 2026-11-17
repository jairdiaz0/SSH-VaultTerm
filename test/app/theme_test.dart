import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_vault_term/app/theme/app_palette.dart';
import 'package:ssh_vault_term/app/theme/app_theme.dart';
import 'package:ssh_vault_term/app/theme/app_tokens.dart';

void main() {
  test('light palette uses the agreed neutrals', () {
    expect(AppPalette.light.background, const Color(0xFFF3F4F6));
    expect(AppPalette.light.surface, const Color(0xFFFFFFFF));
    expect(AppPalette.light.surfaceVariant, const Color(0xFFE5E7EB));
    expect(AppPalette.light.border, const Color(0xFFE4E4E7));
    expect(AppPalette.light.textPrimary, const Color(0xFF111827));
    expect(AppPalette.light.iconSecondary, const Color(0xFF5F6672));
    expect(AppPalette.light.brightness, Brightness.light);
  });

  test('dark palette avoids pure black and keeps a soft carbon border', () {
    expect(AppPalette.dark.background, const Color(0xFF09090B));
    expect(AppPalette.dark.surface, const Color(0xFF151518));
    expect(AppPalette.dark.surfaceElevated, const Color(0xFF222227));
    expect(AppPalette.dark.border, const Color(0xFF232328));
    expect(AppPalette.dark.textPrimary, const Color(0xFFF4F4F5));
    expect(AppPalette.dark.background, isNot(Colors.black));
    expect(AppPalette.dark.surface, isNot(Colors.black));
  });

  test('both themes carry tokens, radii, fonts and terminal palettes', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final tokens = theme.extension<AppTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.cardRadius, 12);
      expect(tokens.dialogRadius, 12);
      expect(tokens.buttonRadius, 10);
      expect(tokens.fieldRadius, 10);
      expect(tokens.chipRadius, 8);
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

      expect(light.background, const Color(0xFF0E0E10));
      expect(dark.background, const Color(0xFF0E0E10));
      expect(alwaysDark.background, const Color(0xFF0E0E10));
      expect(light.foreground, const Color(0xFFF4F4F5));
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
