# 0.4.0+4: ejercicio, revisión y biblioteca

23 de octubre de 2026, Cloud Linux, sobre la rama privada `codex/android-updates-annotations` y la entrega 0.3.0 (`9a5a2ee`). Flutter 3.47.3/Dart 3.13.3/JDK 17. No se utilizaron vídeos reales ni certificados Apple.

## Implementado

Iniciar ejercicio activa el propietario existente de cámara si hace falta y comienza una grabación finita. Terminar abre y reproduce directamente el vídeo. Guardar conserva el archivo con sus dibujos y metadata en soporte privado; Eliminar espera al cierre del decodificador; Otro ejercicio vuelve a grabar desde la revisión inmediata. Volver desde un pendiente ofrece Guardar/Eliminar/Decidir después. La biblioteca permite reabrir, buscar por nombre/notas y filtrar favoritos/pendientes.

Anotaciones: dibujo libre, línea, ángulo, flecha, rectángulo y elipse, cuatro colores, tres grosores, duración 1/3/5 s o hasta el final, deshacer/rehacer, ocultar y borrar dibujos visibles. Repetición A–B, momentos persistentes con salto directo, cámara lenta y saltos de un segundo. El original no se modifica ni se exporta recortado.

## Verificación local

Comandos ejecutados sobre el código final:

```text
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool/check_update_feed.dart
flutter analyze --fatal-infos
flutter test
flutter build apk --release
flutter build apk --debug
cd android && ./gradlew :app:testDebugUnitTest
```

Lock y formato correctos; análisis sin incidencias; builds Android release y debug correctos; **102 pruebas Flutter superadas**. Cubren el flujo iniciar/terminar/revisión/guardar/eliminar/otro, finalización automática sin doble ruta, conservación del propietario, archivo fijado hasta el cierre, salida durante inicialización, fallos de escritura, cuotas separadas, reapertura, migración compatible, geometría y estilos, gestos reales de dibujo/cancelación con decodificador simulado, deshacer/rehacer, biblioteca/filtros, A–B y tamaños 393×852, 852×393 y 1366×1024. Se mantienen las pruebas de descarga/verificación de actualizaciones.

El target nativo de la app termina con `BUILD SUCCESSFUL`, 7 pruebas y cero fallos/errores (política sin cambios respecto a 0.3.0, outputs válidos reutilizados por Gradle). No se amplió al target global de plugins, cuya limitación Robolectric/Java 17 se registró en la evidencia anterior.

APK release compilado: **55 332 651 bytes** (55.3 MB en Flutter). SHA-256:

```text
5c6eb8f0fe2a8da0348dfe4f9e9960aef647459e79690693f532d74eac5e2317
```

## Límites

Un ángulo, sin audio. Stop solicitado a los 3 minutos; el archivo activo no tiene límite duro de bytes de esta API. Se rechazan vídeos finalizados de más de 256 MiB. Pendientes: máximo 3/512 MiB, eliminables por retención; guardados: 200/2 GiB sin borrado automático. La cuota de guardados llena rechaza guardar y deja el pendiente disponible. La migración copia los clips 0.3.0 todavía presentes; no recupera caché ya purgada. La eliminación de un importado retira también su copia antigua; se conserva durante la migración hasta esa decisión o retención de pendientes. La biblioteca se pierde al desinstalar o borrar datos y aún no tiene exportación/respaldo propio.

La app no incorpora nube, body tracking, calibración biomecánica, zoom/pan, stepping exacto, segundo ángulo ni revisión continua comprimida. Las medidas son manuales 2D de la imagen. Las pruebas usan cámaras/decodificadores simulados y archivos sintéticos; cámara, lápiz, instalación Android y almacenamiento prolongado requieren validación física.

## Publicación verificada

[Release estable 0.4.0+4](https://github.com/tecnofifamobile-ai/AcroStella-Updates/releases/tag/v0.4.0%2B4), commit público de instaladores `a77345caeff0bcdce59863d31a69db1f4ae09e33`. [APK directo](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/v0.4.0%2B4/acrostella-analytics-0.4.0%2B4.apk). El árbol público contiene README, APK 0.3.0, APK 0.4.0 y manifiesto; el repositorio de código sigue privado.

Publicación mediante el modo Git autorizado. Hubo errores 503 transitorios de GitHub; se inspeccionó el estado remoto antes de reintentar mutaciones y no se sustituyó ninguna etiqueta publicada. Las consultas y descargas del publicador admiten reintentos, sin repetir mutaciones automáticamente. El aviso de GitHub por superar su recomendación de 50 MiB no impidió el push: el APK está por debajo del límite de 100 MiB de este canal.

`dart run tool/check_update_feed.dart /tmp/acrostella-public-check-v04` consultó la versión estable y descargó íntegramente 55 332 651 bytes sin autenticación usando el mismo cliente que la app. Tamaño y SHA-256 coinciden con el APK local; `apksigner verify --verbose --print-certs` sobre la descarga confirma firma v2 válida y continuidad de la clave de pruebas de 0.3.0 (huella `dfbc2a66221d8b63f7d473fac2e1b80ae7b6a968c2f16f757994f97b16936d3f`). `aapt` confirma paquete `com.acrostella.acrostella_analytics`, versión 0.4.0, código 4, minSdk 24, targetSdk 36. No equivale a instalación física. Log adicional: `v04-public-client.log`.

## Apple

La CI de 0.3.0 falló en `video_player_avfoundation` 2.12.2 con el SDK de Xcode 16.4: extra argument `isolation`. El job iOS 0.4.0 de [CI 40004598011](https://github.com/tecnofifamobile-ai/AcroStella-Analytics/actions/runs/40004598011), commit `08729ef9a9422a2e69970d2d12319559be3d70b9`, terminó con **success**. Logs observados: Xcode **26.3 (17C529)**, SDK iPhoneOS **26.2**, `Built build/ios/iphoneos/Runner.app (18.1MB)`. Se conserva un [extracto seleccionado](2026-10-23-ios-ci-extracto.txt). Artefacto `acrostella-ios-unsigned`, ID `12523931033`, ZIP de 7 398 146 bytes, retención 7 días. Es Runner.app sin firma empaquetada: **no una IPA instalable**, ni evidencia de ejecución en el iPad. No se utilizaron certificados Apple.

Logs locales: `/workspace/.acrostella-setup/logs/v04-{pub,format,analyze,tests,build,native-tests,publish}.log`. Este documento resume resultados; no es un log bruto ni una medición de hardware.

## CI completa

[Run 40004598011](https://github.com/tecnofifamobile-ai/AcroStella-Analytics/actions/runs/40004598011), commit `08729ef9a9422a2e69970d2d12319559be3d70b9`: workflow **success**, jobs `checks` e `ios` **success**. Incluye lock/formato/análisis, 102 tests Flutter, APK debug y el target de pruebas nativas propio. Artefacto Android `acrostella-android-debug`, ID `12524356576`, ZIP de 78 973 069 bytes. Es una compilación de CI con su propia clave de depuración: las actualizaciones compatibles distribuidas son el APK release Cloud ya verificado, no este artefacto. [Respuesta estructurada seleccionada](2026-10-23-ci-v04.json). Las actualizaciones documentales posteriores conservan el mismo código de aplicación probado.
