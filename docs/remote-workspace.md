# AcroStella Hub / Remote Workspace 0.7

La interfaz Flutter y el módulo deportivo existentes se conservan. `lib/src/hub` organiza cinco áreas con navegadores residentes: los análisis mantienen su ruta, cursor y anotaciones. Los reproductores ocultos se pausan. La cámara sigue perteneciendo a `CaptureSession`, nunca al dashboard.

## Integración efectiva

`lib/src/remote/workspace_engine.dart` separa el contrato compartido de su adaptador nativo. `packages/acro_workspace` integra GameStream en iOS: emparejamiento, consulta autenticada de aplicaciones, launch/resume, vídeo y audio, superficie nativa y entrada. Android comparte dashboard, perfiles, consulta y gestión, pero todavía no contiene este motor de escritorio. No se abre Moonlight externo ni una ventana web.

Canales Flutter transportan comandos y estadísticas, no frames sin comprimir. `AVSampleBufferDisplayLayer` recibe vídeo comprimido mediante el renderer de Moonlight; VideoToolbox anuncia disponibilidad de hardware. La disponibilidad no prueba por sí sola el rendimiento de una sesión. Audio SDL2/Opus. C core utiliza enet/nanors y OpenSSL. Las identidades de cliente y certificados del servidor se guardan en Keychain device-only; no son los certificados de firma Apple del usuario.

La primera visita requiere añadir la IP LAN, IP Tailscale o nombre `.ts.net`, emparejar usando el PIN mostrado y aceptarlo en Apollo, consultar aplicaciones y seleccionar Escritorio. Bonjour `_nvstream._tcp` aporta descubrimiento local; no autentica equipos. La búsqueda se detiene al salir del módulo o de la app. Las observaciones HTTP se marcan como no autenticadas; `Permission=0` de esa respuesta no diagnostica permisos del cliente. La consulta HTTPS autenticada sí informa permisos de ratón/teclado y capacidad/disponibilidad de pantalla virtual.

## Referencias y licencias verificadas

| Fuente | Revisión investigada | Aplicación |
| --- | --- | --- |
| [Moonlight iOS](https://github.com/moonlight-stream/moonlight-ios) | `02dc9780496eeeac6d01c8bbdccb8b6fe71ef28a` | StreamManager, transporte, render y soporte de teclado adaptados, GPLv3 |
| [Moonlight common-c](https://github.com/moonlight-stream/moonlight-common-c) | `41cedb89d6b8592f99c09975c764ca3875034726` | Protocolo GameStream, GPLv3 |
| [Apollo](https://github.com/ClassicOldSong/Apollo) | `adc5c5a0bd80831ce495434bb16aee2cd4175fb8` | Servidor externo; permisos, pantalla virtual y extensión de portapapeles investigados, GPLv3 |
| [Moonlight iOS MFX](https://github.com/linckosz/moonlight-ios-MFX) | `c99e11a3244761bf6c73ff72bdb52c28a2a0a1cc` | Referencia; no se incorporan sus prototipos de MetalFX/PiP |

Originales y avisos de autor se conservan en el plugin. El código nuevo se distingue por los archivos Acro y las adaptaciones documentadas en `upstream.json`. GPL no se evita mediante Platform Channels o FFI: el módulo forma parte de la misma aplicación. No había licencia raíz del proyecto al comenzar esta ampliación. Uso privado no exige hacer público el repositorio; distribuir una aplicación combinada exige condiciones compatibles y código fuente correspondiente para sus destinatarios. Dar créditos por sí solo no lo sustituye. El repositorio de desarrollo no se hará público automáticamente.

Las dependencias nativas se compilan desde fuentes fijadas: OpenSSL 3.5.4 (Apache-2.0), FFmpeg 6.1.2 (LGPL2.1+ en esta configuración), SDL2 2.28.5 (zlib) y Opus 1.5.2 (BSD y avisos incluidos). Versiones, URL y SHA-256 están en `packages/acro_workspace/upstream.json`. No se redistribuyen archivos binarios opacos sin correspondencia de fuente. El render AV1 usa headers internos de FFmpeg de la misma fuente compilada. Se conservan licencias MIT/BSD/etc. de las dependencias deportivas existentes.

## Entrada y perfiles

- Modos trackpad relativo y táctil directo, cambio inmediato, clic, doble toque, clic derecho con dos dedos/botón y arrastre. Desplazamiento vertical/horizontal con dos dedos; lápiz como puntero preciso. No se transmiten presión o inclinación de Pencil.
- Botón para teclado de iPadOS, cierre, Ctrl/Alt/Shift/Windows persistentes, Tab y Esc. Atajos básicos alfanuméricos se envían como teclas Windows; texto español mediante UTF-8. Teclado físico usa el mapeo HID de Moonlight. Distribuciones, teclados externos y conflictos con gestos del sistema requieren prueba física.
- Equilibrado 2732×2048/HEVC/60/10 Mbps; calidad 2732×2048/60/12 con frame pacing; respuesta 2048×1536/60/8. Perfiles personalizados persistentes, códec H264/HEVC/AV1 condicionado a disponibilidad de hardware y configuración de Apollo. No se promete que el host acepte todas las resoluciones.
- Superficie nativa ajusta letterboxing y coordenadas al girar. Pantalla virtual solo se solicita si Apollo la declara capaz y preparada. Botones flotantes ocultables; sin copia de vídeo a Dart.

## Protección del deporte y recuperación

Una grabación, transferencia, cámara emparejada o servidor de cámara activo impiden iniciar el escritorio. No se desconecta la pareja silenciosamente. Con una cámara local en reposo, se suspende antes de iniciar el escritorio y se restaura tras confirmar el cierre nativo. Todos los solicitantes de cierre esperan la misma finalización. Un cierre no confirmado bloquea la reapertura de cámara. Al salir del módulo remoto o pasar la app a segundo plano se finaliza el stream, liberando entradas y recursos; la configuración y confianza permanecen. No se promete sesión remota en segundo plano ni captura y escritorio simultáneos.

El cierre de `PairController` espera lectura TCP y respuestas pendientes antes de finalizar el diario de recuperación. Se corrige así una carrera real de persistencia observada en CI, manteniendo el protocolo de cámaras v3 y su confianza segura.

## Diagnóstico y límites honestos

El motor ofrece FPS recibidos, RTT del transporte y su variación, pérdidas de frames en la ventana y procesado del host cuando están disponibles. No se confunden con jitter de paquetes ni latencia completa de entrada a pantalla. FPS presentados, codificación, decodificación, presentación, bitrate real y ruta Tailscale directa/DERP quedan como no disponibles si no se miden. No hay benchmarks físicos de 60 FPS, latencia, memoria, temperatura o duración en este entorno Cloud. No se ha conectado el iPad al Apollo particular del usuario.

No hay aún transferencia PC–tablet, portapapeles, adaptación automática de bitrate, WoL, pantalla externa, reconexión automática de escritorio ni benchmarks A/B. Apollo expone extensión de portapapeles, pero sus bits de transferencia de archivos no demuestran un servicio implementado. GameStream no equivale a un protocolo de gestión de archivos. RDP queda para otro motor; QUIC es un transporte. Windows Home no se presume servidor RDP.

Media & Files sí importa documentos con selector nativo, conserva copias privadas acotadas y permite compartirlas con Archivos/hoja nativa. El original no se borra. La biblioteca deportiva y sus exportaciones permanecen independientes del escritorio. No se envían vídeos a servidores ni se incorpora nube o body tracking.

## Compilación reproducible

Flutter 3.47.3, Dart 3.13.3; lock conservado. Linux compila Android con JDK17/SDK36. iOS requiere macOS/Xcode26.3 (SDK26.2) y `python3 tool/prepare_workspace_native.py` antes de `flutter build ios --release --no-codesign`. El script verifica hashes y compila dependencias arm64 para iPhoneOS15+; no incluye simulador. `tool/package_unsigned_ipa.py` valida y empaqueta una IPA sin firma. La CI existente automatiza ambos sistemas y no recibe certificados Apple. SideStore/ArcticSign/Flarestore firman en el dispositivo; no sustituyen Xcode.

Pruebas de regresión cubren navegación móvil/tablet durante grabación, conservación y pausa de revisión, configuración inválida, consulta de servidor real de loopback, exclusión de captura/escritorio, espera de cierre, cuarentena ante error nativo e importación privada con cuotas/rollback. Los falsos de cámara/reproductor/motor de pruebas no son validación física.
