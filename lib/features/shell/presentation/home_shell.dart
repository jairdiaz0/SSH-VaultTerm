import 'package:flutter/material.dart';

import '../../../app/session_controller.dart';
import '../../../app/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/connection.dart';
import '../../../shared/models/server_collection.dart';

/// Unlocked desktop shell.
///
/// Phase 1 scope: shows the real content of the unlocked profile (its
/// collections and connections) and the lock action. Collections/connections
/// CRUD, the terminal and SFTP arrive in later phases; nothing here fakes a
/// capability that does not exist yet.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = controller.session;
    final profile = controller.profile;
    if (session == null || profile == null) {
      return const SizedBox.shrink();
    }

    final collections = session.collections.all();
    final connections = session.connections.all();
    final favorites = connections.where((c) => c.favorite).toList();
    final ungrouped = connections.where((c) => c.collectionId == null).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, size: 18),
            const SizedBox(width: 8),
            Text(profile.name),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('lock-session-button'),
            tooltip: l10n.lockSessionAction,
            icon: const Icon(Icons.lock_outline, size: 18),
            onPressed: controller.lock,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.connectionCountLabel(connections.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (collections.isEmpty && connections.isEmpty)
            _EmptyProfile(l10n: l10n)
          else ...[
            if (favorites.isNotEmpty) ...[
              _SectionHeader(title: l10n.favoritesSection),
              _ConnectionGroup(connections: favorites),
              const SizedBox(height: 20),
            ],
            if (collections.isNotEmpty) ...[
              _SectionHeader(title: l10n.collectionsSection),
              for (final collection in collections)
                _CollectionCard(
                  collection: collection,
                  connections: connections
                      .where((c) => c.collectionId == collection.id)
                      .toList(),
                ),
              const SizedBox(height: 20),
            ],
            if (ungrouped.isNotEmpty) ...[
              _SectionHeader(title: l10n.connectionsSection),
              _ConnectionGroup(connections: ungrouped),
            ],
            if (collections.isEmpty &&
                connections.isNotEmpty &&
                ungrouped.isEmpty) ...[
              _SectionHeader(title: l10n.collectionsSection),
              Text(
                l10n.emptyCollectionsMessage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _EmptyProfile extends StatelessWidget {
  const _EmptyProfile({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        const Icon(
          Icons.dns_outlined,
          size: 32,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 12),
        Text(l10n.emptyConnectionsMessage, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection, required this.connections});

  final ServerCollection collection;
  final List<Connection> connections;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                collection.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (connections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    AppLocalizations.of(context).emptyConnectionsMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else
                _ConnectionGroup(connections: connections),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionGroup extends StatelessWidget {
  const _ConnectionGroup({required this.connections});

  final List<Connection> connections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final connection in connections)
          _ConnectionTile(connection: connection),
      ],
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({required this.connection});

  final Connection connection;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        '${connection.username}@${connection.hostname}:${connection.port}';
    return ListTile(
      dense: true,
      leading: Icon(
        connection.favorite ? Icons.star : Icons.terminal,
        size: 18,
        color: connection.favorite
            ? AppColors.warning
            : AppColors.textSecondary,
      ),
      title: Text(connection.name),
      subtitle: Text(subtitle),
    );
  }
}
