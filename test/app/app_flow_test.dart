import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/app/session_gate.dart';
import 'package:ssh_client/features/authentication/presentation/lock_screen.dart';
import 'package:ssh_client/features/profiles/presentation/first_run_screen.dart';
import 'package:ssh_client/features/shell/presentation/home_shell.dart';
import 'package:ssh_client/shared/models/connection.dart';
import 'package:ssh_client/shared/models/server_collection.dart';

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

  Future<void> pumpGate(WidgetTester tester) async {
    // Desktop-sized surface: SessionGate mounts the desktop shell.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness.wrap(SessionGate(controller: harness.controller)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> createFirstProfile(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('first-run-name-field')),
      'Work',
    );
    await tester.enterText(
      find.byKey(const Key('first-run-password-field')),
      testPassword,
    );
    await tester.enterText(
      find.byKey(const Key('first-run-confirmation-field')),
      testPassword,
    );
    await tester.tap(find.byKey(const Key('first-run-submit-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('empty catalog shows the first-run wizard only', (tester) async {
    await pumpGate(tester);

    expect(find.byType(FirstRunScreen), findsOneWidget);
    expect(find.byType(LockScreen), findsNothing);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('first-run validation rejects short and mismatched passwords', (
    tester,
  ) async {
    await pumpGate(tester);

    await tester.enterText(
      find.byKey(const Key('first-run-name-field')),
      'Work',
    );
    await tester.enterText(
      find.byKey(const Key('first-run-password-field')),
      'short',
    );
    await tester.enterText(
      find.byKey(const Key('first-run-confirmation-field')),
      'short',
    );
    await tester.tap(find.byKey(const Key('first-run-submit-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('al menos'), findsOneWidget);
    expect(harness.controller.hasProfiles, isFalse);

    await tester.enterText(
      find.byKey(const Key('first-run-password-field')),
      testPassword,
    );
    await tester.enterText(
      find.byKey(const Key('first-run-confirmation-field')),
      '$testPassword!',
    );
    await tester.tap(find.byKey(const Key('first-run-submit-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('no coinciden'), findsOneWidget);
    expect(harness.controller.hasProfiles, isFalse);
  });

  testWidgets('creating the first profile unlocks the app', (tester) async {
    await pumpGate(tester);
    await createFirstProfile(tester);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Work'), findsWidgets);
    expect(harness.controller.isUnlocked, isTrue);
  });

  testWidgets('restart shows the lock screen with no way to create profiles', (
    tester,
  ) async {
    await pumpGate(tester);
    await createFirstProfile(tester);

    final restarted = harness.restartedController();
    await tester.pumpWidget(harness.wrap(SessionGate(controller: restarted)));
    await tester.pumpAndSettle();

    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.byType(FirstRunScreen), findsNothing);
    expect(find.byKey(const Key('first-run-name-field')), findsNothing);
    expect(find.text('Crear perfil'), findsNothing);

    restarted.dispose();
  });

  testWidgets('wrong password keeps the app locked with a generic message', (
    tester,
  ) async {
    await pumpGate(tester);
    await createFirstProfile(tester);

    final restarted = harness.restartedController();
    await tester.pumpWidget(harness.wrap(SessionGate(controller: restarted)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('lock-password-field')),
      'not the password',
    );
    await tester.tap(find.byKey(const Key('lock-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Contraseña incorrecta.'), findsOneWidget);
    expect(restarted.isUnlocked, isFalse);

    await tester.enterText(
      find.byKey(const Key('lock-password-field')),
      testPassword,
    );
    await tester.tap(find.byKey(const Key('lock-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(restarted.isUnlocked, isTrue);

    restarted.dispose();
  });

  testWidgets('locking from the shell closes the session and returns to lock', (
    tester,
  ) async {
    await pumpGate(tester);
    await createFirstProfile(tester);

    final session = harness.controller.session;
    expect(session, isNotNull);

    await tester.tap(find.byKey(const Key('lock-session-button')));
    await tester.pumpAndSettle();

    expect(find.byType(LockScreen), findsOneWidget);
    expect(harness.controller.isUnlocked, isFalse);
    expect(session!.isClosed, isTrue);
  });

  testWidgets(
    'shell lists the real collections and connections of the profile',
    (tester) async {
      await pumpGate(tester);
      await createFirstProfile(tester);

      final session = harness.controller.session!;
      final now = DateTime.utc(2026, 1, 2);
      final collection = ServerCollection(
        id: 'c1',
        name: 'Servers',
        description: null,
        icon: null,
        color: null,
        position: 0,
        createdAt: now,
        updatedAt: now,
      );
      session.collections.insert(collection);
      session.connections.insert(
        Connection(
          id: 's1',
          collectionId: collection.id,
          name: 'web-01',
          hostname: '10.0.0.10',
          port: 22,
          username: 'deploy',
          authType: AuthenticationType.password,
          credentialId: null,
          description: null,
          favorite: true,
          position: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.tap(find.byKey(const Key('lock-session-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('lock-password-field')),
        testPassword,
      );
      await tester.tap(find.byKey(const Key('lock-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('Servers'), findsOneWidget);
      // Favourites appear twice by design: in Favourites and in its collection.
      expect(find.text('web-01'), findsNWidgets(2));
      expect(find.text('deploy@10.0.0.10:22'), findsNWidgets(2));
      expect(find.text('FAVORITOS'), findsOneWidget);
      expect(find.text('COLECCIONES'), findsOneWidget);
    },
  );
}
