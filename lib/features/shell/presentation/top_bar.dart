import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../ssh/domain/ssh_connection_state.dart';
import 'shell_controller.dart';

/// Round 6 top bar: a 44 px strip with the pinned sections and one closable
/// tab per live session. Sessions keep running when another tab is shown.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.controller, this.onOpenMenu});

  final ShellController controller;

  /// Only for narrow layouts, where the sidebar lives in a drawer.
  final VoidCallback? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = controller.tabs;
    return Container(
      height: AppLayout.topBarHeight,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: context.colors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (onOpenMenu != null)
            IconButton(
              key: const Key('open-sidebar'),
              tooltip: l10n.expandSidebar,
              iconSize: AppIconSize.sm,
              onPressed: onOpenMenu,
              icon: const Icon(AppIcons.menu),
            ),
          _PinnedTab(
            key: const Key('tab-dashboard'),
            icon: AppIcons.grid,
            label: l10n.tabConnections,
            selected: controller.view == ShellView.dashboard,
            onTap: controller.showDashboard,
          ),
          _PinnedTab(
            key: const Key('tab-sftp'),
            icon: AppIcons.folder,
            label: l10n.tabSftp,
            selected: controller.view == ShellView.sftp,
            onTap: controller.showSftp,
          ),
          if (tabs.isNotEmpty)
            Container(
              width: 1,
              height: AppLayout.topBarHeight,
              color: context.colors.outlineVariant,
            ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final tab = tabs[index];
                return _SessionTab(
                  key: Key('tab-session-${tab.id}'),
                  tabId: tab.id,
                  label: tab.connection.name,
                  icon: tab.isSftp ? AppIcons.folder : AppIcons.terminal,
                  status: tab.workspace.status,
                  selected:
                      controller.view == ShellView.session &&
                      controller.activeTab?.id == tab.id,
                  onTap: () => controller.activateTab(tab),
                  onClose: () => controller.closeTab(tab.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedTab extends StatelessWidget {
  const _PinnedTab({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? context.colors.onSurface
        : context.colors.onSurfaceVariant;
    return Material(
      color: selected ? context.colors.surfaceContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: AppLayout.topBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? context.colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: AppIconSize.sm, color: color),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionTab extends StatelessWidget {
  const _SessionTab({
    super.key,
    required this.tabId,
    required this.label,
    required this.icon,
    required this.status,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final String tabId;
  final String label;
  final IconData icon;
  final SshConnectionStatus status;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final color = selected
        ? context.colors.onSurface
        : context.colors.onSurfaceVariant;
    final dot = switch (status) {
      SshConnectionStatus.connected => tokens.success,
      SshConnectionStatus.connecting ||
      SshConnectionStatus.awaitingHostKey ||
      SshConnectionStatus.authenticating ||
      SshConnectionStatus.sessionEnded => tokens.warning,
      SshConnectionStatus.failed => tokens.palette.error,
      SshConnectionStatus.disconnected ||
      SshConnectionStatus.disconnectedUnexpectedly =>
        context.colors.onSurfaceVariant,
    };
    return Material(
      color: selected ? context.colors.surfaceContainer : Colors.transparent,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadii.field),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.field),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            right: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? context.colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: AppIconSize.sm, color: color),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                width: 8,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              IconButton(
                key: Key('close-tab-$tabId'),
                tooltip: l10n.tabCloseSession,
                visualDensity: VisualDensity.compact,
                iconSize: 14,
                onPressed: onClose,
                icon: const Icon(AppIcons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
