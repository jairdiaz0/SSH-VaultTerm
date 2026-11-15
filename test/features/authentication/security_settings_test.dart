import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/core/errors/app_exception.dart';
import 'package:ssh_client/features/authentication/data/security_settings_service.dart';

import '../../support/test_context.dart';

void main() {
  late TestContext ctx;
  late SecuritySettingsService service;

  setUp(() async {
    ctx = await TestContext.create();
    service = SecuritySettingsService(
      catalog: ctx.catalog,
      auth: ctx.auth,
      clock: () => ctx.clock.value,
    );
  });

  tearDown(() async {
    await ctx.dispose();
  });

  Future<String> createProfile() async {
    final profile = await ctx.profiles.create(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    return profile.id;
  }

  bool requireReauth(String id) =>
      ctx.catalog.profiles
          .byId(id)!
          .settings[SecuritySettingsService.requireReauthKey] ==
      true;

  test(
    'a wrong password leaves the setting untouched and counts the failure',
    () async {
      final id = await createProfile();

      await expectLater(
        service.setRequireReauthOnEdit(
          profileId: id,
          value: true,
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

      expect(requireReauth(id), isFalse);
      expect(ctx.catalog.profiles.byId(id)!.failedAttempts, 1);
    },
  );

  test('the correct password enables and disables the switch', () async {
    final id = await createProfile();

    await service.setRequireReauthOnEdit(
      profileId: id,
      value: true,
      password: testPassword,
    );
    expect(requireReauth(id), isTrue);

    await service.setRequireReauthOnEdit(
      profileId: id,
      value: false,
      password: testPassword,
    );
    expect(requireReauth(id), isFalse);
  });

  test('a locked profile rejects even the correct password', () async {
    final id = await createProfile();
    for (var attempt = 0; attempt < 3; attempt++) {
      await expectLater(
        service.setRequireReauthOnEdit(
          profileId: id,
          value: true,
          password: 'wrong-password',
        ),
        throwsA(isA<AppException>()),
      );
    }

    await expectLater(
      service.setRequireReauthOnEdit(
        profileId: id,
        value: true,
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
    expect(requireReauth(id), isFalse);
  });
}
