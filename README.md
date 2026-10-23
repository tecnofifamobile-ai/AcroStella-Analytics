# AcroStella Analytics

Estudio de grabación y análisis deportivo local para iPad y Android. Versión **0.5.2+7**: ejercicios con revisión inmediata, biblioteca, seis herramientas de dibujo y conexión de dos cámaras por red local.

[APK Android 0.5.2](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/v0.5.2%2B7/acrostella-analytics-0.5.2%2B7.apk) · [Fuente Flarestore](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/main/flarestore.json) · [IPA 0.5.2 sin firma](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/ios-v0.5.2%2B7/acrostella-analytics-0.5.2%2B7-unsigned.ipa).

El código sigue privado. El [repositorio público](https://github.com/tecnofifamobile-ai/AcroStella-Updates) contiene solo instaladores y metadatos. No se publican grabaciones, claves ni certificados.

## Grabar y revisar

**Iniciar ejercicio → Terminar ejercicio → revisión automática.** La cámara local se activa al iniciar si hace falta. Al terminar se abre el vídeo con Guardar, Eliminar y Otro ejercicio. Se conserva un único propietario de cámara; los reproductores solo decodifican archivos.

Revisión con zoom/desplazamiento hasta 6×, controles ocultables, velocidades 0,25×/0,5×/1×, saltos aproximados de 0,03 s y contador en milisegundos. Dibujo libre, líneas, ángulos, flechas, rectángulos y elipses; color, grosor, duración, deshacer/rehacer y visibilidad. El modo Mover y ampliar evita confundir gestos con trazos. Los originales no se modifican. Repetición A–B y momentos marcados con salto directo.

## Dos ángulos

Actualizar **ambos dispositivos a 0.5.2** y conectarlos a la misma Wi-Fi o al hotspot del Android. En Android: **Dispositivos → Usar como segunda cámara**. En el iPad: buscar la cámara e introducir sus seis cifras de emparejamiento y conectar; autorizar red local y cámara. Iniciar y terminar desde el iPad, esperar la transferencia y revisar ambos ángulos con controles comunes. Guardar y eliminar gestionan los dos archivos del ejercicio en el iPad. La copia del Android se conserva.

El emparejamiento es efímero y la transferencia está cifrada/autenticada; tamaño y SHA-256 se comprueban antes de adjuntar el segundo archivo. No hay cuentas ni nube obligatoria. Mantener ambas apps abiertas y las pantallas desbloqueadas.

Los relojes de comandos permiten una alineación inicial estimada, con ajuste manual durante la revisión. Comprobar una palmada o movimiento común. **No se garantiza cero desfase**, sincronización del sensor ni presentación física simultánea. Esta entrega transfiere archivos al terminar: **no ofrece vista remota en directo ni captura comprimida continua durante la revisión**. [Procedimiento, sincronización y recuperación](docs/conexion-local.md).

## Biblioteca y copias

Nombre, notas, favoritos, sesión, hasta ocho etiquetas, búsqueda y ordenación. Comparar dos intentos abre dos lectores con controles comunes, sin unir ni recortar los archivos originales. Los dibujos identifican su ángulo y el tiempo de su propio medio.

Hasta tres ejercicios pendientes/512 MiB; los guardados se conservan hasta eliminarlos, con límite de 200 ejercicios/2 GiB. Máximo 256 MiB por ángulo y finalización solicitada tras tres minutos. Son límites de medios conservados: el archivo activo y las operaciones de copia necesitan espacio adicional. Desinstalar o borrar datos elimina la biblioteca.

**Exportar biblioteca** permite guardar una copia `.acrostella` de medios, dibujos y metadatos mediante la hoja de compartir. Importar valida la copia y añade registros con IDs nuevos sin sustituir los existentes. Importar dos veces puede crear duplicados; una interrupción de escritura puede dejar una importación parcial, que se comunica. La copia no está cifrada y debe tratarse como los vídeos originales. Esto no incorpora nube ni sincronización.

## Instalar y actualizar

Android 7+ (minSdk 24), mismo package y firmante persistente de pruebas de 0.4.0. Desde 0.3.0, **Actualizaciones** permite buscar y descargar dentro de la app; Android confirma la instalación. Los APK debug de CI pueden tener otra clave y no se publican como actualizaciones compatibles. [Publicación Android](docs/actualizaciones.md).

iOS/iPadOS 15+ según el paquete: añadir o refrescar la fuente de Flarestore, descargar y firmar con el certificado/perfil del usuario conservando el identificador anterior. Las IPA publicadas **no tienen firma**; no se instalan directamente desde Safari. No se han usado certificados Apple en Cloud. El usuario confirma la instalación de 0.4.0; 0.5.2 y el flujo de dos cámaras necesitan su propia prueba física. [Procedimiento Apple](docs/ios-flarestore.md).

En iPad, **Actualizaciones → Buscar actualizaciones** consulta GitHub directamente y descarga la IPA con verificación; **Enviar IPA al firmador** abre la hoja de compartir. Se puede guardar en Archivos e importar en Flarestore. Firmar/instalar se completa allí, manteniendo el identificador anterior. El catálogo del firmador puede seguir requiriendo refresco; no se da por controlada la caché de una app ajena.

## Verificación y continuidad

132 pruebas Flutter, siete pruebas nativas propias del instalador y ocho pruebas del empaquetador/publicador IPA; análisis/formato/lock correctos. APK release construido y descarga comprobada con el cliente de la app. IPA generada por CI macOS, descargada y verificada por hash/CRC/identidad. [Evidencia vigente de compilación y CI](docs/evidencias/2026-10-23-actualizaciones-ios.md).

Las pruebas de conexión usan sockets TCP reales en loopback y cámaras sintéticas; las de reproducción usan decodificadores simulados. No sustituyen comprobar cámara, hotspot, lápiz, consumo y alineación en S24/iPad. Nube, body tracking, vídeo remoto en directo, timestamps del sensor y captura continua siguen pendientes.

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
