import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/app/app.dart';
import 'package:ssh_client/app/app_services.dart';
import 'package:ssh_client/app/theme/theme_controller.dart';
import 'package:ssh_client/core/database/database_key_store.dart';
import 'package:ssh_client/core/security/password_hasher.dart';
import 'package:ssh_client/core/storage/app_paths.dart';
import 'package:ssh_client/core/storage/app_reset_service.dart';
import 'package:ssh_client/core/storage/secret_store.dart';
import 'package:ssh_client/features/profiles/presentation/first_run_screen.dart';

import '../support/app_harness.dart';
import '../support/in_memory_secret_store.dart';
import '../support/test_context.dart';

void main() {
  testWidgets(
    'reset from Settings rebuilds services and returns to first run',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final root = Directory.systemTemp.createTempSync('app_reset_flow_');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final secrets = InMemorySecretStore();
      Future<AppServices> build() => AppServices.fromStorage(
        secrets: secrets,
        paths: AppPaths(root.path),
        hasher: PasswordHasher(derive: testKeyDerivation),
      );

      final services = await build();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        try {
          services.dispose();
        } catch (_) {
          // Replaced after the reset.
        }
      });
      final theme = ThemeController.memory(mode: ThemeMode.dark);

      await tester.pumpWidget(
        SshClientApp(
          services: services,
          themeController: theme,
          rebuildServices: build,
        ),
      );
      await tester.pumpAndSettle();

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
      expect(find.byKey(const Key('new-connection-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.byKey(const Key('reset-app-button')),
        find.byType(ListView).last,
        const Offset(0, -250),
      );
      await tester.tap(find.byKey(const Key('reset-app-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reset-word-field')),
        'RESTABLECER',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('reset-confirm-word')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('confirm-password-field')),
        testPassword,
      );
      await tester.tap(find.byKey(const Key('confirm-password-submit')));
      await tester.pumpAndSettle();

      expect(find.byType(FirstRunScreen), findsOneWidget);
      // The rebuilt application created a fresh catalog, with no profiles.
      expect(await secrets.keysWithPrefix('profile/'), isEmpty);
    },
  );

  test('a corrupt catalog is deleted without opening it', () async {
    final root = Directory.systemTemp.createTempSync('reset_corrupt_');
    addTearDown(() async {
      for (var attempt = 0; attempt < 10; attempt++) {
        try {
          if (root.existsSync()) root.deleteSync(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
    });
    final paths = AppPaths(root.path)..ensureCreated();
    File(paths.catalogDatabase).writeAsStringSync('not a database');
    final secrets = InMemorySecretStore();
    await secrets.write(SecretKeys.catalogDatabaseKey, 'aa' * 32);
    final keys = DatabaseKeyStore(secrets: secrets);

    await AppResetService(paths: paths, keys: keys).reset();

    expect(File(paths.catalogDatabase).existsSync(), isFalse);
    expect(await secrets.read(SecretKeys.catalogDatabaseKey), isNull);
  });

  test('a pending reset marker is applied before any database opens', () async {
    final root = Directory.systemTemp.createTempSync('reset_pending_');
    addTearDown(() async {
      for (var attempt = 0; attempt < 10; attempt++) {
        try {
          if (root.existsSync()) root.deleteSync(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
    });
    final paths = AppPaths(root.path)..ensureCreated();
    File(paths.catalogDatabase).writeAsStringSync('locked');
    File(paths.resetMarker).writeAsStringSync('pending');
    final secrets = InMemorySecretStore();
    await secrets.write(SecretKeys.profileDatabaseKey('p1'), 'bb' * 32);
    final keys = DatabaseKeyStore(secrets: secrets);

    await AppResetService.applyPendingReset(paths: paths, keys: keys);

    expect(File(paths.catalogDatabase).existsSync(), isFalse);
    expect(File(paths.resetMarker).existsSync(), isFalse);
    expect(await secrets.keysWithPrefix('profile/'), isEmpty);
  });
}
