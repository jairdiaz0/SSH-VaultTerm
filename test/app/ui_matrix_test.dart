import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_client/app/localizations.dart';
import 'package:ssh_client/app/session_gate.dart';
import 'package:ssh_client/app/theme/app_theme.dart';
import 'package:ssh_client/features/connections/presentation/connection_form_dialog.dart';
import 'package:ssh_client/features/sftp/presentation/sftp_controller.dart';
import 'package:ssh_client/features/sftp/presentation/sftp_panel.dart';
import 'package:ssh_client/features/shell/presentation/home_shell.dart';
import 'package:ssh_client/features/shell/presentation/shell_controller.dart';
import 'package:ssh_client/features/ssh/domain/host_key_verifier.dart';
import 'package:ssh_client/features/workspace/presentation/host_key_dialog.dart';
import 'package:ssh_client/shared/models/connection.dart';
import 'package:ssh_client/shared/models/server_collection.dart';

import '../support/app_harness.dart';
import '../support/fake_sftp_gateway.dart';
import '../support/shell_harness.dart';

const _sizes = <Size>[Size(900, 600), Size(1280, 720), Size(1920, 1080)];

const _themes = <ThemeMode>[ThemeMode.light, ThemeMode.dark];

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void seedDenseSidebar(AppHarness harness) {
  final session = harness.controller.session!;
  final now = DateTime.utc(2026, 1, 1);
  final collection = ServerCollection(
    id: 'col-1',
    name: 'Producción europea con nombre largo',
    position: 0,
    createdAt: now,
    updatedAt: now,
  );
  session.collections.insert(collection);
  for (var index = 0; index < 5; index++) {
    session.connections.insert(
      Connection(
        id: 'conn-$index',
        collectionId: collection.id,
        name: 'Servidor $index de producción',
        hostname: 'host-$index.example.com',
        port: 22,
        username: 'deploy',
        authType: AuthenticationType.password,
        connectionType: index.isEven ? ConnectionType.ssh : ConnectionType.sftp,
        credentialId: 'cred-$index',
        favorite: index == 0,
        position: index,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

void main() {
  for (final mode in _themes) {
    for (final size in _sizes) {
      final label = '${mode.name} ${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('first run fits at $label with 1.3 text', (tester) async {
        setView(tester, size);
        final harness = await AppHarness.create(mode: mode);
        addTearDown(harness.dispose);
        await tester.pumpWidget(
          harness.wrap(
            SessionGate(controller: harness.controller),
            textScale: 1.3,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Crea tu primer perfil'), findsOneWidget);
      });

      testWidgets('lock screen fits at $label with 1.3 text', (tester) async {
        setView(tester, size);
        final harness = await pumpShell(tester, size: size, mode: mode);
        addTearDown(harness.dispose);
        await harness.controller.lock();
        await tester.pumpWidget(
          harness.wrap(
            SessionGate(controller: harness.controller),
            textScale: 1.3,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Desbloquear perfil'), findsOneWidget);
      });

      testWidgets('shell and settings fit at $label with 1.3 text', (
        tester,
      ) async {
        setView(tester, size);
        final harness = await pumpShell(tester, size: size, mode: mode);
        addTearDown(harness.dispose);
        seedDenseSidebar(harness);
        await tester.pumpWidget(
          harness.wrap(
            HomeShell(controller: harness.controller),
            textScale: 1.3,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('open-settings')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('theme-selector')), findsOneWidget);
      });

      testWidgets('connection form fits at $label with 1.3 text', (
        tester,
      ) async {
        setView(tester, size);
        final harness = await pumpShell(tester, size: size, mode: mode);
        addTearDown(harness.dispose);
        await tester.pumpWidget(
          harness.wrap(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => ConnectionFormDialog.show(
                      context,
                      controller: ShellController(
                        services: harness.services,
                        session: harness.controller.session!,
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            textScale: 1.3,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('connection-name-field')), findsOneWidget);
      });

      testWidgets('host key dialog fits at $label with 1.3 text', (
        tester,
      ) async {
        setView(tester, size);
        final harness = await AppHarness.create(mode: mode);
        addTearDown(harness.dispose);
        await tester.pumpWidget(
          harness.wrap(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showHostKeyConfirmation(
                      context,
                      HostKeyChallenge(
                        hostname: 'server.example.com',
                        port: 22,
                        keyType: 'ssh-ed25519',
                        fingerprint:
                            'SHA256:abcdefghijklmnopqrstuvwxyz0123456789ABCD',
                        status: HostKeyStatus.untrusted,
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            textScale: 1.3,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('host-key-accept')), findsOneWidget);
      });
    }

    testWidgets('SFTP panel fits at ${mode.name} with 1.3 text', (
      tester,
    ) async {
      setView(tester, const Size(900, 600));
      final gateway = FakeSftpGateway(
        tree: {
          '/home/test': [
            FakeSftpGateway.dir('/home/test', 'docs'),
            FakeSftpGateway.file('/home/test', 'notes.txt', size: 2048),
          ],
        },
      );
      final controller = SftpController(gateway: gateway);
      addTearDown(controller.dispose);
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: mode == ThemeMode.light ? AppTheme.light() : AppTheme.dark(),
          locale: const Locale('es'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: const [Locale('es')],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(body: SftpPanel(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('sftp-entry-docs')), findsOneWidget);
    });
  }
}
