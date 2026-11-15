# DECISIONS — SSH Client

Decisiones técnicas con su justificación y evidencia. Formato: `D-XXX` con
fecha, contexto, decisión, consecuencias y verificación.

---

## D-001 — Entorno de verificación: sin compilador de escritorio ni Android SDK
**Fecha:** 2026-11-15
**Contexto:** `flutter doctor -v` en la máquina de desarrollo (Windows 11 26H2):
- Flutter 3.47.9 stable, Dart 3.13.7, `windows-x64`.
- **Visual Studio no instalado** → no se puede compilar `windows` desktop.
- **Android SDK no localizado** → no se puede compilar `android`.
- Chrome no instalado; Edge sí (web está fuera de alcance).
- `flutter test` y `flutter analyze` funcionan.

**Decisión:** se implementa y verifica con `dart format`, `flutter analyze`,
`flutter test` (unitarios, widget, golden y FFI) y tests de integración contra el
servidor de pruebas. Todo lo que exige ejecutar la app (plugins de plataforma,
keychain, drag and drop real, teclado virtual) se marca `[~]` o `[!]` con la
causa, nunca se simula.

**Consecuencias:**
- `flutter_secure_storage` **no se puede verificar en ejecución aquí**: es un
  plugin de plataforma y no hay binario ejecutable. Se implementa tras una
  interfaz `SecretStore` con implementación en memoria para tests.
- Para cerrar la verificación real, el usuario debe instalar el workload
  «Desktop development with C++» de Visual Studio (Windows) y/o el Android SDK.
- El aviso de `flutter pub get` «Building with plugins requires symlink support»
  (Developer Mode de Windows desactivado) no bloquea `pub get`, `analyze` ni
  `test`; sí afectaría a la compilación de plugins de escritorio.

**Verificación:** salida de `flutter doctor -v` y `flutter test` (ver
`docs/TESTING.md`).

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

**Verificación pendiente:** `flutter analyze` actual pasa con `xterm` 4.0.0 como
dependencia; la integración funcional se prueba en la fase 3.

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
**Fecha:** 2026-11-15 (decisión inicial; se cierra en fase 1)
**Decisión propuesta:** Argon2id con `cryptography` 2.9.0 ejecutado en un
isolate (Dart puro, coste alto), sal aleatoria de 16 bytes por perfil y
parámetros almacenados junto al verificador para poder migrarlos. Alternativa
documentada si el rendimiento en móvil es inaceptable: PBKDF2-HMAC-SHA256 con
≥600 000 iteraciones.
**Pendiente:** validar con vectores de prueba conocidos (RFC 9106) en fase 1.

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
**Fecha:** 2026-11-15 (decisión inicial para la fase 1)
**Decisión propuesta:**
```text
<appSupport>/ssh_client/
  catalog.db                 # cifrada: perfiles (sin secretos) + metadatos
  profiles/<profileId>/data.db  # cifrada: colecciones, conexiones, known hosts
```
Claves en Secure Storage:
- `catalog/key`
- `profile/<profileId>/dbKey`
- `profile/<profileId>/credential/<credentialId>`
Ningún secreto en SQLite. Las claves nunca se escriben en disco ni en logs.
**Pendiente:** confirmar rutas por plataforma con `path_provider` en fase 1.
