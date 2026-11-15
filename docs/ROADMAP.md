# ROADMAP — Propuestas fuera de alcance

Elementos que la aplicación **no** implementa hoy. Algunos exigirían cambios de
modelo o de contrato; se documentan para que nadie los dé por hechos.

## Fuera de alcance por decisión de producto

- **Terminal local**: requeriría un PTY local multiplataforma (plugin nativo) y un
  modelo de «sesión local» separado del SSH.
- **Keychain de llaves e identidades compartidas**: hoy cada credencial guarda su
  PEM en el almacén del sistema. Compartir identidades entre conexiones exige una
  entidad `Identity` con su tabla, migración y un panel propio.
- **Historial y Logs**: implican almacenar comandos/salida, lo que choca con la
  regla de no guardar salida ni comandos.

## GUI de la ronda 6 (pendiente)

- Barra superior de pestañas con sesiones vivas, sidebar de navegación de 220 px,
  dashboard de conexiones con búsqueda/colecciones/cuadrícula y panel de detalles
  deslizante. Requiere un controlador de sesiones múltiples y extraer el formulario
  de conexión a un componente reutilizable conservando reautenticación.
- Rediseño del explorador SFTP (tabla, selección múltiple, menú contextual,
  permisos chmod). Requiere mapear `SftpFileAttrs.mode` a un formulario rwx y
  probar chmod contra el servidor.
- Pestañas de sesión y SFTP de doble panel (fases 4 y 5 de la ronda 6).
- `osHint` en `Connection` + detección `cat /etc/os-release`: migración de esquema y
  `formatVersion` de backups.
- Barra de título propia con `window_manager`: no se añade sin poder verificar
  arrastre/maximizar en Windows.
