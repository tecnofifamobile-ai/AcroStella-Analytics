# Actualizaciones iOS y publicación unificada — 0.5.2+7

Fuente `d5fafbaf21aec355901dd337c71be0737e912c47`. [CI](https://github.com/tecnofifamobile-ai/AcroStella-Analytics/actions/runs/40025955002): CI completa Android/iOS correcta. iOS job 120662093359, artefacto 12531979150 (ZIP Actions 7997005 bytes); Xcode 26.3 (17C529), SDK iPhoneOS 26.2. No se utilizan certificados Apple del usuario.

## Problema y alcance de la corrección

El usuario vuelve a no ver la versión en Flarestore. Se consultaron ambas URL públicas y servían 0.5.1/build6 con IPA verificada, `Cache-Control: max-age=300`. Esto no reproduce la caché ni las comparaciones del cliente del usuario; causa sin confirmar. La fuente es compatible con formato AltStore; no se afirma que cambiar el JSON controle todas las cachés externas.

Se implementa consulta y descarga propias en AcroStella iOS: API pública de GitHub para HEAD de main, manifiesto iOS en URL fijada a ese commit, comprobación de Release iOS no borrador, URL del instalador fijada a etiqueta, tamaño/SHA-256 y mínima versión iOS. No usa releases/latest de Android. Códigos/versión instalados leídos con PackageInfo; menor/patch del SO comparados. Aviso diario opcional, búsqueda manual, cancelación/progreso, cache de instaladores separada de vídeos. Verifica de nuevo antes de compartir. Compartir abre el selector del sistema; Flarestore o Archivos/importación completan la firma/instalación. No se anuncian completadas hasta observar el build realmente instalado.

Un publicador genera ambos catálogos y manifiesto desde la misma IPA, conserva identidades/URL/bundle, exige build creciente y valida binarios arm64/CRC/hash/identidad. Retira el filtro opcional isBeta y añade versión/build visibles y noticia de publicación. No se atribuye el fallo anterior al filtro sin prueba del cliente. El repositorio público contiene únicamente instaladores, catálogos y documentación; las fuentes y herramientas de la app siguen privadas.

## Comprobaciones

Lock, formato y análisis sin incidencias; **132 pruebas Flutter**, **ocho Python**, **siete nativas**. Tests específicos de cambio de HEAD con catálogo antiguo, manifiesto/URL/bundle incorrectos, borrador, hash incorrecto y limpieza parcial; verificación de IPA modificada antes del envío; compartir no equivale a instalar; compatibilidad iOS por versión menor; interfaz de envío; publicación de los tres JSON coherentes desde una IPA, identidades, incremento y rechazo de material de firma. Se mantienen las pruebas anteriores de cámaras sintéticas, TCP local real, medios agrupados y lectores simulados. APK debug/release compilados en Linux; iOS exclusivamente macOS.

## Entrega pública

- [APK 0.5.2+7](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/v0.5.2%2B7/acrostella-analytics-0.5.2%2B7.apk), **57631417 bytes**, SHA-256 `5034dd9cbd91f3604b40ab48631669de9c0b80cfad3db941d86cddc925da0da5`. Firmante persistente SHA-256 `dfbc2a66221d8b63f7d473fac2e1b80ae7b6a968c2f16f757994f97b16936d3f`; no distribución con clave efímera de CI.
- [IPA 0.5.2+7 sin firma](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/ios-v0.5.2%2B7/acrostella-analytics-0.5.2%2B7-unsigned.ipa), **8020526 bytes**, SHA-256 `be5fbe0aa80c4cb38a2b60f05665b3f89f1cdf495d9f46a8232423f88103af2a`. Commit público `5ff46e2a68c57c8c5eb2be9e398ce832cf147c5b`. Bundle `com.acrostella.acrostellaAnalytics`, mínimo 15.0.
- Ambas fuentes Flarestore y `acrostella-ios-update.json` comprobados desde la publicación; descarga completa con los clientes reales Android/iOS sin autenticación y hash/tamaño verificados. La Release estable sigue siendo Android; iOS prerelease separada.

La IPA debe importarse una vez para estrenar este actualizador. Los archivos .p12/perfil adjuntados no se han leído, enviado a CI ni copiado a fuentes/artefactos. No se prueba firma, compatibilidad del certificado, importación ni ejecución en hardware. Persisten los límites de grabación finita, ausencia de vista remota en directo y necesidad de comprobar alineación física; nube y body tracking aplazados.
