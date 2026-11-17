import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';
import 'shell_controller.dart';

/// Known host fingerprints of this profile, in the workspace area.
///
/// The same list lives in the settings dialog; both read the profile session,
/// so forgetting a key in one place is reflected in the other.
class FingerprintsPanel extends StatelessWidget {
  const FingerprintsPanel({super.key, required this.controller});

  final ShellController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hosts = controller.knownHosts;
    if (hosts.isEmpty) {
      return EmptyState(
        icon: AppIcons.fingerprint,
        title: l10n.knownHostsTitle,
        message: l10n.knownHostsEmpty,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          l10n.knownHostsTitle,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final known in hosts)
          ListTile(
            key: Key('known-host-${known.id}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              AppIcons.fingerprint,
              size: AppIconSize.sm,
              color: context.colors.onSurfaceVariant,
            ),
            title: Text(
              l10n.knownHostsEntry(known.hostname, known.port, known.keyType),
            ),
            subtitle: Text(
              known.fingerprint,
              style: TextStyle(fontFamily: AppTheme.monoFamily, fontSize: 11),
            ),
            trailing: IconButton(
              key: Key('forget-known-host-${known.id}'),
              tooltip: l10n.deleteAction,
              iconSize: AppIconSize.sm,
              onPressed: () {
                controller.session.knownHosts.delete(known.id);
                controller.reload();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.hostKeyForgotten)));
              },
              icon: const Icon(AppIcons.delete),
            ),
          ),
      ],
    );
  }
}
