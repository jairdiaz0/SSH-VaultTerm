# DEVELOPMENT_PLAN — SSH Client

Estado de cada ítem:
- `[ ]` pendiente
- `[~]` implementado, sin verificar
- `[x]` verificado (evidencia en `docs/TESTING.md`)
- `[!]` bloqueado (causa anotada)

Entorno de esta máquina (ver `docs/DECISIONS.md` D-001): Flutter 3.47.9 / Dart
3.13.7 en Windows 11. **No hay Visual Studio C++ ni Android SDK**, así que no se
puede compilar ni ejecutar la app; la verificación se hace con `flutter analyze`
y `flutter test` (unitarios, widget, golden, FFI).

---

## Fase 0 — Auditoría
- [x] Inspeccionar el repositorio y estado de git (repo nuevo, solo `prompt.md`).
- [x] `flutter doctor -v`; identificar SO y plataformas compilables.
- [x] Crear `.env.test` y `.gitignore` (antes del primer commit).
- [x] Comprobar conectividad con el servidor de pruebas (`192.168.100.129:22`).
- [x] Auditar dependencias reales en pub.dev y sus licencias.
- [x] PoC de SQLite cifrado real (SQLCipher 4.20.0) — verificado.
- [!] PoC de `flutter_secure_storage` en ejecución: imposible sin plataforma compilable (D-001).
- [x] Proyecto Flutter creado con plataformas windows/android/linux/macos.
- [x] Documentos base: `AGENTS.md`, `docs/SPEC.md`, `docs/DECISIONS.md`, este plan, `docs/TESTING.md`, `THIRD_PARTY_NOTICES.md`.

## Fase 1 — Backend y seguridad
### Núcleo
- [x] `core/errors`: jerarquía de errores (`AppException`, códigos) y descripción segura sin mensajes de capas bajas.
- [x] `core/utils/logger`: logger sin secretos (nunca contraseñas, llaves, comandos ni salida de terminal).
- [x] `core/storage/app_paths`: rutas de datos por plataforma con `path_provider`, WAL/`-shm` incluidas al borrar.
- [x] `l10n` base: ARB en español (`lib/l10n/app_es.arb`), `gen-l10n` y `AppLocalizations` cableado en `MaterialApp`.
- [x] Tema oscuro base con la paleta del SPEC y componentes sin elevación ni gradientes.

### Secretos
- [x] Interfaz `SecretStore` + implementación en memoria (tests).
- [~] Implementación real sobre `flutter_secure_storage` 11.2.0 (no verificable en ejecución aquí, D-001).
- [x] Claves de BD: generación CSPRNG 32 bytes, lectura/escritura en Secure Storage, borrado por perfil.

### Base de datos cifrada
- [x] `EncryptedDatabase`: apertura con `PRAGMA key` en crudo, comprobación de `cipher_version`, cierre, borrado.
- [x] Migraciones con `PRAGMA user_version` y transacciones (catálogo y perfil); `schemaTooNew` para versiones futuras.
- [x] Esquema del catálogo (perfiles sin secretos, último perfil activo único, contadores de bloqueo).
- [x] Esquema por perfil (colecciones, conexiones, huellas conocidas, ajustes del perfil).
- [x] Repositorios: `ProfileRepository`, `CollectionRepository`, `ConnectionRepository`, `KnownHostRepository`.
- [x] Validación de pertenencia al perfil en cada operación (aislamiento real, no solo UI).

### Autenticación local
- [x] Argon2id (`cryptography`) en isolate, sal por perfil, parámetros persistidos.
- [x] Vectores de prueba y verificación/actualización de parámetros (vector de referencia `argon2-cffi`).
- [x] Servicio de autenticación: verificador, mensajes genéricos, retardo progresivo persistente.
- [x] Sesión: desbloquear, bloquear, cambiar de perfil, cerrar (y cerrar BD + limpiar memoria).
- [x] Creación de perfil restringida a sesión desbloqueada; nunca copia datos.
- [~] Interruptor de reautenticación por perfil: flag persistido (`settings.requireReauthOnEdit`) y
  `confirmPassword` listos; el control en Ajustes llega en la fase 4.

### Credenciales
- [x] `CredentialService` con namespace `profile/{profileId}/credential/{credentialId}`.
- [x] Sólo metadatos en SQLite; secretos exclusivamente en Secure Storage.
- [x] Borrado en cascada al borrar perfil/credencial (sin huérfanos).

### Shell de aplicación (adelanto de la fase 4)
- [x] Gate de sesión con los tres estados: sin perfiles (primer inicio), bloqueado, desbloqueado.
- [x] Pantalla de desbloqueo: último perfil, enlace discreto «Cambiar de perfil» (D-008), mensaje
  genérico de fallo y aviso de espera durante el bloqueo.
- [x] Asistente del primer perfil con validación local (nombre, longitud mínima, confirmación).
- [x] Home de solo lectura con colecciones, favoritos y conexiones reales del perfil + bloqueo de sesión.
- [x] Cierre de sesión real: cierra la BD del perfil y vuelve a la pantalla bloqueada.
- [!] Golden test con tipografías reales: requiere empaquetar Inter y JetBrains Mono (fase 4).

### Verificación de fase
- [x] Tests unitarios de perfiles, auth, aislamiento, colecciones, conexiones.
- [x] Tests de BD: cifrado efectivo, clave incorrecta, migraciones, persistencia, borrado.
- [x] Tests de UI: primera ejecución, bloqueo, desbloqueo, mensaje de fallo, cierre de sesión, tema.
- [x] `dart format .`, `flutter analyze`, `flutter test` en verde (82 tests).

## Fase 2 — Motor SSH
- [x] `SshService` con una única sesión `SSHClient` por conexión y canales separados.
- [x] TOFU: callback obligatorio, SHA-256, primera aceptación, comparación posterior, bloqueo si cambia.
- [~] Persistencia de huellas (`KnownHost`) por perfil y conexión; revisión y borrado desde UI
  (repositorio y verificación cubiertos por tests; pantalla en fase 4).
- [x] Autenticación por contraseña (credencial desde Secure Storage, cargada solo al conectar).
- [x] Autenticación por llave privada: importar archivo, passphrase, validación de formato, tipos soportados por `dartssh2` 4.1.0.
- [x] Estados de conexión: conectando, autenticando, esperando huella, conectado, desconexión inesperada.
- [x] Timeout, keep-alive, errores sin fuga de secretos, cierre ordenado de canales.
- [x] Primera conexión real al servidor de pruebas (test de integración etiquetado `integration`).

## Fase 3 — Terminal
- [ ] Integración de `xterm` con la shell/pty remota (flujo bidireccional).
- [ ] Redimensionado que envía el tamaño al servidor (`resizeTerminal`).
- [ ] Colores ANSI/256/true color, UTF-8, scrollback, selección/copia/pegado.
- [ ] Rendimiento con salida grande; nada de salida o comandos persistidos.
- [ ] Tests de widget del terminal; interactividad real marcada `[~]` si no se puede ejecutar.

## Fase 4 — UI de escritorio
- [ ] Tema completo y componentes reutilizables del SPEC.
- [ ] Fuentes Inter y JetBrains Mono empaquetadas como assets (OFL) + avisos.
- [ ] Sidebar con perfil, colecciones expandibles, servidores, favoritos, ajustes, indicador de conexión.
- [ ] CRUD de colecciones y conexiones desde UI con menús contextuales y reordenación.
- [ ] Workspace con terminal + SFTP y divisor redimensionable / maximizar panel.
- [ ] Arrastrar y soltar de entrada (SO → SFTP) con `desktop_drop`.
- [!] Arrastrar y soltar de salida (SFTP → SO): bloqueado por conflicto de dependencias (D-006).

## Fase 5 — SFTP
- [ ] Explorador remoto real: breadcrumbs, navegación, refrescar, permisos, ocultos, estados vacío/error/desconexión.
- [ ] Operaciones: listar, abrir, subir, descargar, crear carpeta, renombrar, eliminar (confirmación; recursivo seguro).
- [ ] Cola de transferencias por chunks con progreso, velocidad, cancelación, reintento y errores.
- [ ] Lógica POSIX propia para rutas remotas (sin `path` local).
- [ ] Integridad por checksum en tests contra el servidor de pruebas.

## Fase 6 — Backups
- [ ] Exportación JSON con advertencia bloqueante y confirmación explícita.
- [ ] Esquema versionado, validación estricta y migraciones.
- [ ] Importación con resumen previo y modos Fusionar / Reemplazar perfil / Reemplazar todo.
- [ ] Atomicidad con staging y rollback; prueba con fallos inyectados.

## Fase 7 — Android
- [ ] Drawer y workspace con pestañas Terminal/Archivos que conservan la sesión.
- [ ] Terminal móvil: teclado virtual, foco, scroll, selección, barra de teclas.
- [ ] SFTP táctil con menús y transferencias; selectores nativos.
- [ ] Tablets con `LayoutBuilder` y breakpoints por espacio.
- [!] Verificación en dispositivo: imposible aquí (sin Android SDK, D-001).

## Fase 8 — Revisión final
- [ ] `flutter pub get`, `dart format .`, `flutter analyze`, `flutter test` limpios.
- [ ] Tests de integración SSH/SFTP contra el servidor de pruebas.
- [ ] Compilar las plataformas posibles y documentar las no verificadas.
- [ ] Informe final de la sección 19 del SPEC.
