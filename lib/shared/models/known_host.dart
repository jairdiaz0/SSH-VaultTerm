import 'package:sqlite3/sqlite3.dart';

/// A host key the user explicitly accepted for a connection (TOFU).
class KnownHost {
  const KnownHost({
    required this.id,
    required this.connectionId,
    required this.hostname,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    required this.createdAt,
  });

  final String id;
  final String connectionId;
  final String hostname;
  final int port;

  /// OpenSSH key type, e.g. `ssh-ed25519`, `ssh-rsa`, `ecdsa-sha2-nistp256`.
  final String keyType;

  /// OpenSSH-style `SHA256:<base64>` fingerprint.
  final String fingerprint;
  final DateTime createdAt;

  Map<String, Object?> toRow() => {
    'id': id,
    'connection_id': connectionId,
    'hostname': hostname,
    'port': port,
    'key_type': keyType,
    'fingerprint': fingerprint,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static KnownHost fromRow(Row row) => KnownHost(
    id: row['id'] as String,
    connectionId: row['connection_id'] as String,
    hostname: row['hostname'] as String,
    port: row['port'] as int,
    keyType: row['key_type'] as String,
    fingerprint: row['fingerprint'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'connectionId': connectionId,
    'hostname': hostname,
    'port': port,
    'keyType': keyType,
    'fingerprint': fingerprint,
    'createdAt': createdAt.toIso8601String(),
  };

  static KnownHost fromJson(Map<String, Object?> json) => KnownHost(
    id: json['id']! as String,
    connectionId: json['connectionId']! as String,
    hostname: json['hostname']! as String,
    port: json['port']! as int,
    keyType: json['keyType']! as String,
    fingerprint: json['fingerprint']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
  );

  /// True when [presented] is the stored fingerprint.
  bool matches(String presented) => fingerprint == presented;
}
