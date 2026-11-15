import 'package:material_ui/material_ui.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/connection.dart';
import 'host_key_dialog.dart';
import 'workspace_controller.dart';

/// Connects [connection] on [controller] and explains the outcome.
///
/// The host key dialog is shown for an unknown key; a changed key is never a
/// choice, so it gets an explanatory dialog after the connection is blocked.
Future<void> connectAndExplain(
  BuildContext context,
  WorkspaceController controller,
  Connection connection,
) async {
  await controller.open(
    connection,
    confirmHostKey: (challenge) => showHostKeyConfirmation(context, challenge),
  );
  if (!context.mounted) return;
  if (controller.errorCode == AppErrorCode.hostKeyChanged) {
    await showHostKeyChangedDialog(context, hostname: connection.hostname);
  }
}
