import 'dart:io';

import '../../../core/errors/app_exception.dart';
import 'remote_entry.dart';

enum TransferDirection { upload, download }

enum TransferStatus { pending, running, completed, failed, cancelled }

/// Cooperative cancellation for one transfer.
class TransferCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  /// Clears a previous cancellation so a failed task can be retried.
  void reset() => _cancelled = false;

  void throwIfCancelled() {
    if (_cancelled) failWith(AppErrorCode.transferCancelled);
  }
}

/// One queued upload or download, with the progress the UI renders.
class TransferTask {
  TransferTask({
    required this.id,
    required this.name,
    required this.direction,
    required this.totalBytes,
    this.remotePath = '',
    this.localPath = '',
  });

  final String id;
  final String name;
  final TransferDirection direction;

  /// Known before starting for uploads; updated from the server for downloads.
  int totalBytes;
  final String remotePath;
  final String localPath;

  final TransferCancelToken cancelToken = TransferCancelToken();

  int transferredBytes = 0;
  TransferStatus status = TransferStatus.pending;
  AppErrorCode? errorCode;
  double bytesPerSecond = 0;

  bool get isFinished =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.cancelled;

  double get progress =>
      totalBytes <= 0 ? 0 : (transferredBytes / totalBytes).clamp(0, 1);
}

/// Contract the SFTP panel and the transfer queue depend on.
///
/// The real implementation is [SftpService]; tests use an in-memory fake, so the
/// UI never needs a live server to be exercised.
abstract interface class SftpGateway {
  Future<String> home();
  Future<List<RemoteEntry>> list(String path);
  Future<void> createDirectory(String path);
  Future<void> rename(String from, String to);
  Future<void> remove(String path, {bool recursive = true});
  Future<void> upload({
    required File local,
    required String remote,
    required void Function(int transferred, int total) onProgress,
    required TransferCancelToken cancelToken,
  });
  Future<void> download({
    required String remote,
    required File local,
    required void Function(int transferred, int total) onProgress,
    required TransferCancelToken cancelToken,
  });
  Future<void> close();
}
