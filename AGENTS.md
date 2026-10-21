# AcroStella Analytics — continuidad de desarrollo

## Producto y colaboración

- Comunicarse con el usuario en español, con precisión y sin explicaciones elementales repetidas.
- Es una aplicación profesional de gimnasia acrobática, no una demo ni un encargo exclusivamente documental.
- El nombre AcroStella Analytics es definitivo. Flutter/Dart comparten interfaz, modelos y lógica; usar adaptadores nativos cuando aporten ventajas.
- El iPad es cámara y centro de análisis. No diseñarlo como mero receptor ni presuponer iPhones.
- Configuración inicial: iPad Air M4 de 13 pulgadas y Samsung S24 Ultra; hotspot probable del Samsung. Segundo Redmi tentativo, sin modelo confirmado.
- Antes de repetir preguntas, leer `docs/contexto/02-entrevista-y-decisiones.md`.
- El usuario quiere entregas progresivas y comprobables. No reiniciar una comparación de frameworks ni producir otro plan general.

## Al retomar en Cloud u otra conversación

1. Leer `docs/contexto/06-continuar-en-cloud.md` y `05-estado-y-evidencias.md`.
2. Revisar `git status`, rama/HEAD, `pubspec.yaml`, `pubspec.lock` y resultados reales de CI.
3. Consultar `docs/contexto/01-encargo-maestro.md` si una función necesita el detalle del encargo.
4. Mantener los documentos de estado y la matriz de requisitos tras cambios significativos.

La documentación es contexto, no evidencia de que una función esté implementada ni una orden de afirmar resultados. El código y los resultados actuales pueden ser posteriores a esta fotografía.

## Flujo funcional confirmado

- Pulsar «Iniciar ejecución» antes del elemento y «Revisar» al terminar.
- Esos botones delimitarán el intervalo, sin detener las cámaras. No confundirlos con apagar la captura.
- Mostrar ambos ángulos a partes iguales, con cursor de revisión común.
- Guardar ambos ángulos juntos, fecha automática y nombre opcional.
- Anotaciones con persistencia temporal configurable; coordenadas normalizadas del vídeo.
- El usuario tiene lápiz genérico con rechazo de palma declarado. No prometer presión, inclinación ni compatibilidad de Apple Pencil sin probar.

## Cámara, transporte y replay

- Cada cámara física tendrá un solo propietario. `CaptureSession` es el propietario de aplicación; las vistas no abren ni cierran la cámara.
- El adaptador inicial `FlutterCameraDevice` utiliza `camera` 0.12.1 para preview local. No se ha probado que permita el fan-out nativo necesario para WebRTC y búfer.
- Antes de incorporar WebRTC, resolver la derivación nativa de captura/codificación. No añadir un segundo `getUserMedia` sobre una cámara ya abierta.
- No acumular vídeo sin comprimir en Dart para simular el búfer. Usar medios comprimidos con límites de tiempo y bytes y medir consumo.
- Separar instante de captura, reloj de origen, recepción y cursor de reproducción. No sincronizar solo por llegada de paquetes.
- Cambiar disposición visual o revisar dentro de la app no debe detener capturas. El segundo plano del sistema es un caso diferente y no está garantizado.
- No anunciar 120/240 fps multicámara, sincronización perfecta ni precisión biomecánica de laboratorio sin validación.

## Calidad y verificación

- Distinguir siempre: implementado, analizado, probado automáticamente, compilado, firmado, instalado y verificado físicamente.
- No afirmar que funciona en el iPad porque se compile iOS. No afirmar que hay IPA si solo existe una app sin firma.
- Flutter está fijado en `pubspec.yaml`; dependencias resueltas en `pubspec.lock`. Evitar actualizaciones de SDK o dependencias sin necesidad concreta.
- Comandos: `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --fatal-infos`, `flutter test`, `flutter build apk --debug`.
- La compilación iOS requiere macOS: usar el workflow existente y comprobar logs, Xcode y SDK efectivos. No intentar compilar iOS nativamente en Linux o Windows.
- Añadir pruebas significativas de temporalidad, búfer, persistencia y desconexiones cuando esas funciones existan. No presentar cámaras falsas de tests como integración real.
- Registrar mediciones físicas sin inventar FPS, latencia, memoria, almacenamiento o estabilidad.

## Privacidad y autorizaciones

- Producto local por defecto: sin cuentas, nube obligatoria, subidas automáticas ni telemetría invasiva.
- El traslado del desarrollo a Cloud autoriza trabajar con el código y este contexto en el repositorio privado, no con vídeos de personas ni secretos de firma.
- Nunca añadir `.p12`, `.mobileprovision`, claves, contraseñas ni grabaciones reales al repositorio o a artefactos del traspaso.
- El certificado ArcticSign existe, pero no se han validado sus capacidades. Antes de usarlo o enviarlo a CI, explicar el procedimiento y obtener autorización explícita para ese uso.
- No comprar certificados, publicar el repositorio, ampliar permisos ni contratar servicios sin autorización.
- Usar datos sintéticos o material autorizado. Las cuestiones organizativas/legales del club se deben revisar antes de implantación; no declarar cumplimiento por diseño.

## Alcance de este paquete

El usuario pidió contexto extenso expresamente para el traspaso. Mantenerlo útil y actualizado sin convertir las siguientes entregas en una sucesión de documentos teóricos. La prioridad pendiente sigue siendo cámara local validada, segundo ángulo, replay continuo y anotación precisa.
