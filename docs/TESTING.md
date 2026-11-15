# TESTING — SSH Client

Registro de verificaciones ejecutadas, con comando y resultado resumido. Un
ítem del plan solo pasa a `[x]` si aparece aquí su evidencia.

## Entorno
- SO: Windows 11 26H2 (10.0.26300), shell PowerShell.
- Flutter 3.47.9 stable · Dart 3.13.7 · `windows-x64`.
- Sin Visual Studio C++ → sin compilación Windows. Sin Android SDK → sin
  compilación Android. Ver `docs/DECISIONS.md` D-001.

## 2026-11-15 — Fase 0

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

## 2026-11-15 — Fase 7 (Android / layouts por espacio)

### Estado global
```text
flutter analyze   → No issues found!
flutter test      → +185 All tests passed!
```

### Layout responsive — `test/features/shell/mobile_layout_test.dart`
- Con 700×900 la app usa `Drawer`: la barra lateral no está montada hasta abrir el
  cajón, y al abrirlo aparece el perfil.
- Con 1400×1000 no hay `Drawer` y la barra lateral está siempre visible.
- El breakpoint depende del ancho disponible (`LayoutBuilder`), no del SO.

### Pestañas — `test/shared/compact_tabs_test.dart`
`IndexedStack` mantiene las dos pestañas montadas: cambiar de Terminal a Archivos
no reconstruye el terminal ni el canal SFTP. Se comprueba que el contenido de la
pestaña oculta sigue en el árbol (`skipOffstage: false`).

### Barra de teclas — `test/features/terminal/terminal_key_bar_test.dart`
Esc, Tab y flechas envían sus secuencias ANSI; Ctrl+C/D/L envían los caracteres de
control; Alt prefija `ESC` solo a la siguiente tecla. La barra escribe en el pty
con `RemoteTerminal.send`, sin pasar por el IME.

Pendiente: teclado virtual real, latches Ctrl/Alt aplicados al teclado del sistema,
scroll y selección táctil, y selectores nativos. Todo eso exige dispositivo o
emulador Android, que este entorno no tiene (D-001).

## Pendiente de verificación (bloqueado por el entorno, D-001)
- `flutter_secure_storage` en ejecución: plugin de plataforma; no hay app
  ejecutable en esta máquina. Marcado `[~]`.
- Compilación Windows/Linux/macOS/Android y ejecución real de la app.
- Drag and drop real, teclado virtual, terminal y SFTP: dependen de ejecución.
- Golden tests con tipografías reales: pendiente de empaquetar los assets (fase 4).
