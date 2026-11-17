import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/transfer.dart';

/// Sequential queue of uploads and downloads.
///
/// One worker runs at a time so a slow transfer never starves the UI or the
/// SSH channel. Progress is reported per chunk; speeds are a simple average over
/// the running transfer. Cancelling marks the token and the worker stops at the
/// next chunk boundary, leaving a partially written file that the user can
/// retry (retry truncates again).
class TransferQueue extends ChangeNotifier {
  TransferQueue({required this.gateway, this.uuid = const Uuid()});

  final SftpGateway gateway;
  final Uuid uuid;

  final List<TransferTask> _tasks = <TransferTask>[];
  bool _running = false;

  List<TransferTask> get tasks => List.unmodifiable(_tasks);

  bool get isRunning => _running;

  TransferTask enqueueUpload({
    required File local,
    required String remote,
    required String name,
  }) {
    final task = TransferTask(
      id: uuid.v4(),
      name: name,
      direction: TransferDirection.upload,
      totalBytes: local.lengthSync(),
      remotePath: remote,
      localPath: local.path,
    );
    _tasks.add(task);
    notifyListeners();
    return task;
  }

  TransferTask enqueueDownload({
    required String remote,
    required File local,
    required String name,
    int totalBytes = 0,
  }) {
    final task = TransferTask(
      id: uuid.v4(),
      name: name,
      direction: TransferDirection.download,
      totalBytes: totalBytes,
      remotePath: remote,
      localPath: local.path,
    );
    _tasks.add(task);
    notifyListeners();
    return task;
  }

  /// Drains the queue. Calling it while it runs is a no-op.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    notifyListeners();
    try {
      for (final task in _tasks) {
        if (task.isFinished) continue;
        await _run(task);
      }
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  /// Asks for cancellation. A pending task becomes cancelled immediately; a
  /// running one stops at the next chunk boundary.
  void cancel(String id) {
    final task = _task(id);
    if (task == null || task.isFinished) return;
    task.cancelToken.cancel();
    if (task.status == TransferStatus.pending) {
      task.status = TransferStatus.cancelled;
    }
    notifyListeners();
  }

  /// Puts a failed or cancelled task back at the end of the queue.
  void retry(String id) {
    final task = _task(id);
    if (task == null) return;
    if (task.status != TransferStatus.failed &&
        task.status != TransferStatus.cancelled) {
      return;
    }
    task.cancelToken.reset();
    task.status = TransferStatus.pending;
    task.transferredBytes = 0;
    task.bytesPerSecond = 0;
    task.errorCode = null;
    notifyListeners();
  }

  Future<void> _run(TransferTask task) async {
    if (task.cancelToken.isCancelled) {
      task.status = TransferStatus.cancelled;
      notifyListeners();
      return;
    }
    task.status = TransferStatus.running;
    task.transferredBytes = 0;
    task.errorCode = null;
    notifyListeners();

    final stopwatch = Stopwatch()..start();
    try {
      switch (task.direction) {
        case TransferDirection.upload:
          await gateway.upload(
            local: File(task.localPath),
            remote: task.remotePath,
            onProgress: (transferred, total) =>
                _onProgress(task, transferred, total, stopwatch),
            cancelToken: task.cancelToken,
          );
        case TransferDirection.download:
          await gateway.download(
            remote: task.remotePath,
            local: File(task.localPath),
            onProgress: (transferred, total) =>
                _onProgress(task, transferred, total, stopwatch),
            cancelToken: task.cancelToken,
          );
      }
      task.status = TransferStatus.completed;
      task.transferredBytes = task.totalBytes;
    } on AppException catch (error) {
      task.errorCode = error.code;
      task.status = error.code == AppErrorCode.transferCancelled
          ? TransferStatus.cancelled
          : TransferStatus.failed;
    } catch (_) {
      task.errorCode = AppErrorCode.transferFailed;
      task.status = TransferStatus.failed;
    } finally {
      stopwatch.stop();
      if (task.status == TransferStatus.running) {
        task.status = TransferStatus.failed;
        task.errorCode ??= AppErrorCode.transferFailed;
      }
      if (task.bytesPerSecond == 0 &&
          task.transferredBytes > 0 &&
          stopwatch.elapsedMilliseconds > 0) {
        task.bytesPerSecond =
            task.transferredBytes * 1000 / stopwatch.elapsedMilliseconds;
      }
      notifyListeners();
    }
  }

  void _onProgress(
    TransferTask task,
    int transferred,
    int total,
    Stopwatch stopwatch,
  ) {
    task.transferredBytes = transferred;
    if (total > 0) task.totalBytes = total;
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed >= 100) {
      task.bytesPerSecond = transferred * 1000 / elapsed;
    }
    notifyListeners();
  }

  TransferTask? _task(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }
}
