# SSH Client

Cliente SSH/SFTP de escritorio y Android construido con Flutter. Local, sin
cuentas, sin sincronización, sin telemetría: la red solo se usa para hablar con
los servidores del usuario.

- Requisitos completos: [`docs/SPEC.md`](docs/SPEC.md)
- Reglas de trabajo: [`AGENTS.md`](AGENTS.md)
- Arquitectura: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- Base de datos y claves: [`docs/DATABASE.md`](docs/DATABASE.md)
- Seguridad y modelo de amenazas: [`docs/SECURITY.md`](docs/SECURITY.md)
- Estado y progreso: [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md)
- Decisiones técnicas: [`docs/DECISIONS.md`](docs/DECISIONS.md)
- Verificaciones ejecutadas: [`docs/TESTING.md`](docs/TESTING.md)
- Licencias de terceros: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)

## Estado

Fases 0–8 completadas en lo que este entorno permite. `flutter analyze` sin
incidencias y **280 tests** en verde, incluidos SSH, pty y SFTP reales contra el
servidor de pruebas y un test de integración sobre la **app real compilada para
Windows** (almacén seguro y SQLCipher reales). Implementado: bases de datos
cifradas con **SQLCipher 4.20.0** y claves en el almacén secreto del sistema,
Argon2id verificado contra `argon2-cffi`, bloqueo progresivo, TOFU de host keys,
autenticación por contraseña y llave, **conexiones SSH o SFTP con vista única**
(D-018), terminal real, explorador SFTP con cola, copias de seguridad JSON con
importación transaccional, gestión de perfiles, UI de escritorio/móvil por espacio y temas claro/oscuro/sistema con iconos Lucide. La reautenticación protege el interruptor de seguridad y la exportación de respaldos. Las bases viven en `%LOCALAPPDATA%` y la importación usa staging con verificación en frío y rollback; hay reset completo desde Ajustes → Avanzado o con `tool/reset_dev_data.ps1`. Pendiente de esta ronda: colores automáticos de terminal, rediseño visual, pestañas multi-sesión y pruebas de estrés SFTP.

Windows compila en release (`build\windows\x64\runner\Release\ssh_client.exe`).
Android, macOS y Linux no tienen toolchain aquí y se declaran no verificados.

- Informe final (SPEC §19): [`docs/FINAL_REPORT.md`](docs/FINAL_REPORT.md)
- Evidencias de cada verificación: [`docs/TESTING.md`](docs/TESTING.md)

## Requisitos para desarrollar

- Flutter 3.47.x / Dart 3.13.x.
- Windows: Visual Studio con el workload «Desktop development with C++» para
  compilar la app de escritorio.
- Android: Android SDK + JDK para compilar el APK.
- `flutter pub get` descarga durante el build el binario precompilado de
  SQLCipher (nunca en tiempo de ejecución de la app).

## Comandos

```bash
flutter pub get
flutter gen-l10n     # regenera lib/l10n/generated tras editar los .arb
dart format .
flutter analyze
flutter test
```

## Servidor de pruebas

Las pruebas de integración usan `.env.test` (ignorado por git) con
`SSH_TEST_HOST`, `SSH_TEST_PORT`, `SSH_TEST_USER`, `SSH_TEST_PASSWORD`. Sin esas
variables, los tests etiquetados `integration` se omiten.
