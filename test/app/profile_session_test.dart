import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/app/profile_session.dart';
import 'package:ssh_client/core/database/database_key_store.dart';
import 'package:ssh_client/shared/models/connection.dart';

import '../support/test_context.dart';

void main() {
  late TestContext ctx;

  setUp(() async {
    ctx = await TestContext.create();
  });

  tearDown(() async {
    await ctx.dispose();
  });

  Future<ProfileSession> openFor(String name) async {
    final profile = await ctx.profiles.create(
      name: name,
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );
    return ProfileSession.open(
      profile: profile,
      paths: ctx.paths,
      keys: ctx.keys,
    );
  }

  test('each profile gets its own database and its own key', () async {
    final a = await openFor('A');
    final b = await openFor('B');
    addTearDown(a.close);
    addTearDown(b.close);

    expect(
      ctx.paths.profileDatabase(a.profile.id),
      isNot(ctx.paths.profileDatabase(b.profile.id)),
    );

    final keyA = await ctx.keys.loadProfileKey(a.profile.id);
    final keyB = await ctx.keys.loadProfileKey(b.profile.id);
    expect(keyA, isNot(equals(keyB)));

    final now = ctx.clock.value;
    a.connections.insert(
      Connection(
        id: 'a-server',
        name: 'A only',
        hostname: 'a.example.com',
        port: 22,
        username: 'root',
        authType: AuthenticationType.password,
        position: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(a.connections.all().length, 1);
    expect(b.connections.all(), isEmpty);
  });

  test('data survives closing and reopening a session', () async {
    final profile = await ctx.profiles.create(
      name: 'Persist',
      password: testPassword,
      passwordConfirmation: testPassword,
      params: testArgon2Params,
    );

    final first = await ProfileSession.open(
      profile: profile,
      paths: ctx.paths,
      keys: ctx.keys,
    );
    final now = ctx.clock.value;
    first.connections.insert(
      Connection(
        id: 's1',
        name: 'Server',
        hostname: 's1.example.com',
        port: 2222,
        username: 'admin',
        authType: AuthenticationType.privateKey,
        credentialId: 'cred-1',
        position: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    first.close();

    final second = await ProfileSession.open(
      profile: profile,
      paths: ctx.paths,
      keys: ctx.keys,
    );
    addTearDown(second.close);

    expect(second.connections.all().single.hostname, 's1.example.com');
    expect(second.connections.byId('s1')!.port, 2222);
    expect(
      second.connections.byId('s1')!.authType,
      AuthenticationType.privateKey,
    );
  });

  test('close is idempotent', () async {
    final session = await openFor('Idempotent');
    session.close();
    session.close();
    expect(session.isClosed, isTrue);
  });

  test('DatabaseKeyStore creates keys once and keeps them stable', () async {
    final store = DatabaseKeyStore(secrets: ctx.secrets);
    final first = await store.createProfileKey('p');
    final second = await store.loadProfileKey('p');
    expect(first, equals(second));
    expect(first.length, 32);

    await store.forgetProfile('p');
    final recreated = await store.createProfileKey('p');
    expect(recreated, isNot(equals(first)));
  });
}
