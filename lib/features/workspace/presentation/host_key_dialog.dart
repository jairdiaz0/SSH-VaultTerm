import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../ssh/domain/host_key_verifier.dart';

/// Asks the user to trust an unknown host key.
///
/// The fingerprint is selectable so it can be compared with
/// `ssh-keygen -lf` on the server. Closing the dialog is a refusal.
Future<bool> showHostKeyConfirmation(
  BuildContext context,
  HostKeyChallenge challenge,
) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _HostKeyDialog(challenge: challenge),
  );
  return accepted ?? false;
}

/// Explains that a stored host key changed. There is no "continue" action on
/// purpose: the user must forget the stored fingerprint and reconnect.
Future<void> showHostKeyChangedDialog(
  BuildContext context, {
  required String hostname,
}) => showDialog<void>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.gpp_bad_outlined, color: AppColors.danger),
      title: Text(l10n.hostKeyChangedTitle),
      content: Text(l10n.hostKeyChangedBody(hostname)),
      actions: [
        FilledButton(
          key: const Key('host-key-changed-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  },
);

class _HostKeyDialog extends StatelessWidget {
  const _HostKeyDialog({required this.challenge});

  final HostKeyChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.fingerprint, color: AppColors.accent),
      title: Text(l10n.hostKeyDialogTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.hostKeyUnknownBody(challenge.hostname)),
            const SizedBox(height: 16),
            Text(
              l10n.hostKeyKeyTypeLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SelectableText(
              '${challenge.keyType} · ${challenge.hostname}:${challenge.port}',
            ),
            const SizedBox(height: 12),
            Text(
              l10n.hostKeyFingerprintLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SelectableText(
              challenge.fingerprint,
              key: const Key('host-key-fingerprint'),
              style: const TextStyle(fontFamily: AppTheme.monoFamily),
            ),
            if (challenge.isChanged) ...[
              const SizedBox(height: 12),
              Text(
                l10n.hostKeyChangedBody(challenge.hostname),
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('host-key-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        if (!challenge.isChanged)
          FilledButton(
            key: const Key('host-key-accept'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.hostKeyAcceptAction),
          ),
      ],
    );
  }
}
