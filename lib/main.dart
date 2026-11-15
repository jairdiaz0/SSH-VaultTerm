import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'app/startup_failure_app.dart';
import 'core/errors/app_exception.dart';
import 'core/utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = AppLogger();

  try {
    final services = await AppServices.bootstrap(logger: logger);
    runApp(SshClientApp(services: services));
  } on AppException catch (error) {
    logger.error('startup_failed', {'code': error.code.name});
    runApp(StartupFailureApp(error: error));
  }
}
