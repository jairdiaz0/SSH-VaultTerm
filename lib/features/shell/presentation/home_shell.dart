import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../app/session_controller.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/presentation/settings_dialog.dart';
import '../../workspace/presentation/workspace_panel.dart';
import 'shell_controller.dart';
import 'sidebar.dart';

/// Unlocked desktop shell: sidebar plus workspace.
///
/// Locking or signing out closes the SSH/SFTP sessions before closing the
/// profile database, so no socket outlives the session.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final SessionController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  ShellController? _shell;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSessionChanged);
    _sync();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onSessionChanged);
      widget.controller.addListener(_onSessionChanged);
    }
    _sync();
  }

  void _sync() {
    final session = widget.controller.session;
    if (session == null) return;
    final current = _shell;
    if (current != null && identical(current.session, session)) return;
    _shell?.dispose();
    _shell = ShellController(
      services: widget.controller.services,
      session: session,
    );
  }

  void _onSessionChanged() {
    final before = _shell?.session.profile.id;
    setState(_sync);
    final after = _shell?.session.profile.id;
    if (before == after) return;
    // Creating, switching or deleting a profile invalidates any open dialog
    // that was bound to the previous session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _lock() async {
    await _shell?.workspace.close();
    await widget.controller.lock();
  }

  Future<void> _signOut() async {
    await _shell?.workspace.close();
    await widget.controller.lock();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSessionChanged);
    final shell = _shell;
    _shell = null;
    shell?.dispose();
    super.dispose();
  }

  Future<void> _openSettings(BuildContext context, ShellController shell) =>
      SettingsDialog.show(
        context,
        controller: shell,
        sessionController: widget.controller,
        onLock: _lock,
        onSignOut: _signOut,
      );

  @override
  Widget build(BuildContext context) {
    final shell = _shell;
    if (shell == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppLayout.minWidth;
        Sidebar sidebar() => Sidebar(
          controller: shell,
          onOpenSettings: () => _openSettings(context, shell),
          onLock: _lock,
        );
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  AppIcons.terminal,
                  size: 18,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 8),
                Text(l10n.appTitle),
              ],
            ),
          ),
          drawer: wide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: ListenableBuilder(
                      listenable: shell,
                      builder: (context, _) => sidebar(),
                    ),
                  ),
                ),
          body: ListenableBuilder(
            listenable: shell,
            builder: (context, _) => wide
                ? Row(
                    children: [
                      sidebar(),
                      const VerticalDivider(width: 1, thickness: 1),
                      Expanded(
                        child: WorkspacePanel(controller: shell.workspace),
                      ),
                    ],
                  )
                : WorkspacePanel(controller: shell.workspace),
          ),
        );
      },
    );
  }
}
