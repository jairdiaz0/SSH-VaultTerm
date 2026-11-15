import 'package:material_ui/material_ui.dart';

import '../features/authentication/presentation/lock_screen.dart';
import '../features/profiles/presentation/first_run_screen.dart';
import '../features/shell/presentation/home_shell.dart';
import 'session_controller.dart';

/// Chooses the screen for the current session state and rebuilds whenever the
/// controller changes.
///
/// Only three states exist: no profiles at all (first run), profiles but
/// locked, and unlocked. Creating profiles is impossible from the locked state
/// because [LockScreen] has no path to [SessionController.createProfile].
class SessionGate extends StatelessWidget {
  const SessionGate({super.key, required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.hasProfiles) {
          return FirstRunScreen(controller: controller);
        }
        if (!controller.isUnlocked) {
          return LockScreen(controller: controller);
        }
        return HomeShell(controller: controller);
      },
    );
  }
}
