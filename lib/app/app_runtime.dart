import 'package:material_ui/material_ui.dart';

/// Exposes an application-level reset to any screen that needs it, without
/// leaking the service graph to widgets.
class AppRuntime extends InheritedWidget {
  const AppRuntime({
    super.key,
    required this.resetApplication,
    required super.child,
  });

  final Future<void> Function() resetApplication;

  static AppRuntime? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppRuntime>();

  @override
  bool updateShouldNotify(AppRuntime oldWidget) =>
      oldWidget.resetApplication != resetApplication;
}
