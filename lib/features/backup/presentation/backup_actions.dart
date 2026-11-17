import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_services.dart';
import '../../../app/error_messages.dart';
import '../../../core/errors/app_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/confirm_password_dialog.dart';
import '../../shell/presentation/shell_controller.dart';
import '../data/backup_importer.dart';
import '../domain/backup_document.dart';
import 'backup_dialogs.dart';

/// Export and import flows for the settings screen.
///
/// Export writes nothing until the user confirms the security warning. Import
/// validates the whole file first and shows the summary before touching state;
/// when the open profile is going to be replaced, the session is closed first so
/// no database handle outlives its files.
class BackupActions {
  BackupActions({required this.services, required this.controller});

  final AppServices services;
  final ShellController controller;

  BackupImporter get _importer => BackupImporter(
    catalog: services.catalog,
    paths: services.paths,
    keys: services.keys,
    credentials: services.credentials,
  );

  /// Warning → explicit confirmation → profile password → only then is any
  /// secret read and the file written. A failure or a cancellation produces no
  /// file and reads no secret (the service verifies before exporting).
  Future<void> export(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    if (!await showExportWarning(context)) return;
    if (!context.mounted) return;

    String? encoded;
    final authorized = await showConfirmPasswordDialog(
      context,
      title: l10n.confirmPasswordTitle,
      body: l10n.exportPasswordBody,
      onConfirm: (password) async {
        encoded = await services.backupExport.exportText(
          profileId: controller.session.profile.id,
          password: password,
        );
      },
    );
    if (!authorized || encoded == null || !context.mounted) return;

    try {
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[^0-9]'), '')
          .substring(0, 14);
      final saved = await FilePicker.saveFile(
        fileName: 'ssh-vaultterm-backup-$stamp.json',
        bytes: utf8.encode(encoded!),
        mimeType: 'application/json',
      );
      if (!context.mounted || saved == null) return;
      _snack(context, l10n.exportDone);
    } on AppException catch (error) {
      if (!context.mounted) return;
      _snack(context, describeAppError(l10n, error));
    }
  }

  Future<void> import(
    BuildContext context, {
    required Future<void> Function() onLock,
  }) async {
    final l10n = AppLocalizations.of(context);
    final files = await FilePicker.pickFiles();
    if (files.isEmpty || !context.mounted) return;

    BackupDocument document;
    try {
      final bytes = await files.first.readAsBytes();
      document = BackupDocument.decode(utf8.decode(bytes));
    } on AppException catch (error) {
      if (!context.mounted) return;
      _snack(context, describeAppError(l10n, error));
      return;
    }
    if (!context.mounted) return;

    final summary = _importer.summarize(document);
    final choice = await showImportSummary(
      context,
      document: document,
      summary: summary,
      localProfiles: services.catalog.profiles.all(),
    );
    if (choice == null || !context.mounted) return;

    final openProfileId = controller.session.profile.id;
    final replacesOpenProfile =
        choice.mode == BackupImportMode.replaceAll ||
        (choice.mode == BackupImportMode.replaceProfile &&
            choice.targetProfileId == openProfileId);

    if (replacesOpenProfile) {
      // Close the database handle before its files can be replaced.
      await onLock();
    }

    try {
      await _importer.apply(
        document,
        mode: choice.mode,
        targetProfileId: choice.targetProfileId,
      );
    } on Object catch (error) {
      final code = error is AppException
          ? error.code
          : AppErrorCode.backupInvalid;
      services.logger.error('backup.import.failed', {
        'code': code.name,
        'mode': choice.mode.name,
      });
      if (replacesOpenProfile || !context.mounted) return;
      _snack(context, l10n.importFailed);
      return;
    }

    if (replacesOpenProfile) return;
    if (!context.mounted) return;
    controller.reload();
    _snack(context, l10n.importDone);
  }

  static void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}
