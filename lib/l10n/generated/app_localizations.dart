import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'SSH Client'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get commonRetry;

  /// No description provided for @firstRunTitle.
  ///
  /// In es, this message translates to:
  /// **'Crea tu primer perfil'**
  String get firstRunTitle;

  /// No description provided for @firstRunSubtitle.
  ///
  /// In es, this message translates to:
  /// **'La contraseña del perfil protege el acceso a la aplicación. No se puede recuperar: si la olvidas, los datos del perfil quedan inaccesibles.'**
  String get firstRunSubtitle;

  /// No description provided for @profileNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre del perfil'**
  String get profileNameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get passwordLabel;

  /// No description provided for @passwordConfirmLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get passwordConfirmLabel;

  /// No description provided for @createProfileAction.
  ///
  /// In es, this message translates to:
  /// **'Crear perfil'**
  String get createProfileAction;

  /// No description provided for @passwordMinLengthHint.
  ///
  /// In es, this message translates to:
  /// **'Mínimo {min} caracteres.'**
  String passwordMinLengthHint(int min);

  /// No description provided for @lockTitle.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear perfil'**
  String get lockTitle;

  /// No description provided for @lockSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Introduce la contraseña de {profile} para continuar.'**
  String lockSubtitle(String profile);

  /// No description provided for @unlockAction.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear'**
  String get unlockAction;

  /// No description provided for @switchProfileAction.
  ///
  /// In es, this message translates to:
  /// **'Cambiar de perfil'**
  String get switchProfileAction;

  /// No description provided for @profileSwitcherTitle.
  ///
  /// In es, this message translates to:
  /// **'Elige un perfil'**
  String get profileSwitcherTitle;

  /// No description provided for @homeTitle.
  ///
  /// In es, this message translates to:
  /// **'Sesión desbloqueada'**
  String get homeTitle;

  /// No description provided for @lockSessionAction.
  ///
  /// In es, this message translates to:
  /// **'Bloquear sesión'**
  String get lockSessionAction;

  /// No description provided for @signOutAction.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get signOutAction;

  /// No description provided for @collectionsSection.
  ///
  /// In es, this message translates to:
  /// **'Colecciones'**
  String get collectionsSection;

  /// No description provided for @favoritesSection.
  ///
  /// In es, this message translates to:
  /// **'Favoritos'**
  String get favoritesSection;

  /// No description provided for @connectionsSection.
  ///
  /// In es, this message translates to:
  /// **'Conexiones'**
  String get connectionsSection;

  /// No description provided for @emptyCollectionsMessage.
  ///
  /// In es, this message translates to:
  /// **'Este perfil todavía no tiene colecciones.'**
  String get emptyCollectionsMessage;

  /// No description provided for @emptyConnectionsMessage.
  ///
  /// In es, this message translates to:
  /// **'Este perfil todavía no tiene conexiones.'**
  String get emptyConnectionsMessage;

  /// No description provided for @connectionCountLabel.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin conexiones} =1{1 conexión} other{{count} conexiones}}'**
  String connectionCountLabel(int count);

  /// No description provided for @settingsAction.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsAction;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In es, this message translates to:
  /// **'Contraseña incorrecta.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorAccountLocked.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos fallidos. Vuelve a intentarlo en {seconds} segundos.'**
  String errorAccountLocked(int seconds);

  /// No description provided for @errorPasswordMismatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden.'**
  String get errorPasswordMismatch;

  /// No description provided for @errorPasswordTooShort.
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe tener al menos {min} caracteres.'**
  String errorPasswordTooShort(int min);

  /// No description provided for @errorProfileNameEmpty.
  ///
  /// In es, this message translates to:
  /// **'Escribe un nombre para el perfil.'**
  String get errorProfileNameEmpty;

  /// No description provided for @errorProfileNameTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya existe un perfil con ese nombre.'**
  String get errorProfileNameTaken;

  /// No description provided for @errorValidation.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos introducidos.'**
  String get errorValidation;

  /// No description provided for @errorConflict.
  ///
  /// In es, this message translates to:
  /// **'Ese elemento ya existe.'**
  String get errorConflict;

  /// No description provided for @errorSecureStorageUnavailable.
  ///
  /// In es, this message translates to:
  /// **'El almacén seguro del sistema no está disponible. Sin él no se pueden guardar secretos y la aplicación no puede continuar.'**
  String get errorSecureStorageUnavailable;

  /// No description provided for @errorDatabaseFailure.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la base de datos cifrada del perfil.'**
  String get errorDatabaseFailure;

  /// No description provided for @errorHostKeyRejected.
  ///
  /// In es, this message translates to:
  /// **'No has aceptado la huella del servidor. La conexión se ha cancelado.'**
  String get errorHostKeyRejected;

  /// No description provided for @errorHostKeyChanged.
  ///
  /// In es, this message translates to:
  /// **'La huella del servidor ha cambiado desde la última conexión. La conexión se ha bloqueado para protegerte. Si el cambio es legítimo, borra la huella guardada para ese servidor y vuelve a conectar.'**
  String get errorHostKeyChanged;

  /// No description provided for @errorAuthFailed.
  ///
  /// In es, this message translates to:
  /// **'El servidor rechazó las credenciales. Comprueba el usuario y el método de acceso.'**
  String get errorAuthFailed;

  /// No description provided for @errorNetworkUnreachable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo alcanzar el servidor. Comprueba el host, el puerto y tu red.'**
  String get errorNetworkUnreachable;

  /// No description provided for @errorConnectionTimeout.
  ///
  /// In es, this message translates to:
  /// **'El servidor no respondió a tiempo.'**
  String get errorConnectionTimeout;

  /// No description provided for @errorConnectionFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo establecer la conexión SSH.'**
  String get errorConnectionFailed;

  /// No description provided for @errorConnectionLost.
  ///
  /// In es, this message translates to:
  /// **'La conexión con el servidor se interrumpió inesperadamente.'**
  String get errorConnectionLost;

  /// No description provided for @errorCredentialMissing.
  ///
  /// In es, this message translates to:
  /// **'Esta conexión no tiene credenciales guardadas. Edita la conexión y vuelve a introducirlas.'**
  String get errorCredentialMissing;

  /// No description provided for @errorPrivateKeyInvalid.
  ///
  /// In es, this message translates to:
  /// **'La llave privada no es válida o está dañada.'**
  String get errorPrivateKeyInvalid;

  /// No description provided for @errorPrivateKeyPassphraseRequired.
  ///
  /// In es, this message translates to:
  /// **'Esta llave privada está protegida con una frase de contraseña.'**
  String get errorPrivateKeyPassphraseRequired;

  /// No description provided for @errorPrivateKeyPassphraseInvalid.
  ///
  /// In es, this message translates to:
  /// **'La frase de contraseña de la llave no es correcta.'**
  String get errorPrivateKeyPassphraseInvalid;

  /// No description provided for @errorPrivateKeyUnsupportedFormat.
  ///
  /// In es, this message translates to:
  /// **'Formato de llave no soportado. Se admiten llaves OpenSSH, RSA PKCS#1 y EC SEC1.'**
  String get errorPrivateKeyUnsupportedFormat;

  /// No description provided for @errorUnknown.
  ///
  /// In es, this message translates to:
  /// **'Ha ocurrido un error inesperado.'**
  String get errorUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
