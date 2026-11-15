# ARCHITECTURE — SSH Client

Estructura modular por *features*, sin sobreingeniería. La UI nunca ejecuta SQL
ni gestiona conexiones SSH: usa servicios y repositorios.

## 1. Mapa de carpetas

```text
lib/
  main.dart                 # arranque: bootstrap de servicios o pantalla de fallo
  app/
    app.dart                # MaterialApp: tema, l10n, SessionGate
    app_services.dart       # composition root (bootstrap / fromStorage) + sshFor
    profile_session.dart    # ensambla la BD del perfil y sus repositorios
    session_controller.dart # estado bloqueado/desbloqueado + sesión de perfil
    session_gate.dart       # elige pantalla según el estado
    error_messages.dart     # AppErrorCode -> mensaje localizado
    startup_failure_app.dart
    theme/app_theme.dart    # paleta y componentes base
  core/
    database/               # EncryptedDatabase, migraciones, esquemas
    errors/                 # AppException + códigos
    security/               # Argon2id, CSPRNG, comparación en tiempo constante
    storage/                # SecretStore, AppPaths, implementación real
    utils/                  # logger redactado
    widgets/                # widgets compartidos (InlineMessage)
  features/
    authentication/         # data/ domain/ presentation/: desbloqueo y bloqueo
    profiles/               # data/ domain/ presentation/: catálogo y reglas
    collections/            # data/: repositorio de colecciones
    connections/            # data/: repositorios de conexiones y credenciales
    ssh/                    # domain/: reglas puras (TOFU, llaves, errores)
                            # data/: SshService, SshConnection, repositorio
    shell/                  # presentation/: home del perfil desbloqueado
  shared/
    models/                 # Profile, ServerCollection, Connection, KnownHost
  l10n/
    app_es.arb              # cadenas en español (plantilla)
    generated/              # salida de gen-l10n (versionada)
```

Fases 3–7 añadirán `features/terminal`, `features/sftp`, `features/backup` y
`features/settings` con la misma forma: `data/` (servicios y repositorios),
`domain/` (reglas puras), `presentation/` (widgets).

### Dónde va un modelo

- Vive en `shared/models/` solo si **dos o más features** lo usan (`Connection`,
  `Profile`, `KnownHost`). Si solo lo usa una feature, va a su `domain/`.
- `core/` no conoce features. Por eso `ProfileSession`, que ensambla repositorios
  de varias features, vive en `app/` y no en `core/`.
- Sin barrels (`export`): cada import nombra el fichero real, así no se crean
  ciclos ocultos ni se degrada el *tree shaking*.

## 2. Capas

| Capa | Responsabilidad | Prohibido |
| --- | --- | --- |
| `presentation` | Widgets, estado de pantalla, textos vía `AppLocalizations` | SQL, sockets, claves |
| `data` | Servicios y repositorios: transacciones, cifrado, almacén de secretos | Decisiones de negocio escondidas |
| `domain` | Reglas puras y comprobables (`LockoutPolicy`, validaciones) | `BuildContext`, I/O |
| `core` | Infraestructura compartida (BD, errores, criptografía, rutas) | Conocer features |

Regla de dependencia: `presentation → data → core` y `presentation → domain`.
Nunca al revés.

## 3. Composition root y estado

- `AppServices.bootstrap()` construye: `SecretStore` real (falla si el sistema no
  tiene almacén seguro), `AppPaths`, `DatabaseKeyStore`, `CatalogStore`,
  `PasswordHasher`, `ProfileService` y `AuthenticationService`.
- `AppServices.fromStorage(...)` es la misma ruta con piezas inyectadas: así los
  tests ejercitan el código de producción, no una copia.
- `SessionController` (un `ChangeNotifier`) posee el estado: sin sesión, con
  sesión abierta. `SessionGate` se suscribe y decide pantalla.
- No hay singletons mutables globales. El estado de pantalla vive en el widget.

### Shell de la ronda 6

```text
HomeShell (StatefulWidget)
  └── ShellController            (ChangeNotifier, una instancia por perfil abierto)
        ├── SessionTab[]         (una por conexión abierta)
        │     └── WorkspaceController  (canal SSH, pty y SFTP de esa sesión)
        └── sección/vista        (Conexiones | Huellas | dashboard | SFTP | sesión)
```

- `ShellController` es el único escritor de colecciones y conexiones desde la UI y
  el dueño de las sesiones abiertas. Cambiar de pestaña solo cambia qué widget se
  pinta; el `WorkspaceController` de cada pestaña sigue vivo.
- `ShellController.workspace` devuelve el workspace de la pestaña activa (o el del
  shell si no hay pestañas), de modo que el código anterior sigue siendo válido.
- Cerrar una pestaña, bloquear el perfil o borrar una conexión libera su canal
  (`WorkspaceController.close`) antes de disponer del controlador.

## 4. Ciclo de vida de una sesión

```text
arranque → catálogo cifrado abierto → sin perfiles ? asistente : pantalla de bloqueo
bloqueo  → contraseña correcta → ProfileSession.open (abre data.db cifrada)
         → home con colecciones y conexiones (sin cargar credenciales)
bloqueo manual / cierre → ProfileSession.close() → handle cerrado → pantalla de bloqueo
```

Invariantes:

- Un solo perfil abierto a la vez; abrir otro cierra el anterior.
- Las credenciales no se cargan al desbloquear: solo al conectar (fase 2).
- La app siempre arranca bloqueada.

## 5. Errores y textos

- Los errores de dominio son `AppException(code)`; el mensaje técnico nunca sale
  de la capa que lo produjo (`description` solo expone código y tipo de causa).
- La UI traduce el código con `describeAppError(l10n, error)`. Mensajes genéricos
  para credenciales, para no filtrar si el perfil existe.
- Ningún texto visible se escribe literal en un widget.

## 6. Rutas

- Locales: `package:path` y `AppPaths` (única fuente de rutas locales).
- Remotas: lógica POSIX propia a partir de la fase 5 (`path` local no sirve y no
  se usará para remotas).

## 7. Pruebas por capa

| Capa | Herramienta |
| --- | --- |
| `core`, `data`, `domain` | `flutter test` con servicios reales y directorio temporal |
| `presentation` | `testWidgets` con `AppHarness` (servicios reales, `SecretStore` en memoria) |
| SSH/SFTP contra el servidor de pruebas | `flutter test` con tests etiquetados `integration`; se omiten solos si falta `.env.test` |
| Plataforma (keychain, drag and drop) | bloqueado por el entorno (`DECISIONS.md` D-001) |

Los tests de integración no se pueden simular: usan `SshSocket.connect` real. Por
eso viven aparte, con etiqueta `integration` (`dart_test.yaml`), y `flutter test -x
integration` deja una ejecución sin red.

## 8. Motor SSH (fase 2)

```text
UI (fase 3/4) → AppServices.sshFor(session) → SshService.connect(connection)
                                           ├─ CredentialService (secret store, solo al conectar)
                                           ├─ TofuHostKeyVerifier → KnownHostRepository (BD del perfil)
                                           └─ SSHClient (dartssh2)
SshConnection: un SSHClient por conexión; terminal y SFTP abrirán canales sobre él.
```

- `SshService` recibe `profileId`, credenciales, repositorio de huellas y logger.
  `AppServices.sshFor` es el único sitio que lo construye, para que ningún
  llamador olvide el aislamiento por perfil.
- Estados observables: `connecting → awaitingHostKey → authenticating →
  connected`, más `disconnected`, `disconnectedUnexpectedly` y `failed` (con su
  `AppErrorCode`).
- Los errores de `dartssh2` se traducen a códigos en
  `domain/ssh_error_mapper.dart`; los mensajes del servidor no se propagan nunca.
- `SshConnection` no guarda comandos ni salida. `execute` existe para diagnósticos
  y tests; la terminal usará `openShell` (fase 3).

## 9. Análisis estático y estilo

`analysis_options.yaml` activa `strict-casts`, `strict-inference` y
`strict-raw-types`, y trata como obligatorios `unawaited_futures`, `avoid_print`,
`directives_ordering`, `always_declare_return_types` y `prefer_single_quotes`.

Regla operativa: si una regla estorba, se corrige el código o se justifica por
escrito. No se añade un `// ignore` sin motivo.
