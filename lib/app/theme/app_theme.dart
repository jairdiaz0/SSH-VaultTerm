import 'package:material_ui/material_ui.dart';

import 'app_palette.dart';
import 'app_tokens.dart';

/// Light and dark themes built by hand from [AppPalette] (not `fromSeed`).
///
/// Fonts: Inter for the UI and JetBrains Mono for the terminal, both bundled as
/// assets. Component themes carry the radii and colours; widgets should not
/// hardcode colours or paddings of their own.
abstract final class AppTheme {
  static const fontFamily = 'Inter';
  static const monoFamily = 'JetBrainsMono';

  static ThemeData light({bool alwaysDarkTerminal = false}) =>
      _build(AppPalette.light, alwaysDarkTerminal: alwaysDarkTerminal);

  static ThemeData dark({bool alwaysDarkTerminal = false}) =>
      _build(AppPalette.dark, alwaysDarkTerminal: alwaysDarkTerminal);

  static ThemeData _build(
    AppPalette palette, {
    required bool alwaysDarkTerminal,
  }) {
    final tokens = AppTokens.of(
      palette,
      alwaysDarkTerminal: alwaysDarkTerminal,
    );
    final scheme = _scheme(palette);
    final base = ThemeData(
      brightness: palette.brightness,
      useMaterial3: true,
      fontFamily: fontFamily,
    );

    return base.copyWith(
      colorScheme: scheme,
      extensions: [tokens],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      dividerColor: palette.border,
      focusColor: palette.accent.withValues(alpha: 0.18),
      hoverColor: palette.accent.withValues(alpha: 0.08),
      splashColor: palette.accent.withValues(alpha: 0.10),
      highlightColor: palette.accent.withValues(alpha: 0.06),
      textTheme: _textTheme(base.textTheme, palette),
      primaryTextTheme: _textTheme(base.primaryTextTheme, palette),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          side: BorderSide(color: palette.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.dialogRadius),
          side: BorderSide(color: palette.border),
        ),
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
        contentTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 14,
          fontFamily: fontFamily,
        ),
      ),
      inputDecorationTheme: _inputTheme(palette, tokens),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor: palette.disabled.withValues(alpha: 0.28),
          disabledForegroundColor: palette.disabled,
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.iconSecondary,
          minimumSize: const Size(48, 48),
          iconSize: 20,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.buttonRadius),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceVariant,
        selectedColor: palette.accent.withValues(alpha: 0.16),
        side: BorderSide(color: palette.border),
        labelStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.chipRadius),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : palette.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent.withValues(alpha: 0.45)
              : palette.surfaceVariant,
        ),
        trackOutlineColor: WidgetStatePropertyAll(palette.border),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(palette.onAccent),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          side: BorderSide(color: palette.border),
        ),
        textStyle: TextStyle(color: palette.textPrimary, fontSize: 14),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(color: palette.border),
        ),
        textStyle: TextStyle(color: palette.textPrimary, fontSize: 12),
        waitDuration: const Duration(milliseconds: 450),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.accent,
        unselectedLabelColor: palette.textSecondary,
        indicatorColor: palette.accent,
        dividerColor: palette.border,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(8),
        thumbColor: WidgetStatePropertyAll(
          palette.textSecondary.withValues(alpha: 0.45),
        ),
        trackColor: WidgetStatePropertyAll(palette.surfaceVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.surfaceVariant,
        circularTrackColor: palette.surfaceVariant,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.iconSecondary,
        textColor: palette.textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        minVerticalPadding: AppSpacing.sm,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.fieldRadius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceElevated,
        contentTextStyle: TextStyle(color: palette.textPrimary, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.buttonRadius),
          side: BorderSide(color: palette.border),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? palette.onAccent
                : palette.textPrimary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? palette.accent
                : palette.surface,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.buttonRadius),
            ),
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accent,
        selectionColor: palette.accent.withValues(alpha: 0.30),
        selectionHandleColor: palette.accent,
      ),
    );
  }

  static ColorScheme _scheme(AppPalette palette) => ColorScheme(
    brightness: palette.brightness,
    primary: palette.accent,
    onPrimary: palette.onAccent,
    primaryContainer: palette.accent.withValues(alpha: 0.16),
    onPrimaryContainer: palette.textPrimary,
    secondary: palette.success,
    onSecondary: palette.onSuccess,
    secondaryContainer: palette.success.withValues(alpha: 0.14),
    onSecondaryContainer: palette.textPrimary,
    tertiary: palette.warning,
    onTertiary: palette.onWarning,
    error: palette.error,
    onError: palette.onError,
    errorContainer: palette.error.withValues(alpha: 0.14),
    onErrorContainer: palette.textPrimary,
    surface: palette.background,
    onSurface: palette.textPrimary,
    surfaceContainerLowest: palette.surface,
    surfaceContainerLow: palette.surface,
    surfaceContainer: palette.surfaceVariant,
    surfaceContainerHigh: palette.surfaceElevated,
    surfaceContainerHighest: palette.surfaceElevated,
    onSurfaceVariant: palette.textSecondary,
    outline: palette.border,
    outlineVariant: palette.border,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: palette.textPrimary,
    onInverseSurface: palette.background,
    inversePrimary: palette.accent,
    surfaceTint: Colors.transparent,
  );

  static InputDecorationThemeData _inputTheme(
    AppPalette palette,
    AppTokens tokens,
  ) => InputDecorationThemeData(
    filled: true,
    fillColor: palette.surfaceVariant,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.md,
    ),
    hintStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
    labelStyle: TextStyle(color: palette.textSecondary, fontSize: 13),
    helperStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
    errorStyle: TextStyle(color: palette.error, fontSize: 12),
    border: _border(palette.border, tokens.fieldRadius),
    enabledBorder: _border(palette.border, tokens.fieldRadius),
    focusedBorder: _border(palette.accent, tokens.fieldRadius, width: 1.5),
    errorBorder: _border(palette.error, tokens.fieldRadius),
    focusedErrorBorder: _border(palette.error, tokens.fieldRadius, width: 1.5),
  );

  static OutlineInputBorder _border(
    Color color,
    double radius, {
    double width = 1,
  }) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: color, width: width),
  );

  static TextTheme _textTheme(TextTheme base, AppPalette palette) => base
      .apply(bodyColor: palette.textPrimary, displayColor: palette.textPrimary)
      .copyWith(
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.25,
          color: palette.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: palette.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: palette.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: palette.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.45,
          color: palette.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: palette.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12.5,
          height: 1.4,
          color: palette.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: palette.textSecondary,
        ),
      )
      .apply(fontFamily: fontFamily);
}
