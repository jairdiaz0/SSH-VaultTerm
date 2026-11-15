import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

import 'app_palette.dart';

/// Spacing tokens, in logical pixels. Every gap in the UI uses one of these.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Minimum window size. The Windows runner also enforces it.
abstract final class AppLayout {
  static const minWidth = 900.0;
  static const minHeight = 600.0;
  static const sidebarWidth = 288.0;

  /// Forms and settings keep a readable measure on wide screens.
  static const maxFormWidth = 720.0;
}

/// Project tokens that are not part of [ColorScheme]: status colours, terminal
/// palette, radii, durations and curves.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.palette,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.terminalTheme,
    required this.terminalStyle,
    required this.cardRadius,
    required this.dialogRadius,
    required this.buttonRadius,
    required this.fieldRadius,
    required this.chipRadius,
    required this.fast,
    required this.normal,
    required this.slow,
    required this.enterCurve,
    required this.emphasizedCurve,
    required this.focusRing,
  });

  final AppPalette palette;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final TerminalTheme terminalTheme;
  final TerminalStyle terminalStyle;

  final double cardRadius;
  final double dialogRadius;
  final double buttonRadius;
  final double fieldRadius;
  final double chipRadius;

  final Duration fast;
  final Duration normal;
  final Duration slow;
  final Curve enterCurve;
  final Curve emphasizedCurve;
  final Color focusRing;

  static const _curve = Curves.easeOutCubic;

  static AppTokens of(AppPalette palette, {bool alwaysDarkTerminal = false}) =>
      AppTokens(
        palette: palette,
        success: palette.success,
        onSuccess: palette.onSuccess,
        warning: palette.warning,
        onWarning: palette.onWarning,
        terminalTheme: appTerminalTheme(
          alwaysDarkTerminal || palette.isDark ? AppPalette.dark : palette,
        ),
        terminalStyle: const TerminalStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 13,
          height: 1.3,
        ),
        cardRadius: 18,
        dialogRadius: 22,
        buttonRadius: 14,
        fieldRadius: 12,
        chipRadius: 10,
        fast: const Duration(milliseconds: 150),
        normal: const Duration(milliseconds: 200),
        slow: const Duration(milliseconds: 250),
        enterCurve: _curve,
        emphasizedCurve: Curves.easeInOutCubic,
        focusRing: palette.accent,
      );

  @override
  AppTokens copyWith({AppPalette? palette, TerminalTheme? terminalTheme}) =>
      AppTokens(
        palette: palette ?? this.palette,
        success: success,
        onSuccess: onSuccess,
        warning: warning,
        onWarning: onWarning,
        terminalTheme: terminalTheme ?? this.terminalTheme,
        terminalStyle: terminalStyle,
        cardRadius: cardRadius,
        dialogRadius: dialogRadius,
        buttonRadius: buttonRadius,
        fieldRadius: fieldRadius,
        chipRadius: chipRadius,
        fast: fast,
        normal: normal,
        slow: slow,
        enterCurve: enterCurve,
        emphasizedCurve: emphasizedCurve,
        focusRing: focusRing,
      );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      palette: t < 0.5 ? palette : other.palette,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      terminalTheme: t < 0.5 ? terminalTheme : other.terminalTheme,
      terminalStyle: terminalStyle,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      dialogRadius: lerpDouble(dialogRadius, other.dialogRadius, t),
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t),
      fieldRadius: lerpDouble(fieldRadius, other.fieldRadius, t),
      chipRadius: lerpDouble(chipRadius, other.chipRadius, t),
      fast: fast,
      normal: normal,
      slow: slow,
      enterCurve: enterCurve,
      emphasizedCurve: emphasizedCurve,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Ergonomic access for widgets.
extension AppThemeContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
}

/// Terminal palette per brightness. ANSI slots stay legible on both themes
/// (tested in `test/app/theme_contrast_test.dart`).
TerminalTheme appTerminalTheme(AppPalette palette) => TerminalTheme(
  cursor: palette.accent,
  selection: palette.accent.withValues(alpha: 0.28),
  foreground: palette.textPrimary,
  background: palette.isDark ? palette.background : palette.surface,
  black: palette.isDark ? const Color(0xFF2E3138) : const Color(0xFF2E3138),
  red: palette.isDark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E),
  green: palette.isDark ? const Color(0xFF6FE7A8) : const Color(0xFF1B6B45),
  yellow: palette.isDark ? const Color(0xFFE5C07B) : const Color(0xFF6B4A00),
  blue: palette.isDark ? const Color(0xFF82B1FF) : const Color(0xFF244F8F),
  magenta: palette.isDark ? const Color(0xFFD7A8FF) : const Color(0xFF6A2E8F),
  cyan: palette.isDark ? const Color(0xFF57E0EC) : const Color(0xFF0A5C66),
  white: palette.isDark ? const Color(0xFFDDE1E7) : const Color(0xFF3A3F47),
  brightBlack: const Color(0xFF7A828D),
  brightRed: const Color(0xFFFF9F97),
  brightGreen: const Color(0xFF8AF0BC),
  brightYellow: const Color(0xFFF2D08A),
  brightBlue: const Color(0xFFA6C8FF),
  brightMagenta: const Color(0xFFE6C2FF),
  brightCyan: const Color(0xFF8CEFF6),
  brightWhite: const Color(0xFFFFFFFF),
  searchHitBackground: palette.warning,
  searchHitBackgroundCurrent: palette.warning,
  searchHitForeground: palette.onWarning,
);
