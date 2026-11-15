import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/connection.dart';
import '../../../shared/models/server_collection.dart';
import '../../collections/presentation/collection_dialog.dart';
import '../../connections/presentation/connection_form_dialog.dart';
import 'shell_controller.dart';
import 'shell_dialogs.dart';

/// One server: a 64 px card in the grid or a full-width row in the list.
class ConnectionCard extends StatelessWidget {
  const ConnectionCard({
    super.key,
    required this.controller,
    required this.connection,
  });

  final ShellController controller;
  final Connection connection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSftp = connection.connectionType == ConnectionType.sftp;
    return Material(
      color: context.colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: () => controller.connect(context, connection),
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Icon(
                  isSftp ? AppIcons.folder : AppIcons.terminal,
                  size: AppIconSize.sm,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${connection.username}@${connection.hostname}:'
                      '${connection.port}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (connection.favorite)
                Icon(AppIcons.star, size: 12, color: context.tokens.warning),
              const SizedBox(width: AppSpacing.xs),
              _TypeBadge(label: isSftp ? l10n.typeSftp : l10n.typeSsh),
              PopupMenuButton<String>(
                key: Key('connection-menu-${connection.id}'),
                iconSize: AppIconSize.sm,
                icon: const Icon(AppIcons.more),
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
                      final confirmed = await confirmDestructive(
                        context,
                        title: l10n.deleteAction,
                        body: l10n.confirmDeleteConnection(connection.name),
                      );
                      if (confirmed) {
                        await controller.deleteConnection(connection);
                      }
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
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.deleteAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header of one collection, with its reorder and delete actions.
class CollectionHeader extends StatelessWidget {
  const CollectionHeader({
    super.key,
    required this.controller,
    required this.collection,
  });

  final ShellController controller;
  final ServerCollection collection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ids = controller.collections.map((item) => item.id).toList();
    final index = ids.indexOf(collection.id);
    final total = controller.connectionsOf(collection).length;
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Icon(
            AppIcons.folder,
            size: AppIconSize.sm,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              collection.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text('$total', style: Theme.of(context).textTheme.bodySmall),
          PopupMenuButton<String>(
            key: Key('collection-menu-${collection.id}'),
            iconSize: AppIconSize.sm,
            icon: const Icon(AppIcons.more),
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
                  final confirmed = await confirmDestructive(
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
                enabled: index > 0,
                child: Text(l10n.moveUpAction),
              ),
              PopupMenuItem(
                value: 'down',
                enabled:
                    index >= 0 && index < controller.collections.length - 1,
                child: Text(l10n.moveDownAction),
              ),
              PopupMenuItem(value: 'delete', child: Text(l10n.deleteAction)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: context.colors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadii.chip),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}
