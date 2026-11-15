import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_client/core/errors/app_exception.dart';
import 'package:ssh_client/features/ssh/domain/ssh_error_mapper.dart';

void main() {
  group('mapSshError', () {
    test('an unreachable host maps to networkUnreachable', () {
      expect(
        mapSshError(const SocketException('Connection refused')),
        AppErrorCode.networkUnreachable,
      );
      expect(
        mapSshError(SSHSocketError(const SocketException('no route'))),
        AppErrorCode.networkUnreachable,
      );
    });

    test('timeouts map to connectionTimeout', () {
      expect(
        mapSshError(TimeoutException('slow')),
        AppErrorCode.connectionTimeout,
      );
      expect(
        mapSshError(SSHAuthAbortError('Authentication timed out')),
        AppErrorCode.connectionTimeout,
      );
      expect(
        mapSshError(SSHHandshakeError('Handshake timed out')),
        AppErrorCode.connectionTimeout,
      );
    });

    test('authentication failures never surface the server text', () {
      final code = mapSshError(SSHAuthFailError('password rejected for root'));

      expect(code, AppErrorCode.authFailed);
      expect(code.name, isNot(contains('root')));
    });

    test('other authentication aborts are connection failures', () {
      expect(
        mapSshError(SSHAuthAbortError('closed before authentication')),
        AppErrorCode.connectionFailed,
      );
      expect(
        mapSshError(SSHHandshakeError('protocol mismatch')),
        AppErrorCode.connectionFailed,
      );
    });

    test('host key errors map to a rejection', () {
      expect(
        mapSshError(SSHHostkeyError('Hostkey verification failed')),
        AppErrorCode.hostKeyRejected,
      );
    });

    test('a peer disconnect maps to connectionLost', () {
      expect(
        mapSshError(SSHDisconnectError(2, 'bye')),
        AppErrorCode.connectionLost,
      );
    });

    test('domain errors pass through unchanged', () {
      expect(
        mapSshError(
          const AppException(AppErrorCode.privateKeyPassphraseInvalid),
        ),
        AppErrorCode.privateKeyPassphraseInvalid,
      );
    });

    test('anything else is a generic connection failure', () {
      expect(
        mapSshError(StateError('unexpected')),
        AppErrorCode.connectionFailed,
      );
    });
  });
}
