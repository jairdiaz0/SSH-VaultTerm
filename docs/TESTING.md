# TESTING — SSH Client

Registro de verificaciones ejecutadas, con comando y resultado resumido. Un
ítem del plan solo pasa a `[x]` si aparece aquí su evidencia.

## Entorno
- SO: Windows 11 26H2 (10.0.26300), shell PowerShell.
- Flutter 3.47.9 stable · Dart 3.13.7 · `windows-x64`.
- Sin Visual Studio C++ → sin compilación Windows. Sin Android SDK → sin
  compilación Android. Ver `docs/DECISIONS.md` D-001.

## 2026-11-15 — Fase 0

### Toolchain
```text
flutter --version        → Flutter 3.47.9 / Dart 3.13.7
flutter doctor -v        → Windows OK; Android SDK y Visual Studio ausentes
```

### Conectividad al servidor de pruebas
```text
Test-NetConnection 192.168.100.129 -Port 22 → TcpTestSucceeded: True
```

### Resolución de dependencias
```text
flutter pub get → OK (80 dependencias)
```
Conflicto real detectado y resuelto: `cross_file` (ver D-006). Aviso no
bloqueante: «Building with plugins requires symlink support» (Developer Mode
desactivado); `pub get`, `analyze` y `test` siguen funcionando.

### Análisis estático
```text
flutter analyze → No issues found! (31.2s)
```

### Tests base
```text
flutter test (template) → All tests passed!
```

### PoC de SQLite cifrado (SQLCipher)
```text
flutter test test/poc/encrypted_sqlite_poc_test.dart → +3 All tests passed!
```
Evidencia concreta:
- `PRAGMA cipher_version` → `4.20.0 community` (no es SQLite plano).
- Archivo creado con clave: el marcador `SUPER_SECRET_MARKER_1234` **no** aparece
  en los bytes del archivo; la cabecera no es `SQLite format 3`.
- Clave incorrecta → `SqliteException` (`hmac check failed for pgno=1`).
- Clave correcta en forma cruda `x'<hex>'` → lee el dato.

### Pendiente de verificación
- `flutter_secure_storage`: plugin de plataforma; no hay app ejecutable en esta
  máquina (D-001). Se marcará `[~]` hasta que exista una plataforma compilable.
- Drag and drop real y teclado virtual: requieren ejecución.
