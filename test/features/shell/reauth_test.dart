import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/shell_harness.dart';
import '../../support/test_context.dart';

Future<void> confirmPassword(WidgetTester tester, String password) async {
  await tester.enterText(
    find.byKey(const Key('confirm-password-field')),
    password,
  );
  await tester.tap(find.byKey(const Key('confirm-password-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the reauth switch asks for the password and persists', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    // A wrong password keeps the previous value and stores nothing.
    await tester.tap(find.byKey(const Key('reauth-switch')));
    await tester.pumpAndSettle();
    await confirmPassword(tester, 'wrong-password');
    expect(find.byKey(const Key('confirm-password-error')), findsOneWidget);

    final before = harness.services.catalog.profiles
        .byId(harness.controller.profile!.id)!
        .settings['requireReauthOnEdit'];
    expect(before, isFalse);

    await tester.tap(find.byKey(const Key('confirm-password-cancel')));
    await tester.pumpAndSettle();
    expect(
      harness.services.catalog.profiles
          .byId(harness.controller.profile!.id)!
          .settings['requireReauthOnEdit'],
      isFalse,
    );

    // The correct password enables it.
    await tester.tap(find.byKey(const Key('reauth-switch')));
    await tester.pumpAndSettle();
    await confirmPassword(tester, testPassword);
    expect(
      harness.services.catalog.profiles
          .byId(harness.controller.profile!.id)!
          .settings['requireReauthOnEdit'],
      isTrue,
    );

    // Disabling also asks for the password.
    await tester.tap(find.byKey(const Key('reauth-switch')));
    await tester.pumpAndSettle();
    await confirmPassword(tester, testPassword);
    expect(
      harness.services.catalog.profiles
          .byId(harness.controller.profile!.id)!
          .settings['requireReauthOnEdit'],
      isFalse,
    );
  });

  testWidgets('saving a connection asks for the password when required', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reauth-switch')));
    await tester.pumpAndSettle();
    await confirmPassword(tester, testPassword);
    await tester.tap(find.byKey(const Key('settings-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-connection-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('connection-name-field')),
      'web',
    );
    await tester.enterText(
      find.byKey(const Key('connection-host-field')),
      '10.0.0.1',
    );
    await tester.enterText(
      find.byKey(const Key('connection-user-field')),
      'deploy',
    );
    await tester.enterText(
      find.byKey(const Key('connection-password-field')),
      'ssh-secret',
    );
    await tester.tap(find.byKey(const Key('connection-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirm-password-field')), findsOneWidget);
    await confirmPassword(tester, 'wrong-password');
    expect(find.byKey(const Key('confirm-password-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-password-cancel')));
    await tester.pumpAndSettle();
    expect(harness.controller.session!.connections.all(), isEmpty);

    await tester.tap(find.byKey(const Key('connection-save-button')));
    await tester.pumpAndSettle();
    await confirmPassword(tester, testPassword);

    expect(harness.controller.session!.connections.all(), hasLength(1));
  });
}
