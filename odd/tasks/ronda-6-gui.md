# Ronda 6 — GUI (shell, dashboard, sesiones)

Objetivo: rehacer la GUI con el sistema neutro de la ronda 6 (barra superior de
pestañas, sidebar de 220 px, dashboard de conexiones) sin tocar lógica de
negocio, seguridad, base de datos, SSH/SFTP ni respaldos.
Rama: `ronda-6-gui`. Runner: `flutter test` (etiqueta `integration` aparte).

## Specs

- S1 — Paleta neutra y radios de la ronda 6 en ambos temas: fondos
  `#09090B`/`#0E0E10`, superficies `#151518`/`#1C1C20`/`#222227`,
  borde `#232328`, popover `#18181B`, acento de relleno `#2563EB`, acento de
  texto `#3B82F6`, estados `#22C55E`/`#F59E0B`/`#EF4444`; claros
  `#F3F4F6`/`#F9FAFB`/`#FFFFFF`/`#E5E7EB`/`#E4E4E7`; radios 12/10/8. El
  contraste AA (4.5:1 texto, 3:1 componentes) se mantiene verificado.
- S2 — Barra superior de 44 px con dos pestañas fijas («Conexiones» y «SFTP») y
  una pestaña por sesión abierta, con cierre individual. Cambiar de pestaña no
  cierra la sesión: terminal y SFTP siguen vivos.
- S3 — Sidebar de 220 px, contraíble a una barra de iconos, con navegación
  «Conexiones», «Huellas» y «Ajustes», y al pie el perfil y el bloqueo.
  En ventanas estrechas se comporta como cajón (`drawer`).
- S4 — Dashboard de conexiones en el área principal: buscador, selector de
  vista cuadrícula/lista, orden, botón «Nueva conexión» y «Nueva colección»,
  sección «Favoritos», tarjetas de colección y tarjetas de conexión con menú
  (editar, favorito, eliminar).
- S5 — Panel de detalles de conexión de 360–400 px que sustituye al diálogo de
  edición, conservando validación y reautenticación.
- S6 — Vista de huellas conocidas en el área principal, con borrado por huella.
- S7 — Todas las etiquetas visibles en español, con claves nuevas en
  `lib/l10n/app_es.arb`.
- S8 — Sin cambios de lógica de negocio: misma base de datos, mismos servicios,
  mismas claves `Key(...)` que usan los tests existentes.
- S9 — Cada fase termina en verde: `dart format`, `flutter analyze` sin avisos y
  `flutter test -x integration` en verde, con commit propio.

## Tasks

| ID | Descripción | Specs | Ruta | Estado |
| --- | --- | --- | --- | --- |
| T1 | Paleta, radios y tema de componentes | S1 | inline | [x] `cf20120` |
| T2 | Controlador de pestañas y sesiones vivas | S2, S8 | inline | [x] `test/features/shell/shell_tabs_test.dart` |
| T3 | Barra superior de 44 px con pestañas | S2, S7 | inline | [x] `test/features/shell/shell_tabs_test.dart` |
| T4 | Sidebar 220 contraíble con navegación | S3, S7 | inline | [x] `test/features/shell/dashboard_test.dart` |
| T5 | Dashboard de conexiones y colecciones | S4, S7 | inline | [x] `test/features/shell/dashboard_test.dart` |
| T6 | Vista de huellas en el área principal | S6 | inline | [x] `test/features/shell/dashboard_test.dart` |
| T7 | Panel de detalles de conexión | S5 | inline | [ ] |
| T8 | Rediseño SFTP de un panel | S4 | inline | [ ] |

## Log

- L1 (2026-11-15, verificación): «vamos a la ronda 6».
- L2 (2026-11-15, verificación): «recuerda igual ir actualizando todos los .md
  para que si llega un nuevo agente sepa donde estamos».
- L3 (2026-11-15): T1 cerrado con `flutter analyze` limpio y
  `flutter test -x integration` → +270. La paleta y los radios quedan
  verificados por `test/app/theme_test.dart` y `test/app/theme_contrast_test.dart`.
- L4 (2026-11-15): el spec de la ronda 6 (barra de pestañas, sidebar de 220,
  dashboard, panel de detalles) no existe como archivo en el repositorio; se
  transcribe aquí desde la petición de la ronda. Cualquier requisito que no esté
  en S1–S9 y aparezca después se añadirá como `S#` nuevo con su entrada de log.
- L5 (2026-11-15): la pestaña fija «SFTP» muestra el explorador de la sesión
  activa; sin sesión SFTP muestra un estado vacío con la explicación. No se abre
  un canal SFTP nuevo sobre una sesión SSH (sería lógica nueva, fuera de S8).
- L6 (2026-11-15): «Ajustes» abre el diálogo existente en vez de una pantalla
  propia, para no duplicar el formulario de respaldos, perfiles y reset.
- L7 (2026-11-15): T2–T6 cerrados. `flutter analyze` → No issues found!;
  `flutter test -x integration` → +280 (270 previos + 5 de pestañas + 5 de
  dashboard). Los tests de shell existentes pasan sin cambios. La integración real
  contra `192.168.100.129:22` sigue sin ejecutarse (host no alcanzable).
- L8 (2026-11-15): el buscador del dashboard filtra por nombre, host, usuario y
  etiqueta; los filtros por etiqueta aparecen solo si hay etiquetas guardadas.
  No se persiste la vista cuadrícula/lista: es estado de pantalla.
