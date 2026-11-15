import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/core/errors/app_exception.dart';
import 'package:ssh_client/features/authentication/domain/lockout_policy.dart';

import '../../support/test_context.dart';

void main() {
  group('LockoutPolicy', () {
    const policy = LockoutPolicy();

    test('no delay before the free attempt threshold', () {
      expect(policy.delayFor(0), Duration.zero);
      expect(policy.delayFor(2), Duration.zero);
    });

    test('delay grows exponentially and is capped', () {
      expect(policy.delayFor(3), const Duration(seconds: 2));
      expect(policy.delayFor(4), const Duration(seconds: 4));
      expect(policy.delayFor(5), const Duration(seconds: 8));
      expect(policy.delayFor(30), policy.maxDelay);
    });

    test('isLocked only while the deadline is in the future', () {
      final now = DateTime.utc(2026);
      expect(policy.isLocked(null, now), isFalse);
      expect(policy.isLocked(now.add(const Duration(seconds: 1)), now), isTrue);
      expect(
        policy.isLocked(now.subtract(const Duration(seconds: 1)), now),
        isFalse,
      );
    });
  });

  group('AuthenticationService', () {
    late TestContext ctx;

    setUp(() async {
      ctx = await TestContext.create();
    });

    tearDown(() async {
      await ctx.dispose();
    });

    Future<String> createProfile() async {
      final profile = await ctx.profiles.create(
        name: 'Personal',
        password: testPassword,
        passwordConfirmation: testPassword,
        params: testArgon2Params,
      );
      return profile.id;
    }

    test(
      'unlocks with the right password and marks the profile active',
      () async {
        final id = await createProfile();

        final unlocked = await ctx.auth.unlock(
          profileId: id,
          password: testPassword,
        );

        expect(unlocked.id, id);
        expect(ctx.catalog.profiles.lastActive()!.id, id);
        expect(ctx.catalog.profiles.byId(id)!.failedAttempts, 0);
      },
    );

    test('a wrong password fails generically and is persisted', () async {
      final id = await createProfile();

      await expectLater(
        ctx.auth.unlock(profileId: id, password: 'wrong password'),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.invalidCredentials,
          ),
        ),
      );

      final stored = ctx.catalog.profiles.byId(id)!;
      expect(stored.failedAttempts, 1);
      expect(stored.lockoutUntil, isNull);
    });

    test(
      'lockout applies after three failures and survives a reload',
      () async {
        final id = await createProfile();

        for (var i = 0; i < 3; i++) {
          await expectLater(
            ctx.auth.unlock(profileId: id, password: 'nope$i'),
            throwsA(isA<AppException>()),
          );
        }

        final locked = ctx.catalog.profiles.byId(id)!;
        expect(locked.failedAttempts, 3);
        expect(locked.lockoutUntil, isNotNull);

        // Even the correct password is refused while locked.
        await expectLater(
          ctx.auth.unlock(profileId: id, password: testPassword),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppErrorCode.accountLocked,
            ),
          ),
        );

        // Lockout is persisted in the catalog, not in memory only.
        final reopened = ctx.catalog.profiles.byId(id)!;
        expect(reopened.lockoutUntil, locked.lockoutUntil);
      },
    );

    test('after the delay expires the user can unlock again', () async {
      final id = await createProfile();
      for (var i = 0; i < 3; i++) {
        await expectLater(
          ctx.auth.unlock(profileId: id, password: 'nope$i'),
          throwsA(isA<AppException>()),
        );
      }

      ctx.clock.advance(const Duration(seconds: 5));
      final unlocked = await ctx.auth.unlock(
        profileId: id,
        password: testPassword,
      );

      expect(unlocked.id, id);
      final stored = ctx.catalog.profiles.byId(id)!;
      expect(stored.failedAttempts, 0);
      expect(stored.lockoutUntil, isNull);
    });

    test('lockout delays grow with repeated failure cycles', () async {
      final id = await createProfile();

      for (var i = 0; i < 4; i++) {
        await expectLater(
          ctx.auth.unlock(profileId: id, password: 'nope$i'),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppErrorCode.invalidCredentials,
            ),
          ),
        );
        // Wait out the lockout so the next attempt counts as a new failure.
        if (i < 3) ctx.clock.advance(const Duration(seconds: 30));
      }

      final stored = ctx.catalog.profiles.byId(id)!;
      final remaining = stored.lockoutUntil!.difference(ctx.clock.value);
      expect(remaining, const Duration(seconds: 4));
    });

    test('sensitive actions verify the password and count failures', () async {
      final id = await createProfile();

      await ctx.auth.verifyForSensitiveAction(
        profileId: id,
        password: testPassword,
      );
      expect(ctx.catalog.profiles.byId(id)!.failedAttempts, 0);

      await expectLater(
        ctx.auth.verifyForSensitiveAction(profileId: id, password: 'bad'),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.invalidCredentials,
          ),
        ),
      );
      expect(ctx.catalog.profiles.byId(id)!.failedAttempts, 1);

      // Three failures in a row trigger the same progressive lockout as unlock.
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          ctx.auth.verifyForSensitiveAction(profileId: id, password: 'bad'),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppErrorCode.invalidCredentials,
            ),
          ),
        );
      }
      await expectLater(
        ctx.auth.verifyForSensitiveAction(
          profileId: id,
          password: testPassword,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.accountLocked,
          ),
        ),
      );
    });

    test('unknown profile ids are not found, not unlocked', () async {
      await expectLater(
        ctx.auth.unlock(profileId: 'missing', password: testPassword),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.notFound,
          ),
        ),
      );
    });
  });
}
