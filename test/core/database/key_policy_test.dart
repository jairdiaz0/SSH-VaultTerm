import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/app/profile_session.dart';
import 'package:ssh_client/core/database/database_key_store.dart';
import 'package:ssh_client/core/errors/app_exception.dart';
import 'package:ssh_client/core/security/secure_random.dart';
import 'package:ssh_client/core/storage/secret_store.dart';
import 'package:ssh_client/features/profiles/data/catalog_store.dart';

import '../../support/test_context.dart';

void main() {
  late TestContext ctx;

  setUp(() async {
    ctx = await TestContext.create();
  });

  tearDown(() async {
    await ctx.dispose();
  });

  test(
    'a profile file without its key fails and does NOT mint a new key',
    () async {
      final profile = await ctx.profiles.create(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
        params: testArgon2Params,
      );
      await ctx.keys.forgetProfile(profile.id);

      await expectLater(
        ProfileSession.open(profile: profile, paths: ctx.paths, keys: ctx.keys),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.databaseKeyMissing,
          ),
        ),
      );
      expect(await ctx.keys.hasProfileKey(profile.id), isFalse);
    },
  );

  test('a key without its database is reported, not reused', () async {
    final profile = await ctx.profiles.create(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    ctx.paths.deleteProfileFiles(profile.id);

    await expectLater(
      ProfileSession.open(profile: profile, paths: ctx.paths, keys: ctx.keys),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.databaseKeyOrphan,
        ),
      ),
    );
  });

  test(
    'an invalid stored key length is rejected without regenerating',
    () async {
      final profile = await ctx.profiles.create(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
        params: testArgon2Params,
      );
      await ctx.secrets.write(
        SecretKeys.profileDatabaseKey(profile.id),
        'aabb',
      );

      await expectLater(
        ProfileSession.open(profile: profile, paths: ctx.paths, keys: ctx.keys),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.databaseKeyInvalid,
          ),
        ),
      );
    },
  );

  test('the catalog never recreates a key for an existing file', () async {
    ctx.catalog.close();
    await ctx.secrets.delete(SecretKeys.catalogDatabaseKey);

    await expectLater(
      CatalogStore.open(paths: ctx.paths, keys: ctx.keys),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.databaseKeyMissing,
        ),
      ),
    );
    expect(await ctx.keys.hasCatalogKey(), isFalse);
  });

  test(
    'a wrong key is distinct from an invalid one and keeps the data',
    () async {
      final profile = await ctx.profiles.create(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
        params: testArgon2Params,
      );
      await ctx.keys.saveProfileKey(profile.id, CryptoRandom().bytes(32));

      await expectLater(
        ProfileSession.open(profile: profile, paths: ctx.paths, keys: ctx.keys),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.databaseKeyMismatch,
          ),
        ),
      );
      expect(File(ctx.paths.profileDatabase(profile.id)).existsSync(), isTrue);
    },
  );

  test('profile creation is all-or-nothing', () async {
    final profile = await ctx.profiles.create(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    expect(ctx.paths.profileDirectoryExists(profile.id), isTrue);
    expect(await ctx.keys.hasProfileKey(profile.id), isTrue);

    // Recreating the same id must fail without deleting the existing data.
    final keys = DatabaseKeyStore(secrets: ctx.secrets);
    await expectLater(
      keys.createProfileKey(profile.id),
      throwsA(isA<AppException>()),
    );
    expect(await keys.hasProfileKey(profile.id), isTrue);
  });
}
