# DECISIONS — SSH Client

Decisiones técnicas con su justificación y evidencia. Formato: `D-XXX` con
fecha, contexto, decisión, consecuencias y verificación.

---

## D-001 — Entorno de verificación: Windows compilable, Android SDK ausente
**Fecha:** 2026-11-15 (actualizado el 2026-11-15 tras la primera prueba manual)
**Contexto:** `flutter doctor -v` en la máquina de desarrollo (Windows 11 26H2):
- Flutter 3.47.9 stable, Dart 3.13.7, `windows-x64`.
- **Visual Studio Community 2026 18.12 con el workload de C++ está instalado**:
  `flutter build windows --release` compila y `flutter test integration_test
  -d windows` ejecuta la app real (verificado en esta ronda).
- **Android SDK sigue sin localizarse** → `android` no se puede compilar.
- Chrome no instalado; Edge sí (web está fuera de alcance).

**Decisión:** la verificación primaria es `dart format`, `flutter analyze`,
`flutter test` y, para lo que exige plataforma, **integración real en Windows**
(`integration_test` con almacén seguro y SQLCipher reales) más la compilación de
release. Android/macOS/Linux siguen marcados como no verificados con su causa y
no se simulan.

**Consecuencias:**
- `flutter_secure_storage` queda verificado en Windows por el test de integración
  (probe de escritura/lectura real contra Credential Manager) y por el uso real de
  credenciales y claves de BD durante el flujo.
- Los tests de integración usan un directorio temporal (`AppPaths` explícito) y un
  namespace de secretos desechable; nunca tocan el perfil real del usuario.
- Sigue pendiente compilar/ejecutar en Android, macOS y Linux.
- El aviso de `flutter pub get` «Building with plugins requires symlink support»
  (Developer Mode desactivado) no bloquea `pub get`, `analyze`, `test` ni
  `build windows`.

**Verificación:** `flutter build windows --release` y `flutter test
integration_test/app_windows_test.dart -d windows` (ver `docs/TESTING.md`).

---

## D-002 — SQLite cifrado: SQLCipher embebido vía hook de `sqlite3` 3.x
**Fecha:** 2026-11-15
**Contexto:** `sqlite3_flutter_libs` 0.6.0+eol y `sqlcipher_flutter_libs`
0.7.0+eol están marcados EOL por su autor («update to version 3.x of
package:sqlite3»). `package:sqlite3` 3.x incluye un build hook que descarga
binarios precompilados y permite elegir la variante con
`hooks: user_defines: sqlite3: source: <sqlite3|sqlite3mc|sqlcipher>`.

**Decisión:** `sqlite3: ^3.9.1` con `source: sqlcipher`. Claves de BD: 32 bytes
CSPRNG, aplicadas con la forma de clave en crudo `PRAGMA key = "x'<hex>'"` (sin
KDF, que no aporta nada cuando la clave ya es aleatoria de 256 bits y evita
~250 ms de PBKDF2 por apertura).

**Consecuencias:**
- El binario se descarga en build (nunca en ejecución). No requiere compilador C
  en esta máquina: el hook usa binarios precompilados.
- Prohibido abrir cualquier BD sin `PRAGMA key`; se centraliza en un único
  `EncryptedDatabase.open` (fase 1) para que sea imposible olvidarlo.
- `PRAGMA cipher_version` permite una comprobación barata en tests de que el
  binario no es SQLite plano.

**Verificación:** `flutter test test/poc/encrypted_sqlite_poc_test.dart` →
`SQLCipher version: 4.20.0 community`; marcador sensible ausente en bytes del
archivo; clave incorrecta lanza `SqliteException`; clave correcta lee el dato.

---

## D-003 — TOFU con SHA-256 usando `dartssh2` 4.1.0 sin vendorizar
**Fecha:** 2026-11-15
**Contexto:** el SPEC exige verificar qué entrega `onVerifyHostKey`; si solo
expusiera MD5 habría que vendorizar o parchear el paquete.

**Decisión:** se usa `dartssh2` 4.1.0 (mantenido por `vicajilau`, publicado
2026-09-04) sin vendorizar. Su API instalada es:

```dart
typedef SSHHostkeyVerifyHandler = FutureOr<bool> Function(
  String type,          // p.ej. 'ssh-ed25519'
  Uint8List fingerprint // 'SHA256:<base64>' en UTF-8
);
```

**Consecuencias:**
- La huella ya es SHA-256 estilo OpenSSH; se compara con la almacenada y se
  muestra al usuario en el primer contacto.
- `onVerifyHostKey: null` acepta cualquier clave: **prohibido** en este proyecto.
  El servicio SSH siempre pasa el callback.
- También expone `SSHRawHostKey.encode()` (blob binario) si algún día hace falta
  una huella calculada por nosotros.

**Verificación:** lectura del código fuente de la versión instalada en
`%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\dartssh2-4.1.0\lib\src\ssh_transport.dart`.

---

## D-004 — Sin Drift: repositorios sobre `sqlite3` directo
**Fecha:** 2026-11-15
**Contexto:** el esquema son ~6 tablas por base (catálogo y perfil). Drift aporta
tipado y migraciones, pero añade `build_runner`, código generado y capas sobre la
apertura de la BD, justo donde necesitamos control absoluto (`PRAGMA key`,
`PRAGMA cipher`, apertura/cierre por perfil).

**Decisión:** `sqlite3` directo con repositorios escritos a mano y un runner de
migraciones propio con `PRAGMA user_version`. SQL explícito, sentencias
preparadas y transacciones.

**Consecuencias:** cero código generado, sin dependencia EOL (`drift_flutter`
todavía arrastra `sqlite3_flutter_libs`/`sqlcipher_flutter_libs` EOL), y la
capa de cifrado queda en un único punto auditable. Las consultas se validan con
tests por repositorio.

---

## D-005 — `xterm` 4.0.0 aceptado provisionalmente, con plan B
**Fecha:** 2026-11-15
**Contexto:** `xterm` (TerminalStudio) 4.0.0 es de 2024-02, último commit del
repo 2025-06. Existe el fork `xterm2` 5.4.0 (2026-10, MIT) y `flterm` (2026-10).
El SPEC pide el paquete real `xterm` y prohíbe forks AGPL/GPL.

**Decisión:** se usa `xterm: ^4.0.0`. Si en la fase 3 no compila o no funciona
con Flutter 3.47.9, se evalúa `xterm2` (MIT, mantenido) y se registra aquí el
cambio con evidencia. No se acepta ningún fork AGPL/GPL.

**Verificación (fase 3):** `xterm` 4.0.0 compila con Flutter 3.47.9 y funciona en
`flutter test`: `Terminal`, `TerminalView`, búfer, colores ANSI, entrada y
`onResize` están cubiertos por tests. Contra el servidor real, un pty responde a
`stty size` (24×80 al abrir, 30×100 tras `resize`), devuelve UTF-8 correcto
(`áéíóú`) y mantiene los comandos bidireccionales. **Se mantiene `xterm`; no se
cambia a `xterm2`.**
**Limitación conocida:** con `maxLines` menor que la altura visible (24 por
defecto) el búfer circular de `xterm` 4.0.0 lanza `RangeError`. La app usa 10 000
líneas de scrollback, muy por encima, y el test lo fija en 100 con 150 líneas
escritas. Si algún día se permite configurar scrollback por debajo de la altura,
hay que subir ese mínimo o migrar a `xterm2`.

---

## D-006 — Selectores y drag and drop: `file_picker` + `desktop_drop 0.8.4`
**Fecha:** 2026-11-15
**Contexto:** `cross_file` es el cuello de botella del ecosistema:
- `desktop_drop` 0.9.x exige `cross_file ^0.4.0`; ningún selector mantenido lo
  soporta (`file_picker` 13.3.3 y `file_selector` 1.1.0 siguen en `^0.3.x`).
- `super_drag_and_drop` 0.9.1 (la única opción para arrastrar **hacia fuera**) no
  resuelve junto a `flutter_secure_storage` 11.x por el pin de `win32`.

**Decisión:** `file_picker: ^13.3.3` y `desktop_drop: ^0.8.4` (arrastrar y
soltar **hacia dentro**). El arrastre hacia fuera (lista SFTP → escritorio)
queda **bloqueado** (`[!]` en el plan) hasta que `super_drag_and_drop`
0.10.0-dev.2 o superior resuelva con el resto del árbol. No se simulará.

**Consecuencias:** la fase 4 implementa la entrada; la salida se declara no
disponible en este árbol de dependencias, con la causa documentada.

---

## D-007 — Hash de contraseña de perfil: Argon2id en isolate
**Fecha:** 2026-11-15 (decisión inicial; verificada en fase 1)
**Decisión:** Argon2id con `cryptography` 2.9.0 ejecutado en un isolate
(`Isolate.run`), sal aleatoria de 16 bytes por perfil, 32 bytes de tag y
parámetros (64 MiB, t=3, p=2) persistidos junto al verificador para poder
migrarlos. Alternativa documentada si el rendimiento en móvil es inaceptable:
PBKDF2-HMAC-SHA256 con ≥600 000 iteraciones.
**Verificación:** `matches a reference Argon2id implementation (argon2-cffi)` en
`test/core/security/password_hasher_test.dart`: el tag coincide con el de
`argon2-cffi` para un vector fijado (sal, memoria, iteraciones y paralelismo
constantes). Comparación en tiempo constante sobre el verificador.
**Consecuencia:** los tests usan `PasswordHasher.direct()` (sin isolate) para no
pagar el arranque; los widget tests usan un doble de la derivación (D-012).

---

## D-008 — «Cambiar de perfil» en la pantalla bloqueada
**Fecha:** 2026-11-15
**Contexto:** el SPEC pide registrar esta decisión.
**Decisión:** se incluye un enlace discreto que solo permite **elegir entre
perfiles existentes**. No crea perfiles ni revela datos: al elegir, se pide la
contraseña de ese perfil. Sin este enlace, tras reiniciar solo sería accesible el
último perfil.

---

## D-009 — l10n: español por defecto, inglés preparado
**Fecha:** 2026-11-15
**Decisión:** UI en español mediante ARB (`lib/l10n/app_es.arb`), con
`app_en.arb` añadible sin tocar código (toda cadena visible pasa por
`AppLocalizations`). Código, identificadores y commits en inglés.
**Consecuencia:** prohibido escribir texto visible literal en widgets.

---

## D-010 — Estructura de datos en disco
**Fecha:** 2026-11-15 (cerrada en fase 1)
**Decisión:**
```text
<applicationSupport>/ssh_client/
  catalog.db                    # cifrada: perfiles (sin secretos) + metadatos
  profiles/<profileId>/data.db  # cifrada: colecciones, conexiones, known hosts
```
Claves en Secure Storage:
- `catalog/dbKey`
- `profile/<profileId>/dbKey`
- `profile/<profileId>/credential/<credentialId>`
Ningún secreto en SQLite. Las claves nunca se escriben en disco ni en logs.
**Verificación:** rutas resueltas con `path_provider`
(`getApplicationSupportDirectory`) en `core/storage/app_paths.dart`, fijadas por
`test/core/storage/app_paths_test.dart` junto con el namespace de secretos.
**Detalle:** al borrar un perfil se eliminan el fichero y sus sidecars `-wal`/`-shm`
(el WAL está activo, ver `EncryptedDatabase._configure`).

---

## D-011 — Estado de aplicación sin Riverpod por ahora
**Fecha:** 2026-11-15
**Contexto:** el SPEC admite `flutter_riverpod` como auxiliar «solo si hace
falta». La fase 1 necesita un único estado global (bloqueado/desbloqueado +
sesión de perfil abierta) y tres pantallas.
**Decisión:** `SessionController extends ChangeNotifier` como dueño del estado,
expuesto a la UI con `ListenableBuilder` desde `SessionGate`. `AppServices` es el
composition root (`bootstrap` en producción, `fromStorage` en tests) y no hay
ningún singleton mutable global.
**Consecuencias:** cero código generado y ninguna API nueva para un estado de
tres valores. `flutter_riverpod` queda **sin usar**; se retirará del
`pubspec.yaml` si la fase 3 no lo necesita, y añadirlo entonces sería una
decisión nueva, no un reflejo.
**Alternativa descartada:** Riverpod ahora, por ceremonia en un estado de tres
valores.

---

## D-012 — Doble de la derivación Argon2 en widget tests
**Fecha:** 2026-11-15
**Contexto:** Argon2 de `cryptography` cede el turno con
`Future.delayed(Duration(microseconds: 1))` dentro del bucle de cómputo. En la
zona *fake-async* de `testWidgets` esos temporizadores no avanzan, así que
cualquier widget test que desbloquee o cree un perfil se cuelga (comprobado: el
`pumpAndSettle` expira con el indicador de progreso eterno).
**Decisión:** los widget tests inyectan `testKeyDerivation` (FNV/LCG
determinista, rápido, distingue contraseñas) en `PasswordHasher(derive: ...)`.
Argon2id real se verifica aparte, con vector externo, en
`test/core/security/password_hasher_test.dart`.
**Consecuencias:** los widget tests prueban el flujo completo (validación,
gate, apertura/cierre de BD) sin pagar 64 MiB por intento. El doble vive en
`test/support/app_harness.dart` y no se enlaza desde `lib/`.

---

## D-013 — l10n sin paquete sintético
**Fecha:** 2026-11-15
**Contexto:** `synthetic-package` está deprecado en Flutter 3.47 y
`flutter gen-l10n` avisa de que ya no tiene efecto.
**Decisión:** `l10n.yaml` con `output-dir: lib/l10n/generated` y
`nullable-getter: false`. Los ficheros generados se versionan para que
`flutter analyze` y `flutter test` funcionen sin un paso previo de generación.
**Consecuencias:** al añadir una cadena hay que ejecutar `flutter gen-l10n`
(también lo hace `flutter run`/`build` con `generate: true`). Prohibido escribir
texto visible literal en widgets: todo pasa por `AppLocalizations`.

---

## D-014 — Línea base de análisis estático estricta
**Fecha:** 2026-11-15
**Contexto:** `flutter_lints` solo trae las reglas recomendadas; con un cliente
SSH que maneja sockets, bases de datos y secretos, un `dynamic` implícito o un
`Future` olvidado cuestan caro y se detectan tarde.
**Decisión:** `analysis_options.yaml` activa `strict-casts`, `strict-inference` y
`strict-raw-types`, y eleva a **error** `unawaited_futures` y `avoid_print`.
Además, obligatorias: `directives_ordering`, `always_declare_return_types`,
`avoid_dynamic_calls` y `prefer_single_quotes`.
**Consecuencias:** el umbral de `flutter analyze` es «No issues found!» o no hay
commit. Un `// ignore` necesita justificación escrita junto a la línea. Los
ficheros generados de l10n ya cumplen las reglas.

---

## D-015 — Errores SSH: códigos propios y la huella decide, no el texto
**Fecha:** 2026-11-15
**Contexto:** `dartssh2` pierde el `SSHHostkeyError` original cuando el rechazo
ocurre durante el handshake: `authenticated` falla con
`SSHAuthAbortError('Connection closed before authentication')`. Mapear por tipo
habría mostrado «no se pudo conectar» en un caso de posible MITM, y mapear por
texto habría dependido de mensajes de la librería.
**Decisión:** `mapSshError` traduce solo errores de red, autenticación y handshake
a `AppErrorCode`, sin propagar mensajes. La decisión sobre la host key la toma
`SshService` a partir del resultado del verificador (`lastAccepted` y `status`):
rechazo del usuario → `hostKeyRejected`; huella distinta → `hostKeyChanged`.
**Consecuencias:** el usuario ve la causa real aunque la librería la enmascare.
Un fallo de red ocurrido mientras el diálogo de huella está abierto sigue siendo
`networkUnreachable`, porque el verificador aún no tiene veredicto. Cubierto por
el test unitario del mapper y por el de integración de huella cambiada.

---

## D-016 — Tests de integración SSH: etiqueta, `.env.test` y omisión explícita
**Fecha:** 2026-11-15
**Contexto:** el servidor de pruebas es real y externo; CI sin red o un clon sin
`.env.test` no deben fallar por ello, pero tampoco deben fingir que probaron SSH.
**Decisión:** los tests viven en `test/features/ssh/ssh_integration_auth_test.dart`
y `ssh_integration_sessions_test.dart`, con la etiqueta `integration` (declarada en
`dart_test.yaml`) y un montaje común en `test/support/ssh_integration_harness.dart`.
`SshTestServer.load()` lee variables de entorno o `.env.test`; si faltan, el grupo
se marca `skip` con un motivo explícito. Operan solo dentro de
`~/opencode_sandbox/run_<uuid>/` y borran su rastro, incluida la llave pública
efímera de `authorized_keys`.
**Consecuencias:** `flutter test` ejercita red real cuando hay entorno;
`flutter test -x integration` es la ejecución offline. Ningún ítem se marca `[x]`
sin haber ejecutado la versión con red.

---

## D-017 — Importación de respaldos: validar, fotografiar y compensar
**Fecha:** 2026-11-15
**Contexto:** el estado vive en tres almacenes distintos (catálogo cifrado, una BD
cifrada por perfil y el almacén de secretos del sistema). No existe una
transacción ACID que los abarque, y el SPEC exige atomicidad y rollback probado.
Construir BDs nuevas en staging y luego intercambiar ficheros obliga a renombrar
directorios con la app abierta y a reescribir todas las claves de secretos; si el
intercambio falla a medias, el propio staging se convierte en el problema.
**Decisión:** validar el documento completo **antes** de tocar nada (versión,
tipos, UUIDs duplicados, datos huérfanos), tomar una fotografía en memoria del
estado actual (perfiles, datos y secretos) y aplicar los cambios. Ante cualquier
fallo, restaurar la fotografía: borrar lo presente y reconstruirlo desde memoria.
**Consecuencias:** el rollback está probado con un almacén de secretos que falla a
mitad (`test/features/backup/backup_test.dart`). La restauración reconstruye las
BDs con claves nuevas y reescribe secretos, así que es costosa en perfiles muy
grandes; se acepta porque una importación es una operación excepcional. No se
afirma atomicidad a nivel de disco: se garantiza que un fallo no deja perfiles a
medias ni credenciales huérfanas, que es el requisito verificable. Si en el futuro
se añade staging real, esta decisión se revisa con evidencia.

---

## D-018 — Cada conexión es SSH o SFTP; una vista a pantalla completa
**Fecha:** 2026-11-15 (decisión revisada a petición del usuario tras la primera
prueba manual)
**Contexto:** la primera implementación abría terminal y SFTP a la vez en un panel
dividido. En uso real el explorador ocupaba espacio que el terminal necesitaba y
la conexión no expresaba qué se quería hacer con el servidor.
**Decisión:** `Connection` gana `connectionType` (`ssh` | `sftp`), elegido en el
formulario. Al abrir una conexión se muestra **solo** su vista: terminal a pantalla
completa para SSH, explorador a pantalla completa para SFTP. Se elimina el panel
dividido y su divisor; en Android desaparecen las pestañas porque ya no hay dos
paneles que alternar.
**Migración:** esquema de perfil v2 añade `connections.connection_type` con
`DEFAULT 'ssh'` y `CHECK (connection_type IN ('ssh','sftp'))`, así que las filas
existentes siguen abriendo terminal como antes. Los respaldos pasan a
`formatVersion: 2`; los documentos v1 se aceptan y se migran a SSH al leerlos.
**Consecuencias:** una misma conexión ya no sirve para terminal y archivos; el
usuario crea dos si necesita ambas (verificado en el test de integración de
Windows). La barra de teclas táctil solo aparece en Android/iOS. La UI de escritorio
ya no tiene divisor que probar; `ResizableSplit` y `CompactTabs` se eliminaron.
**Verificación:** migración (`test/core/database/profile_migration_test.dart`),
respaldo v1 (`backup_test.dart`), formulario y vista
(`test/features/shell/shell_crud_test.dart`), y flujo real SSH/SFTP en Windows
(`integration_test/app_windows_test.dart`).

---

## D-019 — Entrada del terminal: eventos de teclado en escritorio, IME en móvil
**Fecha:** 2026-11-15
**Contexto:** en la primera prueba manual en Windows las letras no se escribían,
mientras Enter, flechas y teclas especiales sí. Diagnóstico: esas teclas ya pasan
por eventos de hardware de Flutter, mientras que xterm 4.0.0 inserta texto
imprimible a través de su `TextInputClient` (IME), que en Windows no entregaba los
caracteres.
**Decisión:** en escritorio `TerminalView` se crea con `hardwareKeyboardOnly:
true` (eventos de teclado y `character`, sin IME); en Android/iOS se mantiene el
camino IME y se añade la barra de teclas (que además escribe secuencias ANSI
directamente en el pty con `RemoteTerminal.send`). La barra no se muestra en
escritorio.
**Consecuencias:** letras, mayúsculas, números, símbolos, acentos compuestos por el
teclado y Ctrl+C llegan al pty en Windows (probado con eventos y con la app real).
La composición con IME de tildes depende del teclado del sistema en Android, que no
es verificable aquí. Pegar conserva el texto tal cual (los saltos de línea no se
traducen).
**Verificación:** `test/features/terminal/terminal_input_test.dart` (todas las
letras, dígitos, símbolos con Shift, acentos, Enter/Tab/flechas, Ctrl+C, pegar) y
`echo INTEGRATION-OK` tecleado en la app real de Windows.

---

## D-020 — Datos de desarrollo aislados por variables de entorno
**Fecha:** 2026-11-15
**Contexto:** el usuario borró sus datos de prueba tras una ejecución; los tests no
debían poder tocar el perfil real.
**Decisión:** `AppPaths.resolveFrom` acepta `SSH_CLIENT_DATA_DIR` y
`SecureStorageSecretStore` acepta `SSH_CLIENT_SECRET_NAMESPACE` (o se pasan
explícitamente). Los tests de integración usan un directorio temporal y un namespace
desechable, y los borran en `tearDown` incluso si el test falla. Cada `AppHarness` y
`TestContext` registra su limpieza en el momento de crear el directorio.
**Consecuencias:** ejecutar tests o la app con esas variables activas es seguro;
`tool/reset_dev_data.ps1` lista archivos y credenciales de la app antes de pedir
confirmación (`BORRAR`) y respeta ambas variables.
**Verificación:** script probado contra un directorio falso; el test de integración
de Windows crea y elimina su propio namespace y directorio.

---

## D-021 — Iconos Lucide centralizados en `AppIcons`
**Fecha:** 2026-11-15
**Contexto:** los iconos Material eran inconsistentes en trazo y tamaño, y cambiar
de librería obligaba a tocar decenas de widgets. Se evaluaron Lucide
(`lucide_icons_flutter` 4.0.3, MIT) y Phosphor (`phosphor_flutter` 2.1.0, MIT):
ambas empaquetadas como fuente, sin descargas en ejecución. Lucide tiene un solo
estilo coherente y un set suficiente para este producto.
**Decisión:** Lucide, con todos los iconos expuestos desde
`lib/app/theme/app_icons.dart` (`AppIcons`) y tamaños en `AppIconSize`. Ningún
widget importa la librería directamente.
**Consecuencias:** cambiar de set significa editar un archivo. Se añadió
`lucide_icons_flutter` a `THIRD_PARTY_NOTICES.md`. Los iconos decorativos siguen
usando `Semantics`/tooltips para su etiqueta.

---

## D-022 — Tema claro/oscuro/sistema con preferencia global (shared_preferences)
**Fecha:** 2026-11-15
**Contexto:** la pantalla de bloqueo aparece antes de abrir cualquier base de
perfil; guardar el tema por perfil obligaría a esperar al desbloqueo y produciría
parpadeos.
**Decisión:** `ThemeController` global persistido con `shared_preferences`
(`ui.themeMode` = system|light|dark y `ui.terminalAlwaysDark`). Se carga en
`main` **antes del primer frame**; sin preferencia se usa `ThemeMode.system`.
`AppThemeScope` expone el controlador a Ajustes y el `MaterialApp` cambia de tema
al instante con `themeAnimationDuration` de 220 ms. El terminal usa la paleta ANSI
de cada tema salvo que «Terminal siempre oscura» esté activo.
**Consecuencias:** nueva dependencia `shared_preferences` (BSD-3) en
`THIRD_PARTY_NOTICES.md`. Los tests usan `ThemeController.memory` o
`SharedPreferences.setMockInitialValues`; nunca tocan preferencias reales.

---

## D-023 — Sistema de diseño en `lib/app/theme` (solo presentación)
**Fecha:** 2026-11-15
**Contexto:** había colores y paddings escritos a mano en 14 widgets, un único
tema oscuro y ninguna garantía de contraste.
**Decisión:** paleta `AppPalette` clara y oscura construida a mano (no
`fromSeed`), `AppTokens` como `ThemeExtension` (espaciados, radios, duraciones,
curvas, estados y terminal) y component themes para todo lo usado. Los widgets
consumen `context.colors`, `context.texts` y `context.tokens`. Se añadieron tests
de contraste (4,5:1 texto, 3:1 componentes) y una matriz de pantallas en ambos
temas, tres tamaños y escala 1,3.
**Consecuencias:** ningún `Color(0x...)`/`Colors.white|black|grey` queda fuera de
`lib/app/theme`. Los golden tests se omitieron: en `flutter_test` las fuentes de
assets no se cargan por defecto (Ahem), así que no representarían la tipografía
real; la cobertura equivalente son los tests de layout, contraste y temas.
No se tocó lógica de negocio, seguridad, base de datos, SSH/SFTP ni navegación.

---

## D-024 — Claves de BD: crear y abrir son operaciones distintas
**Fecha:** 2026-11-15
**Contexto:** el bug reportado (hmac check failed tras importar y en cada
desbloqueo) exige que un archivo existente nunca reciba una clave recién generada.
El código anterior usaba `getOrCreate` al abrir; una clave ausente (namespace
distinto, reset parcial, restauración a medias) producía una clave nueva y la
apertura fallaba con SQLCipher sin explicación.
**Decisión:** `DatabaseKeyStore` expone `createCatalogKey`/`createProfileKey` y
`loadCatalogKey`/`loadProfileKey`. Reglas: archivo+clave → abrir; archivo sin clave
→ `databaseKeyMissing` sin generar; clave sin archivo → `databaseKeyOrphan` (solo
se limpia con el reset); longitud inválida → `databaseKeyInvalid`; clave correcta
en forma pero distinta de la del archivo → `databaseKeyMismatch`. La creación de
perfil genera clave, archivo cifrado y fila con compensación ante fallo.
`EncryptedDatabase` fija `cipher_compatibility = 4` y `cipher_page_size = 4096`
antes de aplicar la clave.
**Consecuencias:** un fallo de apertura es tipado y no sobrescribe datos ni claves.
Tests: `test/core/database/key_policy_test.dart`, migración y backup.

---

## D-025 — Importación con staging, verificación en frío y rollback
**Fecha:** 2026-11-15
**Contexto:** la importación anterior escribía directamente y usaba un snapshot en
memoria; no construía bases nuevas ni verificaba que las claves promovidas abrieran
los archivos. Un fallo a mitad podía dejar archivo y clave desalineados: el síntoma
del bug.
**Decisión:** `merge` solo escribe filas en bases existentes (transacción + snapshot
de filas/secretos). `replaceProfile`/`replaceAll`: construyen bases nuevas con claves
nuevas en `staging/<uuid>`, copian claves/credenciales a `staging/<uuid>/...` en el
almacén, mueven las bases actuales a `backup/<uuid>`, guardan las claves viejas en
`backup/<uuid>/...`, intercambian, promueven claves/credenciales y **reabren catálogo
y perfiles leyendo las claves del almacén** antes de borrar los backups. Cualquier
fallo revierte archivos, claves, credenciales y filas; los tests inyectan fallos en
staging y en la promoción de claves.
**Consecuencias:** el intercambio tiene más pasos y requiere que la UI cierre la
sesión del perfil abierto antes de reemplazar. Si el proceso muere a mitad, quedan
`staging/`/`backup/` y claves con prefijo propio; la pantalla de estado y el reset
las detectan y limpian. No quedan sidecars `-wal`/`-shm` de las bases antiguas
porque se mueve el directorio completo del perfil.

---

## D-026 — Reset completo y ubicación de datos
**Fecha:** 2026-11-15
**Contexto:** el usuario no necesita los datos actuales y el requisito es que la app
vuelva a "recién instalada" sin desactivar SQLCipher ni guardar claves en archivos.
**Decisión:** `AppResetService` borra `catalog.db` y sidecars, `profiles/`,
`staging/`, `backup/` y **solo** claves de este namespace (`catalog/`, `profile/`,
`staging/`, `backup/`, `__probe__`), enumerando claves exactas; nunca un
`deletePrefix('')` ni el Credential Manager completo. Si un archivo sigue abierto,
deja un marcador `reset.pending` que el siguiente arranque aplica antes de abrir
nada. En Windows los datos pasan a `%LOCALAPPDATA%\dev.sshclient\ssh_client`
(nunca Roaming: una carpeta itinerante viajaría sin sus claves). Los datos antiguos
en Roaming no se abren; la pantalla de estado los señala y el reset los elimina.
**Consecuencias:** cambiar de equipo se hace solo exportando e importando el JSON
(no cifrado; la contraseña del perfil verifica identidad, no cifra), nunca copiando
archivos. Android lleva `allowBackup=false` y reglas de exclusión para Android 12+.

---

## D-027 — Android: nada de la app viaja en copias ni transferencias
**Fecha:** 2026-11-15
**Decisión:** `android:allowBackup="false"`, `fullBackupContent` y
`dataExtractionRules` excluyen bases, preferencias y ficheros de la app. Copiar la
base sin su clave no sirve y restaurarla en otro dispositivo produce el hmac failure
descrito; por eso se bloquea en origen.
**Consecuencias:** no verificable sin SDK/dispositivo; revisado en manifiesto y XML.

---

## D-028 — Reset: sustituir el árbol antes de cerrar las bases
**Fecha:** 2026-11-15
**Contexto:** al probar el reset desde Ajustes, el diálogo seguía montado mientras
se cerraban y borraban las bases, y su reconstrucción consultaba el catálogo ya
cerrado (`Bad state: This database has already been closed`).
**Decisión:** `SshClientApp` marca `_resetting`, sustituye el árbol por una pantalla
de transición y espera al final del frame antes de cerrar servicios y borrar. Solo
después construye el grafo nuevo y vuelve al gate. `AppServices.dispose` es
idempotente y `SshClientApp.dispose` cierra el catálogo que posee.
**Consecuencias:** el reset con sesión abierta funciona y está cubierto por un widget
test; ningún widget toca una base cerrada durante la operación. La UI de la fase 1 de
esta ronda no se implementó (ver `ROADMAP.md`).

---

## D-029 — Almacén de claves en Windows y reset real
**Fecha:** 2026-11-15
**Contexto:** el reset de desarrollo no borraba nada y la app mostraba «No se pudo
abrir la base de datos cifrada del perfil». Diagnóstico con evidencia: los datos
viven en `%LOCALAPPDATA%\dev.sshclient\ssh_client` (desde D-026), mientras el script
miraba `%APPDATA%...\ssh_client`; y `flutter_secure_storage_windows` 4.x guarda los
secretos cifrados con DPAPI en `%APPDATA%\dev.sshclient\ssh_client\flutter_secure_storage.dat`,
no en Credential Manager. El catálogo existente se quedó sin su clave y el error
tipado se mostraba como mensaje genérico.
**Decisión:** el script de desarrollo usa LOCALAPPDATA, borra el `.dat` cuando no hay
namespace, y lista sidecars/staging/backup/preferencias. El reset in-app borra el
`.dat` solo si el namespace está vacío (en tests con namespace no se toca el archivo
compartido) y tolera errores del almacén al enumerar/borrar claves.
**Consecuencias:** un almacén corrupto ya no impide limpiar las bases; los tests con
namespace siguen aislados. Las credenciales del Credential Manager se siguen borrando
como respaldo para versiones antiguas del plugin.

---

## D-030 - Shell de la ronda 6: pestañas, sidebar y dashboard
**Fecha:** 2026-11-15
**Contexto:** la ronda 6 pide barra superior de pestañas con sesiones vivas, sidebar
de 220 px, dashboard de conexiones y vista de huellas, sin tocar la lógica de
negocio ni las claves que usan los tests.
**Decisión:**
- Cada conexión abierta tiene su propio `WorkspaceController` dentro de un
  `SessionTab`. Cambiar de pestaña solo cambia qué se pinta: el canal SSH, el pty
  y el subsistema SFTP siguen vivos hasta cerrar la pestaña, desbloquear o borrar
  la conexión. `ShellController.workspace` sigue devolviendo el workspace activo
  (o el del shell cuando no hay pestañas), así que el código y los tests previos no
  cambian.
- Las pestañas fijas son «Conexiones» (dashboard) y «SFTP» (explorador de la sesión
  activa). Si la sesión activa no es SFTP, la pestaña muestra un estado vacío: no se
  abre un canal SFTP nuevo sobre una sesión SSH, porque sería lógica nueva.
- La sidebar es solo navegación; el contenido (colecciones, servidores, acciones)
  pasa al dashboard. Se conservan todas las claves `Key(...)` de los tests
  (`new-connection-button`, `new-collection-button`, `connection-tile-*`,
  `connection-menu-*`, `collection-menu-*`, `sidebar-profile-name`,
  `open-settings`, `lock-session-button`).
- «Ajustes» abre el diálogo existente en lugar de una pantalla propia: duplicar en
  una página los respaldos, perfiles, reset y huellas añadiría riesgo sin cambiar
  el comportamiento.
- El contraído de la sidebar es estado de sesión (no persistido): no hay preferencia
  de usuario que justifique tocar el almacén todavía.
**Consecuencias:** una sesión por conexión, sin fugas al cambiar de pestaña; el
panel de detalles y el rediseño SFTP quedan como tareas siguientes en
`odd/tasks/ronda-6-gui.md`. Los tests de shell existentes pasan sin cambios.
