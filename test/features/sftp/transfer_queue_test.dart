import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_vault_term/core/errors/app_exception.dart';
import 'package:ssh_vault_term/features/sftp/data/transfer_queue.dart';
import 'package:ssh_vault_term/features/sftp/domain/remote_entry.dart';
import 'package:ssh_vault_term/features/sftp/domain/transfer.dart';

/// In-memory gateway: simulates chunks, failures and cancellation without SFTP.
class FakeSftpGateway implements SftpGateway {
  FakeSftpGateway({this.failOnce = false, this.totalForDownload = 300});

  final bool failOnce;
  final int totalForDownload;
  bool _failed = false;
  int uploadCalls = 0;
  int downloadCalls = 0;

  @override
  Future<void> upload({
    required File local,
    required String remote,
    required void Function(int transferred, int total) onProgress,
    required TransferCancelToken cancelToken,
  }) async {
    uploadCalls++;
    const total = 300;
    for (var step = 1; step <= 3; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (failOnce && !_failed) {
        _failed = true;
        throw const AppException(AppErrorCode.sftpFailure);
      }
      if (cancelToken.isCancelled) {
        throw const AppException(AppErrorCode.transferCancelled);
      }
      onProgress(step * 100, total);
    }
  }

  @override
  Future<void> download({
    required String remote,
    required File local,
    required void Function(int transferred, int total) onProgress,
    required TransferCancelToken cancelToken,
  }) async {
    downloadCalls++;
    for (var step = 1; step <= 3; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (cancelToken.isCancelled) {
        throw const AppException(AppErrorCode.transferCancelled);
      }
      onProgress(step * 100, totalForDownload);
    }
  }

  @override
  Future<String> home() async => '/home/test';

  @override
  Future<List<RemoteEntry>> list(String path) async => const [];

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> rename(String from, String to) async {}

  @override
  Future<void> remove(String path, {bool recursive = true}) async {}

  @override
  Future<void> close() async {}
}

void main() {
  late Directory root;
  late File localFile;

  setUp(() {
    root = Directory.systemTemp.createTempSync('sftp_queue_test_');
    localFile = File('${root.path}/local.bin')
      ..writeAsBytesSync(List<int>.generate(300, (index) => index % 256));
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('an upload runs once and reports chunks and speed', () async {
    final gateway = FakeSftpGateway();
    final queue = TransferQueue(gateway: gateway);
    addTearDown(queue.dispose);
    final task = queue.enqueueUpload(
      local: localFile,
      remote: '/remote/local.bin',
      name: 'local.bin',
    );

    final states = <TransferStatus>[];
    queue.addListener(() => states.add(task.status));

    await queue.start();

    expect(task.status, TransferStatus.completed);
    expect(task.transferredBytes, task.totalBytes);
    expect(task.totalBytes, 300);
    expect(task.bytesPerSecond, greaterThan(0));
    expect(gateway.uploadCalls, 1);
    expect(states, contains(TransferStatus.running));
  });

  test('a download learns its total size from the server', () async {
    final gateway = FakeSftpGateway(totalForDownload: 900);
    final queue = TransferQueue(gateway: gateway);
    addTearDown(queue.dispose);
    final task = queue.enqueueDownload(
      remote: '/remote/big.bin',
      local: File('${root.path}/big.bin'),
      name: 'big.bin',
    );

    await queue.start();

    expect(task.status, TransferStatus.completed);
    expect(task.totalBytes, 900);
    expect(task.progress, 1);
  });

  test('cancelling a running transfer stops it at the next chunk', () async {
    final gateway = FakeSftpGateway();
    final queue = TransferQueue(gateway: gateway);
    addTearDown(queue.dispose);
    final task = queue.enqueueUpload(
      local: localFile,
      remote: '/remote/local.bin',
      name: 'local.bin',
    );

    final running = queue.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    queue.cancel(task.id);
    await running;

    expect(task.status, TransferStatus.cancelled);
    expect(task.errorCode, AppErrorCode.transferCancelled);
  });

  test('a cancelled pending task never touches the gateway', () async {
    final gateway = FakeSftpGateway();
    final queue = TransferQueue(gateway: gateway);
    addTearDown(queue.dispose);
    final task = queue.enqueueUpload(
      local: localFile,
      remote: '/remote/local.bin',
      name: 'local.bin',
    );

    queue.cancel(task.id);
    await queue.start();

    expect(task.status, TransferStatus.cancelled);
    expect(gateway.uploadCalls, 0);
  });

  test('a failure is reported and retry can finish the transfer', () async {
    final gateway = FakeSftpGateway(failOnce: true);
    final queue = TransferQueue(gateway: gateway);
    addTearDown(queue.dispose);
    final task = queue.enqueueUpload(
      local: localFile,
      remote: '/remote/local.bin',
      name: 'local.bin',
    );

    await queue.start();
    expect(task.status, TransferStatus.failed);
    expect(task.errorCode, AppErrorCode.sftpFailure);

    queue.retry(task.id);
    expect(task.status, TransferStatus.pending);
    expect(task.transferredBytes, 0);

    await queue.start();
    expect(task.status, TransferStatus.completed);
    expect(task.errorCode, isNull);
    expect(gateway.uploadCalls, 2);
  });
}
