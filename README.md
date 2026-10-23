# AcroStella Analytics

Aplicación Flutter para análisis deportivo local en iPad y Android. Versión actual: **0.3.0+3, actualizaciones Android y anotaciones temporales**.

## Nuevo en 0.3.0

- Actualizador Android integrado: aviso dentro de la app, búsqueda automática diaria opcional, notas, descarga con progreso/cancelación y verificación de tamaño, SHA-256, paquete, versión y certificado antes de abrir el instalador del sistema. Android solicita la confirmación final.
- Líneas y ángulos sobre clips pausados: dos o tres toques, duración de 1/3/5 segundos del vídeo y deshacer. Coordenadas normalizadas, cálculo respetando la proporción del vídeo y persistencia junto al clip temporal.
- Código privado y [repositorio público de instaladores](https://github.com/tecnofifamobile-ai/AcroStella-Updates). Primera instalación manual de 0.3.0; las siguientes se descargan dentro de la app. [Procedimiento de publicación](docs/actualizaciones.md).
- 81 pruebas Flutter y 7 pruebas nativas de la app superadas; APK release compilado con la misma firma de pruebas que el APK Cloud 0.2.0. Instalación y cámara físicas pendientes. iOS 0.3.0 aún no se ha compilado ni firmado.

Para dibujar: abre un clip, páusalo, selecciona Línea o Ángulo, elige la duración y toca dos o tres puntos del vídeo. Reproduce para comprobar el intervalo. Los clips y sus dibujos son caché temporal; no se exportan ni constituyen todavía una biblioteca definitiva.

## Nuevo en 0.2.0

- «Grabar clip» y «Finalizar clip» usan el mismo controlador de la cámara local, sin audio ni fotogramas crudos en Dart. Finalización automática solicitada a los 30 segundos.
- «Clips locales» permite reproducir, pausar, desplazarse por el vídeo y elegir 0,25×, 0,5× o 1×. Volver al directo no abre una segunda cámara.
- Caché privada con fecha automática, eliminación manual y un máximo de tres clips y 128 MiB conservados. Los clips abiertos no se eliminan automáticamente; el sistema puede limpiar esta caché. No es aún la biblioteca definitiva de ejecuciones.
- 38 pruebas automatizadas, incluido el ciclo de grabación, recuperación de archivos, cuotas y navegación con cámara/reproductor simulados.

Esta entrega guarda archivos finitos de **un ángulo**. Finalizar un clip cierra su archivo antes de reproducirlo, conservando el propietario de la previsualización. **No implementa todavía «Iniciar ejecución / Revisar» con captura comprimida continua**, búfer segmentado, segundo ángulo ni sincronización. La captura y la reproducción nativas necesitan validación física en S24/iPad; las pruebas simuladas no la sustituyen. La compilación iOS actual aún no está verificada.

Prueba de esta versión: activa la cámara, pulsa «Grabar clip», espera unos segundos, pulsa «Finalizar clip» y abre «Clips locales». Comprueba reproducción, pausa, desplazamiento y cámara lenta; vuelve al directo. Prueba también la finalización automática y salir de la app durante un clip. Usa solo material autorizado y registra lo observado en [la guía física](docs/contexto/08-pruebas-fisicas.md).

**Continuar en Cloud:** leer [el punto de entrada](docs/contexto/06-continuar-en-cloud.md), [el índice del contexto completo](docs/contexto/README.md) y [AGENTS.md](AGENTS.md). Incluyen el encargo, respuestas literales, decisiones, especificación, matriz de requisitos, arquitectura y evidencia de la primera entrega.

Repositorio privado: [tecnofifamobile-ai/AcroStella-Analytics](https://github.com/tecnofifamobile-ai/AcroStella-Analytics).

## Estado comprobado de la primera entrega 0.1.0

- Implementado: cámara trasera, previsualización nativa, apertura explícita, mensajes de permisos, suspensión y recuperación al volver a la app, disposición adaptable, ampliación de la vista y temas claro/oscuro.
- Android: APK de depuración compilado en Windows y en CI, con Flutter 3.47.3 y Dart 3.13.3.
- Análisis estático sin incidencias y 12 pruebas automatizadas superadas: concurrencia de apertura, cancelación, suspensión, permisos y cambios de distribución.
- iPadOS: **compilación para dispositivo sin firma superada en macOS CI**; firma, instalación y funcionamiento físico pendientes.
- Hardware: **sin pruebas físicas**. Ninguna cifra de FPS, latencia, memoria o precisión temporal medida.

La segunda vista identifica expresamente que la conexión remota todavía no está disponible. La entrega 0.1.0 no grababa vídeos; 0.2.0 añadió clips y 0.3.0 incorpora anotaciones temporales. WebRTC, búfer circular, revisión continua, sincronización y biblioteca de ejecuciones siguen pendientes.

## Ejecutar y verificar

Flutter está fijado en `pubspec.yaml`. En este PC se encuentra en `C:\flutter\bin`; puede invocarse con su ruta completa si no está en PATH.

```powershell
& C:\flutter\bin\flutter.bat pub get --enforce-lockfile
& C:\flutter\bin\flutter.bat analyze --fatal-infos
& C:\flutter\bin\flutter.bat test
& C:\flutter\bin\flutter.bat build apk --debug
```

El SDK Android y Android Studio están instalados. `flutter doctor -v` detecta que faltan `cmdline-tools` y no puede comprobar las licencias por esa vía; la compilación local sí terminó con las plataformas y licencias ya presentes. No se han aceptado licencias nuevas automáticamente ni se ha modificado el PATH global.

## Primera prueba en Android (entrega 0.1.0)

APK local: `artifacts/acrostella-analytics-0.1.0+1-debug.apk`, copia de `build/app/outputs/flutter-apk/app-debug.apk`. Huella SHA-256 junto al archivo. Es una compilación de desarrollo firmada con la clave de depuración local.

1. Instalar el APK en el S24 Ultra. Si Android solicita permiso para instalarlo desde la aplicación utilizada, gestionarlo directamente en el móvil.
2. Abrir AcroStella Analytics y pulsar «Activar cámara». Autorizar la cámara cuando se solicite. Esta entrega no solicita grabación de audio.
3. Comprobar imagen trasera, giro vertical/horizontal, ampliación de la vista y cambio de tema. Confirmar que la imagen mantiene su proporción y sigue actualizándose.
4. Desactivar y reactivar la cámara. Salir de la app y volver. Probar permiso denegado y recuperación desde los ajustes del dispositivo.
5. Comunicar versión exacta de Android/One UI y cualquier error visible. No enviar grabaciones de personas para diagnosticar esta primera prueba.

No registrar «captura continua durante replay» como superada: todavía no existe replay. Tampoco tomar las dimensiones mostradas como medición de FPS. Los APK generados en CI pueden tener una clave de depuración distinta; para actualizaciones continuas habrá que establecer una clave de pruebas estable.

## iPadOS y CI

`.github/workflows/ci.yml` ejecuta análisis, pruebas, APK Android y compilación iOS sin firma sobre `macos-15`, registrando Xcode y SDK usados. [Primera ejecución real, superada](https://github.com/tecnofifamobile-ai/AcroStella-Analytics/actions/runs/39681910999): ambos jobs correctos y artefactos `acrostella-android-debug` y `acrostella-ios-unsigned`. Para Apple: Xcode 16.4 (16F6), SDK iPhoneOS 18.5 y `Runner.app` sin firma. El ZIP de una aplicación sin firma no es una IPA instalable. Los resultados se conservan en [las evidencias](docs/contexto/05-estado-y-evidencias.md).

No se han leído ni utilizado certificados. Antes de firmar hay que revisar con autorización el identificador de aplicación, dispositivos y capacidades permitidos por el perfil ArcticSign, y acordar dónde se realiza la firma. No añadir `.p12`, `.mobileprovision` ni contraseñas al repositorio.

## Estructura

- `lib/src/capture`: contrato de dispositivo, propietario de sesión y adaptador de cámara.
- `lib/src/clips`: almacenamiento temporal limitado, lista y reproductor de clips locales.
- `lib/src/updates`: consulta pública, descarga verificada e interfaz del actualizador Android.
- `lib/src/training`: pantalla compartida de entrenamiento.
- `test`: pruebas de lógica y componentes; utilizan cámaras falsas solo dentro de los tests.
- `docs/requisitos.md`: respuestas confirmadas y decisiones pendientes.
- `docs/arquitectura.md`: decisiones breves y condiciones para añadir WebRTC y replay.
- `docs/contexto/`: paquete amplio de continuidad a Cloud con respuestas, trazabilidad y estados verificables.
- `docs/evidencias/`: resultados seleccionados de la primera CI, sin secretos ni grabaciones.

Siguiente paso: verificar físicamente la cámara local y resolver la derivación nativa de captura y el almacenamiento comprimido antes de integrar la segunda cámara. No abrir simultáneamente la misma cámara desde el plugin y WebRTC.
