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

### Aislamiento entre perfiles — `test/core/session/profile_session_test.dart`
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

## Pendiente de verificación (bloqueado por el entorno, D-001)
- `flutter_secure_storage` en ejecución: plugin de plataforma; no hay app
  ejecutable en esta máquina. Marcado `[~]`.
- Compilación Windows/Linux/macOS/Android y ejecución real de la app.
- Drag and drop real, teclado virtual, terminal y SFTP: dependen de ejecución.
- Golden tests con tipografías reales: pendiente de empaquetar los assets (fase 4).
