# Primera instalación iOS con Flarestore

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
