import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/core/errors/app_exception.dart';

import '../support/app_harness.dart';
import '../support/test_context.dart';

void main() {
  late AppHarness harness;

  setUp(() async {
    harness = await AppHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  Matcher throwsCode(AppErrorCode code) =>
      throwsA(isA<AppException>().having((e) => e.code, 'code', code));

  test(
    'createProfile requires an unlocked session once profiles exist',
    () async {
      await harness.controller.createFirstProfile(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
      );

      final locked = harness.restartedController();
      addTearDown(locked.dispose);
      expect(locked.isUnlocked, isFalse);

      await expectLater(
        locked.createProfile(
          name: 'Other',
          password: testPassword,
          passwordConfirmation: testPassword,
        ),
        throwsCode(AppErrorCode.validation),
      );
    },
  );

  test(
    'createFirstProfile is rejected when a profile already exists',
    () async {
      await harness.controller.createFirstProfile(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
      );

      await expectLater(
        harness.controller.createFirstProfile(
          name: 'Second',
          password: testPassword,
          passwordConfirmation: testPassword,
        ),
        throwsCode(AppErrorCode.conflict),
      );
    },
  );

  test(
    'creating a profile from an unlocked session switches the session',
    () async {
      await harness.controller.createFirstProfile(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
      );
      final firstSession = harness.controller.session!;

      final second = await harness.controller.createProfile(
        name: 'Personal',
        password: 'another password',
        passwordConfirmation: 'another password',
      );

      expect(harness.controller.profile?.id, second.id);
      expect(firstSession.isClosed, isTrue);
      expect(harness.controller.session!.isClosed, isFalse);
    },
  );

  test('lock closes the profile database and keeps the catalog', () async {
    await harness.controller.createFirstProfile(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
    );
    final session = harness.controller.session!;

    await harness.controller.lock();

    expect(harness.controller.isUnlocked, isFalse);
    expect(session.isClosed, isTrue);
    expect(harness.controller.hasProfiles, isTrue);
  });

  test('unlock with the wrong password keeps the app locked', () async {
    await harness.controller.createFirstProfile(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
    );
    final profileId = harness.controller.profile!.id;
    await harness.controller.lock();

    await expectLater(
      harness.controller.unlock(profileId: profileId, password: 'nope'),
      throwsCode(AppErrorCode.invalidCredentials),
    );
    expect(harness.controller.isUnlocked, isFalse);
  });

  test(
    'deleting the open profile locks first and removes its secrets',
    () async {
      final created = await harness.controller.createFirstProfile(
        name: 'Work',
        password: testPassword,
        passwordConfirmation: testPassword,
      );
      final secretsBefore = await harness.services.secrets.keysWithPrefix(
        'profile/${created.id}/',
      );
      expect(secretsBefore, isNotEmpty);

      await harness.controller.deleteProfile(created);

      expect(harness.controller.isUnlocked, isFalse);
      expect(harness.controller.hasProfiles, isFalse);
      expect(
        await harness.services.secrets.keysWithPrefix('profile/${created.id}/'),
        isEmpty,
      );
    },
  );

  test('last active profile is remembered across controllers', () async {
    await harness.controller.createFirstProfile(
      name: 'Work',
      password: testPassword,
      passwordConfirmation: testPassword,
    );

    final restarted = harness.restartedController();
    addTearDown(restarted.dispose);

    expect(restarted.lastActiveProfile?.name, 'Work');
    expect(restarted.profiles, hasLength(1));
  });
}
