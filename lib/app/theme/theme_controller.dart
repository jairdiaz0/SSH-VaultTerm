// Private fields cannot be named formal parameters, so they are assigned in the
// constructor body; the prefer_initializing_formals lint cannot apply.
// ignore_for_file: prefer_initializing_formals
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global appearance preference (not per profile: the lock screen shows before
/// any profile database is open).
///
/// Loaded before the first frame so the app never flashes the wrong theme.
class ThemeController extends ChangeNotifier {
  ThemeController._({
    SharedPreferences? preferences,
    ThemeMode mode = ThemeMode.system,
    bool alwaysDarkTerminal = false,
  }) : _preferences = preferences,
       _mode = mode,
       _alwaysDarkTerminal = alwaysDarkTerminal;

  static const modeKey = 'ui.themeMode';
  static const terminalDarkKey = 'ui.terminalAlwaysDark';

  final SharedPreferences? _preferences;
  ThemeMode _mode;
  bool _alwaysDarkTerminal;

  ThemeMode get mode => _mode;
  bool get alwaysDarkTerminal => _alwaysDarkTerminal;

  /// In-memory controller for tests and for the fallback app surface.
  factory ThemeController.memory({
    ThemeMode mode = ThemeMode.system,
    bool alwaysDarkTerminal = false,
  }) => ThemeController._(mode: mode, alwaysDarkTerminal: alwaysDarkTerminal);

  static Future<ThemeController> load() async {
    final preferences = await SharedPreferences.getInstance();
    return ThemeController._(
      preferences: preferences,
      mode: _parse(preferences.getString(modeKey)),
      alwaysDarkTerminal: preferences.getBool(terminalDarkKey) ?? false,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _preferences?.setString(modeKey, _serialize(mode));
  }

  Future<void> setAlwaysDarkTerminal(bool value) async {
    if (value == _alwaysDarkTerminal) return;
    _alwaysDarkTerminal = value;
    notifyListeners();
    await _preferences?.setBool(terminalDarkKey, value);
  }

  /// Removes the appearance preferences (application reset).
  Future<void> resetPreferences() async {
    _mode = ThemeMode.system;
    _alwaysDarkTerminal = false;
    notifyListeners();
    await _preferences?.remove(modeKey);
    await _preferences?.remove(terminalDarkKey);
  }

  static ThemeMode _parse(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _serialize(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

/// Exposes the controller to settings without threading it through every widget.
class AppThemeScope extends InheritedNotifier<ThemeController> {
  const AppThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>()?.notifier;
}
