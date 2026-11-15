import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/shared/models/connection.dart';

import '../../support/shell_harness.dart';

void main() {
  testWidgets('creates a collection from the sidebar', (tester) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await createCollection(tester, 'Producción');

    expect(find.text('Producción'), findsOneWidget);
    final collections = harness.controller.session!.collections.all();
    expect(collections.single.name, 'Producción');
    expect(find.text('COLECCIONES'), findsOneWidget);
  });

  testWidgets('creates a password connection and stores its secret apart', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await createPasswordConnection(tester);

    expect(find.text('web-01'), findsOneWidget);
    expect(find.text('deploy@10.0.0.10:22'), findsOneWidget);

    final session = harness.controller.session!;
    final connection = session.connections.all().single;
    expect(connection.credentialId, isNotNull);
    expect(connection.favorite, isFalse);

    final secret = await harness.services.credentials.load(
      profileId: session.profile.id,
      credentialId: connection.credentialId!,
    );
    expect(secret?.password, 'secret-password');
  });

  testWidgets('rejects a connection without a host', (tester) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const Key('new-connection-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('connection-name-field')), 'x');
    await tester.tap(find.byKey(const Key('connection-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('connection-form-error')), findsOneWidget);
    expect(harness.controller.session!.connections.all(), isEmpty);
  });

  testWidgets('edits a connection and keeps the stored password', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);
    await createPasswordConnection(tester);

    final session = harness.controller.session!;
    final original = session.connections.all().single;

    await tester.tap(find.byKey(Key('connection-menu-${original.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('connection-name-field')),
      'web-02',
    );
    await tester.tap(find.byKey(const Key('connection-save-button')));
    await tester.pumpAndSettle();

    final updated = session.connections.all().single;
    expect(updated.name, 'web-02');
    expect(updated.credentialId, original.credentialId);

    final secret = await harness.services.credentials.load(
      profileId: session.profile.id,
      credentialId: updated.credentialId!,
    );
    expect(secret?.password, 'secret-password');
  });

  testWidgets('toggles favourite and lists it under favourites', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);
    await createPasswordConnection(tester);

    final connection = harness.controller.session!.connections.all().single;
    await tester.tap(find.byKey(Key('connection-menu-${connection.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir a favoritos'));
    await tester.pumpAndSettle();

    expect(find.text('FAVORITOS'), findsOneWidget);
    expect(find.text('web-01'), findsNWidgets(2));
    expect(
      harness.controller.session!.connections.byId(connection.id)!.favorite,
      isTrue,
    );
  });

  testWidgets('deletes a connection and its credential', (tester) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);
    await createPasswordConnection(tester);

    final session = harness.controller.session!;
    final connection = session.connections.all().single;
    await tester.tap(find.byKey(Key('connection-menu-${connection.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(session.connections.all(), isEmpty);
    final secret = await harness.services.credentials.load(
      profileId: session.profile.id,
      credentialId: connection.credentialId!,
    );
    expect(secret, isNull);
  });

  testWidgets('deleting a collection keeps its connections unassigned', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);
    await createCollection(tester, 'Producción');
    await createPasswordConnection(tester, collection: 'Producción');

    final session = harness.controller.session!;
    final collection = session.collections.all().single;
    expect(session.connections.all().single.collectionId, collection.id);

    await tester.tap(find.byKey(Key('collection-menu-${collection.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(session.collections.all(), isEmpty);
    expect(session.connections.all().single.collectionId, isNull);
    expect(find.text('web-01'), findsOneWidget);
  });

  testWidgets('creates an SFTP connection with the type chips', (tester) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const Key('new-connection-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('connection-name-field')),
      'files',
    );
    await tester.enterText(
      find.byKey(const Key('connection-host-field')),
      '10.0.0.11',
    );
    await tester.enterText(
      find.byKey(const Key('connection-user-field')),
      'deploy',
    );
    await tester.enterText(
      find.byKey(const Key('connection-password-field')),
      'secret-password',
    );
    await tester.tap(find.byKey(const Key('type-sftp-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('connection-save-button')));
    await tester.pumpAndSettle();

    final connection = harness.controller.session!.connections.all().single;
    expect(connection.connectionType, ConnectionType.sftp);
    expect(connection.authType, AuthenticationType.password);
  });

  testWidgets('reorders collections from the menu', (tester) async {
    final harness = await pumpShell(tester);
    addTearDown(harness.dispose);
    await createCollection(tester, 'Primera');
    await createCollection(tester, 'Segunda');

    final session = harness.controller.session!;
    final second = session.collections.all().last;

    await tester.tap(find.byKey(Key('collection-menu-${second.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subir'));
    await tester.pumpAndSettle();

    expect(session.collections.all().first.name, 'Segunda');
  });
}
