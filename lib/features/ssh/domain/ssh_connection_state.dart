import '../../../core/errors/app_exception.dart';

/// Lifecycle of one SSH connection, in the order the user sees it.
enum SshConnectionStatus {
  disconnected,

  /// Opening the TCP socket and running the transport handshake.
  connecting,

  /// The server presented a host key and the user must confirm it.
  awaitingHostKey,

  /// Host key accepted; authenticating the user.
  authenticating,
  connected,

  /// The peer or the network closed a connection the user did not close.
  disconnectedUnexpectedly,

  /// The attempt failed; nothing is open.
  failed,
}

/// Immutable snapshot of a connection attempt or session.
///
/// Carries only a code, never a message: the UI translates it, so no
/// server-supplied text (banners, MOTDs) can reach the screen through here.
class SshConnectionState {
  const SshConnectionState(this.status, {this.errorCode});

  static const disconnected = SshConnectionState(
    SshConnectionStatus.disconnected,
  );

  final SshConnectionStatus status;
  final AppErrorCode? errorCode;

  bool get isConnected => status == SshConnectionStatus.connected;

  bool get isTerminal =>
      status == SshConnectionStatus.disconnected ||
      status == SshConnectionStatus.disconnectedUnexpectedly ||
      status == SshConnectionStatus.failed;

  SshConnectionState copyWith({
    SshConnectionStatus? status,
    AppErrorCode? errorCode,
  }) => SshConnectionState(
    status ?? this.status,
    errorCode: errorCode ?? this.errorCode,
  );

  @override
  String toString() =>
      'SshConnectionState(${status.name}'
      '${errorCode == null ? '' : ', ${errorCode!.name}'})';

  @override
  bool operator ==(Object other) =>
      other is SshConnectionState &&
      other.status == status &&
      other.errorCode == errorCode;

  @override
  int get hashCode => Object.hash(status, errorCode);
}
