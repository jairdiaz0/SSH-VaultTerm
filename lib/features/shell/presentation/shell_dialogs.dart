import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Confirmation used by every destructive action in the shell. The delete
/// button keeps a stable key so the widget tests can drive it.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('confirm-delete'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: context.colors.error),
          child: Text(l10n.deleteAction),
        ),
      ],
    ),
  );
  return result ?? false;
}
