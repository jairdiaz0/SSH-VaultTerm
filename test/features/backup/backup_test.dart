import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_vault_term/app/profile_session.dart';
import 'package:ssh_vault_term/core/errors/app_exception.dart';
import 'package:ssh_vault_term/core/storage/secret_store.dart';
import 'package:ssh_vault_term/features/backup/data/backup_exporter.dart';
import 'package:ssh_vault_term/features/backup/data/backup_importer.dart';
import 'package:ssh_vault_term/features/backup/domain/backup_document.dart';
import 'package:ssh_vault_term/features/connections/data/credential_service.dart';
import 'package:ssh_vault_term/shared/models/connection.dart';
import 'package:ssh_vault_term/shared/models/known_host.dart';
import 'package:ssh_vault_term/shared/models/profile.dart';
import 'package:ssh_vault_term/shared/models/server_collection.dart';

import '../../support/in_memory_secret_store.dart';
import '../../support/test_context.dart';

/// Fails once on the next credential write, to force a mid-import failure.
class FailingSecretStore implements SecretStore {
  FailingSecretStore(this.inner, {this.failures = 1});

  final InMemorySecretStore inner;
  int failures;

  Future<void> _maybeFail(String key) async {
    if (failures > 0 && key.contains('/credential/')) {
      failures--;
      throw StateError('injected secret store failure');
    }
  }

  @override
  Future<bool> isAvailable() => inner.isAvailable();

  @override
  Future<void> write(String key, String value) async {
    await _maybeFail(key);
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

void main() {
  late TestContext ctx;
  late CredentialService credentials;
  late BackupExporter exporter;
  late BackupImporter importer;

  Future<void> newContext({SecretStore? secrets}) async {
    ctx = await TestContext.create();
    final store = secrets ?? ctx.secrets;
    credentials = CredentialService(secrets: store);
    exporter = BackupExporter(
      catalog: ctx.catalog,
      paths: ctx.paths,
      keys: ctx.keys,
      credentials: credentials,
      clock: () => ctx.clock.value,
    );
    importer = BackupImporter(
      catalog: ctx.catalog,
      paths: ctx.paths,
      keys: ctx.keys,
      credentials: credentials,
      clock: () => ctx.clock.value,
    );
  }

  tearDown(() async {
    await ctx.dispose();
  });

  Future<ProfileSession> openProfile(String profileId) async {
    final profile = ctx.catalog.profiles.byId(profileId)!;
    return ProfileSession.open(
      profile: profile,
      paths: ctx.paths,
      keys: ctx.keys,
    );
  }

  Future<Connection> seedConnection({
    required String profileId,
    required String id,
    String collectionId = 'col-1',
    String credentialId = 'cred-1',
    String password = 'secret-password',
  }) async {
    final session = await openProfile(profileId);
    try {
      session.collections.insert(
        ServerCollection(
          id: collectionId,
          name: 'Servers',
          position: 0,
          createdAt: ctx.clock.value,
          updatedAt: ctx.clock.value,
        ),
      );
      session.connections.insert(
        Connection(
          id: id,
          collectionId: collectionId,
          name: 'web-$id',
          hostname: 'host-$id.example.com',
          port: 22,
          username: 'deploy',
          authType: AuthenticationType.password,
          credentialId: credentialId,
          favorite: true,
          position: 0,
          createdAt: ctx.clock.value,
          updatedAt: ctx.clock.value,
        ),
      );
      session.knownHosts.accept(
        KnownHost(
          id: 'known-$id',
          connectionId: id,
          hostname: 'host-$id.example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: 'SHA256:$id',
          createdAt: ctx.clock.value,
        ),
      );
      await credentials.save(
        profileId: profileId,
        credentialId: credentialId,
        secret: CredentialSecret(password: password),
      );
      return session.connections.byId(id)!;
    } finally {
      session.close();
    }
  }

  test(
    'exports profiles, data and secrets, but never the master keys',
    () async {
      await newContext();
      final profile = await ctx.profiles.create(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
        params: testArgon2Params,
      );
      await seedConnection(profileId: profile.id, id: 's1');

      final document = await exporter.build();
      final encoded = document.encode();

      expect(document.formatVersion, 2);
      expect(document.profiles.single.id, profile.id);
      expect(document.profileData.single.connections.single.name, 'web-s1');
      expect(document.credentials.single.secret.password, 'secret-password');
      expect(encoded, isNot(contains(testPassword)));

      final catalogKey = base64Encode(await ctx.keys.loadCatalogKey());
      final profileKey = base64Encode(
        await ctx.keys.loadProfileKey(profile.id),
      );
      expect(encoded, isNot(contains(catalogKey)));
      expect(encoded, isNot(contains(profileKey)));
    },
  );

  test('round-trips through JSON into a fresh installation', () async {
    await newContext();
    final profile = await ctx.profiles.create(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    await seedConnection(profileId: profile.id, id: 's1');
    final encoded = (await exporter.build()).encode();

    final originalKey = await ctx.keys.loadProfileKey(profile.id);
    await ctx.dispose();

    await newContext();
    final document = BackupDocument.decode(encoded);
    await importer.apply(document, mode: BackupImportMode.replaceAll);

    final imported = ctx.catalog.profiles.all().single;
    expect(imported.id, profile.id);
    expect(imported.name, 'Work');
    expect(imported.isLastActive, isTrue);
    expect(imported.failedAttempts, 0);

    final session = await openProfile(imported.id);
    addTearDown(session.close);
    expect(session.collections.all().single.name, 'Servers');
    expect(session.connections.all().single.favorite, isTrue);
    expect(session.knownHosts.count(), 1);

    final secret = await credentials.load(
      profileId: imported.id,
      credentialId: 'cred-1',
    );
    expect(secret?.password, 'secret-password');

    // The database key was regenerated: it is not the exported one.
    final newKey = await ctx.keys.loadProfileKey(imported.id);
    expect(base64Encode(newKey), isNot(base64Encode(originalKey)));

    // The original profile password still unlocks the restored profile.
    await ctx.auth.unlock(profileId: imported.id, password: testPassword);
  });

  test('merge keeps local data that is not in the backup', () async {
    await newContext();
    final local = await ctx.profiles.create(
      name: 'Local',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    await seedConnection(profileId: local.id, id: 'local-1');

    final document = await exporter.build();
    await ctx.dispose();

    await newContext();
    final existing = await ctx.profiles.create(
      name: 'Local',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    // A local connection that the backup does not contain must survive.
    final first = await openProfile(existing.id);
    first.connections.insert(
      Connection(
        id: 'only-local',
        name: 'local-only',
        hostname: 'local.example.com',
        port: 22,
        username: 'me',
        authType: AuthenticationType.password,
        credentialId: null,
        position: 0,
        createdAt: ctx.clock.value,
        updatedAt: ctx.clock.value,
      ),
    );
    first.close();

    // Rebuild the document against the original profile id: the merge path
    // creates the missing profile instead of overwriting the local one.
    await importer.apply(document, mode: BackupImportMode.merge);

    final profiles = ctx.catalog.profiles.all();
    expect(
      profiles.map((p) => p.name),
      containsAll(['Local', 'Local (importado)']),
    );
    final imported = profiles.firstWhere((p) => p.id == local.id);
    final session = await openProfile(imported.id);
    addTearDown(session.close);
    expect(session.connections.all().single.id, 'local-1');

    final localSession = await openProfile(existing.id);
    addTearDown(localSession.close);
    expect(
      localSession.connections.all().map((c) => c.id),
      contains('only-local'),
    );
  });

  test('replaceProfile only touches the chosen profile', () async {
    await newContext();
    final target = await ctx.profiles.create(
      name: 'Target',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    final other = await ctx.profiles.create(
      name: 'Other',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    await seedConnection(profileId: target.id, id: 'old');
    final otherSession = await openProfile(other.id);
    otherSession.connections.insert(
      Connection(
        id: 'keep-me',
        name: 'keep',
        hostname: 'keep.example.com',
        port: 22,
        username: 'me',
        authType: AuthenticationType.password,
        credentialId: null,
        position: 0,
        createdAt: ctx.clock.value,
        updatedAt: ctx.clock.value,
      ),
    );
    otherSession.close();

    final document = await exporter.build();
    final data = document.dataFor(target.id)!;
    final replacement = BackupDocument(
      formatVersion: 1,
      exportedAt: document.exportedAt,
      profiles: document.profiles,
      profileData: [
        BackupProfileData(
          profileId: target.id,
          collections: const [],
          connections: const [],
          knownHosts: const [],
        ),
      ],
      credentials: const [],
    );
    expect(data.connections, hasLength(1));

    await importer.apply(
      replacement,
      mode: BackupImportMode.replaceProfile,
      targetProfileId: target.id,
    );

    final targetSession = await openProfile(target.id);
    addTearDown(targetSession.close);
    expect(targetSession.connections.all(), isEmpty);

    final otherAfter = await openProfile(other.id);
    addTearDown(otherAfter.close);
    expect(otherAfter.connections.all().single.id, 'keep-me');
  });

  test('a failed import restores the previous state', () async {
    await newContext();
    final profile = await ctx.profiles.create(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    await seedConnection(profileId: profile.id, id: 's1');
    final encoded = (await exporter.build()).encode();
    await ctx.dispose();

    final failing = FailingSecretStore(InMemorySecretStore(), failures: 1);
    await newContext(secrets: failing);

    await expectLater(
      importer.apply(
        BackupDocument.decode(encoded),
        mode: BackupImportMode.replaceAll,
      ),
      throwsA(isA<StateError>()),
    );

    // Nothing half-imported: the fresh installation is still empty.
    expect(ctx.catalog.profiles.all(), isEmpty);
    expect(await failing.keysWithPrefix('profile/'), isEmpty);
  });

  test('a v1 backup migrates: every connection becomes SSH', () {
    final profile = Profile(
      id: 'p1',
      name: 'Work',
      passwordSalt: const [1, 2, 3],
      passwordVerifier: const [4, 5, 6],
      kdf: 'argon2id',
      kdfParams: jsonEncode(testArgon2Params.toJson()),
      settings: const {},
      isLastActive: true,
      failedAttempts: 0,
      lockoutUntil: null,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final v1Connection = Connection(
      id: 'c1',
      name: 'server',
      hostname: 'host',
      port: 22,
      username: 'root',
      authType: AuthenticationType.password,
      position: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ).toJson()..remove('connectionType');

    final document = BackupDocument.decode(
      jsonEncode({
        'formatVersion': 1,
        'exportedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'profiles': [profile.toJson()],
        'profileData': [
          {
            'profileId': 'p1',
            'collections': const <Object?>[],
            'connections': [v1Connection],
            'knownHosts': const <Object?>[],
          },
        ],
        'credentials': const <Object?>[],
      }),
    );

    expect(document.formatVersion, 1);
    expect(
      document.profileData.single.connections.single.connectionType,
      ConnectionType.ssh,
    );
  });

  test('rejects malformed and future backups with specific codes', () {
    expect(
      () => BackupDocument.decode('not json'),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.backupInvalid,
        ),
      ),
    );
    expect(
      () => BackupDocument.decode('{"formatVersion": 99}'),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.backupVersionUnsupported,
        ),
      ),
    );
    expect(
      () => BackupDocument.decode(
        '{"formatVersion": 1, "exportedAt": "2026-01-01T00:00:00Z", '
        '"profiles": [{"id": "x"}], "profileData": [], "credentials": []}',
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.backupInvalid,
        ),
      ),
    );
  });
}
