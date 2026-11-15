import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/app/theme/app_theme.dart';

void main() {
  test('the bundled fonts exist as assets', () {
    for (final file in [
      'Inter-Regular.ttf',
      'Inter-Medium.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf',
      'JetBrainsMono-Regular.ttf',
      'JetBrainsMono-Bold.ttf',
    ]) {
      expect(
        File('assets/fonts/$file').existsSync(),
        isTrue,
        reason: '$file must be bundled: nothing is downloaded at runtime',
      );
    }
    expect(AppTheme.fontFamily, 'Inter');
    expect(AppTheme.monoFamily, 'JetBrainsMono');
  });

  test('palette matches the SPEC values', () {
    expect(AppColors.background, const Color(0xFF0E1113));
    expect(AppColors.surfaceSecondary, const Color(0xFF121619));
    expect(AppColors.panel, const Color(0xFF1D232A));
    expect(AppColors.elevated, const Color(0xFF252D35));
    expect(AppColors.border, const Color(0xFF303943));
    expect(AppColors.textPrimary, const Color(0xFFE8EDF2));
    expect(AppColors.textSecondary, const Color(0xFF929DA8));
    expect(AppColors.accent, const Color(0xFF00D4E8));
    expect(AppColors.accentSecondary, const Color(0xFF20C997));
    expect(AppColors.danger, const Color(0xFFFF5D6C));
    expect(AppColors.warning, const Color(0xFFE5AE4B));
  });

  testWidgets('theme applies dark colours, no elevation and no gradients', (
    tester,
  ) async {
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
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.accent);
    expect(theme.colorScheme.secondary, AppColors.accentSecondary);
    expect(theme.colorScheme.error, AppColors.danger);
    expect(theme.colorScheme.onSurface, AppColors.textPrimary);
    expect(theme.colorScheme.outline, AppColors.border);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.appBarTheme.elevation, 0);
    expect(theme.appBarTheme.backgroundColor, AppColors.surfaceSecondary);
    expect(theme.filledButtonTheme.style?.backgroundColor, isNotNull);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.textTheme.bodyMedium?.color, AppColors.textPrimary);
  });
}
