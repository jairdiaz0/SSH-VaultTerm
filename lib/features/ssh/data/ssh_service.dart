import 'dart:async';

import 'package:dartssh2/dartssh2.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../../../shared/models/connection.dart';
import '../../connections/data/credential_service.dart';
import '../domain/host_key_verifier.dart';
import '../domain/private_key_inspector.dart';
import '../domain/ssh_connection_state.dart';
import '../domain/ssh_error_mapper.dart';
import 'known_host_repository.dart';
import 'ssh_connection.dart';

/// Opens a TCP socket to an SSH server. Injected so tests can simulate
/// unreachable hosts without touching the network.
typedef SshSocketOpener = Future<SSHSocket> Function(
  String host,
  int port, {
  Duration? timeout,
});

Future<SSHSocket> _connectSocket(String host, int port, {Duration? timeout}) =>
    SSHSocket.connect(host, port, timeout: timeout);

typedef SshProgress = void Function(SshConnectionState state);

/// Opens SSH sessions for one unlocked profile.
///
/// Credentials are read from the secret store only when a connection starts;
/// host keys are verified through [TofuHostKeyVerifier] and persisted in the
/// profile database. Nothing here logs a secret, a command or terminal output.
class SshService {
  SshService({
    required this.profileId,
    required this.credentials,
    required this.knownHosts,
    required this.logger,
    SshSocketOpener? openSocket,
    this.connectTimeout = const Duration(seconds: 20),
    this.handshakeTimeout = const Duration(seconds: 20),
    this.authTimeout = const Duration(seconds: 30),
    this.keepAliveInterval = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : _openSocket = openSocket ?? _connectSocket,
       _clock = clock ?? DateTime.now;

  final String profileId;
  final CredentialService credentials;
  final KnownHostRepository knownHosts;
  final AppLogger logger;

  final Duration connectTimeout;
  final Duration handshakeTimeout;
  final Duration authTimeout;
  final Duration keepAliveInterval;

  final SshSocketOpener _openSocket;
  final DateTime Function() _clock;

  /// Connects and authenticates, reporting every state through [onProgress].
  ///
  /// [confirmHostKey] is mandatory: an unknown host key must be confirmed by the
  /// user, and a changed one is refused without asking. Throws an
  /// [AppException] whose code is safe to display; the returned connection is
  /// already authenticated.
  Future<SshConnection> connect(
    Connection connection, {
    required HostKeyConfirmation confirmHostKey,
    SshProgress? onProgress,
  }) async {
    final credentialId = connection.credentialId;
    if (credentialId == null || credentialId.isEmpty) {
      failWith(AppErrorCode.credentialMissing, cause: 'no credential id');
    }
    final secret = await credentials.load(
      profileId: profileId,
      credentialId: credentialId,
    );
    if (secret == null || secret.isEmpty) {
      failWith(AppErrorCode.credentialMissing, cause: 'no stored secret');
    }

    final material = _authMaterial(connection, secret);
    final verifier = TofuHostKeyVerifier(
      connectionId: connection.id,
      hostname: connection.hostname,
      port: connection.port,
      knownHosts: knownHosts,
      confirm: _progressHostKey(onProgress, confirmHostKey),
      clock: _clock,
    );

    onProgress?.call(const SshConnectionState(SshConnectionStatus.connecting));

    SSHClient? client;
    try {
      final socket = await _openSocket(
        connection.hostname,
        connection.port,
        timeout: connectTimeout,
      );
      final created = SSHClient(
        socket,
        username: connection.username,
        onVerifyHostKey: (keyType, fingerprint) async {
          final accepted = await verifier.verify(keyType, fingerprint);
          if (accepted) {
            onProgress?.call(
              const SshConnectionState(SshConnectionStatus.authenticating),
            );
          }
          return accepted;
        },
        identities: material.identities,
        onPasswordRequest: material.password == null
            ? null
            : () => material.password,
        keepAliveInterval: keepAliveInterval,
        handshakeTimeout: handshakeTimeout,
        authTimeout: authTimeout,
        // Host key verification is never disabled: dartssh2's own default is
        // false and the app keeps it that way on purpose.
      );
      client = created;
      await created.authenticated;
    } catch (error, stackTrace) {
      try {
        await client?.close();
      } catch (_) {
        // Best effort: the error below is the one the caller must see.
      }
      final code = verifier.lastAccepted == false
          ? (verifier.status == HostKeyStatus.changed
                ? AppErrorCode.hostKeyChanged
                : AppErrorCode.hostKeyRejected)
          : mapSshError(error);
      logger.warning('ssh.connect.failed', {
        'connection': connection.id,
        'code': code.name,
      });
      onProgress?.call(
        SshConnectionState(SshConnectionStatus.failed, errorCode: code),
      );
      throw AppException(code, cause: error, stackTrace: stackTrace);
    }

    logger.info('ssh.connected', {
      'connection': connection.id,
      'host': connection.hostname,
      'port': connection.port,
    });
    onProgress?.call(const SshConnectionState(SshConnectionStatus.connected));
    return SshConnection(connection: connection, client: client);
  }

  HostKeyConfirmation _progressHostKey(
    SshProgress? onProgress,
    HostKeyConfirmation confirm,
  ) {
    return (challenge) async {
      onProgress?.call(
        const SshConnectionState(SshConnectionStatus.awaitingHostKey),
      );
      try {
        return await confirm(challenge);
      } catch (_) {
        // A prompt that blows up (window closed, for instance) is a refusal,
        // never an implicit acceptance.
        return false;
      }
    };
  }

  ({List<SSHKeyPair>? identities, String? password}) _authMaterial(
    Connection connection,
    CredentialSecret secret,
  ) {
    switch (connection.authType) {
      case AuthenticationType.password:
        final password = secret.password;
        if (password == null || password.isEmpty) {
          failWith(AppErrorCode.credentialMissing, cause: 'no password');
        }
        return (identities: null, password: password);
      case AuthenticationType.privateKey:
        final pem = secret.privateKeyPem;
        if (pem == null || pem.isEmpty) {
          failWith(AppErrorCode.credentialMissing, cause: 'no private key');
        }
        return (
          identities: PrivateKeyInspector.decode(
            pem,
            passphrase: secret.passphrase,
          ),
          password: null,
        );
    }
  }
}
