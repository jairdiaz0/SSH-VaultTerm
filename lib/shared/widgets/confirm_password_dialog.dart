import 'package:material_ui/material_ui.dart';

import '../../app/error_messages.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/errors/app_exception.dart';
import '../../l10n/generated/app_localizations.dart';

/// Asks for the profile password and runs [onConfirm] with it.
///
/// [onConfirm] is expected to verify the password (services do it) and throw an
/// [AppException] when it is wrong; the dialog shows the generic message, clears
/// the field and stays open. Nothing is cached: the controller is disposed when
/// the dialog closes, and the password never reaches a log.
Future<bool> showConfirmPasswordDialog(
  BuildContext context, {
  required String title,
  String? body,
  required Future<void> Function(String password) onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ConfirmPasswordDialog(title: title, body: body, onConfirm: onConfirm),
  );
  return confirmed ?? false;
}

class _ConfirmPasswordDialog extends StatefulWidget {
  const _ConfirmPasswordDialog({
    required this.title,
    required this.body,
    required this.onConfirm,
  });

  final String title;
  final String? body;
  final Future<void> Function(String password) onConfirm;

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
  final TextEditingController _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final password = _password.text;
    if (password.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm(password);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = describeAppError(l10n, error);
        _password.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.body != null) ...[
              Text(widget.body!),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              key: const Key('confirm-password-field'),
              controller: _password,
              autofocus: true,
              obscureText: true,
              enabled: !_busy,
              decoration: InputDecoration(labelText: l10n.passwordLabel),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _error!,
                  key: const Key('confirm-password-error'),
                  style: TextStyle(color: context.colors.error, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('confirm-password-cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('confirm-password-submit'),
          onPressed: _busy ? null : _submit,
          child: Text(l10n.confirmAction),
        ),
      ],
    );
  }
}
