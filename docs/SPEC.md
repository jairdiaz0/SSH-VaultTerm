# SPEC — SSH Client

## 1. Producto
Cliente SSH/SFTP multiplataforma, minimalista, rápido y seguro, de estética profesional tipo Termius pero con identidad propia (sin copiar marca ni logotipos). Nombre provisional: `SSH Client`.

Principios: local, sin cuentas, sin sincronización, sin backend propio, sin telemetría, sin publicidad, solo SSH y SFTP, almacenamiento local seguro, arquitectura extensible. La red solo se usa para hablar con los servidores del usuario.

Plataformas: Windows, macOS, Linux, Android y tablets Android, con una sola base Flutter. Sin web ni iOS.

### Modelo de amenazas (documentar en SECURITY.md)
- Protege contra: lectura de archivos SQLite sin la clave, acceso a la UI sin contraseña de perfil, fuga de secretos por logs o backups no deseados, MITM (host keys).
- No protege contra: un atacante con sesión del sistema operativo ya desbloqueada o con acceso al llavero. La contraseña de perfil es una puerta de la interfaz, no deriva claves. No afirmar lo contrario.
- El borrado de secretos de memoria en Dart es de mejor esfuerzo (las cadenas son inmutables); documentarlo.

## 2. Stack (verificar todo antes de usar)
Investiga versiones estables compatibles con el SDK instalado. Verifica licencia y mantenimiento de cada dependencia; registra todo en `THIRD_PARTY_NOTICES.md`.

- **SSH/SFTP**: `dartssh2`. Una sola sesión `SSHClient` por conexión, con canales separados para terminal y SFTP (la terminal y el explorador comparten el mismo registro y la misma sesión). Lee su API instalada: `onVerifyHostKey`, `SSHKeyPair.fromPem`, `shell`/pty, `resizeTerminal`, `sftp()`, keep-alive.
- **Terminal**: paquete `xterm` de TerminalStudio (verifica en pub.dev nombre real, versión, licencia MIT y compatibilidad). No asumas nombres como `xterm2`/`xterm3`. Rechaza cualquier fork AGPL/GPL.
- **Secretos**: `flutter_secure_storage`. Revisa requisitos por plataforma: Android (minSdk), macOS (entitlements de Keychain), Windows, Linux (libsecret y un keyring activo). Si no hay almacén seguro, error explícito; nunca texto plano.
- **SQLite cifrado real**: evalúa SQLite3MultipleCiphers (vía `sqlite3`/Drift con hooks) o SQLCipher (`sqlcipher_flutter_libs`, `sqflite_sqlcipher`, `sqflite_common_ffi`). Elige según estado actual de mantenimiento y que compile en las 4 plataformas. Si una opción está descontinuada, no la uses. No se acepta SQLite sin cifrar.
- **Hash de contraseña de perfil**: Argon2id con implementación mantenida (por ejemplo `cryptography`; ejecútalo en un isolate si es Dart puro). Alternativa documentada: PBKDF2-HMAC-SHA256 con parámetros actuales. Sal única por perfil. Prueba con vectores conocidos.
- **Auxiliares (solo si hacen falta)**: `path_provider`, `file_picker`/`file_selector`, `desktop_drop`, `super_drag_and_drop`, `uuid`, `flutter_riverpod`, `path` (rutas locales), `shared_preferences` (solo no sensibles).
- **Fuentes**: Inter para la UI y JetBrains Mono para la terminal, empaquetadas como assets (licencia OFL). Nada de descargas en tiempo de ejecución.
- **Configuración nativa obligatoria**: permiso `INTERNET` en el manifest de Android (también release), `android:allowBackup="false"`; entitlements de red cliente, Keychain y acceso a archivos en macOS; dependencias GTK/libsecret documentadas para Linux.

## 3. Arquitectura
Modular por features, sin sobreingeniería:

```text
lib/
  main.dart
  app/ (app.dart, router.dart, theme/)
  core/ (errors, security, database, storage, services, utils, widgets)
  features/ (authentication, profiles, collections, connections, ssh, terminal, sftp, backup, settings)
  shared/ (models, providers, widgets)
```

La UI nunca ejecuta SQL ni gestiona conexiones SSH directamente: usa servicios y repositorios. Rutas remotas con lógica POSIX propia (no `path` local), validando nombres.

## 4. Diseño
Tema oscuro obligatorio. Paleta: fondo `#0E1113`, secundario `#121619`, paneles `#1D232A`, elevados `#252D35`, bordes `#303943`, texto `#E8EDF2`, texto secundario `#929DA8`, acento `#00D4E8`, acento secundario y OK `#20C997`, error `#FF5D6C`, aviso `#E5AE4B`. Acento usado con moderación.

Esquinas ligeramente redondeadas, bordes discretos, sin gradientes ni sombras decorativas. Componentes reutilizables: botones, campos, selectores, tarjetas, menús contextuales, diálogos, tooltips, indicadores de conexión, progreso, paneles laterales, pestañas, breadcrumbs, listas, alertas y notificaciones. Debe parecer un producto comercial.

## 5. Datos
Jerarquía: Perfil → Colección → Conexión. Una conexión es un único servidor y sirve para terminal y SFTP.

- **Profile**: id (UUID), name, passwordSalt, passwordVerifier, createdAt, updatedAt, settings, isLastActive, y contador persistente de intentos fallidos/bloqueo.
- **ServerCollection**: id, profileId, name, description, icon, color, position, createdAt, updatedAt.
- **Connection**: id, collectionId, name, hostname, port (22 por defecto), username, authenticationType, credentialId, description, tags, favorite, position, createdAt, updatedAt.
- **CredentialReference**: solo metadatos y referencia; los secretos nunca van en SQLite.
- **KnownHost**: huella aceptada, asociada a conexión y perfil.

Documenta esquema y migraciones en `docs/DATABASE.md`.

## 6. Seguridad (prioridad máxima)
1. **Aislamiento por perfil**: UUID, FKs, repositorios ligados al perfil activo, validación de pertenencia en cada operación y namespaces de credenciales. No basta con ocultar en la UI.
2. **Cifrado**: una BD de catálogo cifrada (metadatos mínimos) y una BD cifrada independiente por perfil, cada una con clave aleatoria CSPRNG guardada solo en Secure Storage. Implementa apertura, cierre, migración y destrucción.
3. **Credenciales** en Secure Storage con claves `profile/{profileId}/credential/{credentialId}`: crear, leer, actualizar, borrar y borrar todas las de un perfil. Se cargan solo al conectar.
4. **Contraseña de perfil**: solo verificador con sal; sin claves derivadas de ella. Sin recuperación que la salte.
5. **Anti-fuerza bruta**: retardo progresivo persistente (sobrevive a reinicios), mensajes genéricos.
6. **Cierre de sesión**: cierra SSH/SFTP, cierra la BD del perfil, limpia memoria sensible. La app arranca bloqueada.
7. **Logs**: jamás contraseñas, llaves, passphrases, comandos ni salida de terminal.

## 7. Perfiles y autenticación
- **Primer inicio** (catálogo vacío): asistente para crear el primer perfil. Solo en ese caso.
- **Inicio normal**: pantalla mínima con nombre del último perfil, un campo de contraseña y un botón. Sin crear cuentas ni perfiles. Decisión a registrar: incluir un enlace discreto «Cambiar de perfil» que solo permite elegir entre perfiles existentes (sin crear), para que los demás perfiles sigan accesibles tras un reinicio.
- **Validación**: verificador, mensaje discreto en fallo; si es correcta, abrir BD del perfil y cargar colecciones y conexiones (sin cargar credenciales).
- **Crear perfil**: solo desde sesión desbloqueada: Ajustes → Gestión de perfiles → Crear (nombre, contraseña y confirmación, nueva BD y clave). Nunca copia datos de otros perfiles.
- **Sesión**: cerrar sesión, cambiar de perfil, bloqueo manual, desbloquear el último perfil.
- **Reautenticación**: interruptor por perfil «Requerir contraseña al crear/editar conexiones». Si está activo, pide la contraseña al guardar cambios en datos del servidor o credenciales, no para cambios cosméticos (color, orden).

## 8. SSH
Formulario: nombre, **tipo de conexión (SSH o SFTP)**, host/IP, puerto, usuario, método (contraseña o llave privada), credencial, descripción, colección.

> Decisión revisada tras la primera prueba manual (D-018): cada conexión declara si abre
> una **terminal** (SSH) o un **explorador de archivos** (SFTP). Al abrirla se muestra
> solo esa vista, a pantalla completa. No hay panel dividido terminal + SFTP.

Llaves privadas: importar archivo, soporte de passphrase, validar formato antes de guardar, contenido solo en Secure Storage, nunca en el sistema de archivos de la app, errores comprensibles. Verifica qué tipos soporta la versión instalada de dartssh2 (RSA, ECDSA, Ed25519, formatos OpenSSH/PEM) y documenta los no soportados.

**TOFU de host keys (obligatorio)**: primera conexión, mostrar huella SHA-256 y pedir confirmación; si se acepta, guardarla; en conexiones posteriores comparar; si cambia, bloquear y advertir. Nunca aceptar automáticamente una clave desconocida o modificada. Permitir revisar y borrar huellas guardadas.

> Verificación crítica: comprueba qué entrega `onVerifyHostKey` en la versión instalada. Si solo expone la huella MD5 y no la clave pública, no aceptes MD5 como sustituto en silencio: obtén el blob de la clave (por ejemplo parcheando o vendorizando dartssh2 mediante dependencia local documentada) para calcular SHA-256, y registra la decisión en `docs/DECISIONS.md`.

Sesión: conectar, desconectar, estados (conectando, autenticando, esperando confirmación de huella, conectado, desconexión inesperada), timeout, keep-alive, errores de autenticación y red sin revelar secretos, cierre ordenado de canales y sesiones concurrentes.

## 9. Terminal
Shell remota real con pty, no un terminal local simulado. Colores ANSI/256/true color, UTF-8, Unicode, scrollback, selección y copia, pegado, cursor, redimensionado con envío de tamaño al servidor, teclado físico, foco correcto, aplicaciones interactivas (vim, nano, htop). Rendimiento fluido con salida grande. No se guarda ni salida ni comandos.

## 10. SFTP
Explorador remoto real (no reutilizar uno local). Barra de ruta con breadcrumbs, atrás, adelante, subir un nivel, refrescar, listado con tipo, nombre, tamaño, fecha y permisos, archivos ocultos, estados vacío, carga, error y desconexión.

Operaciones: listar, abrir, subir, descargar, crear carpeta, renombrar, eliminar (con confirmación; las carpetas, de forma recursiva y segura), manejo de errores del servidor.

Cola de transferencias en segundo plano sin bloquear la UI (streaming por chunks): nombre, dirección, total, transferido, porcentaje, velocidad, estado (pendiente, en curso, finalizada, fallida, cancelada), error, cancelación, reintento seguro, tratamiento de archivos existentes y de errores de permisos o espacio.

## 11. UI de escritorio
Barra superior, sidebar (perfil activo, colecciones expandibles, servidores, favoritos, ajustes, gestión de perfiles, indicador de conexión) y espacio de trabajo que muestra **solo la vista del tipo de la conexión abierta**: terminal para SSH, explorador de archivos para SFTP (D-018). Sidebar: crear, renombrar, eliminar, reordenar colecciones; crear conexiones; favoritos; menús contextuales.

Drag and drop de entrada (SO → panel SFTP, sube al directorio actual) y de salida (lista SFTP → escritorio, descargando a una ubicación temporal que se limpia con seguridad y sin borrar mientras el SO la usa). Elige librerías compatibles y verifica; si una plataforma no lo permite, documenta la limitación sin simularlo.

## 12. UI de Android
Diseño propio, no el de escritorio comprimido. Drawer (perfil, colecciones, servidores, favoritos, ajustes, perfiles) y espacio de trabajo que muestra la vista del tipo de conexión: terminal para SSH, archivos para SFTP (D-018), conservando la sesión al navegar. Terminal móvil: teclado virtual, foco, scroll táctil, selección, copia, pegado y barra de teclas Ctrl, Alt, Esc, Tab y flechas (solo en móvil). SFTP táctil con selección, menús contextuales, operaciones y transferencias. Selector nativo para subir y selector de destino para guardar, sin permisos generales de almacenamiento. Tablets: aprovechar el espacio con `LayoutBuilder` y breakpoints según espacio disponible, no según tipo de dispositivo.

## 13. Backups JSON
Exportar desde Ajustes o Gestión de perfiles tras mostrar esta advertencia y requerir confirmación explícita, sin exportar nada antes:

> ADVERTENCIA DE SEGURIDAD. El archivo de respaldo contendrá información sensible, incluidas contraseñas SSH, llaves privadas y frases de contraseña. El archivo JSON NO estará cifrado ni protegido por la aplicación. Cualquier persona con acceso al archivo podría conectarse a tus servidores. Guárdalo en un lugar seguro y no lo compartas. Además incluye el verificador de la contraseña de perfil, que podría someterse a fuerza bruta.

Contenido: `formatVersion`, `exportedAt`, `profiles`, `collections`, `connections`, `credentials` (leídas de Secure Storage y serializadas explícitamente), `knownHosts`, configuración, y sal, verificador y parámetros de Argon2. No exportar claves maestras de BD ni claves internas del almacén; al importar se regeneran. Sin logs del contenido ni copias temporales innecesarias. Esquema documentado, validación estricta y migraciones entre versiones.

Importar: sin pedir contraseñas SSH. Resumen previo (perfiles, colecciones, servidores, credenciales, conflictos) y tres modos: **Fusionar** (crea lo que falta, actualiza por UUID, conserva lo local no incluido), **Reemplazar un perfil** (elegido por el usuario) y **Reemplazar todos** (con advertencia y confirmación explícita). Identidad solo por UUID, nunca por host o nombre.

Atomicidad: construye todo en staging (BDs nuevas y secretos con namespace temporal), valida y solo entonces intercambia. Si falla, rollback: sin perfiles a medias, sin credenciales huérfanas, sin borrar datos antiguos antes de garantizar el éxito. Prueba el rollback con fallos inyectados.

## 14. Ajustes
General (nombre del perfil, preferencias, info de la app), Seguridad (interruptor de reautenticación, bloqueo manual, gestión de seguridad del perfil, huellas conocidas), Apariencia (fuente, tamaño, espaciado y scrollback de la terminal), Gestión de perfiles (crear, cambiar, eliminar), Backups (exportar, importar, última exportación).

## 15. Errores, estados y accesibilidad
Estados coherentes para toda operación. Ninguna excepción interna cierra la app. Mensajes comprensibles y logs técnicos sin secretos. Accesibilidad básica: etiquetas semánticas, contraste, navegación por teclado en escritorio.

## 16. Pruebas
- **Unitarias**: validación de perfiles, autenticación local, aislamiento entre perfiles, colecciones, conexiones, credenciales, serialización, importación, exportación, conflictos, reglas de seguridad.
- **Base de datos**: creación, cifrado efectivo, apertura con clave correcta, fallo sin clave, que cadenas sensibles de prueba no aparezcan legibles en los archivos (por ejemplo con `strings`), migraciones, persistencia, aislamiento y borrado.
- **SSH** (servidor de pruebas): contraseña, llave, huella desconocida, aceptada y modificada, fallo de autenticación, desconexión, reconexión.
- **SFTP** (servidor de pruebas): listado, navegación, subida, descarga, renombrado, borrado, carpetas, progreso, cancelación, errores de permisos. Valida integridad con checksums.
- **UI**: bloqueo y desbloqueo, creación inicial, restricción de crear perfiles desde la pantalla bloqueada, navegación, layouts de escritorio y Android, orientación, estados vacíos, diálogos.

## 17. Fases
En `docs/DEVELOPMENT_PLAN.md` mantén el checklist de cada fase y no avances con la anterior en `[!]` sin registrar el motivo.

0. **Auditoría**: inspeccionar repo, `flutter doctor -v`, versiones, plataformas disponibles, `.env.test`, conectividad al servidor de pruebas, elegir y justificar dependencias (licencias), documentar decisiones. Prueba de concepto mínima de SQLite cifrado y de `flutter_secure_storage` en la plataforma disponible antes de seguir.
1. **Backend y seguridad**: catálogo, BD por perfil, Secure Storage, credenciales, hash, autenticación local, último perfil, creación restringida, colecciones, conexiones, migraciones.
2. **Motor SSH**: servicio, contraseña, llave, TOFU, sesiones, shell remota. Primera conexión real al servidor de pruebas.
3. **Terminal**: integración del emulador, flujo bidireccional, redimensionado, teclado, copiar y pegar, errores.
4. **Escritorio**: tema, sidebar, colecciones, workspace dividido, divisor, ajustes, drag and drop.
5. **SFTP**: explorador, operaciones, cola de transferencias.
6. **Backups**: exportar, importar, modos, atomicidad.
7. **Android**: drawer, pestañas, teclado móvil, selectores nativos, tablets.
8. **Revisión final**: `flutter pub get`, `dart format .`, `flutter analyze`, `flutter test`, tests de integración, compilar las plataformas posibles y documentar las que no.

## 18. Criterio de terminado
Cada ítem solo es `[x]` si fue verificado. Checklist de aceptación: primer perfil, recordar último perfil, desbloqueo con solo contraseña, sin creación desde pantalla bloqueada, creación desde sesión, aislamiento, BD realmente cifrada, credenciales solo en Secure Storage, interruptor de reautenticación; SSH por contraseña y llave con huella verificada, terminal remota real con colores e interactividad, cierre correcto de sesiones; SFTP listar, navegar, subir, descargar, renombrar, eliminar, crear carpetas, cola y cancelación; escritorio con sidebar, colecciones, split redimensionable y drag and drop de entrada y salida; Android con drawer, pestañas, teclado, selectores nativos y tablets; backups exportar con advertencia, importar, fusionar, reemplazar uno, reemplazar todos y manejo de errores sin dejar datos inconsistentes.

## 19. Informe final
Funcionalidades implementadas, arquitectura, dependencias y licencias, pruebas y resultados, plataformas compiladas de verdad y no verificadas, limitaciones, pendientes y comandos exactos para ejecutar y compilar. Lo que no se pudo completar o probar se declara expresamente.

Documentos a mantener: `README.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/SECURITY.md`, `docs/DEVELOPMENT_PLAN.md`, `docs/DECISIONS.md`, `docs/TESTING.md`, `THIRD_PARTY_NOTICES.md`.
