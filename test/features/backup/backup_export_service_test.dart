import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_vault_term/core/errors/app_exception.dart';
import 'package:ssh_vault_term/core/storage/secret_store.dart';
import 'package:ssh_vault_term/features/backup/data/backup_export_service.dart';
import 'package:ssh_vault_term/features/backup/data/backup_exporter.dart';
import 'package:ssh_vault_term/features/backup/domain/backup_document.dart';
import 'package:ssh_vault_term/features/connections/data/credential_service.dart';
import 'package:ssh_vault_term/shared/models/connection.dart';

import '../../support/in_memory_secret_store.dart';
import '../../support/test_context.dart';

/// Counts reads of credential secrets to prove that a failed password check
/// never touches the platform store.
class CountingSecretStore implements SecretStore {
  CountingSecretStore(this.inner);

  final InMemorySecretStore inner;
  int credentialReads = 0;

  @override
  Future<bool> isAvailable() => inner.isAvailable();

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<String?> read(String key) {
    if (key.contains('/credential/')) credentialReads++;
    return inner.read(key);
  }

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<List<String>> keysWithPrefix(String prefix) =>
      inner.keysWithPrefix(prefix);

  @override
  Future<int> deletePrefix(String prefix) => inner.deletePrefix(prefix);
}

void main() {
  late TestContext ctx;
  late CountingSecretStore counting;
  late BackupExportService service;

  setUp(() async {
    ctx = await TestContext.create();
    counting = CountingSecretStore(ctx.secrets);
    final credentials = CredentialService(secrets: counting);
    service = BackupExportService(
      exporter: BackupExporter(
        catalog: ctx.catalog,
        paths: ctx.paths,
        keys: ctx.keys,
        credentials: credentials,
      ),
      auth: ctx.auth,
    );

    final profile = await ctx.profiles.create(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    final session = await ctx.openProfile(profile.id);
    session.connections.insert(
      Connection(
        id: 'conn-1',
        name: 'server',
        hostname: 'host',
        port: 22,
        username: 'root',
        authType: AuthenticationType.password,
        credentialId: 'cred-1',
        position: 0,
        createdAt: ctx.clock.value,
        updatedAt: ctx.clock.value,
      ),
    );
    session.close();
    await credentials.save(
      profileId: profile.id,
      credentialId: 'cred-1',
      secret: const CredentialSecret(password: 'ssh-secret'),
    );
    counting.credentialReads = 0;
  });

  tearDown(() async {
    await ctx.dispose();
  });

  test('a wrong password reads no secret and returns no document', () async {
    await expectLater(
      service.exportText(
        profileId: ctx.catalog.profiles.all().single.id,
        password: 'wrong-password',
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.invalidCredentials,
        ),
      ),
    );

    expect(counting.credentialReads, 0);
  });

  test('the correct password exports the credentials', () async {
    final text = await service.exportText(
      profileId: ctx.catalog.profiles.all().single.id,
      password: testPassword,
    );

    expect(counting.credentialReads, greaterThan(0));
    final document = BackupDocument.decode(text);
    expect(document.credentials.single.secret.password, 'ssh-secret');
  });
}
