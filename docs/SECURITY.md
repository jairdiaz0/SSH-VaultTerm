# SECURITY — SSH Client

Modelo de amenazas, inventario criptográfico y reglas de implementación. Este
documento describe lo que el producto **sí** protege y lo que **no**, sin
prometer garantías que no existen.

## 1. Modelo de amenazas (SPEC §1)

### Protege contra

| Amenaza | Mecanismo |
| --- | --- |
| Lectura de los ficheros SQLite sin la clave | SQLCipher 4.20.0 con clave CSPRNG de 32 bytes por base; sin clave en disco |
| Uso de la interfaz sin la contraseña del perfil | Pantalla de bloqueo al arrancar; verificador Argon2id; no hay ruta que abra una BD de perfil sin desbloquear |
| Fuga de secretos por logs | `AppLogger` con API cerrada (evento + campos) y redacción por nombre de campo |
| Fuga de secretos hacia backups no deseados | Advertencia bloqueante + confirmación explícita antes de exportar; las claves de BD nunca se exportan |
| MITM por sustitución de host key | TOFU obligatorio: SHA-256, confirmación en el primer contacto, bloqueo si la huella cambia |
| Fuerza bruta sobre la contraseña del perfil | Retardo progresivo persistente (sobrevive a reinicios) y mensajes genéricos |
| Credenciales en la base de datos | Los secretos SSH viven **solo** en el almacén secreto del sistema, con namespace por perfil y credencial |

### No protege contra

- **Un atacante con la sesión del sistema operativo ya desbloqueada** y con acceso
  al llavero/almacén del usuario. A esa altura puede leer las claves de BD y los
  secretos SSH. No hay defensa posible dentro del mismo usuario.
- **Fuerza bruta offline sobre la contraseña del perfil** si el atacante obtiene
  un backup JSON exportado: ese fichero incluye sal y verificador. Argon2id lo
  encarece, no lo impide.
- **La contraseña del perfil NO deriva claves**: es una puerta de la interfaz.
  Las claves de las bases de datos son aleatorias y viven en el almacén seguro.
  Quien tenga las claves abre las bases aunque no sepa la contraseña.
- **Capturas de memoria, swap o volcados de proceso**: Dart no ofrece borrado
  garantizado de memoria. El cierre de sesión libera el handle de la BD y deja de
  referenciar los objetos, pero no puede garantizar que el recolector no conserve
  copias. Las `String` de Dart son inmutables y no se pueden sobrescribir: el
  borrado de secretos en memoria es **de mejor esfuerzo**, y así se declara.
- **Un servidor comprometido**: el cliente no audita lo que el servidor devuelve
  (por ejemplo, una shell que exfiltra lo que el usuario escribe).

## 2. Inventario criptográfico

| Uso | Algoritmo / parámetros | Dónde |
| --- | --- | --- |
| Cifrado de bases de datos | SQLCipher 4 (AES-256-CBC + HMAC-SHA512, salt por fichero), clave en crudo `x'<hex>'` de 32 bytes | `core/database/encrypted_database.dart` |
| Generación de claves | CSPRNG del sistema (`Random.secure`) → 32 bytes | `core/security/secure_random.dart` |
| Contraseña del perfil | Argon2id, 64 MiB, t=3, p=2, hash 32 B, sal 16 B por perfil | `core/security/password_hasher.dart` |
| Comparación de verificadores | Comparación en tiempo constante | `constantTimeEquals` |
| Huella de host key | SHA-256 estilo OpenSSH (`SHA256:<base64>`) entregada por `dartssh2` | fase 2 |
| Aleatoriedad de UUID | `uuid` v4 (aleatorio) | `ProfileService` |

Ningún algoritmo criptográfico es propio. Ninguna primitiva se reimplementa.

### Parámetros de Argon2id y migración

Los parámetros se guardan junto al verificador (`kdf_params`, JSON) para poder
subirlos después sin invalidar perfiles existentes. Al verificar se usan los
parámetros **almacenados**, no los globales. Si en el futuro se suben, un
rehash perezoso en el siguiente desbloqueo correcto es el camino previsto; hoy no
se rehashea automáticamente.

Verificado contra un vector de referencia de `argon2-cffi` (ver
`docs/TESTING.md`), no solo contra sí mismo.

## 3. Claves y secretos

- Un fichero de BD = una clave. Nunca se comparte clave entre catálogo y perfil,
  ni entre perfiles.
- Namespace de secretos (`SecretKeys`):
  `catalog/dbKey`, `profile/<profileId>/dbKey`,
  `profile/<profileId>/credential/<credentialId>`.
- El borrado de un perfil elimina **primero** sus secretos y después la fila y
  los ficheros: peor caso, quedan ficheros cifrados sin clave.
- Si el almacén del sistema no está disponible, `AppServices.bootstrap` falla con
  `AppErrorCode.secureStorageUnavailable` y la app muestra un error. **No hay
  respaldo en texto plano.** Nunca.

### Requisitos por plataforma

| Plataforma | Requisito | Estado aquí |
| --- | --- | --- |
| Windows | Credential Manager / DPAPI (`flutter_secure_storage`) | no verificable en ejecución (D-001) |
| macOS | entitlement de Keychain en el runner | no verificable en ejecución |
| Linux | libsecret + keyring desbloqueado | no verificable; sin llavero → error explícito |
| Android | `minSdk` del plugin; backup desactivado | no verificable (sin SDK) |

La verificación en ejecución del almacén real está bloqueada por el entorno
(`docs/DECISIONS.md` D-001). Lo que sí está verificado: toda la app usa una
interfaz `SecretStore`, y los tests la ejercitan con una implementación en
memoria; el contrato de claves está cubierto por tests.

## 4. Autenticación local del perfil

- Se guarda **solo** sal + verificador. La contraseña nunca se almacena ni se
  registra.
- Fallo → `AppErrorCode.invalidCredentials` → mensaje genérico
  («Contraseña incorrecta.»). No se distingue «perfil inexistente» de
  «contraseña incorrecta» en la UI.
- Anti-fuerza bruta: 3 intentos sin espera, después retardo exponencial
  2 s → 4 s → 8 s … con tope de 5 minutos. `failed_attempts` y `lockout_until` se
  persisten en el catálogo: reiniciar la app no borra la penalización.
- La pantalla bloqueada **no** permite crear perfiles (el gate no expone esa
  ruta y `SessionController.createProfile` la rechaza). Solo permite elegir otro
  perfil existente y desbloquearlo (decisión D-008).
- Reautenticación opcional por perfil (`settings.requireReauthOnEdit`): cuando
  está activa, los cambios sensibles piden la contraseña. `confirmPassword` no
  toca los contadores de bloqueo (la sesión ya está autenticada).

## 5. Host keys (TOFU) — fase 2

Reglas no negociables, ya fijadas antes de implementar:

- `onVerifyHostKey` **nunca** se pasa como `null`: en `dartssh2` eso acepta
  cualquier clave.
- Primera conexión: mostrar `SHA256:<base64>` y exigir confirmación explícita.
- Conexiones posteriores: comparar con `known_hosts`; si difiere, **bloquear** y
  advertir. No hay opción «continuar de todos modos» silenciosa.
- Las huellas se pueden revisar y borrar desde la UI (Ajustes → Seguridad).
- Prohibido desactivar la verificación para depurar, incluso con variables de
  entorno.

## 6. Logs

`AppLogger` no acepta mensajes libres arbitrarios: recibe un nombre de evento y un
mapa de campos, y redacta (`***`) cualquier campo cuyo nombre contenga
`password`, `passphrase`, `secret`, `token`, `credential`, `key`, `pem` o
`privatekey`. Reglas adicionales:

- nunca se registran comandos, salida de terminal, contenido de llaves ni
  contraseñas;
- las excepciones que llegan a la UI y a los logs usan `AppException.description`,
  que solo expone el código y el **tipo** de la causa;
- el mensaje del driver SQLite, de `dartssh2` o de `flutter_secure_storage` no se
  muestra al usuario.

## 7. Superficie de red

- La app solo abre conexiones SSH/SFTP hacia los servidores que configura el
  usuario. Sin analíticas, telemetría, publicidad ni backend propio.
- No hay comprobaciones de actualización ni descargas en tiempo de ejecución. Las
  fuentes y assets van empaquetados.

## 8. Secretos fuera de la app

- `.env.test` (credenciales del servidor de pruebas) está ignorado por git y
  nunca se usa desde `lib/`.
- Los tests de integración crean `run_<uuid>/` dentro de
  `~/opencode_sandbox/` del usuario remoto y lo borran al terminar. Nunca operan
  fuera de ese directorio.
- Los tests generan pares de llaves efímeros y retiran la clave pública de
  `authorized_keys` con el comentario `opencode-test-<uuid>` al final.

## 9. Pendiente y limitaciones declaradas

- Verificación en ejecución del almacén secreto real: bloqueada por el entorno
  (D-001). No se simula.
- Cifrado en reposo del *almacén del sistema*: depende de la plataforma (DPAPI,
  Keychain, libsecret). El proyecto no añade cifrado propio encima.
- Rotación de claves de BD: no implementada. Cambiar la contraseña del perfil no
  cambia la clave de la BD (por diseño: no deriva de ella).
- Borrado de memoria: mejor esfuerzo, documentado arriba.
