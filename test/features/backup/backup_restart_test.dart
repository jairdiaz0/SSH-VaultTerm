import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_vault_term/app/app_services.dart';
import 'package:ssh_vault_term/app/profile_session.dart';
import 'package:ssh_vault_term/core/security/password_hasher.dart';
import 'package:ssh_vault_term/core/storage/app_paths.dart';
import 'package:ssh_vault_term/features/backup/data/backup_importer.dart';
import 'package:ssh_vault_term/features/backup/domain/backup_document.dart';
import 'package:ssh_vault_term/features/connections/data/credential_service.dart';
import 'package:ssh_vault_term/shared/models/connection.dart';
import 'package:ssh_vault_term/shared/models/known_host.dart';
import 'package:ssh_vault_term/shared/models/server_collection.dart';

import '../../support/app_harness.dart';
import '../../support/in_memory_secret_store.dart';
import '../../support/test_context.dart';

/// Simulates a real restart: the same secret store survives, every service
/// object is rebuilt, and the catalog/profile databases are opened again from
/// disk with the keys read from that store.
Future<AppServices> coldStart(Directory root, InMemorySecretStore secrets) =>
    AppServices.fromStorage(
      secrets: secrets,
      paths: AppPaths(root.path),
      hasher: PasswordHasher(derive: testKeyDerivation),
    );

Future<void> seed(AppServices services, String profileId) async {
  final profile = services.catalog.profiles.byId(profileId)!;
  final session = await ProfileSession.open(
    profile: profile,
    paths: services.paths,
    keys: services.keys,
  );
  try {
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
    await services.credentials.save(
      profileId: profileId,
      credentialId: 'cred-1',
      secret: const CredentialSecret(password: 'secret'),
    );
  } finally {
    session.close();
  }
}

Future<void> expectReadableAfterRestart(
  Directory root,
  InMemorySecretStore secrets,
  String profileId,
) async {
  final restarted = await coldStart(root, secrets);
  try {
    final profile = restarted.catalog.profiles.byId(profileId);
    expect(profile, isNotNull, reason: 'catalog must contain the profile');
    final session = await ProfileSession.open(
      profile: profile!,
      paths: restarted.paths,
      keys: restarted.keys,
    );
    try {
      expect(session.connections.all().single.name, 'web-01');
      expect(session.collections.all().single.name, 'Servers');
      expect(session.knownHosts.count(), 1);
    } finally {
      session.close();
    }
  } finally {
    restarted.dispose();
  }
}

void main() {
  for (final mode in BackupImportMode.values) {
    test('import ${mode.name} survives a cold start', () async {
      final root = Directory.systemTemp.createTempSync('backup_restart_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final secrets = InMemorySecretStore();

      final services = await coldStart(root, secrets);
      addTearDown(services.dispose);
      final profile = await services.profiles.create(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
        params: testArgon2Params,
      );
      await seed(services, profile.id);
      final text = await services.backupExport.exportText(
        profileId: profile.id,
        password: testPassword,
      );

      final importer = BackupImporter(
        catalog: services.catalog,
        paths: services.paths,
        keys: services.keys,
        credentials: services.credentials,
      );
      await importer.apply(
        BackupDocument.decode(text),
        mode: mode,
        targetProfileId: mode == BackupImportMode.replaceProfile
            ? profile.id
            : null,
      );
      services.dispose();

      await expectReadableAfterRestart(root, secrets, profile.id);
    });
  }
}
