# Distribución iOS con Flarestore


## Versión actual 0.5.2+7

[Descargar IPA sin firma](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/ios-v0.5.2%2B7/acrostella-analytics-0.5.2%2B7-unsigned.ipa) · 8020526 bytes · SHA-256 `be5fbe0aa80c4cb38a2b60f05665b3f89f1cdf495d9f46a8232423f88103af2a`. Si el catálogo conserva la anterior, descargar este archivo e importarlo en Flarestore; firmar e instalar con el mismo identificador, sin desinstalar AcroStella. La fuente y la IPA deben mostrar 0.5.2/build7. No es necesario añadir otra fuente en cada publicación.

Desde esta versión: AcroStella → Actualizaciones → Buscar actualizaciones → Descargar → Enviar IPA al firmador. El aviso automático consulta GitHub como máximo una vez al día; búsqueda manual disponible. La hoja de compartir permite escoger un firmador compatible o guardar en Archivos para importarla. La app consulta la versión realmente instalada después; enviar el archivo no se anuncia como instalación. La ruta física de compartir/importar sigue pendiente en el iPad del usuario.

La consulta propia usa API pública de GitHub para obtener HEAD y luego un manifiesto en el commit inmutable, más comprobación de la Release iOS. Evita depender de una copia antigua del JSON de Flarestore para anunciar/descargar futuras versiones. No permite forzar el estado de una aplicación ajena; no se ha confirmado la causa del catálogo anterior.

Publicar futuras IPA con:

```sh
python3 tool/publish_ios_update.py RUTA_IPA --notes-file NOTAS
dart run tool/check_update_feed.dart --ios DIRECTORIO_DE_VERIFICACION
```

El comando clona solo el repositorio público autorizado; inspecciona la IPA, rechaza perfiles/certificados y firma de distribución de Runner, comprueba identidad/versiones/binarios/CRC, actualiza atómicamente ambos catálogos y el manifiesto, verifica los archivos públicos y publica una prerelease separada del canal Android. Conserva las firmas de los frameworks del SDK. Nunca sobrescribir etiquetas/instaladores publicados. Una interrupción tras el push exige comprobar esos mismos bytes antes de completar la Release; no sustituir archivos ni avanzar versión sin necesidad.

El usuario aportó archivos de certificado/perfil; no se han leído ni utilizado en Cloud. La publicación sigue sin firma del usuario y se firma en su dispositivo.

## Historial: 0.5.1+6

Refrescar la fuente ya añadida, descargar **0.5.1/build 6** y firmar conservando certificado/perfil e identificador anteriores. No desinstalar la app para actualizar. Ambas fuentes (`flarestore.json` y `flarestore-latest.json`) ofrecen la misma versión actual, con sus identidades y URL propias. Actualizar también Android: el código de seis cifras utiliza un protocolo nuevo.

- [IPA sin firma · 7,877,307 bytes](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/ios-v0.5.1%2B6/acrostella-analytics-0.5.1%2B6-unsigned.ipa).
- SHA-256 antes de firmar: `9915383f7edce942dffb638ec94a9eae6509cd37b9180823e86ad8fbbcaf36be`.
- Fuente privada `c3f3b8281b0a7d1dbf6c3aa1e6397f81ce457daf`; [CI](https://github.com/tecnofifamobile-ai/AcroStella-Analytics/actions/runs/40022670860), job iOS 120650904055, Xcode 26.3 (17C529), SDK iPhoneOS 26.2.
- Bundle `com.acrostella.acrostellaAnalytics`, build 6, mínimo 15.0, iPad/iPhone. `NSBonjourServices` declara `_acrostella._tcp`, además de los motivos de cámara y red local.

CRC, identidad, versión, hash y descarga públicos comprobados. Runner no lleva firma de distribución del usuario ni perfil; los frameworks precompilados conservan los metadatos de firma de la herramienta/SDK. No se han leído ni usado certificados Apple del usuario. Flarestore debe firmar la app y sus componentes antes de instalar. La compilación no verifica la conexión física S24/iPad. [Guía de seis cifras](conexion-local.md).

## Historial: entrega 0.5.0+5

El usuario confirma que instaló 0.4.0 en iOS. La misma fuente ofrece ahora **0.5.0**: refrescarla, descargar y firmar con el mismo certificado/perfil e identificador de aplicación para actualizar la instalación. No se han utilizado certificados Apple en Cloud.

- [Fuente para Flarestore](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/main/flarestore.json).
- [IPA 0.5.0 sin firma · 7 756 088 bytes](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/ios-v0.5.0%2B5/acrostella-analytics-0.5.0%2B5-unsigned.ipa).
- SHA-256 previo a firmar: `f6c8ac8b2a28b0ac40cfd1b7d4dba0e16528821b9d13e242e63a9b80c105560b`.
- Compilación macOS verificada del commit `8437d685b8f522a300fa3fb084edd44da5332635`, CI `40016472936`, job iOS `120629876022`; Xcode 26.3 (17C529), SDK iPhoneOS 26.2. Identidad `com.acrostella.acrostellaAnalytics`, build 5, mínimo iOS 15, iPad/iPhone.

Se comprobó la descarga pública, hash, CRC, Info.plist, permiso de red local, Mach-O arm64 y ausencia de archivos de firma. La instalación de esta nueva versión y la cámara/red con dos dispositivos siguen sin comprobar físicamente. Actualizar también el Android a 0.5.0 y seguir [la guía de conexión](conexion-local.md). Esta entrega transfiere el segundo archivo al terminar, sin vista remota en directo ni captura continua. La alineación física requiere comprobación visual y no garantiza cero desfase.

## Si Flarestore conserva 0.4.0

El usuario comunica que su fuente sigue mostrando 0.4.0 aunque la URL pública y la IPA servían 0.5.0/build 5, con identidad y SHA-256 correctos. No se ha inspeccionado el cliente; caché o selección de una entrada del historial son hipótesis, no una causa confirmada.

Se publicaron en el commit público `66c47fe` una fuente principal con una sola versión actual y una fuente de compatibilidad con URL/identidad nuevas:

```text
https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/main/flarestore-latest.json
```

En Fuentes, retirar únicamente la fuente antigua y añadir la nueva; no desinstalar AcroStella. La fuente alternativa se llama «AcroStella Updates · Actual», ID `com.acrostella.updates.latest`; el bundle de la aplicación permanece `com.acrostella.acrostellaAnalytics`. Se mantiene con una sola versión actual; desde esta entrega, 0.5.1/build 6. Las IPA anteriores permanecen inmutables en sus etiquetas. Firmar conservando el identificador anterior. Verificación HTTP/JSON y descarga/hash realizadas; falta confirmar la presentación en el Flarestore del usuario.

En futuras publicaciones actualizar ambos JSON a la misma versión actual, manteniendo cada `identifier` y `sourceURL` propios. Las versiones antiguas siguen en Releases y Git; no reintroducir varias entradas en estas fuentes de versión actual. GitHub puede conservar el JSON anterior durante cinco minutos: la URL nueva evita reutilizar esa entrada de caché.

## Procedimiento y evidencia histórica de 0.4.0

El usuario confirma que utiliza Flarestore con su certificado ArcticSign. Se entrega una **IPA sin firma** de AcroStella 0.4.0+4 para importarla y firmarla en su dispositivo. No se han leído, recibido, enviado a CI ni publicado certificados Apple, perfiles o contraseñas. La validez del certificado, los dispositivos autorizados y la compatibilidad del perfil siguen sin verificar.

## Procedimiento

1. Añadir como fuente en Flarestore `https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/main/flarestore.json` y descargar AcroStella desde allí. Como alternativa, descargar la IPA sin firma al iPad e importarla como archivo.
2. Seleccionar el certificado y perfil que el usuario ya utiliza allí.
3. Firmar e instalar mediante Flarestore. El identificador propuesto es `com.acrostella.acrostellaAnalytics`; debe estar permitido por el perfil. Mantener un identificador fijo en futuras instalaciones para conservar los datos de la app.
4. Abrir AcroStella y autorizar cámara. Probar iniciar/terminar ejercicio, revisión automática, guardar/reabrir, giro y dibujo con lápiz. Registrar modelo/versión real del sistema y cualquier mensaje de error, sin enviar vídeos de personas ni credenciales.

No se ha operado Flarestore ni verificado esta instalación en hardware. Los nombres exactos de sus menús dependen de su versión. La IPA sin firmar no se instala directamente desde Safari. Estas pruebas no validan sincronización multicámara ni precisión biomecánica.

## Artefacto y empaquetado

Origen: `Runner.app` para dispositivo generado por el job iOS de la CI 40004598011, commit `08729ef9a9422a2e69970d2d12319559be3d70b9`. Xcode 26.3 (17C529), SDK iPhoneOS 26.2. El empaquetado en Linux reutiliza esa compilación macOS; no recompila código iOS.

```sh
gh run download 40004598011 --repo tecnofifamobile-ai/AcroStella-Analytics --name acrostella-ios-unsigned --dir artifacts/ios-0.4.0-ci
python3 tool/package_unsigned_ipa.py artifacts/ios-0.4.0-ci/acrostella-unsigned.zip artifacts/ios-0.4.0-ipa
python3 -m unittest discover -s tool -p 'test_package_unsigned_ipa.py'
```

La herramienta crea `Payload/Runner.app` conservando bytes, permisos Unix y enlaces simbólicos. Verifica identidad, versión, familia iPad, plataforma física iPhoneOS, permiso de cámara, binarios Mach-O arm64 (incluido el contenedor FAT de App.framework) y CRC. Rechaza rutas inseguras, archivos de firma y sobrescritura silenciosa. Cuatro pruebas de empaquetado superadas y validación sobre el artefacto real. La CI futura genera directamente `.ipa` y `.sha256` con esta herramienta.

Archivo: `acrostella-analytics-0.4.0+4-unsigned.ipa`, 7 418 498 bytes. SHA-256 previo a la firma:

[Descarga directa](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/ios-v0.4.0%2B4/acrostella-analytics-0.4.0%2B4-unsigned.ipa) · [Release de pruebas iOS](https://github.com/tecnofifamobile-ai/AcroStella-Updates/releases/tag/ios-v0.4.0%2B4). Se descargó públicamente otra vez y se verificaron tamaño, SHA-256, CRC, estructura e Info.plist. Commit público exclusivamente de instaladores: `54695b3`. El canal estable Android mantiene la versión 0.4.0.

```text
93806548c272aa2d67d3a19ce99b97f43654d935b24b9649abbf0c3349240576
```

Firmar modifica el archivo y su hash. El hash publicado verifica la descarga original, no una IPA ya firmada. Las versiones iOS se publican como prereleases separadas, para conservar la release estable Android y su actualizador. iOS todavía no tiene actualización integrada: las siguientes IPA se importan y firman en Flarestore.

## Fuente para Flarestore

Publicado `flarestore.json` en el repositorio público de instaladores, commit `665a2d0`, con formato AltStore: identidad estable de fuente, aplicación, versiones y campos heredados, icono de la app actual, tamaño y SHA-256. La versión apunta a la IPA inmutable ya publicada. La URL de fuente permanece en `main` para futuras entregas. Se contrastaron identidad, versión/build y sistema mínimo con Info.plist; fuente e icono accesibles sin autenticación y descarga de IPA verificada de nuevo por tamaño/hash/CRC. La release estable Android sigue siendo `v0.4.0+4`.

Formato contrastado con los decodificadores `Source`, `StoreApp` y `AppVersion` de [AltStore](https://github.com/altstoreio/AltStore/tree/develop/AltStoreCore/Model). El soporte de fuentes AltStore de Flarestore aparece documentado también en [su distribución localizada](https://github.com/GodDaddy-one/FlareStore-ZH). No se ha ejecutado el importador de Flarestore en un dispositivo; la importación, firma e instalación física siguen pendientes. En próximas versiones actualizar ambos juegos de campos (`versions` y campos heredados) manteniendo el mismo identificador y la misma URL de fuente.
