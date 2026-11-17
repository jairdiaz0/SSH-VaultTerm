import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_exception.dart';
import '../data/transfer_queue.dart';
import '../domain/posix_path.dart';
import '../domain/remote_entry.dart';
import '../domain/transfer.dart';

/// Remote directory state of the SFTP panel.
///
/// Holds the current path, its entries and a small back/forward history. Every
/// mutation goes through [gateway], so the same controller drives the real
/// panel and a fake in tests. Nothing here reads or writes local files except
/// through the transfer queue.
class SftpController extends ChangeNotifier {
  SftpController({required this.gateway, TransferQueue? queue})
    : queue = queue ?? TransferQueue(gateway: gateway);

  final SftpGateway gateway;
  final TransferQueue queue;

  final List<RemoteEntry> _entries = <RemoteEntry>[];
  final List<String> _history = <String>[];
  int _historyIndex = -1;
  String _path = '/';
  bool _loading = false;
  bool _showHidden = false;
  AppErrorCode? _errorCode;

  String get path => _path;
  bool get isLoading => _loading;
  bool get showHidden => _showHidden;
  AppErrorCode? get errorCode => _errorCode;

  List<RemoteEntry> get entries => _showHidden
      ? List.unmodifiable(_entries)
      : _entries.where((entry) => !entry.isHidden).toList();

  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward =>
      _historyIndex >= 0 && _historyIndex < _history.length - 1;

  Future<void> initialize() async {
    try {
      final home = await gateway.home();
      await _navigate(home);
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> open(String path) => _navigate(path);

  Future<void> refresh() =>
      _historyIndex < 0 ? initialize() : _navigate(_path, pushHistory: false);

  Future<void> up() async {
    final parent = PosixPath.parent(_path);
    if (parent == _path) return;
    await _navigate(parent);
  }

  Future<void> back() async {
    if (!canGoBack) return;
    _historyIndex--;
    await _navigate(_history[_historyIndex], pushHistory: false);
  }

  Future<void> forward() async {
    if (!canGoForward) return;
    _historyIndex++;
    await _navigate(_history[_historyIndex], pushHistory: false);
  }

  void toggleHidden() {
    _showHidden = !_showHidden;
    notifyListeners();
  }

  Future<bool> createFolder(String name) async {
    final target = PosixPath.join(_path, name.trim());
    if (name.trim().isEmpty) return false;
    try {
      await gateway.createDirectory(target);
      await refresh();
      return true;
    } catch (error) {
      _fail(error);
      return false;
    }
  }

  Future<bool> rename(RemoteEntry entry, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    try {
      await gateway.rename(entry.path, PosixPath.join(_path, trimmed));
      await refresh();
      return true;
    } catch (error) {
      _fail(error);
      return false;
    }
  }

  Future<bool> deleteEntry(RemoteEntry entry) async {
    try {
      await gateway.remove(entry.path);
      await refresh();
      return true;
    } catch (error) {
      _fail(error);
      return false;
    }
  }

  /// Queues one upload per local path into the current remote directory.
  Future<void> uploadFiles(Iterable<String> localPaths) async {
    var queued = 0;
    for (final localPath in localPaths) {
      final file = File(localPath);
      if (!file.existsSync()) continue;
      final name = p.basename(localPath);
      queue.enqueueUpload(
        local: file,
        remote: PosixPath.join(_path, name),
        name: name,
      );
      queued++;
    }
    if (queued == 0) return;
    await queue.start();
    await refresh();
  }

  /// Queues a download of [entry] into [destinationDirectory].
  Future<void> downloadTo(
    RemoteEntry entry,
    String destinationDirectory,
  ) async {
    final file = File(p.join(destinationDirectory, entry.name));
    queue.enqueueDownload(
      remote: entry.path,
      local: file,
      name: entry.name,
      totalBytes: entry.size,
    );
    await queue.start();
  }

  Future<void> _navigate(String path, {bool pushHistory = true}) async {
    _loading = true;
    _errorCode = null;
    notifyListeners();
    try {
      final entries = await gateway.list(path);
      _entries
        ..clear()
        ..addAll(entries);
      _path = path;
      _loading = false;
      if (pushHistory) {
        while (_history.length > _historyIndex + 1) {
          _history.removeLast();
        }
        _history.add(path);
        _historyIndex = _history.length - 1;
      }
      notifyListeners();
    } catch (error) {
      _fail(error);
    }
  }

  void _fail(Object error) {
    _loading = false;
    _errorCode = error is AppException ? error.code : AppErrorCode.sftpFailure;
    notifyListeners();
  }

  @override
  void dispose() {
    queue.dispose();
    unawaited(gateway.close());
    super.dispose();
  }
}
