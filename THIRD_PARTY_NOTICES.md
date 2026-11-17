# THIRD_PARTY_NOTICES — SSH-VaultTerm

Registro de dependencias de terceros: versión, licencia y motivo. Se actualiza
cuando se añade o retira una dependencia.

Regla del proyecto: no se aceptan dependencias con licencia AGPL/GPL o con
licencia incompatible con uso comercial cerrado. Todas las listadas son
permisivas (MIT, BSD-2, BSD-3, Apache-2.0, OFL-1.1).

## Dependencias directas

| Paquete | Versión | Licencia | Uso |
|---|---|---|---|
| `dartssh2` | 4.1.0 | MIT | Cliente SSH/SFTP en Dart puro. Sesión única con canales separados para shell y SFTP. |
| `xterm` | 4.0.0 | MIT | Emulador de terminal VT/ANSI para Flutter. |
| `flutter_secure_storage` | 11.2.0 | BSD-3-Clause | Almacén de secretos del sistema (Credential Manager/DPAPI, Keychain, libsecret). |
| `cryptography` | 2.9.0 | Apache-2.0 | Argon2id para el verificador de contraseña de perfil y utilidades criptográficas. |
| `sqlite3` | 3.9.1 | MIT | Enlaces FFI a SQLite. Compilado con **SQLCipher 4.20.0 community** mediante el hook `source: sqlcipher`. |
| `path_provider` | 2.1.6 | BSD-3-Clause | Directorios de datos de la aplicación. |
| `path` | 1.9.1 | BSD-3-Clause | Manipulación de rutas **locales**. Las rutas remotas usan lógica POSIX propia. |
| `uuid` | 4.6.0 | MIT | Identificadores UUID v4 de perfiles, colecciones, conexiones y credenciales. |
| `file_picker` | 13.3.3 | MIT | Selector nativo de archivos (importar llaves, subir archivos a SFTP). |
| `desktop_drop` | 0.8.4 | Apache-2.0 | Recepción de arrastrar y soltar del SO en los paneles (entrada). |
| `intl` | 0.20.3 | BSD-3-Clause | Localización y formateo. |
| `material_ui` | 1.11.0 | BSD-3-Clause | Widgets Material de Flutter 3.50 (`package:flutter/material.dart` quedó deprecado). |
| `cupertino_ui` | 1.1.6 | BSD-3-Clause | Widgets y localizaciones Cupertino del paquete nuevo. |
| `lucide_icons_flutter` | 4.0.3 | MIT | Iconos Lucide empaquetados como fuente; sin descargas en ejecución. |
| `shared_preferences` | 2.5.4 | BSD-3-Clause | Persistencia global del tema (ui.themeMode, ui.terminalAlwaysDark). |

## Dependencias transitivas relevantes

| Paquete | Versión | Licencia | Nota |
|---|---|---|---|
| `pointycastle` | 4.0.0 | MIT (Bouncy Castle) | Criptografía usada por `dartssh2`. |
| `pinenacl` | 0.6.0 | MIT | Ed25519 usado por `dartssh2`. |
| `asn1lib` | 1.6.8 | BSD-2-Clause | Codificación ASN.1 en `dartssh2`. |
| `zmodem` | 0.0.6 | MIT | Transferencias ZMODEM opcionales de `xterm`. |
| `ffi` | 2.2.0 | BSD-3-Clause | Enlaces nativos. |
| `win32` | 6.4.0 | BSD-3-Clause | API Win32 usada por `flutter_secure_storage` y `file_picker`. |

## Componentes nativos empaquetados

| Componente | Versión | Licencia | Nota |
|---|---|---|---|
| SQLCipher (`libsqlcipher`) | 4.20.0 community | BSD-style (Zetetic) | Se descarga precompilado desde las releases de `sqlite3.dart` durante el build. Nunca SQLite sin cifrar. |
| SQLite (base de SQLCipher) | 3.54.x | Public Domain | Incluida dentro de SQLCipher. |
| OpenSSL (usado por SQLCipher) | 4.0.3 | Apache-2.0 | Vinculado dentro del binario de SQLCipher que publica `sqlite3.dart`. |

## Fuentes empaquetadas (assets, nunca descargadas en ejecución)

| Fuente | Versión | Licencia | Ficheros |
|---|---|---|---|
| Inter | 4.1 | SIL Open Font License 1.1 | `assets/fonts/Inter-{Regular,Medium,SemiBold,Bold}.ttf` |
| JetBrains Mono | 2.304 | SIL Open Font License 1.1 | `assets/fonts/JetBrainsMono-{Regular,Bold}.ttf` |

Los textos completos de ambas licencias están junto a los ficheros
(`assets/fonts/LICENSE-Inter.txt`, `assets/fonts/LICENSE-JetBrainsMono.txt`).
No se usa `google_fonts` ni ninguna descarga en tiempo de ejecución.

## Dependencias evaluadas y descartadas

| Paquete | Motivo del descarte |
|---|---|
| `sqlite3_flutter_libs` 0.6.0+eol | Marcado EOL por su autor; el hook de `sqlite3` 3.x lo sustituye. |
| `sqlcipher_flutter_libs` 0.7.0+eol | Marcado EOL por su autor. |
| `file_selector` 1.1.0 | Su interfaz de plataforma fija `cross_file ^0.3.0`; no aporta nada sobre `file_picker` aquí. |
| `super_drag_and_drop` 0.9.1 | No resuelve junto a `flutter_secure_storage` 11.x (conflicto `win32`). Se reevaluará en la fase de escritorio con `0.10.0-dev.2`. |
| `desktop_drop` 0.9.x | Exige `cross_file ^0.4.0`; ningún selector mantenido lo soporta aún. |
| `drift` / `drift_flutter` | Ver `docs/DECISIONS.md` (D-004): se usa `sqlite3` directo para control total del cifrado y las migraciones. |
| `google_fonts` | Prohibido: descarga recursos en tiempo de ejecución. |