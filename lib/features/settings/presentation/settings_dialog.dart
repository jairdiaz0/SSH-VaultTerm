import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../app/app_runtime.dart';
import '../../../app/session_controller.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../core/storage/app_reset_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/confirm_password_dialog.dart';
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
  Future<void> _showStorageStatus() async {
    final l10n = AppLocalizations.of(context);
    final status = await AppResetService(
      paths: widget.controller.services.paths,
      keys: widget.controller.services.keys,
      environment: Platform.environment,
    ).inspectAsync();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.storageStatusTitle),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                dense: true,
                title: Text(l10n.storageCatalogLabel),
                subtitle: Text(
                  !status.catalogExists
                      ? l10n.storageAbsent
                      : !status.catalogKeyExists
                      ? l10n.storageCatalogKeyMissing
                      : status.catalogOpens
                      ? l10n.storageCatalogOk
                      : l10n.storageCatalogError(
                          status.profileError ?? 'unknown',
                        ),
                ),
              ),
              for (final profile in status.profiles)
                ListTile(
                  dense: true,
                  title: Text(profile.id),
                  subtitle: Text(
                    l10n.storageProfileLabel(
                      profile.id,
                      profile.fileExists
                          ? l10n.storagePresent
                          : l10n.storageAbsent,
                      profile.keyExists
                          ? l10n.storagePresent
                          : l10n.storageAbsent,
                      profile.opens
                          ? l10n.storageCatalogOk
                          : (profile.errorCode?.name ?? l10n.storageAbsent),
                    ),
                  ),
                ),
              if (status.pendingReset)
                ListTile(dense: true, title: Text(l10n.storagePendingReset)),
              if (status.legacyWindowsData)
                ListTile(dense: true, title: Text(l10n.storageLegacy)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Future<void> _resetApplication() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ResetConfirmationDialog(),
    );
    if (confirmed != true || !mounted) return;
    final profile = widget.sessionController.profile;
    if (profile == null) return;
    final authorized = await showConfirmPasswordDialog(
      context,
      title: l10n.confirmPasswordTitle,
      body: l10n.resetWarningBody,
      onConfirm: (password) => widget.sessionController.auth
          .verifyForSensitiveAction(profileId: profile.id, password: password),
    );
    if (!authorized || !mounted) return;
    final runtime = AppRuntime.maybeOf(context);
    try {
      if (runtime == null) throw StateError('no runtime');
      await runtime.resetApplication();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.resetFailed)));
    }
  }

  Future<void> _lockAndClose() async {
    Navigator.of(context).pop();
    widget.onLock();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeController = AppThemeScope.maybeOf(context);
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
              leading: const Icon(AppIcons.shield, size: 18),
              title: Text(controller.profileName),
            ),
            ListTile(
              key: const Key('manage-profiles'),
              leading: const Icon(AppIcons.users, size: 18),
              title: Text(l10n.manageProfilesAction),
              onTap: () => ProfileManagementDialog.show(
                context,
                controller: widget.sessionController,
              ),
            ),
            const SizedBox(height: 8),
            if (themeController != null) ...[
              _SectionHeader(title: l10n.appearanceSection),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.themeLabel, style: context.texts.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedButton<ThemeMode>(
                      key: const Key('theme-selector'),
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(l10n.themeSystem),
                          icon: Icon(AppIcons.settings, size: AppIconSize.sm),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(l10n.themeLight),
                          icon: Icon(AppIcons.eye, size: AppIconSize.sm),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(l10n.themeDark),
                          icon: Icon(AppIcons.eyeOff, size: AppIconSize.sm),
                        ),
                      ],
                      selected: {themeController.mode},
                      onSelectionChanged: (selection) =>
                          themeController.setMode(selection.first),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                key: const Key('terminal-dark-switch'),
                value: themeController.alwaysDarkTerminal,
                onChanged: themeController.setAlwaysDarkTerminal,
                title: Text(l10n.terminalAlwaysDark),
                subtitle: Text(l10n.terminalAlwaysDarkHelp),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _SectionHeader(title: l10n.securitySection),
            SwitchListTile(
              key: const Key('reauth-switch'),
              value: controller.requireReauthOnEdit,
              onChanged: (value) async {
                final confirmed = await showConfirmPasswordDialog(
                  context,
                  title: l10n.confirmPasswordTitle,
                  body: l10n.requireReauthHelp,
                  onConfirm: (password) => controller.setRequireReauthOnEdit(
                    value: value,
                    password: password,
                  ),
                );
                if (confirmed && mounted) setState(() {});
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
                    style: TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 11,
                    ),
                  ),
                  trailing: IconButton(
                    key: Key('forget-known-host-${known.id}'),
                    tooltip: l10n.deleteAction,
                    icon: const Icon(AppIcons.delete, size: 18),
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
            _SectionHeader(title: l10n.advancedSection),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    key: const Key('storage-status-button'),
                    onPressed: _showStorageStatus,
                    icon: const Icon(AppIcons.info, size: AppIconSize.sm),
                    label: Text(l10n.storageStatusAction),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('reset-app-button'),
                    onPressed: _resetApplication,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.error,
                      side: BorderSide(color: context.colors.error),
                    ),
                    icon: const Icon(AppIcons.warning, size: AppIconSize.sm),
                    label: Text(l10n.resetApplicationAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
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
                    icon: const Icon(AppIcons.download, size: 16),
                    label: Text(l10n.exportBackupAction),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    key: const Key('import-backup-button'),
                    onPressed: () => BackupActions(
                      services: controller.services,
                      controller: controller,
                    ).import(context, onLock: _lockAndClose),
                    icon: const Icon(AppIcons.upload, size: 16),
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

/// Strong confirmation: the user must type the word, and then the profile
/// password is requested separately.
class _ResetConfirmationDialog extends StatefulWidget {
  const _ResetConfirmationDialog();

  @override
  State<_ResetConfirmationDialog> createState() =>
      _ResetConfirmationDialogState();
}

class _ResetConfirmationDialogState extends State<_ResetConfirmationDialog> {
  final TextEditingController _word = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      icon: Icon(AppIcons.warning, color: context.colors.error),
      title: Text(l10n.resetWarningTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.resetWarningBody),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.resetTypeWord),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('reset-word-field'),
              controller: _word,
              autofocus: true,
              onChanged: (value) =>
                  setState(() => _matches = value.trim() == l10n.resetWord),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('reset-confirm-word'),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(backgroundColor: context.colors.error),
          child: Text(l10n.resetConfirmAction),
        ),
      ],
    );
  }
}
