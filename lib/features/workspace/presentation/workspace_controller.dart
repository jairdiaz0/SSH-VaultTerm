import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../../../app/app_services.dart';
import '../../../app/profile_session.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/models/connection.dart';
import '../../sftp/data/sftp_service.dart';
import '../../sftp/presentation/sftp_controller.dart';
import '../../ssh/data/ssh_connection.dart';
import '../../ssh/domain/host_key_verifier.dart';
import '../../ssh/domain/ssh_connection_state.dart';
import '../../ssh/domain/ssh_error_mapper.dart';
import '../../terminal/data/remote_terminal.dart';

/// Owns the active session of one workspace.
///
/// A connection is either a terminal (SSH) or a file explorer (SFTP): the
/// workspace shows only that view. [open] closes the previous session first, so
/// switching servers never leaks a socket, a pty or an SFTP channel.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController({required this.services, required this.session});

  final AppServices services;
  final ProfileSession session;

  Connection? _connection;
  SshConnection? _ssh;
  RemoteTerminal? _terminal;
  SftpController? _sftp;
  SshConnectionStatus _status = SshConnectionStatus.disconnected;
  AppErrorCode? _errorCode;
  AppErrorCode? _sftpErrorCode;
  HostKeyChallenge? _lastChallenge;
  bool _disposed = false;

  Connection? get connection => _connection;
  SshConnection? get ssh => _ssh;
  Terminal? get terminal => _terminal?.terminal;
  SftpController? get sftp => _sftp;
  SshConnectionStatus get status => _status;
  AppErrorCode? get errorCode => _errorCode;

  /// Set when the SSH connection works but the SFTP subsystem did not open.
  AppErrorCode? get sftpErrorCode => _sftpErrorCode;

  /// Last host key challenge presented, for diagnostics and tests.
  HostKeyChallenge? get lastChallenge => _lastChallenge;

  bool get isBusy =>
      _status == SshConnectionStatus.connecting ||
      _status == SshConnectionStatus.awaitingHostKey ||
      _status == SshConnectionStatus.authenticating;

  bool get isConnected => _status == SshConnectionStatus.connected;

  /// True when the session is over but the panel still offers reconnect/close.
  bool get hasEnded =>
      _status == SshConnectionStatus.sessionEnded ||
      _status == SshConnectionStatus.disconnectedUnexpectedly;

  /// Connects and opens the view of [connection]. Errors are reflected in
  /// [status] and [errorCode] instead of thrown, so the workspace can render them.
  Future<void> open(
    Connection connection, {
    required HostKeyConfirmation confirmHostKey,
  }) async {
    await close();
    _connection = connection;
    _errorCode = null;
    _sftpErrorCode = null;
    _setStatus(SshConnectionStatus.connecting);

    try {
      final ssh = await services
          .sshFor(session)
          .connect(
            connection,
            confirmHostKey: (challenge) {
              _lastChallenge = challenge;
              return confirmHostKey(challenge);
            },
            onProgress: (state) {
              _status = state.status;
              _errorCode = state.errorCode;
              _notify();
            },
          );
      _ssh = ssh;
      ssh.state.addListener(_onSshState);

      switch (connection.connectionType) {
        case ConnectionType.ssh:
          final terminal = await RemoteTerminal.open(ssh);
          _terminal = terminal;
          terminal.exitCode.addListener(_onTerminalExit);
          // The pty may end before the listener is installed.
          if (terminal.exitCode.value != null) {
            unawaited(_endSession());
            return;
          }
        case ConnectionType.sftp:
          final sftp = SftpController(gateway: await SftpService.open(ssh));
          await sftp.initialize();
          _sftp = sftp;
          if (sftp.errorCode != null) {
            failWith(sftp.errorCode!);
          }
      }
      _setStatus(SshConnectionStatus.connected);
    } catch (error) {
      _errorCode = error is AppException ? error.code : mapSshError(error);
      await _releaseResources();
      _setStatus(SshConnectionStatus.failed);
    }
  }

  /// Closes the current view and the SSH session. The selected server stays,
  /// so the user can reconnect from the same panel.
  Future<void> close() async {
    await _releaseResources();
    if (_status != SshConnectionStatus.failed) {
      _setStatus(SshConnectionStatus.disconnected);
    }
  }

  /// Leaves the ended session behind and returns to the empty workspace.
  void dismiss() {
    _connection = null;
    _errorCode = null;
    _sftpErrorCode = null;
    _setStatus(SshConnectionStatus.disconnected);
  }

  /// Sends a raw key sequence through the terminal channel.
  void sendTerminal(String data) => _terminal?.send(data);

  Future<void> _releaseResources() async {
    final sftp = _sftp;
    _sftp = null;
    _sftpErrorCode = null;
    sftp?.dispose();

    final terminal = _terminal;
    _terminal = null;
    if (terminal != null) {
      terminal.exitCode.removeListener(_onTerminalExit);
      await terminal.close();
      terminal.dispose();
    }

    final ssh = _ssh;
    _ssh = null;
    if (ssh != null) {
      ssh.state.removeListener(_onSshState);
      await ssh.close();
      ssh.dispose();
    }
  }

  /// The remote shell exited or its channel closed: nothing else uses the SSH
  /// client, so release it and let the panel offer reconnect or close.
  Future<void> _endSession() async {
    if (_status == SshConnectionStatus.sessionEnded) return;
    await _releaseResources();
    _errorCode = null;
    _setStatus(SshConnectionStatus.sessionEnded);
  }

  void _onTerminalExit() {
    final exitCode = _terminal?.exitCode.value;
    if (exitCode == null) return;
    unawaited(_endSession());
  }

  void _onSshState() {
    final current = _ssh?.state.value;
    if (current == null) return;
    _status = current.status;
    _errorCode = current.errorCode;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  void _setStatus(SshConnectionStatus status) {
    _status = status;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _terminal?.exitCode.removeListener(_onTerminalExit);
    unawaited(_releaseResources());
    super.dispose();
  }
}
