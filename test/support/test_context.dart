import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/app/profile_session.dart';

import 'package:ssh_client/core/database/database_key_store.dart';
import 'package:ssh_client/core/security/password_hasher.dart';
import 'package:ssh_client/core/storage/app_paths.dart';
import 'package:ssh_client/features/authentication/data/authentication_service.dart';
import 'package:ssh_client/features/profiles/data/catalog_store.dart';
import 'package:ssh_client/features/profiles/data/profile_service.dart';

import 'in_memory_secret_store.dart';

/// Cheap Argon2 parameters for tests: correctness, not cost, is under test.
const testArgon2Params = Argon2Params(
  memoryKib: 1024,
  iterations: 1,
  parallelism: 1,
  hashLength: 32,
);

const testPassword = 'correct horse battery';

/// A clock tests can advance.
class MutableClock {
  DateTime value = DateTime.utc(2026, 1, 1, 12);

  DateTime call() => value;

  void advance(Duration duration) => value = value.add(duration);
}

/// Wires the real production services against a temp directory and the
/// in-memory secret store.
class TestContext {
  TestContext._({
    required this.root,
    required this.paths,
    required this.secrets,
    required this.keys,
    required this.catalog,
    required this.hasher,
    required this.profiles,
    required this.auth,
    required this.clock,
  });

  final Directory root;
  final AppPaths paths;
  final InMemorySecretStore secrets;
  final DatabaseKeyStore keys;
  final CatalogStore catalog;
  final PasswordHasher hasher;
  final ProfileService profiles;
  final AuthenticationService auth;
  final MutableClock clock;

  static Future<TestContext> create() async {
    final root = Directory.systemTemp.createTempSync('ssh_client_test_');
    final paths = AppPaths(root.path);
    final secrets = InMemorySecretStore();
    final keys = DatabaseKeyStore(secrets: secrets);
    final hasher = PasswordHasher.direct();
    final catalog = await CatalogStore.open(paths: paths, keys: keys);
    final clock = MutableClock();

    final context = TestContext._(
      root: root,
      paths: paths,
      secrets: secrets,
      keys: keys,
      catalog: catalog,
      hasher: hasher,
      profiles: ProfileService(
        catalog: catalog,
        keys: keys,
        hasher: hasher,
        paths: paths,
        clock: clock.call,
      ),
      auth: AuthenticationService(
        catalog: catalog,
        hasher: hasher,
        clock: clock.call,
      ),
      clock: clock,
    );
    // Registered as soon as the directory exists: a failing test still cleans up.
    addTearDown(context.dispose);
    return context;
  }

  Future<ProfileSession> openProfile(String profileId) async {
    final profile = catalog.profiles.byId(profileId)!;
    return ProfileSession.open(profile: profile, paths: paths, keys: keys);
  }

  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      catalog.close();
    } catch (_) {
      // A test may have closed it already.
    }
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
