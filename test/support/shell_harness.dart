import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/app/profile_session.dart';
import 'package:ssh_client/features/shell/presentation/home_shell.dart';

import 'app_harness.dart';
import 'test_context.dart';

/// Mounts the unlocked desktop shell with a real (in-memory) profile database.
Future<AppHarness> pumpShell(
  WidgetTester tester, {
  Size size = const Size(1400, 1000),
  void Function(ProfileSession session)? seed,
}) async {
  // Desktop-sized surface: the real target for this shell.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final harness = await AppHarness.create();
  await harness.controller.createFirstProfile(
    name: 'Work',
    password: testPassword,
    passwordConfirmation: testPassword,
  );
  seed?.call(harness.controller.session!);
  await tester.pumpWidget(
    harness.wrap(HomeShell(controller: harness.controller)),
  );
  await tester.pumpAndSettle();
  return harness;
}

Future<void> createCollection(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('new-collection-button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('collection-name-field')), name);
  await tester.tap(find.byKey(const Key('collection-save-button')));
  await tester.pumpAndSettle();
}

Future<void> createPasswordConnection(
  WidgetTester tester, {
  String name = 'web-01',
  String host = '10.0.0.10',
  String user = 'deploy',
  String password = 'secret-password',
  String? collection,
}) async {
  await tester.tap(find.byKey(const Key('new-connection-button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('connection-name-field')), name);
  await tester.enterText(find.byKey(const Key('connection-host-field')), host);
  await tester.enterText(find.byKey(const Key('connection-user-field')), user);
  await tester.enterText(
    find.byKey(const Key('connection-password-field')),
    password,
  );
  if (collection != null) {
    final dropdown = find.byKey(const Key('connection-collection-field'));
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(collection).last);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('connection-save-button')));
  await tester.pumpAndSettle();
}
