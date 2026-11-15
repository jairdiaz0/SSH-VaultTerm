import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/shared/models/connection.dart';
import 'package:ssh_client/shared/models/server_collection.dart';

import '../../support/shell_harness.dart';

/// The Windows runner enforces this minimum; the layout must fit with a dense
/// sidebar and must never overflow at any larger size either.
const _sizes = <Size>[Size(900, 600), Size(1280, 720), Size(1920, 1080)];

void main() {
  for (final size in _sizes) {
    testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      final harness = await pumpShell(
        tester,
        size: size,
        seed: (session) {
          final now = DateTime.utc(2026, 1, 1);
          final collection = ServerCollection(
            id: 'col-1',
            name: 'Servidores de producción con nombre largo',
            position: 0,
            createdAt: now,
            updatedAt: now,
          );
          session.collections.insert(collection);
          for (var index = 0; index < 8; index++) {
            session.connections.insert(
              Connection(
                id: 'conn-$index',
                collectionId: collection.id,
                name: 'Servidor con un nombre bastante largo $index',
                hostname: 'host-$index.example.com',
                port: 22,
                username: 'deploy-user',
                authType: AuthenticationType.password,
                connectionType: index.isEven
                    ? ConnectionType.ssh
                    : ConnectionType.sftp,
                credentialId: 'cred-$index',
                favorite: index == 0,
                position: index,
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        },
      );
      addTearDown(harness.dispose);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('new-collection-button')), findsOneWidget);

      // The sidebar must scroll instead of clipping when the list is long.
      await tester.drag(
        find.byKey(const Key('connection-tile-conn-7')),
        const Offset(0, -200),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The settings dialog must fit too.
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('settings-close')), findsOneWidget);
    });
  }
}
