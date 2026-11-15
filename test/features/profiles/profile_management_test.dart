import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/app/session_gate.dart';
import 'package:ssh_client/features/authentication/presentation/lock_screen.dart';
import 'package:ssh_client/features/profiles/presentation/profile_management_dialog.dart';

import '../../support/shell_harness.dart';
import '../../support/test_context.dart';

Future<void> openProfiles(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('manage-profiles')));
  await tester.pumpAndSettle();
}

Future<void> fillNewProfile(
  WidgetTester tester, {
  required String name,
  required String password,
}) async {
  await tester.enterText(find.byKey(const Key('new-profile-name')), name);
  await tester.enterText(
    find.byKey(const Key('new-profile-password')),
    password,
  );
  await tester.enterText(
    find.byKey(const Key('new-profile-confirmation')),
    password,
  );
  await tester.tap(find.byKey(const Key('new-profile-save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('creates a profile from Settings and switches into it', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await openProfiles(tester);
    expect(find.byType(ProfileManagementDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-profile-button')));
    await tester.pumpAndSettle();
    await fillNewProfile(tester, name: 'Home', password: testPassword);

    expect(harness.controller.profile!.name, 'Home');
    expect(harness.controller.profiles.map((p) => p.name), contains('Work'));
  });

  testWidgets('switches to another profile only with its password', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await openProfiles(tester);
    await tester.tap(find.byKey(const Key('create-profile-button')));
    await tester.pumpAndSettle();
    await fillNewProfile(tester, name: 'Home', password: testPassword);

    final work = harness.controller.profiles.firstWhere(
      (profile) => profile.name == 'Work',
    );
    await openProfiles(tester);
    await tester.tap(find.byKey(Key('switch-profile-${work.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-password-field')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('profile-password-confirm')));
    await tester.pumpAndSettle();
    expect(harness.controller.profile!.name, 'Home');
    expect(find.byKey(const Key('profile-management-error')), findsOneWidget);

    await tester.tap(find.byKey(Key('switch-profile-${work.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-password-field')),
      testPassword,
    );
    await tester.tap(find.byKey(const Key('profile-password-confirm')));
    await tester.pumpAndSettle();

    expect(harness.controller.profile!.name, 'Work');
  });

  testWidgets('deleting a profile requires the correct password', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await openProfiles(tester);
    await tester.tap(find.byKey(const Key('create-profile-button')));
    await tester.pumpAndSettle();
    await fillNewProfile(tester, name: 'Home', password: testPassword);

    final work = harness.controller.profiles.firstWhere(
      (profile) => profile.name == 'Work',
    );
    await openProfiles(tester);
    await tester.tap(find.byKey(Key('delete-profile-${work.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-password-field')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('profile-password-confirm')));
    await tester.pumpAndSettle();

    expect(harness.controller.profiles.map((p) => p.name), contains('Work'));

    await tester.tap(find.byKey(Key('delete-profile-${work.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-password-field')),
      testPassword,
    );
    await tester.tap(find.byKey(const Key('profile-password-confirm')));
    await tester.pumpAndSettle();

    expect(
      harness.controller.profiles.map((p) => p.name),
      isNot(contains('Work')),
    );
  });

  testWidgets('the locked screen offers switching but never creation', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);
    await harness.controller.createProfile(
      name: 'Home',
      password: testPassword,
      passwordConfirmation: testPassword,
    );
    await harness.controller.lock();

    final restarted = harness.restartedController();
    addTearDown(restarted.dispose);
    await tester.pumpWidget(harness.wrap(SessionGate(controller: restarted)));
    await tester.pumpAndSettle();

    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('Cambiar de perfil'), findsOneWidget);
    expect(find.text('Crear perfil'), findsNothing);
  });
}
