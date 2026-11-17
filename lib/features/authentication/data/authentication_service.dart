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
    final profile = await _verifyWithLockout(
      profileId: profileId,
      password: password,
    );
    catalog.profiles.setLastActive(profile.id, now: now());
    return catalog.profiles.byId(profile.id)!;
  }

  /// Re-checks the password for a sensitive action (changing a security setting,
  /// exporting a backup) with the same persistent progressive lockout as unlock.
  ///
  /// Throws [AppErrorCode.invalidCredentials] on a wrong password and
  /// [AppErrorCode.accountLocked] while a delay is in force. Never caches the
  /// password and never unlocks the session again.
  Future<void> verifyForSensitiveAction({
    required String profileId,
    required String password,
  }) => _verifyWithLockout(profileId: profileId, password: password);

  Future<Profile> _verifyWithLockout({
    required String profileId,
    required String password,
  }) async {
    final profile = catalog.profiles.byId(profileId);
    if (profile == null) {
      failWith(AppErrorCode.notFound, cause: 'profile not found');
    }
    final at = now();
    if (policy.isLocked(profile.lockoutUntil, at)) {
      failWith(AppErrorCode.accountLocked);
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
      failWith(AppErrorCode.invalidCredentials);
    }

    catalog.profiles.clearFailures(profile.id, now: at);
    return catalog.profiles.byId(profile.id)!;
  }

  /// Time left before [profileId] accepts attempts again. Used by the UI to
  /// explain the wait without exposing the stored counters.
  Duration lockoutRemaining(String profileId) {
    final until = catalog.profiles.byId(profileId)?.lockoutUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
