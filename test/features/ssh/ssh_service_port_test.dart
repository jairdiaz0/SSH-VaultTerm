import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_vault_term/core/errors/app_exception.dart';
import 'package:ssh_vault_term/core/utils/app_logger.dart';
import 'package:ssh_vault_term/features/connections/data/credential_service.dart';
import 'package:ssh_vault_term/features/ssh/data/ssh_service.dart';
import 'package:ssh_vault_term/shared/models/connection.dart';

import '../../support/app_harness.dart';
import '../../support/test_context.dart';

void main() {
  test(
    'connects to the host and port of the connection, not the defaults',
    () async {
      final harness = await AppHarness.create();
      addTearDown(harness.dispose);
      await harness.controller.createFirstProfile(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
      );
      final session = harness.controller.session!;
      const credentialId = 'cred-1';
      await harness.services.credentials.save(
        profileId: session.profile.id,
        credentialId: credentialId,
        secret: const CredentialSecret(password: 'secret-password'),
      );

      var seen = <Object>[];
      final service = SshService(
        profileId: session.profile.id,
        credentials: harness.services.credentials,
        knownHosts: session.knownHosts,
        logger: AppLogger(),
        openSocket: (host, port, {timeout}) async {
          seen = [host, port];
          // Stop before the handshake: the socket destination is what matters.
          throw AppException(AppErrorCode.networkUnreachable);
        },
      );

      await expectLater(
        service.connect(
          Connection(
            id: 'c1',
            name: 'custom-port',
            hostname: '10.0.0.9',
            port: 2222,
            username: 'deploy',
            authType: AuthenticationType.password,
            credentialId: credentialId,
            position: 0,
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
          confirmHostKey: (_) async => true,
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            AppErrorCode.networkUnreachable,
          ),
        ),
      );

      expect(seen, ['10.0.0.9', 2222]);
    },
  );
}
