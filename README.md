# AcroStella Analytics

Aplicación Flutter para análisis deportivo local en iPad y Android. Primer incremento: **0.1.0+1, prueba de cámara local**.

## Estado comprobado

- Implementado: cámara trasera, previsualización nativa, apertura explícita, mensajes de permisos, suspensión y recuperación al volver a la app, disposición adaptable, ampliación de la vista y temas claro/oscuro.
- Android: APK de depuración compilado en Windows con Flutter 3.47.3 y Dart 3.13.3.
- Análisis estático sin incidencias y 12 pruebas automatizadas superadas: concurrencia de apertura, cancelación, suspensión, permisos y cambios de distribución.
- iPadOS: fuentes generadas y flujo macOS CI preparado; **compilación, firma e instalación pendientes**.
- Hardware: **sin pruebas físicas**. Ninguna cifra de FPS, latencia, memoria o precisión temporal medida.

La segunda vista identifica expresamente que la conexión remota todavía no está disponible. Esta versión no graba ni guarda vídeos. WebRTC, búfer circular, revisión, sincronización, anotaciones y biblioteca están pendientes.

## Ejecutar y verificar

Flutter está fijado en `pubspec.yaml`. En este PC se encuentra en `C:\flutter\bin`; puede invocarse con su ruta completa si no está en PATH.

```powershell
& C:\flutter\bin\flutter.bat pub get --enforce-lockfile
& C:\flutter\bin\flutter.bat analyze --fatal-infos
& C:\flutter\bin\flutter.bat test
& C:\flutter\bin\flutter.bat build apk --debug
```

El SDK Android y Android Studio están instalados. `flutter doctor -v` detecta que faltan `cmdline-tools` y no puede comprobar las licencias por esa vía; la compilación local sí terminó con las plataformas y licencias ya presentes. No se han aceptado licencias nuevas automáticamente ni se ha modificado el PATH global.

## Primera prueba en Android

APK local: `artifacts/acrostella-analytics-0.1.0+1-debug.apk`, copia de `build/app/outputs/flutter-apk/app-debug.apk`. Huella SHA-256 junto al archivo. Es una compilación de desarrollo firmada con la clave de depuración local.

1. Instalar el APK en el S24 Ultra. Si Android solicita permiso para instalarlo desde la aplicación utilizada, gestionarlo directamente en el móvil.
2. Abrir AcroStella Analytics y pulsar «Activar cámara». Autorizar la cámara cuando se solicite. Esta entrega no solicita grabación de audio.
3. Comprobar imagen trasera, giro vertical/horizontal, ampliación de la vista y cambio de tema. Confirmar que la imagen mantiene su proporción y sigue actualizándose.
4. Desactivar y reactivar la cámara. Salir de la app y volver. Probar permiso denegado y recuperación desde los ajustes del dispositivo.
5. Comunicar versión exacta de Android/One UI y cualquier error visible. No enviar grabaciones de personas para diagnosticar esta primera prueba.

No registrar «captura continua durante replay» como superada: todavía no existe replay. Tampoco tomar las dimensiones mostradas como medición de FPS. Los APK generados en CI pueden tener una clave de depuración distinta; para actualizaciones continuas habrá que establecer una clave de pruebas estable.

## iPadOS y CI

`.github/workflows/ci.yml` prepara análisis, pruebas, APK Android y compilación iOS sin firma sobre `macos-15`, registrando Xcode y SDK usados. Debe ejecutarse y corregirse con sus resultados reales cuando el repositorio privado esté disponible. El ZIP de una aplicación sin firma no es una IPA instalable.

No se han leído ni utilizado certificados. Antes de firmar hay que revisar con autorización el identificador de aplicación, dispositivos y capacidades permitidos por el perfil ArcticSign, y acordar dónde se realiza la firma. No añadir `.p12`, `.mobileprovision` ni contraseñas al repositorio.

## Estructura

- `lib/src/capture`: contrato de dispositivo, propietario de sesión y adaptador de cámara.
- `lib/src/training`: pantalla compartida de entrenamiento.
- `test`: pruebas de lógica y componentes; utilizan cámaras falsas solo dentro de los tests.
- `docs/requisitos.md`: respuestas confirmadas y decisiones pendientes.
- `docs/arquitectura.md`: decisiones breves y condiciones para añadir WebRTC y replay.

Siguiente paso: verificar físicamente la cámara local y resolver la derivación nativa de captura y el almacenamiento comprimido antes de integrar la segunda cámara. No abrir simultáneamente la misma cámara desde el plugin y WebRTC.
