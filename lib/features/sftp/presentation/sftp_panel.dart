import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/error_messages.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/errors/app_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/format/bytes.dart';
import '../domain/posix_path.dart';
import '../domain/remote_entry.dart';
import 'sftp_controller.dart';
import 'transfer_list.dart';

const _rowHeight = 30.0;

/// Remote file explorer with breadcrumbs, hidden files, transfers and drag-in.
///
/// Drag OUT is not implemented: the dependency that allows it does not resolve
/// (docs/DECISIONS.md D-006), and it is not simulated.
class SftpPanel extends StatefulWidget {
  const SftpPanel({super.key, required this.controller});

  final SftpController controller;

  @override
  State<SftpPanel> createState() => _SftpPanelState();
}

class _SftpPanelState extends State<SftpPanel> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = widget.controller;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        controller.uploadFiles(details.files.map((file) => file.path));
      },
      child: Container(
        key: const Key('sftp-panel'),
        color: _dragging
            ? context.colors.surfaceContainerHigh
            : context.colors.surfaceContainerLow,
        child: ListenableBuilder(
          listenable: Listenable.merge([controller, controller.queue]),
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Toolbar(controller: controller),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: controller.isLoading
                    ? const LinearProgressIndicator(
                        key: ValueKey('sftp-loading'),
                        minHeight: 2,
                      )
                    : const SizedBox(key: ValueKey('sftp-idle'), height: 2),
              ),
              _Breadcrumbs(controller: controller),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  child: KeyedSubtree(
                    key: ValueKey(
                      '${controller.path}|${controller.errorCode?.name}',
                    ),
                    child: _body(l10n, controller),
                  ),
                ),
              ),
              TransferList(queue: controller.queue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n, SftpController controller) {
    final error = controller.errorCode;
    if (error != null) {
      return Center(
        key: const Key('sftp-error'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.folderOff, color: context.colors.error),
              const SizedBox(height: 8),
              Text(
                describeAppError(l10n, AppException(error)),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('sftp-retry'),
                onPressed: controller.refresh,
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }
    final entries = controller.entries;
    if (entries.isEmpty) {
      return Center(
        key: const Key('sftp-empty'),
        child: Text(
          l10n.sftpEmptyFolder,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) =>
          _EntryRow(entry: entries[index], controller: controller),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final SftpController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.folder, size: 16),
          const SizedBox(width: 6),
          Text(l10n.filesTab, style: const TextStyle(fontSize: 12)),
          const Spacer(),
          IconButton(
            key: const Key('sftp-back'),
            tooltip: l10n.backAction,
            icon: const Icon(AppIcons.back, size: 16),
            onPressed: controller.canGoBack ? controller.back : null,
          ),
          IconButton(
            key: const Key('sftp-forward'),
            tooltip: l10n.forwardAction,
            icon: const Icon(AppIcons.forward, size: 16),
            onPressed: controller.canGoForward ? controller.forward : null,
          ),
          IconButton(
            key: const Key('sftp-up'),
            tooltip: l10n.upOneLevelAction,
            icon: const Icon(AppIcons.up, size: 16),
            onPressed: controller.up,
          ),
          IconButton(
            key: const Key('sftp-refresh'),
            tooltip: l10n.refreshAction,
            icon: const Icon(AppIcons.refresh, size: 16),
            onPressed: controller.refresh,
          ),
          IconButton(
            key: const Key('sftp-hidden-toggle'),
            tooltip: controller.showHidden
                ? l10n.hideHiddenAction
                : l10n.showHiddenAction,
            icon: Icon(
              controller.showHidden ? AppIcons.eyeOff : AppIcons.eye,
              size: 16,
            ),
            onPressed: controller.toggleHidden,
          ),
          IconButton(
            key: const Key('sftp-new-folder'),
            tooltip: l10n.sftpNewFolderTitle,
            icon: const Icon(AppIcons.folderPlus, size: 16),
            onPressed: () => _createFolder(context, controller),
          ),
          IconButton(
            key: const Key('sftp-upload'),
            tooltip: l10n.uploadAction,
            icon: const Icon(AppIcons.upload, size: 16),
            onPressed: () => _pickAndUpload(controller),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder(
    BuildContext context,
    SftpController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = await _promptText(
      context,
      title: l10n.sftpNewFolderTitle,
      label: l10n.folderNameLabel,
    );
    if (name == null || name.trim().isEmpty) return;
    final created = await controller.createFolder(name);
    if (!context.mounted) return;
    _snack(context, created ? l10n.sftpFolderCreated : l10n.errorSftpFailure);
  }

  Future<void> _pickAndUpload(SftpController controller) async {
    final files = await FilePicker.pickFiles();
    final paths = files
        .map((file) => file.path)
        .whereType<String>()
        .toList(growable: false);
    await controller.uploadFiles(paths);
  }
}

class _Breadcrumbs extends StatefulWidget {
  const _Breadcrumbs({required this.controller});

  final SftpController controller;

  @override
  State<_Breadcrumbs> createState() => _BreadcrumbsState();
}

class _BreadcrumbsState extends State<_Breadcrumbs> {
  bool _editing = false;
  final TextEditingController _path = TextEditingController();

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  void _beginEdit() {
    _path.text = widget.controller.path;
    _path.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _path.text.length,
    );
    setState(() => _editing = true);
  }

  Future<void> _submit(String value) async {
    final target = value.trim();
    setState(() => _editing = false);
    if (target.isEmpty || target == widget.controller.path) return;
    await widget.controller.open(target);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final segments = PosixPath.segments(controller.path);
    // Ctrl+L focuses the path editor, like OpenSSH clients. The panel owns the
    // focus while it is visible: there is no terminal behind it.
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            HardwareKeyboard.instance.isControlPressed &&
            event.logicalKey == LogicalKeyboardKey.keyL) {
          _beginEdit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        height: 32,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          child: _editing
              ? Padding(
                  key: const ValueKey('editing'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  child: TextField(
                    key: const Key('sftp-path-field'),
                    controller: _path,
                    autofocus: true,
                    style: TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                    ),
                    onSubmitted: _submit,
                    onTapOutside: (_) => setState(() => _editing = false),
                  ),
                )
              : Row(
                  key: const ValueKey('breadcrumbs'),
                  children: [
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        children: [
                          TextButton(
                            key: const Key('crumb-root'),
                            onPressed: () => controller.open('/'),
                            child: const Text('/'),
                          ),
                          for (var index = 0; index < segments.length; index++)
                            TextButton(
                              key: Key('crumb-${segments[index]}'),
                              onPressed: () => controller.open(
                                '/${segments.sublist(0, index + 1).join('/')}',
                              ),
                              child: Text(
                                index == segments.length - 1
                                    ? segments[index]
                                    : '${segments[index]} /',
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Free space: clicking it turns the breadcrumbs into an
                    // editable path. There is no second path label.
                    Expanded(
                      child: GestureDetector(
                        key: const Key('sftp-path-free-space'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _beginEdit,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatefulWidget {
  const _EntryRow({required this.entry, required this.controller});

  final RemoteEntry entry;
  final SftpController controller;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  bool _hovered = false;

  RemoteEntry get entry => widget.entry;
  SftpController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        color: _hovered
            ? context.colors.surfaceContainerHigh
            : Colors.transparent,
        child: InkWell(
          key: Key('sftp-entry-${entry.name}'),
          onTap: entry.isDirectory
              ? () => controller.open(entry.path)
              : () => _download(context, controller, entry),
          child: SizedBox(
            height: _rowHeight,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(
                  entry.isDirectory ? AppIcons.folder : AppIcons.file,
                  size: 14,
                  color: entry.isDirectory
                      ? context.colors.primary
                      : context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    entry.isDirectory ? '—' : formatBytes(entry.size),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: Text(
                    entry.permissions,
                    style: TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 10,
                    ),
                  ),
                ),
                SizedBox(
                  width: 116,
                  child: Text(
                    formatRemoteDate(entry.modifiedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('sftp-entry-menu-${entry.name}'),
                  tooltip: l10n.moreActions,
                  icon: const Icon(AppIcons.more, size: 14),
                  onSelected: (value) => _onMenu(context, value),
                  itemBuilder: (_) => [
                    if (!entry.isDirectory)
                      PopupMenuItem(
                        value: 'download',
                        child: Text(l10n.downloadAction),
                      ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(l10n.renameTitle),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.deleteAction),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String value) async {
    final l10n = AppLocalizations.of(context);
    switch (value) {
      case 'download':
        await _download(context, controller, entry);
      case 'rename':
        final name = await _promptText(
          context,
          title: l10n.renameTitle,
          label: l10n.newNameLabel,
          initial: entry.name,
        );
        if (name == null || name.trim().isEmpty) return;
        final renamed = await controller.rename(entry, name);
        if (!context.mounted) return;
        _snack(context, renamed ? l10n.sftpRenamed : l10n.errorSftpFailure);
      case 'delete':
        final confirmed = await _confirm(
          context,
          l10n.deleteAction,
          entry.name,
        );
        if (!confirmed) return;
        final deleted = await controller.deleteEntry(entry);
        if (!context.mounted) return;
        _snack(context, deleted ? l10n.sftpDeleted : l10n.errorSftpFailure);
    }
  }

  Future<void> _download(
    BuildContext context,
    SftpController controller,
    RemoteEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context);
    final directory = await FilePicker.getDirectoryPath();
    if (directory == null) return;
    await controller.downloadTo(entry, directory);
    if (!context.mounted) return;
    _snack(context, l10n.sftpDownloadStarted);
  }
}

Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _TextPromptDialog(title: title, label: label, initial: initial),
);

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.initial,
  });

  final String title;
  final String label;
  final String initial;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: TextField(
          key: const Key('sftp-text-field'),
          controller: _text,
          autofocus: true,
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
          key: const Key('sftp-text-save'),
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String subject,
) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(subject),
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

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
