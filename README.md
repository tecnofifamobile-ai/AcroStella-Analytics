# AcroStella Analytics

Estudio de grabación y análisis deportivo local para iPad y Android. Versión **0.6.0+8**: dos cámaras en directo en el iPad, emparejamiento recordado, recuperación de ángulos, controles más limpios y material Liquid Glass.

[APK Android 0.6.0](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/v0.6.0%2B8/acrostella-analytics-0.6.0%2B8.apk) · [Fuente Flarestore](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/main/flarestore.json) · [IPA 0.6.0 sin firma](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/ios-v0.6.0%2B8/acrostella-analytics-0.6.0%2B8-unsigned.ipa).

El código sigue privado. El [repositorio público](https://github.com/tecnofifamobile-ai/AcroStella-Updates) contiene solo instaladores y metadatos. No se publican grabaciones, claves ni certificados.

## Grabar y revisar

**Iniciar ejercicio → Revisar → vídeo automático.** La cámara local se activa al iniciar si hace falta. Al terminar se abre el vídeo con Guardar, Eliminar y Otro ejercicio. Se conserva un único propietario de cámara; los reproductores solo decodifican archivos.

Revisión con zoom/desplazamiento hasta 6×, controles ocultables, velocidades 0,25×/0,5×/1×, saltos aproximados de 0,03 s y contador en milisegundos. Dibujo libre, líneas, ángulos, flechas, rectángulos y elipses; color, grosor, duración, deshacer/rehacer y visibilidad. El modo Mover y ampliar evita confundir gestos con trazos. Los originales no se modifican. Repetición A–B y momentos marcados con salto directo.

## Dos ángulos

Actualizar **ambos dispositivos a 0.6.0** y conectarlos a la misma Wi-Fi o al hotspot del Android. En Android: **Dispositivos → Usar como segunda cámara**. En el iPad: buscar la cámara e introducir sus seis cifras de emparejamiento y conectar; autorizar red local y cámara. Iniciar y terminar desde el iPad, esperar la transferencia y revisar ambos ángulos con controles comunes. Guardar y eliminar gestionan los dos archivos del ejercicio en el iPad. La copia del Android se conserva.

La primera conexión usa seis cifras y abre el panel al tocar la cámara descubierta. Las siguientes usan confianza guardada en Keychain/almacenamiento seguro Android; se recupera la conexión al volver. La cámara no se mantiene grabando en segundo plano. Se conservan los clips terminados, su correlación temporal y los acuses pendientes para reunir los ángulos y liberar el siguiente ejercicio tras cortes.

El centro muestra ambas cámaras por defecto, con vista LAN WebRTC y captura nativa compartida. La revisión utiliza los archivos originales, con inicio estimado desde el primer frame aceptado por el writer y ajuste visual manual. **No se garantiza cero desfase**, exposición sincronizada ni presentación atómica. Sigue pendiente un búfer comprimido circular/replay continuo. [Uso y recuperación](docs/conexion-local.md).

El estudio utiliza el API de Liquid Glass de Apple en iOS 26+, material de sistema anterior y un renderizador Flutter para Android compatible. La alternativa opaca respeta accesibilidad/renderizado sin shaders. [Fuentes oficiales y elección del renderer](docs/diseno-liquid-glass.md).

## Biblioteca y copias

Nombre, notas, favoritos, sesión, hasta ocho etiquetas, búsqueda y ordenación. Comparar dos intentos abre dos lectores con controles comunes, sin unir ni recortar los archivos originales. Los dibujos identifican su ángulo y el tiempo de su propio medio.

Hasta tres ejercicios pendientes/512 MiB; los guardados se conservan hasta eliminarlos, con límite de 200 ejercicios/2 GiB. Máximo 256 MiB por ángulo y finalización solicitada tras tres minutos. Son límites de medios conservados: el archivo activo y las operaciones de copia necesitan espacio adicional. Desinstalar o borrar datos elimina la biblioteca.

**Exportar biblioteca** permite guardar una copia `.acrostella` de medios, dibujos y metadatos mediante la hoja de compartir. Importar valida la copia y añade registros con IDs nuevos sin sustituir los existentes. Importar dos veces puede crear duplicados; una interrupción de escritura puede dejar una importación parcial, que se comunica. La copia no está cifrada y debe tratarse como los vídeos originales. Esto no incorpora nube ni sincronización.

## Instalar y actualizar

Android 7+ (minSdk 24), mismo package y firmante persistente de pruebas de 0.4.0. Desde 0.3.0, **Actualizaciones** permite buscar y descargar dentro de la app; Android confirma la instalación. Los APK debug de CI pueden tener otra clave y no se publican como actualizaciones compatibles. [Publicación Android](docs/actualizaciones.md).

iOS/iPadOS 15+ según el paquete: añadir o refrescar la fuente de Flarestore, descargar y firmar con el certificado/perfil del usuario conservando el identificador anterior. Las IPA publicadas **no tienen firma**; no se instalan directamente desde Safari. No se han usado certificados Apple en Cloud. El usuario confirma la instalación de 0.4.0; 0.6.0 y el flujo de dos cámaras necesitan su propia prueba física. [Procedimiento Apple](docs/ios-flarestore.md).

En iPad, **Actualizaciones → Buscar actualizaciones** consulta GitHub directamente y descarga la IPA con verificación; **Enviar IPA al firmador** abre la hoja de compartir. Se puede guardar en Archivos e importar en Flarestore. Firmar/instalar se completa allí, manteniendo el identificador anterior. El catálogo del firmador puede seguir requiriendo refresco; no se da por controlada la caché de una app ajena.

## Verificación y continuidad

138 pruebas Flutter, ocho pruebas nativas propias (instalador y puerta de frames) y ocho pruebas del empaquetador/publicador IPA; análisis/formato/lock correctos. APK release construido y descarga comprobada con el cliente de la app. IPA generada por CI macOS, descargada y verificada por hash/CRC/identidad. [Evidencia vigente de compilación y CI](docs/evidencias/2026-10-23-directo-y-reconexion.md).

Las pruebas de conexión usan sockets TCP reales en loopback y cámaras sintéticas; las de reproducción usan decodificadores simulados. No sustituyen comprobar cámara, hotspot, lápiz, consumo y alineación en S24/iPad. Nube, body tracking, timestamps de exposición del sensor, stepping exacto y búfer/replay continuo siguen pendientes. El directo y la orientación del nuevo MP4 requieren prueba física en iPad/S24.

Flutter 3.47.3 y dependencias fijadas en `pubspec.yaml`/`pubspec.lock`. En este entorno Cloud:

```sh
source /workspace/.acrostella-setup/activate.sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
```

La CI construye iOS exclusivamente en macOS con Xcode 26.3 y empaqueta la IPA sin firma. Para continuar: [AGENTS.md](AGENTS.md), [estado](docs/contexto/05-estado-y-evidencias.md), [entrada Cloud](docs/contexto/06-continuar-en-cloud.md), [matriz](docs/contexto/07-matriz-de-requisitos.md) y [arquitectura](docs/arquitectura.md). El historial de entregas se conserva en contexto/evidencias y Git.
