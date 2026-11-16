// ignore_for_file: deprecated_member_use

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
  String get confirmAction => 'Confirmar';

  @override
  String get confirmPasswordTitle => 'Confirma tu contraseña';

  @override
  String get confirmPasswordBody =>
      'El perfil pide tu contraseña para continuar.';

  @override
  String get exportPasswordBody =>
      'Introduce la contraseña del perfil para leer los secretos y crear el archivo.';

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
  String get errorDatabaseKeyMismatch =>
      'La clave guardada no corresponde a estos datos cifrados. Si no necesitas recuperarlos, restablece la aplicación.';

  @override
  String get errorDatabaseKeyOrphan =>
      'Hay una clave guardada sin base de datos asociada. Restablece la aplicación para empezar de cero.';

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
  String get errorSftpPermissionDenied =>
      'El servidor denegó el permiso para esa operación.';

  @override
  String get errorSftpNotFound =>
      'La ruta remota no existe o ya no está disponible.';

  @override
  String get errorSftpFailure =>
      'El servidor rechazó la operación de archivos.';

  @override
  String get errorTransferCancelled => 'Transferencia cancelada.';

  @override
  String get errorTransferFailed => 'La transferencia falló.';

  @override
  String get errorBackupInvalid =>
      'El archivo de respaldo no es válido o está incompleto.';

  @override
  String get errorBackupVersionUnsupported =>
      'Este respaldo se creó con una versión más reciente de la aplicación.';

  @override
  String get errorBackupReadFailed => 'No se pudo leer el archivo de respaldo.';

  @override
  String get errorBackupWriteFailed =>
      'No se pudo escribir el archivo de respaldo.';

  @override
  String get sftpEmptyFolder => 'Esta carpeta está vacía.';

  @override
  String get sftpNewFolderTitle => 'Nueva carpeta';

  @override
  String get folderNameLabel => 'Nombre de la carpeta';

  @override
  String get uploadAction => 'Subir archivos';

  @override
  String get downloadAction => 'Descargar';

  @override
  String get showHiddenAction => 'Mostrar archivos ocultos';

  @override
  String get hideHiddenAction => 'Ocultar archivos ocultos';

  @override
  String get transferQueueTitle => 'Transferencias';

  @override
  String get transferUploadLabel => 'Subida';

  @override
  String get transferDownloadLabel => 'Descarga';

  @override
  String get transferPending => 'Pendiente';

  @override
  String get transferRunning => 'En curso';

  @override
  String get transferCompleted => 'Finalizada';

  @override
  String get transferFailed => 'Fallida';

  @override
  String get transferCancelled => 'Cancelada';

  @override
  String get cancelAction => 'Cancelar';

  @override
  String get renameTitle => 'Renombrar';

  @override
  String get newNameLabel => 'Nuevo nombre';

  @override
  String get sftpOpenFailed =>
      'No se pudo abrir el explorador de archivos del servidor.';

  @override
  String get sftpChooseFolderFirst => 'Elige una carpeta de destino.';

  @override
  String get sftpFolderCreated => 'Carpeta creada.';

  @override
  String get sftpRenamed => 'Elemento renombrado.';

  @override
  String get sftpDeleted => 'Elemento eliminado.';

  @override
  String get sftpUploadStarted => 'Subida en curso.';

  @override
  String get sftpDownloadStarted => 'Descarga en curso.';

  @override
  String get advancedSection => 'Avanzado';

  @override
  String get storageStatusAction => 'Estado del almacenamiento';

  @override
  String get storageStatusTitle => 'Estado del almacenamiento';

  @override
  String get storageCatalogLabel => 'Catálogo cifrado';

  @override
  String get storageCatalogOk => 'abre correctamente';

  @override
  String get storageCatalogKeyMissing => 'clave ausente';

  @override
  String storageCatalogError(String code) {
    return 'error: $code';
  }

  @override
  String storageProfileLabel(String id, String file, String key, String state) {
    return '$id · archivo $file · clave $key · $state';
  }

  @override
  String get storagePresent => 'sí';

  @override
  String get storageAbsent => 'no';

  @override
  String get storagePendingReset =>
      'Hay un restablecimiento pendiente; se completará al reiniciar.';

  @override
  String get storageLegacy =>
      'Se detectaron datos antiguos en Roaming. No se abren; usa Restablecer para limpiarlos.';

  @override
  String get resetApplicationAction => 'Restablecer la aplicación';

  @override
  String get resetWarningTitle => 'Restablecer la aplicación';

  @override
  String get resetWarningBody =>
      'Se borrarán TODOS los perfiles, conexiones, credenciales, huellas y las claves de las bases de datos. La aplicación volverá a mostrarse como recién instalada. Esta acción no se puede deshacer.';

  @override
  String get resetTypeWord => 'Escribe RESTABLECER para continuar';

  @override
  String get resetWord => 'RESTABLECER';

  @override
  String get resetConfirmAction => 'Restablecer';

  @override
  String get resetFailed =>
      'No se pudo restablecer por completo. Cierra la aplicación y vuelve a abrirla; si el problema continúa, usa tool/reset_dev_data.ps1.';

  @override
  String get backupSection => 'Respaldos';

  @override
  String get exportBackupAction => 'Exportar respaldo';

  @override
  String get importBackupAction => 'Importar respaldo';

  @override
  String get exportWarningTitle => 'Advertencia de seguridad';

  @override
  String get exportWarningBody =>
      'ADVERTENCIA DE SEGURIDAD. El archivo de respaldo contendrá información sensible, incluidas contraseñas SSH, llaves privadas y frases de contraseña. El archivo JSON NO estará cifrado ni protegido por la aplicación. Cualquier persona con acceso al archivo podría conectarse a tus servidores. Guárdalo en un lugar seguro y no lo compartas. Además incluye el verificador de la contraseña de perfil, que podría someterse a fuerza bruta.';

  @override
  String get exportConfirmAction => 'Entiendo los riesgos y quiero exportar';

  @override
  String get exportDone => 'Respaldo exportado.';

  @override
  String get exportFailed => 'No se pudo exportar el respaldo.';

  @override
  String get importTitle => 'Importar respaldo';

  @override
  String importSummary(int profiles, int connections, int credentials) {
    return '$profiles perfiles · $connections conexiones · $credentials credenciales';
  }

  @override
  String get importModeMerge => 'Fusionar';

  @override
  String get importModeMergeHelp =>
      'Crea lo que falta y actualiza por identificador. Conserva los datos locales que no estén en el respaldo.';

  @override
  String get importModeReplaceProfile => 'Reemplazar un perfil';

  @override
  String get importModeReplaceAll => 'Reemplazar todos';

  @override
  String get importReplaceWarning =>
      'Se borrarán los perfiles actuales antes de importar. La sesión se bloqueará.';

  @override
  String get importTargetProfile => 'Perfil a reemplazar';

  @override
  String get importConfirmAction => 'Importar';

  @override
  String get importDone => 'Respaldo importado.';

  @override
  String get importFailed =>
      'No se pudo importar el respaldo. No se ha cambiado nada.';

  @override
  String get connectionTypeLabel => 'Tipo de conexión';

  @override
  String get connectionTypeSsh => 'SSH · terminal';

  @override
  String get connectionTypeSftp => 'SFTP · archivos';

  @override
  String get refreshAction => 'Refrescar';

  @override
  String get backAction => 'Atrás';

  @override
  String get forwardAction => 'Adelante';

  @override
  String get upOneLevelAction => 'Subir un nivel';

  @override
  String get moreActions => 'Más acciones';

  @override
  String get sessionEndedTitle => 'Sesión finalizada';

  @override
  String get sessionEndedBody =>
      'El shell remoto ha terminado. Puedes reconectar o cerrar la sesión.';

  @override
  String get sessionEndedUnexpected =>
      'La conexión se interrumpió de forma inesperada.';

  @override
  String get closeWorkspaceAction => 'Cerrar sesión';

  @override
  String get connectionStatusConnected => 'Conectado';

  @override
  String get connectionStatusConnecting => 'Conectando…';

  @override
  String get connectionStatusDisconnected => 'Desconectado';

  @override
  String get connectionStatusFailed => 'Error de conexión';

  @override
  String get newConnectionAction => 'Nueva conexión';

  @override
  String get newCollectionAction => 'Nueva colección';

  @override
  String get editAction => 'Editar';

  @override
  String get deleteAction => 'Eliminar';

  @override
  String get renameAction => 'Renombrar';

  @override
  String get moveUpAction => 'Subir';

  @override
  String get moveDownAction => 'Bajar';

  @override
  String get addToFavoritesAction => 'Añadir a favoritos';

  @override
  String get removeFromFavoritesAction => 'Quitar de favoritos';

  @override
  String get emptySidebarHint =>
      'Crea una colección y añade tu primer servidor.';

  @override
  String get sidebarServersSection => 'Servidores';

  @override
  String get connectionFormNewTitle => 'Nueva conexión';

  @override
  String get connectionFormEditTitle => 'Editar conexión';

  @override
  String get connectionNameLabel => 'Nombre';

  @override
  String get connectionHostLabel => 'Host o IP';

  @override
  String get connectionPortLabel => 'Puerto';

  @override
  String get connectionUserLabel => 'Usuario';

  @override
  String get authMethodLabel => 'Método de acceso';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authPrivateKeyLabel => 'Llave privada';

  @override
  String get privateKeyImportAction => 'Importar llave…';

  @override
  String privateKeyLoaded(String type) {
    return 'Llave $type cargada.';
  }

  @override
  String privateKeyLoadedEncrypted(String type) {
    return 'Llave $type cifrada cargada.';
  }

  @override
  String get passphraseLabel => 'Frase de contraseña de la llave';

  @override
  String get passphraseOptionalHint =>
      'Déjala vacía si la llave no está protegida.';

  @override
  String get descriptionLabel => 'Descripción';

  @override
  String get collectionLabel => 'Colección';

  @override
  String get noCollectionOption => 'Sin colección';

  @override
  String get favoriteLabel => 'Favorito';

  @override
  String get saveAction => 'Guardar';

  @override
  String get passwordKeepHint => 'Déjala vacía para conservar la guardada.';

  @override
  String get fieldRequired => 'Este campo es obligatorio.';

  @override
  String get invalidHost =>
      'Escribe un host o una dirección IP, sin esquema ni barras.';

  @override
  String get invalidPort => 'El puerto debe estar entre 1 y 65535.';

  @override
  String get credentialRequired =>
      'Introduce una contraseña o importa una llave.';

  @override
  String get connectionSaved => 'Conexión guardada.';

  @override
  String get connectionDeleted => 'Conexión eliminada.';

  @override
  String get collectionNameLabel => 'Nombre de la colección';

  @override
  String get collectionFormNewTitle => 'Nueva colección';

  @override
  String get collectionFormEditTitle => 'Renombrar colección';

  @override
  String get collectionDeletedConnectionsKept =>
      'Colección eliminada. Sus conexiones siguen disponibles sin colección.';

  @override
  String confirmDeleteConnection(String name) {
    return '¿Eliminar «$name»? También se borrará su credencial guardada.';
  }

  @override
  String confirmDeleteCollection(String name) {
    return '¿Eliminar «$name»? Las conexiones no se borran.';
  }

  @override
  String get hostKeyDialogTitle => 'Huella del servidor';

  @override
  String hostKeyUnknownBody(String host) {
    return 'Es la primera conexión a $host. Comprueba que la huella coincide con la del servidor antes de aceptar.';
  }

  @override
  String get hostKeyFingerprintLabel => 'Huella SHA-256';

  @override
  String get hostKeyKeyTypeLabel => 'Tipo de clave';

  @override
  String get hostKeyAcceptAction => 'Confiar y conectar';

  @override
  String get hostKeyChangedTitle => 'La huella del servidor ha cambiado';

  @override
  String hostKeyChangedBody(String host) {
    return 'La huella guardada para $host no coincide con la que presenta ahora. Puede ser un ataque de intermediario, así que la conexión se ha bloqueado.';
  }

  @override
  String get hostKeyForgetAction => 'Borrar huella guardada';

  @override
  String get hostKeyForgotten =>
      'Huella borrada. Vuelve a conectar para confirmar la nueva.';

  @override
  String get workspaceEmptyTitle => 'Sin sesión';

  @override
  String get workspaceEmptyBody =>
      'Elige un servidor en la barra lateral para abrir una terminal.';

  @override
  String get terminalTab => 'Terminal';

  @override
  String get filesTab => 'Archivos';

  @override
  String get disconnectAction => 'Desconectar';

  @override
  String get reconnectAction => 'Reconectar';

  @override
  String get maximizePanelAction => 'Maximizar panel';

  @override
  String get restoreSplitAction => 'Restaurar división';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get securitySection => 'Seguridad';

  @override
  String get knownHostsTitle => 'Huellas conocidas';

  @override
  String get knownHostsEmpty => 'No hay huellas guardadas en este perfil.';

  @override
  String knownHostsEntry(String host, int port, String type) {
    return '$host:$port · $type';
  }

  @override
  String get profileSection => 'Perfil';

  @override
  String get appearanceSection => 'Apariencia';

  @override
  String get themeLabel => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get terminalAlwaysDark => 'Terminal siempre oscura';

  @override
  String get terminalAlwaysDarkHelp =>
      'Usa la paleta oscura del terminal aunque la interfaz esté en claro.';

  @override
  String get manageProfilesAction => 'Gestionar perfiles';

  @override
  String get profilesTitle => 'Perfiles';

  @override
  String get currentProfileLabel => 'Perfil activo';

  @override
  String get deleteProfileAction => 'Eliminar perfil';

  @override
  String confirmDeleteProfile(String name) {
    return '¿Eliminar el perfil «$name»? Se borrarán sus conexiones, huellas y credenciales, y no se puede deshacer.';
  }

  @override
  String profilePasswordPrompt(String name) {
    return 'Contraseña del perfil «$name»';
  }

  @override
  String get profileCreated => 'Perfil creado.';

  @override
  String get profileDeleted => 'Perfil eliminado.';

  @override
  String get requireReauthLabel => 'Requerir contraseña al editar';

  @override
  String get requireReauthHelp =>
      'Pide la contraseña del perfil al guardar conexiones o credenciales.';

  @override
  String get reauthPromptTitle => 'Confirma tu contraseña';

  @override
  String get reauthPromptBody =>
      'Este perfil pide la contraseña antes de guardar cambios en conexiones o credenciales.';

  @override
  String get errorUnknown => 'Ha ocurrido un error inesperado.';

  @override
  String get navConnections => 'Conexiones';

  @override
  String get navFingerprints => 'Huellas';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get collapseSidebar => 'Contraer barra lateral';

  @override
  String get expandSidebar => 'Expandir barra lateral';

  @override
  String get tabConnections => 'Conexiones';

  @override
  String get tabCloseSession => 'Cerrar pestaña';

  @override
  String get dashboardSearchHint =>
      'Buscar por nombre, host, usuario o etiqueta';

  @override
  String get dashboardGridView => 'Cuadrícula';

  @override
  String get dashboardListView => 'Lista';

  @override
  String get dashboardSortLabel => 'Ordenar';

  @override
  String get dashboardSortByName => 'Nombre';

  @override
  String get dashboardSortByHost => 'Host';

  @override
  String get dashboardSortByRecent => 'Más recientes';

  @override
  String get dashboardEmptyTitle => 'Aún no hay conexiones';

  @override
  String get dashboardEmptyBody =>
      'Crea tu primera conexión o una colección para organizar tus servidores.';

  @override
  String get dashboardNoResults => 'Ningún servidor coincide con la búsqueda.';

  @override
  String get dashboardClearFilters => 'Limpiar filtros';

  @override
  String get ungroupedSection => 'Sin colección';

  @override
  String get connectionOpenAction => 'Abrir';

  @override
  String get typeSsh => 'SSH';

  @override
  String get typeSftp => 'SFTP';

  @override
  String get sftpInvalidName => 'El nombre no puede contener «/».';

  @override
  String serversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servidores',
      one: '1 servidor',
      zero: 'Ningún servidor',
    );
    return '$_temp0';
  }
}
