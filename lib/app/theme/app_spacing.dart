/// Spacing tokens, in logical pixels. Every gap in the UI uses one of these so
/// rhythm stays consistent across screens; no ad-hoc values.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

/// Minimum window size. The layout is designed to fit at least this space; the
/// Windows runner also enforces it so the user cannot shrink into overflow.
abstract final class AppLayout {
  static const minWidth = 900.0;
  static const minHeight = 600.0;
  static const sidebarWidth = 288.0;
}
