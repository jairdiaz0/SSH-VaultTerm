import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_vault_term/core/errors/app_exception.dart';
import 'package:ssh_vault_term/core/storage/secret_store.dart';

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
    'creates the first profile as last active with its own database key',
    () async {
      final profile = await ctx.profiles.create(
        name: '  Personal  ',
        password: testPassword,
        passwordConfirmation: testPassword,
        params: testArgon2Params,
      );

      expect(profile.name, 'Personal');
      expect(profile.isLastActive, isTrue);
      expect(profile.kdf, 'argon2id');
      expect(profile.passwordSalt.length, 16);
      expect(profile.passwordVerifier.length, 32);
      expect(ctx.catalog.profiles.count(), 1);
      expect(
        await ctx.secrets.read(SecretKeys.profileDatabaseKey(profile.id)),
        isNotEmpty,
      );
      // The password itself is nowhere in the catalog row.
      expect(profile.passwordVerifier, isNot(contains(testPassword.codeUnits)));
    },
  );

  test('only the first profile is created as last active', () async {
    final first = await ctx.profiles.create(
      name: 'One',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    final second = await ctx.profiles.create(
      name: 'Two',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );

    expect(first.isLastActive, isTrue);
    expect(second.isLastActive, isFalse);
    expect(ctx.catalog.profiles.lastActive()!.id, first.id);
  });

  test('markLastActive keeps exactly one active profile', () async {
    await ctx.profiles.create(
      name: 'One',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    final second = await ctx.profiles.create(
      name: 'Two',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );

    ctx.profiles.markLastActive(second);
    expect(ctx.catalog.profiles.lastActive()!.id, second.id);
    expect(ctx.catalog.profiles.all().where((p) => p.isLastActive).length, 1);
  });

  test(
    'rejects invalid names, short passwords and mismatched confirmation',
    () async {
      for (final call in [
        () => ctx.profiles.create(
          name: '   ',
          password: testPassword,
          passwordConfirmation: testPassword,
          params: testArgon2Params,
        ),
        () => ctx.profiles.create(
          name: 'a' * 65,
          password: testPassword,
          passwordConfirmation: testPassword,
          params: testArgon2Params,
        ),
        () => ctx.profiles.create(
          name: 'X',
          password: 'short',
          passwordConfirmation: 'short',
          params: testArgon2Params,
        ),
        () => ctx.profiles.create(
          name: 'X',
          password: testPassword,
          passwordConfirmation: 'other password',
          params: testArgon2Params,
        ),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppErrorCode.validation,
            ),
          ),
        );
      }
      expect(ctx.catalog.profiles.count(), 0);
    },
  );

  test('profile names are unique case-insensitively', () async {
    await ctx.profiles.create(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    await expectLater(
      ctx.profiles.create(
        name: '  work ',
        password: testPassword,
        passwordConfirmation: testPassword,
        params: testArgon2Params,
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.conflict,
        ),
      ),
    );
  });

  test('deleting a profile removes its secrets and database files', () async {
    final profile = await ctx.profiles.create(
      name: 'Doomed',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    ctx.paths.ensureProfileDirectory(profile.id);
    ctx.paths.profileDatabase(profile.id);
    expect(ctx.paths.profileDirectoryExists(profile.id), isTrue);

    await ctx.profiles.delete(profile);

    expect(ctx.catalog.profiles.count(), 0);
    expect(
      await ctx.secrets.read(SecretKeys.profileDatabaseKey(profile.id)),
      isNull,
    );
    expect(ctx.paths.profileDirectoryExists(profile.id), isFalse);
  });
}
