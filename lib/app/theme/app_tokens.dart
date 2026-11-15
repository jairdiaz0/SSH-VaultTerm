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

  /// Round 6 shell: 220 px sidebar that collapses to a 64 px icon rail, a
  /// 44 px tab strip and a 380 px details panel.
  static const sidebarWidth = 220.0;
  static const railWidth = 64.0;
  static const topBarHeight = 44.0;
  static const detailsPanelWidth = 380.0;

  /// Forms and settings keep a readable measure on wide screens.
  static const maxFormWidth = 720.0;
}

/// Round 6 corner radii, available to widgets that cannot read the theme
/// extension (const decorations, const borders).
abstract final class AppRadii {
  static const card = 12.0;
  static const dialog = 12.0;
  static const button = 10.0;
  static const field = 10.0;
  static const chip = 8.0;
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
        cardRadius: 12,
        dialogRadius: 12,
        buttonRadius: 10,
        fieldRadius: 10,
        chipRadius: 8,
        fast: const Duration(milliseconds: 150),
        normal: const Duration(milliseconds: 200),
        slow: const Duration(milliseconds: 250),
        enterCurve: _curve,
        emphasizedCurve: Curves.easeInOutCubic,
        focusRing: palette.accentForeground,
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
  cursor: const Color(0xFF3B82F6),
  selection: const Color(0x553B82F6),
  foreground: const Color(0xFFF4F4F5),
  background: const Color(0xFF0E0E10),
  black: const Color(0xFF3F3F46),
  red: const Color(0xFFF87171),
  green: const Color(0xFF4ADE80),
  yellow: const Color(0xFFFACC15),
  blue: const Color(0xFF60A5FA),
  magenta: const Color(0xFFC084FC),
  cyan: const Color(0xFF22D3EE),
  white: const Color(0xFFE4E4E7),
  brightBlack: const Color(0xFFA1A1AA),
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
