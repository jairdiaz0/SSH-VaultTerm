import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../../core/security/password_hasher.dart';

/// A local profile. Holds only the password *verifier*, never the password.
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.passwordSalt,
    required this.passwordVerifier,
    required this.kdf,
    required this.kdfParams,
    required this.settings,
    required this.isLastActive,
    required this.failedAttempts,
    required this.lockoutUntil,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<int> passwordSalt;
  final List<int> passwordVerifier;
  final String kdf;
  final String kdfParams;
  final Map<String, Object?> settings;
  final bool isLastActive;
  final int failedAttempts;
  final DateTime? lockoutUntil;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Parameters used to derive [passwordVerifier], so they can be upgraded.
  Argon2Params get argon2Params =>
      Argon2Params.fromJson(jsonDecode(kdfParams) as Map<String, Object?>);

  PasswordVerifier toPasswordVerifier() => PasswordVerifier(
    salt: Uint8List.fromList(passwordSalt),
    verifier: Uint8List.fromList(passwordVerifier),
    params: argon2Params,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'name_normalized': normalizeName(name),
    'password_salt': passwordSalt,
    'password_verifier': passwordVerifier,
    'kdf': kdf,
    'kdf_params': kdfParams,
    'settings': jsonEncode(settings),
    'is_last_active': isLastActive ? 1 : 0,
    'failed_attempts': failedAttempts,
    'lockout_until': lockoutUntil?.millisecondsSinceEpoch,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  static Profile fromRow(Row row) => Profile(
    id: row['id'] as String,
    name: row['name'] as String,
    passwordSalt: row['password_salt'] as List<int>,
    passwordVerifier: row['password_verifier'] as List<int>,
    kdf: row['kdf'] as String,
    kdfParams: row['kdf_params'] as String,
    settings: jsonDecode(row['settings'] as String) as Map<String, Object?>,
    isLastActive: (row['is_last_active'] as int) == 1,
    failedAttempts: row['failed_attempts'] as int,
    lockoutUntil: row['lockout_until'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['lockout_until'] as int),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
  );

  /// Serialization used by JSON backups (never contains the profile password:
  /// only its salt and verifier, as the database stores them).
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'passwordSalt': base64Encode(passwordSalt),
    'passwordVerifier': base64Encode(passwordVerifier),
    'kdf': kdf,
    'kdfParams': kdfParams,
    'settings': settings,
    'isLastActive': isLastActive,
    'failedAttempts': failedAttempts,
    'lockoutUntil': lockoutUntil?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static Profile fromJson(Map<String, Object?> json) => Profile(
    id: json['id']! as String,
    name: json['name']! as String,
    passwordSalt: base64Decode(json['passwordSalt']! as String),
    passwordVerifier: base64Decode(json['passwordVerifier']! as String),
    kdf: json['kdf']! as String,
    kdfParams: json['kdfParams']! as String,
    settings: (json['settings']! as Map).cast<String, Object?>(),
    isLastActive: json['isLastActive']! as bool,
    failedAttempts: json['failedAttempts']! as int,
    lockoutUntil: json['lockoutUntil'] == null
        ? null
        : DateTime.parse(json['lockoutUntil']! as String),
    createdAt: DateTime.parse(json['createdAt']! as String),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
  );

  Profile copyWith({
    String? name,
    Map<String, Object?>? settings,
    bool? isLastActive,
    int? failedAttempts,
    DateTime? lockoutUntil,
    bool clearLockout = false,
    DateTime? updatedAt,
  }) => Profile(
    id: id,
    name: name ?? this.name,
    passwordSalt: passwordSalt,
    passwordVerifier: passwordVerifier,
    kdf: kdf,
    kdfParams: kdfParams,
    settings: settings ?? this.settings,
    isLastActive: isLastActive ?? this.isLastActive,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockoutUntil: clearLockout ? null : (lockoutUntil ?? this.lockoutUntil),
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Case-insensitive uniqueness without locale surprises.
  static String normalizeName(String value) => value.trim().toLowerCase();
}
