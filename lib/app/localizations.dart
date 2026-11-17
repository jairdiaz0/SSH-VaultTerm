import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';

/// Delegates for the app, built on the Material/Cupertino UI packages.
///
/// The generated `AppLocalizations.localizationsDelegates` still references the
/// deprecated `flutter_localizations` aliases, whose types do not satisfy the
/// Material widgets of `material_ui`, so the app and the tests share this list.
final appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];
