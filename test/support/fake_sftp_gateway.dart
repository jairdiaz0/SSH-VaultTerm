import 'dart:io';

import 'package:ssh_client/core/errors/app_exception.dart';
import 'package:ssh_client/features/sftp/domain/posix_path.dart';
import 'package:ssh_client/features/sftp/domain/remote_entry.dart';
import 'package:ssh_client/features/sftp/domain/transfer.dart';

/// In-memory SFTP server for widget tests.
class FakeSftpGateway implements SftpGateway {
  FakeSftpGateway({
    Map<String, List<RemoteEntry>>? tree,
    this.homePath = '/home/test',
  }) : tree = tree ?? <String, List<RemoteEntry>>{};

  final Map<String, List<RemoteEntry>> tree;
  final String homePath;

  bool failList = false;
  bool closed = false;
  int listCalls = 0;
  final List<String> uploaded = <String>[];
  final List<String> downloaded = <String>[];

  static RemoteEntry dir(String parent, String name, {int mode = 0x41ED}) =>
      RemoteEntry(
        name: name,
        path: PosixPath.join(parent, name),
        type: RemoteEntryType.directory,
        modeValue: mode,
        modifiedAt: DateTime.utc(2026, 1, 1, 10),
      );

  static RemoteEntry file(
    String parent,
    String name, {
    int size = 1024,
    int mode = 0x81A4,
  }) => RemoteEntry(
    name: name,
    path: PosixPath.join(parent, name),
    type: RemoteEntryType.file,
    size: size,
    modeValue: mode,
    modifiedAt: DateTime.utc(2026, 1, 1, 10),
  );

  @override
  Future<String> home() async => homePath;

  @override
  Future<List<RemoteEntry>> list(String path) async {
    listCalls++;
    if (failList) throw const AppException(AppErrorCode.sftpNotFound);
    return tree[path] ?? <RemoteEntry>[];
  }

  @override
  Future<void> createDirectory(String path) async {
    tree[path] = <RemoteEntry>[];
    final parent = PosixPath.parent(path);
    tree[parent] = [...?tree[parent], dir(parent, PosixPath.basename(path))];
  }

  @override
  Future<void> rename(String from, String to) async {
    final parent = PosixPath.parent(from);
    final entries = tree[parent] ?? <RemoteEntry>[];
    final index = entries.indexWhere((entry) => entry.path == from);
    if (index < 0) throw const AppException(AppErrorCode.sftpNotFound);
    final renamed = RemoteEntry(
      name: PosixPath.basename(to),
      path: to,
      type: entries[index].type,
      size: entries[index].size,
      modeValue: entries[index].modeValue,
      modifiedAt: entries[index].modifiedAt,
    );
    entries[index] = renamed;
    tree[parent] = entries;
  }

  @override
  Future<void> remove(String path, {bool recursive = true}) async {
    final parent = PosixPath.parent(path);
    tree[parent]?.removeWhere((entry) => entry.path == path);
    tree.remove(path);
  }

  @override
  Future<void> upload({
    required File local,
    required String remote,
    required void Function(int transferred, int total) onProgress,
    required TransferCancelToken cancelToken,
  }) async {
    cancelToken.throwIfCancelled();
    uploaded.add(remote);
    final total = local.lengthSync();
    onProgress(total, total);
    final parent = PosixPath.parent(remote);
    tree[parent] = [
      ...?tree[parent],
      file(parent, PosixPath.basename(remote), size: total),
    ];
  }

  @override
  Future<void> download({
    required String remote,
    required File local,
    required void Function(int transferred, int total) onProgress,
    required TransferCancelToken cancelToken,
  }) async {
    cancelToken.throwIfCancelled();
    downloaded.add(remote);
    local.writeAsStringSync('downloaded:$remote');
    onProgress(10, 10);
  }

  @override
  Future<void> close() async => closed = true;
}
