import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/security/password_hasher.dart';
import '../features/authentication/data/authentication_service.dart';
import '../shared/models/profile.dart';
import 'app_services.dart';
import 'profile_session.dart';

/// Owns the locked/unlocked state of the app and the single open profile
/// session.
///
/// Rules enforced here (not only in the UI):
/// - a profile is only created from an unlocked session, except the very first
///   one, which is the documented first-run exception;
/// - unlocking opens exactly one profile database, closing any previous one;
/// - locking closes the database so the key and the data leave memory.
class SessionController extends ChangeNotifier {
  SessionController({
    required this.services,
    this.createParams = Argon2Params.baseline,
  });

  final AppServices services;

  /// Argon2 cost used when creating a profile. Tests pass cheap parameters.
  final Argon2Params createParams;

  ProfileSession? _session;
  Profile? _profile;
  bool _disposed = false;

  ProfileSession? get session => _session;
  Profile? get profile => _profile;
  bool get isUnlocked => _session != null;
  bool get hasProfiles => services.auth.hasProfiles;
  List<Profile> get profiles => services.auth.profiles();
  Profile? get lastActiveProfile => services.auth.lastActiveProfile();
  AuthenticationService get auth => services.auth;

  /// First-run wizard: allowed only while the catalog has no profiles.
  Future<Profile> createFirstProfile({
    required String name,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (hasProfiles) {
      failWith(AppErrorCode.conflict, cause: 'profiles already exist');
    }
    return createProfile(
      name: name,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
  }

  /// Creates an additional profile. Requires an unlocked session.
  Future<Profile> createProfile({
    required String name,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (hasProfiles && !isUnlocked) {
      failWith(AppErrorCode.validation, cause: 'unlocked session required');
    }
    final created = await services.profiles.create(
      name: name,
      password: password,
      passwordConfirmation: passwordConfirmation,
      params: createParams,
    );
    await _enter(created);
    return created;
  }

  Future<void> unlock({
    required String profileId,
    required String password,
  }) async {
    final unlocked = await services.auth.unlock(
      profileId: profileId,
      password: password,
    );
    await _enter(unlocked);
  }

  Future<void> _enter(Profile profile) async {
    _session?.close();
    final opened = await ProfileSession.open(
      profile: profile,
      paths: services.paths,
      keys: services.keys,
    );
    _session = opened;
    _profile = profile;
    _notify();
  }

  /// Closes the profile database. The app is locked afterwards.
  Future<void> lock() async {
    final open = _session;
    _session = null;
    _profile = null;
    open?.close();
    _notify();
  }

  /// Deletes a profile and every secret it owns. Deleting the open profile
  /// locks the app first so no handle survives.
  Future<void> deleteProfile(Profile profile) async {
    if (_profile?.id == profile.id) {
      await lock();
    }
    await services.profiles.delete(profile);
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session?.close();
    _session = null;
    _profile = null;
    super.dispose();
  }
}
