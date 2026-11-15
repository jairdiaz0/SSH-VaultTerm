import 'package:flutter/material.dart';

import '../../../app/error_messages.dart';
import '../../../app/session_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../l10n/generated/app_localizations.dart';

/// First-run wizard. It only exists while the catalog has no profiles; the
/// controller rejects any later use.
class FirstRunScreen extends StatefulWidget {
  const FirstRunScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirmation = _confirmationController.text;

    if (name.isEmpty) {
      setState(() => _message = l10n.errorProfileNameEmpty);
      return;
    }
    if (password.length < profilePasswordMinLength) {
      setState(
        () => _message = l10n.errorPasswordTooShort(profilePasswordMinLength),
      );
      return;
    }
    if (password != confirmation) {
      setState(() => _message = l10n.errorPasswordMismatch);
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await widget.controller.createFirstProfile(
        name: name,
        password: password,
        passwordConfirmation: confirmation,
      );
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _message = describeAppError(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.firstRunTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.firstRunSubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('first-run-name-field'),
                      controller: _nameController,
                      enabled: !_busy,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.profileNameLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('first-run-password-field'),
                      controller: _passwordController,
                      enabled: !_busy,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        helperText: l10n.passwordMinLengthHint(
                          profilePasswordMinLength,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('first-run-confirmation-field'),
                      controller: _confirmationController,
                      enabled: !_busy,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.passwordConfirmLabel,
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      InlineMessage(message: _message!),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('first-run-submit-button'),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.createProfileAction),
                    ),
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
