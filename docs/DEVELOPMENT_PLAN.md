# DEVELOPMENT_PLAN — SSH Client

Estado de cada ítem:
- `[ ]` pendiente
- `[~]` implementado, sin verificar
- `[x]` verificado (evidencia en `docs/TESTING.md`)
- `[!]` bloqueado (causa anotada)

Entorno de esta máquina (ver `docs/DECISIONS.md` D-001 y D-032): Flutter 3.50.0
stable / Dart 3.14.0 en Windows 11 26H2. Visual Studio 2026 con C++ instalado
permite `flutter build windows`; **hay Android SDK 36 con emulador API 37**, así
que Windows y Android se compilan y se verifican; macOS y Linux no se pueden
compilar aquí. La verificación principal es `flutter analyze`, `flutter test` y
los tests de integración contra el servidor de pruebas.

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
- [x] Interruptor de reautenticación por perfil: flag persistido
  (`settings.requireReauthOnEdit`), control en Ajustes y petición de contraseña al
  guardar conexiones o credenciales (probado).

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
- [x] Integración de `xterm` con la shell/pty remota (flujo bidireccional).
- [x] Redimensionado que envía el tamaño al servidor (`resizeTerminal`).
- [~] Colores ANSI/256/true color, UTF-8, scrollback, selección/copia/pegado
  (emulador, UTF-8 real y scrollback cubiertos; selección/copia/pegado llegan con
  el workspace de la fase 4).
- [~] Rendimiento con salida grande; nada de salida o comandos persistidos
  (no se persiste nada por diseño; falta medir el rendimiento en la UI real).
- [x] Tests de widget del terminal; interactividad real marcada `[~]` si no se puede ejecutar.

## Fase 4 — UI de escritorio
- [x] Tema completo y componentes reutilizables del SPEC.
- [x] Fuentes Inter y JetBrains Mono empaquetadas como assets (OFL) + avisos.
- [x] Sidebar con perfil, colecciones expandibles, servidores, favoritos, ajustes, indicador de conexión.
- [x] CRUD de colecciones y conexiones desde UI con menús contextuales y reordenación
  (menú Subir/Bajar, accesible por teclado; arrastre de elementos no implementado).
- [x] Workspace que muestra solo la vista del tipo de conexión: terminal a pantalla
  completa (SSH) o explorador a pantalla completa (SFTP); sin panel dividido (D-018).
- [~] Arrastrar y soltar de entrada (SO → SFTP) con `desktop_drop` (destino de
  arrastre y manejador probados; el arrastre real del SO no es ejecutable aquí).
- [!] Arrastrar y soltar de salida (SFTP → SO): bloqueado por conflicto de dependencias (D-006).

## Fase 5 — SFTP
- [x] Explorador remoto real: breadcrumbs, navegación, refrescar, permisos, ocultos, estados vacío/error/desconexión.
- [x] Operaciones: listar, abrir, subir, descargar, crear carpeta, renombrar, eliminar (confirmación; recursivo seguro).
- [x] Cola de transferencias por chunks con progreso, velocidad, cancelación, reintento y errores.
- [x] Lógica POSIX propia para rutas remotas (sin `path` local).
- [x] Integridad por checksum en tests contra el servidor de pruebas.

## Fase 6 — Backups
- [x] Exportación JSON con advertencia bloqueante y confirmación explícita.
- [~] Esquema versionado y validación estricta (rechaza versiones futuras; aún no hay
  migración de documentos v0 → v1 porque solo existe la v1).
- [x] Importación con resumen previo y modos Fusionar / Reemplazar perfil / Reemplazar todo.
- [~] Atomicidad con rollback verificado por fallo inyectado (la sustitución usa
  snapshot + compensación en vez de staging de ficheros; ver D-017).

## Fase 7 — Android
- [x] Drawer y workspace que muestra la vista del tipo de conexión (terminal o
  archivos), conservando la sesión al navegar (D-018: ya no hay pestañas dobles).
- [~] Terminal móvil: teclado virtual, foco, scroll, selección, barra de teclas
  (barra de teclas implementada y probada; teclado, scroll y selección requieren
  dispositivo real).
- [~] SFTP táctil con menús y transferencias; selectores nativos (menús y cola
  compartidos y probados; selectores nativos no ejecutables aquí).
- [x] Tablets con `LayoutBuilder` y breakpoints por espacio, no por tipo de dispositivo.
- [!] Verificación en dispositivo: imposible aquí (sin Android SDK, D-001).

## Ronda de correcciones 1 (tras la primera prueba manual en Windows)

- [x] Tipo de conexión SSH/SFTP con migración v2, formulario, respaldos v2 (lee v1) y
  vista única por tipo (D-018).
- [x] Teclado del terminal en Windows: letras, mayúsculas, números, símbolos, tildes,
  Ctrl+C y pegar llegan al pty; la barra táctil solo aparece en Android/iOS (D-019).
- [x] Fin de sesión: overlay «Sesión finalizada» con Reconectar y Cerrar, canal cerrado
  y `SSHClient` liberado; estado del sidebar actualizado.
- [x] Ruta SFTP: una sola barra de breadcrumbs editable al pulsar el espacio libre o
  Ctrl+L; animaciones de 150–250 ms en cambio de carpeta, filas y progreso.
- [x] Layout: tokens de espaciado (4/8/12/16/24), padding del pie corregido, tamaño
  mínimo de ventana (900×600) y tests de overflow a 900×600, 1280×720 y 1920×1080.
- [x] Gestión de perfiles en Ajustes: crear, cambiar y eliminar con contraseña; la
  pantalla bloqueada mantiene «Cambiar de perfil» sin crear.
- [x] Datos aislados: `SSH_CLIENT_DATA_DIR` y `SSH_CLIENT_SECRET_NAMESPACE`, limpieza
  garantizada de directorios temporales y `tool/reset_dev_data.ps1` con confirmación.
- [x] Verificación real en Windows: `flutter build windows --release` y
  `flutter test integration_test -d windows` con almacén seguro y BD cifrada reales.
- [!] Android/macOS/Linux: sin toolchain aquí (D-001). Sin verificar en ejecución.

## Ronda 6 (GUI) - estado

Detalle de tareas y especificaciones: `odd/tasks/ronda-6-gui.md`.

- [x] Reset de la aplicación verificado con el flujo real de UI: el árbol se
  sustituye antes de cerrar las bases, se reconstruye el grafo de servicios y se
  vuelve al asistente del primer perfil (`test/app/app_reset_flow_test.dart`).
- [x] Reset con catálogo corrupto, sin abrir ninguna base.
- [x] Marcador de reset pendiente aplicado antes de abrir bases.
- [x] Solo se borran secretos con prefijos de SSH Client; otros namespaces intactos.
- [x] Paleta neutra de la ronda 6, radios 12/10/8, acento `#2563EB`/`#3B82F6`,
  estados y terminal siempre oscura; contraste AA verificado
  (`test/app/theme_test.dart`, `test/app/theme_contrast_test.dart`).
- [x] Barra superior de 44 px con la vista fija «Conexiones» y una pestaña por
  sesión, con cierre individual y sesiones que siguen vivas al cambiar de
  pestaña (`test/features/shell/shell_tabs_test.dart`).
- [x] Sidebar de 220 px contraíble a barra de iconos, con «Conexiones»,
  «Huellas» y «Ajustes», y perfil/bloqueo al pie; cajón en ventanas estrechas.
- [x] Dashboard de conexiones: buscador, filtros por etiqueta, vista
  cuadrícula/lista, orden por nombre/host/recientes, secciones «Favoritos»,
  «Colecciones» y «Sin colección», tarjetas con menú de editar/favorito/eliminar
  (`test/features/shell/dashboard_test.dart`).
- [x] Vista de huellas conocidas en el área principal con borrado por huella.
- [ ] Panel de detalles de conexión de 360–400 px que sustituya al diálogo de
  edición (conservando validación y reautenticación).
- [ ] Rediseño SFTP de un panel (tabla, selección múltiple, menú contextual,
  chmod y cola de transferencias rediseñada).
- [ ] Quick connect y badges de sistema operativo: requieren credencial efímera
  y `osHint` en el modelo; ver `docs/ROADMAP.md`.
- [ ] Fases 4 y 5 (opcionales): no evaluadas.
- [!] Android: sigue sin toolchain para compilar.

## Ronda 6 (GUI) - correcciones de la prueba manual

Verificación: `flutter analyze` limpio, `flutter test -x integration` → +291,
`flutter test integration_test -d windows` → +2 contra `192.168.100.129`
(usuario `agente_test`), y arranque real del binario en Windows.

- [x] Pestaña fija «SFTP» eliminada: solo queda «Conexiones» como vista fija.
- [x] Pestaña de sesión ajustada al contenido: icono, punto de estado, nombre y
  cierre a la derecha, sin espacio sobrante (`test/features/shell/shell_tabs_test.dart`).
- [x] **Huella no solicitada**: el diálogo se abría con el contexto de la tarjeta
  del dashboard, que se desmonta al mostrar la pestaña de la sesión; ahora se usa
  el contexto del navegador. Test que falla con el código anterior y pasa con el
  nuevo (`test/features/shell/host_key_prompt_test.dart`).
- [x] Switches visibles en claro y oscuro: pulgar y contorno con el color de texto
  secundario (apagado) y relleno de acento con pulgar claro (encendido); contraste
  ≥ 3:1 comprobado en `test/app/theme_contrast_test.dart`.
- [x] **Restablecer la aplicación**: `main` no pasaba la fábrica de servicios, así
  que el reset lanzaba `reset unavailable` y no borraba nada. Ahora
  `SshClientApp.rebuildServices` es obligatorio (error de compilación si falta) y
  la ruta del almacén DPAPI se calcula con `windowsSecretStoreFile`, con test.
- [x] Iconos de exportar/importar intercambiados: exportar sube (`upload`),
  importar baja (`download`), con test (`test/features/settings/settings_icons_test.dart`).
- [x] Script de reset: se niega a ejecutarse con la app abierta, verifica lo
  borrado y sale con error si queda algo. Probado con la app abierta (rechaza) y
  cerrada (borra catálogo, perfiles, DPAPI y preferencias; el arranque siguiente
  crea un catálogo nuevo con `profiles/` vacío).
- [x] El puerto escrito en el formulario se usa al conectar (`ssh_service_port_test`)
  y el tipo SSH/SFTP decide terminal o explorador (integración real).
- [x] Validación por campo en el formulario de conexión (nombre, host, puerto,
  usuario y credencial), en el asistente del primer perfil y en los diálogos de
  nombre del SFTP; los errores de servicio se muestran como aviso con icono.
- [x] Cerrar una sesión finalizada cierra su pestaña y vuelve al dashboard.
- [ ] Panel de detalles de conexión de 360–400 px.
- [ ] Rediseño SFTP de un panel (tabla, selección múltiple, chmod).
- [ ] Quick connect y badges de sistema operativo (`osHint` en el modelo).

## Ronda 4 (integridad de almacenamiento y terminal)

- [x] Causa raíz del hmac: separación crear/abrir claves, errores tipados
  (`databaseKeyMissing`/`Orphan`/`Invalid`/`Mismatch`) y parámetros de cifrado fijos.
- [x] Importación con staging, copias `.bak` de archivos y claves, verificación en
  frío y rollback probado con fallos inyectados.
- [x] Reset completo (catálogo, perfiles, sidecars, staging, backup y solo claves
  propias) con confirmación fuerte + contraseña, estado del almacenamiento y
  marcador para el siguiente arranque.
- [x] Windows en `LOCALAPPDATA`; Android sin backup ni transferencia de datos.
- [x] Paleta ANSI por tema con contraste ≥4,5:1 y verificación de 256/true color;
  `xterm-256color` en el pty.
- [ ] «Activar colores en esta sesión» (detectar shell y enviar comandos): pendiente.
- [ ] Resaltado inteligente de terminal (2.3): pendiente; la API de celdas existe
  (`setForeground`), no se ha implementado ni probado.
- [ ] Rediseño de la Parte 3 (navegación, tarjetas, buscador, cuadrícula, pestañas
  multi-sesión): pendiente.
- [ ] Parte 4 (estrés SFTP 50 MiB, fuzz adicional, autobloqueo, huellas en la
  navegación): pendiente.

## Ronda 3 (seguridad adicional y modernización de UI)

- [x] Reautenticación de acciones sensibles en la capa de servicio: interruptor de
  reautenticación y exportación de respaldos exigen contraseña verificada con el
  mismo Argon2id y el bloqueo persistente; sin caché ni archivos temporales.
- [x] Diálogo reutilizable de confirmación de contraseña en los tres flujos.
- [x] Sistema de diseño en `lib/app/theme`: paletas clara/oscura a mano, tokens
  (espaciados, radios, duraciones, curvas, estados, terminal) y component themes.
- [x] Tema Sistema/Claro/Oscuro persistido globalmente y terminal siempre oscura.
- [x] Iconos Lucide centralizados en `AppIcons`.
- [x] Componentes reutilizables `EmptyState`, `StatusBadge` y ajustes de
  accesibilidad (SafeArea, 48 dp, tooltips semánticos).
- [x] Tests de contraste AA, matriz de pantallas (2 temas × 3 tamaños × 1,3 texto)
  y persistencia del tema.
- [x] `flutter build windows --release` e integración real en Windows tras la UI.
- [ ] Golden tests: omitidos con motivo (fuentes de assets no cargadas en
  `flutter_test`); ver `docs/UI_AUDIT.md` y `docs/TESTING.md`.
- [!] Android/macOS/Linux: sin toolchain aquí; UI móvil solo con widget tests.

## Fase 8 — Revisión final
- [x] `flutter pub get`, `dart format .`, `flutter analyze`, `flutter test` limpios.
- [x] Tests de integración SSH/SFTP contra el servidor de pruebas.
- [x] Compilar las plataformas posibles: Windows (exe + instalador) y Android
  (APK universal y por ABI) compilados y ejecutados. macOS y Linux siguen sin
  toolchain aquí (D-001, D-032). Evidencia en `docs/TESTING.md` y `docs/BUILD.md`.
- [x] Informe final de la sección 19 del SPEC (`docs/FINAL_REPORT.md`).

## Ronda de empaquetado (iconos, builds e instalador)

- [x] Iconos generados desde `icons/terminal-icon.svg` con placa clara para no
  perderse en modo oscuro (`tool/build_icons.ps1`).
- [x] `.ico` de Windows con 9 tamaños, entradas DIB, todas legibles por el
  cargador del sistema.
- [x] Icono adaptativo de Android con capas `background`, `foreground` y
  `monochrome`, más `mipmap` heredados para API 24-25.
- [x] `FileDescription` y título de ventana a «SSH Client»; `CompanyName` y
  `ProductName` intactos para no mover los datos del usuario (D-032).
- [x] Etiqueta de Android «SSH Client».
- [x] Instalador de Inno Setup por usuario, con `AppId` fijo, versión leída del
  `VERSIONINFO` y tarea opcional «Empezar de cero».
- [x] Instalación y desinstalación silenciosas verificadas de extremo a extremo.
- [x] APK instalado y arrancado en emulador API 37; icono comprobado en la
  pantalla de recientes.
- [x] `tool/build_release.ps1` para reproducir los artefactos.
- [x] `docs/BUILD.md` con el procedimiento y lo que se verificó.
- [!] Firma de release de Android: pendiente de un keystore propio. Hoy se firma
  con la clave de depuración, suficiente para probar y no para publicar.
- [!] macOS y Linux: sin toolchain en este entorno.
