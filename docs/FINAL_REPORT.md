# Informe final (SPEC §19)

Fecha: 2026-11-15. Repositorio local, rama `main`, sin push.

## 1. Resumen

Cliente SSH/SFTP de escritorio y Android construido con Flutter, local-first (sin
cuentas, sin sincronización, sin telemetría), con catálogo y bases de datos por
perfil cifradas con SQLCipher, credenciales en el almacén secreto del sistema,
TOFU de host keys, terminal real sobre pty, explorador SFTP con cola de
transferencias, copias de seguridad JSON con importación transaccional y una
interfaz de escritorio y móvil derivada del espacio disponible.

`flutter analyze` sin incidencias y **256 tests** en verde, incluidos SSH, pty y
SFTP reales contra el servidor de pruebas y un **test de integración sobre la app
real compilada para Windows** (almacén seguro y SQLCipher reales). Windows compila
en release (`build\windows\x64\runner\Release\ssh_client.exe`); Android, macOS y
Linux siguen sin toolchain en este entorno (D-001) y se declaran no verificados.

## 2. Funcionalidades implementadas

| Área | Estado |
| --- | --- |
| Perfiles: primer inicio, último perfil, desbloqueo, cambio, borrado | Implementado y probado |
| Catálogo y BD por perfil cifradas (SQLCipher 4.20.0, clave CSPRNG por BD) | Implementado y probado (incluye cifrado efectivo en disco) |
| Credenciales en Secure Storage con namespace por perfil | Implementado; ejecución del plugin no verificable aquí |
| Argon2id con sal por perfil y parámetros persistidos | Verificado contra vector de `argon2-cffi` |
| Bloqueo progresivo persistente | Implementado y probado |
| Reautenticación al editar conexiones/credenciales | Implementado y probado |
| SSH: contraseña y llave privada, TOFU SHA-256, estados, timeouts, keep-alive, cierre ordenado | Implementado y probado contra servidor real |
| Terminal: pty real, UTF-8, colores ANSI, scrollback, resize, barra de teclas | Motor y barra probados; teclado/scroll/selección táctil sin dispositivo |
| SFTP: navegación, operaciones, cola con progreso/cancelación/reintento, checksum | Implementado y probado contra servidor real |
| UI escritorio: sidebar, CRUD, workspace con divisores | Implementado y probado; sustituido por vista única SSH/SFTP (D-018) |
| UI Android: drawer, vista única por tipo, breakpoints por espacio | Implementado y probado en widget tests |
| Backups: exportar con advertencia, importar con 3 modos, rollback | Implementado y probado; selectores nativos sin ejecutar |
| Gestión de perfiles en Ajustes (crear, cambiar, eliminar con contraseña) | Implementado y probado |
| Reautenticación de acciones sensibles en servicios (interruptor y exportación) | Implementado y probado |
| Temas claro/oscuro/sistema persistidos, terminal por tema y siempre oscura | Implementado y probado |
| Sistema de diseño y iconos Lucide centralizados (`AppIcons`) | Implementado; contraste y layout testeados |
| Datos aislados por entorno y `tool/reset_dev_data.ps1` | Implementado y probado el script con datos falsos |
| Entrada de terminal en Windows (letras, símbolos, Ctrl+C, pegar) | Verificado con eventos y con la app real |

## 3. Arquitectura

Feature-first con capas `domain/` (reglas puras), `data/` (servicios y
repositorios) y `presentation/` (widgets y estado de pantalla); `core/` solo
infraestructura y `app/` como composition root. Detalle en
`docs/ARCHITECTURE.md`.

Decisiones relevantes, con su motivo y consecuencias, en `docs/DECISIONS.md`
(D-001…D-017): SQLCipher vía hook de `sqlite3`, sin Drift, Argon2id en isolate,
TOFU con la huella que ya entrega `dartssh2` 4.1.0, `xterm` verificado y su límite
de scrollback, backups con snapshot y compensación, y análisis estático estricto.

## 4. Dependencias y licencias

Todas permisivas (MIT, BSD, Apache-2.0, OFL-1.1); ninguna AGPL/GPL. Lista
completa en `THIRD_PARTY_NOTICES.md`. Fuentes Inter y JetBrains Mono empaquetadas
como assets con sus licencias; no se descarga nada en ejecución.

## 5. Pruebas y resultados

```text
dart format .     → 0 cambios
flutter analyze   → No issues found!
flutter test      → +187 All tests passed!
```

Cobertura por área (detalle y evidencia en `docs/TESTING.md`):

- Unitarios: perfiles, autenticación, bloqueo, aislamiento, cifrado, migraciones,
  credenciales, logger, reglas POSIX, entradas remotas, cola de transferencias,
  documento de respaldo y su rollback.
- Widget: gate de sesión, primer inicio, bloqueo, shell, CRUD con credenciales,
  reautenticación, gestión de perfiles, workspace, panel SFTP con ruta editable,
  tamaños de ventana sin overflow, barra de teclas, entrada del terminal, tema y
  fuentes. Matriz completa de pantallas en tema claro y oscuro, 900×600,
  1280×720 y 1920×1080 con escala de texto 1,3.
- Integración real (etiqueta `integration`, se omite sin `.env.test`): SSH con
  contraseña y llave, TOFU aceptado y bloqueado, contraseña incorrecta, sesiones
  concurrentes, pérdida de transporte, pty con resize y UTF-8, y SFTP con 2 MiB y
  SHA-256 coincidente, borrado recursivo y cola completa.
- Integración de la app real en Windows: perfil, conexión SSH tecleada, `exit`,
  «Sesión finalizada», y conexión SFTP separada con navegación.

## 6. Plataformas compiladas de verdad y no verificadas

- **Windows**: compilado en release y ejecutado por
  `integration_test/app_windows_test.dart -d windows` (perfil, SSH real con tecleo,
  fin de sesión, SFTP real). Almacén seguro verificado con Credential Manager.
- **Android, macOS y Linux**: no compilados aquí (sin SDK toolchains). No
  verificados en ejecución.
- **No verificadas en ejecución:** arrastre real del sistema operativo; teclado
  virtual y selección táctil de Android; selectores nativos de archivos; golden
  tests (omitidos porque `flutter_test` no carga las fuentes de assets por
  defecto; ver `docs/UI_AUDIT.md`).

## 7. Limitaciones declaradas

- **Drag and drop de salida** (SFTP → SO): bloqueado por conflicto de
  dependencias (D-006). No se simula.
- **Backups**: no hay migración de documentos de versiones anteriores (solo
  existe la v1); la atomicidad se garantiza con snapshot y compensación, no con
  staging de ficheros (D-017). Si la importación reemplaza el perfil abierto, la
  sesión se bloquea antes; un fallo en ese camino queda en el log técnico y el
  estado se restaura.
- **Terminal**: selección, copia/pegado desde la UI y rendimiento con salidas muy
  grandes no se han podido medir aquí.
- **Memoria y secretos**: el borrado en memoria es de mejor esfuerzo; las
  `String` de Dart no se pueden sobrescribir.
- **Contraseña del perfil**: no deriva claves; protege la interfaz, no la BD si
  alguien obtiene la clave del almacén del sistema.

## 8. Pendientes concretos

1. Compilar y ejecutar en Android, macOS y Linux; validar teclado virtual,
   selección táctil, selectores nativos y almacén seguro en cada plataforma.
2. Arrastrar y soltar de salida: bloqueado por dependencias (D-006).
3. Composición de tildes mediante IME en Android: depende del teclado del sistema.
4. Migración de documentos de respaldo cuando exista una v3.
5. Evaluar `xterm2` si se permite configurar scrollback por debajo de la altura
   visible (límite documentado de `xterm` 4.0.0).
6. Golden tests con las fuentes reales por plataforma.

## 9. Comandos exactos

```sh
flutter pub get
flutter gen-l10n          # tras editar lib/l10n/app_es.arb
dart format .
flutter analyze
flutter test              # incluye integración si existe .env.test
flutter test -x integration   # sin red
flutter build windows --release   # verificado en esta máquina
flutter test integration_test/app_windows_test.dart -d windows   # app real en Windows
powershell -File tool/reset_dev_data.ps1   # borra datos de desarrollo (pide BORRAR)
flutter build apk         # requiere Android SDK (no disponible aquí)
```

`.env.test` (ignorado por git) define `SSH_TEST_HOST`, `SSH_TEST_PORT`,
`SSH_TEST_USER` y `SSH_TEST_PASSWORD`. Los tests de integración operan solo en
`~/opencode_sandbox/run_<uuid>/` y borran su rastro.
