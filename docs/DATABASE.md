# DATABASE — SSH-VaultTerm

Esquema, migraciones y claves de las bases de datos cifradas. Complementa
`docs/ARCHITECTURE.md` y `docs/SECURITY.md`.

## 1. Ficheros en disco

Rutas resueltas con `path_provider` (`getApplicationSupportDirectory`), en
`lib/core/storage/app_paths.dart`:

```text
<applicationSupport>/ssh_client/
  catalog.db                        # catálogo cifrado (perfiles y metadatos)
  profiles/<profileId>/data.db      # BD cifrada propia de cada perfil
```

- Cada BD es un fichero SQLCipher independiente con su **propia clave aleatoria
  de 32 bytes** (CSPRNG), nunca compartida entre perfiles.
- Las claves viven **solo** en el almacén secreto del sistema
  (`SecretStore`), con este namespace (`SecretKeys`):

| Clave | Contenido |
| --- | --- |
| `catalog/dbKey` | clave de `catalog.db` (64 hex = 32 bytes) |
| `profile/<profileId>/dbKey` | clave de `data.db` del perfil |
| `profile/<profileId>/credential/<credentialId>` | secreto de la credencial SSH |
| `__probe__/secret_store` | clave efímera de sondeo; se borra al instante |

Ninguna clave se escribe en SQLite, en archivos, en logs ni en los backups
exportados. Al importar un backup se regeneran.

## 2. Apertura cifrada

Único punto de apertura: `EncryptedDatabase.open` (`lib/core/database/`).

```dart
EncryptedDatabase.open(path: ..., key: <32 bytes>, migrations: runner)
```

Pasos que no se pueden omitir:

1. `PRAGMA key = "x'<hex>'"` — clave en crudo. La clave ya es aleatoria de
   256 bits, así que no se aplica KDF (evita ~250 ms de PBKDF2 por apertura).
2. `PRAGMA cipher_version` — comprobación barata de que el binario enlazado es
   SQLCipher y no SQLite plano (`4.20.0 community`).
3. `PRAGMA foreign_keys = ON` (por conexión, no persiste).
4. Migraciones (`PRAGMA user_version`).

El binario cifrado llega por el *build hook* de `sqlite3` 3.x con
`hooks: user_defines: sqlite3: source: sqlcipher` (ver `DECISIONS.md` D-002).
No existe ninguna ruta de código que abra una BD sin `PRAGMA key`.

Clave incorrecta → `SqliteException` (`hmac check failed for pgno=1`) traducida a
`AppErrorCode.databaseFailure`; nunca se propaga el mensaje del driver a la UI.

## 3. Esquema del catálogo (`catalog.db`)

Metadatos mínimos: **nunca** credenciales, llaves ni secretos SSH.

```sql
CREATE TABLE app_meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
) STRICT;

CREATE TABLE profiles (
  id TEXT PRIMARY KEY,                        -- UUID v4
  name TEXT NOT NULL,
  name_normalized TEXT NOT NULL UNIQUE,       -- minúsculas + trim
  password_salt BLOB NOT NULL,                -- 16 bytes
  password_verifier BLOB NOT NULL,            -- Argon2id, 32 bytes
  kdf TEXT NOT NULL,                          -- 'argon2id'
  kdf_params TEXT NOT NULL,                   -- JSON de Argon2Params
  settings TEXT NOT NULL DEFAULT '{}',        -- JSON (p. ej. reautenticación)
  is_last_active INTEGER NOT NULL DEFAULT 0 CHECK (is_last_active IN (0,1)),
  failed_attempts INTEGER NOT NULL DEFAULT 0, -- persistente entre reinicios
  lockout_until INTEGER,                      -- epoch ms o NULL
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
) STRICT;

-- Un único perfil "último activo" a la vez, garantizado por el motor.
CREATE UNIQUE INDEX profiles_single_last_active
  ON profiles (is_last_active) WHERE is_last_active = 1;
CREATE INDEX profiles_name_normalized ON profiles (name_normalized);
```

## 4. Esquema por perfil (`profiles/<id>/data.db`)

Una BD por perfil: el **límite de fichero es el límite de aislamiento**. Los
repositorios solo ven su propia BD, de modo que un `id` de otro perfil no existe
para ellos.

```sql
CREATE TABLE collections (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT,
  color TEXT,
  position INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
) STRICT;

CREATE TABLE connections (
  id TEXT PRIMARY KEY,
  collection_id TEXT REFERENCES collections (id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  hostname TEXT NOT NULL,
  port INTEGER NOT NULL DEFAULT 22 CHECK (port BETWEEN 1 AND 65535),
  username TEXT NOT NULL,
  auth_type TEXT NOT NULL CHECK (auth_type IN ('password','privateKey')),
  credential_id TEXT,                  -- referencia al almacén secreto
  description TEXT,
  tags TEXT NOT NULL DEFAULT '[]',      -- JSON array de strings
  favorite INTEGER NOT NULL DEFAULT 0 CHECK (favorite IN (0,1)),
  position INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
) STRICT;

CREATE INDEX connections_by_collection ON connections (collection_id, position);
CREATE INDEX connections_by_favorite ON connections (favorite);

CREATE TABLE known_hosts (
  id TEXT PRIMARY KEY,
  connection_id TEXT NOT NULL REFERENCES connections (id) ON DELETE CASCADE,
  hostname TEXT NOT NULL,
  port INTEGER NOT NULL CHECK (port BETWEEN 1 AND 65535),
  key_type TEXT NOT NULL,               -- p. ej. 'ssh-ed25519'
  fingerprint TEXT NOT NULL,            -- 'SHA256:<base64>'
  created_at INTEGER NOT NULL,
  UNIQUE (connection_id, hostname, port)
) STRICT;

CREATE TABLE profile_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
) STRICT;
```

Decisiones de modelado:

- **`ON DELETE SET NULL`** en `connections.collection_id`: borrar una colección
  no destruye servidores; quedan sin colección (documentado y probado).
- **`ON DELETE CASCADE`** en `known_hosts`: una huella no sobrevive a su conexión.
- `STRICT` en todas las tablas: SQLite no relega tipos en silencio.
- `tags` se guarda como JSON `TEXT` porque SQLite no tiene arrays; la
  serialización se valida en el modelo.

## 5. Migraciones

`MigrationRunner` (`lib/core/database/migrations.dart`) aplica una lista de lotes
por versión, en una transacción, y actualiza `PRAGMA user_version` al final:

- versión actual = longitud de la lista; nunca se ejecuta dos veces;
- si la BD tiene `user_version` mayor que la soportada →
  `AppErrorCode.schemaTooNew` (no se degrada ni se adivina);
- un fallo en mitad de un lote hace `ROLLBACK`: no quedan migraciones a medias.

Añadir una migración = añadir un lote nuevo al final de la lista. **Nunca** editar
un lote ya publicado: hay instalaciones con ese `user_version`.

## 6. Ciclo de vida y borrado

| Acción | Efecto |
| --- | --- |
| Crear perfil | inserta fila en `profiles`, materializa su clave (`profile/<id>/dbKey`) y crea el directorio del perfil |
| Desbloquear | abre `data.db` con su clave; la sesión mantiene un único handle |
| Bloquear / cerrar sesión | `ProfileSession.close()` → `database.close()`; el handle deja de existir |
| Borrar perfil | primero secretos (`deletePrefix('profile/<id>/')`), luego la fila y por último los ficheros |

El orden del borrado es deliberado: **los secretos van primero**. Si el borrado
de ficheros fallase a medias, lo que queda es un fichero cifrado sin clave, es
decir, basura inútil en lugar de datos legibles.

## 7. Copias de seguridad (fase 6)

- La exportación JSON **no** incluye claves de BD: se regeneran al importar.
- Sí incluye sal, verificador y parámetros de Argon2 del perfil, por lo que el
  fichero puede sufrir fuerza bruta sobre la contraseña del perfil. De ahí la
  advertencia bloqueante del SPEC (sección 13).
- Los secretos SSH se serializan explícitamente desde el almacén seguro, nunca
  desde SQLite, porque en SQLite no están.
- La importación construye todo en *staging* (BDs y secretos con namespace
  temporal) y solo intercambia si la validación completa pasa.

## 8. Pruebas

`test/core/database/encrypted_database_test.dart`, `test/features/repositories_test.dart`
y `test/poc/encrypted_sqlite_poc_test.dart` cubren: cifrado efectivo (marcadores
sensibles ausentes del fichero), fallo con clave incorrecta, apertura correcta,
migraciones idempotentes, `schemaTooNew`, aislamiento entre perfiles (mismo id en
dos perfiles), cascadas y borrado. Evidencia: esa misma suite en verde.
