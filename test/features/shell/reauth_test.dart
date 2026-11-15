import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/shell_harness.dart';
import '../../support/test_context.dart';

void main() {
  testWidgets('the reauth switch persists in the profile settings', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reauth-switch')));
    await tester.pumpAndSettle();

    final settings = harness.services.catalog.profiles
        .byId(harness.controller.profile!.id)!
        .settings;
    expect(settings['requireReauthOnEdit'], isTrue);
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

    expect(find.byKey(const Key('reauth-password-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('reauth-password-field')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('reauth-confirm')));
    await tester.pumpAndSettle();

    expect(harness.controller.session!.connections.all(), isEmpty);
    expect(find.byKey(const Key('connection-form-error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('connection-save-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reauth-password-field')),
      testPassword,
    );
    await tester.tap(find.byKey(const Key('reauth-confirm')));
    await tester.pumpAndSettle();

    expect(harness.controller.session!.connections.all(), hasLength(1));
  });
}
