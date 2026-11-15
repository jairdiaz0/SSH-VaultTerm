import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../app/profile_session.dart';
import '../../../shared/models/connection.dart';
import '../../../shared/models/server_collection.dart';
import '../../workspace/presentation/workspace_actions.dart';
import '../../workspace/presentation/workspace_controller.dart';

/// View state of the unlocked desktop shell.
///
/// Owns the workspace (one SSH session) and is the only writer of collections,
/// connections and their credentials from the UI. Every mutation reloads the
/// shell through [notifyListeners]; the repositories stay synchronous.
class ShellController extends ChangeNotifier {
  ShellController({required this.services, required this.session})
    : workspace = WorkspaceController(services: services, session: session);

  final AppServices services;
  final ProfileSession session;
  final WorkspaceController workspace;

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

  DateTime get now => DateTime.now();

  /// Whether editing connections or credentials must ask for the profile
  /// password again. Read from the catalog, so the toggle takes effect at once.
  bool get requireReauthOnEdit {
    final profile = services.catalog.profiles.byId(session.profile.id);
    return profile?.settings['requireReauthOnEdit'] == true;
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

  Future<void> connect(BuildContext context, Connection connection) async {
    await connectAndExplain(context, workspace, connection);
    notifyListeners();
  }

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
    if (workspace.connection?.id == connection.id) {
      await workspace.close();
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

  @override
  void dispose() {
    workspace.dispose();
    super.dispose();
  }
}
