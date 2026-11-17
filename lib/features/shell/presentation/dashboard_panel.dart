import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/connection.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../collections/presentation/collection_dialog.dart';
import '../../connections/presentation/connection_form_dialog.dart';
import 'dashboard_cards.dart';
import 'shell_controller.dart';

enum _DashboardLayout { grid, list }

enum _SortMode { name, host, recent }

/// Round 6 dashboard: search, view and sort on top, favourites, collections and
/// ungrouped servers below, as cards or rows.
class DashboardPanel extends StatefulWidget {
  const DashboardPanel({super.key, required this.controller});

  final ShellController controller;

  @override
  State<DashboardPanel> createState() => _DashboardPanelState();
}

class _DashboardPanelState extends State<DashboardPanel> {
  final _search = TextEditingController();
  _DashboardLayout _layout = _DashboardLayout.grid;
  _SortMode _sort = _SortMode.name;
  String? _tag;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  ShellController get controller => widget.controller;

  List<String> get _allTags {
    final tags = <String>{};
    for (final connection in controller.connections) {
      tags.addAll(connection.tags);
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  List<Connection> _filter(Iterable<Connection> source) {
    final query = _search.text.trim().toLowerCase();
    final tag = _tag;
    final result = source.where((connection) {
      if (tag != null && !connection.tags.contains(tag)) return false;
      if (query.isEmpty) return true;
      return connection.name.toLowerCase().contains(query) ||
          connection.hostname.toLowerCase().contains(query) ||
          connection.username.toLowerCase().contains(query) ||
          connection.tags.any((item) => item.toLowerCase().contains(query));
    }).toList();
    result.sort(switch (_sort) {
      _SortMode.name => (a, b) => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
      _SortMode.host => (a, b) => a.hostname.toLowerCase().compareTo(
        b.hostname.toLowerCase(),
      ),
      _SortMode.recent => (a, b) => b.updatedAt.compareTo(a.updatedAt),
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tags = _allTags;
    final favorites = _filter(controller.favorites);
    final ungrouped = _filter(controller.ungrouped);
    final collections = [
      for (final collection in controller.collections)
        (collection, _filter(controller.connectionsOf(collection))),
    ];
    final hasAnything =
        controller.connections.isNotEmpty || controller.collections.isNotEmpty;
    final filtering = _search.text.trim().isNotEmpty || _tag != null;
    final anyMatch =
        favorites.isNotEmpty ||
        ungrouped.isNotEmpty ||
        collections.any((entry) => entry.$2.isNotEmpty);
    final hasResults = !filtering || anyMatch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(context, l10n),
        if (tags.isNotEmpty) _tagBar(context, tags),
        Expanded(
          child: !hasAnything
              ? EmptyState(
                  icon: AppIcons.terminal,
                  title: l10n.dashboardEmptyTitle,
                  message: l10n.dashboardEmptyBody,
                )
              : !hasResults
              ? EmptyState(
                  icon: AppIcons.search,
                  title: l10n.dashboardNoResults,
                  action: TextButton(
                    key: const Key('dashboard-clear-search'),
                    onPressed: () {
                      _search.clear();
                      setState(() => _tag = null);
                    },
                    child: Text(l10n.dashboardClearFilters),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  children: [
                    if (favorites.isNotEmpty) ...[
                      _SectionTitle(label: l10n.favoritesSection),
                      _cards(favorites),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (collections.isNotEmpty) ...[
                      _SectionTitle(label: l10n.collectionsSection),
                      for (final entry in collections)
                        _collection(context, entry.$2, entry.$1.id),
                    ],
                    if (ungrouped.isNotEmpty) ...[
                      _SectionTitle(
                        label: collections.isEmpty
                            ? l10n.sidebarServersSection
                            : l10n.ungroupedSection,
                      ),
                      _cards(ungrouped),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              key: const Key('dashboard-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.dashboardSearchHint,
                prefixIcon: const Icon(AppIcons.search, size: AppIconSize.sm),
                isDense: true,
              ),
            ),
          ),
          _segmented(context, l10n),
          PopupMenuButton<_SortMode>(
            key: const Key('dashboard-sort'),
            tooltip: l10n.dashboardSortLabel,
            icon: const Icon(AppIcons.sort, size: AppIconSize.sm),
            initialValue: _sort,
            onSelected: (mode) => setState(() => _sort = mode),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _SortMode.name,
                child: Text(l10n.dashboardSortByName),
              ),
              PopupMenuItem(
                value: _SortMode.host,
                child: Text(l10n.dashboardSortByHost),
              ),
              PopupMenuItem(
                value: _SortMode.recent,
                child: Text(l10n.dashboardSortByRecent),
              ),
            ],
          ),
          FilledButton.icon(
            key: const Key('new-connection-button'),
            onPressed: () =>
                ConnectionFormDialog.show(context, controller: controller),
            icon: const Icon(AppIcons.add, size: AppIconSize.sm),
            label: Text(l10n.newConnectionAction),
          ),
          OutlinedButton.icon(
            key: const Key('new-collection-button'),
            onPressed: () =>
                CollectionDialog.show(context, controller: controller),
            icon: const Icon(AppIcons.folderPlus, size: AppIconSize.sm),
            label: Text(l10n.newCollectionAction),
          ),
        ],
      ),
    );
  }

  Widget _segmented(BuildContext context, AppLocalizations l10n) {
    Widget button(
      _DashboardLayout mode,
      IconData icon,
      String tooltip,
      Key key,
    ) {
      final selected = _layout == mode;
      return IconButton(
        key: key,
        tooltip: tooltip,
        iconSize: AppIconSize.sm,
        onPressed: () => setState(() => _layout = mode),
        style: IconButton.styleFrom(
          backgroundColor: selected ? context.colors.surfaceContainer : null,
          foregroundColor: selected
              ? context.colors.onSurface
              : context.colors.onSurfaceVariant,
        ),
        icon: Icon(icon),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(
          _DashboardLayout.grid,
          AppIcons.grid,
          l10n.dashboardGridView,
          const Key('dashboard-view-grid'),
        ),
        button(
          _DashboardLayout.list,
          AppIcons.list,
          l10n.dashboardListView,
          const Key('dashboard-view-list'),
        ),
      ],
    );
  }

  Widget _tagBar(BuildContext context, List<String> tags) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final tag in tags)
            FilterChip(
              key: Key('tag-filter-$tag'),
              label: Text(tag),
              selected: _tag == tag,
              onSelected: (selected) =>
                  setState(() => _tag = selected ? tag : null),
            ),
        ],
      ),
    );
  }

  Widget _collection(
    BuildContext context,
    List<Connection> connections,
    String collectionId,
  ) {
    final l10n = AppLocalizations.of(context);
    final collection = controller.collections.firstWhere(
      (item) => item.id == collectionId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectionHeader(controller: controller, collection: collection),
        if (connections.isEmpty)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              l10n.emptyConnectionsMessage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          _cards(connections),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _cards(List<Connection> connections) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = [
        for (final connection in connections)
          ConnectionCard(
            key: Key('connection-tile-${connection.id}'),
            controller: controller,
            connection: connection,
          ),
      ];
      if (_layout == _DashboardLayout.list) {
        return Column(
          children: [
            for (final card in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: card,
              ),
          ],
        );
      }
      final columns = (constraints.maxWidth / 288).floor().clamp(1, 4);
      final width =
          (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final card in cards) SizedBox(width: width, child: card),
        ],
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
      ],
    ),
  );
}
