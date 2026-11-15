import 'package:material_ui/material_ui.dart';

import '../../../app/error_messages.dart';
import '../../../app/session_controller.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/profile.dart';
import '../domain/profile_rules.dart';

/// Profile management from Settings: create (only while unlocked), switch and
/// delete with password confirmation. The locked screen keeps its discreet
/// "switch profile" link and never offers creation.
class ProfileManagementDialog extends StatefulWidget {
  const ProfileManagementDialog({super.key, required this.controller});

  final SessionController controller;

  static Future<void> show(
    BuildContext context, {
    required SessionController controller,
  }) => showDialog<void>(
    context: context,
    builder: (_) => ProfileManagementDialog(controller: controller),
  );

  @override
  State<ProfileManagementDialog> createState() =>
      _ProfileManagementDialogState();
}

class _ProfileManagementDialogState extends State<ProfileManagementDialog> {
  String? _error;

  SessionController get controller => widget.controller;

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final data = await showDialog<_NewProfileData>(
      context: context,
      builder: (_) => const _NewProfileDialog(),
    );
    if (data == null || !mounted) return;
    try {
      await controller.createProfile(
        name: data.name,
        password: data.password,
        passwordConfirmation: data.confirmation,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.profileCreated)));
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = describeAppError(l10n, error));
    }
  }

  Future<void> _switch(Profile profile) async {
    final l10n = AppLocalizations.of(context);
    final password = await _askPassword(
      l10n.profilePasswordPrompt(profile.name),
    );
    if (password == null || !mounted) return;
    try {
      await controller.unlock(profileId: profile.id, password: password);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = describeAppError(l10n, error));
    }
  }

  Future<void> _delete(Profile profile) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProfileAction),
        content: Text(l10n.confirmDeleteProfile(profile.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-delete-profile'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final password = await _askPassword(
      l10n.profilePasswordPrompt(profile.name),
    );
    if (password == null || !mounted) return;
    final valid = await controller.auth.confirmPassword(
      profileId: profile.id,
      password: password,
    );
    if (!mounted) return;
    if (!valid) {
      setState(() => _error = l10n.errorInvalidCredentials);
      return;
    }
    await controller.deleteProfile(profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.profileDeleted)));
    setState(() => _error = null);
  }

  Future<String?> _askPassword(String label) => showDialog<String>(
    context: context,
    builder: (_) => _PasswordDialog(label: label),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentId = controller.profile?.id;
    final profiles = controller.profiles;

    return AlertDialog(
      title: Text(l10n.profilesTitle),
      content: SizedBox(
        width: 460,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  _error!,
                  key: const Key('profile-management-error'),
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final profile in profiles)
                    ListTile(
                      key: Key('profile-row-${profile.id}'),
                      leading: Icon(
                        profile.id == currentId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: profile.id == currentId
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      title: Text(profile.name),
                      subtitle: profile.id == currentId
                          ? Text(l10n.currentProfileLabel)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (profile.id != currentId)
                            IconButton(
                              key: Key('switch-profile-${profile.id}'),
                              tooltip: l10n.switchProfileAction,
                              icon: const Icon(Icons.login, size: 18),
                              onPressed: () => _switch(profile),
                            ),
                          IconButton(
                            key: Key('delete-profile-${profile.id}'),
                            tooltip: l10n.deleteProfileAction,
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            onPressed: () => _delete(profile),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              key: const Key('create-profile-button'),
              onPressed: _create,
              icon: const Icon(Icons.person_add_alt, size: 16),
              label: Text(l10n.createProfileAction),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('profiles-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

class _NewProfileData {
  const _NewProfileData(this.name, this.password, this.confirmation);

  final String name;
  final String password;
  final String confirmation;
}

class _NewProfileDialog extends StatefulWidget {
  const _NewProfileDialog();

  @override
  State<_NewProfileDialog> createState() => _NewProfileDialogState();
}

class _NewProfileDialogState extends State<_NewProfileDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.errorProfileNameEmpty);
      return;
    }
    if (_password.text.length < ProfileRules.minPasswordLength) {
      setState(
        () =>
            _error = l10n.errorPasswordTooShort(ProfileRules.minPasswordLength),
      );
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _error = l10n.errorPasswordMismatch);
      return;
    }
    Navigator.of(context)
        .pop(_NewProfileData(name, _password.text, _confirmation.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.createProfileAction),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('new-profile-name'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.profileNameLabel),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('new-profile-password'),
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.passwordLabel),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('new-profile-confirmation'),
              controller: _confirmation,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.passwordConfirmLabel),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _error!,
                  key: const Key('new-profile-error'),
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('new-profile-save'),
          onPressed: _submit,
          child: Text(l10n.createProfileAction),
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.label});

  final String label;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.passwordLabel),
      content: SizedBox(
        width: 360,
        child: TextField(
          key: const Key('profile-password-field'),
          controller: _password,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(labelText: widget.label),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('profile-password-confirm'),
          onPressed: () => Navigator.of(context).pop(_password.text),
          child: Text(l10n.unlockAction),
        ),
      ],
    );
  }
}
