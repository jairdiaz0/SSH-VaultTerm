import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../shared/models/known_host.dart';
import '../data/known_host_repository.dart';

/// How a presented host key relates to what the profile already trusts.
enum HostKeyStatus {
  /// No fingerprint stored for this connection yet.
  untrusted,

  /// The presented fingerprint matches the stored one.
  trusted,

  /// A different fingerprint is stored: the connection must be blocked.
  changed,
}

/// What the user is being asked to confirm.
///
/// [fingerprint] is OpenSSH-style `SHA256:<base64>`, exactly what
/// `ssh-keygen -lf` prints, so it can be compared out of band.
class HostKeyChallenge {
  const HostKeyChallenge({
    required this.hostname,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    required this.status,
    this.trustedFingerprint,
  });

  final String hostname;
  final int port;
  final String keyType;
  final String fingerprint;
  final HostKeyStatus status;

  /// The fingerprint already stored, when [status] is [HostKeyStatus.changed].
  final String? trustedFingerprint;

  bool get isChanged => status == HostKeyStatus.changed;
}

/// Asks the user to accept an unknown host key. Returning false cancels.
typedef HostKeyConfirmation = Future<bool> Function(HostKeyChallenge challenge);

/// Trust-on-first-use verifier wired into `SSHClient.onVerifyHostKey`.
///
/// The rules are strict on purpose:
/// - a stored and matching fingerprint continues without asking again;
/// - an unknown fingerprint is asked once and only stored when accepted;
/// - a different fingerprint is never presented as a choice and never
///   overwritten: the connection fails, because an automatic prompt is how
///   man-in-the-middle attacks get accepted.
class TofuHostKeyVerifier {
  TofuHostKeyVerifier({
    required this.connectionId,
    required this.hostname,
    required this.port,
    required this.knownHosts,
    required this.confirm,
    this.uuid = const Uuid(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String connectionId;
  final String hostname;
  final int port;
  final KnownHostRepository knownHosts;
  final HostKeyConfirmation confirm;
  final Uuid uuid;
  final DateTime Function() _clock;

  HostKeyStatus? _status;
  HostKeyChallenge? _lastChallenge;
  bool? _lastAccepted;

  /// Outcome of the last [verify] call, or null before the first one.
  HostKeyStatus? get status => _status;

  /// Whether the last verification was accepted, refused, or still pending.
  ///
  /// Lets the caller tell a user refusal apart from a network failure that
  /// happened while the confirmation dialog was open.
  bool? get lastAccepted => _lastAccepted;

  /// The challenge last shown (or refused) to the user.
  HostKeyChallenge? get lastChallenge => _lastChallenge;

  /// Signature expected by `SSHClient.onVerifyHostKey`.
  Future<bool> verify(String keyType, Uint8List fingerprintBytes) async {
    final fingerprint = utf8.decode(fingerprintBytes, allowMalformed: true);
    final stored = knownHosts.find(
      connectionId: connectionId,
      hostname: hostname,
      port: port,
    );

    if (stored != null) {
      if (stored.matches(fingerprint)) {
        _status = HostKeyStatus.trusted;
        _lastAccepted = true;
        return true;
      }
      _status = HostKeyStatus.changed;
      _lastAccepted = false;
      _lastChallenge = HostKeyChallenge(
        hostname: hostname,
        port: port,
        keyType: keyType,
        fingerprint: fingerprint,
        status: HostKeyStatus.changed,
        trustedFingerprint: stored.fingerprint,
      );
      return false;
    }

    _status = HostKeyStatus.untrusted;
    final challenge = HostKeyChallenge(
      hostname: hostname,
      port: port,
      keyType: keyType,
      fingerprint: fingerprint,
      status: HostKeyStatus.untrusted,
    );
    _lastChallenge = challenge;

    if (!await confirm(challenge)) {
      _lastAccepted = false;
      return false;
    }

    knownHosts.accept(
      KnownHost(
        id: uuid.v4(),
        connectionId: connectionId,
        hostname: hostname,
        port: port,
        keyType: keyType,
        fingerprint: fingerprint,
        createdAt: _clock(),
      ),
    );
    _status = HostKeyStatus.trusted;
    _lastAccepted = true;
    return true;
  }
}
