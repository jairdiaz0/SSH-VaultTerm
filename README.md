# SSH-VaultTerm

[![Flutter](https://img.shields.io/badge/Flutter-3.50-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-4B5563)](#getting-started)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)
[![Telemetry: none](https://img.shields.io/badge/telemetry-none-success)](#security-first)

**A fast, minimalist, local-first SSH and SFTP client.** No accounts, no cloud,
no telemetry, no sync. The only network connection this app ever opens is the
one you configure: your own servers.

SSH-VaultTerm keeps every profile in its own encrypted SQLite database, stores
credentials exclusively in the operating system keychain, and verifies host
keys with a strict SHA-256 TOFU flow. It runs on Windows, macOS, Linux and
Android.

## Features

- **Real PTY terminal** — a true remote pseudo-terminal over `dartssh2`, rendered
  by `xterm`. Full ANSI/VT escape sequences, 256-color and 24-bit color SGR,
  10 000 lines of scrollback, and window resizes propagated to the remote pty
  (the client requests `xterm-256color`).
- **Mobile key bar** — on phones and tablets the terminal gets a dedicated bar
  with `Ctrl`, `Alt`, `Esc`, `Tab` and arrow keys, so you can send control
  sequences without a hardware keyboard.
- **Dedicated SFTP explorer** — a separate panel per session: browse, create,
  rename, upload and download, with an in-app transfer queue that keeps running
  while you use the terminal. On desktop you can drag files from the OS straight
  onto the panel.
- **Multi-profile isolation** — each profile has its own encrypted database, its
  own credential namespace and its own known hosts. Only one profile is
  unlocked at a time, and opening another closes the previous one.
- **Concurrent sessions** — several tabs per profile, each with its own SSH
  channel, pty and SFTP channel, without tearing down the connection when you
  switch views.
- **Host key fingerprints** — a dedicated panel to review the SHA-256
  fingerprints this profile trusts, and a settings screen to forget them.
- **Portable backups** — export and import everything as a JSON document, with
  atomic staging and rollback so a failed import never leaves you with half a
  profile.
- **Light, dark or system theme**, Lucide icons, and fully bundled fonts and
  assets: nothing is downloaded at runtime.

The interface ships in Spanish today. Strings live in ARB files under
`lib/l10n/`, and a new locale only needs a new `app_<locale>.arb`.

## Security First

SSH-VaultTerm is built around the assumption that the local machine is the only
thing you control. What it does, and what it deliberately does not do:

| Area | Implementation |
| --- | --- |
| **Databases** | One SQLCipher 4 database per profile (AES-256-CBC + HMAC-SHA512, per-file salt). The `sqlite3` dependency is compiled with the SQLCipher variant; there is no plain-SQLite code path. |
| **Database keys** | A random 32-byte CSPRNG key per database, never stored on disk. Keys live in the OS secure store (`flutter_secure_storage`): DPAPI on Windows, Keychain on macOS, libsecret on Linux, Keystore on Android. If the secure store is unavailable the app refuses to start instead of falling back to plaintext. |
| **SSH secrets** | Passwords, private keys and passphrases live **only** in the secure store, namespaced `profile/<profileId>/credential/<credentialId>`. They are read on connect, never cached, never written to SQLite, `shared_preferences` or logs. |
| **Profile password** | Stored as an Argon2id verifier (64 MiB, t=3, p=2, 32-byte hash, 16-byte salt) with its parameters persisted alongside, so they can be raised later without invalidating profiles. Comparison is constant-time. |
| **Brute-force lockout** | Three attempts without delay, then a persistent exponential delay (2 s → 4 s → 8 s … capped at 5 minutes). Counters live in the encrypted catalog, so restarting the app does not reset the penalty. |
| **Host keys** | Strict TOFU. The first connection shows the `SHA256:<base64>` fingerprint and requires explicit confirmation; later connections reuse it. A changed fingerprint is a hard stop: the connection closes, the stored key is never overwritten, and the only way out is to delete the fingerprint yourself. |
| **Backups** | JSON exports are **not encrypted** — they contain connection metadata and secrets, and the app shows a blocking warning plus a password confirmation before writing one. The database keys themselves are never exported. |
| **Logs** | A closed logger API (event + fields) that redacts any field whose name looks like a secret. Commands, terminal output, keys and passwords are never logged. |
| **Network surface** | SSH and SFTP to the servers you configured. No analytics, no crash reporting, no ads, no update checks, no self-hosted backend. |

What it does **not** protect against: an attacker who already controls your
unlocked OS session and its keychain, offline brute force of an exported backup,
or a compromised remote server. See [`docs/SECURITY.md`](docs/SECURITY.md) for
the full threat model and the cryptographic inventory.

## Screenshots

<!--
  Drop real captures in docs/screenshots/ before the public announcement.
  Suggested set (1440x900 desktop, 390x844 Android), with hostnames, usernames
  and fingerprints blurred or replaced by example values:

  ![Desktop: dashboard and open terminal](docs/screenshots/desktop-dashboard.png)
  ![Desktop: SFTP explorer with the transfer queue](docs/screenshots/desktop-sftp.png)
  ![Android: terminal with the special-keys bar](docs/screenshots/android-terminal.png)
-->

_Coming soon._

## Project Structure

```text
lib/
  app/        # MaterialApp, composition root, session gate, theme
  core/       # encrypted database, security, secret store, paths, logger
  features/   # authentication, backup, collections, connections, profiles,
              # settings, sftp, shell, ssh, terminal, workspace
  shared/     # models and reusable widgets
  l10n/       # ARB template and generated localizations
```

Each feature follows the same shape: `data/` (services and repositories),
`domain/` (pure rules) and `presentation/` (widgets). Dependencies point one
way: `presentation → data → core`, and `presentation → domain`. The UI never
runs SQL and never opens a socket; everything goes through a service or a
repository. More detail in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

### Tech stack

| Package | Role |
| --- | --- |
| [`dartssh2`](https://pub.dev/packages/dartssh2) | SSH transport, channels, pty and SFTP |
| [`xterm`](https://pub.dev/packages/xterm) | Terminal emulator |
| [`sqlite3`](https://pub.dev/packages/sqlite3) + SQLCipher | Encrypted per-profile databases |
| [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) | OS keychain / credential store |
| [`cryptography`](https://pub.dev/packages/cryptography) | Argon2id |
| [`file_picker`](https://pub.dev/packages/file_picker), [`desktop_drop`](https://pub.dev/packages/desktop_drop) | Key import, SFTP uploads, drag and drop from the OS |
| [`path_provider`](https://pub.dev/packages/path_provider) | Application data directories |

Live dependency versions and licenses: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
Design decisions and their rationale: [`docs/DECISIONS.md`](docs/DECISIONS.md).

## Getting Started

### Prerequisites

- **Flutter 3.50.0** (stable) with Dart 3.13 or newer.
- **Windows**: Visual Studio with the *Desktop development with C++* workload.
  Optional: Inno Setup 7 to build the installer.
- **macOS**: Xcode and the CocoaPods toolchain.
- **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`,
  `libsecret-1-dev`, `libjsoncpp-dev`. A running and unlocked keyring is
  required at runtime: without libsecret the app reports the failure instead of
  falling back to plaintext.
- **Android**: Android SDK (platform 36), JDK 17+, and an emulator or device.
  `minSdk` is 24.

### Run it

```bash
flutter pub get
flutter run -d windows    # or: macos, linux, chrome-free device id
flutter run -d <android-device-id>
```

`flutter pub get` fetches the precompiled SQLCipher binary; the app itself never
downloads anything at runtime.

### Build a release

```bash
# Windows
flutter build windows --release
# macOS
flutter build macos --release
# Linux
flutter build linux --release
# Android (universal APK; add --split-per-abi for per-ABI APKs)
flutter build apk --release
```

The Android release is signed with the template debug key until you configure
`android/key.properties` with your own keystore. Publishing to Google Play
requires that keystore; the project does not invent or bypass one.

Windows and Android artifacts (including the Inno Setup installer) can be
produced in one step:

```powershell
pwsh -File tool/build_release.ps1                 # windows + android
pwsh -File tool/build_release.ps1 -Target windows
```

### Verify your changes

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter test -x integration    # offline: skips tests that need a real server
```

Integration tests talk to a real SSH server and self-skip unless `.env.test`
(or the equivalent environment variables) is present. That file is git-ignored
and must never be committed.

## Documentation

- [Architecture and layering](docs/ARCHITECTURE.md)
- [Security model and cryptographic inventory](docs/SECURITY.md)
- [Encrypted database layout](docs/DATABASE.md)
- [Design decisions](docs/DECISIONS.md)
- [Third-party licenses](THIRD_PARTY_NOTICES.md)
- [Agent and contributor rules](AGENTS.md)

## License

MIT — see [LICENSE](LICENSE). Copyright © 2026 Edén Jair Sánchez Díaz.
