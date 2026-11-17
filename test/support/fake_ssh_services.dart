import 'package:ssh_vault_term/app/app_services.dart';
import 'package:ssh_vault_term/app/profile_session.dart';
import 'package:ssh_vault_term/core/errors/app_exception.dart';
import 'package:ssh_vault_term/features/ssh/data/ssh_connection.dart';
import 'package:ssh_vault_term/features/ssh/data/ssh_service.dart';
import 'package:ssh_vault_term/features/ssh/domain/host_key_verifier.dart';
import 'package:ssh_vault_term/shared/models/connection.dart';

/// Real services with a fake SSH engine: it asks for the host key exactly like
/// the real one does, then fails, so no socket is needed.
///
/// Used to prove that the confirmation dialog is reachable from the dashboard,
/// where the widget that starts the connection disappears as soon as the
/// session tab is shown.
class FakeSshServices extends AppServices {
  FakeSshServices(this.base)
    : super(
        paths: base.paths,
        secrets: base.secrets,
        keys: base.keys,
        hasher: base.hasher,
        catalog: base.catalog,
        profiles: base.profiles,
        auth: base.auth,
        credentials: base.credentials,
        securitySettings: base.securitySettings,
        backupExport: base.backupExport,
        logger: base.logger,
      );

  final AppServices base;

  /// Number of connection attempts, to check a live session is not reopened.
  int connects = 0;

  @override
  SshService sshFor(ProfileSession session) =>
      _FakeSshService(base, session, onConnect: () => connects++);
}

class _FakeSshService extends SshService {
  _FakeSshService(
    AppServices base,
    ProfileSession session, {
    required this.onConnect,
  }) : super(
         profileId: session.profile.id,
         credentials: base.credentials,
         knownHosts: session.knownHosts,
         logger: base.logger,
       );

  final void Function() onConnect;

  @override
  Future<SshConnection> connect(
    Connection connection, {
    required HostKeyConfirmation confirmHostKey,
    SshProgress? onProgress,
  }) async {
    onConnect();
    // A real handshake takes longer than one frame; without this delay the
    // widget that started the connection would still be mounted and the test
    // could not catch a dialog bound to a defunct context.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final accepted = await confirmHostKey(
      HostKeyChallenge(
        hostname: connection.hostname,
        port: connection.port,
        keyType: 'ssh-ed25519',
        fingerprint: 'SHA256:fakeFingerprintForTests',
        status: HostKeyStatus.untrusted,
      ),
    );
    if (!accepted) {
      throw AppException(AppErrorCode.hostKeyRejected);
    }
    // Past the host key check the fake stops: reaching a real server is the
    // job of the integration suite, not of this widget test.
    throw AppException(AppErrorCode.networkUnreachable);
  }
}
