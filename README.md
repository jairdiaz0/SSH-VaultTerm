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

Fases 0 y 1 completadas y verificadas con `flutter analyze` y `flutter test`:
catálogo y bases de datos por perfil cifradas con **SQLCipher 4.20.0**, claves en
el almacén secreto del sistema, Argon2id verificado contra `argon2-cffi`, bloqueo
progresivo persistente y el shell de la app (primer perfil, desbloqueo, home de
solo lectura).

Fase 2 (motor SSH) implementada y verificada: TOFU con huellas SHA-256,
autenticación por contraseña y por llave privada, estados de conexión, timeouts,
keep-alive y cierre ordenado, con tests unitarios y tests de integración reales
contra el servidor de pruebas.

Fase 3 (terminal) tiene su motor listo y verificado: emulador `xterm` conectado a
un pty real (bidireccional, redimensionado, UTF-8 y scrollback acotado).

Fase 4 (UI de escritorio) implementada: sidebar real (perfil, favoritos,
colecciones expandibles, servidores, indicador de conexión), CRUD de colecciones
y conexiones con credenciales en el almacén del sistema, workspace con terminal,
divisor redimensionable y maximización, y fuentes Inter/JetBrains Mono
empaquetadas. **141 tests**, incluidos SSH y pty reales. Falta el explorador SFTP
(fase 5), del que depende el arrastrar y soltar de entrada. Los widget tests nunca
sustituyen la verificación real: ver `docs/TESTING.md`. Consulta el plan para el
detalle.

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
