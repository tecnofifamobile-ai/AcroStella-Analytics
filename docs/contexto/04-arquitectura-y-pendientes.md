# Arquitectura real y decisiones pendientes

Este documento distingue **código existente**, **condiciones del encargo** y **propuestas pendientes**. No hay todavía motor multicámara, búfer comprimido ni persistencia de ejecuciones.

**Actualización 0.3.0 (23 de octubre):** existen grabación finita y reproducción de clips locales, cuota y recuperación, líneas/ángulos temporales y actualizador Android público. Las secciones que describen solo abrir/cerrar corresponden a la base 0.1.0. `VideoCaptureDevice` y `CaptureSession` serializan grabación/finalización y ciclo de vida. Véase [la arquitectura actual](../arquitectura.md) para límites, propiedad, anotaciones y distribución. WebRTC y segmentación siguen sin resolverse; no añadir un segundo propietario de cámara.

## 1. Estructura existente

| Ruta | Responsabilidad implementada |
| --- | --- |
| `lib/main.dart` | Inicializar Flutter y abrir `AcroStellaApp` |
| `lib/src/app.dart` | Tema, propietario de cámara de ámbito de aplicación y observación del ciclo de vida |
| `lib/src/capture/capture_device.dart` | Contrato `CaptureDevice`, formato devuelto y fallo tipado |
| `lib/src/capture/capture_session.dart` | Serialización de apertura/cierre y estados de cámara |
| `lib/src/capture/flutter_camera_device.dart` | Adaptador del plugin `camera`, selección trasera y traducción de errores |
| `lib/src/training/training_screen.dart` | Pantalla compartida adaptable y controles de prueba local |
| `test/capture_session_test.dart` | Pruebas del propietario usando `TestCamera` |
| `test/training_screen_test.dart` | Disposiciones de pantalla y conservación del propietario |
| `android/` | Proyecto Android generado por Flutter con permiso de cámara |
| `ios/` | Proyecto Apple generado por Flutter, descripción de permiso de cámara y orientaciones |
| `.github/workflows/ci.yml` | Análisis, tests y compilaciones Android/iOS sin firma |

No existe una carpeta oculta con la implementación restante. La vista remota dice expresamente que todavía no está disponible.

## 2. Dependencias y configuración

- Flutter 3.47.3 fijado en `pubspec.yaml`; Dart observado 3.13.3.
- `camera` 0.12.1 fijado directamente.
- Implementaciones resueltas: `camera_android_camerax` 0.7.6, `camera_avfoundation` 0.10.3+1 y `camera_platform_interface` 2.15.0, según el lock del incremento inicial.
- `flutter_lints` como dependencia de desarrollo. No hay biblioteca externa de estado: se usa `ChangeNotifier`/`ListenableBuilder`.
- No hay dependencias WebRTC, SQLite, pose, nube ni analíticas añadidas.
- Android: applicationId `com.acrostella.acrostella_analytics`, minSdk 24, target/compile SDK 36 observados en APK.
- Apple: identificador inicial `com.acrostella.acrostellaAnalytics`; despliegue inicial generado 15.0. El identificador debe confrontarse con el perfil antes de firmar.

Las versiones transitorias no deben cambiarse solo por ser inferiores a una publicada más tarde. Resolver compatibilidad y reconstruir antes de actualizar el lock.

## 3. Propiedad de cámara implementada

`AcroStellaApp` crea una instancia de `FlutterCameraDevice` y una de `CaptureSession`. La pantalla toma prestadas esas instancias. `CameraPreview` representa la textura del controlador; no inicia una segunda sesión ni copia fotogramas crudos a Dart.

`CaptureSession` usa una cola de futuros para serializar la interacción nativa. Mantiene intención de activación, estado de primer plano, recurso abierto y destrucción. Esto evita abrir otra vez ante varias pulsaciones concurrentes y cierra el resultado tardío si se detuvo o destruyó la sesión mientras esperaba permisos.

Estados existentes: `idle`, `opening`, `live`, `suspended`, `failed`. `CaptureFormat` informa dimensiones y nombre de cámara. `CaptureFailure` lleva código y texto. La resolución y FPS pedidos no son mediciones de rendimiento.

`FlutterCameraDevice.open()` comprueba plataforma iOS/Android, enumera cámaras, selecciona la primera trasera, pide `ResolutionPreset.veryHigh`, `fps: 30` y `enableAudio: false`. No se ha validado aún cuál de las traseras físicas representa la primera en cada dispositivo. No hay selección de lente, control de zoom óptico, exposición ni enfoque.

Al salir de la aplicación se libera la cámara. Volver al primer plano la reabre si seguía solicitada. Cambiar disposición o tema dentro de la app conserva el propietario. El encargo de captura continua durante revisión no implica captura garantizada en segundo plano del sistema.

## 4. Lo que el contrato actual no resuelve

El contrato solo ofrece abrir/cerrar para preview. No expone todavía muestras de vídeo, paquetes comprimidos, tiempo de sensor, encoder, destinatarios, buffers ni grabación.

No afirmar que encapsular un plugin resuelve por sí mismo el fan-out multimedia. Antes de transmisión/replay hay que determinar con código nativo y documentación concreta:

1. Dónde se produce cada muestra y qué reloj usa.
2. Qué componentes poseen captura, encoder y buffers.
3. Cómo se deriva la muestra a preview y WebRTC sin abrir la cámara otra vez.
4. Dónde se conserva vídeo comprimido local y recibido, con tiempos recuperables.
5. Qué copias/codificaciones resultan inevitables y cómo medirlas.

Si el plugin no proporciona los puntos de extensión, ampliar o sustituir el adaptador, manteniendo el dueño de aplicación, componentes y modelos compartidos. No añadir una segunda sesión como atajo.

## 5. Investigación de implementación prioritaria

### Captura local y emisión remota

Comprobar la integración real entre AVFoundation/CameraX y la biblioteca WebRTC elegida. `flutter_webrtc 1.6.2+hotfix.4` es una referencia aportada por el usuario, no una dependencia validada. Investigar acceso al capturador, soporte de frames externos y puntos de extensión antes de fijar versión.

Mantener las muestras pesadas en nativo cuando sea viable. Un `MethodChannel` es adecuado para control y metadatos; no asumir que enviar todos los píxeles por él es una solución de tiempo real.

### Vídeo remoto y búfer comprimido

Recibir WebRTC no demuestra que el plugin exponga el flujo comprimido necesario para guardar segmentos. Verificar qué ocurre antes y después del decoder, orientación, keyframes, timestamps y límites del receptor. Si hacen falta cambios nativos, definirlos explícitamente. No iniciar una transferencia manual de archivos como sustituto de replay.

### Segmentación y reproducción simultánea

Propuesta: índice de segmentos comprimidos con rangos temporales, tamaño, fuente y relación con la sesión. Los lectores fijan segmentos que necesiten; el borrado respeta esas referencias. Definir continuidad de decodificación y keyframes. Evitar depender de `stopVideoRecording()` de un archivo monolítico para poder revisar mientras sigue la captura.

Estas son líneas de implementación pendientes, no afirmaciones de que el diseño de contenedor/codec ya esté elegido.

## 6. Sincronización

Propuesta de contratos: reloj monotónico por fuente, estimación de mapeo a reloj de sesión, incertidumbre y corrección manual. Guardar metadatos que permitan reproducir el ajuste aplicado. El orden de llegada de paquetes no sustituye al tiempo de captura.

Al introducir DataChannels o señalización local, medir intercambio de tiempos y jitter. Considerar deriva en sesiones largas y reset de timestamps tras reconexión. No fijar un número de milisegundos alcanzable sin medición.

Separar retraso del directo, desplazamiento entre fuentes y cursor de revisión. La primera aceptación es alineación útil y transparente para el entrenador; no implica una validación de laboratorio.

## 7. Anotaciones y almacenamiento futuros

La transformación debe componer rectángulo real de vídeo, letterboxing, rotación, zoom, desplazamiento y coordenadas normalizadas. Vincular cada dibujo a fuente e intervalo/fotograma. Añadir pruebas de ida/vuelta de coordenadas, persistencia y cambios de disposición con relaciones de aspecto diferentes.

Persistencia de referencia: SQLite para metadatos y archivos locales para medios. No existe aún esquema ni motor SQLite. Proponer guardado coherente de conjunto de archivos y metadatos, detección de huérfanos y recuperación tras interrupción. Separar datos temporales de biblioteca persistente.

Si PencilKit se incorpora, no aceptar un modelo de anotación incompatible como formato único de todo el producto. Comprobar entrada del lápiz genérico antes de asumir ventajas.

## 8. Red local y seguridad

No existe señalización ni servidor de emparejamiento implementado. La propuesta debe funcionar sin Internet y sin servicio externo obligatorio. Planificar código/QR, identidad persistente, autorización y reconexión de fuentes conocidas. Una dirección IP no es identidad suficiente.

El hotspot del S24 debe probarse como anfitrión de red y cámara al mismo tiempo. Discovery puede fallar por permisos o aislamiento; ofrecer dirección local/QR. No diagnosticar aislamiento con certeza solo por timeout.

WebRTC aporta mecanismos de transporte seguro, pero no resuelve automáticamente el consentimiento de emparejamiento ni quién controla qué cámara. Definir el protocolo de control antes de permitir comandos remotos.

## 9. Límites conocidos del incremento

- No hay grabación, replay, stepping ni anotación real.
- No hay medición continua de FPS, memoria, temperatura o red.
- No hay tratamiento exhaustivo de todos los errores asíncronos del controlador después de abrir; revisar esa ruta al robustecer el adaptador.
- No hay grabación en segundo plano ni servicio foreground Android configurado.
- No se ha probado el efecto de interrupciones, bloqueo de pantalla, consumo térmico ni periféricos de entrada reales.
- Los tests del propietario no validan que una cámara física mantenga su sesión al recrear un preview.
- No se ha validado compatibilidad del certificado o del perfil con el identificador generado.

Estos puntos son trabajo pendiente, no imposibilidades técnicas demostradas.

## 10. Orden práctico de continuidad

Resolver fallos reales de la CI existente, preparar la instalación y comprobar la cámara local en dispositivos. Después, una prueba técnica acotada del propietario nativo y fan-out comprimido, seguida de conexión con un Android y reproducción independiente. La entrevista y matriz deben guiar las entregas; evitar una reescritura o un sistema de paquetes excesivo antes de necesitarlo.
