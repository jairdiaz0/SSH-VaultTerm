import 'migrations.dart';

/// Schema of the encrypted catalog database: profiles and app-wide metadata
/// only. It never holds credentials, keys, hostnames or SSH secrets.
abstract final class CatalogSchema {
  static const runner = MigrationRunner(migrations: [_v1]);

  static const _v1 = <String>[
    '''
    CREATE TABLE app_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    ) STRICT
    ''',
    '''
    CREATE TABLE profiles (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      name_normalized TEXT NOT NULL UNIQUE,
      password_salt BLOB NOT NULL,
      password_verifier BLOB NOT NULL,
      kdf TEXT NOT NULL,
      kdf_params TEXT NOT NULL,
      settings TEXT NOT NULL DEFAULT '{}',
      is_last_active INTEGER NOT NULL DEFAULT 0 CHECK (is_last_active IN (0, 1)),
      failed_attempts INTEGER NOT NULL DEFAULT 0,
      lockout_until INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    ) STRICT
    ''',
    '''
    CREATE UNIQUE INDEX profiles_single_last_active
      ON profiles (is_last_active) WHERE is_last_active = 1
    ''',
    '''
    CREATE INDEX profiles_name_normalized ON profiles (name_normalized)
    ''',
  ];
}

/// Schema of a per-profile encrypted database. One file per profile, one key
/// per profile, stored only in the platform secret store.
abstract final class ProfileSchema {
  static const runner = MigrationRunner(migrations: [_v1]);

  static const _v1 = <String>[
    '''
    CREATE TABLE collections (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      icon TEXT,
      color TEXT,
      position INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    ) STRICT
    ''',
    '''
    CREATE TABLE connections (
      id TEXT PRIMARY KEY,
      collection_id TEXT REFERENCES collections (id) ON DELETE SET NULL,
      name TEXT NOT NULL,
      hostname TEXT NOT NULL,
      port INTEGER NOT NULL DEFAULT 22 CHECK (port BETWEEN 1 AND 65535),
      username TEXT NOT NULL,
      auth_type TEXT NOT NULL CHECK (auth_type IN ('password', 'privateKey')),
      credential_id TEXT,
      description TEXT,
      tags TEXT NOT NULL DEFAULT '[]',
      favorite INTEGER NOT NULL DEFAULT 0 CHECK (favorite IN (0, 1)),
      position INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    ) STRICT
    ''',
    '''
    CREATE INDEX connections_by_collection
      ON connections (collection_id, position)
    ''',
    'CREATE INDEX connections_by_favorite ON connections (favorite)',
    '''
    CREATE TABLE known_hosts (
      id TEXT PRIMARY KEY,
      connection_id TEXT NOT NULL REFERENCES connections (id) ON DELETE CASCADE,
      hostname TEXT NOT NULL,
      port INTEGER NOT NULL CHECK (port BETWEEN 1 AND 65535),
      key_type TEXT NOT NULL,
      fingerprint TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE (connection_id, hostname, port)
    ) STRICT
    ''',
    '''
    CREATE TABLE profile_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    ) STRICT
    ''',
  ];
}
