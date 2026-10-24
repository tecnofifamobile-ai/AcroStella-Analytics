# Distribución Android

El código permanece privado en `AcroStella-Analytics`. El usuario autorizó y creó [AcroStella-Updates](https://github.com/tecnofifamobile-ai/AcroStella-Updates), público, para distribuir únicamente instaladores y metadatos de actualización. No copiar fuentes, grabaciones ni claves allí.

## Usar las actualizaciones

Instalar una primera vez el APK actual de Releases. Desde esa versión, el icono de actualizaciones permite buscar manualmente y descargar dentro de la app, con notas de versión, progreso, cancelación y reintento. La consulta automática está activada inicialmente, se puede desactivar y se limita a una comprobación exitosa cada 24 horas mientras la app está abierta. El aviso aparece dentro de la app cuando no se está grabando; no requiere permisos de notificaciones del sistema.

La descarga requiere Internet, no cuenta ni token. No se inicia hasta pulsar descargar. Al terminar, se comprueban tamaño, SHA-256, paquete, versión superior, versión Android y certificado de firma. Se verifica de nuevo antes de abrir el instalador nativo. Android solicita autorización para instalar desde AcroStella cuando sea necesaria y siempre controla la confirmación final. Se bloquea instalar durante un clip activo. Al volver se consulta la versión realmente instalada: abrir el instalador no se anuncia como actualización completada.

Los instaladores se guardan solo en `cache/app_updates`, separados de los clips. Una descarga incompleta nunca se ofrece para instalar; se limpia al cancelar/reintentar. Se conservan como máximo el último APK descargado y uno anterior. La caché puede desaparecer por acción del sistema. Los metadatos y las redirecciones solo admiten HTTPS en los hosts permitidos de GitHub; no se desactiva TLS.

## Publicar una versión futura

1. Incrementar `version` en `pubspec.yaml`, especialmente el código tras `+`.
2. Mantener la misma clave Android que firmó la versión ya instalada. El build actual usa la clave de pruebas persistente del entorno; no es una clave de distribución comercial. Conservarla privadamente y no regenerarla entre publicaciones. Los APK de Actions pueden tener otra clave y no deben publicarse como actualizaciones compatibles.
3. Ejecutar las comprobaciones del proyecto y las pruebas nativas de la app (`cd android && ./gradlew :app:testDebugUnitTest`). Compilar el APK e inspeccionar su firma.
4. Escribir notas breves, sin información privada, y publicar desde el proyecto privado:

```sh
flutter build apk --release
python3 tool/publish_android_update.py build/app/outputs/flutter-apk/app-release.apk --notes-file /tmp/release-notes.txt
dart run tool/check_update_feed.dart /tmp/acrostella-public-check
```

El publicador requiere Android SDK (build-tools 36.0.0), Python 3.11+ y `gh` autenticado con permiso de Releases del repositorio público. Valida identidad, firma y código creciente, impide sobrescribir una versión y compara el certificado con el manifiesto previo. Crea un borrador, sube exactamente el APK inspeccionado y `acrostella-update.json`, vuelve a descargar ambos para verificarlos y publica solo después. Un error conserva el borrador para diagnóstico. No subir un directorio con comodines.

Si las credenciales del entorno no permiten subir a `uploads.github.com`, se admite `--git-assets`. Este modo clona solo el repositorio público, añade exactamente APK/manifiesto y sube un commit y una etiqueta de versión mediante Git. Nunca clona ni añade el proyecto privado. Verifica ambos archivos públicos antes de publicar la Release. La app los descarga desde `raw.githubusercontent.com`, fijados a esa etiqueta; rechaza referencias como `main` y discrepancias entre etiqueta y versión. Se usa este canal en 0.3.0 porque la subida de assets devuelve 401 en Cloud. No se fuerza ni sobrescribe una etiqueta publicada.

```sh
python3 tool/publish_android_update.py build/app/outputs/flutter-apk/app-release.apk --notes-file /tmp/release-notes.txt --git-assets
```

El modo Git solo admite APK menores de 100 MiB y conserva los binarios en la historia pública: aumenta el tamaño del repositorio con cada versión. Preferir assets de Releases cuando estén disponibles; la app admite ambos canales sin cambiar la configuración. Si una publicación Git se interrumpe tras el push, comprobar el hash y los archivos ya subidos antes de completar el borrador; no volver a subir el mismo número con otros bytes.

El manifiesto contiene schema, paquete, nombre/código de versión, minSdk, bytes, SHA-256, nombre del APK, notas y huella pública del certificado. La app compara el certificado real del APK con el suyo; no confía solo en la huella del manifiesto. La herramienta de comprobación usa el mismo cliente de red y verificación SHA-256 que la app, sin autenticación. No sustituye la instalación física.

Las IPA sin firma se distribuyen mediante la [fuente Flarestore](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/main/flarestore.json), con releases iOS marcadas como prereleases para conservar el canal estable Android. La firma se realiza en el dispositivo del usuario, sin utilizar certificados Apple en Cloud. [Procedimiento y evidencia](ios-flarestore.md). La comprobación Android no modifica ese procedimiento.
