# Decisiones que condicionan la implementación

## Incremento 0.6.0: un track, directo LAN y confianza persistente

Se sustituye el adaptador `camera` por un único `getUserMedia(audio:false)` de `flutter_webrtc` 1.6.2+hotfix.4. `CaptureSession` conserva la propiedad y serialización; `RTCVideoRenderer`, `RTCRtpSender` y el MP4 nativo comparten ese mismo track. Se solicita 1080p30; para el directo se pide escala 1,5 y máximo 2 Mbit/s/30 fps. Son parámetros solicitados, no mediciones. [Parches del proveedor](../third_party/flutter_webrtc/ACROSTELLA_PATCHES.md), con MIT/NOTICE conservados. No se transfieren imágenes crudas a Dart ni se instala otro propietario.

El writer Android conserva como máximo un frame retenido, entrega el timestamp fuente a EGL, normaliza el primer PTS escrito y drena EOS con plazo antes de cerrar. iOS conserva un frame en cola serial, guarda orientación inicial en la matriz del archivo y espera la finalización de AVAssetWriter. La consulta `recordingInfo` devuelve la edad del primer frame aceptado sobre el reloj monotónico nativo; la aplicación acota su correspondencia con el reloj de control mediante las dos marcas de la consulta. No es exposición del sensor y no garantiza cero error. Se mantiene la alineación visual manual y el intervalo común de revisión.

`LivePreview` intercambia SDP e ICE por el canal autenticado; RTP usa el cifrado de WebRTC. Solo candidatos host, sin STUN/TURN, señalización pública, cuentas ni servidores. El centro prepara su cámara local y un renderer remoto; la cámara agrega su track ya abierto al sender. Un fallo de vídeo no elimina la conexión de comandos ni un archivo grabado. La revisión decodifica los originales transferidos, no el directo con su latencia de red.

El protocolo LAN v3 conserva SRP para las seis cifras iniciales. Dentro del canal cifrado intercambia una clave de confianza aleatoria de 256 bits. Keychain/almacenamiento seguro Android conservan identidad pública aleatoria, rol, endpoint y hasta ocho pares. La reconexión usa retos frescos, pruebas HMAC-SHA256 vinculadas a ambos IDs y HKDF/AES-GCM direccionales; no reutiliza la clave AES de una sesión anterior ni degrada automáticamente al código. Bonjour publica protocolo e ID público, nunca claves. Puede buscar de nuevo el mismo ID si cambia la IP, pero solo su prueba criptográfica autoriza la conexión.

Segundo plano suspende cámara/transporte y finaliza el archivo; conserva confianza y ejecución pendiente. Al volver se restaura el último rol y se reintenta con contrapresión temporal. `pending-pair.json` guarda IDs de clips finalizados y correlación original de tiempos mediante rename serializado, sin claves. Permite recuperar ambos ángulos tras reconstruir el controlador; no recupera un MP4 que el sistema mató antes de finalizar. Los acuses pendientes también se conservan para liberar el siguiente ejercicio cuando se perdió la respuesta final. No se reanudan bytes de una transferencia parcial: se recibe otra vez el archivo completo y se valida hash/tamaño.

El acabado usa el API público `UIGlassEffect(.regular)` de iOS 26+, `UIBlurEffect` anterior y `liquid_glass_renderer` 0.2.0-dev.4 en Impeller Android. Los renderizadores sin filtros shader y opciones de accesibilidad usan superficie opaca; UIKit atiende Reducir transparencia. Solo controles, no el contenido del vídeo. Véase [investigación y límites](diseno-liquid-glass.md). La ventana evita el apagado automático solo mientras la cámara está activa en primer plano; no hay wake lock ni captura en segundo plano. Se desactiva backup automático Android para no restaurar secretos cifrados sin su clave de Keystore.

Los incrementos siguientes son históricos: las menciones de ausencia de WebRTC o de `camera` describen esas entregas, no 0.6.0.

## Incremento 0.5.0: estudio y dos ángulos por LAN

`PairController` coordina dos `CaptureSession` existentes mediante mensajes TCP cifrados y autenticados; no se añade WebRTC ni se abre una cámara desde una segunda API. Se estima el reloj monotónico de control, programa el inicio, finaliza ambos archivos y transfiere el secundario comprimido por bloques. Un solo centro por sesión y secreto efímero; límites de tramas, tiempo, bytes y hash antes de adjuntar medios. La seguridad de la red no sustituye la comprobación física del permiso, la cámara o el hotspot.

`FileClipStore` amplía manifiestos compatibles con organización, segundo archivo e intervalo temporal. El grupo ocupa una entrada y ambos archivos están protegidos por el mismo lease. Adjuntar publica metadata al final; los guardados no son víctimas de expulsión. Los dibujos identifican ángulo y tiempo de su propio medio. Las copias `.acrostella` usan un contenedor de metadatos limitado y blobs con tamaño/hash, sin rutas de extracción; importan registros nuevos sin sustituir existentes.

`LinkedPlayback` serializa operaciones, limita al intervalo común y espera ambos seeks antes de reproducir. Muestrea posiciones nativas conjuntamente y pausa ambos si hay buffering; corrige desfase observado con umbral. No ofrece presentación atómica entre decodificadores. El reloj de comandos tampoco identifica el primer frame, por lo que existe corrección visual manual. La revisión no es captura continua ni stepping garantizado. [Guía detallada](conexion-local.md).

## Incremento 0.4.0: revisión inmediata y ejercicios guardados

El botón Iniciar ejercicio abre la cámara si hace falta y solicita grabación al mismo propietario. Al finalizar manualmente o por límite, `CaptureSession` entrega una finalización consumible una sola vez y `TrainingScreen` abre la revisión con reproducción automática. El encoder del archivo finito se finaliza antes de reproducirlo; la previsualización conserva su propietario. Esto aún no es captura comprimida continua ni revisión de dos ángulos.

`FileClipStore` conserva los nuevos archivos en soporte privado de aplicación, separado de la caché de instaladores. Los manifiestos siguen siendo schema 1 con campos opcionales compatibles: `saved`, `name`, `memo`, `favorite`, `markers`. Guardar publica la metadata por rename; no mueve un archivo que está leyendo el decodificador. La cuota de pendientes (3/512 MiB) nunca elige guardados como víctimas. Guardados: 200/2 GiB; superar el límite rechaza el guardado y deja intacto el pendiente. Un manifiesto dañado en modo durable oculta el registro, pero conserva sus archivos para recuperación. La biblioteca no es respaldo: se pierde al desinstalar/borrar datos.

La migración copia los clips y sidecars 0.3.0 aún existentes desde caché, publica cada manifiesto al final y marca la importación completada. No elimina los originales y no vuelve a importar los pendientes ya gestionados. No recupera una caché previamente purgada por el sistema. Los campos nuevos sobreviven reapertura; no hay servicio de nube ni transferencia remota.

La revisión protege la salida de pendientes con Guardar/Eliminar/Decidir después. La eliminación espera a desmontar los widgets de vídeo, cerrar el decodificador y liberar su lease. Salir durante inicialización nativa conserva el pendiente y difiere la liberación hasta el resultado tardío. Los fallos de escritura no se anuncian como guardados.

Anotaciones: seis herramientas, hasta 512 puntos por trazo, 100 dibujos y 512 KiB por ejercicio. Estilo y tiempo se guardan en el sidecar compatible; 30 operaciones de historial de deshacer por apertura, rehacer, ocultar y borrar visibles. La cancelación de puntero descarta el trazo. La repetición A–B y los saltos usan la posición del medio del reproductor: no prometen stepping exacto ni alteran/exportan el archivo. Hasta 50 momentos marcados se guardan en metadata. Medidas manuales 2D, sin calibración ni tracking.

La CI Apple selecciona Xcode 26.3 del runner macOS 15: el SDK predeterminado 16.4 falló al compilar las APIs de concurrencia de `video_player_avfoundation` 2.12.2. No se cambió la dependencia para ocultar ese error. Solo se compila sin firma; no se utilizan certificados.

## Incremento 0.3.0: actualizador y anotaciones

`GitHubUpdateSource` consulta Releases estables del repositorio público autorizado de instaladores. Admite assets de Releases o archivos fijados a una etiqueta de versión del mismo repositorio. La descarga se escribe por bloques a un archivo parcial, se limita por bytes y se publica tras verificar SHA-256. `UpdateController` coordina consulta, cancelación, permisos e instalador; las preferencias se escriben de forma serializada en soporte privado. No hay tokens ni subidas de vídeo. Véase [el procedimiento](actualizaciones.md).

El canal nativo Android verifica en un worker la ruta privada, hash, paquete, versión creciente, minSdk y certificado real del APK frente a la instalación actual. Solo expone el subdirectorio de instaladores mediante `FileProvider` no exportado, y repite la verificación antes de abrir el instalador del sistema. Abrirlo no equivale a instalar: se vuelve a consultar la versión al regresar. Se bloquea instalar mientras un clip está activo.

`VideoAnnotation` conserva puntos normalizados e intervalo del tiempo de reproducción. El overlay ocupa el rectángulo real del vídeo dentro de `AspectRatio`, sin incluir barras; el cálculo del ángulo usa las dimensiones originales, no un cuadrado normalizado. `FileClipStore` escribe un sidecar atómico de máximo 100 anotaciones/64 KiB por clip y lo retira con el vídeo. Un sidecar inválido no elimina el vídeo ni se sobrescribe automáticamente. Es almacenamiento temporal no destructivo, sin tracking, calibración, zoom/pan ni sincronización multicámara.

## Incremento 0.2.0: clips finitos locales

`CaptureSession` serializa también el inicio y la finalización de grabación del mismo `FlutterCameraDevice`. El contrato opcional `VideoCaptureDevice` permite probar esa ruta sin confundir una cámara falsa con integración física. La salida es un archivo comprimido nativo; no se solicita `startImageStream` ni otra cámara. La petición de bitrate es 8 Mbit/s; no es una medición ni una garantía del dispositivo.

El adaptador CameraX fijado enlaza `videoCapture` al proveedor de cámara existente al grabar y lo desenlaza al finalizar. Esto puede reconfigurar casos de uso y **no demuestra continuidad sin huecos**. La ruta AVFoundation también usa el controlador existente, pero la compilación iOS actual y ambas rutas físicas siguen pendientes de prueba. No se ha resuelto todavía la derivación a WebRTC ni el acceso a paquetes codificados para segmentación.

Los clips se finalizan tras una solicitud automática a los 30 s o una acción explícita. Salir de la app intenta finalizarlos antes de liberar la cámara; volver no inicia una grabación nueva. La reproducción usa un decodificador de archivo separado con posición y velocidad propias, sin poseer la cámara. Cada lector fija el archivo hasta que termina la liberación del reproductor nativo.

`FileClipStore` conserva como máximo tres clips y 128 MiB en una caché privada. Rechaza archivos vacíos o de más de 64 MiB tras su finalización. El archivo activo lo escribe el plugin y **no tiene un límite duro de bytes proporcionado por esta API**; una importación puede ocupar hasta 64 MiB adicionales de preparación. La cuota descrita es de clips conservados, no de toda la caché nativa. Un manifiesto por archivo, publicado mediante rename, permite recuperar clips terminados al reabrir y limpiar escrituras incompletas. El sistema puede purgar la caché. No se declara persistencia definitiva ni atomicidad conjunta de una ejecución multicámara.

La fecha usa el reloj civil; `elapsed` registra tiempo monotónico de control, no timestamps del sensor. La duración y posición de reproducción proceden del archivo. No son una línea temporal común ni sincronización entre cámaras.

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
