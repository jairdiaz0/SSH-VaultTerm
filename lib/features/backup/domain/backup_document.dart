import 'dart:convert';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/connection.dart';
import '../../../shared/models/known_host.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/models/server_collection.dart';
import '../../connections/data/credential_service.dart';

/// Data of one profile inside a backup document.
class BackupProfileData {
  const BackupProfileData({
    required this.profileId,
    this.collections = const [],
    this.connections = const [],
    this.knownHosts = const [],
  });

  final String profileId;
  final List<ServerCollection> collections;
  final List<Connection> connections;
  final List<KnownHost> knownHosts;

  Map<String, Object?> toJson() => {
    'profileId': profileId,
    'collections': [for (final item in collections) item.toJson()],
    'connections': [for (final item in connections) item.toJson()],
    'knownHosts': [for (final item in knownHosts) item.toJson()],
  };

  static BackupProfileData fromJson(Map<String, Object?> json) =>
      BackupProfileData(
        profileId: json['profileId']! as String,
        collections: [
          for (final item in json['collections']! as List)
            ServerCollection.fromJson((item as Map).cast<String, Object?>()),
        ],
        connections: [
          for (final item in json['connections']! as List)
            Connection.fromJson((item as Map).cast<String, Object?>()),
        ],
        knownHosts: [
          for (final item in json['knownHosts']! as List)
            KnownHost.fromJson((item as Map).cast<String, Object?>()),
        ],
      );
}

/// One credential of a profile, decrypted for the export on purpose.
class BackupCredential {
  const BackupCredential({
    required this.profileId,
    required this.credentialId,
    required this.secret,
  });

  final String profileId;
  final String credentialId;
  final CredentialSecret secret;

  Map<String, Object?> toJson() => {
    'profileId': profileId,
    'credentialId': credentialId,
    'secret': secret.toJson(),
  };

  static BackupCredential fromJson(Map<String, Object?> json) =>
      BackupCredential(
        profileId: json['profileId']! as String,
        credentialId: json['credentialId']! as String,
        secret: CredentialSecret.fromJson(
          ((json['secret']! as Map).cast<String, Object?>()),
        ),
      );
}

/// Versioned, strictly parsed JSON backup.
///
/// Contains the profile verifier (salt + Argon2 params) so a restore does not
/// need the original password, but never the database master keys: those are
/// regenerated on import.
class BackupDocument {
  const BackupDocument({
    required this.formatVersion,
    required this.exportedAt,
    required this.profiles,
    required this.profileData,
    required this.credentials,
  });

  static const currentFormatVersion = 1;

  final int formatVersion;
  final DateTime exportedAt;
  final List<Profile> profiles;
  final List<BackupProfileData> profileData;
  final List<BackupCredential> credentials;

  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'profiles': [for (final profile in profiles) profile.toJson()],
    'profileData': [for (final data in profileData) data.toJson()],
    'credentials': [for (final credential in credentials) credential.toJson()],
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  static BackupDocument decode(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) failWith(AppErrorCode.backupInvalid);
      return fromJson(decoded.cast<String, Object?>());
    } on AppException {
      rethrow;
    } catch (error) {
      failWith(AppErrorCode.backupInvalid, cause: error);
    }
  }

  static BackupDocument fromJson(Map<String, Object?> json) {
    try {
      final version = json['formatVersion']! as int;
      if (version != currentFormatVersion) {
        failWith(AppErrorCode.backupVersionUnsupported, cause: 'v$version');
      }
      final document = BackupDocument(
        formatVersion: version,
        exportedAt: DateTime.parse(json['exportedAt']! as String),
        profiles: [
          for (final item in json['profiles']! as List)
            Profile.fromJson((item as Map).cast<String, Object?>()),
        ],
        profileData: [
          for (final item in json['profileData']! as List)
            BackupProfileData.fromJson((item as Map).cast<String, Object?>()),
        ],
        credentials: [
          for (final item in json['credentials']! as List)
            BackupCredential.fromJson((item as Map).cast<String, Object?>()),
        ],
      );
      document._validate();
      return document;
    } on AppException {
      rethrow;
    } catch (error) {
      failWith(AppErrorCode.backupInvalid, cause: error);
    }
  }

  BackupProfileData? dataFor(String profileId) {
    for (final data in profileData) {
      if (data.profileId == profileId) return data;
    }
    return null;
  }

  List<BackupCredential> credentialsFor(String profileId) =>
      credentials.where((item) => item.profileId == profileId).toList();

  /// Identity is the UUID: duplicated ids would make "update by id" ambiguous.
  void _validate() {
    final ids = <String>{};
    for (final profile in profiles) {
      if (!ids.add(profile.id)) {
        failWith(AppErrorCode.backupInvalid, cause: 'duplicate profile id');
      }
    }
    for (final data in profileData) {
      if (!ids.contains(data.profileId)) {
        failWith(AppErrorCode.backupInvalid, cause: 'orphan profile data');
      }
      _validateUnique(data.collections.map((item) => item.id), 'collections');
      _validateUnique(data.connections.map((item) => item.id), 'connections');
      _validateUnique(data.knownHosts.map((item) => item.id), 'knownHosts');
    }
    _validateUnique(
      credentials.map((item) => item.credentialId),
      'credentials',
    );
  }

  static void _validateUnique(Iterable<String> ids, String label) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        failWith(AppErrorCode.backupInvalid, cause: 'duplicate $label id');
      }
    }
  }
}
