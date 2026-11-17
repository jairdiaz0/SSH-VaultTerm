import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'shell_controller.dart';

/// Round 6 sidebar: 220 px of navigation (Conexiones, Huellas, Ajustes) with
/// the profile and the lock at the bottom. Collapses to a 64 px icon rail.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.controller,
    required this.onOpenSettings,
    required this.onLock,
    this.collapsible = true,
    this.onNavigate,
  });

  final ShellController controller;
  final VoidCallback onOpenSettings;
  final VoidCallback onLock;

  /// The drawer is already narrow, so it never collapses inside itself.
  final bool collapsible;

  /// Called after a navigation item is tapped, to close the mobile drawer.
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final collapsed = collapsible && controller.sidebarCollapsed;
    return Material(
      color: context.colors.surfaceContainerLow,
      child: SizedBox(
        width: collapsed ? AppLayout.railWidth : AppLayout.sidebarWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              collapsed: collapsed,
              collapsible: collapsible,
              onToggle: controller.toggleSidebar,
            ),
            const SizedBox(height: AppSpacing.sm),
            _NavItem(
              key: const Key('nav-connections'),
              icon: AppIcons.grid,
              label: l10n.navConnections,
              collapsed: collapsed,
              selected: controller.section == ShellSection.connections,
              onTap: () {
                controller.selectSection(ShellSection.connections);
                onNavigate?.call();
              },
            ),
            _NavItem(
              key: const Key('nav-fingerprints'),
              icon: AppIcons.fingerprint,
              label: l10n.navFingerprints,
              collapsed: collapsed,
              selected: controller.section == ShellSection.fingerprints,
              onTap: () {
                controller.selectSection(ShellSection.fingerprints);
                onNavigate?.call();
              },
            ),
            _NavItem(
              key: const Key('open-settings'),
              icon: AppIcons.settings,
              label: l10n.navSettings,
              collapsed: collapsed,
              selected: false,
              onTap: () {
                onNavigate?.call();
                onOpenSettings();
              },
            ),
            const Spacer(),
            Divider(height: 1, color: context.colors.outlineVariant),
            _Footer(
              collapsed: collapsed,
              profileName: controller.profileName,
              onLock: onLock,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.collapsed,
    required this.collapsible,
    required this.onToggle,
  });

  final bool collapsed;
  final bool collapsible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: AppLayout.topBarHeight,
      padding: EdgeInsets.only(
        left: collapsed ? 0 : AppSpacing.md,
        right: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colors.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          if (!collapsed) ...[
            Icon(AppIcons.shield, size: 18, color: context.colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.appTitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (collapsible)
            IconButton(
              key: const Key('toggle-sidebar'),
              tooltip: collapsed ? l10n.expandSidebar : l10n.collapseSidebar,
              iconSize: AppIconSize.sm,
              onPressed: onToggle,
              icon: const Icon(AppIcons.panelLeft),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 36,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : AppSpacing.sm),
      decoration: BoxDecoration(
        color: selected ? context.colors.surfaceContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisAlignment: collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          if (selected && !collapsed)
            Container(
              width: 2,
              height: 16,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          Icon(
            icon,
            size: AppIconSize.sm,
            color: selected
                ? context.colors.onSurface
                : context.colors.onSurfaceVariant,
          ),
          if (!collapsed) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? context.colors.onSurface
                      : context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return Tooltip(
      message: collapsed ? label : '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: content,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.collapsed,
    required this.profileName,
    required this.onLock,
  });

  final bool collapsed;
  final String profileName;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            Icon(
              AppIcons.users,
              size: AppIconSize.sm,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.xs),
            IconButton(
              key: const Key('lock-session-button'),
              tooltip: l10n.lockSessionAction,
              iconSize: AppIconSize.sm,
              onPressed: onLock,
              icon: const Icon(AppIcons.lock),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.users,
            size: AppIconSize.sm,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              profileName,
              key: const Key('sidebar-profile-name'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            key: const Key('lock-session-button'),
            tooltip: l10n.lockSessionAction,
            iconSize: AppIconSize.sm,
            onPressed: onLock,
            icon: const Icon(AppIcons.lock),
          ),
        ],
      ),
    );
  }
}
