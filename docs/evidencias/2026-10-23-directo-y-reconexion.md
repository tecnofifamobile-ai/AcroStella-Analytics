# Directo LAN, confianza y recuperación — 0.6.0+8

Código de ejecución: `406e6c836b7153e24ee1903b1af8a4d1d427afc6`. Entrega del 24 de octubre de 2026 (Europe/Madrid; archivos de CI fechados en UTC). [CI completa](https://github.com/tecnofifamobile-ai/AcroStella-Analytics/actions/runs/40031981690): **success**; jobs Android `120682266921` e iOS `120682266729`. [Datos de CI](2026-10-23-ci-v06.json).

## Implementación

Un track nativo para textura, sender WebRTC y writer MP4 acotado. Código de seis cifras inicial con SRP, identidad y confianza segura, HMAC de reanudación con retos nuevos, reconexión al primer plano y búsqueda por ID. Centro con dos cámaras visibles. Clips finalizados/acuse/correlación temporal conservados en diario atómico; recuperación al reconstruir controladores y corte al final del archivo. Primer frame aceptado nativo como ancla de alineación; ajuste manual conservado. UI compacta, material de Apple y renderer Flutter investigados; mantener pantalla despierta solo en primer plano. [Arquitectura](../arquitectura.md), [uso](../conexion-local.md), [fuentes del diseño](../diseno-liquid-glass.md).

## Verificación real en Cloud

- `flutter pub get --enforce-lockfile`, formato y `flutter analyze --fatal-infos`: correctos.
- **138 pruebas Flutter**: regresiones, TCP loopback/cámaras sintéticas, confianza persistente, reanudación sin código y rechazos de clave/identidad, recuperación con reloj de controlador nuevo, acuse perdido, finalización concurrente que espera al archivo, agrupación/hash y revisión con decodificadores simulados.
- **8 pruebas Python** de empaquetado/publicación IPA y **8 JUnit** propios: siete de instalador y uno concurrente de la puerta nativa de frames.
- APK debug/release reales en Linux. MinSdk 24 y tres ABI; cámara/red/instalador, sin micrófono, almacenamiento externo ni wake lock. Keystore Android persistente, firmante SHA-256 `dfbc2a66221d8b63f7d473fac2e1b80ae7b6a968c2f16f757994f97b16936d3f`.
- iOS dispositivo release **sin firma** compilado en macOS con Xcode **26.3 (17C529)** / SDK **26.2**. IPA arm64/minOS `15.0`, bundle `com.acrostella.acrostellaAnalytics`, familia iPhone/iPad. No se abrieron ni utilizaron los certificados/perfil aportados. No es instalación automática.
- Publicación verificada por descarga completa/hash usando los clientes reales de actualización Android e iOS. Ambos catálogos mantienen identidad/URL y anuncian un único 0.6.0/build8; Android sigue siendo la Release estable latest.

## Artefactos publicados

| Plataforma | Etiqueta / commit público | Bytes | SHA-256 |
| --- | --- | --- | --- |
| [APK](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/v0.6.0%2B8/acrostella-analytics-0.6.0%2B8.apk) | `v0.6.0+8` / `c0bd90c7136c75eec0bc251f519c775837a8a1cf` | 92,799,843 | `4aa15cf55d58b1f08a562a4914d10092674bc91d2c0f2e1255307a1a056ab24e` |
| [IPA sin firma](https://raw.githubusercontent.com/tecnofifamobile-ai/AcroStella-Updates/refs/tags/ios-v0.6.0%2B8/acrostella-analytics-0.6.0%2B8-unsigned.ipa) | `ios-v0.6.0+8` / `17178b2731d3edb7ed9f87c3e6b9a0637a4af93b` | 13,825,843 | `290241be9a9d06109a0dbe971747d578885f4665ed50767acc4b814c8904003f` |

Artefacto de CI iOS `12535158228`: 13,789,310 bytes, retención de siete días. Copias locales en `artifacts/`, fuera de Git. Solo instaladores, manifiestos y documentación en el repositorio público autorizado; fuentes privadas.

## Límites pendientes

No se ha instalado ni probado físicamente **esta versión** en iPad/S24. Faltan permisos, orientación del MP4, doble directo real, reconexión del hotspot, fidelidad visual del material nativo, calor, memoria, latencia y alineación sobre un movimiento común. Los tests de cámara/reproductor son simulados; la puerta concurrente no mide consumo total de WebRTC. Las capturas de layout en renderizado software no validan refracción GPU.

El directo tiene su latencia; la revisión usa los originales y una alineación inicial estimada, no exposición sincronizada del sensor ni presentación atómica. No hay cero desfase garantizado, búfer circular, replay comprimido continuo, nube ni body tracking. Segundo plano puede suspender la cámara. La recuperación requiere archivos finalizados todavía existentes; no repara un MP4 interrumpido antes de finalizar ni reanuda bytes.

La primera compilación de esta entrega detectó un identificador incorrecto en el canal nativo iOS; se corrigió antes de publicar. Los runs intermedios/cancelados no se presentan como evidencia del commit final.
