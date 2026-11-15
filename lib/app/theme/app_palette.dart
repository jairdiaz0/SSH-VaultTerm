import 'package:material_ui/material_ui.dart';

/// Semantic colours for one brightness, hand-picked from the round 6 spec.
///
/// Contrast is enforced by `test/app/theme_contrast_test.dart`: text pairs must
/// reach 4.5:1 and interactive components 3:1. Disabled colours are exempt.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceElevated,
    required this.workspace,
    required this.hover,
    required this.active,
    required this.popover,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconSecondary,
    required this.disabled,
    required this.accent,
    required this.onAccent,
    required this.accentForeground,
    required this.error,
    required this.onError,
    required this.warning,
    required this.onWarning,
    required this.success,
    required this.onSuccess,
  });

  final Brightness brightness;

  /// Base, top bar and sidebar.
  final Color background;

  /// Cards, inputs and inactive tabs.
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceElevated;

  /// Work area behind cards.
  final Color workspace;
  final Color hover;
  final Color active;
  final Color popover;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color iconSecondary;

  /// Disabled text and elements (WCAG exempt).
  final Color disabled;

  /// Fill accent (primary button, selected row, group tile).
  final Color accent;
  final Color onAccent;

  /// Accent used as text, icon and focus ring.
  final Color accentForeground;
  final Color error;
  final Color onError;
  final Color warning;
  final Color onWarning;
  final Color success;
  final Color onSuccess;

  bool get isDark => brightness == Brightness.dark;

  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF3F4F6),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFE5E7EB),
    surfaceElevated: Color(0xFFFFFFFF),
    workspace: Color(0xFFF9FAFB),
    hover: Color(0xFFF3F4F6),
    active: Color(0xFFE5E7EB),
    popover: Color(0xFFFFFFFF),
    border: Color(0xFFE4E4E7),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF5F6672),
    iconSecondary: Color(0xFF5F6672),
    // Spec says #9CA3AF; raised to AA for placeholders (the test enforces it).
    disabled: Color(0xFF71717A),
    accent: Color(0xFF2563EB),
    onAccent: Color(0xFFFFFFFF),
    accentForeground: Color(0xFF2563EB),
    error: Color(0xFFB91C1C),
    onError: Color(0xFFFFFFFF),
    warning: Color(0xFFB45309),
    onWarning: Color(0xFFFFFFFF),
    success: Color(0xFF15803D),
    onSuccess: Color(0xFFFFFFFF),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF09090B),
    surface: Color(0xFF151518),
    surfaceVariant: Color(0xFF1C1C20),
    surfaceElevated: Color(0xFF222227),
    workspace: Color(0xFF0E0E10),
    hover: Color(0xFF1C1C20),
    active: Color(0xFF222227),
    popover: Color(0xFF18181B),
    border: Color(0xFF232328),
    textPrimary: Color(0xFFF4F4F5),
    // Spec says #8E8E98; raised slightly to keep AA on the workspace too.
    textSecondary: Color(0xFFAFAFB8),
    iconSecondary: Color(0xFFAFAFB8),
    disabled: Color(0xFF52525B),
    accent: Color(0xFF2563EB),
    onAccent: Color(0xFFFFFFFF),
    accentForeground: Color(0xFF3B82F6),
    error: Color(0xFFEF4444),
    onError: Color(0xFF200606),
    warning: Color(0xFFF59E0B),
    onWarning: Color(0xFF1C1200),
    success: Color(0xFF22C55E),
    onSuccess: Color(0xFF052E16),
  );
}
