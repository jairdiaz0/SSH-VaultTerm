import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

import '../../../app/error_messages.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/connection.dart';
import '../../sftp/presentation/sftp_panel.dart';
import '../../ssh/domain/ssh_connection_state.dart';
import '../../terminal/presentation/terminal_key_bar.dart';
import '../../terminal/presentation/terminal_style.dart';
import 'workspace_actions.dart';
import 'workspace_controller.dart';

/// View of the open connection: terminal for SSH, file explorer for SFTP.
/// One connection shows one view; there is no split panel.
class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final connection = controller.connection;
        if (connection == null) {
          return const _EmptyWorkspace();
        }
        final l10n = AppLocalizations.of(context);
        final busy = controller.isBusy;
        final ended = controller.hasEnded;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WorkspaceHeader(controller: controller),
            if (busy) const LinearProgressIndicator(minHeight: 2),
            if (!busy && !ended && controller.errorCode != null)
              _ErrorBanner(code: controller.errorCode!),
            Expanded(
              child: ended
                  ? _SessionEnded(controller: controller)
                  : _content(connection),
            ),
            SizedBox(
              height: AppSpacing.xl + AppSpacing.sm,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    l10n.connectionStatus(label: controller.status),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _content(Connection connection) {
    if (connection.connectionType == ConnectionType.sftp) {
      final sftp = controller.sftp;
      if (sftp == null) return const _FilesUnavailable();
      return SftpPanel(controller: sftp);
    }
    final terminal = controller.terminal;
    if (terminal == null) return const SizedBox.shrink();
    return _TerminalPane(terminal: terminal, onKey: controller.sendTerminal);
  }
}

extension on AppLocalizations {
  String connectionStatus({required SshConnectionStatus label}) =>
      switch (label) {
        SshConnectionStatus.connected => connectionStatusConnected,
        SshConnectionStatus.connecting ||
        SshConnectionStatus.awaitingHostKey ||
        SshConnectionStatus.authenticating => connectionStatusConnecting,
        SshConnectionStatus.disconnectedUnexpectedly ||
        SshConnectionStatus.sessionEnded ||
        SshConnectionStatus.failed => connectionStatusFailed,
        SshConnectionStatus.disconnected => connectionStatusDisconnected,
      };
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.terminal_outlined,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.workspaceEmptyTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.workspaceEmptyBody,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SessionEnded extends StatelessWidget {
  const _SessionEnded({required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final connection = controller.connection;
    final unexpected =
        controller.status == SshConnectionStatus.disconnectedUnexpectedly;
    return Center(
      key: const Key('session-ended'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unexpected ? Icons.cloud_off_outlined : Icons.logout,
              size: 40,
              color: unexpected ? AppColors.danger : AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.sessionEndedTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              unexpected ? l10n.sessionEndedUnexpected : l10n.sessionEndedBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  key: const Key('session-reconnect'),
                  onPressed: connection == null
                      ? null
                      : () =>
                            connectAndExplain(context, controller, connection),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.reconnectAction),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(
                  key: const Key('session-close'),
                  onPressed: controller.dismiss,
                  child: Text(l10n.closeWorkspaceAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final connection = controller.connection!;
    final isSftp = connection.connectionType == ConnectionType.sftp;
    final active = controller.isConnected || controller.isBusy;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSecondary,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(
            isSftp
                ? (active ? Icons.folder : Icons.folder_outlined)
                : (active ? Icons.terminal : Icons.terminal_outlined),
            size: 18,
            color: active ? AppColors.accentSecondary : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${connection.username}@${connection.hostname}:${connection.port}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!active && !controller.hasEnded)
            TextButton.icon(
              key: const Key('reconnect-button'),
              onPressed: () =>
                  connectAndExplain(context, controller, connection),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.reconnectAction),
            ),
          if (active)
            TextButton.icon(
              key: const Key('disconnect-button'),
              onPressed: controller.close,
              icon: const Icon(Icons.link_off, size: 16),
              label: Text(l10n.disconnectAction),
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.code});

  final AppErrorCode code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('workspace-error'),
      width: double.infinity,
      color: AppColors.danger.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              describeAppError(l10n, AppException(code)),
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalPane extends StatelessWidget {
  const _TerminalPane({required this.terminal, required this.onKey});

  final Terminal terminal;
  final void Function(String data) onKey;

  /// The touch key bar is for mobile soft keyboards; desktop keyboards already
  /// produce every sequence natively.
  static bool get _showKeyBar => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.background,
    child: Column(
      children: [
        Expanded(
          child: TerminalView(
            terminal,
            theme: appTerminalTheme,
            textStyle: appTerminalStyle,
            padding: const EdgeInsets.all(AppSpacing.sm),
            autofocus: true,
            // Desktop must read raw key events: the IME text path of xterm
            // 4.0.0 does not deliver printable characters on Windows.
            hardwareKeyboardOnly: !_showKeyBar,
          ),
        ),
        if (_showKeyBar) TerminalKeyBar(onInput: onKey),
      ],
    ),
  );
}

class _FilesUnavailable extends StatelessWidget {
  const _FilesUnavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: AppColors.surfaceSecondary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      alignment: Alignment.center,
      child: Text(
        l10n.sftpOpenFailed,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
