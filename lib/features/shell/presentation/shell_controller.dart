import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../app/profile_session.dart';
import '../../../shared/models/connection.dart';
import '../../../shared/models/known_host.dart';
import '../../../shared/models/server_collection.dart';
import '../../workspace/presentation/workspace_actions.dart';
import '../../workspace/presentation/workspace_controller.dart';

/// Sections reachable from the sidebar.
enum ShellSection { connections, fingerprints }

/// What the workspace area is showing.
enum ShellView { dashboard, session }

/// One open session, kept alive while the user moves between tabs.
///
/// The tab owns its [WorkspaceController], so switching tabs never closes the
/// SSH channel, the pty or the SFTP subsystem. Only [ShellController.closeTab]
/// or a disconnect releases them.
class SessionTab {
  SessionTab({required this.connection, required this.workspace});

  final Connection connection;
  final WorkspaceController workspace;

  String get id => connection.id;

  bool get isSftp => connection.connectionType == ConnectionType.sftp;
}

/// View state of the unlocked desktop shell.
///
/// Owns the open sessions and is the only writer of collections, connections
/// and their credentials from the UI. Every mutation reloads the shell through
/// [notifyListeners]; the repositories stay synchronous.
class ShellController extends ChangeNotifier {
  ShellController({required this.services, required this.session})
    : _homeWorkspace = WorkspaceController(
        services: services,
        session: session,
      );

  final AppServices services;
  final ProfileSession session;

  /// Workspace of a connection opened from a test or from the workspace itself
  /// before the tab bar exists. Sessions opened through [connect] get their own.
  final WorkspaceController _homeWorkspace;

  final List<SessionTab> _tabs = [];
  String? _activeId;
  ShellSection _section = ShellSection.connections;
  ShellView _view = ShellView.dashboard;
  bool _collapsed = false;
  bool _disposed = false;

  String get profileName => session.profile.name;

  List<ServerCollection> get collections => session.collections.all();

  List<Connection> get connections => session.connections.all();

  List<Connection> get favorites =>
      connections.where((connection) => connection.favorite).toList();

  List<Connection> get ungrouped => connections
      .where((connection) => connection.collectionId == null)
      .toList();

  List<Connection> connectionsOf(ServerCollection collection) => connections
      .where((connection) => connection.collectionId == collection.id)
      .toList();

  List<KnownHost> get knownHosts => session.knownHosts.all();

  DateTime get now => DateTime.now();

  /// Open sessions, in the order they were opened.
  List<SessionTab> get tabs => List.unmodifiable(_tabs);

  SessionTab? get activeTab {
    final id = _activeId;
    if (id == null) return null;
    for (final tab in _tabs) {
      if (tab.id == id) return tab;
    }
    return null;
  }

  ShellSection get section => _section;

  ShellView get view => _view;

  bool get sidebarCollapsed => _collapsed;

  /// The workspace shown in the current view. Reading it with no session open
  /// returns the shell workspace, never null.
  WorkspaceController get workspace => activeTab?.workspace ?? _homeWorkspace;

  /// Whether editing connections or credentials must ask for the profile
  /// password again. Read from the catalog, so the toggle takes effect at once.
  bool get requireReauthOnEdit {
    final profile = services.catalog.profiles.byId(session.profile.id);
    return profile?.settings['requireReauthOnEdit'] == true;
  }

  void selectSection(ShellSection section) {
    _section = section;
    _view = ShellView.dashboard;
    notifyListeners();
  }

  void showDashboard() {
    _section = ShellSection.connections;
    _view = ShellView.dashboard;
    notifyListeners();
  }

  void toggleSidebar() {
    _collapsed = !_collapsed;
    notifyListeners();
  }

  /// Shows the tab of [tab]; the session keeps running in the background.
  void activateTab(SessionTab tab) {
    if (!_tabs.contains(tab)) return;
    _activeId = tab.id;
    _section = ShellSection.connections;
    _view = ShellView.session;
    notifyListeners();
  }

  /// Opens the tab of [connection], or brings its existing tab to front.
  ///
  /// Never touches the network: [connect] does that, so a live session is not
  /// reopened when the user picks the same server again.
  SessionTab openTab(Connection connection) {
    final existing = _tabFor(connection.id);
    _section = ShellSection.connections;
    if (existing != null) {
      _activeId = existing.id;
      _view = ShellView.session;
      notifyListeners();
      return existing;
    }
    final tab = SessionTab(
      connection: connection,
      workspace: WorkspaceController(services: services, session: session),
    );
    _tabs.add(tab);
    _activeId = tab.id;
    _view = ShellView.session;
    notifyListeners();
    return tab;
  }

  /// Opens [connection] in its own tab, or reuses the tab that already holds
  /// it. A live session is never reopened: the tab is only brought to front.
  ///
  /// Dialogs are bound to the navigator, not to the caller's context: the
  /// dashboard card that starts the connection is unmounted as soon as the
  /// session tab is shown, and a defunct context would silently refuse the host
  /// key (the connection then ended as "host key rejected").
  Future<void> connect(BuildContext context, Connection connection) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final tab = openTab(connection);
    if (tab.workspace.isConnected || tab.workspace.isBusy) return;
    await connectAndExplain(navigator.context, tab.workspace, connection);
    _notify();
  }

  /// Closes one session and releases its channel. The neighbouring tab, if
  /// any, becomes active; otherwise the dashboard is shown.
  Future<void> closeTab(String id) async {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    final tab = _tabs.removeAt(index);
    if (_activeId == id) {
      final next = _tabs.isEmpty
          ? null
          : _tabs[index.clamp(0, _tabs.length - 1)];
      _activeId = next?.id;
      _view = next == null ? ShellView.dashboard : ShellView.session;
    }
    notifyListeners();
    await tab.workspace.close();
    tab.workspace.dispose();
  }

  /// Closes every session before the profile database is closed.
  Future<void> closeAllSessions() async {
    final tabs = List<SessionTab>.from(_tabs);
    _tabs.clear();
    _activeId = null;
    _view = ShellView.dashboard;
    notifyListeners();
    for (final tab in tabs) {
      await tab.workspace.close();
      tab.workspace.dispose();
    }
  }

  /// Changes the setting after the service verifies the password. A wrong
  /// password throws and leaves the stored value untouched.
  Future<void> setRequireReauthOnEdit({
    required bool value,
    required String password,
  }) async {
    await services.securitySettings.setRequireReauthOnEdit(
      profileId: session.profile.id,
      value: value,
      password: password,
    );
    notifyListeners();
  }

  /// Re-checks the profile password with the persistent lockout policy.
  Future<void> verifyPassword(String password) =>
      services.auth.verifyForSensitiveAction(
        profileId: session.profile.id,
        password: password,
      );

  void reload() => notifyListeners();

  void toggleFavorite(Connection connection) {
    session.connections.setFavorite(
      connection.id,
      favorite: !connection.favorite,
      now: now,
    );
    notifyListeners();
  }

  /// Deletes the secret first: without the row, an orphan secret would be
  /// unreachable garbage; without the secret, the row is useless.
  Future<void> deleteConnection(Connection connection) async {
    final tab = _tabFor(connection.id);
    if (tab != null) {
      await closeTab(tab.id);
    } else if (_homeWorkspace.connection?.id == connection.id) {
      await _homeWorkspace.close();
    }
    final credentialId = connection.credentialId;
    if (credentialId != null) {
      await services.credentials.delete(
        profileId: session.profile.id,
        credentialId: credentialId,
      );
    }
    session.connections.delete(connection.id);
    notifyListeners();
  }

  void deleteCollection(ServerCollection collection) {
    session.collections.delete(collection.id);
    notifyListeners();
  }

  /// Moves a collection up (-1) or down (+1). Menu actions instead of drag:
  /// they work with keyboard and screen readers too.
  void moveCollection(ServerCollection collection, int delta) {
    final ordered = collections.map((item) => item.id).toList();
    final index = ordered.indexOf(collection.id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= ordered.length) return;
    ordered
      ..removeAt(index)
      ..insert(target, collection.id);
    session.collections.reorder(ordered, now: now);
    notifyListeners();
  }

  SessionTab? _tabFor(String connectionId) {
    for (final tab in _tabs) {
      if (tab.id == connectionId) return tab;
    }
    return null;
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final tab in _tabs) {
      tab.workspace.dispose();
    }
    _tabs.clear();
    _homeWorkspace.dispose();
    super.dispose();
  }
}
