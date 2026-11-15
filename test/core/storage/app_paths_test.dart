import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ssh_client/core/storage/app_paths.dart';
import 'package:ssh_client/core/storage/secret_store.dart';

void main() {
  late Directory root;
  late AppPaths paths;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ssh_client_paths_test_');
    paths = AppPaths(root.path);
  });

  tearDown(() {
    paths.deleteProfileFiles('p1');
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('layout is stable and documented in docs/DATABASE.md', () {
    expect(paths.catalogDatabase, p.join(root.path, 'catalog.db'));
    expect(paths.profileDirectory('p1'), p.join(root.path, 'profiles', 'p1'));
    expect(
      paths.profileDatabase('p1'),
      p.join(root.path, 'profiles', 'p1', 'data.db'),
    );
  });

  test('ensureCreated creates the data and profiles directories', () {
    paths.ensureCreated();

    expect(Directory(root.path).existsSync(), isTrue);
    expect(Directory(p.join(root.path, 'profiles')).existsSync(), isTrue);
    expect(paths.profileDirectoryExists('p1'), isFalse);

    paths.ensureProfileDirectory('p1');
    expect(paths.profileDirectoryExists('p1'), isTrue);
  });

  test('Windows uses LOCALAPPDATA, never Roaming', () async {
    final resolved = await AppPaths.resolveFrom(
      environment: const {
        'LOCALAPPDATA': r'C:\Users\me\AppData\Local',
        'APPDATA': r'C:\Users\me\AppData\Roaming',
      },
      applicationSupport: () async => Directory(root.path),
      isWindows: true,
    );
    expect(
      resolved.root,
      p.join(r'C:\Users\me\AppData\Local', 'dev.sshclient', 'ssh_client'),
    );
  });

  test('the data dir override wins on every platform', () async {
    final override = p.join(root.path, 'override');
    final resolved = await AppPaths.resolveFrom(
      environment: {'SSH_CLIENT_DATA_DIR': override},
      applicationSupport: () async => Directory(root.path),
      isWindows: true,
    );
    expect(resolved.root, p.normalize(p.absolute(override)));
  });

  test('deleteProfileFiles removes the database and its WAL sidecars', () {
    paths.ensureProfileDirectory('p1');
    final db = File(paths.profileDatabase('p1'))..writeAsStringSync('x');
    final wal = File('${db.path}-wal')..writeAsStringSync('x');
    final shm = File('${db.path}-shm')..writeAsStringSync('x');

    paths.deleteProfileFiles('p1');

    expect(db.existsSync(), isFalse);
    expect(wal.existsSync(), isFalse);
    expect(shm.existsSync(), isFalse);
    expect(paths.profileDirectoryExists('p1'), isFalse);
  });

  test('deleteProfileFiles tolerates a missing profile directory', () {
    expect(() => paths.deleteProfileFiles('missing'), returnsNormally);
  });

  test('secret key namespace is exactly the documented one', () {
    expect(SecretKeys.catalogDatabaseKey, 'catalog/dbKey');
    expect(SecretKeys.profileDatabaseKey('p1'), 'profile/p1/dbKey');
    expect(SecretKeys.credential('p1', 'c1'), 'profile/p1/credential/c1');
    expect(SecretKeys.profilePrefix('p1'), 'profile/p1/');
  });
}
