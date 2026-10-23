# Punto de entrada para continuar en ChatGPT Work Cloud

**Actualización, 23 de octubre de 2026:** entorno preparado activando `/workspace/.acrostella-setup/activate.sh` (Flutter 3.47.3/Dart 3.13.3/JDK 17). El incremento **0.4.0+4** añade iniciar/terminar con revisión automática, Guardar/Eliminar/Otro, biblioteca persistente, nombres/notas/favoritos/búsqueda, seis herramientas de dibujo y repetición A–B/momentos. Pasaron 102 pruebas Flutter y 7 nativas, análisis y APK release. Leer `05-estado-y-evidencias.md`, `estado.json` y [publicación](../actualizaciones.md) para la evidencia vigente. El código sigue privado; `AcroStella-Updates` público está autorizado solo para instaladores. Mantener la clave Android persistente. iOS usa Xcode 26.3 en CI sin firma; verificar resultado real, no asumir IPA. Nube y body tracking pospuestos por el usuario. Multicámara/continuidad y hardware pendientes.

## 1. Qué se entrega

Código Flutter del primer incremento y contexto amplio en un repositorio privado. El objetivo es continuar el mismo producto sin repetir la entrevista ni rehacer su definición. La aplicación deportiva seguirá procesando datos localmente por defecto; cambiar dónde desarrollamos no añade nube al producto.

Repositorio: `https://github.com/tecnofifamobile-ai/AcroStella-Analytics`. Rama: `main`. El código inicial está en `05ad74499c7f39a4c5c9a41cbfe99813bf43b1be`; consultar el HEAD remoto para el commit posterior del paquete contextual.

El traspaso original se conserva a continuación; la preparación y el avance actuales se resumen arriba.

## 2. Prompt para abrir la nueva tarea

Copiar el siguiente bloque en una tarea Cloud con acceso al repositorio privado:

```text
Continúa el desarrollo real de AcroStella Analytics desde el repositorio privado
https://github.com/tecnofifamobile-ai/AcroStella-Analytics, rama main.

Lee primero AGENTS.md, docs/contexto/README.md,
docs/contexto/05-estado-y-evidencias.md y
docs/contexto/02-entrevista-y-decisiones.md. Consulta el encargo extenso en
docs/contexto/01-encargo-maestro.md y la arquitectura en
docs/contexto/04-arquitectura-y-pendientes.md. No repitas la entrevista inicial.

Ya existe una app Flutter 0.4.0+4: iniciar/terminar ejercicio abre y reproduce
directamente el vídeo con guardar/eliminar/otro. Biblioteca persistente de
un ángulo con fecha, nombre, notas, favoritos y búsqueda; dibujo libre,
líneas, ángulos, flechas, rectángulos y elipses; estilo, duración, historial,
momentos y repetición A-B. Actualizador Android integrado desde 0.3.0.
102 tests Flutter, 7 nativos, análisis y APK release correctos en Cloud.
Ver evidencias para publicación y CI Apple (Xcode 26.3, sin firma).
No atribuir builds anteriores a esta versión ni inventar hardware físico.
Faltan WebRTC, búfer segmentado, replay continuo y sincronización. Los guardados
ya no son caché; solo se eliminan por acción explícita. Los pendientes se limitan
a 3/512 MiB. Nube y body tracking se dejan para el futuro por petición del usuario.
Leer docs/actualizaciones.md antes de publicar y mantener la misma clave Android.

El iPad Air M4 de 13 pulgadas ES cámara y centro de análisis. La primera
cámara Android es Samsung S24 Ultra, One UI 8.5 declarada; probablemente
usaremos su hotspot. No tenemos Mac. No presupongas iPhones ni otro Android.

El flujo aceptado es pulsar Iniciar ejecución antes del elemento y Revisar
al terminar. Eso delimita un intervalo de ambas cámaras sin detenerlas.
Se revisan a partes iguales y se guardan ambos ángulos juntos, con fecha
automática y nombre opcional. Las anotaciones tendrán duración configurable.
El lápiz es genérico con rechazo de palma declarado. Audio aún sin decidir;
la primera prueba local está sin audio.

Comprueba rama, estado Git, herramientas y CI. Trabaja por entregas comprobables:
validar cámara local y resolver el propietario nativo y la derivación de
captura antes de integrar WebRTC y replay comprimido. No abras la misma
cámara a la vez desde camera y getUserMedia. No acumules frames crudos en Dart.

Comunícate en español. No vuelvas a comparar frameworks ni generes otro
plan genérico. Distingue implementación, tests, compilación, firma,
instalación y hardware real. No inventes métricas. No uses ni pidas subir
certificados, perfiles, contraseñas o vídeos reales; la firma requiere
procedimiento seguro y autorización específica. Continúa con trabajo real.
```

## 3. Preparar el entorno de ejecución

Primero comprobar acceso efectivo al repositorio y herramientas. La conexión GitHub de esta conversación no garantiza permisos idénticos en otra tarea. Si el entorno necesita una autorización nueva, explicarla de forma concreta y no solicitar contraseñas en el chat.

En un shell Linux/macOS, una vez clonado en el directorio elegido por el entorno:

```sh
git status --short
git log -3 --oneline
flutter --version
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
```

No ejecutar estos comandos como si Flutter estuviera instalado sin comprobarlo. Si falta el SDK, preparar la versión fijada en `pubspec.yaml`, no cambiar la app a otra tecnología ni actualizarla a ciegas. No copiar `android/local.properties` de Windows.

Android necesita Java, SDK y NDK apropiados. El workflow ya muestra una configuración ejecutable. iOS necesita macOS: utilizar Actions, no intentar invocar Xcode en un contenedor Linux. El código generado puede compilarse con un SDK anterior al iPadOS del usuario; eso no sustituye probar su instalación y ejecución.

## 4. Trabajo inmediato con sentido

1. Revisar el resultado y artefactos de la primera CI. Corregir únicamente errores reales.
2. Preparar acceso al APK y una primera prueba de cámara en el S24; registrar lo observado.
3. Separadamente, diseñar el procedimiento de firma del resultado iOS con el certificado ya disponible, sin leerlo ni enviarlo a servicios hasta autorización específica. No recomendar comprar otro certificado antes de revisar el existente.
4. Resolver el punto técnico pendiente de mayor impacto: captura nativa única y derivación hacia preview, WebRTC y almacenamiento comprimido.
5. Incorporar una segunda fuente real y después revisión de intervalos con captura continua, con pruebas progresivas.

No bloquear lógica independiente esperando todos los detalles de biblioteca o biomecánica. Tampoco construir una interfaz de replay con datos simulados y declararla funcional.

## 5. Preguntas que podrían hacer falta después

Audio; duración máxima de un elemento y una sesión; cuota/retención; versión base de Android; modelo real del segundo móvil; calibración; herramientas de dibujo iniciales. Preguntar cuando condicionen una entrega, explicando la consecuencia. No repetir preguntas sobre vista mitad y mitad, selección antes/después, guardado de ambos ángulos o iPad como cámara.

## 6. Fin de una entrega

Actualizar `05-estado-y-evidencias.md`, `07-matriz-de-requisitos.md` y `estado.json` con revisión, comandos, resultados y límites. Mantener documentos de fuente/entrevista como historial, sin alterar retrospectivamente lo que dijo el usuario. Informar de implementación, pruebas, pendientes y siguiente paso en pocas líneas.
