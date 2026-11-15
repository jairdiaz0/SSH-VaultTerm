import 'package:material_ui/material_ui.dart';

/// Colour palette from the SPEC (section 4). Dark only: there is no light
/// theme, so these are the single source of truth for every custom widget.
abstract final class AppColors {
  static const background = Color(0xFF0E1113);
  static const surfaceSecondary = Color(0xFF121619);
  static const panel = Color(0xFF1D232A);
  static const elevated = Color(0xFF252D35);
  static const border = Color(0xFF303943);
  static const textPrimary = Color(0xFFE8EDF2);
  static const textSecondary = Color(0xFF929DA8);
  static const accent = Color(0xFF00D4E8);
  static const accentSecondary = Color(0xFF20C997);
  static const danger = Color(0xFFFF5D6C);
  static const warning = Color(0xFFE5AE4B);

  /// Text/icon colour over [accent] and [accentSecondary] fills.
  static const onAccent = Color(0xFF06181B);
}

/// Shared geometry so panels, dialogs and fields stay consistent.
abstract final class AppShape {
  static const radius = 8.0;
  static const radiusLarge = 12.0;

  static const button = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(radius)),
  );

  static BorderSide get borderSide => const BorderSide(color: AppColors.border);
}

abstract final class AppTheme {
  /// Bundled UI font family (assets/fonts/Inter-*.ttf).
  static const fontFamily = 'Inter';

  /// Bundled monospace family for the terminal (assets/fonts/JetBrainsMono-*).
  static const monoFamily = 'JetBrainsMono';

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accentSecondary,
      onSecondary: AppColors.onAccent,
      error: AppColors.danger,
      onError: AppColors.background,
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surfaceSecondary,
      surfaceContainer: AppColors.panel,
      surfaceContainerHigh: AppColors.elevated,
      surfaceContainerHighest: AppColors.elevated,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      inverseSurface: AppColors.textPrimary,
      onInverseSurface: AppColors.background,
      inversePrimary: AppColors.accent,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: fontFamily,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      splashColor: AppColors.accent.withValues(alpha: 0.08),
      highlightColor: AppColors.accent.withValues(alpha: 0.05),
      textTheme: _textTheme(base.textTheme),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.surfaceSecondary,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppShape.radius)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppShape.radiusLarge)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: _inputTheme(),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.elevated,
          disabledForegroundColor: AppColors.textSecondary,
          elevation: 0,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: AppShape.button,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: AppShape.borderSide,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: AppShape.button,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
        minVerticalPadding: 8,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.elevated,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.elevated,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: Color(0x4D00D4E8),
        selectionHandleColor: AppColors.accent,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) => base
      .apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      )
      .copyWith(
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyMedium: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        bodySmall: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      )
      // The copyWith styles above replace the family, so it is applied last.
      .apply(fontFamily: fontFamily);

  static InputDecorationThemeData _inputTheme() => InputDecorationThemeData(
    filled: true,
    fillColor: AppColors.elevated,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
    helperStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
    errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
    border: _inputBorder(AppColors.border),
    enabledBorder: _inputBorder(AppColors.border),
    focusedBorder: _inputBorder(AppColors.accent),
    errorBorder: _inputBorder(AppColors.danger),
    focusedErrorBorder: _inputBorder(AppColors.danger),
  );

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(AppShape.radius)),
    borderSide: BorderSide(color: color),
  );
}
