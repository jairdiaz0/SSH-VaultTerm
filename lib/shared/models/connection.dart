import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

enum AuthenticationType {
  password,
  privateKey;

  static AuthenticationType fromStorage(String value) => switch (value) {
    'password' => AuthenticationType.password,
    'privateKey' => AuthenticationType.privateKey,
    _ => throw ArgumentError.value(value, 'value', 'unknown auth type'),
  };
}

/// One server. Serves both the terminal and the SFTP browser.
///
/// [credentialId] points into the secret store; the SQLite row never contains a
/// password or a private key.
class Connection {
  const Connection({
    required this.id,
    this.collectionId,
    required this.name,
    required this.hostname,
    required this.port,
    required this.username,
    required this.authType,
    this.credentialId,
    this.description,
    this.tags = const <String>[],
    this.favorite = false,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? collectionId;
  final String name;
  final String hostname;
  final int port;
  final String username;
  final AuthenticationType authType;
  final String? credentialId;
  final String? description;
  final List<String> tags;
  final bool favorite;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toRow() => {
    'id': id,
    'collection_id': collectionId,
    'name': name,
    'hostname': hostname,
    'port': port,
    'username': username,
    'auth_type': authType.name,
    'credential_id': credentialId,
    'description': description,
    'tags': jsonEncode(tags),
    'favorite': favorite ? 1 : 0,
    'position': position,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  static Connection fromRow(Row row) => Connection(
    id: row['id'] as String,
    collectionId: row['collection_id'] as String?,
    name: row['name'] as String,
    hostname: row['hostname'] as String,
    port: row['port'] as int,
    username: row['username'] as String,
    authType: AuthenticationType.fromStorage(row['auth_type'] as String),
    credentialId: row['credential_id'] as String?,
    description: row['description'] as String?,
    tags: (jsonDecode(row['tags'] as String) as List).cast<String>(),
    favorite: (row['favorite'] as int) == 1,
    position: row['position'] as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'collectionId': collectionId,
    'name': name,
    'hostname': hostname,
    'port': port,
    'username': username,
    'authType': authType.name,
    'credentialId': credentialId,
    'description': description,
    'tags': tags,
    'favorite': favorite,
    'position': position,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static Connection fromJson(Map<String, Object?> json) => Connection(
    id: json['id']! as String,
    collectionId: json['collectionId'] as String?,
    name: json['name']! as String,
    hostname: json['hostname']! as String,
    port: json['port']! as int,
    username: json['username']! as String,
    authType: AuthenticationType.fromStorage(json['authType']! as String),
    credentialId: json['credentialId'] as String?,
    description: json['description'] as String?,
    tags: (json['tags']! as List).cast<String>(),
    favorite: json['favorite']! as bool,
    position: json['position']! as int,
    createdAt: DateTime.parse(json['createdAt']! as String),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
  );

  Connection copyWith({
    String? collectionId,
    String? name,
    String? hostname,
    int? port,
    String? username,
    AuthenticationType? authType,
    String? credentialId,
    String? description,
    List<String>? tags,
    bool? favorite,
    int? position,
    DateTime? updatedAt,
  }) => Connection(
    id: id,
    collectionId: collectionId ?? this.collectionId,
    name: name ?? this.name,
    hostname: hostname ?? this.hostname,
    port: port ?? this.port,
    username: username ?? this.username,
    authType: authType ?? this.authType,
    credentialId: credentialId ?? this.credentialId,
    description: description ?? this.description,
    tags: tags ?? this.tags,
    favorite: favorite ?? this.favorite,
    position: position ?? this.position,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
