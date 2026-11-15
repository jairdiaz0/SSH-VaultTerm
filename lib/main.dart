import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'app/startup_failure_app.dart';
import 'app/theme/theme_controller.dart';
import 'core/database/database_key_store.dart';
import 'core/errors/app_exception.dart';
import 'core/storage/app_paths.dart';
import 'core/storage/app_reset_service.dart';
import 'core/storage/secure_storage_secret_store.dart';
import 'core/utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = AppLogger();

  // Loaded before the first frame so the app never flashes the wrong theme.
  final themeController = await ThemeController.load();

  try {
    // A reset that could not delete the catalog while it was open finishes
    // here, before anything opens it.
    final secrets = SecureStorageSecretStore();
    final paths = await AppPaths.resolve();
    if (await secrets.isAvailable()) {
      await AppResetService.applyPendingReset(
        paths: paths,
        keys: DatabaseKeyStore(secrets: secrets),
        environment: Platform.environment,
      );
    }
    final services = await AppServices.bootstrap(logger: logger);
    runApp(SshClientApp(services: services, themeController: themeController));
  } on AppException catch (error) {
    logger.error('startup_failed', {'code': error.code.name});
    runApp(StartupFailureApp(error: error));
  }
}
