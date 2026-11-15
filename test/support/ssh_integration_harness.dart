import 'package:sqlite3/sqlite3.dart';
import 'package:ssh_client/core/database/encrypted_database.dart';
import 'package:ssh_client/core/database/schemas.dart';
import 'package:ssh_client/core/utils/app_logger.dart';
import 'package:ssh_client/features/connections/data/connection_repository.dart';
import 'package:ssh_client/features/connections/data/credential_service.dart';
import 'package:ssh_client/features/ssh/data/known_host_repository.dart';
import 'package:ssh_client/features/ssh/data/ssh_service.dart';
import 'package:ssh_client/shared/models/connection.dart';
import 'package:uuid/uuid.dart';

import 'in_memory_secret_store.dart';
import 'ssh_test_server.dart';

const sshIntegrationProfileId = 'profile-1';

/// Wires the real SSH engine against an in-memory encrypted profile database and
/// the dedicated test server.
///
/// One harness per test: the profile database starts empty, so host key and
/// credential state never leak between cases.
class SshIntegrationHarness {
  SshIntegrationHarness._({
    required this.server,
    required this.db,
    required this.credentials,
    required this.knownHosts,
    required this.connections,
    required this.logs,
  }) : service = SshService(
         profileId: sshIntegrationProfileId,
         credentials: credentials,
         knownHosts: knownHosts,
         logger: AppLogger(minLevel: LogLevel.debug, sink: logs.add),
       );

  final SshTestServer server;
  final Database db;
  final CredentialService credentials;
  final KnownHostRepository knownHosts;
  final ConnectionRepository connections;
  final SshService service;
  final List<String> logs;

  static SshIntegrationHarness create(SshTestServer server) {
    final db = EncryptedDatabase.openInMemory(
      key: EncryptedDatabase.generateKey(),
      migrations: ProfileSchema.runner,
    );
    final secrets = InMemorySecretStore();
    final credentials = CredentialService(secrets: secrets);
    return SshIntegrationHarness._(
      server: server,
      db: db,
      credentials: credentials,
      knownHosts: KnownHostRepository(db),
      connections: ConnectionRepository(db),
      logs: [],
    );
  }

  /// Registers a connection row and its credential, as the UI would.
  Future<Connection> addConnection({
    String id = 'conn-1',
    AuthenticationType authType = AuthenticationType.password,
    String? password,
    String? privateKeyPem,
    String? passphrase,
  }) async {
    final credentialId = 'cred-$id';
    final connection = Connection(
      id: id,
      name: 'Test server',
      hostname: server.host,
      port: server.port,
      username: server.username,
      authType: authType,
      credentialId: credentialId,
      position: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    connections.insert(connection);
    await credentials.save(
      profileId: sshIntegrationProfileId,
      credentialId: credentialId,
      secret: CredentialSecret(
        password: password,
        privateKeyPem: privateKeyPem,
        passphrase: passphrase,
      ),
    );
    return connection;
  }

  /// A fresh directory inside the only remote area these tests may touch.
  String newSandbox() => '~/opencode_sandbox/run_${const Uuid().v4()}';

  void dispose() => db.close();
}
