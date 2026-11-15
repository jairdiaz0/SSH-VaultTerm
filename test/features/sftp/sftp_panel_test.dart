import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/app/theme/app_theme.dart';
import 'package:ssh_client/features/sftp/domain/transfer.dart';
import 'package:ssh_client/features/sftp/presentation/sftp_controller.dart';
import 'package:ssh_client/features/sftp/presentation/sftp_panel.dart';
import 'package:ssh_client/l10n/generated/app_localizations.dart';

import '../../support/fake_sftp_gateway.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  locale: const Locale('es'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 900, height: 700, child: child)),
);

FakeSftpGateway populatedGateway() => FakeSftpGateway(
  tree: {
    '/home/test': [
      FakeSftpGateway.dir('/home/test', 'docs'),
      FakeSftpGateway.file('/home/test', 'notes.txt', size: 2048),
      FakeSftpGateway.file('/home/test', '.hidden', size: 10),
    ],
    '/home/test/docs': [
      FakeSftpGateway.file('/home/test/docs', 'readme.md', size: 512),
    ],
  },
);

Future<SftpController> pumpPanel(
  WidgetTester tester,
  FakeSftpGateway gateway,
) async {
  final controller = SftpController(gateway: gateway);
  addTearDown(controller.dispose);
  await controller.initialize();
  await tester.pumpWidget(host(SftpPanel(controller: controller)));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('lists the remote directory and hides dot files by default', (
    tester,
  ) async {
    final controller = await pumpPanel(tester, populatedGateway());

    expect(controller.path, '/home/test');
    expect(find.byKey(const Key('sftp-entry-docs')), findsOneWidget);
    expect(find.byKey(const Key('sftp-entry-notes.txt')), findsOneWidget);
    expect(find.byKey(const Key('sftp-entry-.hidden')), findsNothing);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text('rw-r--r--'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sftp-hidden-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sftp-entry-.hidden')), findsOneWidget);
  });

  testWidgets('navigates into a folder, back and up with breadcrumbs', (
    tester,
  ) async {
    final controller = await pumpPanel(tester, populatedGateway());

    await tester.tap(find.byKey(const Key('sftp-entry-docs')));
    await tester.pumpAndSettle();
    expect(controller.path, '/home/test/docs');
    expect(find.byKey(const Key('sftp-entry-readme.md')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sftp-back')));
    await tester.pumpAndSettle();
    expect(controller.path, '/home/test');

    await tester.tap(find.byKey(const Key('sftp-forward')));
    await tester.pumpAndSettle();
    expect(controller.path, '/home/test/docs');

    await tester.tap(find.byKey(const Key('sftp-up')));
    await tester.pumpAndSettle();
    expect(controller.path, '/home/test');

    await tester.tap(find.byKey(const Key('crumb-root')));
    await tester.pumpAndSettle();
    expect(controller.path, '/');
  });

  testWidgets('creates a folder from the toolbar', (tester) async {
    final gateway = populatedGateway();
    final controller = await pumpPanel(tester, gateway);

    await tester.tap(find.byKey(const Key('sftp-new-folder')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sftp-text-field')), 'nueva');
    await tester.tap(find.byKey(const Key('sftp-text-save')));
    await tester.pumpAndSettle();

    expect(controller.path, '/home/test');
    expect(find.byKey(const Key('sftp-entry-nueva')), findsOneWidget);
  });

  testWidgets('renames and deletes an entry through its menu', (tester) async {
    final gateway = populatedGateway();
    final controller = await pumpPanel(tester, gateway);

    await tester.tap(find.byKey(const Key('sftp-entry-menu-notes.txt')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renombrar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('sftp-text-field')),
      'renamed.txt',
    );
    await tester.tap(find.byKey(const Key('sftp-text-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sftp-entry-renamed.txt')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sftp-entry-menu-renamed.txt')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(
      controller.entries.map((entry) => entry.name),
      isNot(contains('renamed.txt')),
    );
  });

  testWidgets('shows the mapped error and retries', (tester) async {
    final gateway = populatedGateway()..failList = true;
    final controller = await pumpPanel(tester, gateway);

    expect(find.byKey(const Key('sftp-error')), findsOneWidget);
    expect(find.textContaining('no existe'), findsOneWidget);

    gateway.failList = false;
    await tester.tap(find.byKey(const Key('sftp-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sftp-entry-docs')), findsOneWidget);
    expect(controller.errorCode, isNull);
  });

  testWidgets('an upload queues, completes and refreshes the listing', (
    tester,
  ) async {
    final gateway = populatedGateway();
    final controller = await pumpPanel(tester, gateway);
    final root = Directory.systemTemp.createTempSync('sftp_panel_test_');
    addTearDown(() => root.deleteSync(recursive: true));
    final local = File('${root.path}/payload.txt')..writeAsStringSync('hola');

    await tester.runAsync(() => controller.uploadFiles([local.path]));
    await tester.pumpAndSettle();

    expect(gateway.uploaded, ['/home/test/payload.txt']);
    expect(find.byKey(const Key('sftp-entry-payload.txt')), findsOneWidget);
    final task = controller.queue.tasks.single;
    expect(task.status, TransferStatus.completed);
    expect(find.byKey(Key('transfer-status-${task.id}')), findsOneWidget);
    expect(find.text('Finalizada'), findsOneWidget);
  });
}
