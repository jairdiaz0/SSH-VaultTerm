// ignore_for_file: deprecated_member_use
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

  /// No description provided for @confirmAction.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get confirmAction;

  /// No description provided for @confirmPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'Confirma tu contraseña'**
  String get confirmPasswordTitle;

  /// No description provided for @confirmPasswordBody.
  ///
  /// In es, this message translates to:
  /// **'El perfil pide tu contraseña para continuar.'**
  String get confirmPasswordBody;

  /// No description provided for @exportPasswordBody.
  ///
  /// In es, this message translates to:
  /// **'Introduce la contraseña del perfil para leer los secretos y crear el archivo.'**
  String get exportPasswordBody;

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

  /// No description provided for @errorDatabaseKeyMismatch.
  ///
  /// In es, this message translates to:
  /// **'La clave guardada no corresponde a estos datos cifrados. Si no necesitas recuperarlos, restablece la aplicación.'**
  String get errorDatabaseKeyMismatch;

  /// No description provided for @errorDatabaseKeyOrphan.
  ///
  /// In es, this message translates to:
  /// **'Hay una clave guardada sin base de datos asociada. Restablece la aplicación para empezar de cero.'**
  String get errorDatabaseKeyOrphan;

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

  /// No description provided for @errorSftpPermissionDenied.
  ///
  /// In es, this message translates to:
  /// **'El servidor denegó el permiso para esa operación.'**
  String get errorSftpPermissionDenied;

  /// No description provided for @errorSftpNotFound.
  ///
  /// In es, this message translates to:
  /// **'La ruta remota no existe o ya no está disponible.'**
  String get errorSftpNotFound;

  /// No description provided for @errorSftpFailure.
  ///
  /// In es, this message translates to:
  /// **'El servidor rechazó la operación de archivos.'**
  String get errorSftpFailure;

  /// No description provided for @errorTransferCancelled.
  ///
  /// In es, this message translates to:
  /// **'Transferencia cancelada.'**
  String get errorTransferCancelled;

  /// No description provided for @errorTransferFailed.
  ///
  /// In es, this message translates to:
  /// **'La transferencia falló.'**
  String get errorTransferFailed;

  /// No description provided for @errorBackupInvalid.
  ///
  /// In es, this message translates to:
  /// **'El archivo de respaldo no es válido o está incompleto.'**
  String get errorBackupInvalid;

  /// No description provided for @errorBackupVersionUnsupported.
  ///
  /// In es, this message translates to:
  /// **'Este respaldo se creó con una versión más reciente de la aplicación.'**
  String get errorBackupVersionUnsupported;

  /// No description provided for @errorBackupReadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el archivo de respaldo.'**
  String get errorBackupReadFailed;

  /// No description provided for @errorBackupWriteFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo escribir el archivo de respaldo.'**
  String get errorBackupWriteFailed;

  /// No description provided for @sftpEmptyFolder.
  ///
  /// In es, this message translates to:
  /// **'Esta carpeta está vacía.'**
  String get sftpEmptyFolder;

  /// No description provided for @sftpNewFolderTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva carpeta'**
  String get sftpNewFolderTitle;

  /// No description provided for @folderNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la carpeta'**
  String get folderNameLabel;

  /// No description provided for @uploadAction.
  ///
  /// In es, this message translates to:
  /// **'Subir archivos'**
  String get uploadAction;

  /// No description provided for @downloadAction.
  ///
  /// In es, this message translates to:
  /// **'Descargar'**
  String get downloadAction;

  /// No description provided for @showHiddenAction.
  ///
  /// In es, this message translates to:
  /// **'Mostrar archivos ocultos'**
  String get showHiddenAction;

  /// No description provided for @hideHiddenAction.
  ///
  /// In es, this message translates to:
  /// **'Ocultar archivos ocultos'**
  String get hideHiddenAction;

  /// No description provided for @transferQueueTitle.
  ///
  /// In es, this message translates to:
  /// **'Transferencias'**
  String get transferQueueTitle;

  /// No description provided for @transferUploadLabel.
  ///
  /// In es, this message translates to:
  /// **'Subida'**
  String get transferUploadLabel;

  /// No description provided for @transferDownloadLabel.
  ///
  /// In es, this message translates to:
  /// **'Descarga'**
  String get transferDownloadLabel;

  /// No description provided for @transferPending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get transferPending;

  /// No description provided for @transferRunning.
  ///
  /// In es, this message translates to:
  /// **'En curso'**
  String get transferRunning;

  /// No description provided for @transferCompleted.
  ///
  /// In es, this message translates to:
  /// **'Finalizada'**
  String get transferCompleted;

  /// No description provided for @transferFailed.
  ///
  /// In es, this message translates to:
  /// **'Fallida'**
  String get transferFailed;

  /// No description provided for @transferCancelled.
  ///
  /// In es, this message translates to:
  /// **'Cancelada'**
  String get transferCancelled;

  /// No description provided for @cancelAction.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelAction;

  /// No description provided for @renameTitle.
  ///
  /// In es, this message translates to:
  /// **'Renombrar'**
  String get renameTitle;

  /// No description provided for @newNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nuevo nombre'**
  String get newNameLabel;

  /// No description provided for @sftpOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el explorador de archivos del servidor.'**
  String get sftpOpenFailed;

  /// No description provided for @sftpChooseFolderFirst.
  ///
  /// In es, this message translates to:
  /// **'Elige una carpeta de destino.'**
  String get sftpChooseFolderFirst;

  /// No description provided for @sftpFolderCreated.
  ///
  /// In es, this message translates to:
  /// **'Carpeta creada.'**
  String get sftpFolderCreated;

  /// No description provided for @sftpRenamed.
  ///
  /// In es, this message translates to:
  /// **'Elemento renombrado.'**
  String get sftpRenamed;

  /// No description provided for @sftpDeleted.
  ///
  /// In es, this message translates to:
  /// **'Elemento eliminado.'**
  String get sftpDeleted;

  /// No description provided for @sftpUploadStarted.
  ///
  /// In es, this message translates to:
  /// **'Subida en curso.'**
  String get sftpUploadStarted;

  /// No description provided for @sftpDownloadStarted.
  ///
  /// In es, this message translates to:
  /// **'Descarga en curso.'**
  String get sftpDownloadStarted;

  /// No description provided for @advancedSection.
  ///
  /// In es, this message translates to:
  /// **'Avanzado'**
  String get advancedSection;

  /// No description provided for @storageStatusAction.
  ///
  /// In es, this message translates to:
  /// **'Estado del almacenamiento'**
  String get storageStatusAction;

  /// No description provided for @storageStatusTitle.
  ///
  /// In es, this message translates to:
  /// **'Estado del almacenamiento'**
  String get storageStatusTitle;

  /// No description provided for @storageCatalogLabel.
  ///
  /// In es, this message translates to:
  /// **'Catálogo cifrado'**
  String get storageCatalogLabel;

  /// No description provided for @storageCatalogOk.
  ///
  /// In es, this message translates to:
  /// **'abre correctamente'**
  String get storageCatalogOk;

  /// No description provided for @storageCatalogKeyMissing.
  ///
  /// In es, this message translates to:
  /// **'clave ausente'**
  String get storageCatalogKeyMissing;

  /// No description provided for @storageCatalogError.
  ///
  /// In es, this message translates to:
  /// **'error: {code}'**
  String storageCatalogError(String code);

  /// No description provided for @storageProfileLabel.
  ///
  /// In es, this message translates to:
  /// **'{id} · archivo {file} · clave {key} · {state}'**
  String storageProfileLabel(String id, String file, String key, String state);

  /// No description provided for @storagePresent.
  ///
  /// In es, this message translates to:
  /// **'sí'**
  String get storagePresent;

  /// No description provided for @storageAbsent.
  ///
  /// In es, this message translates to:
  /// **'no'**
  String get storageAbsent;

  /// No description provided for @storagePendingReset.
  ///
  /// In es, this message translates to:
  /// **'Hay un restablecimiento pendiente; se completará al reiniciar.'**
  String get storagePendingReset;

  /// No description provided for @storageLegacy.
  ///
  /// In es, this message translates to:
  /// **'Se detectaron datos antiguos en Roaming. No se abren; usa Restablecer para limpiarlos.'**
  String get storageLegacy;

  /// No description provided for @resetApplicationAction.
  ///
  /// In es, this message translates to:
  /// **'Restablecer la aplicación'**
  String get resetApplicationAction;

  /// No description provided for @resetWarningTitle.
  ///
  /// In es, this message translates to:
  /// **'Restablecer la aplicación'**
  String get resetWarningTitle;

  /// No description provided for @resetWarningBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán TODOS los perfiles, conexiones, credenciales, huellas y las claves de las bases de datos. La aplicación volverá a mostrarse como recién instalada. Esta acción no se puede deshacer.'**
  String get resetWarningBody;

  /// No description provided for @resetTypeWord.
  ///
  /// In es, this message translates to:
  /// **'Escribe RESTABLECER para continuar'**
  String get resetTypeWord;

  /// No description provided for @resetWord.
  ///
  /// In es, this message translates to:
  /// **'RESTABLECER'**
  String get resetWord;

  /// No description provided for @resetConfirmAction.
  ///
  /// In es, this message translates to:
  /// **'Restablecer'**
  String get resetConfirmAction;

  /// No description provided for @resetFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo restablecer por completo. Cierra la aplicación y vuelve a abrirla; si el problema continúa, usa tool/reset_dev_data.ps1.'**
  String get resetFailed;

  /// No description provided for @backupSection.
  ///
  /// In es, this message translates to:
  /// **'Respaldos'**
  String get backupSection;

  /// No description provided for @exportBackupAction.
  ///
  /// In es, this message translates to:
  /// **'Exportar respaldo'**
  String get exportBackupAction;

  /// No description provided for @importBackupAction.
  ///
  /// In es, this message translates to:
  /// **'Importar respaldo'**
  String get importBackupAction;

  /// No description provided for @exportWarningTitle.
  ///
  /// In es, this message translates to:
  /// **'Advertencia de seguridad'**
  String get exportWarningTitle;

  /// No description provided for @exportWarningBody.
  ///
  /// In es, this message translates to:
  /// **'ADVERTENCIA DE SEGURIDAD. El archivo de respaldo contendrá información sensible, incluidas contraseñas SSH, llaves privadas y frases de contraseña. El archivo JSON NO estará cifrado ni protegido por la aplicación. Cualquier persona con acceso al archivo podría conectarse a tus servidores. Guárdalo en un lugar seguro y no lo compartas. Además incluye el verificador de la contraseña de perfil, que podría someterse a fuerza bruta.'**
  String get exportWarningBody;

  /// No description provided for @exportConfirmAction.
  ///
  /// In es, this message translates to:
  /// **'Entiendo los riesgos y quiero exportar'**
  String get exportConfirmAction;

  /// No description provided for @exportDone.
  ///
  /// In es, this message translates to:
  /// **'Respaldo exportado.'**
  String get exportDone;

  /// No description provided for @exportFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar el respaldo.'**
  String get exportFailed;

  /// No description provided for @importTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar respaldo'**
  String get importTitle;

  /// No description provided for @importSummary.
  ///
  /// In es, this message translates to:
  /// **'{profiles} perfiles · {connections} conexiones · {credentials} credenciales'**
  String importSummary(int profiles, int connections, int credentials);

  /// No description provided for @importModeMerge.
  ///
  /// In es, this message translates to:
  /// **'Fusionar'**
  String get importModeMerge;

  /// No description provided for @importModeMergeHelp.
  ///
  /// In es, this message translates to:
  /// **'Crea lo que falta y actualiza por identificador. Conserva los datos locales que no estén en el respaldo.'**
  String get importModeMergeHelp;

  /// No description provided for @importModeReplaceProfile.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar un perfil'**
  String get importModeReplaceProfile;

  /// No description provided for @importModeReplaceAll.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar todos'**
  String get importModeReplaceAll;

  /// No description provided for @importReplaceWarning.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán los perfiles actuales antes de importar. La sesión se bloqueará.'**
  String get importReplaceWarning;

  /// No description provided for @importTargetProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil a reemplazar'**
  String get importTargetProfile;

  /// No description provided for @importConfirmAction.
  ///
  /// In es, this message translates to:
  /// **'Importar'**
  String get importConfirmAction;

  /// No description provided for @importDone.
  ///
  /// In es, this message translates to:
  /// **'Respaldo importado.'**
  String get importDone;

  /// No description provided for @importFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar el respaldo. No se ha cambiado nada.'**
  String get importFailed;

  /// No description provided for @connectionTypeLabel.
  ///
  /// In es, this message translates to:
  /// **'Tipo de conexión'**
  String get connectionTypeLabel;

  /// No description provided for @connectionTypeSsh.
  ///
  /// In es, this message translates to:
  /// **'SSH · terminal'**
  String get connectionTypeSsh;

  /// No description provided for @connectionTypeSftp.
  ///
  /// In es, this message translates to:
  /// **'SFTP · archivos'**
  String get connectionTypeSftp;

  /// No description provided for @refreshAction.
  ///
  /// In es, this message translates to:
  /// **'Refrescar'**
  String get refreshAction;

  /// No description provided for @backAction.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get backAction;

  /// No description provided for @forwardAction.
  ///
  /// In es, this message translates to:
  /// **'Adelante'**
  String get forwardAction;

  /// No description provided for @upOneLevelAction.
  ///
  /// In es, this message translates to:
  /// **'Subir un nivel'**
  String get upOneLevelAction;

  /// No description provided for @moreActions.
  ///
  /// In es, this message translates to:
  /// **'Más acciones'**
  String get moreActions;

  /// No description provided for @sessionEndedTitle.
  ///
  /// In es, this message translates to:
  /// **'Sesión finalizada'**
  String get sessionEndedTitle;

  /// No description provided for @sessionEndedBody.
  ///
  /// In es, this message translates to:
  /// **'El shell remoto ha terminado. Puedes reconectar o cerrar la sesión.'**
  String get sessionEndedBody;

  /// No description provided for @sessionEndedUnexpected.
  ///
  /// In es, this message translates to:
  /// **'La conexión se interrumpió de forma inesperada.'**
  String get sessionEndedUnexpected;

  /// No description provided for @closeWorkspaceAction.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get closeWorkspaceAction;

  /// No description provided for @connectionStatusConnected.
  ///
  /// In es, this message translates to:
  /// **'Conectado'**
  String get connectionStatusConnected;

  /// No description provided for @connectionStatusConnecting.
  ///
  /// In es, this message translates to:
  /// **'Conectando…'**
  String get connectionStatusConnecting;

  /// No description provided for @connectionStatusDisconnected.
  ///
  /// In es, this message translates to:
  /// **'Desconectado'**
  String get connectionStatusDisconnected;

  /// No description provided for @connectionStatusFailed.
  ///
  /// In es, this message translates to:
  /// **'Error de conexión'**
  String get connectionStatusFailed;

  /// No description provided for @newConnectionAction.
  ///
  /// In es, this message translates to:
  /// **'Nueva conexión'**
  String get newConnectionAction;

  /// No description provided for @newCollectionAction.
  ///
  /// In es, this message translates to:
  /// **'Nueva colección'**
  String get newCollectionAction;

  /// No description provided for @editAction.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get editAction;

  /// No description provided for @deleteAction.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get deleteAction;

  /// No description provided for @renameAction.
  ///
  /// In es, this message translates to:
  /// **'Renombrar'**
  String get renameAction;

  /// No description provided for @moveUpAction.
  ///
  /// In es, this message translates to:
  /// **'Subir'**
  String get moveUpAction;

  /// No description provided for @moveDownAction.
  ///
  /// In es, this message translates to:
  /// **'Bajar'**
  String get moveDownAction;

  /// No description provided for @addToFavoritesAction.
  ///
  /// In es, this message translates to:
  /// **'Añadir a favoritos'**
  String get addToFavoritesAction;

  /// No description provided for @removeFromFavoritesAction.
  ///
  /// In es, this message translates to:
  /// **'Quitar de favoritos'**
  String get removeFromFavoritesAction;

  /// No description provided for @emptySidebarHint.
  ///
  /// In es, this message translates to:
  /// **'Crea una colección y añade tu primer servidor.'**
  String get emptySidebarHint;

  /// No description provided for @sidebarServersSection.
  ///
  /// In es, this message translates to:
  /// **'Servidores'**
  String get sidebarServersSection;

  /// No description provided for @connectionFormNewTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva conexión'**
  String get connectionFormNewTitle;

  /// No description provided for @connectionFormEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar conexión'**
  String get connectionFormEditTitle;

  /// No description provided for @connectionNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get connectionNameLabel;

  /// No description provided for @connectionHostLabel.
  ///
  /// In es, this message translates to:
  /// **'Host o IP'**
  String get connectionHostLabel;

  /// No description provided for @connectionPortLabel.
  ///
  /// In es, this message translates to:
  /// **'Puerto'**
  String get connectionPortLabel;

  /// No description provided for @connectionUserLabel.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get connectionUserLabel;

  /// No description provided for @authMethodLabel.
  ///
  /// In es, this message translates to:
  /// **'Método de acceso'**
  String get authMethodLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get authPasswordLabel;

  /// No description provided for @authPrivateKeyLabel.
  ///
  /// In es, this message translates to:
  /// **'Llave privada'**
  String get authPrivateKeyLabel;

  /// No description provided for @privateKeyImportAction.
  ///
  /// In es, this message translates to:
  /// **'Importar llave…'**
  String get privateKeyImportAction;

  /// No description provided for @privateKeyLoaded.
  ///
  /// In es, this message translates to:
  /// **'Llave {type} cargada.'**
  String privateKeyLoaded(String type);

  /// No description provided for @privateKeyLoadedEncrypted.
  ///
  /// In es, this message translates to:
  /// **'Llave {type} cifrada cargada.'**
  String privateKeyLoadedEncrypted(String type);

  /// No description provided for @passphraseLabel.
  ///
  /// In es, this message translates to:
  /// **'Frase de contraseña de la llave'**
  String get passphraseLabel;

  /// No description provided for @passphraseOptionalHint.
  ///
  /// In es, this message translates to:
  /// **'Déjala vacía si la llave no está protegida.'**
  String get passphraseOptionalHint;

  /// No description provided for @descriptionLabel.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get descriptionLabel;

  /// No description provided for @collectionLabel.
  ///
  /// In es, this message translates to:
  /// **'Colección'**
  String get collectionLabel;

  /// No description provided for @noCollectionOption.
  ///
  /// In es, this message translates to:
  /// **'Sin colección'**
  String get noCollectionOption;

  /// No description provided for @favoriteLabel.
  ///
  /// In es, this message translates to:
  /// **'Favorito'**
  String get favoriteLabel;

  /// No description provided for @saveAction.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get saveAction;

  /// No description provided for @passwordKeepHint.
  ///
  /// In es, this message translates to:
  /// **'Déjala vacía para conservar la guardada.'**
  String get passwordKeepHint;

  /// No description provided for @fieldRequired.
  ///
  /// In es, this message translates to:
  /// **'Este campo es obligatorio.'**
  String get fieldRequired;

  /// No description provided for @invalidHost.
  ///
  /// In es, this message translates to:
  /// **'Escribe un host o una dirección IP, sin esquema ni barras.'**
  String get invalidHost;

  /// No description provided for @invalidPort.
  ///
  /// In es, this message translates to:
  /// **'El puerto debe estar entre 1 y 65535.'**
  String get invalidPort;

  /// No description provided for @credentialRequired.
  ///
  /// In es, this message translates to:
  /// **'Introduce una contraseña o importa una llave.'**
  String get credentialRequired;

  /// No description provided for @connectionSaved.
  ///
  /// In es, this message translates to:
  /// **'Conexión guardada.'**
  String get connectionSaved;

  /// No description provided for @connectionDeleted.
  ///
  /// In es, this message translates to:
  /// **'Conexión eliminada.'**
  String get connectionDeleted;

  /// No description provided for @collectionNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la colección'**
  String get collectionNameLabel;

  /// No description provided for @collectionFormNewTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva colección'**
  String get collectionFormNewTitle;

  /// No description provided for @collectionFormEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Renombrar colección'**
  String get collectionFormEditTitle;

  /// No description provided for @collectionDeletedConnectionsKept.
  ///
  /// In es, this message translates to:
  /// **'Colección eliminada. Sus conexiones siguen disponibles sin colección.'**
  String get collectionDeletedConnectionsKept;

  /// No description provided for @confirmDeleteConnection.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar «{name}»? También se borrará su credencial guardada.'**
  String confirmDeleteConnection(String name);

  /// No description provided for @confirmDeleteCollection.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar «{name}»? Las conexiones no se borran.'**
  String confirmDeleteCollection(String name);

  /// No description provided for @hostKeyDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Huella del servidor'**
  String get hostKeyDialogTitle;

  /// No description provided for @hostKeyUnknownBody.
  ///
  /// In es, this message translates to:
  /// **'Es la primera conexión a {host}. Comprueba que la huella coincide con la del servidor antes de aceptar.'**
  String hostKeyUnknownBody(String host);

  /// No description provided for @hostKeyFingerprintLabel.
  ///
  /// In es, this message translates to:
  /// **'Huella SHA-256'**
  String get hostKeyFingerprintLabel;

  /// No description provided for @hostKeyKeyTypeLabel.
  ///
  /// In es, this message translates to:
  /// **'Tipo de clave'**
  String get hostKeyKeyTypeLabel;

  /// No description provided for @hostKeyAcceptAction.
  ///
  /// In es, this message translates to:
  /// **'Confiar y conectar'**
  String get hostKeyAcceptAction;

  /// No description provided for @hostKeyChangedTitle.
  ///
  /// In es, this message translates to:
  /// **'La huella del servidor ha cambiado'**
  String get hostKeyChangedTitle;

  /// No description provided for @hostKeyChangedBody.
  ///
  /// In es, this message translates to:
  /// **'La huella guardada para {host} no coincide con la que presenta ahora. Puede ser un ataque de intermediario, así que la conexión se ha bloqueado.'**
  String hostKeyChangedBody(String host);

  /// No description provided for @hostKeyForgetAction.
  ///
  /// In es, this message translates to:
  /// **'Borrar huella guardada'**
  String get hostKeyForgetAction;

  /// No description provided for @hostKeyForgotten.
  ///
  /// In es, this message translates to:
  /// **'Huella borrada. Vuelve a conectar para confirmar la nueva.'**
  String get hostKeyForgotten;

  /// No description provided for @workspaceEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin sesión'**
  String get workspaceEmptyTitle;

  /// No description provided for @workspaceEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Elige un servidor en la barra lateral para abrir una terminal.'**
  String get workspaceEmptyBody;

  /// No description provided for @terminalTab.
  ///
  /// In es, this message translates to:
  /// **'Terminal'**
  String get terminalTab;

  /// No description provided for @filesTab.
  ///
  /// In es, this message translates to:
  /// **'Archivos'**
  String get filesTab;

  /// No description provided for @disconnectAction.
  ///
  /// In es, this message translates to:
  /// **'Desconectar'**
  String get disconnectAction;

  /// No description provided for @reconnectAction.
  ///
  /// In es, this message translates to:
  /// **'Reconectar'**
  String get reconnectAction;

  /// No description provided for @maximizePanelAction.
  ///
  /// In es, this message translates to:
  /// **'Maximizar panel'**
  String get maximizePanelAction;

  /// No description provided for @restoreSplitAction.
  ///
  /// In es, this message translates to:
  /// **'Restaurar división'**
  String get restoreSplitAction;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @securitySection.
  ///
  /// In es, this message translates to:
  /// **'Seguridad'**
  String get securitySection;

  /// No description provided for @knownHostsTitle.
  ///
  /// In es, this message translates to:
  /// **'Huellas conocidas'**
  String get knownHostsTitle;

  /// No description provided for @knownHostsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay huellas guardadas en este perfil.'**
  String get knownHostsEmpty;

  /// No description provided for @knownHostsEntry.
  ///
  /// In es, this message translates to:
  /// **'{host}:{port} · {type}'**
  String knownHostsEntry(String host, int port, String type);

  /// No description provided for @profileSection.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profileSection;

  /// No description provided for @appearanceSection.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get appearanceSection;

  /// No description provided for @themeLabel.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @terminalAlwaysDark.
  ///
  /// In es, this message translates to:
  /// **'Terminal siempre oscura'**
  String get terminalAlwaysDark;

  /// No description provided for @terminalAlwaysDarkHelp.
  ///
  /// In es, this message translates to:
  /// **'Usa la paleta oscura del terminal aunque la interfaz esté en claro.'**
  String get terminalAlwaysDarkHelp;

  /// No description provided for @manageProfilesAction.
  ///
  /// In es, this message translates to:
  /// **'Gestionar perfiles'**
  String get manageProfilesAction;

  /// No description provided for @profilesTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfiles'**
  String get profilesTitle;

  /// No description provided for @currentProfileLabel.
  ///
  /// In es, this message translates to:
  /// **'Perfil activo'**
  String get currentProfileLabel;

  /// No description provided for @deleteProfileAction.
  ///
  /// In es, this message translates to:
  /// **'Eliminar perfil'**
  String get deleteProfileAction;

  /// No description provided for @confirmDeleteProfile.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar el perfil «{name}»? Se borrarán sus conexiones, huellas y credenciales, y no se puede deshacer.'**
  String confirmDeleteProfile(String name);

  /// No description provided for @profilePasswordPrompt.
  ///
  /// In es, this message translates to:
  /// **'Contraseña del perfil «{name}»'**
  String profilePasswordPrompt(String name);

  /// No description provided for @profileCreated.
  ///
  /// In es, this message translates to:
  /// **'Perfil creado.'**
  String get profileCreated;

  /// No description provided for @profileDeleted.
  ///
  /// In es, this message translates to:
  /// **'Perfil eliminado.'**
  String get profileDeleted;

  /// No description provided for @requireReauthLabel.
  ///
  /// In es, this message translates to:
  /// **'Requerir contraseña al editar'**
  String get requireReauthLabel;

  /// No description provided for @requireReauthHelp.
  ///
  /// In es, this message translates to:
  /// **'Pide la contraseña del perfil al guardar conexiones o credenciales.'**
  String get requireReauthHelp;

  /// No description provided for @reauthPromptTitle.
  ///
  /// In es, this message translates to:
  /// **'Confirma tu contraseña'**
  String get reauthPromptTitle;

  /// No description provided for @reauthPromptBody.
  ///
  /// In es, this message translates to:
  /// **'Este perfil pide la contraseña antes de guardar cambios en conexiones o credenciales.'**
  String get reauthPromptBody;

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
