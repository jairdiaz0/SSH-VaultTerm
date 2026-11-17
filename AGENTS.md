# AGENTS.md

Operating rules for AI coding agents (OpenCode, Claude Code, Cursor, Codex, …)
working on this repository. Read this file before touching code. If a rule here
conflicts with your defaults, this file wins.

## 1. Purpose and scope

SSH-VaultTerm is a cross-platform SSH/SFTP client built with Flutter:

- **Supported platforms:** Windows, macOS, Linux and Android.
- **Out of scope:** iOS and web. Do not add `ios/` or `web/` targets, web
  fallbacks, or platform abstractions that only exist for them.
- **Local-first by design:** no accounts, no sync, no backend, no telemetry, no
  analytics, no ad SDKs, no update checks, and no network calls beyond the
  user's own SSH/SFTP servers.

Do not add features that contradict that promise, even behind a flag.

## 2. Architecture map and layering

```text
lib/
  main.dart     # bootstrap: build services or show the startup failure screen
  app/          # MaterialApp, composition root (AppServices), session gate,
                # theme, runtime injection
  core/         # encrypted database, security primitives, secret store,
                # app paths, redacted logger, shared low-level widgets
  features/     # one folder per capability, each with data/ domain/ presentation/
  shared/       # models and widgets used by two or more features
  l10n/         # app_es.arb (template) and generated localizations
```

**Strict layering rule — the UI never talks to infrastructure directly:**

- `presentation/` renders widgets and holds screen state. It **must not** run
  SQL, open SSH/SFTP sockets, read secrets, or touch the filesystem.
- `data/` owns services and repositories: transactions, encryption, secret
  store access, SSH sessions, SFTP transfers.
- `domain/` holds pure, testable rules (`LockoutPolicy`, TOFU verification,
  POSIX path handling, validations). No `BuildContext`, no I/O.
- `core/` is shared infrastructure and **must not** import `features/`.

Allowed dependency direction: `presentation → data → core` and
`presentation → domain`. Never the reverse. No barrel files (`export`): every
import names the real file, so hidden cycles and broken tree shaking stay out.

A model goes to `shared/models/` only when two or more features use it;
otherwise it belongs to the feature's `domain/`.

Composition happens in `lib/app/app_services.dart` (production) and
`AppServices.fromStorage(...)` (tests with injected pieces). Do not introduce
mutable global singletons. `AppServices.sshFor(session)` is the only place that
builds an SSH service, because it enforces profile isolation.

## 3. Security invariants — never break these

1. **Secrets never touch SQLite, `shared_preferences`, or plain files.**
   SSH passwords, private keys and passphrases live **only** in
   `flutter_secure_storage` (DPAPI, Keychain, libsecret, Android Keystore), with
   the namespace defined in `lib/core/storage/secret_store.dart`:
   `profile/<profileId>/credential/<credentialId>` for credentials,
   `profile/<profileId>/dbKey` for database keys, `catalog/dbKey` for the
   catalog. If the secure store is unavailable, fail with
   `AppErrorCode.secureStorageUnavailable`. There is no plaintext fallback, and
   adding one is a release blocker.
2. **Never open an unencrypted SQLite database.** Every database goes through
   `EncryptedDatabase` with SQLCipher (the `sqlite3` `hooks` section pins
   `source: sqlcipher`; do not remove it), and every query is scoped to the
   active `profileId`. Never share a database handle, a key, or a repository
   between profiles.
3. **Never accept an unknown or changed host key automatically.** The TOFU flow
   (`features/ssh/domain/host_key_verifier.dart`) requires explicit user
   confirmation for a new SHA-256 fingerprint and hard-fails with
   `hostKeyChanged` when a stored fingerprint differs. Never pass
   `onVerifyHostKey: null`, never use `disableHostkeyVerification`, and never
   overwrite a stored fingerprint from code.
4. **Never log credentials, commands, terminal output, key material or
   tokens.** Use `AppLogger` (event name + fields); it redacts fields whose
   names look secret. `AppException.description` may expose the error code and
   cause type only — never a library message, a server banner, or a password.
   Do not add `print`, `debugPrint`, or raw `developer.log` calls.
5. **Remote SFTP paths use the project's POSIX logic**
   (`features/sftp/domain/posix_path.dart`), never `package:path` and never
   `dart:io` path helpers. `package:path` is for local OS paths only (app data,
   pickers). Mixing them breaks remote paths on Windows.

Additional non-negotiables:

- No custom cryptography. Use `cryptography` / `dartssh2` primitives; never
  implement a cipher, KDF or RNG.
- Do not remove or weaken Argon2id parameters, the constant-time comparison, or
  the persistent progressive lockout.
- Do not add GPL/AGPL dependencies, dependencies that download assets at
  runtime, or any telemetry/analytics package.
- Do not commit `.env` files, real credentials, databases, keystores or private
  keys. The private keys under `test/fixtures/keys/` are throwaway test vectors:
  they must never be used against a real server and must never be replaced by
  real ones.
- No dead UI: no buttons without behavior, no mocked data pretending to be a
  live connection, no TODO in a critical path, no empty `catch` blocks.

## 4. UI and design conventions

- **Dark-first design with light and system variants.** The palette lives in
  `lib/app/theme/` (tokens, palette, icons). The theme preference defaults to
  `ThemeMode.system` and the terminal has its own palette plus an optional
  "always dark" switch. Keep both variants legible; do not hardcode colors in
  widgets.
- **Native mobile layout, not a squeezed desktop.** `HomeShell` switches at
  `AppLayout.minWidth` (900 px): at or above it uses the persistent sidebar; below
  it uses a drawer and stacked panels. Do not "fix" mobile by scaling the
  desktop view down, and do not collapse tablet layouts into the phone one.
- **SSH and SFTP are separate views.** The terminal (PTY, `xterm`) and the SFTP
  explorer are distinct panels driven by their own controllers. Do not merge
  them into one widget or route SFTP traffic through the terminal channel.
- **All user-visible strings go through `AppLocalizations`.** Never write a
  literal string in a widget. The template is `lib/l10n/app_es.arb`; regenerate
  with `flutter gen-l10n` after editing it.
- Use the Lucide icon set and the shared widgets in `lib/shared/widgets/` and
  `lib/core/widgets/` before creating new ones.

## 5. Internal identifiers that must not change

These define where user data lives or how the app is signed. Renaming them
silently orphans profiles, database keys and credentials, or breaks upgrades:

| Identifier | Value | Why it is frozen |
| --- | --- | --- |
| App data folder | `ssh_client` under `dev.sshclient` | `AppPaths` resolves profile databases and secrets from it |
| Windows `CompanyName` / `ProductName` | `dev.sshclient` / `ssh_client` | `path_provider` derives the app folder from them |
| Android `applicationId` / namespace | `dev.sshclient.ssh_client` | App data and signing identity |
| macOS bundle identifier | `dev.sshclient.sshClient` | App identity and keychain access |
| Linux `APPLICATION_ID` | `dev.sshclient.ssh_client` | App identity |
| Secret prefixes | `catalog/`, `profile/<id>/` | Existing secrets become unreachable |
| Env overrides | `SSH_CLIENT_DATA_DIR`, `SSH_CLIENT_SECRET_NAMESPACE` | Test and reset tooling depend on them |

Changing any of them requires an explicit migration plus a decision entry in
`docs/DECISIONS.md`. Do not do it as a side effect of a rename.

The product name is **SSH-VaultTerm**; the Dart package is `ssh_vault_term`.
Imports use `package:ssh_vault_term/...`.

## 6. Verification commands

Run these before claiming a change works:

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter test -x integration   # offline: integration tests are skipped
```

- `flutter analyze` must report **no issues**. The analyzer enables
  `strict-casts`, `strict-inference`, `strict-raw-types`, `unawaited_futures`,
  `avoid_print`, `directives_ordering`, `always_declare_return_types` and
  `prefer_single_quotes`.
- Do not add `// ignore` without a written justification next to it.
- New behavior needs a test at the right layer: pure rules in `domain/`,
  services/repositories in `data/` (real services plus a temporary directory),
  widgets with `AppHarness` and an in-memory `SecretStore`.
- **Integration tests** are tagged `integration` (`dart_test.yaml`) and talk to a
  real SSH server. They read credentials from `.env.test` or environment
  variables and **self-skip** when those are missing. Keep them that way; never
  stub a real SSH session to make them pass, and never commit the credentials.
  If you run them against a server you own, confine writes to a temporary
  directory you delete afterwards and never change the server's configuration.
- If a platform toolchain is unavailable, say "not verified" and record the
  cause. Never claim a platform check you did not run.

## 7. Language and commits

- **Code, identifiers, comments and commits in English.** Documentation under
  `docs/` and user-facing UI strings are in Spanish today.
- Conventional Commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`,
  `build:`, `chore:`. Never add AI attribution or `Co-Authored-By` trailers.
- Keep a commit reviewable: one coherent behavior with its tests and docs.
- Do not commit build output, `.dart_tool/`, `.env*`, databases, keystores or
  IDE folders; `.gitignore` already covers them.

## 8. Where to look next

- Layering and session lifecycle: `docs/ARCHITECTURE.md`
- Threat model and crypto inventory: `docs/SECURITY.md`
- Schema and migrations: `docs/DATABASE.md`
- Why the code looks the way it does: `docs/DECISIONS.md`
- Dependency licenses: `THIRD_PARTY_NOTICES.md`
