import 'package:flutter/material.dart';

import '../../../app/session_controller.dart';
import '../../../app/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../backup/presentation/backup_actions.dart';
import '../../profiles/presentation/profile_management_dialog.dart';
import '../../shell/presentation/shell_controller.dart';

/// Settings for the unlocked profile: identity, known host keys and session
/// actions. Everything here reads real data from the profile database.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.controller,
    required this.sessionController,
    required this.onLock,
    required this.onSignOut,
  });

  final ShellController controller;
  final SessionController sessionController;
  final VoidCallback onLock;
  final VoidCallback onSignOut;

  static Future<void> show(
    BuildContext context, {
    required ShellController controller,
    required SessionController sessionController,
    required VoidCallback onLock,
    required VoidCallback onSignOut,
  }) => showDialog<void>(
    context: context,
    builder: (_) => SettingsDialog(
      controller: controller,
      sessionController: sessionController,
      onLock: onLock,
      onSignOut: onSignOut,
    ),
  );

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  /// Closes this dialog, then locks: used when an import replaces the open
  /// profile and its database handle must be released first.
  Future<void> _lockAndClose() async {
    Navigator.of(context).pop();
    widget.onLock();
  }

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
            ListTile(
              key: const Key('manage-profiles'),
              leading: const Icon(Icons.people_outline, size: 18),
              title: Text(l10n.manageProfilesAction),
              onTap: () => ProfileManagementDialog.show(
                context,
                controller: widget.sessionController,
              ),
            ),
            const SizedBox(height: 8),
            _SectionHeader(title: l10n.securitySection),
            SwitchListTile(
              key: const Key('reauth-switch'),
              value: controller.requireReauthOnEdit,
              onChanged: (value) {
                controller.setRequireReauthOnEdit(value);
                setState(() {});
              },
              title: Text(l10n.requireReauthLabel),
              subtitle: Text(l10n.requireReauthHelp),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
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
            const SizedBox(height: 8),
            _SectionHeader(title: l10n.backupSection),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    key: const Key('export-backup-button'),
                    onPressed: () => BackupActions(
                      services: controller.services,
                      controller: controller,
                    ).export(context),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: Text(l10n.exportBackupAction),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    key: const Key('import-backup-button'),
                    onPressed: () => BackupActions(
                      services: controller.services,
                      controller: controller,
                    ).import(context, onLock: _lockAndClose),
                    icon: const Icon(Icons.upload_outlined, size: 16),
                    label: Text(l10n.importBackupAction),
                  ),
                ],
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
