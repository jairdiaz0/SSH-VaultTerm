# SSH Client

Cliente SSH/SFTP de escritorio y Android construido con Flutter. Local, sin
cuentas, sin sincronización, sin telemetría: la red solo se usa para hablar con
los servidores del usuario.

- Requisitos completos: [`docs/SPEC.md`](docs/SPEC.md)
- Reglas de trabajo: [`AGENTS.md`](AGENTS.md)
- Estado y progreso: [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md)
- Decisiones técnicas: [`docs/DECISIONS.md`](docs/DECISIONS.md)
- Verificaciones ejecutadas: [`docs/TESTING.md`](docs/TESTING.md)
- Licencias de terceros: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)

## Estado

Fase 0 (auditoría) completada: toolchain verificada, dependencias auditadas con
licencias, y prueba de concepto de SQLite cifrado con **SQLCipher 4.20.0**
funcionando. El resto de fases está en curso; consulta el plan para el detalle.

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
dart format .
flutter analyze
flutter test
```

## Servidor de pruebas

Las pruebas de integración usan `.env.test` (ignorado por git) con
`SSH_TEST_HOST`, `SSH_TEST_PORT`, `SSH_TEST_USER`, `SSH_TEST_PASSWORD`. Sin esas
variables, los tests etiquetados `integration` se omiten.
