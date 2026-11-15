import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/connection.dart';
import '../../../shared/models/server_collection.dart';
import '../../collections/presentation/collection_dialog.dart';
import '../../connections/presentation/connection_form_dialog.dart';
import '../../ssh/domain/ssh_connection_state.dart';
import 'shell_controller.dart';

/// Left navigation of the desktop shell: profile, favourites, expandable
/// collections, ungrouped servers and the session status.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.controller,
    required this.onOpenSettings,
    required this.onLock,
  });

  final ShellController controller;
  final VoidCallback onOpenSettings;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final favorites = controller.favorites;
    final collections = controller.collections;
    final ungrouped = controller.ungrouped;

    return Material(
      color: context.colors.surfaceContainerLow,
      child: SizedBox(
        width: AppLayout.sidebarWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              profileName: controller.profileName,
              onOpenSettings: onOpenSettings,
              onLock: onLock,
            ),
            _ConnectionIndicator(controller: controller),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  if (favorites.isNotEmpty) ...[
                    _SectionHeader(title: l10n.favoritesSection),
                    for (final connection in favorites)
                      _ConnectionTile(
                        controller: controller,
                        connection: connection,
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _SectionHeader(title: l10n.collectionsSection),
                  for (final collection in collections)
                    _CollectionTile(
                      controller: controller,
                      collection: collection,
                    ),
                  if (ungrouped.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SectionHeader(title: l10n.sidebarServersSection),
                    for (final connection in ungrouped)
                      _ConnectionTile(
                        controller: controller,
                        connection: connection,
                      ),
                  ],
                  if (favorites.isEmpty &&
                      collections.isEmpty &&
                      ungrouped.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        l10n.emptySidebarHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const Key('new-connection-button'),
                    onPressed: () => ConnectionFormDialog.show(
                      context,
                      controller: controller,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(l10n.newConnectionAction),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    key: const Key('new-collection-button'),
                    onPressed: () =>
                        CollectionDialog.show(context, controller: controller),
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 16,
                    ),
                    label: Text(l10n.newCollectionAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.profileName,
    required this.onOpenSettings,
    required this.onLock,
  });

  final String profileName;
  final VoidCallback onOpenSettings;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: context.colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              profileName,
              key: const Key('sidebar-profile-name'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            key: const Key('open-settings'),
            tooltip: l10n.settingsAction,
            icon: const Icon(Icons.settings_outlined, size: 18),
            onPressed: onOpenSettings,
          ),
          IconButton(
            key: const Key('lock-session-button'),
            tooltip: l10n.lockSessionAction,
            icon: const Icon(Icons.lock_outline, size: 18),
            onPressed: onLock,
          ),
        ],
      ),
    );
  }
}

class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator({required this.controller});

  final ShellController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (status, color) = switch (controller.workspace.status) {
      SshConnectionStatus.connected => (
        l10n.connectionStatusConnected,
        context.colors.secondary,
      ),
      SshConnectionStatus.connecting ||
      SshConnectionStatus.awaitingHostKey ||
      SshConnectionStatus.authenticating => (
        l10n.connectionStatusConnecting,
        context.tokens.warning,
      ),
      SshConnectionStatus.failed => (
        l10n.connectionStatusFailed,
        context.colors.error,
      ),
      SshConnectionStatus.sessionEnded => (
        l10n.sessionEndedTitle,
        context.tokens.warning,
      ),
      SshConnectionStatus.disconnected ||
      SshConnectionStatus.disconnectedUnexpectedly => (
        l10n.connectionStatusDisconnected,
        context.colors.onSurfaceVariant,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(status, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.controller, required this.collection});

  final ShellController controller;
  final ServerCollection collection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final connections = controller.connectionsOf(collection);
    final index = controller.collections.indexOf(collection);
    final isFirst = index == 0;
    final isLast = index == controller.collections.length - 1;

    return ExpansionTile(
      key: Key('collection-tile-${collection.id}'),
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.xs,
      ),
      childrenPadding: const EdgeInsets.only(left: AppSpacing.sm),
      title: Text(collection.name, style: const TextStyle(fontSize: 13)),
      leading: const Icon(Icons.folder_outlined, size: 16),
      trailing: PopupMenuButton<String>(
        key: Key('collection-menu-${collection.id}'),
        icon: const Icon(Icons.more_horiz, size: 16),
        onSelected: (value) async {
          switch (value) {
            case 'rename':
              await CollectionDialog.show(
                context,
                controller: controller,
                existing: collection,
              );
            case 'up':
              controller.moveCollection(collection, -1);
            case 'down':
              controller.moveCollection(collection, 1);
            case 'delete':
              final confirmed = await _confirm(
                context,
                title: l10n.deleteAction,
                body: l10n.confirmDeleteCollection(collection.name),
              );
              if (confirmed) controller.deleteCollection(collection);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'rename', child: Text(l10n.renameAction)),
          PopupMenuItem(
            value: 'up',
            enabled: !isFirst,
            child: Text(l10n.moveUpAction),
          ),
          PopupMenuItem(
            value: 'down',
            enabled: !isLast,
            child: Text(l10n.moveDownAction),
          ),
          PopupMenuItem(value: 'delete', child: Text(l10n.deleteAction)),
        ],
      ),
      children: [
        for (final connection in connections)
          _ConnectionTile(controller: controller, connection: connection),
        if (connections.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              28,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              l10n.emptyConnectionsMessage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({required this.controller, required this.connection});

  final ShellController controller;
  final Connection connection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      key: Key('connection-tile-${connection.id}'),
      dense: true,
      onTap: () => controller.connect(context, connection),
      leading: Icon(
        connection.favorite
            ? Icons.star
            : connection.connectionType == ConnectionType.sftp
            ? Icons.folder_outlined
            : Icons.terminal,
        size: 16,
        color: connection.favorite
            ? context.tokens.warning
            : context.colors.onSurfaceVariant,
      ),
      title: Text(
        connection.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        '${connection.username}@${connection.hostname}:${connection.port}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: PopupMenuButton<String>(
        key: Key('connection-menu-${connection.id}'),
        icon: const Icon(Icons.more_horiz, size: 16),
        onSelected: (value) async {
          switch (value) {
            case 'edit':
              await ConnectionFormDialog.show(
                context,
                controller: controller,
                existing: connection,
              );
            case 'favorite':
              controller.toggleFavorite(connection);
            case 'delete':
              final confirmed = await _confirm(
                context,
                title: l10n.deleteAction,
                body: l10n.confirmDeleteConnection(connection.name),
              );
              if (confirmed) await controller.deleteConnection(connection);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(l10n.editAction)),
          PopupMenuItem(
            value: 'favorite',
            child: Text(
              connection.favorite
                  ? l10n.removeFromFavoritesAction
                  : l10n.addToFavoritesAction,
            ),
          ),
          PopupMenuItem(value: 'delete', child: Text(l10n.deleteAction)),
        ],
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('confirm-delete'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: context.colors.error),
          child: Text(l10n.deleteAction),
        ),
      ],
    ),
  );
  return result ?? false;
}
