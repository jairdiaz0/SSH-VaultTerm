import 'package:material_ui/material_ui.dart';

import '../../../app/error_messages.dart';
import '../../../app/session_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/profile.dart';

/// Entry screen when the app starts with at least one profile: one password
/// field, one button, and a discreet way to reach the other existing profiles.
///
/// It never creates profiles.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  Profile? _selected;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _selected =
        widget.controller.lastActiveProfile ??
        (widget.controller.profiles.isEmpty
            ? null
            : widget.controller.profiles.first);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final profile = _selected;
    final password = _passwordController.text;
    if (profile == null || password.isEmpty || _busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await widget.controller.unlock(profileId: profile.id, password: password);
    } on AppException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _message = describeAppError(
          l10n,
          error,
          lockoutRemaining: widget.controller.auth.lockoutRemaining(profile.id),
        );
        _passwordController.clear();
      });
      _passwordFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseProfile() async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showDialog<Profile>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.profileSwitcherTitle),
        children: [
          for (final profile in widget.controller.profiles)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(profile),
              child: Text(profile.name),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _selected = chosen;
      _message = null;
      _passwordController.clear();
    });
    _passwordFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = _selected;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.appTitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.lockTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (profile != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.lockSubtitle(profile.name),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('lock-password-field'),
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      autofocus: true,
                      obscureText: true,
                      enabled: !_busy,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      InlineMessage(message: _message!),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('lock-submit-button'),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.unlockAction),
                    ),
                    if (widget.controller.profiles.length > 1) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('lock-switch-profile'),
                        onPressed: _busy ? null : () => _chooseProfile(),
                        child: Text(l10n.switchProfileAction),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
