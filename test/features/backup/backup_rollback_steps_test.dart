import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_vault_term/app/app_services.dart';
import 'package:ssh_vault_term/app/profile_session.dart';
import 'package:ssh_vault_term/core/security/password_hasher.dart';
import 'package:ssh_vault_term/core/storage/app_paths.dart';
import 'package:ssh_vault_term/core/storage/secret_store.dart';
import 'package:ssh_vault_term/features/backup/data/backup_importer.dart';
import 'package:ssh_vault_term/features/backup/domain/backup_document.dart';
import 'package:ssh_vault_term/features/connections/data/credential_service.dart';
import 'package:ssh_vault_term/shared/models/connection.dart';

import '../../support/app_harness.dart';
import '../../support/in_memory_secret_store.dart';
import '../../support/test_context.dart';

class PredicateSecretStore implements SecretStore {
  PredicateSecretStore(this.inner, this.shouldFail);

  final InMemorySecretStore inner;
  bool Function(String key) shouldFail;

  @override
  Future<bool> isAvailable() => inner.isAvailable();

  @override
  Future<void> write(String key, String value) async {
    if (shouldFail(key)) throw StateError('injected failure for $key');
    await inner.write(key, value);
  }

  @override
  Future<String?> read(String key) => inner.read(key);

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<List<String>> keysWithPrefix(String prefix) =>
      inner.keysWithPrefix(prefix);

  @override
  Future<int> deletePrefix(String prefix) => inner.deletePrefix(prefix);
}

Future<AppServices> cold(Directory root, SecretStore secrets) =>
    AppServices.fromStorage(
      secrets: secrets,
      paths: AppPaths(root.path),
      hasher: PasswordHasher(derive: testKeyDerivation),
    );

Future<void> seedProfile(AppServices services, String profileId) async {
  final session = await ProfileSession.open(
    profile: services.catalog.profiles.byId(profileId)!,
    paths: services.paths,
    keys: services.keys,
  );
  try {
    final now = DateTime.utc(2026, 1, 1);
    session.connections.insert(
      Connection(
        id: 'conn-1',
        name: 'old-server',
        hostname: 'old.example.com',
        port: 22,
        username: 'root',
        authType: AuthenticationType.password,
        credentialId: 'cred-1',
        position: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await services.credentials.save(
      profileId: profileId,
      credentialId: 'cred-1',
      secret: const CredentialSecret(password: 'old-secret'),
    );
  } finally {
    session.close();
  }
}

Future<void> expectOldDataReadable(
  Directory root,
  SecretStore secrets,
  String profileId,
) async {
  final restarted = await cold(root, secrets);
  try {
    final session = await ProfileSession.open(
      profile: restarted.catalog.profiles.byId(profileId)!,
      paths: restarted.paths,
      keys: restarted.keys,
    );
    try {
      expect(session.connections.all().single.name, 'old-server');
      final secret = await restarted.credentials.load(
        profileId: profileId,
        credentialId: 'cred-1',
      );
      expect(secret?.password, 'old-secret');
    } finally {
      session.close();
    }
  } finally {
    restarted.dispose();
  }
}

void main() {
  for (final stage in ['staging credentials', 'key promotion']) {
    test('failing at $stage rolls everything back', () async {
      final root = Directory.systemTemp.createTempSync('backup_rollback_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final store = PredicateSecretStore(InMemorySecretStore(), (_) => false);
      var services = await cold(root, store);
      final profile = await services.profiles.create(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
        params: testArgon2Params,
      );
      await seedProfile(services, profile.id);
      final exportText = await services.backupExport.exportText(
        profileId: profile.id,
        password: testPassword,
      );
      final document = BackupDocument.decode(exportText);
      final profileKeyName = SecretKeys.profileDatabaseKey(profile.id);

      var failed = false;
      store.shouldFail = stage == 'staging credentials'
          ? (key) =>
                !failed &&
                key.startsWith('staging/') &&
                key.contains('/credential/') &&
                (failed = true)
          : (key) => !failed && key == profileKeyName && (failed = true);
      final importer = BackupImporter(
        catalog: services.catalog,
        paths: services.paths,
        keys: services.keys,
        credentials: services.credentials,
      );

      await expectLater(
        importer.apply(document, mode: BackupImportMode.replaceAll),
        throwsA(isA<StateError>()),
      );

      final paths = services.paths;
      final keys = services.keys;
      services.dispose();
      store.shouldFail = (_) => false;
      services = await cold(root, store);
      addTearDown(services.dispose);
      expect(
        services.catalog.profiles.byId(profile.id),
        isNotNull,
        reason: 'catalog row restored',
      );
      final stagingLeftovers = Directory(paths.stagingRoot).existsSync()
          ? Directory(paths.stagingRoot).listSync(recursive: true)
          : const <FileSystemEntity>[];
      expect(
        stagingLeftovers,
        isEmpty,
        reason: 'staging cleaned: $stagingLeftovers',
      );
      expect(await keys.hasProfileKey(profile.id), isTrue);
      await expectOldDataReadable(root, store, profile.id);
    });
  }

  test('malformed JSON leaves the installation untouched', () async {
    final root = Directory.systemTemp.createTempSync('backup_malformed_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final store = InMemorySecretStore();
    final services = await cold(root, store);
    addTearDown(services.dispose);
    final profile = await services.profiles.create(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );

    for (final broken in [
      'not json at all',
      '{"formatVersion": 2}',
      '{"formatVersion": 99}',
      '{"formatVersion": 2, "exportedAt": "nope"}',
    ]) {
      expect(
        () => BackupDocument.decode(broken),
        throwsA(anything),
        reason: broken,
      );
    }
    expect(services.catalog.profiles.byId(profile.id), isNotNull);
  });
}
