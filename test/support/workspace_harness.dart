import 'package:ssh_vault_term/features/connections/data/credential_service.dart';
import 'package:ssh_vault_term/shared/models/connection.dart';

import 'app_harness.dart';

/// A connection to a closed loopback port: refused immediately, no real server.
Future<Connection> addUnreachableConnection(AppHarness harness) async {
  final session = harness.controller.session!;
  final now = DateTime.utc(2026, 1, 1);
  final connection = Connection(
    id: 'bad-host',
    name: 'bad-host',
    hostname: '127.0.0.1',
    port: 1,
    username: 'root',
    authType: AuthenticationType.password,
    credentialId: 'cred-bad',
    position: 0,
    createdAt: now,
    updatedAt: now,
  );
  session.connections.insert(connection);
  await harness.services.credentials.save(
    profileId: session.profile.id,
    credentialId: 'cred-bad',
    secret: const CredentialSecret(password: 'irrelevant'),
  );
  return connection;
}
