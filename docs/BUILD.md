# BUILD — Compilación y distribución

Este documento explica cómo se generan los binarios de Windows y Android, de
dónde salen los iconos y qué se verificó de verdad en cada plataforma.

## Entorno

| Herramienta | Versión usada | Nota |
| --- | --- | --- |
| Flutter / Dart | 3.50.0 stable / 3.14.0 | `flutter doctor` sin incidencias |
| Visual Studio | 2026 (18.12) | workload «Desktop development with C++» |
| Android SDK | 36.0.0 (platform 37, build-tools 36.0.0) | `minSdk` 24, `targetSdk` 36 |
| NDK | 30.0.16248370 | fijado en `android/app/build.gradle.kts` |
| JDK | Android Studio JBR (OpenJDK 25) | usado por Gradle |
| Inno Setup | 7.1.1 | `C:\Program Files\Inno Setup 7\ISCC.exe` |
| Edge | estable | solo para rasterizar el SVG de los iconos |

**Smart App Control**: con el Control inteligente de aplicaciones activo,
Windows bloquea `dartaotruntime.exe` del SDK de Dart y **el build de release
falla** («An Application Control policy… blocked execution»). El build de debug
funciona porque no usa AOT. En esta máquina se desactivó para poder compilar;
no hay forma de permitir solo ese binario.

## Iconos

El arte de origen está en `icons/`:

- `terminal-icon.svg` — marca vectorial (ventana de terminal con `>_` recortado).
- `terminal-svgrepo-com.png` — el mismo arte a 256 px, respaldo si falta Edge.
- `terminal-icon.ico` — el `.ico` que entregó el usuario; **no** se usa, se
  regenera desde el SVG para controlar cada tamaño.

Regenerar todo:

```powershell
pwsh -File tool/build_icons.ps1            # Windows + Android
pwsh -File tool/build_icons.ps1 -SkipAndroid
```

El script rasteriza el SVG a 1024 px con Edge en modo headless, compone cada
tamaño y escribe los PNG y el `.ico`. No hay dependencias nuevas.

### Por qué hay un fondo claro detrás de la marca

La marca es negra pura. Sobre fondo transparente desaparece en una barra de
tareas o un lanzador oscuro. Por eso cada icono se compone sobre una **placa
clara redondeada** (`#F6F7F9`):

- en modo oscuro se ve la placa y la silueta;
- en modo claro la placa se funde con el fondo y se ve la marca negra original.

En Android el mismo criterio se aplica con capas: la placa es la capa de fondo
del icono adaptativo (color `ic_launcher_background`) y la marca va en la capa
frontal, dentro de la zona segura. Se añade la capa **monochrome** para que
Android 13+ pueda tintar el icono con los colores del sistema.

Salidas:

| Archivo | Contenido |
| --- | --- |
| `windows/runner/resources/app_icon.ico` | 16, 20, 24, 32, 40, 48, 64, 128 y 256 px, entradas DIB sin comprimir |
| `android/app/src/main/res/mipmap-<densidad>/ic_launcher.png` | icono heredado (API 24-25): 48-192 px |
| `…/ic_launcher_foreground.png` | capa frontal del icono adaptativo: 108-432 px |
| `…/ic_launcher_monochrome.png` | capa para iconos temáticos de Android 13+ |
| `icons/generated/app-icon-1024.png` | vista maestra para documentación |

El `.ico` usa entradas DIB en todos los tamaños, incluido 256: es el formato que
leen igual Explorer, el cargador de recursos de Windows y el compilador de Inno
Setup. Las entradas PNG de 256 px ahorran bytes, pero algunas herramientas las
rechazan.

## Windows

```powershell
flutter build windows --release
& 'C:\Program Files\Inno Setup 7\ISCC.exe' tool\installer\ssh-client.iss
```

O todo junto: `pwsh -File tool/build_release.ps1 -Target windows`.

Artefactos:

- `build\windows\x64\runner\Release\ssh_client.exe` (+ `data`, DLLs y
  `sqlcipher.dll`; no es un ejecutable suelto: hay que distribuir la carpeta).
- `build\installer\ssh-client-<versión>-windows-x64-setup.exe`.

### Instalador (Inno Setup)

`tool/installer/ssh-client.iss`.

- **Instalación por usuario** (`PrivilegesRequired=lowest`): sin UAC, en
  `%LOCALAPPDATA%\Programs\SSH Client`. Los datos de la app ya son por usuario.
- **AppId fijo**: `{79B09999-D946-42E3-AB86-A7DF44FD4280}`. No cambiarlo, o las
  actualizaciones se instalan en paralelo en vez de actualizar.
- **Versión**: se lee del `VERSIONINFO` que Flutter escribe desde `pubspec.yaml`.
  `0.1.0+1` se traduce a `0.1.0.1`, de modo que el nombre del instalador incluye
  el número de build. Si no existe el release, el script **no compila**: evita
  empaquetar una carpeta vacía.
- **Tarea «Empezar de cero»** (desmarcada): borra
  `%LOCALAPPDATA%\dev.sshclient\ssh_client` y
  `%APPDATA%\dev.sshclient\ssh_client` antes de copiar archivos. Es la forma de
  instalar limpio sobre una máquina que ya usó builds de desarrollo.
- **Archivos abiertos**: `CloseApplications=yes` cierra la app con Restart
  Manager; no la vuelve a abrir (`RestartApplications=no`).
- **Desinstalar**: quita programa y accesos, **no** borra los datos del usuario.
- Silencioso (útil para probar): `setup.exe /VERYSILENT /SUPPRESSMSGBOXES
  /NORESTART /DIR="<carpeta>"`.

### Metadatos del ejecutable

`windows/runner/Runner.rc` publica `FileDescription = "SSH Client"` (lo que ven
Task Manager y «Aplicaciones instaladas») y `main.cpp` titula la ventana
«SSH Client». **`CompanyName` y `ProductName` se dejan intactos** a propósito:
`path_provider` deriva de ellos la carpeta `%APPDATA%\<empresa>\<producto>`, y
cambiarlos movería el archivo DPAPI de las claves y las preferencias de todas las
instalaciones existentes.

### Datos de la aplicación

| Ruta | Contenido |
| --- | --- |
| `%LOCALAPPDATA%\dev.sshclient\ssh_client` | catálogo, `profiles/`, staging y backups |
| `%APPDATA%\dev.sshclient\ssh_client` | `flutter_secure_storage.dat` (DPAPI) y `shared_preferences.json` |

Para dejar la máquina limpia: `pwsh -File tool/reset_dev_data.ps1 -Force`.

## Android

```powershell
flutter build apk --release                 # universal, todos los ABI
flutter build apk --release --split-per-abi # un APK por ABI
```

Artefactos en `build\app\outputs\flutter-apk\`:

| Archivo | Tamaño observado | Uso |
| --- | --- | --- |
| `app-release.apk` | 75,6 MB | instalar en cualquier dispositivo |
| `app-arm64-v8a-release.apk` | 27,6 MB | móvil moderno (recomendado) |
| `app-armeabi-v7a-release.apk` | 24,8 MB | dispositivos de 32 bits |
| `app-x86_64-release.apk` | 29,7 MB | emulador |

- Paquete `dev.sshclient.ssh_client`, etiqueta visible «SSH Client».
- `minSdk` 24, `targetSdk` 36.
- El APK incluye `arm64-v8a`, `armeabi-v7a` y `x86_64`; SQLCipher va compilado
  dentro (`sqlcipher.dll` en Windows, `.so` en Android).

### Firma

`android/app/build.gradle.kts` firma el release con la **clave de depuración**
(herencia del template de Flutter, con su `TODO`). Sirve para instalar y probar,
**no para publicar**: Play Store rechaza APK/AAB firmados en debug y la clave de
debug no es un secreto controlado por nosotros.

Para una distribución real hace falta un keystore propio y un
`android/key.properties` (ambos ignorados por git; ver `.gitignore`:

```properties
storeFile=<ruta al .jks>
storePassword=<...>
keyAlias=<...>
keyPassword=<...>
```

y leerlo desde Gradle. Esa decisión no se tomó en esta ronda porque implica
custodiar un secreto; queda pendiente.

## Verificación de esta ronda

```text
flutter analyze                                      → No issues found!
flutter test -x integration                          → +291 All tests passed!
flutter build windows --release                      → ✓ ssh_client.exe
ISCC tool\installer\ssh-client.iss                   → ✓ ssh-client-0.1.0.1-windows-x64-setup.exe (14,3 MB)
setup.exe /VERYSILENT /DIR=<temp>                    → exit 0, 32 archivos instalados
instalado + arranque                                 → asistente «Crea tu primer perfil» (sin perfiles), título «SSH Client»
unins000.exe /VERYSILENT                             → exit 0, carpeta y clave de desinstalación eliminadas, sin accesos
flutter build apk --release                          → ✓ app-release.apk (75,6 MB, firmado en debug)
flutter build apk --release --split-per-abi          → ✓ arm64 27,6 MB / armv7 24,8 MB / x86_64 29,7 MB
adb install app-x86_64-release.apk                   → Success en emulador API 37
arranque en el emulador                              → asistente «Crea tu primer perfil» (sin datos)
```

Comprobaciones del icono en el APK: `aapt dump badging` muestra
`application-label:'SSH Client'` y un icono adaptativo; `aapt2 dump xmltree`
confirma las capas `background`, `foreground` y `monochrome`, y los PNG están en
48/72/96/144/192 px (heredado) y 108/162/216/324/432 px (capas).

## Limitaciones de este entorno

- macOS y Linux no se pueden compilar ni verificar aquí.
- No hay dispositivo Android físico conectado: la app se probó en el emulador
  `Medium_Phone_API_37.0` (x86_64).
- El build de Android migró automáticamente AGP 9.1.0 → 9.1.1, Gradle 9.3.1 →
  9.5.0 y fijó `ndkVersion` en `android/app/build.gradle.kts`. Son cambios del
  propio Flutter, no manuales.
