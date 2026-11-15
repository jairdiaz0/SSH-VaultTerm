// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'SSH Client';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get firstRunTitle => 'Crea tu primer perfil';

  @override
  String get firstRunSubtitle =>
      'La contraseña del perfil protege el acceso a la aplicación. No se puede recuperar: si la olvidas, los datos del perfil quedan inaccesibles.';

  @override
  String get profileNameLabel => 'Nombre del perfil';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get passwordConfirmLabel => 'Confirmar contraseña';

  @override
  String get createProfileAction => 'Crear perfil';

  @override
  String passwordMinLengthHint(int min) {
    return 'Mínimo $min caracteres.';
  }

  @override
  String get lockTitle => 'Desbloquear perfil';

  @override
  String lockSubtitle(String profile) {
    return 'Introduce la contraseña de $profile para continuar.';
  }

  @override
  String get unlockAction => 'Desbloquear';

  @override
  String get switchProfileAction => 'Cambiar de perfil';

  @override
  String get profileSwitcherTitle => 'Elige un perfil';

  @override
  String get homeTitle => 'Sesión desbloqueada';

  @override
  String get lockSessionAction => 'Bloquear sesión';

  @override
  String get signOutAction => 'Cerrar sesión';

  @override
  String get collectionsSection => 'Colecciones';

  @override
  String get favoritesSection => 'Favoritos';

  @override
  String get connectionsSection => 'Conexiones';

  @override
  String get emptyCollectionsMessage =>
      'Este perfil todavía no tiene colecciones.';

  @override
  String get emptyConnectionsMessage =>
      'Este perfil todavía no tiene conexiones.';

  @override
  String connectionCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conexiones',
      one: '1 conexión',
      zero: 'Sin conexiones',
    );
    return '$_temp0';
  }

  @override
  String get settingsAction => 'Ajustes';

  @override
  String get errorInvalidCredentials => 'Contraseña incorrecta.';

  @override
  String errorAccountLocked(int seconds) {
    return 'Demasiados intentos fallidos. Vuelve a intentarlo en $seconds segundos.';
  }

  @override
  String get errorPasswordMismatch => 'Las contraseñas no coinciden.';

  @override
  String errorPasswordTooShort(int min) {
    return 'La contraseña debe tener al menos $min caracteres.';
  }

  @override
  String get errorProfileNameEmpty => 'Escribe un nombre para el perfil.';

  @override
  String get errorProfileNameTaken => 'Ya existe un perfil con ese nombre.';

  @override
  String get errorValidation => 'Revisa los datos introducidos.';

  @override
  String get errorConflict => 'Ese elemento ya existe.';

  @override
  String get errorSecureStorageUnavailable =>
      'El almacén seguro del sistema no está disponible. Sin él no se pueden guardar secretos y la aplicación no puede continuar.';

  @override
  String get errorDatabaseFailure =>
      'No se pudo abrir la base de datos cifrada del perfil.';

  @override
  String get errorHostKeyRejected =>
      'No has aceptado la huella del servidor. La conexión se ha cancelado.';

  @override
  String get errorHostKeyChanged =>
      'La huella del servidor ha cambiado desde la última conexión. La conexión se ha bloqueado para protegerte. Si el cambio es legítimo, borra la huella guardada para ese servidor y vuelve a conectar.';

  @override
  String get errorAuthFailed =>
      'El servidor rechazó las credenciales. Comprueba el usuario y el método de acceso.';

  @override
  String get errorNetworkUnreachable =>
      'No se pudo alcanzar el servidor. Comprueba el host, el puerto y tu red.';

  @override
  String get errorConnectionTimeout => 'El servidor no respondió a tiempo.';

  @override
  String get errorConnectionFailed => 'No se pudo establecer la conexión SSH.';

  @override
  String get errorConnectionLost =>
      'La conexión con el servidor se interrumpió inesperadamente.';

  @override
  String get errorCredentialMissing =>
      'Esta conexión no tiene credenciales guardadas. Edita la conexión y vuelve a introducirlas.';

  @override
  String get errorPrivateKeyInvalid =>
      'La llave privada no es válida o está dañada.';

  @override
  String get errorPrivateKeyPassphraseRequired =>
      'Esta llave privada está protegida con una frase de contraseña.';

  @override
  String get errorPrivateKeyPassphraseInvalid =>
      'La frase de contraseña de la llave no es correcta.';

  @override
  String get errorPrivateKeyUnsupportedFormat =>
      'Formato de llave no soportado. Se admiten llaves OpenSSH, RSA PKCS#1 y EC SEC1.';

  @override
  String get errorUnknown => 'Ha ocurrido un error inesperado.';
}
