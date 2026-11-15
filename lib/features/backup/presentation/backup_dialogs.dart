import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_icons.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/profile.dart';
import '../data/backup_importer.dart';
import '../domain/backup_document.dart';

/// The warning the SPEC requires before writing any backup.
Future<bool> showExportWarning(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(AppIcons.warning, color: context.colors.error),
      title: Text(l10n.exportWarningTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Text(
            l10n.exportWarningBody,
            key: const Key('export-warning-body'),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('export-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: context.colors.error),
          child: Text(l10n.exportConfirmAction),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class ImportChoice {
  const ImportChoice({required this.mode, this.targetProfileId});

  final BackupImportMode mode;
  final String? targetProfileId;
}

/// Summary + mode selection before importing.
Future<ImportChoice?> showImportSummary(
  BuildContext context, {
  required BackupDocument document,
  required BackupImportSummary summary,
  required List<Profile> localProfiles,
}) => showDialog<ImportChoice>(
  context: context,
  builder: (_) => _ImportDialog(
    document: document,
    summary: summary,
    localProfiles: localProfiles,
  ),
);

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({
    required this.document,
    required this.summary,
    required this.localProfiles,
  });

  final BackupDocument document;
  final BackupImportSummary summary;
  final List<Profile> localProfiles;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  BackupImportMode _mode = BackupImportMode.merge;
  String? _targetProfileId;

  @override
  void initState() {
    super.initState();
    final localIds = widget.localProfiles.map((profile) => profile.id).toSet();
    for (final profile in widget.document.profiles) {
      if (localIds.contains(profile.id)) {
        _targetProfileId = profile.id;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = widget.summary;
    final target = _targetProfileId;

    return AlertDialog(
      title: Text(l10n.importTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.importSummary(
                  summary.profiles,
                  summary.connections,
                  summary.credentials,
                ),
                key: const Key('import-summary'),
              ),
              const SizedBox(height: 12),
              RadioGroup<BackupImportMode>(
                groupValue: _mode,
                onChanged: (value) => setState(() => _mode = value!),
                child: Column(
                  children: [
                    RadioListTile<BackupImportMode>(
                      key: const Key('import-mode-merge'),
                      value: BackupImportMode.merge,
                      title: Text(l10n.importModeMerge),
                      subtitle: Text(l10n.importModeMergeHelp),
                    ),
                    RadioListTile<BackupImportMode>(
                      key: const Key('import-mode-replace-profile'),
                      value: BackupImportMode.replaceProfile,
                      title: Text(l10n.importModeReplaceProfile),
                      enabled: target != null,
                    ),
                    RadioListTile<BackupImportMode>(
                      key: const Key('import-mode-replace-all'),
                      value: BackupImportMode.replaceAll,
                      title: Text(l10n.importModeReplaceAll),
                      subtitle: Text(l10n.importReplaceWarning),
                    ),
                  ],
                ),
              ),
              if (_mode == BackupImportMode.replaceProfile) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('import-target-profile'),
                  initialValue: target,
                  decoration: InputDecoration(
                    labelText: l10n.importTargetProfile,
                  ),
                  items: [
                    for (final profile in widget.localProfiles)
                      DropdownMenuItem(
                        value: profile.id,
                        child: Text(profile.name),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _targetProfileId = value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('import-confirm'),
          onPressed: () {
            if (_mode == BackupImportMode.replaceProfile &&
                _targetProfileId == null) {
              return;
            }
            Navigator.of(
              context,
            ).pop(ImportChoice(mode: _mode, targetProfileId: _targetProfileId));
          },
          child: Text(l10n.importConfirmAction),
        ),
      ],
    );
  }
}
