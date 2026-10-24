# Emparejamiento sencillo — 0.5.1+6

Fuente privada: `c3f3b8281b0a7d1dbf6c3aa1e6397f81ce457daf`. [PR #1](https://github.com/tecnofifamobile-ai/AcroStella-Analytics/pull/1). El usuario identificó que no había actualizado y pidió seis cifras; no se atribuye el problema anterior a un fallo de hotspot confirmado.

## Cambio entregado

Android muestra un código numérico de seis cifras, incluyendo ceros iniciales; copia/regeneración, caducidad de cinco minutos y cinco intentos. iPad busca cámaras con DNS-SD/Bonjour nativo y muestra su nombre, con alternativa por IPv4 local y puerto 45872. El código no se anuncia ni se envía en claro: SRP-6a con parámetros locales fijos de RFC 5054 (3072 bits, g=5, SHA-256), verificación mutua y canal AES-256-GCM con claves direccionales frescas derivadas mediante HKDF. No hay reducción del antiguo secreto a una clave de seis cifras. Sin degradación al protocolo v1; actualizar ambos dispositivos.

Accesos con texto a Dispositivos, Comparar intentos y Copias de seguridad; versión/build realmente instalados mediante `package_info_plus`; errores diferenciados y liberación/cancelación de descubrimiento/anuncios. Se mantiene la grabación finita, transferencia de ambos medios y revisión/guardado agrupados.

## Verificación local

- `flutter pub get --enforce-lockfile`, formato y `flutter analyze --fatal-infos`: correctos.
- `flutter test`: **124 pruebas superadas**. Sockets TCP reales en loopback con cámaras sintéticas; grabación/transferencia agrupadas; SRP con ceros iniciales, claves frescas, código incorrecto, prueba repetida, límite de claves públicas, bloqueo y caducidad. Descubrimiento encontrado/perdido/cancelado y anuncio tardío mediante mensajes nativos simulados. Layout móvil/tableta y herramientas/reproducción con decodificadores simulados.
- `python3 -m unittest discover -s tool -p test_package_unsigned_ipa.py`: cuatro pruebas correctas.
- `flutter build apk --release`, `flutter build apk --debug`, `./android/gradlew -p android :app:testDebugUnitTest`: correctos; siete pruebas nativas, cero fallos.
- Capturas de interfaz sintética inspeccionadas, fuentes reales, en `artifacts/pairing-android-051.png` y `artifacts/pairing-ipad-051.png` (excluidas de Git). No son fotografías de dispositivos ni se cuentan como pruebas físicas.

## CI e iOS

[Run 40022670860](https://github.com/tecnofifamobile-ai/AcroStella-Analytics/actions/runs/40022670860) completado correctamente para el commit anterior: jobs iOS 120650904055 y checks 120650904421. Xcode **26.3 (17C529)**, SDK iPhoneOS **26.2**. Runner.app 19.2 MB; IPA empaquetada por la herramienta de CI, no reconstruida en Linux. Artefacto iOS **12531331771**, comprimido de Actions **7 854 349 bytes**. IPA **7,877,307 bytes**, SHA-256 `9915383f7edce942dffb638ec94a9eae6509cd37b9180823e86ad8fbbcaf36be`.

Se comprobaron CRC, Info.plist, bundle/versión/build, mínimo 15.0, familia [1,2], permiso de cámara/red local, servicio Bonjour y ausencia de perfil/certificados del usuario/firma de distribución de Runner. Los frameworks conservan las firmas/metadatos de su compilación por la herramienta; no implican firma instalable del usuario. No se han usado secretos Apple. Flarestore debe firmar antes de instalar.

## Publicación y comprobación pública

Solo instaladores y metadatos en el repositorio público autorizado, sin fuentes privadas, vídeos ni claves.

| Plataforma | Etiqueta | Bytes | SHA-256 |
| --- | --- | --- | --- |
| Android | `v0.5.1+6` | 57 615 033 | `ea0cdc729556bd61a602a8bed433ef60c0adeba36315fc0bb687d1df3e21777a` |
| iOS sin firma | `ios-v0.5.1+6` | 7,877,307 | `9915383f7edce942dffb638ec94a9eae6509cd37b9180823e86ad8fbbcaf36be` |

[APK](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/v0.5.1%2B6/acrostella-analytics-0.5.1%2B6.apk) · [IPA](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/ios-v0.5.1%2B6/acrostella-analytics-0.5.1%2B6-unsigned.ipa). Commit público Android `cfea60844510fe335f84e7f53982f642d0c810c8`; iOS/fuentes `fa97f947b1d838e94679a061809ab7c60055e863`. Se descargó el APK con el mismo cliente de actualización de la app, sin autenticación; tamaño/hash y firma coinciden. Firmante SHA-256 `dfbc2a66221d8b63f7d473fac2e1b80ae7b6a968c2f16f757994f97b16936d3f`, igual a las entregas previas; sigue siendo la clave persistente de pruebas. Package `com.acrostella.acrostella_analytics`, código 6, minSdk24/target36. Sin micrófono, almacenamiento compartido ni wake lock; añade permiso multicast para NSD.

La descarga pública de IPA coincide en hash/bytes. Ambas fuentes Flarestore publican exclusivamente 0.5.1/build6, campos actuales y heredados coherentes, mismo bundle y URL inmutable. Cada fuente conserva identifier/sourceURL propios. La Release iOS es prerelease y conserva la última estable Android para el actualizador.

## Límites que siguen pendientes

Prueba física con iPad y S24/hotspot: permiso de red local y cámara, anuncio Bonjour, conexión por IP, grabación, transferencia, alineación, lápiz y consumo. Un hotspot que aísla clientes puede bloquear también el acceso por IP. Sin vista remota en directo, timestamps del sensor ni captura comprimida continua; no se garantiza cero desfase físico. Nube y body tracking siguen aplazados. No se ha operado Flarestore ni firmado/instalado en el dispositivo del usuario.
