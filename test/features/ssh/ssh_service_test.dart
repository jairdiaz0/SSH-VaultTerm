import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ssh_vault_term/core/database/encrypted_database.dart';
import 'package:ssh_vault_term/core/database/schemas.dart';
import 'package:ssh_vault_term/core/errors/app_exception.dart';
import 'package:ssh_vault_term/core/utils/app_logger.dart';
import 'package:ssh_vault_term/features/connections/data/credential_service.dart';
import 'package:ssh_vault_term/features/ssh/data/known_host_repository.dart';
import 'package:ssh_vault_term/features/ssh/data/ssh_service.dart';
import 'package:ssh_vault_term/features/ssh/domain/ssh_connection_state.dart';
import 'package:ssh_vault_term/shared/models/connection.dart';

import '../../support/in_memory_secret_store.dart';

const _profileId = 'profile-1';

Connection _connection({
  String id = 'conn-1',
  String? credentialId = 'cred-1',
  AuthenticationType authType = AuthenticationType.password,
  String hostname = 'example.com',
  int port = 22,
}) => Connection(
  id: id,
  name: 'Server',
  hostname: hostname,
  port: port,
  username: 'root',
  authType: authType,
  credentialId: credentialId,
  position: 0,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  late Database db;
  late InMemorySecretStore secrets;
  late CredentialService credentials;
  late KnownHostRepository knownHosts;
  late List<String> logs;

  setUp(() {
    db = EncryptedDatabase.openInMemory(
      key: EncryptedDatabase.generateKey(),
      migrations: ProfileSchema.runner,
    );
    secrets = InMemorySecretStore();
    credentials = CredentialService(secrets: secrets);
    knownHosts = KnownHostRepository(db);
    logs = [];
  });

  tearDown(() => db.close());

  SshService service({
    SshSocketOpener? openSocket,
    Duration connectTimeout = const Duration(seconds: 1),
  }) => SshService(
    profileId: _profileId,
    credentials: credentials,
    knownHosts: knownHosts,
    logger: AppLogger(minLevel: LogLevel.debug, sink: logs.add),
    openSocket: openSocket,
    connectTimeout: connectTimeout,
    handshakeTimeout: const Duration(seconds: 1),
    authTimeout: const Duration(seconds: 1),
  );

  Future<void> storePassword(String value, {String id = 'cred-1'}) =>
      credentials.save(
        profileId: _profileId,
        credentialId: id,
        secret: CredentialSecret(password: value),
      );

  test('refuses to connect without a credential id', () async {
    var opened = 0;
    final subject = service(
      openSocket: (host, port, {timeout}) async {
        opened++;
        throw const SocketException('should not be reached');
      },
    );

    await expectLater(
      subject.connect(
        _connection(credentialId: null),
        confirmHostKey: (_) async => true,
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.credentialMissing,
        ),
      ),
    );
    expect(opened, 0);
  });

  test('refuses to connect when the stored secret disappeared', () async {
    final states = <SshConnectionState>[];
    final subject = service(
      openSocket: (host, port, {timeout}) async {
        fail('the socket must not be opened');
      },
    );

    await expectLater(
      subject.connect(
        _connection(),
        confirmHostKey: (_) async => true,
        onProgress: states.add,
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.credentialMissing,
        ),
      ),
    );
    expect(states, isEmpty);
  });

  test('reports an unreachable host and the states it went through', () async {
    await storePassword('correct horse');
    final states = <SshConnectionState>[];
    final subject = service(
      openSocket: (host, port, {timeout}) async {
        expect(host, 'example.com');
        expect(port, 22);
        expect(timeout, isNotNull);
        throw const SocketException('Connection refused');
      },
    );

    await expectLater(
      subject.connect(
        _connection(),
        confirmHostKey: (_) async => true,
        onProgress: states.add,
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.networkUnreachable,
        ),
      ),
    );

    expect(states.map((s) => s.status), [
      SshConnectionStatus.connecting,
      SshConnectionStatus.failed,
    ]);
    expect(states.last.errorCode, AppErrorCode.networkUnreachable);
    expect(logs.single, contains('ssh.connect.failed'));
    expect(logs.single, isNot(contains('correct horse')));
  });

  test('maps a socket timeout to connectionTimeout', () async {
    await storePassword('correct horse');
    final subject = service(
      openSocket: (host, port, {timeout}) async {
        throw TimeoutException('timed out', timeout);
      },
    );

    await expectLater(
      subject.connect(_connection(), confirmHostKey: (_) async => true),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.connectionTimeout,
        ),
      ),
    );
  });

  test('detects a stored private key that cannot be decoded', () async {
    await credentials.save(
      profileId: _profileId,
      credentialId: 'cred-1',
      secret: const CredentialSecret(privateKeyPem: 'not a key'),
    );
    var opened = 0;
    final subject = service(
      openSocket: (host, port, {timeout}) async {
        opened++;
        throw const SocketException('unreachable');
      },
    );

    await expectLater(
      subject.connect(
        _connection(authType: AuthenticationType.privateKey),
        confirmHostKey: (_) async => true,
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.privateKeyInvalid,
        ),
      ),
    );
    expect(opened, 0, reason: 'the key is validated before any network I/O');
  });

  test('an encrypted key without passphrase fails before connecting', () async {
    final pem = File('test/fixtures/keys/ed25519_test_encrypted')
        .readAsStringSync();
    await credentials.save(
      profileId: _profileId,
      credentialId: 'cred-1',
      secret: CredentialSecret(privateKeyPem: pem),
    );
    final subject = service(
      openSocket: (host, port, {timeout}) async {
        fail('the socket must not be opened');
      },
    );

    await expectLater(
      subject.connect(
        _connection(authType: AuthenticationType.privateKey),
        confirmHostKey: (_) async => true,
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.privateKeyPassphraseRequired,
        ),
      ),
    );
  });
}
