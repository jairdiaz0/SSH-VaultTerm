# TESTING — SSH Client

Registro de verificaciones ejecutadas, con comando y resultado resumido. Un
ítem del plan solo pasa a `[x]` si aparece aquí su evidencia.

## Entorno
- SO: Windows 11 26H2 (10.0.26300), shell PowerShell.
- Flutter 3.50.0 stable · Dart 3.13.7 · `windows-x64`.
- Visual Studio 2026 con C++ instalado: `build windows` e integración real
  disponibles. Android SDK sigue ausente. Ver `docs/DECISIONS.md` D-001.

## 2026-11-15 — Ronda 4 (integridad de almacenamiento)

### Línea base de la ronda
```text
flutter analyze → No issues found!
flutter test    → +256 All tests passed!
```

### Bug de importación: qué se reprodujo y qué se corrigió
No se reprodujo el fallo completo de importación + reinicio: los tests de reinicio
en frío con almacén en memoria y con `flutter_secure_storage` real en Windows
pasaban antes y después. Sí se demostró el **mecanismo** que produce el síntoma
(`hmac check failed for pgno=1`, `error decrypting page 1`): `DatabaseKeyStore` usaba
get-or-create al abrir, así que un archivo existente sin su clave (namespace
distinto, restauración a medias, borrado parcial) recibía una clave nueva y
SQLCipher rechazaba la página 1 en cada apertura. Antes de la corrección ese caso
generaba clave; ahora falla con `databaseKeyMissing` y **no** la genera (test).

Además, la importación anterior no construía staging ni verificaba en frío; un
fallo durante el snapshot/restauración podía dejar archivo y clave desalineados.

### Política de claves — `test/core/database/key_policy_test.dart`
- Archivo sin clave → `databaseKeyMissing`; `hasProfileKey` sigue `false`. Catálogo
  igual.
- Clave sin archivo → `databaseKeyOrphan`.
- Clave de longitud inválida → `databaseKeyInvalid`.
- Clave distinta → `databaseKeyMismatch`, el archivo no se toca.
- Creación de perfil todo-o-nada: clave, archivo cifrado y fila; recrear el mismo id
  falla sin borrar lo existente.
- `cipher_compatibility = 4` y `cipher_page_size = 4096` fijados antes de la clave.

### Importación con staging — `backup_restart_test.dart`, `backup_rollback_steps_test.dart`, `backup_test.dart`
- Reinicio en frío real: mismos secretos, servicios nuevos, catálogo y perfiles
  reabiertos desde disco en los tres modos.
- Fallo inyectado al escribir credenciales de staging y al promover la clave
  definitiva → rollback restaura filas, archivos y claves; el arranque en frío lee
  los datos antiguos; staging/backup limpios.
- JSON malformado/truncado no toca el estado.
- Integración Windows con secreto real: exportar → reemplazar todo → reinicio →
  datos legibles → reset → arranque nuevo sin perfiles.

### Reset y ubicación de datos
- `reset_service_test.dart`: borra catálogo, sidecars `-wal`/`-shm`, perfiles,
  staging y backup; borra solo claves con prefijos propios y respeta claves ajenas;
  tras el reset el siguiente arranque no tiene perfiles.
- `app_paths_test.dart`: Windows usa `LOCALAPPDATA`, nunca Roaming;
  `SSH_CLIENT_DATA_DIR` gana.
- `reset_ui_test.dart`: exige escribir RESTABLECER y después la contraseña; el botón
  está deshabilitado sin la palabra; el estado del almacenamiento no muestra
  secretos.
- Android: `allowBackup=false`, `backup_rules.xml` y `data_extraction_rules.xml`
  excluyen bases, preferencias y ficheros (no compilable aquí).

### Terminal: color
- Contraste ANSI ≥4,5:1 y negro brillante ≥3:1 en ambos temas.
- `terminal_colors_test.dart`: SGR de 16 colores, 256 y true color se renderizan y
  el texto no cambia; `dartssh2` ya usa `xterm-256color` en el pty.

### Estado al cierre de la ronda
```text
flutter analyze → No issues found!
flutter test    → +277 All tests passed!
flutter build windows --release → ✓
flutter test integration_test -d windows → +2 All tests passed!
```

### Pendiente de esta ronda
- «Activar colores en esta sesión», resaltado inteligente, rediseño visual de la
  Parte 3, pestañas multi-sesión, estrés SFTP, fuzz adicional, autobloqueo y pantalla
  de huellas en la navegación: **no implementados en esta ronda** (ver el plan).

## 2026-11-15 - Fase 0

### Toolchain
```text
flutter --version        → Flutter 3.47.9 / Dart 3.13.7
flutter doctor -v        → Windows OK; Android SDK y Visual Studio ausentes
```

### Conectividad al servidor de pruebas
```text
Test-NetConnection 192.168.100.129 -Port 22 → TcpTestSucceeded: True
```

### Resolución de dependencias
```text
flutter pub get → OK (80 dependencias)
```
Conflicto real detectado y resuelto: `cross_file` (ver D-006). Aviso no
bloqueante: «Building with plugins requires symlink support» (Developer Mode
desactivado); `pub get`, `analyze` y `test` siguen funcionando.

### Análisis estático
```text
flutter analyze → No issues found! (31.2s)
```

### Tests base
```text
flutter test (template) → All tests passed!
```

### PoC de SQLite cifrado (SQLCipher)
```text
flutter test test/poc/encrypted_sqlite_poc_test.dart → +3 All tests passed!
```
Evidencia concreta:
- `PRAGMA cipher_version` → `4.20.0 community` (no es SQLite plano).
- Archivo creado con clave: el marcador `SUPER_SECRET_MARKER_1234` **no** aparece
  en los bytes del archivo; la cabecera no es `SQLite format 3`.
- Clave incorrecta → `SqliteException` (`hmac check failed for pgno=1`).
- Clave correcta en forma cruda `x'<hex>'` → lee el dato.

## 2026-11-15 — Fase 1

### Estado global
```text
dart format .     → Formatted 57 files (0 changed)
flutter analyze   → No issues found! (6.6s)
flutter test      → +82 All tests passed!
```
El ruido `hmac check failed for pgno=1` en la salida de `flutter test` es
esperado: es SQLCipher rechazando una clave incorrecta a propósito.

### Base de datos cifrada — `test/core/database/encrypted_database_test.dart`
- `the linked sqlite is SQLCipher` → `cipher_version` no vacío (4.20.0).
- `sensitive values do not appear in the file on disk` → el valor sensible no
  aparece en los bytes del fichero real (no solo en memoria).
- `a wrong key cannot open the database` → `AppErrorCode.databaseKeyInvalid`.
- `a key of the wrong length is rejected before touching the file` →
  validación antes de abrir; no se crea ningún fichero.
- `migrations are applied once and reported by user_version` y
  `a database newer than the app is refused, not downgraded` (`schemaTooNew`).
- `foreign keys cascade and nullify as declared`.

### Aislamiento entre perfiles — `test/app/profile_session_test.dart`
- Cada perfil abre su propio fichero **y** su propia clave (comparadas como
  distintas).
- Los datos persisten al cerrar y reabrir; `close` es idempotente.
- `DatabaseKeyStore creates keys once and keeps them stable` → una sola escritura
  en el almacén para la misma clave.

### Repositorios — `test/features/repositories_test.dart`
- `deleting a collection keeps its connections, unassigned` (`ON DELETE SET NULL`).
- `deleting a connection cascades to its known hosts`.
- `never stores a password column` → el esquema de conexiones no admite contraseñas.
- `accepts a new fingerprint and refuses a changed one silently` (base de TOFU).
- `reorder applies positions atomically`.

### Argon2id — `test/core/security/password_hasher_test.dart`
- `matches a reference Argon2id implementation (argon2-cffi)` → el tag calculado
  por `cryptography` coincide con `argon2-cffi` para el mismo vector
  (memoria/iteraciones/paralelismo/sal fijados). No es una comparación consigo
  mismo.
- Determinismo con misma sal y parámetros; longitud según `hashLength`; JSON
  round trip; contraseñas UTF-8 con acentos.

### Autenticación local — `test/features/authentication/authentication_service_test.dart`
- Retardo progresivo: 0 antes del umbral, exponencial después, con tope.
- `a wrong password fails generically and is persisted` → `invalidCredentials` y
  contador persistido en el catálogo.
- `after the delay expires the user can unlock again`.
- `confirmPassword does not touch lockout counters`.

### Credenciales — `test/features/connections/credential_service_test.dart`
- Una credencial de otro perfil no es visible (namespace real, no filtro de UI).
- `deleteAll removes every credential of one profile only`.
- Credenciales vacías rechazadas.

### Rutas y contrato de claves — `test/core/storage/app_paths_test.dart`
- Layout exacto `catalog.db` y `profiles/<id>/data.db`.
- `deleteProfileFiles` elimina el fichero y sus sidecars `-wal`/`-shm`, y tolera
  un perfil inexistente.
- Namespace de secretos (`catalog/dbKey`, `profile/<id>/dbKey`,
  `profile/<id>/credential/<id>`) fijado por test.

### UI — `test/app/app_flow_test.dart`, `test/app/session_controller_test.dart`
Widget tests con servicios reales (catálogo y BD de perfil en un directorio
temporal, `SecretStore` en memoria):
- `empty catalog shows the first-run wizard only`.
- `first-run validation rejects short and mismatched passwords` (no crea nada).
- `creating the first profile unlocks the app`.
- `restart shows the lock screen with no way to create profiles` (el botón de
  crear no existe en la pantalla bloqueada).
- `wrong password keeps the app locked with a generic message`, y con la
  contraseña correcta desbloquea.
- `locking from the shell closes the session and returns to lock` → la
  `ProfileSession` queda cerrada (`isClosed == true`).
- `shell lists the real collections and connections of the profile`.
- Sesión: creación desde sesión desbloqueada cierra la anterior; borrar el perfil
  abierto bloquea antes de borrar secretos.
- `test/app/theme_test.dart`: paleta exacta del SPEC y tema oscuro sin elevación.

> Nota de honestidad: los widget tests inyectan una derivación de clave de
> prueba (`testKeyDerivation`) en lugar de Argon2id real. Motivo: Argon2 de
> `cryptography` cede el turno con temporizadores reales que la zona *fake-async*
> de `testWidgets` no avanza, así que el test se colgaría. Argon2id real está
> cubierto, con vector externo, por el test unitario citado arriba. El doble
> **nunca** se usa en `lib/`.

### Logs — `test/core/utils/app_logger_test.dart`, `test/core/errors/app_exception_test.dart`
- Campos con nombre sensible se escriben como `***`.
- `description` de una excepción expone solo código y tipo de causa: ni el
  mensaje del driver ni fragmentos de secretos llegan a logs ni a la UI.

## 2026-11-15 — Fase 2 (motor SSH)

### Estado global
```text
dart format .     → sin cambios pendientes
flutter analyze   → No issues found! (análisis estricto: strict-casts, strict-inference, strict-raw-types)
flutter test      → +122 All tests passed!
```
La suite incluye 7 tests de integración reales contra `192.168.100.129:22`
(etiqueta `integration`). Se omiten solos si falta `.env.test`; sin red se puede
ejecutar `flutter test -x integration`.

### Claves privadas — `test/features/ssh/private_key_inspector_test.dart`
Fixtures efímeros en `test/fixtures/keys/` (llaves de prueba, no de producción):
- OpenSSH Ed25519, PKCS#1 RSA y SEC1 EC se aceptan y reportan su tipo real.
- Llave OpenSSH cifrada: sin passphrase → `privateKeyPassphraseRequired`;
  passphrase vacía → igual; passphrase incorrecta → `privateKeyPassphraseInvalid`;
  correcta → `encrypted: true`.
- PKCS#8 (`PRIVATE KEY`) → `privateKeyUnsupportedFormat` (no soportado por
  `dartssh2` 4.1.0, que solo decodifica OpenSSH, PKCS#1 y SEC1).
- Texto que no es PEM y entrada vacía → `privateKeyInvalid`.
- El `description` de la excepción no contiene material de la llave.

### TOFU — `test/features/ssh/host_key_verifier_test.dart`
- Huella desconocida: se pregunta una vez y, al aceptar, se guarda con el tipo de
  clave, el host y el puerto.
- Huella guardada que coincide: no se vuelve a preguntar.
- Rechazo del usuario: no se guarda nada.
- Huella distinta: `false` sin preguntar, estado `changed`, `trustedFingerprint`
  informado y la fila guardada **no** se sobrescribe.
- `connection_id` distinto mantiene entradas independientes.

### Errores — `test/features/ssh/ssh_error_mapper_test.dart`
`SocketException`/`SSHSocketError` → `networkUnreachable`; `TimeoutException`,
`SSHAuthAbortError('Authentication timed out')` y `SSHHandshakeError(...timed out)`
→ `connectionTimeout`; `SSHAuthFailError` → `authFailed`; `SSHHostkeyError` →
`hostKeyRejected`; `SSHDisconnectError` → `connectionLost`; `AppException` pasa
intacta.

### Servicio — `test/features/ssh/ssh_service_test.dart`
- Sin `credentialId` o sin secreto guardado: `credentialMissing` y el socket ni se
  abre.
- Host inalcanzable: estados `[connecting, failed]` y `networkUnreachable`; el log
  de fallo no contiene la contraseña.
- Timeout de socket: `connectionTimeout`.
- Llave privada corrupta o cifrada sin passphrase: falla **antes** de red.

### Integración real — `test/features/ssh/ssh_integration_auth_test.dart` y `..._sessions_test.dart`
Contra `.env.test` (cuenta de pruebas dedicada), operando solo en
`~/opencode_sandbox/run_<uuid>/`: montaje común en
`test/support/ssh_integration_harness.dart`.
- Contraseña: conexión, huella SHA-256 `SHA256:…` aceptada y persistida,
  secuencia `connecting → awaitingHostKey → authenticating → connected`, comando
  ejecutado y su salida recogida; `rm -rf` del sandbox al terminar.
- Segunda conexión con huella ya guardada: no se vuelve a preguntar.
- Huella guardada distinta: `hostKeyChanged`, sin diálogo y sin sobrescribir.
- Contraseña incorrecta: `authFailed` en dos intentos (límite de la cuenta de
  pruebas).
- Llave Ed25519 efímera: se genera con `ssh-keygen`, se añade a
  `~/.ssh/authorized_keys` con el comentario `opencode-test-<uuid>`, se conecta
  con llave y se retira la línea al final.
- Dos sesiones concurrentes: cada una ejecuta su comando; cerrar una no afecta a
  la otra.
- Pérdida del transporte (`socket.destroy()`): estado
  `disconnectedUnexpectedly`.

## 2026-11-15 — Fase 3 (terminal)

### Estado global
```text
flutter analyze   → No issues found!
flutter test      → +127 All tests passed! (incluye el pty real)
```

### Emulador — `test/features/terminal/terminal_view_test.dart`
- Texto y colores ANSI: una celda en rojo conserva su color tras el reseteo.
- Scrollback acotado: 150 líneas con `maxLines: 100` dejan la última y no
  desbordan (ver la limitación de `xterm` en D-005).
- Entrada del usuario: `textInput`/`paste` llegan a `onOutput` (lo que se envía
  por el canal SSH).
- `TerminalView` se monta en un `MaterialApp`, recibe salida y reporta tamaño
  (`viewWidth`/`viewHeight` > 0), sin excepciones.

### Pty real — `test/features/terminal/terminal_integration_test.dart`
Contra el servidor de pruebas:
- `stty size` responde `24 80` al abrir el pty con ese tamaño.
- Tras `resize(100, 30)`, `stty size` responde `30 100`: el tamaño llega al
  servidor.
- Salida de comandos y eco de entrada funcionan (`MARK-42`).
- UTF-8 en ambos sentidos (`acentos: áéíóú`).
- Cerrar el canal del terminal no cierra la conexión SSH: un `execute` posterior
  sigue funcionando.

Pendiente (fase 4): selección, copia/pegado desde la UI, barra de teclas en
Android y medición de rendimiento con volúmenes grandes.

## 2026-11-15 — Fase 4 (UI de escritorio)

### Estado global
```text
flutter analyze   → No issues found!
flutter test      → +141 All tests passed! (incluye pty y SSH reales)
```

### Fuentes empaquetadas
`assets/fonts/Inter-*.ttf` (400/500/600/700) y `assets/fonts/JetBrainsMono-*.ttf`
(400/700), con sus licencias OFL al lado. Test de assets en
`test/app/theme_test.dart`: los seis ficheros existen y el tema aplica la familia
`Inter` (también tras los `copyWith`, que la perdían). El terminal usa
`JetBrainsMono` (`appTerminalStyle`).

### CRUD real — `test/features/shell/shell_crud_test.dart`
Con servicios reales (BD cifrada en memoria y almacén de secretos en memoria):
- Crear colección desde el diálogo y verla en la barra lateral.
- Crear conexión con contraseña: aparece con `usuario@host:puerto`; la credencial
  queda **solo** en el almacén secreto y se recupera con su `credentialId`.
- Validación: sin host no se guarda y se muestra el error.
- Editar el nombre conserva el `credentialId` y la contraseña guardada.
- Favorito: aparece dos veces (Favoritos + colección), como en el diseño.
- Eliminar conexión borra su credencial; eliminar colección deja la conexión sin
  colección (ON DELETE SET NULL verificado desde la UI).
- Reordenar colecciones con el menú Subir/Bajar y posiciones persistidas.

### Workspace — `test/features/workspace/workspace_test.dart`
- `WorkspaceController` contra `127.0.0.1:1` (puerto cerrado, sin servidor):
  estado `failed` y código `networkUnreachable`.
- Panel: banner de error localizado, botón Reconectar y nombre del servidor.
- Ajustes: lista una huella conocida real, muestra su `SHA256:…` y la borra
  (persistida en la BD del perfil, contador a 0).

### Divisor — `test/shared/resizable_split_test.dart`
- Arrastrar el divisor cambia los anchos y conserva los 8 px del asa.
- Maximizar terminal oculta el panel de archivos (y al revés); restaurar devuelve
  la división. El estado de la sesión no se toca al cambiar de modo.

Pendiente (fase 5): panel SFTP real y arrastrar y soltar de entrada.

## 2026-11-15 — Fase 5 (SFTP)

### Estado global
```text
flutter analyze   → No issues found!
flutter test      → +169 All tests passed! (incluye SFTP, SSH y pty reales)
```

### Rutas remotas — `test/features/sftp/posix_path_test.dart`
Lógica POSIX propia (no `path` local): normalización de `//`, `.` y `..` sin salir
de la raíz, `join` con nombre absoluto, `parent` de `/` = `/`, `basename`,
`segments` para breadcrumbs y `isWithin` para comprobar contención real (no
prefijos que solo se parecen).

### Entradas remotas — `test/features/sftp/remote_entry_test.dart`
Tipo por bits `S_IFMT` (directorio, fichero, enlace), permisos estilo `ls`
(`rw-r--r--`, `rwxr-x--x`) y archivos ocultos por punto inicial.

### Cola — `test/features/sftp/transfer_queue_test.dart`
Con un gateway falso: subida completa con progreso y velocidad, descarga que
aprende el tamaño del servidor, cancelación en el siguiente chunk (estado
`cancelled`, código `transferCancelled`), cancelación de una tarea pendiente que
no toca el gateway, fallo reportado y reintento que termina bien.

### Servidor real — `test/features/sftp/sftp_integration_test.dart`
- `home()` absoluto y listado del directorio del usuario.
- Subida de 2 MiB por chunks; `sha256sum` remoto **igual** al SHA-256 local.
- Listado con tamaño, permisos y fecha reales.
- Descarga y comparación de hashes local/descarga: integridad verificada.
- Renombrado, carpetas anidadas y borrado recursivo comprobado por listado.
- Ruta inexistente → `sftpNotFound`.
- Cola completa subiendo y bajando el mismo fichero, con hash igual al original.
Todo dentro de `~/opencode_sandbox/run_<uuid>/`, borrado al terminar.

### Panel — `test/features/sftp/sftp_panel_test.dart`
Con un servidor en memoria: listado con tamaños y permisos, ocultos, navegación
con historial (atrás/adelante/arriba/breadcrumbs), creación de carpeta,
renombrado, borrado con confirmación, estado de error con reintento, y subida que
encola, completa y refresca el listado mostrando «Finalizada».

Pendiente: el arrastre real del sistema operativo al panel (`DropTarget` y su
manejador cableados y probados por código, no por gesto del SO).

## 2026-11-15 — Fase 6 (backups)

### Estado global
```text
flutter analyze   → No issues found!
flutter test      → +178 All tests passed!
```

### Documento — `test/features/backup/backup_test.dart`
- Exporta perfiles, colecciones, conexiones, huellas y credenciales (leídas del
  almacén) y **no** incluye las claves maestras de las BD: se comprueba que ni la
  clave del catálogo ni la del perfil aparecen en el JSON, ni la contraseña.
- Round trip completo JSON → instalación nueva: perfiles, datos, credenciales y
  huellas se restauran; la clave de BD del perfil es **nueva**; la contraseña
  original sigue desbloqueando el perfil restaurado (el verificador se conserva).
- Fusionar conserva los datos locales que no están en el respaldo y renombra el
  perfil importado si el nombre choca («Local (importado)»).
- Reemplazar un perfil deja intacto el otro perfil.
- Fallo inyectado en el almacén de secretos a mitad de importación → se restaura
  el estado anterior (sin perfiles a medias, sin secretos huérfanos).
- Versión futura → `backupVersionUnsupported`; JSON inválido o incompleto →
  `backupInvalid`.

### Diálogos — `test/features/backup/backup_dialogs_test.dart`
- La advertencia de exportación muestra el texto del SPEC (incluye la frase de
  fuerza bruta) y solo devuelve `true` con la confirmación explícita.
- El resumen de importación muestra perfiles, conexiones y credenciales, permite
  elegir modo y avisa al elegir «Reemplazar todos»; «Reemplazar un perfil» queda
  deshabilitado si el respaldo no contiene un perfil local coincidente.

Pendiente: escritura/lectura real de ficheros vía selector del sistema (no
ejecutable aquí) y migración de documentos de versiones anteriores (solo existe v1).

## 2026-11-15 - Ronda 3: línea base

Flutter se actualizó a **3.50.0** (Dart 3.13.7), donde `package:flutter/material.dart`
está deprecado en favor de `package:material_ui/material_ui.dart` (y Cupertino en
`cupertino_ui`). Se migraron todos los imports y los delegates de localización
(`lib/app/localizations.dart`), con `material_ui 1.11.0` y `cupertino_ui 1.1.6`.

```text
flutter analyze   → No issues found!
flutter test      → +204 All tests passed!
```

Esta es la línea base de la etiqueta `pre-ui-modernization`. Rama de trabajo:
`ui-modernization`.

## 2026-11-15 — Ronda 3 (seguridad y modernización de UI)

### Estado global al cierre
```text
dart format --set-exit-if-changed lib test integration_test → 0 cambios
flutter analyze                                             → No issues found!
flutter test                                                → +256 All tests passed!
flutter build windows --release                             → ✓ Built build\windows\x64\runner\Release\ssh_client.exe
flutter test integration_test/app_windows_test.dart -d windows → +1 All tests passed!
```

### Reautenticación (servicios, no solo UI)
- `AuthenticationService.verifyForSensitiveAction` reutiliza Argon2id y el
  contador persistente: contraseña correcta, incorrecta (cuenta 1 intento) y
  bloqueo tras tres fallos (incluida la contraseña correcta mientras dura).
- `SecuritySettingsService.setRequireReauthOnEdit`: con contraseña incorrecta el
  ajuste no cambia y el intento cuenta; con la correcta activa y desactiva.
- `BackupExportService.exportText`: con contraseña incorrecta lanza y **no lee
  ninguna credencial** (almacén envolvente con contador: 0 lecturas); con la
  correcta exporta y el documento contiene la credencial.
- `ConfirmPasswordDialog` reutilizable: error genérico, limpia el campo, no cierra
  con contraseña incorrecta y devuelve `false` al cancelar.
- Widget tests: interruptor con contraseña incorrecta (no guarda), correcta
  (activa/desactiva), crear/editar conexión siguen pidiendo contraseña y
  guardando; sin reautenticación el flujo de conexiones sigue igual.

### Sistema de diseño y contraste
- `test/app/theme_test.dart`: paletas claras/oscuras con los valores acordados,
  tokens (radios 18/22/14/12/10, duraciones 150/200/250), fuentes Inter y
  JetBrains Mono, terminal por tema y opción siempre oscura.
- `test/app/theme_contrast_test.dart`: texto 4,5:1 y componentes 3:1 en ambos
  temas; incluye `onAccent`, estados y 7 colores ANSI sobre el fondo del terminal.
- Sin `Color(0x...)` ni `Colors.white|black|grey` fuera de `lib/app/theme/`.

### Tema y persistencia
- `test/app/theme_mode_test.dart`: sin preferencia → sistema; guardar claro y
  terminal siempre oscura y recargar; volver a sistema; modo sistema sigue
  `platformBrightness` (oscuro y claro); selector de Ajustes cambia el tema al
  instante; switch de terminal siempre oscura persistido.

### Matriz de pantallas
`test/app/ui_matrix_test.dart`: tema claro y oscuro × 900×600, 1280×720 y
1920×1080 × escala de texto 1,3 para primera ejecución, bloqueo, shell con sidebar
densa, ajustes, formulario de conexión, diálogo de huella y panel SFTP (32 tests,
sin overflow).

### Iconos
`AppIcons` centraliza los iconos Lucide; ningún widget importa la librería. Los
tests existentes siguen localizando controles por Key/semántica.

### Verificación real en Windows
- Compilación release correcta.
- Integración real repetida tras la modernización: perfil, SSH tecleado, `exit`,
  «Sesión finalizada» y conexión SFTP con navegación. Almacén seguro y SQLCipher
  reales; directorio y namespace temporales borrados al final.

### Golden tests
Omitidos con motivo documentado en `docs/UI_AUDIT.md`: en `flutter_test` las
fuentes de assets no se cargan por defecto (Ahem), así que un golden no
representaría la tipografía real. Se cubren layout, contraste y ambos temas.

## 2026-11-15 — Ronda de correcciones 1 (primera prueba manual en Windows)

### Estado global
```text
dart format --set-exit-if-changed lib test integration_test → 0 cambios
flutter analyze                                             → No issues found!
flutter test                                                → +204 All tests passed!
flutter build windows --release                             → ✓ Built build\windows\x64\runner\Release\ssh_client.exe
flutter test integration_test/app_windows_test.dart -d windows → +1 All tests passed!
```

### Tipo de conexión — migración y respaldo
`test/core/database/profile_migration_test.dart`:
- Una BD con `user_version = 1` y la tabla `connections` sin `connection_type`
  migra a v2 al abrirla, y la fila existente queda como `ssh`.
- El `CHECK` rechaza tipos desconocidos (`telnet` → `SqliteException`).

`test/features/backup/backup_test.dart`:
- Un documento `formatVersion: 1` (sin `connectionType`) se lee y sus conexiones
  pasan a `ssh`; el export actual escribe v2.
- El resto del round trip, merge, replace y rollback siguen en verde.

`test/features/shell/shell_crud_test.dart`:
- El formulario guarda `ConnectionType.sftp` al elegir el chip SFTP.

### Teclado del terminal — `test/features/terminal/terminal_input_test.dart`
Con `TerminalView(hardwareKeyboardOnly: true)` (escritorio), enviando eventos de
teclado reales al widget:
- Todas las letras (a–z, A–Z), dígitos y símbolos `- . / ;` y espacio llegan al pty
  en el mismo orden.
- Símbolos con Shift (`_ : ! ? @ $`) llegan con su carácter.
- `é` y `ñ` se envían como UTF-8 (la composición real por IME queda para Android).
- Enter (`\r`), Tab (`\t`) y flechas (`ESC[A`, `ESC[D`) envían sus secuencias.
- Ctrl+C envía `\x03` y no una `c`.
- Pegar reenvía el texto (los saltos de línea se conservan: `\n`).

Prueba real: en el test de integración de Windows se teclea
`echo INTEGRATION-OK` con eventos de teclado y el marcador aparece en el búfer del
terminal de la app.

### Fin de sesión
En el test de integración de Windows: tras `exit`, la app muestra el overlay
`session-ended` («Sesión finalizada») con Reconectar/Cerrar, cierra el canal, libera
el `SSHClient` y «Cerrar» devuelve el workspace vacío. El indicador del sidebar
pasa a «Sesión finalizada» (`SshConnectionStatus.sessionEnded`).

### Ruta SFTP — `test/features/sftp/sftp_panel_test.dart`
- Ya no existe la etiqueta de ruta duplicada (`sftp-path` no está en el árbol).
- Pulsar el espacio libre convierte los breadcrumbs en un campo editable; al
  confirmar `/home/test/docs` se navega y lista el contenido.
- Ctrl+L enfoca el mismo campo.

### Layout y overflow — `test/features/shell/layout_sizes_test.dart`
Con sidebar densa (colección + 8 conexiones de nombres largos, SSH y SFTP):
900×600, 1280×720 y 1920×1080 montan el shell y abren Ajustes sin ninguna excepción
de overflow; la lista lateral hace scroll. Tokens `AppSpacing` (4/8/12/16/24) y
tamaño mínimo 900×600 aplicados también en el runner de Windows
(`WM_GETMINMAXINFO`).

### Gestión de perfiles — `test/features/profiles/profile_management_test.dart`
- Crear un perfil desde Ajustes lo añade y entra en él.
- Cambiar de perfil exige su contraseña; con contraseña incorrecta no cambia y
  muestra error; con la correcta, la sesión pasa al perfil elegido.
- Eliminar exige confirmación y contraseña correcta; con la incorrecta el perfil
  sigue existiendo.
- La pantalla bloqueada muestra «Cambiar de perfil» y no ofrece crear.

### Datos aislados y limpieza
- `AppPaths.resolveFrom` acepta `SSH_CLIENT_DATA_DIR`; el almacén seguro acepta
  `SSH_CLIENT_SECRET_NAMESPACE` (probado en `app_paths_test.dart` y en el uso real
  del test de integración con namespace desechable).
- `AppHarness` y `TestContext` registran su limpieza al crear el directorio; un
  fallo de test ya no deja `ssh_client_app_test_*` en `%TEMP%`.
- `tool/reset_dev_data.ps1` probado con un directorio falso y el namespace
  `reset_test_ns`: lista archivos y secretos y solo borra al escribir `BORRAR`.
- Tras la ronda, `%TEMP%` no conserva ningún directorio `ssh_client*` de tests.

### Integración real en Windows — `integration_test/app_windows_test.dart`
Ejecutado con `-d windows` (almacén seguro real y SQLCipher reales; directorio
temporal y namespace propios, borrados al final):
1. Primer inicio: crea el perfil «Integration».
2. Crea la conexión SSH `it-ssh` contra `192.168.100.129`, acepta la huella y
   teclea un comando; el terminal muestra `INTEGRATION-OK`.
3. `exit` → «Sesión finalizada» → Cerrar.
4. Crea la conexión SFTP `it-sftp` (tipo SFTP), acepta la huella, el workspace
   muestra solo el explorador y navega con el campo de ruta a
   `<home>/opencode_sandbox`.

### Estado global
```text
flutter analyze   → No issues found!
flutter test      → +185 All tests passed!
```

## 2026-11-15 — Fase 7 (Android / layouts por espacio)

### Layout responsive — `test/features/shell/mobile_layout_test.dart`
- Con 700×900 la app usa `Drawer`: la barra lateral no está montada hasta abrir el
  cajón, y al abrirlo aparece el perfil.
- Con 1400×1000 no hay `Drawer` y la barra lateral está siempre visible.
- El breakpoint depende del ancho disponible (`LayoutBuilder`), no del SO.

### Pestañas (retiradas en la ronda 1)
La decisión D-018 eliminó el panel doble: cada conexión muestra su única vista, así
que `CompactTabs` y su test se retiraron. El drawer móvil se conserva y se prueba en
`mobile_layout_test.dart`.

### Barra de teclas — `test/features/terminal/terminal_key_bar_test.dart`
Esc, Tab y flechas envían sus secuencias ANSI; Ctrl+C/D/L envían los caracteres de
control; Alt prefija `ESC` solo a la siguiente tecla. La barra escribe en el pty
con `RemoteTerminal.send`, sin pasar por el IME.

Pendiente: teclado virtual real, latches Ctrl/Alt aplicados al teclado del sistema,
scroll y selección táctil, y selectores nativos. Todo eso exige dispositivo o
emulador Android, que este entorno no tiene (D-001).

## Pendiente de verificación (bloqueado por el entorno, D-001)
- **Android, macOS y Linux**: sin toolchain aquí; no compilados ni ejecutados.
  Windows sí: `flutter build windows --release` y el test de integración real.
- Teclado virtual, scroll/selección táctil y selectores nativos de Android: exigen
  dispositivo o emulador.
- Arrastrar y soltar real del sistema operativo: sin gesto automatizable.
- Drag and drop de salida: bloqueado por dependencias (D-006), no simulado.
- Golden tests con tipografías reales: los assets existen y el tema los aplica,
  pero no se ha fijado un golden por plataforma.
