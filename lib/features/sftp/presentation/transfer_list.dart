import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_icons.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/format/bytes.dart';
import '../data/transfer_queue.dart';
import '../domain/transfer.dart';

/// Transfer queue strip: direction, progress, speed and cancel/retry per task.
class TransferList extends StatelessWidget {
  const TransferList({super.key, required this.queue});

  final TransferQueue queue;

  @override
  Widget build(BuildContext context) {
    final tasks = queue.tasks;
    if (tasks.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      constraints: const BoxConstraints(maxHeight: 180),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              l10n.transferQueueTitle,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 6),
              itemCount: tasks.length,
              itemBuilder: (context, index) => _TransferRow(
                task: tasks[tasks.length - 1 - index],
                queue: queue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({required this.task, required this.queue});

  final TransferTask task;
  final TransferQueue queue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                task.direction == TransferDirection.upload
                    ? AppIcons.up
                    : AppIcons.down,
                size: 14,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  task.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Text(
                _statusLabel(l10n, task),
                key: Key('transfer-status-${task.id}'),
                style: TextStyle(
                  fontSize: 11,
                  color: task.status == TransferStatus.failed
                      ? context.colors.error
                      : context.colors.onSurfaceVariant,
                ),
              ),
              if (task.status == TransferStatus.running ||
                  task.status == TransferStatus.pending)
                IconButton(
                  key: Key('transfer-cancel-${task.id}'),
                  tooltip: l10n.cancelAction,
                  icon: const Icon(AppIcons.close, size: 14),
                  onPressed: () => queue.cancel(task.id),
                )
              else if (task.status == TransferStatus.failed ||
                  task.status == TransferStatus.cancelled)
                IconButton(
                  key: Key('transfer-retry-${task.id}'),
                  tooltip: l10n.commonRetry,
                  icon: const Icon(AppIcons.refresh, size: 14),
                  onPressed: () {
                    queue.retry(task.id);
                    queue.start();
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            tween: Tween<double>(
              end: task.status == TransferStatus.completed ? 1 : task.progress,
            ),
            builder: (context, value, _) => LinearProgressIndicator(
              key: Key('transfer-progress-${task.id}'),
              value: value,
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            task.status == TransferStatus.running && task.bytesPerSecond > 0
                ? '${formatBytes(task.transferredBytes)} / '
                      '${formatBytes(task.totalBytes)} · '
                      '${formatSpeed(task.bytesPerSecond)}'
                : '${formatBytes(task.transferredBytes)} / '
                      '${formatBytes(task.totalBytes)}',
            style: TextStyle(
              fontSize: 10,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, TransferTask task) =>
      switch (task.status) {
        TransferStatus.pending => l10n.transferPending,
        TransferStatus.running => l10n.transferRunning,
        TransferStatus.completed => l10n.transferCompleted,
        TransferStatus.failed => l10n.transferFailed,
        TransferStatus.cancelled => l10n.transferCancelled,
      };
}
