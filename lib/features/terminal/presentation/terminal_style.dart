import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

import '../../../app/theme/app_theme.dart';

/// Terminal colours derived from the app palette, so the terminal never looks
/// like a foreign surface inside the app. ANSI slots follow the usual dark
/// values, tuned for contrast on [AppColors.background].
const appTerminalTheme = TerminalTheme(
  cursor: AppColors.accent,
  selection: Color(0x4D00D4E8),
  foreground: AppColors.textPrimary,
  background: AppColors.background,
  black: Color(0xFF0E1113),
  red: Color(0xFFFF5D6C),
  green: Color(0xFF20C997),
  yellow: Color(0xFFE5AE4B),
  blue: Color(0xFF4D9DFF),
  magenta: Color(0xFFC792EA),
  cyan: Color(0xFF00D4E8),
  white: Color(0xFFC7D0D9),
  brightBlack: Color(0xFF5C6B78),
  brightRed: Color(0xFFFF8A95),
  brightGreen: Color(0xFF5CE0B5),
  brightYellow: Color(0xFFF2C879),
  brightBlue: Color(0xFF7FB9FF),
  brightMagenta: Color(0xFFDDB3F5),
  brightCyan: Color(0xFF5CE3F0),
  brightWhite: Color(0xFFE8EDF2),
  searchHitBackground: Color(0xFFE5AE4B),
  searchHitBackgroundCurrent: Color(0xFFFFD98A),
  searchHitForeground: AppColors.background,
);

/// Terminal text style: bundled monospace, sized for density.
const appTerminalStyle = TerminalStyle(
  fontFamily: AppTheme.monoFamily,
  fontSize: 13,
  height: 1.3,
);
