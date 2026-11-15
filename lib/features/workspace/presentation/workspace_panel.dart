import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../../app/error_messages.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/compact_tabs.dart';
import '../../../shared/widgets/resizable_split.dart';
import '../../sftp/presentation/sftp_panel.dart';
import '../../ssh/domain/ssh_connection_state.dart';
import '../../terminal/presentation/terminal_key_bar.dart';
import '../../terminal/presentation/terminal_style.dart';
import 'workspace_actions.dart';
import 'workspace_controller.dart';

/// Right-hand workspace: the terminal of the active session and the SFTP
/// explorer. On desktop it is resizable and maximizable; on narrow layouts the
/// two panes become tabs that keep both channels alive.
class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final WorkspaceController controller;
  final bool compact;

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
        final files = controller.sftp == null
            ? const _FilesUnavailable()
            : SftpPanel(controller: controller.sftp!);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WorkspaceHeader(controller: controller),
            if (controller.isBusy) const LinearProgressIndicator(minHeight: 2),
            if (!controller.isBusy && controller.errorCode != null)
              _ErrorBanner(code: controller.errorCode!),
            Expanded(
              child: controller.terminal == null
                  ? const SizedBox.shrink()
                  : compact
                  ? CompactTabs(
                      firstLabel: l10n.terminalTab,
                      secondLabel: l10n.filesTab,
                      first: _TerminalPane(
                        terminal: controller.terminal!,
                        onKey: controller.sendTerminal,
                      ),
                      second: files,
                    )
                  : ResizableSplit(
                      first: _TerminalPane(
                        terminal: controller.terminal!,
                        onKey: controller.sendTerminal,
                      ),
                      second: files,
                    ),
            ),
            SizedBox(
              height: 28,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
}

extension on AppLocalizations {
  String connectionStatus({required SshConnectionStatus label}) =>
      switch (label) {
        SshConnectionStatus.connected => connectionStatusConnected,
        SshConnectionStatus.connecting ||
        SshConnectionStatus.awaitingHostKey ||
        SshConnectionStatus.authenticating => connectionStatusConnecting,
        SshConnectionStatus.disconnectedUnexpectedly ||
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
          const SizedBox(height: 12),
          Text(l10n.workspaceEmptyTitle),
          const SizedBox(height: 4),
          Text(
            l10n.workspaceEmptyBody,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
    final active = controller.isConnected || controller.isBusy;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSecondary,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.terminal : Icons.terminal_outlined,
            size: 18,
            color: active ? AppColors.accentSecondary : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
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
          if (!active)
            TextButton.icon(
              key: const Key('reconnect-button'),
              onPressed: () => connectAndExplain(
                context,
                controller,
                controller.connection!,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
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
            padding: const EdgeInsets.all(8),
            autofocus: true,
          ),
        ),
        TerminalKeyBar(onInput: onKey),
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
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        l10n.sftpOpenFailed,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
