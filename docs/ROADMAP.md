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

## GUI de la ronda 6 (parcialmente implementada)

- **Panel de detalles de conexión** (360–400 px) que sustituya al diálogo de
  edición: requiere extraer el formulario a un componente reutilizable
  conservando validación, reautenticación y la tarjeta de credenciales.
- **Rediseño del explorador SFTP** (tabla, selección múltiple, menú contextual,
  permisos chmod y cola de transferencias rediseñada). Requiere mapear
  `SftpFileAttrs.mode` a un formulario rwx y probar chmod contra el servidor.
- **Quick connect** de la barra del dashboard: para conectar sin guardar hace
  falta una credencial efímera (hoy `SshService.connect` carga la credencial por
  id del almacén). Es una decisión de seguridad, no de UI.- **Badges de sistema operativo**: necesitan `osHint` en `Connection` y detección
  `cat /etc/os-release`; implican migración de esquema y `formatVersion` de
  backups.
- Pestañas de sesión y SFTP de doble panel (fases 4 y 5 de la ronda 6).
- Barra de título propia con `window_manager`: no se añade sin poder verificar
  arrastre/maximizar en Windows.
