# Evidencias de AcroStella 0.5.0+5

Código de aplicación: `8437d685b8f522a300fa3fb084edd44da5332635`. Rama `codex/android-updates-annotations`, PR #1. No se han usado certificados Apple, secretos nuevos ni vídeos de personas. La evidencia anterior 0.4.0 conserva su alcance; el usuario comunica que ya instaló aquella versión en iOS, sin aportar todavía mediciones de cámara o sincronización.

## Implementación y pruebas

- Formato y `flutter analyze --fatal-infos` correctos; `flutter pub get --enforce-lockfile` correcto.
- 116 pruebas Flutter superadas en el conjunto; el último ajuste de readiness vuelve a superar las cinco pruebas de revisión dual. CI del mismo commit supera el paso de tests completo.
- Siete pruebas Android propias del instalador correctas, XML sin fallos ni errores. Cuatro pruebas del empaquetador IPA correctas.
- Dos cámaras simuladas con salida de archivos sintéticos y sockets TCP reales completan dos ejercicios consecutivos. La autenticación con secreto erróneo, límites de trama, desconexión durante grabación, conservación y vuelta a modo local se prueban automáticamente. No representan red física Android–iPad.
- Persistencia agrupada, leases de ambos archivos, borrar juntos, metadata compatible, dibujos por ángulo, backup/restauración y rechazo de corrupción/truncado comprobados con disco real y datos sintéticos.
- Reproducción dual con decodificadores simulados: intervalo común, búsquedas serializadas, velocidad, corrección de desfase, buffering/readiness, zoom/dibujo, disposiciones y comparación sin modificar archivos. Disposiciones 393×852, 852×393 y 1366×1024 sin overflow. Inspección visual adicional con fuentes reales y medios sintéticos en `artifacts/`, excluidos de Git.

## Android

`flutter build apk --release` correcto para el código final. `apksigner` verifica firma v2 y el mismo certificado SHA-256 público de 0.4.0: `dfbc2a66221d8b63f7d473fac2e1b80ae7b6a968c2f16f757994f97b16936d3f`. Es la clave persistente de pruebas, no una firma comercial. Package `com.acrostella.acrostella_analytics`, versionName 0.5.0, versionCode 5, minSdk 24, targetSdk 36.

Publicado con `tool/publish_android_update.py --git-assets`: etiqueta `v0.5.0+5`, commit público `ae4ddbc88705ba38fcd2473febc439e83ae6a6f5`. Tamaño **57 006 589 bytes**, SHA-256 `19cc079dd28d14761048d8e1777daa863244169f1488dc25f3739b973af61d57`. La herramienta y el cliente real `tool/check_update_feed.dart` descargaron y verificaron la actualización pública sin autenticación. El canal estable sigue apuntando a Android, incluso después de publicar iOS.

[APK público](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/v0.5.0%2B5/acrostella-analytics-0.5.0%2B5.apk). Instalación física de 0.5.0 pendiente. El aviso de KGP de `share_plus` advierte de futuras versiones de Flutter; no ha impedido este build y no se ha actualizado el SDK para ocultarlo.

## iOS

[CI 40016472936](https://github.com/tecnofifamobile-ai/AcroStella-Analytics/actions/runs/40016472936), job iOS **120629876022** correcto. Xcode **26.3 (17C529)** y SDK iPhoneOS **26.2** observados; [extracto del log](2026-10-23-estudio-ios-ci.txt). `flutter build ios --release --no-codesign` produjo Runner.app de 18,9 MB, empaquetada automáticamente como IPA; artefacto **12528088657**.

IPA `acrostella-analytics-0.5.0+5-unsigned.ipa`, **7 756 088 bytes**, SHA-256 `f6c8ac8b2a28b0ac40cfd1b7d4dba0e16528821b9d13e242e63a9b80c105560b`. Se verificaron hash, CRC, identidad/versión/build, mínimo 15.0, familias iPad/iPhone, permiso de red local y ejecutables Mach-O arm64. No contiene certificados/perfiles. Tag público `ios-v0.5.0+5`, commit **823c30ddb92091c2e25609b3f8aee032d7ecff17**, release separada como prerelease para no reemplazar el canal Android.

[IPA pública](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/ios-v0.5.0%2B5/acrostella-analytics-0.5.0%2B5-unsigned.ipa) · [Fuente Flarestore](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/main/flarestore.json). Descargadas sin autenticación; tamaño/hash/CRC/Info.plist correctos y coincidencia de campos heredados/versiones. Se conserva 0.4.0 en el historial de la fuente. Firma e instalación de la nueva IPA se realizan en el dispositivo del usuario, sin autorización ni uso implícito de certificados en Cloud.

## CI Android y aceptación física

CI completa **superada**: job Android `120629875893` e iOS `120629876022`, run `40016472936`, ambos correctos para el commit `8437d685b8f522a300fa3fb084edd44da5332635`. Resolución/formato/análisis, 116 tests, empaquetador, APK debug y pruebas nativas correctos. Artefacto Android debug `12529745243` (83 523 438 bytes comprimidos). También se construyó el APK debug local del código final. El APK publicado procede del build release local y mantiene el firmante anterior; no se distribuye el APK debug de CI con su clave efímera.

Pendiente: actualizar ambos dispositivos, validar permisos y hotspot, grabar una señal común, transferir y comprobar alineación, zoom, lápiz, velocidad y reproducción prolongada; medir error real y estabilidad. No hay vídeo remoto en directo, WebRTC, captura comprimida continua, emparejamiento persistente ni reanudación tras reiniciar. Un cursor común y los timestamps de comandos no demuestran exposición o presentación simultánea. Ver [procedimiento y recuperación](../conexion-local.md).
