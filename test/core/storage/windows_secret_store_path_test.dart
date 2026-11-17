import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ssh_vault_term/core/storage/windows_secret_store_path.dart';

void main() {
  test('the Windows key store lives in the roaming app-support folder', () {
    final roaming = p.join('C:', 'Users', 'someone', 'AppData', 'Roaming');
    final path = windowsSecretStoreFile({'APPDATA': roaming});

    expect(
      path,
      p.join(
        roaming,
        'dev.sshclient',
        'ssh_client',
        'flutter_secure_storage.dat',
      ),
    );
    // Exactly one separator per level: an over-escaped path silently deleted
    // nothing and made the reset fail.
    expect(path, isNot(contains(r'\\')));
  });

  test('no APPDATA means no path to delete', () {
    expect(windowsSecretStoreFile(const {}), isNull);
    expect(windowsSecretStoreFile(const {'APPDATA': '   '}), isNull);
  });
}
