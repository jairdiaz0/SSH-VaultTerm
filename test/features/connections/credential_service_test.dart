import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_vault_term/core/errors/app_exception.dart';
import 'package:ssh_vault_term/core/storage/secret_store.dart';
import 'package:ssh_vault_term/features/connections/data/credential_service.dart';

import '../../support/in_memory_secret_store.dart';

void main() {
  late InMemorySecretStore secrets;
  late CredentialService credentials;

  setUp(() {
    secrets = InMemorySecretStore();
    credentials = CredentialService(secrets: secrets);
  });

  test('stores and loads a password credential under the profile namespace', () async {
    const profileId = 'profile-1';
    final credentialId = credentials.newCredentialId();

    await credentials.save(
      profileId: profileId,
      credentialId: credentialId,
      secret: const CredentialSecret(password: 'server-password'),
    );

    final key = SecretKeys.credential(profileId, credentialId);
    expect(secrets.snapshot.keys, contains(key));
    // The secret lives only in the (platform-encrypted) secret store, keyed by
    // profile and credential id. Nothing about it goes to SQLite.
    expect(secrets.snapshot[key], contains('server-password'));

    final loaded = await credentials.load(
      profileId: profileId,
      credentialId: credentialId,
    );
    expect(loaded!.password, 'server-password');
    expect(
      await credentials.exists(
        profileId: profileId,
        credentialId: credentialId,
      ),
      isTrue,
    );
  });

  test('a credential of another profile is not visible', () async {
    final credentialId = credentials.newCredentialId();
    await credentials.save(
      profileId: 'profile-a',
      credentialId: credentialId,
      secret: const CredentialSecret(password: 'a-secret'),
    );

    expect(
      await credentials.load(
        profileId: 'profile-b',
        credentialId: credentialId,
      ),
      isNull,
    );
    expect(await credentials.listIds('profile-b'), isEmpty);
    expect(await credentials.listIds('profile-a'), [credentialId]);
  });

  test('empty credentials are rejected', () async {
    await expectLater(
      credentials.save(
        profileId: 'p',
        credentialId: 'c',
        secret: const CredentialSecret(),
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.validation,
        ),
      ),
    );
  });

  test('deleteAll removes every credential of one profile only', () async {
    await credentials.save(
      profileId: 'p1',
      credentialId: 'c1',
      secret: const CredentialSecret(password: 'x'),
    );
    await credentials.save(
      profileId: 'p1',
      credentialId: 'c2',
      secret: const CredentialSecret(privateKeyPem: 'pem', passphrase: 'pp'),
    );
    await credentials.save(
      profileId: 'p2',
      credentialId: 'c3',
      secret: const CredentialSecret(password: 'y'),
    );

    expect(await credentials.deleteAll('p1'), 2);
    expect(await credentials.listIds('p1'), isEmpty);
    expect(await credentials.listIds('p2'), ['c3']);
  });

  test('delete removes only the requested credential', () async {
    await credentials.save(
      profileId: 'p',
      credentialId: 'c1',
      secret: const CredentialSecret(password: 'x'),
    );
    await credentials.save(
      profileId: 'p',
      credentialId: 'c2',
      secret: const CredentialSecret(password: 'y'),
    );

    await credentials.delete(profileId: 'p', credentialId: 'c1');
    expect(await credentials.listIds('p'), ['c2']);
  });
}
