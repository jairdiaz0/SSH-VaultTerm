import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/connection.dart';
import '../domain/ssh_connection_state.dart';
import '../domain/ssh_error_mapper.dart';

/// Result of running one remote command, with streams fully drained.
class SshCommandResult {
  const SshCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get succeeded => exitCode == 0;
}

/// One live SSH session: a single [SSHClient] per connection, with every
/// channel (shell for the terminal, SFTP) opened from it.
///
/// Nothing here caches terminal output or commands; the streams go straight to
/// their consumers.
class SshConnection {
  SshConnection({required this.connection, required this.client}) {
    client.done.then<void>(
      (_) => _handleClosed(null),
      onError: (Object error) => _handleClosed(error),
    );
  }

  static const _closeTimeout = Duration(seconds: 5);

  final Connection connection;
  final SSHClient client;

  final ValueNotifier<SshConnectionState> state = ValueNotifier(
    const SshConnectionState(SshConnectionStatus.connected),
  );

  bool _closing = false;

  String get id => connection.id;

  bool get isOpen => !client.isClosed;

  AppErrorCode? get errorCode => state.value.errorCode;

  /// Opens a remote shell with a pty, for the terminal.
  Future<SSHSession> openShell({SSHPtyConfig pty = const SSHPtyConfig()}) =>
      client.shell(pty: pty);

  /// Runs [command] and collects its output.
  ///
  /// Used by diagnostics and tests; the terminal uses [openShell]. Output is
  /// held in memory only, never written anywhere.
  Future<SshCommandResult> execute(String command, {Duration? timeout}) async {
    final session = await client.execute(command);
    final out = <int>[];
    final err = <int>[];
    final drained = Future.wait<void>([
      session.stdout.forEach(out.addAll),
      session.stderr.forEach(err.addAll),
      session.done,
    ]);
    try {
      if (timeout == null) {
        await drained;
      } else {
        await drained.timeout(timeout);
      }
    } on TimeoutException {
      session.kill(SSHSignal.KILL);
      session.close();
      rethrow;
    }
    return SshCommandResult(
      exitCode: session.exitCode ?? -1,
      stdout: utf8.decode(out, allowMalformed: true),
      stderr: utf8.decode(err, allowMalformed: true),
    );
  }

  /// Closes every channel and the transport, in that order, and reports
  /// [SshConnectionStatus.disconnected].
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    try {
      await client.close().timeout(_closeTimeout);
    } on TimeoutException {
      // A peer that never answers must not hold the app: drop the socket.
      client.socket.destroy();
    } catch (_) {
      // An already failed transport is closed enough.
    }
    state.value = SshConnectionState.disconnected;
  }

  /// Releases the notifier. The connection must be closed first.
  void dispose() => state.dispose();

  void _handleClosed(Object? error) {
    if (_closing) return;
    _closing = true;
    state.value = SshConnectionState(
      SshConnectionStatus.disconnectedUnexpectedly,
      errorCode: error == null
          ? AppErrorCode.connectionLost
          : mapSshError(error),
    );
  }
}
