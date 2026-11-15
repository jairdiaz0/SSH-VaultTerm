import '../core/database/database_key_store.dart';
import '../core/errors/app_exception.dart';
import '../core/security/password_hasher.dart';
import '../core/storage/app_paths.dart';
import '../core/storage/secret_store.dart';
import '../core/storage/secure_storage_secret_store.dart';
import '../core/utils/app_logger.dart';
import '../features/authentication/data/authentication_service.dart';
import '../features/profiles/data/catalog_store.dart';
import '../features/profiles/data/profile_service.dart';

/// Composition root: every long-lived service the UI is allowed to touch.
///
/// Widgets never build databases or secrets themselves; they receive this
/// object (production: [AppServices.bootstrap]; tests: an instance wired to a
/// temporary directory and an in-memory secret store).
class AppServices {
  AppServices({
    required this.paths,
    required this.secrets,
    required this.keys,
    required this.hasher,
    required this.catalog,
    required this.profiles,
    required this.auth,
    AppLogger? logger,
  }) : logger = logger ?? AppLogger();

  final AppPaths paths;
  final SecretStore secrets;
  final DatabaseKeyStore keys;
  final PasswordHasher hasher;
  final CatalogStore catalog;
  final ProfileService profiles;
  final AuthenticationService auth;
  final AppLogger logger;

  /// Wires the real platform storage. Throws [AppErrorCode.secureStorageUnavailable]
  /// when the OS keystore cannot be used: there is no plaintext fallback.
  static Future<AppServices> bootstrap({AppLogger? logger}) async {
    final secrets = SecureStorageSecretStore();
    if (!await secrets.isAvailable()) {
      failWith(AppErrorCode.secureStorageUnavailable);
    }
    final paths = await AppPaths.resolve();
    return fromStorage(secrets: secrets, paths: paths, logger: logger);
  }

  /// Same wiring as [bootstrap] but with injected platform pieces, so tests and
  /// bootstrap share one code path.
  static Future<AppServices> fromStorage({
    required SecretStore secrets,
    required AppPaths paths,
    AppLogger? logger,
    PasswordHasher? hasher,
  }) async {
    final keys = DatabaseKeyStore(secrets: secrets);
    final catalog = await CatalogStore.open(paths: paths, keys: keys);
    final effectiveHasher = hasher ?? PasswordHasher();
    return AppServices(
      paths: paths,
      secrets: secrets,
      keys: keys,
      hasher: effectiveHasher,
      catalog: catalog,
      profiles: ProfileService(
        catalog: catalog,
        keys: keys,
        hasher: effectiveHasher,
        paths: paths,
      ),
      auth: AuthenticationService(catalog: catalog, hasher: effectiveHasher),
      logger: logger,
    );
  }

  void dispose() => catalog.close();
}
