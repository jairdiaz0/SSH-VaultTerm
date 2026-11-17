@Tags(['integration'])
library;

import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_vault_term/core/errors/app_exception.dart';
import 'package:ssh_vault_term/features/sftp/data/sftp_service.dart';
import 'package:ssh_vault_term/features/sftp/data/transfer_queue.dart';
import 'package:ssh_vault_term/features/sftp/domain/posix_path.dart';
import 'package:ssh_vault_term/features/sftp/domain/transfer.dart';
import 'package:ssh_vault_term/features/ssh/data/ssh_connection.dart';
import 'package:uuid/uuid.dart';

import '../../support/ssh_integration_harness.dart';
import '../../support/ssh_test_server.dart';

Future<String> sha256OfFile(File file) async {
  final hash = await Sha256().hash(await file.readAsBytes());
  return hash.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

Future<String> remoteSha256(SshConnection ssh, String path) async {
  final result = await ssh.execute('sha256sum $path');
  expect(result.exitCode, 0, reason: result.stderr);
  return result.stdout.split(' ').first.trim();
}

/// Best-effort cleanup: a missing path is already what we want.
Future<void> tryRemove(SftpService sftp, String path) async {
  try {
    await sftp.remove(path);
  } on AppException {
    // Already gone.
  }
}

void main() {
  final server = SshTestServer.load();

  group('SFTP integration (real server)', () {
    final config = server;
    if (config == null) return;

    late SshIntegrationHarness harness;
    late Directory local;

    setUp(() {
      harness = SshIntegrationHarness.create(config);
      local = Directory.systemTemp.createTempSync('ssh_vault_term_sftp_');
    });

    tearDown(() {
      harness.dispose();
      if (local.existsSync()) local.deleteSync(recursive: true);
    });

    test('lists, uploads, verifies checksum, downloads and deletes', () async {
      final connection = await harness.addConnection(password: config.password);
      final ssh = await harness.service.connect(
        connection,
        confirmHostKey: (_) async => true,
      );
      final sftp = await SftpService.open(ssh);
      final home = await sftp.home();
      expect(home.startsWith('/'), isTrue);

      final sandbox = PosixPath.join(home, 'opencode_sandbox');
      final runDirectory = PosixPath.join(sandbox, 'run_${const Uuid().v4()}');
      final homeEntries = await sftp.list(home);
      if (!homeEntries.any(
        (entry) => entry.name == 'opencode_sandbox' && entry.isDirectory,
      )) {
        await sftp.createDirectory(sandbox);
      }
      await sftp.createDirectory(runDirectory);

      try {
        // A 2 MiB pseudo-random payload: chunking, multi-packet transfer.
        final bytes = List<int>.generate(2 * 1024 * 1024, (index) {
          return (index * 1103515245 + 12345) & 0xFF;
        });
        final source = File('${local.path}/payload.bin')
          ..writeAsBytesSync(bytes);
        final remoteFile = PosixPath.join(runDirectory, 'payload.bin');
        final localHash = await sha256OfFile(source);

        final upload = TransferCancelToken();
        var uploaded = 0;
        await sftp.upload(
          local: source,
          remote: remoteFile,
          onProgress: (transferred, total) {
            uploaded = transferred;
            expect(total, bytes.length);
          },
          cancelToken: upload,
        );
        expect(uploaded, bytes.length);
        expect(await remoteSha256(ssh, remoteFile), localHash);

        final listing = await sftp.list(runDirectory);
        final entry = listing.singleWhere((item) => item.name == 'payload.bin');
        expect(entry.isFile, isTrue);
        expect(entry.size, bytes.length);
        expect(entry.permissions.length, 9);

        final downloaded = File('${local.path}/downloaded.bin');
        await sftp.download(
          remote: remoteFile,
          local: downloaded,
          onProgress: (_, _) {},
          cancelToken: TransferCancelToken(),
        );
        expect(await sha256OfFile(downloaded), localHash);

        final renamed = PosixPath.join(runDirectory, 'renamed.bin');
        await sftp.rename(remoteFile, renamed);
        expect(
          (await sftp.list(runDirectory)).map((item) => item.name),
          contains('renamed.bin'),
        );

        // Nested directories, then a recursive delete.
        final nested = PosixPath.join(runDirectory, 'a/b/c');
        await sftp.createDirectory(PosixPath.join(runDirectory, 'a'));
        await sftp.createDirectory(PosixPath.join(runDirectory, 'a/b'));
        await sftp.createDirectory(nested);
        final nestedFile = File('${local.path}/nested.txt')
          ..writeAsStringSync('hola ñandú');
        await sftp.upload(
          local: nestedFile,
          remote: PosixPath.join(nested, 'nested.txt'),
          onProgress: (_, _) {},
          cancelToken: TransferCancelToken(),
        );

        await tryRemove(sftp, runDirectory);
        expect(
          (await sftp.list(sandbox)).map((item) => item.name),
          isNot(contains(PosixPath.basename(runDirectory))),
        );
      } finally {
        await tryRemove(sftp, runDirectory);
        await sftp.close();
        await ssh.close();
      }
    });

    test('maps a missing remote path to sftpNotFound', () async {
      final connection = await harness.addConnection(password: config.password);
      final ssh = await harness.service.connect(
        connection,
        confirmHostKey: (_) async => true,
      );
      final sftp = await SftpService.open(ssh);
      try {
        await expectLater(
          sftp.list('/definitely/not/here/opencode-test'),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppErrorCode.sftpNotFound,
            ),
          ),
        );
      } finally {
        await sftp.close();
        await ssh.close();
      }
    });

    test('the transfer queue uploads and downloads with progress', () async {
      final connection = await harness.addConnection(password: config.password);
      final ssh = await harness.service.connect(
        connection,
        confirmHostKey: (_) async => true,
      );
      final sftp = await SftpService.open(ssh);
      final home = await sftp.home();
      final sandbox = PosixPath.join(home, 'opencode_sandbox');
      final runDirectory = PosixPath.join(sandbox, 'run_${const Uuid().v4()}');
      final homeEntries = await sftp.list(home);
      if (!homeEntries.any(
        (entry) => entry.name == 'opencode_sandbox' && entry.isDirectory,
      )) {
        await sftp.createDirectory(sandbox);
      }
      await sftp.createDirectory(runDirectory);

      final queue = TransferQueue(gateway: sftp);
      addTearDown(queue.dispose);
      try {
        final source = File('${local.path}/queue.bin')
          ..writeAsBytesSync(
            List<int>.generate(200000, (index) => index & 0xFF),
          );
        final upload = queue.enqueueUpload(
          local: source,
          remote: PosixPath.join(runDirectory, 'queue.bin'),
          name: 'queue.bin',
        );
        await queue.start();
        expect(upload.status, TransferStatus.completed);
        expect(upload.transferredBytes, upload.totalBytes);

        final downloaded = File('${local.path}/queue-downloaded.bin');
        final download = queue.enqueueDownload(
          remote: upload.remotePath,
          local: downloaded,
          name: 'queue.bin',
        );
        await queue.start();
        expect(download.status, TransferStatus.completed);
        expect(await sha256OfFile(downloaded), await sha256OfFile(source));
      } finally {
        await tryRemove(sftp, runDirectory);
        await sftp.close();
        await ssh.close();
      }
    });
  }, skip: server == null ? 'SSH_TEST_* not configured (see .env.test)' : null);
}
