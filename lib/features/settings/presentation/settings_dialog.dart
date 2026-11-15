import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shell/presentation/shell_controller.dart';

/// Settings for the unlocked profile: identity, known host keys and session
/// actions. Everything here reads real data from the profile database.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.controller,
    required this.onLock,
    required this.onSignOut,
  });

  final ShellController controller;
  final VoidCallback onLock;
  final VoidCallback onSignOut;

  static Future<void> show(
    BuildContext context, {
    required ShellController controller,
    required VoidCallback onLock,
    required VoidCallback onSignOut,
  }) => showDialog<void>(
    context: context,
    builder: (_) => SettingsDialog(
      controller: controller,
      onLock: onLock,
      onSignOut: onSignOut,
    ),
  );

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = widget.controller;
    final knownHosts = controller.session.knownHosts;

    return AlertDialog(
      title: Text(l10n.settingsTitle),
      content: SizedBox(
        width: 520,
        height: 440,
        child: ListView(
          children: [
            _SectionHeader(title: l10n.profileSection),
            ListTile(
              leading: const Icon(Icons.shield_outlined, size: 18),
              title: Text(controller.profileName),
            ),
            const SizedBox(height: 8),
            _SectionHeader(title: l10n.securitySection),
            _SectionHeader(title: l10n.knownHostsTitle),
            if (knownHosts.count() == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  l10n.knownHostsEmpty,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            for (final connection in controller.connections)
              for (final known in knownHosts.byConnection(connection.id))
                ListTile(
                  key: Key('known-host-${known.id}'),
                  dense: true,
                  title: Text(
                    l10n.knownHostsEntry(
                      known.hostname,
                      known.port,
                      known.keyType,
                    ),
                  ),
                  subtitle: Text(
                    known.fingerprint,
                    style: const TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 11,
                    ),
                  ),
                  trailing: IconButton(
                    key: Key('forget-known-host-${known.id}'),
                    tooltip: l10n.deleteAction,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () {
                      knownHosts.delete(known.id);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.hostKeyForgotten)),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('settings-sign-out'),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSignOut();
          },
          child: Text(l10n.signOutAction),
        ),
        TextButton(
          key: const Key('settings-lock'),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onLock();
          },
          child: Text(l10n.lockSessionAction),
        ),
        FilledButton(
          key: const Key('settings-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4, left: 12),
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
