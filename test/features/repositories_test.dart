import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ssh_client/core/database/encrypted_database.dart';
import 'package:ssh_client/core/database/schemas.dart';
import 'package:ssh_client/core/errors/app_exception.dart';
import 'package:ssh_client/features/collections/data/collection_repository.dart';
import 'package:ssh_client/features/connections/data/connection_repository.dart';
import 'package:ssh_client/features/ssh/data/known_host_repository.dart';
import 'package:ssh_client/shared/models/connection.dart';
import 'package:ssh_client/shared/models/known_host.dart';
import 'package:ssh_client/shared/models/server_collection.dart';

void main() {
  late Database db;
  late CollectionRepository collections;
  late ConnectionRepository connections;
  late KnownHostRepository knownHosts;
  final now = DateTime.utc(2026, 1, 1);

  setUp(() {
    db = EncryptedDatabase.openInMemory(
      key: EncryptedDatabase.generateKey(),
      migrations: ProfileSchema.runner,
    );
    collections = CollectionRepository(db);
    connections = ConnectionRepository(db);
    knownHosts = KnownHostRepository(db);
  });

  tearDown(() => db.close());

  ServerCollection collection(String id, {int position = 0, String? name}) =>
      ServerCollection(
        id: id,
        name: name ?? 'Collection $id',
        position: position,
        createdAt: now,
        updatedAt: now,
      );

  Connection connection(
    String id, {
    String? collectionId,
    bool favorite = false,
    int position = 0,
  }) => Connection(
    id: id,
    collectionId: collectionId,
    name: 'Server $id',
    hostname: 'host-$id.example.com',
    port: 22,
    username: 'root',
    authType: AuthenticationType.password,
    credentialId: 'cred-$id',
    favorite: favorite,
    position: position,
    createdAt: now,
    updatedAt: now,
  );

  group('CollectionRepository', () {
    test('inserts, lists by position and updates', () {
      collections.insert(collection('b', position: 1));
      collections.insert(collection('a', position: 0));

      expect(collections.all().map((c) => c.id), ['a', 'b']);

      collections.update(
        collections.byId('a')!.copyWith(name: 'Renamed', updatedAt: now),
      );
      expect(collections.byId('a')!.name, 'Renamed');
    });

    test('nextPosition continues after the last one', () {
      expect(collections.nextPosition(), 0);
      collections.insert(collection('a', position: 0));
      expect(collections.nextPosition(), 1);
    });

    test('reorder applies positions atomically', () {
      collections.insert(collection('a', position: 0));
      collections.insert(collection('b', position: 1));

      collections.reorder(['b', 'a'], now: now);

      expect(collections.all().map((c) => c.id), ['b', 'a']);
    });

    test('deleting a collection keeps its connections, unassigned', () {
      collections.insert(collection('c'));
      connections.insert(connection('s', collectionId: 'c'));

      collections.delete('c');

      expect(connections.byId('s')!.collectionId, isNull);
    });
  });

  group('ConnectionRepository', () {
    test(
      'rejects a connection pointing at a collection of another profile',
      () {
        // This repository only sees its own database, so an unknown id is the
        // same failure mode as a cross-profile id.
        expect(
          () => connections.insert(connection('s', collectionId: 'ghost')),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppErrorCode.validation,
            ),
          ),
        );
      },
    );

    test('filters favorites and lists by collection', () {
      collections.insert(collection('c'));
      connections.insert(connection('a', collectionId: 'c'));
      connections.insert(connection('b', favorite: true));

      expect(connections.favorites().map((c) => c.id), ['b']);
      expect(connections.byCollection('c').map((c) => c.id), ['a']);
      expect(connections.byCollection(null).map((c) => c.id), ['b']);
    });

    test('persists tags as JSON and returns them typed', () {
      connections.insert(connection('a').copyWith(tags: const ['prod', 'db']));
      expect(connections.byId('a')!.tags, ['prod', 'db']);
    });

    test('never stores a password column', () {
      final columns = db
          .select("SELECT name FROM pragma_table_info('connections')")
          .map((row) => row['name'] as String)
          .toList();
      expect(columns, isNot(contains('password')));
      expect(columns, contains('credential_id'));
    });
  });

  group('KnownHostRepository', () {
    KnownHost host(String fingerprint) => KnownHost(
      id: 'h1',
      connectionId: 's',
      hostname: 'example.com',
      port: 22,
      keyType: 'ssh-ed25519',
      fingerprint: fingerprint,
      createdAt: now,
    );

    test('accepts a new fingerprint and refuses a changed one silently', () {
      connections.insert(connection('s'));

      knownHosts.accept(host('SHA256:aaa'));
      expect(
        knownHosts
            .find(connectionId: 's', hostname: 'example.com', port: 22)!
            .matches('SHA256:aaa'),
        isTrue,
      );

      // Re-accepting the same key is idempotent.
      knownHosts.accept(host('SHA256:aaa'));

      // A different key for the same host is a conflict, never a silent update.
      expect(
        () => knownHosts.accept(host('SHA256:bbb')),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.conflict,
          ),
        ),
      );
    });

    test('deleting a connection cascades to its known hosts', () {
      connections.insert(connection('s'));
      knownHosts.accept(host('SHA256:aaa'));

      connections.delete('s');

      expect(knownHosts.count(), 0);
    });
  });
}
