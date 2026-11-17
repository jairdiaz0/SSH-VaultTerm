import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ssh_vault_term/app/app_services.dart';
import 'package:ssh_vault_term/app/profile_session.dart';
import 'package:ssh_vault_term/core/security/password_hasher.dart';
import 'package:ssh_vault_term/core/storage/app_paths.dart';
import 'package:ssh_vault_term/core/storage/app_reset_service.dart';
import 'package:ssh_vault_term/core/storage/secure_storage_secret_store.dart';
import 'package:ssh_vault_term/features/backup/data/backup_importer.dart';
import 'package:ssh_vault_term/features/backup/domain/backup_document.dart';
import 'package:ssh_vault_term/features/connections/data/credential_service.dart';
import 'package:ssh_vault_term/shared/models/connection.dart';
import 'package:ssh_vault_term/shared/models/known_host.dart';
import 'package:ssh_vault_term/shared/models/server_collection.dart';

const _password = 'round4 restart password';

Future<AppServices> coldStart(Directory root, String namespace) =>
    AppServices.fromStorage(
      secrets: SecureStorageSecretStore(namespace: namespace),
      paths: AppPaths(root.path),
      hasher: PasswordHasher(),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('import with real secure storage survives a cold start', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync(
      'ssh_vault_term_backup_it_',
    );
    final namespace = 'backup_it_${DateTime.now().microsecondsSinceEpoch}';

    addTearDown(() async {
      for (var attempt = 0; attempt < 10; attempt++) {
        try {
          if (root.existsSync()) root.deleteSync(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      await SecureStorageSecretStore(namespace: namespace).deletePrefix('');
    });

    // First run.
    var services = await coldStart(root, namespace);
    final profile = await services.profiles.create(
      name: 'Backup',
      password: _password,
      passwordConfirmation: _password,
      params: const Argon2Params(
        memoryKib: 2048,
        iterations: 1,
        parallelism: 1,
        hashLength: 32,
      ),
    );
    final session = await ProfileSession.open(
      profile: profile,
      paths: services.paths,
      keys: services.keys,
    );
    final now = DateTime.utc(2026, 1, 1);
    session.collections.insert(
      ServerCollection(
        id: 'col-1',
        name: 'Servers',
        position: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    session.connections.insert(
      Connection(
        id: 'conn-1',
        collectionId: 'col-1',
        name: 'web-01',
        hostname: 'host.example.com',
        port: 22,
        username: 'deploy',
        authType: AuthenticationType.password,
        credentialId: 'cred-1',
        position: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    session.knownHosts.accept(
      KnownHost(
        id: 'known-1',
        connectionId: 'conn-1',
        hostname: 'host.example.com',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprint: 'SHA256:abcdef',
        createdAt: now,
      ),
    );
    session.close();
    await services.credentials.save(
      profileId: profile.id,
      credentialId: 'cred-1',
      secret: const CredentialSecret(password: 'secret'),
    );
    final text = await services.backupExport.exportText(
      profileId: profile.id,
      password: _password,
    );

    // Import into a fresh installation built over the same data directory.
    services.dispose();
    services = await coldStart(root, namespace);
    final importer = BackupImporter(
      catalog: services.catalog,
      paths: services.paths,
      keys: services.keys,
      credentials: services.credentials,
    );
    await importer.apply(
      BackupDocument.decode(text),
      mode: BackupImportMode.replaceAll,
    );
    services.dispose();

    // Cold start: new services read the keys from the real secret store.
    services = await coldStart(root, namespace);
    final paths = services.paths;
    final keys = services.keys;
    final restarted = services.catalog.profiles.byId(profile.id);
    expect(restarted, isNotNull);
    final reopened = await ProfileSession.open(
      profile: restarted!,
      paths: paths,
      keys: keys,
    );
    try {
      expect(reopened.connections.all().single.name, 'web-01');
      expect(reopened.collections.all().single.name, 'Servers');
      expect(reopened.knownHosts.count(), 1);
    } finally {
      reopened.close();
      services.dispose();
    }

    // Reset with the real secret store: the next start is a fresh install.
    await AppResetService(
      paths: paths,
      keys: keys,
      environment: const {},
    ).reset();
    services = await coldStart(root, namespace);
    expect(services.catalog.profiles.all(), isEmpty);
    services.dispose();
  });
}
