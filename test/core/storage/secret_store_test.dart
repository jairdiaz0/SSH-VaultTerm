import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/core/storage/secret_store.dart';

import '../../support/in_memory_secret_store.dart';

void main() {
  test('write/read/delete round trip', () async {
    final store = InMemorySecretStore();
    await store.write(SecretKeys.catalogDatabaseKey, 'abc');
    expect(await store.read(SecretKeys.catalogDatabaseKey), 'abc');
    await store.delete(SecretKeys.catalogDatabaseKey);
    expect(await store.read(SecretKeys.catalogDatabaseKey), isNull);
  });

  test('key layout keeps profiles in separate namespaces', () async {
    final store = InMemorySecretStore();
    await store.write(SecretKeys.profileDatabaseKey('p1'), 'k1');
    await store.write(SecretKeys.profileDatabaseKey('p2'), 'k2');
    await store.write(SecretKeys.credential('p1', 'c1'), 'secret1');
    await store.write(SecretKeys.credential('p2', 'c2'), 'secret2');

    expect(await store.keysWithPrefix(SecretKeys.profilePrefix('p1')), [
      'profile/p1/credential/c1',
      'profile/p1/dbKey',
    ]);
    expect(await store.keysWithPrefix(SecretKeys.profilePrefix('p2')), [
      'profile/p2/credential/c2',
      'profile/p2/dbKey',
    ]);

    final removed = await store.deletePrefix(SecretKeys.profilePrefix('p1'));
    expect(removed, 2);
    expect(await store.read(SecretKeys.profileDatabaseKey('p2')), 'k2');
    expect(await store.read(SecretKeys.credential('p2', 'c2')), 'secret2');
  });

  test('an unavailable store reports it instead of degrading', () async {
    final store = InMemorySecretStore(available: false);
    expect(await store.isAvailable(), isFalse);
    await expectLater(
      store.write(SecretKeys.catalogDatabaseKey, 'abc'),
      throwsA(isA<StateError>()),
    );
  });
}
