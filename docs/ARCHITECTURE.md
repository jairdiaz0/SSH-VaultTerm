# ARCHITECTURE — SSH Client

Estructura modular por *features*, sin sobreingeniería. La UI nunca ejecuta SQL
ni gestiona conexiones SSH: usa servicios y repositorios.

## 1. Mapa de carpetas

```text
lib/
  main.dart                 # arranque: bootstrap de servicios o pantalla de fallo
  app/
    app.dart                # MaterialApp: tema, l10n, SessionGate
    app_services.dart       # composition root (bootstrap / fromStorage)
    session_controller.dart # estado bloqueado/desbloqueado + sesión de perfil
    session_gate.dart       # elige pantalla según el estado
    error_messages.dart     # AppErrorCode -> mensaje localizado
    startup_failure_app.dart
    theme/app_theme.dart    # paleta y componentes base
  core/
    database/               # EncryptedDatabase, migraciones, esquemas
    errors/                 # AppException + códigos
    security/               # Argon2id, CSPRNG, comparación en tiempo constante
    session/                # ProfileSession (BD de un perfil abierto)
    storage/                # SecretStore, AppPaths, implementación real
    utils/                  # logger redactado
    widgets/                # widgets compartidos (InlineMessage)
  features/
    authentication/         # servicio de desbloqueo, política de bloqueo, pantalla
    profiles/               # catálogo, creación/borrado, asistente inicial
    collections/            # repositorio de colecciones
    connections/            # repositorio de conexiones, credenciales
    ssh/                    # huellas conocidas (fase 2: servicio SSH)
    shell/                  # home del perfil desbloqueado
  shared/
    models/                 # Profile, ServerCollection, Connection, KnownHost
  l10n/
    app_es.arb              # cadenas en español (plantilla)
    generated/              # salida de gen-l10n (versionada)
```

Fases 2–7 añadirán `features/ssh`, `features/terminal`, `features/sftp`,
`features/backup` y `features/settings` con la misma forma: `data/` (servicios y
repositorios), `domain/` (reglas puras), `presentation/` (widgets).

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
| Plataforma (keychain, drag and drop) | bloqueado por el entorno (`DECISIONS.md` D-001) |
