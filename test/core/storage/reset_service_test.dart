import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/app/app_services.dart';
import 'package:ssh_client/app/profile_session.dart';
import 'package:ssh_client/core/database/database_key_store.dart';
import 'package:ssh_client/core/security/password_hasher.dart';
import 'package:ssh_client/core/storage/app_paths.dart';
import 'package:ssh_client/core/storage/app_reset_service.dart';
import 'package:ssh_client/shared/models/connection.dart';

import '../../support/app_harness.dart';
import '../../support/in_memory_secret_store.dart';
import '../../support/test_context.dart';

Future<AppServices> servicesFor(Directory root, InMemorySecretStore secrets) =>
    AppServices.fromStorage(
      secrets: secrets,
      paths: AppPaths(root.path),
      hasher: PasswordHasher(derive: testKeyDerivation),
    );

void main() {
  test(
    'reset deletes databases, sidecars and only this app\'s secrets',
    () async {
      final root = Directory.systemTemp.createTempSync('app_reset_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final secrets = InMemorySecretStore();
      await secrets.write('other_app/key', 'keep-me');
      final services = await servicesFor(root, secrets);
      final profile = await services.profiles.create(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
        params: testArgon2Params,
      );
      final session = await ProfileSession.open(
        profile: profile,
        paths: services.paths,
        keys: services.keys,
      );
      session.connections.insert(
        Connection(
          id: 'c1',
          name: 'server',
          hostname: 'host',
          port: 22,
          username: 'root',
          authType: AuthenticationType.password,
          credentialId: 'cred-1',
          position: 0,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      session.close();
      final paths = services.paths;
      final keys = services.keys;
      services.dispose();
      File('${paths.catalogDatabase}-wal').writeAsStringSync('wal');
      File('${paths.catalogDatabase}-shm').writeAsStringSync('shm');

      await AppResetService(
        paths: paths,
        keys: keys,
        environment: const {},
      ).reset();

      expect(File(paths.catalogDatabase).existsSync(), isFalse);
      expect(Directory('${paths.root}/profiles').existsSync(), isFalse);
      expect(File('${paths.catalogDatabase}-wal').existsSync(), isFalse);
      expect(await secrets.keysWithPrefix('profile/'), isEmpty);
      expect(await secrets.keysWithPrefix('catalog/'), isEmpty);
      expect(await secrets.read('other_app/key'), 'keep-me');
    },
  );

  test('after a reset the next start is a fresh installation', () async {
    final root = Directory.systemTemp.createTempSync('app_reset_fresh_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final secrets = InMemorySecretStore();
    var services = await servicesFor(root, secrets);
    final paths = services.paths;
    final keys = services.keys;
    await services.profiles.create(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    services.dispose();
    await AppResetService(
      paths: paths,
      keys: keys,
      environment: const {},
    ).reset();

    services = await servicesFor(root, secrets);
    addTearDown(services.dispose);
    expect(services.catalog.profiles.all(), isEmpty);
    expect(services.auth.hasProfiles, isFalse);
  });

  test('a namespace keeps reset away from other test secrets', () async {
    final root = Directory.systemTemp.createTempSync('app_reset_ns_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final secrets = InMemorySecretStore();
    await secrets.write('ns_a/profile/x/dbKey', 'aa');
    final services = await servicesFor(root, secrets);
    final paths = services.paths;
    final keys = services.keys;
    services.dispose();
    await AppResetService(
      paths: paths,
      keys: keys,
      environment: const {},
    ).reset();
    // The in-memory store has no namespace here, so `ns_a/...` is not ours.
    expect(await secrets.read('ns_a/profile/x/dbKey'), 'aa');
  });

  test('extra platform files (secure storage) are deleted by reset', () async {
    final root = Directory.systemTemp.createTempSync('reset_extra_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final paths = AppPaths(root.path);
    final secrets = InMemorySecretStore();
    final keys = DatabaseKeyStore(secrets: secrets);
    final platformFile = File('${root.path}/flutter_secure_storage.dat')
      ..writeAsStringSync('dpapi');

    await AppResetService(
      paths: paths,
      keys: keys,
      environment: const {},
    ).reset(extraFiles: [platformFile.path]);

    expect(platformFile.existsSync(), isFalse);
  });
}
