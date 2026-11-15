import '../../../core/errors/app_exception.dart';
import '../../profiles/data/catalog_store.dart';
import 'authentication_service.dart';

/// Changes to security-related profile settings, guarded by the profile password.
///
/// Living in the service layer means no widget can flip the reauthentication
/// switch without proving the password: the update and the proof happen in the
/// same call, and a wrong password leaves the stored setting untouched.
class SecuritySettingsService {
  SecuritySettingsService({
    required this.catalog,
    required this.auth,
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;

  final CatalogStore catalog;
  final AuthenticationService auth;
  final DateTime Function() now;

  static const requireReauthKey = 'requireReauthOnEdit';

  Future<void> setRequireReauthOnEdit({
    required String profileId,
    required bool value,
    required String password,
  }) async {
    await auth.verifyForSensitiveAction(
      profileId: profileId,
      password: password,
    );
    final profile = catalog.profiles.byId(profileId);
    if (profile == null) {
      failWith(AppErrorCode.notFound, cause: 'profile not found');
    }
    catalog.profiles.update(
      profile.copyWith(
        settings: {...profile.settings, requireReauthKey: value},
        updatedAt: now(),
      ),
    );
  }
}
