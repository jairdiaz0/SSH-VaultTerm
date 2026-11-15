import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/database/database_key_store.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/security/password_hasher.dart';
import '../../../core/storage/app_paths.dart';
import '../../../shared/models/profile.dart';
import 'catalog_store.dart';

/// Creates and destroys profiles. Creation is only reachable from an unlocked
/// session at the UI layer; this service enforces the invariants regardless.
class ProfileService {
  ProfileService({
    required this.catalog,
    required this.keys,
    required this.hasher,
    required this.paths,
    this.uuid = const Uuid(),
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;

  final CatalogStore catalog;
  final DatabaseKeyStore keys;
  final PasswordHasher hasher;
  final AppPaths paths;
  final Uuid uuid;
  final DateTime Function() now;

  static const minPasswordLength = 8;
  static const maxNameLength = 64;

  List<Profile> list() => catalog.profiles.all();

  /// Creates a profile with its own database key. Never copies data from
  /// another profile.
  Future<Profile> create({
    required String name,
    required String password,
    required String passwordConfirmation,
    Argon2Params params = Argon2Params.baseline,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > maxNameLength) {
      fail(AppErrorCode.validation, cause: 'invalid profile name');
    }
    if (password.length < minPasswordLength) {
      fail(AppErrorCode.validation, cause: 'password too short');
    }
    if (password != passwordConfirmation) {
      fail(AppErrorCode.validation, cause: 'password confirmation mismatch');
    }
    if (catalog.profiles.byName(trimmed) != null) {
      fail(AppErrorCode.conflict, cause: 'profile name already exists');
    }

    final verifier = await hasher.hash(password, params: params);
    final createdAt = now();
    final profile = Profile(
      id: uuid.v4(),
      name: trimmed,
      passwordSalt: verifier.salt,
      passwordVerifier: verifier.verifier,
      kdf: 'argon2id',
      kdfParams: jsonEncode(verifier.params.toJson()),
      settings: const {'requireReauthOnEdit': false},
      isLastActive: catalog.profiles.count() == 0,
      failedAttempts: 0,
      lockoutUntil: null,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    catalog.profiles.insert(profile);
    // Materialize the key now so a freshly created profile is immediately
    // usable and so deletion always has something to remove.
    await keys.profileKey(profile.id);
    return profile;
  }

  void markLastActive(Profile profile) {
    catalog.profiles.setLastActive(profile.id, now: now());
  }

  void updateSettings(Profile profile, Map<String, Object?> settings) {
    catalog.profiles.update(
      profile.copyWith(settings: settings, updatedAt: now()),
    );
  }

  /// Removes the profile, its secrets and its database files. Secrets go first:
  /// without the key the files are unreadable even if deletion fails midway.
  Future<void> delete(Profile profile) async {
    await keys.forgetProfile(profile.id);
    catalog.profiles.delete(profile.id);
    paths.deleteProfileFiles(profile.id);
  }
}
