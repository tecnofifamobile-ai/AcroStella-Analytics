# Incremento 0.3.0+3: actualizaciones y anotaciones

23 de octubre de 2026, Europe/Madrid. Árbol de trabajo basado en `e06c389d7b0b1bf3addd3e3e86ae9d1b0788df75`. Verificación local Cloud Linux con Flutter 3.47.3, Dart 3.13.3, JDK 17 y Android SDK 36. No atribuir estos resultados a una ejecución de Actions ni a hardware físico.

## Resultado

- Resolución con `flutter pub get --enforce-lockfile`, formato y `flutter analyze --fatal-infos`: correctos, sin incidencias.
- `flutter test`: **81 pruebas superadas**. Incluyen cámara/reproductor simulados, archivos sintéticos, persistencia y temporalidad de anotaciones, geometría 2D, descargas incompletas/alteradas/canceladas, límites de metadatos, referencias Git inmutables, permisos y estados de instalación.
- `cd android && ./gradlew :app:testDebugUnitTest`: **7 pruebas nativas de política APK**, cero errores/fallos. Hash, paquete, código superior y continuidad de firmante. No son una instalación Android real.
- `flutter build apk --release`: correcto, 52.2 MB mostrados por Flutter. APK exacto: **52 234 231 bytes**.
- APK público descargado de nuevo con `dart run tool/check_update_feed.dart /tmp/acrostella-public-check`, utilizando el mismo `GitHubUpdateSource` y transporte que lleva la app, sin autenticación: versión 0.3.0, código 3, tamaño y SHA-256 verificados.
- `apksigner verify --verbose --print-certs` sobre el APK público: firma válida y mismo certificado que el APK Cloud 0.2.0. `aapt` confirma paquete, versión y permisos.

SHA-256 del APK local y público:

```text
d09db4eed05b08d3310c9b60d9cf0c64bbd51e1a995b84f2dbdd079bba326e8c
```

Certificado Android de pruebas, huella pública SHA-256:

```text
dfbc2a66221d8b63f7d473fac2e1b80ae7b6a968c2f16f757994f97b16936d3f
```

El APK optimizado sigue firmado con la clave persistente de pruebas del entorno, no una clave comercial. No se copió ninguna clave al proyecto, al repositorio público ni al manifiesto. Solo la huella pública permite comprobar continuidad. No garantiza compatibilidad con APK anteriores firmados en Windows/Actions con otras claves.

## Publicación real

El usuario autorizó un repositorio público solo de instaladores y creó `tecnofifamobile-ai/AcroStella-Updates`. Se confirmó público con permisos de escritura; el repositorio de código `AcroStella-Analytics` continúa privado.

Release estable publicada: [v0.3.0+3](https://github.com/tecnofifamobile-ai/AcroStella-Updates/releases/tag/v0.3.0%2B3). Commit público de instaladores: `d9115e333d57475420c7d46a069c1e14de724ad3`. El árbol de esa etiqueta contiene exactamente `README.md`, `acrostella-update.json` y el APK; no contiene fuentes ni grabaciones.

[Descarga directa del APK](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/v0.3.0%2B3/acrostella-analytics-0.3.0%2B3.apk).

La subida a `uploads.github.com` devolvió 401 con las credenciales de Cloud. La API Contents rechazó el tamaño del binario (422). Se publicó mediante un checkout separado exclusivamente del repositorio público, push Git atómico de APK/manifiesto y etiqueta, descarga pública y verificación antes de publicar el borrador de Release. La Release no tiene assets adjuntos: su enlace «Descargar APK» apunta al archivo de la etiqueta. El actualizador admite este canal y assets de Releases, sin abrir web ni incluir claves. Véase [distribución](../actualizaciones.md).

## Límites y verificaciones pendientes

Una ejecución amplia inicial de `./gradlew testDebugUnitTest` incluyó tests ajenos del plugin CameraX: 10 fallaron porque su sandbox Robolectric de Android SDK 36 exige Java 21 y el entorno usa Java 17. Las 7 pruebas de la app sí pasaron y se confirmó por separado el target `:app:testDebugUnitTest`. No se eliminaron assertions ni se presenta la batería de plugins como superada. La CI utiliza el target de la app.

No se ha instalado esta versión en S24/iPad ni probado el diálogo real de Android, cámara, decodificador o lápiz físico. No se ha compilado iOS 0.3.0 ni generado una IPA. No hay mediciones nuevas de rendimiento. Las anotaciones son manuales 2D sobre un clip temporal: no equivalen a biomecánica calibrada, tracking ni biblioteca definitiva. Siguen pendientes segunda cámara, sincronización y revisión continua mientras se graba.

Logs locales de esta ejecución en `/workspace/.acrostella-setup/logs/`: `v03-final-pub.log`, `v03-final-analyze.log`, `v03-final-tests.log`, `v03-app-native-tests.log`, `v03-final-build.log`, `v03-publish-git.log` y `v03-public-client.log`. Estas rutas son del entorno actual; este documento resume sus resultados y no se presenta como un log bruto.
