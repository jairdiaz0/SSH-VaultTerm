import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../../../core/errors/app_exception.dart';

/// Translates an SSH/network failure into a domain code.
///
/// Library messages are never propagated: a server banner, a MOTD or a peer
/// disconnect reason could contain anything, including something the server
/// wants the user to see. Only the error type and two stable timeout markers
/// are inspected here. Host-key refusals are decided by the caller, which knows
/// what the user answered.
AppErrorCode mapSshError(Object error) {
  if (error is AppException) return error.code;

  return _mapCode(error);
}

AppErrorCode _mapCode(Object error) {
  if (error is TimeoutException) return AppErrorCode.connectionTimeout;
  if (error is SocketException) return AppErrorCode.networkUnreachable;

  if (error is SSHHostkeyError) return AppErrorCode.hostKeyRejected;
  if (error is SSHAuthFailError) return AppErrorCode.authFailed;
  if (error is SSHAuthAbortError) {
    if (_isTimeout(error.message)) return AppErrorCode.connectionTimeout;
    if (error.reason is SSHSocketError) return AppErrorCode.networkUnreachable;
    return AppErrorCode.connectionFailed;
  }
  if (error is SSHHandshakeError) {
    return _isTimeout(error.message)
        ? AppErrorCode.connectionTimeout
        : AppErrorCode.connectionFailed;
  }
  if (error is SSHSocketError) return AppErrorCode.networkUnreachable;
  if (error is SSHDisconnectError) return AppErrorCode.connectionLost;
  if (error is SSHError) return AppErrorCode.connectionFailed;
  return AppErrorCode.connectionFailed;
}

bool _isTimeout(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('timed out') || normalized.contains('timeout');
}
