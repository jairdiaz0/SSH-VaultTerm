import '../../../core/errors/app_exception.dart';
import '../../../core/security/password_hasher.dart';
import '../../../shared/models/profile.dart';
import '../../profiles/data/catalog_store.dart';
import '../domain/lockout_policy.dart';

/// Local unlock: verifier only, generic failure message, persistent progressive
/// delay. It never derives a key from the password.
class AuthenticationService {
  AuthenticationService({
    required this.catalog,
    required this.hasher,
    this.policy = const LockoutPolicy(),
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;

  final CatalogStore catalog;
  final PasswordHasher hasher;
  final LockoutPolicy policy;
  final DateTime Function() now;

  List<Profile> profiles() => catalog.profiles.all();

  bool get hasProfiles => catalog.profiles.count() > 0;

  Profile? lastActiveProfile() => catalog.profiles.lastActive();

  /// Unlocks [profileId] with [password].
  ///
  /// Throws [AppErrorCode.invalidCredentials] for a wrong password (the caller
  /// must show a generic message) and [AppErrorCode.accountLocked] while a
  /// progressive delay is in force.
  Future<Profile> unlock({
    required String profileId,
    required String password,
  }) async {
    final profile = catalog.profiles.byId(profileId);
    if (profile == null) {
      fail(AppErrorCode.notFound, cause: 'profile not found');
    }
    final at = now();
    if (policy.isLocked(profile.lockoutUntil, at)) {
      fail(AppErrorCode.accountLocked);
    }

    final ok = await hasher.verify(password, profile.toPasswordVerifier());
    if (!ok) {
      final attempts = profile.failedAttempts + 1;
      final delay = policy.delayFor(attempts);
      catalog.profiles.recordFailedAttempt(
        profile.id,
        failedAttempts: attempts,
        now: at,
        lockoutUntil: delay == Duration.zero ? null : at.add(delay),
      );
      fail(AppErrorCode.invalidCredentials);
    }

    catalog.profiles.clearFailures(profile.id, now: at);
    catalog.profiles.setLastActive(profile.id, now: at);
    return catalog.profiles.byId(profile.id)!;
  }

  /// Re-checks the password for a sensitive action without unlocking again and
  /// without touching lockout counters (the session is already authenticated).
  Future<bool> confirmPassword({
    required String profileId,
    required String password,
  }) async {
    final profile = catalog.profiles.byId(profileId);
    if (profile == null) return false;
    return hasher.verify(password, profile.toPasswordVerifier());
  }
}
