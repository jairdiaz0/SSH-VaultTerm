import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../../core/errors/app_exception.dart';
import '../../ssh/data/ssh_connection.dart';
import '../domain/posix_path.dart';
import '../domain/remote_entry.dart';
import '../domain/transfer.dart';

/// Real SFTP channel on an existing SSH connection.
///
/// One subsystem per instance; the terminal keeps its own channel, so closing
/// this one never closes the session. Files are streamed in chunks: nothing is
/// buffered whole in memory and nothing is logged.
class SftpService implements SftpGateway {
  SftpService._(this.connection, this._client);

  static const chunkSize = 64 * 1024;

  final SshConnection connection;
  final SftpClient _client;

  static Future<SftpService> open(SshConnection connection) async {
    final client = await connection.client.sftp();
    return SftpService._(connection, client);
  }

  @override
  Future<String> home() => _guard(() => _client.absolute('.'));

  @override
  Future<List<RemoteEntry>> list(String path) => _guard(() async {
    final names = await _client.listdir(path);
    final entries = <RemoteEntry>[];
    for (final name in names) {
      if (name.filename == '.' ||
          name.filename == '..' ||
          name.filename.contains('/')) {
        // A server must not be able to smuggle a path separator into a name.
        continue;
      }
      final mode = name.attr.mode?.value;
      final modified = name.attr.modifyTime;
      entries.add(
        RemoteEntry(
          name: name.filename,
          path: PosixPath.join(path, name.filename),
          type: RemoteEntry.typeOf(mode),
          size: name.attr.size ?? 0,
          modifiedAt: modified == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(modified * 1000),
          modeValue: mode,
        ),
      );
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  });

  @override
  Future<void> createDirectory(String path) =>
      _guard(() => _client.mkdir(path));

  @override
  Future<void> rename(String from, String to) =>
      _guard(() => _client.rename(from, to));

  @override
  Future<void> remove(String path, {bool recursive = true}) => _guard(() async {
    final attrs = await _client.stat(path, followLink: false);
    final isDirectory =
        RemoteEntry.typeOf(attrs.mode?.value) == RemoteEntryType.directory;
    if (!isDirectory) {
      await _client.remove(path);
      return;
    }
    if (!recursive) {
      await _client.rmdir(path);
      return;
    }
    for (final child in await list(path)) {
      await remove(child.path);
    }
    await _client.rmdir(path);
  });

  @override
  Future<void> upload({
    required File local,
    required String remote,
    required void Function(int transferred, int total) onProgress,
    required TransferCancelToken cancelToken,
  }) => _guard(() async {
    final total = await local.length();
    final file = await _client.open(
      remote,
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    try {
      var offset = 0;
      await for (final chunk in local.openRead()) {
        cancelToken.throwIfCancelled();
        final data = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        await file.writeBytes(data, offset: offset);
        offset += data.length;
        onProgress(offset, total);
      }
    } finally {
      await file.close();
    }
  });

  @override
  Future<void> download({
    required String remote,
    required File local,
    required void Function(int transferred, int total) onProgress,
    required TransferCancelToken cancelToken,
  }) => _guard(() async {
    final attrs = await _client.stat(remote);
    final total = attrs.size ?? 0;
    final file = await _client.open(remote, mode: SftpFileOpenMode.read);
    final sink = local.openWrite();
    try {
      var offset = 0;
      while (true) {
        cancelToken.throwIfCancelled();
        final data = await file.readBytes(length: chunkSize, offset: offset);
        if (data.isEmpty) break;
        sink.add(data);
        offset += data.length;
        onProgress(offset, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
      await file.close();
    }
  });

  @override
  Future<void> close() async {
    try {
      await _client.close();
    } catch (_) {
      // The channel may already be gone with the connection.
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppException {
      rethrow;
    } on SftpStatusError catch (error) {
      throw AppException(_codeFor(error.code), cause: error);
    } catch (error) {
      throw AppException(AppErrorCode.sftpFailure, cause: error);
    }
  }

  AppErrorCode _codeFor(int statusCode) => switch (statusCode) {
    SftpStatusCode.noSuchFile => AppErrorCode.sftpNotFound,
    SftpStatusCode.permissionDenied => AppErrorCode.sftpPermissionDenied,
    _ => AppErrorCode.sftpFailure,
  };
}
