# Estado verificado y evidencias

Fecha de corte: 21 de octubre de 2026, Europe/Madrid. Revisión inicial de código: `05ad74499c7f39a4c5c9a41cbfe99813bf43b1be`. La documentación de continuidad se añade después de esa revisión sin atribuirle funcionalidades nuevas.

## 1. Resultado de la primera entrega

Existe un proyecto Flutter con plataformas Android e iOS y una primera aplicación de cámara local, versión `0.1.0+1`.

Implementado en código:

- Activación explícita de cámara trasera.
- Previsualización mediante textura nativa del plugin `camera`.
- Propietario de cámara independiente de la distribución visual.
- Serialización de apertura, cierre, cancelación y ciclo de vida.
- Mensajes para cámara ausente, permisos denegados/restringidos y errores de apertura.
- Suspensión al salir de la app y reapertura al volver cuando seguía solicitada.
- Distribución compartida adaptable entre tablet y móvil.
- Cambio entre vista local ampliada y dos áreas de pantalla.
- Tema oscuro inicial y tema claro seleccionable.
- Permiso de cámara; audio desactivado y permisos de micrófono/almacenamiento externo retirados del manifiesto Android final.

No implementado:

- Grabación de vídeo, segmentos, búfer circular, captura continua conservada.
- Conexión Android-iPad, WebRTC, emparejamiento, servidor local ni DataChannels.
- Replay, sincronización entre fuentes, pausa/stepping o retorno al directo desde reproducción.
- Dibujo, medidas, PencilKit, persistencia de anotaciones.
- Guardado/reapertura de ejecuciones, SQLite, importación y exportación.
- Métricas continuas, IA o biomecánica automática.

La segunda área es un estado informativo, no un stream simulado. El botón «Desactivar cámara» de esta prueba detiene la cámara local y **no** representa el futuro botón «Revisar».

## 2. Entorno local observado

| Elemento | Resultado observado |
| --- | --- |
| Equipo de desarrollo | Windows 11 |
| Carpeta inicial | `C:\Users\tecno\Documents\AcroStella Analytics` |
| Flutter | 3.47.3 stable, revisión e8113bf456 |
| Dart | 3.13.3 |
| SDK Flutter | `C:\flutter` |
| Android SDK | Carpeta estándar de Android bajo el perfil local del usuario |
| Android Studio Java | OpenJDK 25.0.2 |
| Android compile SDK | 36 |
| NDK usado por Flutter | 28.2.13676358 |
| Gradle wrapper | 9.3.1 |
| Dispositivos físicos conectados detectados | Ninguno en el diagnóstico inicial |

`flutter doctor -v` advirtió que Flutter/Dart no estaban en PATH y que faltaban `cmdline-tools`; no pudo comprobar licencias por esa vía. Aun así, la compilación Android terminó con el SDK, NDK y licencias presentes. No se modificó el PATH global ni se aceptaron licencias nuevas automáticamente.

No trasladar estas rutas Windows a un entorno Cloud Linux. Localizar allí el SDK real.

## 3. Verificación automática local

Comandos ejecutados:

```text
dart format lib test
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
```

Resultados observados: formato aplicado; análisis sin incidencias (`No issues found!`); **12 pruebas superadas** (`All tests passed!`); compilación Android correcta (`Built build\app\outputs\flutter-apk\app-debug.apk`).

Después se retiraron permisos transitivos innecesarios del manifiesto y se repitieron análisis, las 12 pruebas y compilación. El APK entregado corresponde al manifiesto final. No son mediciones de hardware.

### Cobertura de los 12 casos

1. Construir una sesión no solicita cámara.
2. Varias solicitudes de inicio concurrentes abren una única cámara.
3. Detener durante la inicialización cierra el resultado nativo tardío.
4. Suspender/reanudar preserva la intención de activación.
5. Volver al primer plano no activa una cámara detenida.
6. Una notificación de primer plano no reabre una cámara ya activa.
7. Un error de permisos es visible y un reintento manual puede recuperar.
8. Destruir durante apertura libera el resultado sin notificar después de destruir.
9. Pantalla inicial 1366 × 1024 sin errores de layout.
10. Pantalla inicial 393 × 852 sin errores de layout.
11. Pantalla inicial 852 × 393 sin errores de layout.
12. Cambiar distribución no vuelve a abrir ni cierra el propietario en la prueba con dispositivo falso.

El caso 12 prueba lógica de propietario con `TestCamera`; no demuestra continuidad del sensor, encoder o preview físicos en S24 o iPad. Los cambios de tema también se ejercitan en las pruebas de disposición.

## 4. APK local existente

- Archivo: `artifacts/acrostella-analytics-0.1.0+1-debug.apk`.
- Origen: copia del APK compilado por Flutter.
- SHA-256: `887acf86f00fbc739ee8d9825d666b8d301c5665f76229d346812d564c31ffc6`.
- Tipo: APK de desarrollo con firma de depuración local.
- Package: `com.acrostella.acrostella_analytics`.
- VersionName: `0.1.0`; versionCode: `1`.
- minSdk: `24`; target/compile SDK: `36`.
- ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`.

La inspección final mediante `aapt dump permissions` mostró cámara, Internet/red para la compilación de depuración y permiso interno del receptor. No mostró micrófono ni acceso a almacenamiento externo después de la corrección del manifiesto.

El archivo está excluido de Git mediante `artifacts/`. **No está disponible automáticamente en Cloud por conocer esta ruta.** Los APK de CI pueden diferir en bytes y clave de depuración; no comparar su hash con el APK local como si fueran idénticos.

## 5. GitHub y primera CI real

Repositorio creado manualmente por el usuario: `tecnofifamobile-ai/AcroStella-Analytics`. La conexión confirmó visibilidad privada y permisos de escritura. Se comprobó inicialmente vacío mediante Git y se subió `main` sin sobrescribir otra historia.

Primera ejecución: [Verificar y compilar — run 39681910999](https://github.com/tecnofifamobile-ai/AcroStella-Analytics/actions/runs/39681910999), disparada por push del commit inicial.

### iOS: compilación sin firma confirmada

El job `ios` terminó con éxito, incluida compilación y subida de artefacto. Herramientas registradas en logs:

- Runner solicitado: `macos-15`; Flutter instalado como `stable-3.47.3-arm64`.
- Xcode **16.4**, build **16F6**.
- SDK iPhoneOS **18.5**.
- Comando: `flutter build ios --release --no-codesign`.
- Resultado literal relevante: `Built build/ios/iphoneos/Runner.app (15.2MB)`.

Se confirma compilación Apple para dispositivo, **no** compatibilidad física con el iPadOS 27.0.1 declarado, firma, perfil compatible, instalación ni ejecución. No se utilizó certificado ArcticSign.

Artefacto confirmado: `acrostella-ios-unsigned`, ID `12384337349`, tamaño publicado `6383315` bytes; contiene el ZIP de `Runner.app` sin firma. [Descarga autenticada en GitHub](https://github.com/tecnofifamobile-ai/AcroStella-Analytics/actions/runs/39681910999/artifacts/12384337349). Es una app sin firma empaquetada, **no una IPA instalable**. Su retención configurada es siete días; comprobar caducidad antes de ofrecerlo.

### Android/checks: ejecución completa confirmada

El job `checks` y el workflow completo terminaron con **success**. Finalizaron resolución de dependencias con lock, comprobación de formato, análisis estático, tests, compilación APK y subida de artefacto. Se verificó el resultado final después de observar primero la compilación en curso.

Artefacto confirmado: `acrostella-android-debug`, ID `12384848090`, tamaño publicado `73854221` bytes. [Descarga autenticada en GitHub](https://github.com/tecnofifamobile-ai/AcroStella-Analytics/actions/runs/39681910999/artifacts/12384848090). Es el archivo de artefacto de Actions que contiene el APK, no el tamaño sin comprimir del APK local ni una garantía de firma idéntica.

La respuesta estructurada seleccionada de GitHub, jobs, pasos y artefactos se conserva en [2026-10-21-ci.json](../evidencias/2026-10-21-ci.json). El extracto de herramientas/build Apple está en [2026-10-21-ios-ci-extracto.txt](../evidencias/2026-10-21-ios-ci-extracto.txt). No se presentan estos extractos como logs completos.

Los logs advierten de deprecaciones de acciones Node 20 ejecutadas forzosamente en Node 24. Esto no impidió el job iOS. No se realizaron actualizaciones de acciones solo para eliminar advertencias durante este traspaso.

## 6. Pruebas físicas y métricas

**No hay pruebas físicas confirmadas en ninguno de los dos dispositivos.** No hay informe del usuario de instalación correcta del primer APK. No hay vídeo de prueba, captura de pantalla del iPad ejecutando la app ni registros ADB/Xcode de un dispositivo real.

| Medición | Estado |
| --- | --- |
| FPS reales | Sin medir |
| Latencia de directo | Sin medir |
| Desfase entre cámaras | No hay multicámara implementada; sin medir |
| RAM y almacenamiento temporal | Sin medir; no hay búfer implementado |
| Temperatura y estabilidad prolongada | Sin medir |
| Rechazo de palma y precisión del lápiz | Sin medir |
| Reconexión y aislamiento de hotspot | Sin probar |

Usar `08-pruebas-fisicas.md` para registrar datos reales después de instalar.

## 7. Qué significa estar listo para Cloud

El repositorio contiene fuentes, contexto y workflow. No equivale a crear ya un entorno Cloud con SDKs disponibles, acceso al repo autorizado o conversación migrada con todo el historial. Leer `06-continuar-en-cloud.md`, comprobar acceso real, clonar la rama y localizar herramientas. No trasladar certificados ni grabaciones como parte del contexto.

Los documentos resumen resultados de esta conversación y enlazan evidencia remota. Los logs locales completos de los comandos anteriores no se guardaron originalmente como archivos; no presentar un resumen reconstruido como si fuera un log bruto.
