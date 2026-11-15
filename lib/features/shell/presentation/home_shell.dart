import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../app/session_controller.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../settings/presentation/settings_dialog.dart';
import '../../sftp/presentation/sftp_panel.dart';
import '../../workspace/presentation/workspace_panel.dart';
import 'dashboard_panel.dart';
import 'fingerprints_panel.dart';
import 'shell_controller.dart';
import 'sidebar.dart';
import 'top_bar.dart';

/// Unlocked desktop shell: tab strip, collapsible sidebar and workspace.
///
/// Locking or signing out closes every SSH/SFTP session before closing the
/// profile database, so no socket outlives the session.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final SessionController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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
    await _shell?.closeAllSessions();
    await widget.controller.lock();
  }

  Future<void> _signOut() async {
    await _shell?.closeAllSessions();
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppLayout.minWidth;
        Widget sidebar({VoidCallback? onNavigate, bool collapsible = true}) =>
            Sidebar(
              controller: shell,
              collapsible: collapsible,
              onNavigate: onNavigate,
              onOpenSettings: () => _openSettings(context, shell),
              onLock: _lock,
            );
        return Scaffold(
          key: _scaffoldKey,
          drawer: wide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: ListenableBuilder(
                      listenable: shell,
                      builder: (context, _) => sidebar(
                        collapsible: false,
                        onNavigate: () =>
                            _scaffoldKey.currentState?.closeDrawer(),
                      ),
                    ),
                  ),
                ),
          body: SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: shell,
              builder: (context, _) => Column(
                children: [
                  TopBar(
                    controller: shell,
                    onOpenMenu: wide
                        ? null
                        : () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        if (wide) ...[
                          sidebar(),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: context.colors.outlineVariant,
                          ),
                        ],
                        Expanded(child: _content(context, shell)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, ShellController shell) {
    if (shell.section == ShellSection.fingerprints) {
      return FingerprintsPanel(controller: shell);
    }
    final l10n = AppLocalizations.of(context);
    final tab = shell.activeTab;
    switch (shell.view) {
      case ShellView.dashboard:
        return DashboardPanel(controller: shell);
      case ShellView.sftp:
        final sftp = tab?.workspace.sftp;
        if (sftp == null) {
          return EmptyState(
            icon: AppIcons.folder,
            title: l10n.sftpTabEmptyTitle,
            message: l10n.sftpTabEmptyBody,
          );
        }
        return SftpPanel(controller: sftp);
      case ShellView.session:
        if (tab == null) return DashboardPanel(controller: shell);
        return WorkspacePanel(controller: tab.workspace);
    }
  }
}
