# UI_AUDIT — Ronda 3 (modernización)

Inventario de pantallas y widgets, estilos escritos a mano encontrados y la
checklist de modernización. Todas las filas quedan revisadas al cierre de la
ronda; lo no verificable en este entorno se declara.

## 1. Inventario de pantallas

| Pantalla / widget | Archivo | Estado |
| --- | --- | --- |
| Arranque / fallo de almacén | `app/startup_failure_app.dart` | Modernizado (tema + icono) |
| Gate de sesión | `app/session_gate.dart` | Revisado (sin estilos propios) |
| Bloqueo de perfil | `features/authentication/presentation/lock_screen.dart` | Modernizado (tema, SafeArea global, ancho máximo) |
| Asistente primer perfil | `features/profiles/presentation/first_run_screen.dart` | Modernizado |
| Shell de escritorio | `features/shell/presentation/home_shell.dart` | Modernizado (barra, fondo, iconos) |
| Sidebar | `features/shell/presentation/sidebar.dart` | Modernizado (tarjetas, badge, cabeceras sin mayúsculas, iconos Lucide) |
| Workspace / terminal | `features/workspace/presentation/workspace_panel.dart` | Modernizado (tema del terminal, EmptyState, iconos) |
| Diálogo huella TOFU | `features/workspace/presentation/host_key_dialog.dart` | Modernizado |
| Explorador SFTP | `features/sftp/presentation/sftp_panel.dart` | Modernizado (ruta editable, hover animado, iconos, tooltips) |
| Lista de transferencias | `features/sftp/presentation/transfer_list.dart` | Modernizado (progreso animado, colores de estado) |
| Ajustes | `features/settings/presentation/settings_dialog.dart` | Modernizado (Apariencia, Seguridad, Huellas, Respaldos) |
| Gestión de perfiles | `features/profiles/presentation/profile_management_dialog.dart` | Modernizado |
| Formulario de conexión | `features/connections/presentation/connection_form_dialog.dart` | Modernizado |
| Diálogo de colección | `features/collections/presentation/collection_dialog.dart` | Modernizado |
| Diálogos de respaldo | `features/backup/presentation/backup_dialogs.dart` | Modernizado |
| Confirmación de contraseña | `shared/widgets/confirm_password_dialog.dart` | Nuevo, reutilizable |
| Estados vacíos | `shared/widgets/empty_state.dart` | Nuevo, reutilizable |
| Indicador de estado | `shared/widgets/status_badge.dart` | Nuevo, reutilizable |
| Mensajes inline | `core/widgets/inline_message.dart` | Modernizado (tokens + iconos) |
| Barra de teclas móvil | `features/terminal/presentation/terminal_key_bar.dart` | Modernizado (tema; solo Android/iOS) |

## 2. Estilos escritos a mano encontrados

- **Colores**: `AppColors.*` en 14 archivos + `Color(0x...)` en el tema antiguo y
  paleta del terminal. Todos sustituidos por `colorScheme`, `AppTokens` o
  `AppPalette`; no queda ningún `Color(0x...)`/`Colors.white|black|grey` fuera de
  `lib/app/theme/`.
- **Tipografías**: `TextStyle` sueltos con tamaños y colores en sidebar, workspace,
  SFTP, transferencias y diálogos. Ahora usan `context.texts` y el `TextTheme`; la
  terminal mantiene JetBrains Mono mediante `AppTokens.terminalStyle`.
- **Mayúsculas**: cabeceras `toUpperCase()` en sidebar y ajustes; retiradas
  (frase normal, peso 600). Los tests que buscaban «FAVORITOS» se adaptaron.
- **Paddings mágicos**: `EdgeInsets` con valores 2,6,10,14,20,24... sustituidos
  por tokens `AppSpacing` (4/8/12/16/24/32) en las pantallas tocadas; se conservan
  valores intrínsecos de iconos (2 px de separación de chip).
- **Radios**: `AppShape` (8 px) sustituido por tokens (tarjeta 18, diálogo 22,
  botón 14, campo 12, chip 10).
- **Elevación/sombras**: sin sombras fuertes; diálogos con elevación 2.
- **Iconos**: `Icons.*` de Material en 12 archivos; centralizados en
  `AppIcons` sobre Lucide.

## 3. Checklist de modernización

- [x] Paleta clara y oscura a mano, sin `fromSeed` ni negro puro.
- [x] `ThemeExtension` con espaciados, radios, duraciones, curvas, estados y
      paleta de terminal.
- [x] `TextTheme` con Inter y jerarquía títulos/secciones/cuerpo/etiquetas.
- [x] Component themes de botones, campos, chips, diálogos, menús, tooltips,
      tabs, switches, checkboxes, scrollbars, progreso y listas.
- [x] Tema claro/oscuro/sistema con transición de 220 ms y persistencia global.
- [x] Terminal con paleta ANSI por tema y opción «siempre oscura».
- [x] Iconos Lucide centralizados en `AppIcons` (MIT, empaquetados).
- [x] Componentes reutilizables `EmptyState`, `StatusBadge`,
      `ConfirmPasswordDialog`; tokens de estado en `InlineMessage`.
- [x] Sidebar, cabeceras, tarjetas, listas y filas SFTP con hover/animaciones de
      150–250 ms.
- [x] Estados vacío/carga/error/éxito revisados en shell, workspace y SFTP.
- [x] SafeArea global, controles de 48 dp, scroll seguro en sidebar y diálogos.
- [x] Ancho máximo de formularios y ajustes; sin estirar en 1920 px.
- [x] Etiquetas semánticas en botones de icono (tooltips) y estado con texto
      además de color.
- [x] Tests de contraste AA/3:1 en ambos temas.
- [x] Tests de pantallas a 900×600, 1280×720 y 1920×1080, tema claro y oscuro,
      escala de texto 1.3, sin overflow.
- [x] Cambio de tema persistente y modo Sistema siguiendo al SO (tests).
- [ ] Golden tests: **omitidos** con motivo. En `flutter_test` las fuentes de
      assets no se cargan automáticamente (el motor usa Ahem), así que un golden
      de estas pantallas sería estable pero no representaría la tipografía real;
      se prefieren los tests de layout/contraste y se deja anotado en
      `docs/TESTING.md`. Los assets y el tema sí se prueban.
- [ ] Android/macOS/Linux en ejecución: no verificable aquí (sin toolchain). La
      UI móvil se cubre con widget tests (drawer, pestañas ya retiradas, SafeArea,
      escala de texto y barra de teclas).
