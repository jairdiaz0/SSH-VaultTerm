import '../../authentication/data/authentication_service.dart';
import '../domain/backup_document.dart';
import 'backup_exporter.dart';

/// Exports a backup only after the profile password has been verified.
///
/// The password check happens **before** the exporter reads any secret from the
/// platform store, so a wrong password or a cancellation never touches secrets
/// and never produces a document (and therefore no file).
class BackupExportService {
  BackupExportService({required this.exporter, required this.auth});

  final BackupExporter exporter;
  final AuthenticationService auth;

  Future<String> exportText({
    required String profileId,
    required String password,
  }) async {
    await auth.verifyForSensitiveAction(
      profileId: profileId,
      password: password,
    );
    final BackupDocument document = await exporter.build();
    return document.encode();
  }
}
