import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'app/startup_failure_app.dart';
import 'app/theme/theme_controller.dart';
import 'core/errors/app_exception.dart';
import 'core/utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = AppLogger();

  // Loaded before the first frame so the app never flashes the wrong theme.
  final themeController = await ThemeController.load();

  try {
    final services = await AppServices.bootstrap(logger: logger);
    runApp(SshClientApp(services: services, themeController: themeController));
  } on AppException catch (error) {
    logger.error('startup_failed', {'code': error.code.name});
    runApp(StartupFailureApp(error: error));
  }
}
