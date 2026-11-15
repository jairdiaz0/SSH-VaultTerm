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

/// Owns the active session of one workspace: SSH connection plus its terminal.
///
/// A workspace holds at most one connection. [open] closes the previous one
/// first, so switching servers never leaks a socket or a pty. Nothing here
/// retains commands or output after [close].
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

  /// Connects and opens the terminal. Errors are reflected in [status] and
  /// [errorCode] instead of thrown, so the workspace can render them.
  Future<void> open(
    Connection connection, {
    required HostKeyConfirmation confirmHostKey,
  }) async {
    await close();
    _connection = connection;
    _errorCode = null;
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
              notifyListeners();
            },
          );
      _ssh = ssh;
      ssh.state.addListener(_onSshState);

      final terminal = await RemoteTerminal.open(ssh);
      _terminal = terminal;

      try {
        final sftp = SftpController(gateway: await SftpService.open(ssh));
        await sftp.initialize();
        _sftp = sftp;
      } catch (error) {
        // The terminal must survive a server without the SFTP subsystem.
        _sftpErrorCode = error is AppException
            ? error.code
            : AppErrorCode.sftpFailure;
      }
      _setStatus(SshConnectionStatus.connected);
    } catch (error) {
      _errorCode = error is AppException ? error.code : mapSshError(error);
      _terminal = null;
      final ssh = _ssh;
      _ssh = null;
      if (ssh != null) {
        ssh.state.removeListener(_onSshState);
        await ssh.close();
        ssh.dispose();
      }
      _setStatus(SshConnectionStatus.failed);
    }
  }

  /// Closes the terminal, SFTP and the SSH session. The selected server stays,
  /// so the user can reconnect from the same panel.
  Future<void> close() async {
    final sftp = _sftp;
    _sftp = null;
    _sftpErrorCode = null;
    sftp?.dispose();
    final terminal = _terminal;
    _terminal = null;
    if (terminal != null) {
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
    if (_status != SshConnectionStatus.failed) {
      _setStatus(SshConnectionStatus.disconnected);
    }
  }

  void _onSshState() {
    final current = _ssh?.state.value;
    if (current == null) return;
    _status = current.status;
    _errorCode = current.errorCode;
    notifyListeners();
  }

  void _setStatus(SshConnectionStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    final ssh = _ssh;
    if (ssh != null) {
      ssh.state.removeListener(_onSshState);
      unawaited(ssh.close());
    }
    _terminal?.dispose();
    super.dispose();
  }
}
