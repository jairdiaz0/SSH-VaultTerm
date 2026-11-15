import 'package:material_ui/material_ui.dart';

/// Semantic colours for one brightness. Values are hand-picked, not generated.
///
/// Contrast is enforced by `test/app/theme_contrast_test.dart`: text pairs must
/// reach 4.5:1 and interactive components 3:1.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconSecondary,
    required this.disabled,
    required this.accent,
    required this.onAccent,
    required this.error,
    required this.onError,
    required this.warning,
    required this.onWarning,
    required this.success,
    required this.onSuccess,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color iconSecondary;
  final Color disabled;
  final Color accent;
  final Color onAccent;
  final Color error;
  final Color onError;
  final Color warning;
  final Color onWarning;
  final Color success;
  final Color onSuccess;

  bool get isDark => brightness == Brightness.dark;

  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF8F9FA),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF0F1F3),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFD9DCE1),
    textPrimary: Color(0xFF24262B),
    // #858B95 does not reach AA on light surfaces: this is the readable grey.
    textSecondary: Color(0xFF565B65),
    iconSecondary: Color(0xFF858B95),
    disabled: Color(0xFF858B95),
    accent: Color(0xFF00697A),
    onAccent: Color(0xFFFFFFFF),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    warning: Color(0xFF7A5200),
    onWarning: Color(0xFFFFFFFF),
    success: Color(0xFF1B6B45),
    onSuccess: Color(0xFFFFFFFF),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF111318),
    surface: Color(0xFF181A1F),
    surfaceVariant: Color(0xFF1D2026),
    surfaceElevated: Color(0xFF24262B),
    border: Color(0xFF2E3138),
    textPrimary: Color(0xFFE8EAED),
    textSecondary: Color(0xFFA8AFBA),
    iconSecondary: Color(0xFF858B95),
    disabled: Color(0xFF858B95),
    accent: Color(0xFF3DDDE7),
    onAccent: Color(0xFF04252A),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF3B0906),
    warning: Color(0xFFE5B45B),
    onWarning: Color(0xFF2B1D00),
    success: Color(0xFF4CD69B),
    onSuccess: Color(0xFF04291B),
  );
}
