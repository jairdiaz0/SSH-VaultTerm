import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/app/theme/app_palette.dart';
import 'package:ssh_client/app/theme/app_theme.dart';
import 'package:ssh_client/app/theme/app_tokens.dart';

double _channel(double value) {
  final normalized = value / 255;
  return normalized <= 0.03928
      ? normalized / 12.92
      : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
}

double luminance(Color color) {
  final value = color.computeLuminance();
  // computeLuminance already follows the WCAG formula: keep it explicit here.
  return value > 0 ? value : _channel(0);
}

double contrast(Color foreground, Color background) {
  final a = luminance(foreground) + 0.05;
  final b = luminance(background) + 0.05;
  return a > b ? a / b : b / a;
}

void expectContrast(
  Color foreground,
  Color background,
  double minimum,
  String label,
) {
  final ratio = contrast(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(minimum),
    reason: '$label must reach $minimum:1, got ${ratio.toStringAsFixed(2)}:1',
  );
}

void main() {
  for (final palette in [AppPalette.light, AppPalette.dark]) {
    group('${palette.brightness.name} contrast', () {
      test('text pairs reach WCAG AA 4.5:1', () {
        expectContrast(
          palette.textPrimary,
          palette.background,
          4.5,
          'textPrimary on background',
        );
        expectContrast(
          palette.textSecondary,
          palette.background,
          4.5,
          'textSecondary on background',
        );
        expectContrast(
          palette.textSecondary,
          palette.surface,
          4.5,
          'textSecondary on surface',
        );
        expectContrast(
          palette.textPrimary,
          palette.surfaceVariant,
          4.5,
          'textPrimary on surfaceVariant',
        );
        expectContrast(
          palette.onAccent,
          palette.accent,
          4.5,
          'onAccent on accent',
        );
        expectContrast(palette.onError, palette.error, 4.5, 'onError');
        expectContrast(palette.onWarning, palette.warning, 4.5, 'onWarning');
        expectContrast(palette.onSuccess, palette.success, 4.5, 'onSuccess');
      });

      test('interactive components reach 3:1', () {
        expectContrast(
          palette.accent,
          palette.background,
          3,
          'accent on background',
        );
        expectContrast(palette.accent, palette.surface, 3, 'accent on surface');
        expectContrast(palette.error, palette.background, 3, 'error indicator');
        expectContrast(
          palette.warning,
          palette.background,
          3,
          'warning indicator',
        );
        expectContrast(
          palette.success,
          palette.background,
          3,
          'success indicator',
        );
      });

      test('terminal foreground and ANSI colours stay legible', () {
        final tokens = (palette.isDark ? AppTheme.dark() : AppTheme.light())
            .extension<AppTokens>()!;
        final theme = tokens.terminalTheme;
        expectContrast(theme.foreground, theme.background, 4.5, 'terminal fg');
        for (final entry in {
          'red': theme.red,
          'green': theme.green,
          'yellow': theme.yellow,
          'blue': theme.blue,
          'magenta': theme.magenta,
          'cyan': theme.cyan,
          'white': theme.white,
        }.entries) {
          expectContrast(entry.value, theme.background, 3, entry.key);
        }
      });
    });
  }
}
