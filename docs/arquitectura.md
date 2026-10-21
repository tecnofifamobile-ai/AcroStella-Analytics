# Decisiones que condicionan la implementación

## Primer incremento: cámara local

`CaptureSession` pertenece a la aplicación y serializa las operaciones nativas de un único `CaptureDevice`. Las vistas solo muestran su salida; reorganizarlas no abre ni cierra cámaras. Se utiliza `camera` 0.12.1 como primer adaptador, con implementaciones CameraX y AVFoundation resueltas en `pubspec.lock`. La previsualización usa la textura nativa, sin enviar fotogramas sin comprimir a Dart.

Se solicita el perfil 1080p y 30 fps. La interfaz muestra las dimensiones devueltas por el controlador; no se presenta la frecuencia solicitada como frecuencia medida. No hay todavía registro de vídeo, búfer circular ni medición de latencia.

La cámara solo se activa mediante una acción del usuario. El primer incremento desactiva audio. Salir de la aplicación suspende la cámara y volver permite reabrirla; esto es distinto de revisar dentro de la aplicación. No se garantiza captura con la aplicación en segundo plano ni con la pantalla bloqueada.

## Condición antes de incorporar WebRTC y replay

El contrato de cámara no demuestra que el plugin permita derivar fotogramas comprimidos. Antes de añadir transmisión, hay que comprobar sus puntos de extensión nativos y decidir entre ampliarlo o sustituir únicamente el adaptador. No se permitirá una segunda apertura mediante `getUserMedia` de una cámara que ya tenga propietario.

El propietario nativo deberá derivar la captura hacia previsualización, codificación y transmisión. El búfer temporal usará segmentos comprimidos con límites de tiempo y bytes; no se resolverá acumulando imágenes en Dart. La integración de vídeo remoto comprimido con el búfer del iPad es una investigación de implementación pendiente, no una capacidad existente de esta entrega.

## Flujo acordado para la siguiente fase

«Iniciar ejecución» y «Revisar» delimitarán un intervalo en una línea temporal común. No serán operaciones de apertura y cierre de cámara. La reproducción tendrá su propio cursor, compartido entre ángulos. La estimación del desfase y su incertidumbre quedarán separadas del tiempo de llegada de los paquetes.

La persistencia definitiva combinará SQLite y archivos locales; no se introduce hasta que haya ejecuciones que guardar. Las anotaciones usarán coordenadas normalizadas del vídeo, con cámara e intervalo temporal explícitos. No hay cuentas, telemetría ni subidas automáticas.

## Compilación

Flutter está fijado en `pubspec.yaml`, y las dependencias en `pubspec.lock`. El flujo de GitHub Actions ejecuta análisis, pruebas, APK de depuración y compilación iOS de dispositivo sin firma. La primera compilación iOS terminó correctamente en el run 39681910999 con Xcode 16.4 y SDK iPhoneOS 18.5. No utiliza certificados ni produce por sí solo una IPA instalable. Los identificadores iniciales son provisionales hasta comprobar, con autorización, las restricciones del perfil disponible. El estado detallado se conserva en `contexto/05-estado-y-evidencias.md`.

Referencias de implementación: [camera](https://pub.dev/packages/camera), [Flutter Camera](https://docs.flutter.dev/cookbook/plugins/picture-using-camera), [configuración de Flutter en CI](https://github.com/subosito/flutter-action).
