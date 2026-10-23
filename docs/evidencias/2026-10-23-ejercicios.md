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
cd android && ./gradlew :app:testDebugUnitTest
```

Lock y formato correctos; análisis sin incidencias; **102 pruebas Flutter superadas**. Cubren el flujo iniciar/terminar/revisión/guardar/eliminar/otro, finalización automática sin doble ruta, conservación del propietario, archivo fijado hasta el cierre, salida durante inicialización, fallos de escritura, cuotas separadas, reapertura, migración compatible, geometría y estilos, gestos reales de dibujo/cancelación con decodificador simulado, deshacer/rehacer, biblioteca/filtros, A–B y tamaños 393×852, 852×393 y 1366×1024. Se mantienen las pruebas de descarga/verificación de actualizaciones.

El target nativo de la app termina con `BUILD SUCCESSFUL`, 7 pruebas y cero fallos/errores (política sin cambios respecto a 0.3.0, outputs válidos reutilizados por Gradle). No se amplió al target global de plugins, cuya limitación Robolectric/Java 17 se registró en la evidencia anterior.

APK release compilado: **55 332 651 bytes** (55.3 MB en Flutter). SHA-256:

```text
5c6eb8f0fe2a8da0348dfe4f9e9960aef647459e79690693f532d74eac5e2317
```

## Límites

Un ángulo, sin audio. Stop solicitado a los 3 minutos; el archivo activo no tiene límite duro de bytes de esta API. Se rechazan vídeos finalizados de más de 256 MiB. Pendientes: máximo 3/512 MiB, eliminables por retención; guardados: 200/2 GiB sin borrado automático. La cuota de guardados llena rechaza guardar y deja el pendiente disponible. La migración copia los clips 0.3.0 todavía presentes; no recupera caché ya purgada. La biblioteca se pierde al desinstalar o borrar datos y aún no tiene exportación/respaldo propio.

La app no incorpora nube, body tracking, calibración biomecánica, zoom/pan, stepping exacto, segundo ángulo ni revisión continua comprimida. Las medidas son manuales 2D de la imagen. Las pruebas usan cámaras/decodificadores simulados y archivos sintéticos; cámara, lápiz, instalación Android y almacenamiento prolongado requieren validación física.

## Apple

La CI de 0.3.0 falló en `video_player_avfoundation` 2.12.2 con el SDK de Xcode 16.4: extra argument `isolation`. La CI 0.4.0 selecciona Xcode 26.3, presente en la imagen oficial de macOS 15 consultada. Se verificará su resultado real; la configuración no prueba compilación ni instalación. No se firma ni se genera IPA instalable.

Logs locales: `/workspace/.acrostella-setup/logs/v04-{pub,format,analyze,tests,build,native-tests,publish}.log`. Este documento resume resultados; no es un log bruto ni una medición de hardware.
