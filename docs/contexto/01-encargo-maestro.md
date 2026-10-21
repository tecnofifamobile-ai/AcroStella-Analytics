# Encargo maestro de AcroStella Analytics

Fuente: mensaje inicial del usuario, 21 de octubre de 2026. Se conserva aquí su contenido de producto y de colaboración, reorganizado en Markdown para su consulta. Este documento no registra funcionalidades implementadas. Las respuestas posteriores se conservan en `02-entrevista-y-decisiones.md` y concretan las alternativas abiertas de este encargo.

## 0. Misión y forma de trabajar

Desarrollo profesional de una plataforma multiplataforma de análisis deportivo y biomecánico. El usuario pide actuar con el criterio de un equipo multidisciplinar especializado en arquitectura multiplataforma; Flutter, Dart y diseño de interfaces; iPadOS con Swift, AVFoundation y PencilKit; Android con Kotlin, CameraX, Camera2 y MediaCodec; WebRTC y redes locales; procesamiento de vídeo en tiempo real; sincronización y reproducción diferida; biomecánica, visión artificial y movimiento; UX/UI de productividad; seguridad y privacidad de grabaciones; pruebas, integración continua y distribución.

El objetivo es desarrollar realmente AcroStella Analytics, desde la definición funcional hasta versiones instalables y progresivamente completas. No se solicita una explicación de cómo podría desarrollarse una aplicación. ChatGPT Work será el entorno principal para investigar únicamente lo imprescindible, crear archivos, programar, trabajar con GitHub, ejecutar pruebas, corregir errores, gestionar versiones y preparar compilaciones.

No dedicar una cantidad excesiva de trabajo a planes, análisis genéricos ni documentos teóricos. Las decisiones fundamentales están definidas. Primero realizar una entrevista relevante y profunda; después de resolver las decisiones necesarias, pasar al desarrollo real. No inventar resultados de compilación, funcionalidades terminadas ni pruebas en hardware. Diferenciar siempre código implementado, código compilado, pruebas automatizadas y funcionalidades verificadas físicamente.

## 1. Identidad y visión del producto

Nombre definitivo: **AcroStella Analytics**.

Plataforma profesional de grabación, análisis de vídeo, comparación técnica y estudio biomecánico, enfocada especialmente en gimnasia acrobática. Debe ser útil para entrenadores, gimnastas y deportistas que necesitan estudiar movimientos con precisión.

Referencias funcionales, sin copiar diseño ni código:

- Coach Bowman: cámaras conectadas y revisión durante el entrenamiento.
- Camo Studio: multicámara y gestión de fuentes de vídeo.
- Video Delay Instant Replay: repeticiones automáticas.
- CoachView y herramientas similares: anotaciones, cámara lenta y análisis.
- Kinovea: mediciones y trayectorias.
- OpenCap y herramientas biomecánicas: análisis avanzado del movimiento.

Se quiere un producto original, moderno, fluido y ampliable. Movimientos de interés: entradas agrupadas a pino o cannonball; posiciones estáticas, verticales y mexicanas; impulsos y lanzamientos; mortales y dobles mortales; recepciones o catches; elementos dinámicos en pareja y trío; equilibrios y transiciones; preparación física; ejecuciones individuales y colectivas. La arquitectura debe admitir otros deportes posteriormente.

Filosofía: el entrenador debe poder grabar, observar, repetir, comparar, medir, anotar y explicar **sin interrumpir la captura**, con muy pocas pulsaciones y sin operaciones innecesarias.

## 2. Dispositivos y entorno

Dispositivo principal declarado: iPad Air de 13 pulgadas con procesador M4, inicialmente iPadOS 27.0.1. El usuario dispone de Windows 11, Fedora Linux 44, certificado ArcticSign asociado al iPad, FlareStore instalado, acceso a GitHub, posibilidad de pruebas físicas y disposición a dedicar tiempo al desarrollo y las pruebas. No tiene Mac físico.

No presuponer iPhones como cámaras ni modelos concretos de Android sin preguntar.

- Configuración habitual: el iPad graba con su cámara y un Android graba otro ángulo.
- Configuración ocasional: un iPad y dos Android adicionales.
- Configuración mínima: solo el iPad, autónomo.

La cámara del iPad es esencial. Nunca diseñar el iPad como mero monitor. Aprovechar el M4 y, cuando corresponda, su aceleración de vídeo y procesamiento local.

## 3. Arquitectura: compartir la interfaz

La decisión inicial es Flutter y Dart para evitar desarrollar íntegramente una interfaz para iPadOS y otra para Android.

Requisitos: un mismo proyecto principal; biblioteca compartida de componentes; diseño adaptable a tabletas y móviles; modelos de datos comunes; lógica compartida cuando sea posible; módulos nativos separados solo cuando aporten ventajas; arquitectura modular, comprobable y ampliable.

El iPad será principalmente centro de análisis, pero la arquitectura debe permitir que Android lo sea en el futuro. Ambas plataformas podrán trabajar como cámaras. Compartir interfaz no obliga a compartir motor de cámara: motores diferentes por plataforma son aceptables y deseables.

| Área | Tecnología inicial de referencia |
| --- | --- |
| Interfaz | Flutter + Dart |
| Estado y lógica | Arquitectura reactiva modular |
| Transmisión | WebRTC |
| Captura iPadOS | AVFoundation |
| Captura Android | CameraX / Camera2 |
| Multimedia Apple | AVFoundation / VideoToolbox |
| Multimedia Android | MediaCodec y APIs multimedia |
| Dibujo | Motor compartido, opción PencilKit |
| Control | WebRTC DataChannels / señalización local |
| Persistencia | SQLite y archivos locales |
| Análisis corporal futuro | Vision / Core ML / modelos multiplataforma |
| Compilación iPadOS | macOS en GitHub Actions |
| Compilación Android | Herramientas oficiales de Flutter y Android |

Son decisiones iniciales, no una orden de utilizar librerías inadecuadas. No repetir una investigación general entre Flutter, React Native, SwiftUI y Kotlin Multiplatform. Cambiar una decisión solo ante impedimento técnico comprobable o mejora sustancial, explicándolo brevemente.

Investigar durante la implementación quién posee cada sesión de cámara. Evitar que el plugin WebRTC y los módulos nativos intenten abrir simultáneamente una cámara. Compartir o derivar los fotogramas necesarios sin duplicar innecesariamente sesiones, codificaciones ni copias de memoria.

## 4. Núcleo multicámara

### Captura simultánea

El iPad debe grabar con su cámara, mostrar su directo, recibir simultáneamente un Android, añadir opcionalmente otro, mostrar todas las fuentes, cambiar entre ellas sin interrumpir capturas y seguir capturando mientras se revisan imágenes anteriores.

Android debe actuar como cámara remota, enviar vídeo estable, mostrar conexión y grabación, permitir ajustar calidad, recibir órdenes permitidas, detectar desconexiones y recuperarse cuando sea posible.

Admitir orientación vertical y horizontal; optimizar el análisis del iPad principalmente para horizontal.

### Vistas

Cámara principal a pantalla completa; división en dos; tres fuentes simultáneas; cambio rápido de principal; ventanas flotantes dentro de la app; ampliación de cualquier fuente; reorganización y etiquetas personalizadas como frontal, lateral y diagonal. La captura es independiente de la disposición visual. Cerrar temporalmente una vista no detiene por sí solo su cámara.

### Conexión inalámbrica

Priorizar WebRTC en red local, sin Internet cuando los dispositivos comparten Wi-Fi. Estudiar e implementar descubrimiento, emparejamiento por código o QR, reconexión, identidad persistente de dispositivos autorizados, estado y latencia, permisos, comunicación segura y control desde el iPad.

Evitar servicios externos obligatorios. No presuponer que una Wi-Fi permite comunicación entre clientes: detectar y explicar el aislamiento. No depender de permisos especiales de multicast sin alternativa razonable como dirección local o QR.

## 5. Replay sin transferencia manual de archivos

Es una función esencial. Android transmite continuamente y el iPad conserva temporalmente fragmentos recibidos; no se debe depender del envío manual de grabaciones.

Diseñar un búfer circular temporal y eficiente, preferentemente de medios comprimidos. Duraciones iniciales posibles: 5, 10, 15, 30 y 60 segundos, sujetas a soporte correcto. El entrenador revisa mientras continúa la captura.

Ejemplo: el iPad graba un lanzamiento a mortal con recepción desde lateral; Android transmite frontal; se realiza el ejercicio; se reproduce la ejecución anterior según el retardo configurado; se congela la imagen; se cambia de cámara; se retroceden fotogramas; se dibuja sobre la posición; ambas cámaras siguen capturando; se vuelve al directo instantáneamente. No debe ser necesario guardar una grabación completa.

Modos progresivos: directo, retardo automático, repetición manual, pausa, cámara lenta, fotograma siguiente y anterior, bucle entre dos marcadores, volver al directo, guardar los últimos segundos y guardar una ejecución seleccionada.

Captura, almacenamiento temporal, visualización en directo y reproducción son procesos separados. No almacenar indefinidamente vídeo sin comprimir en RAM. Medir memoria, almacenamiento, codificación y decodificación. Comenzar con resoluciones realistas, por ejemplo 720p o 1080p a 30 fps, y aumentar según hardware y pruebas. Los 120/240 fps son una modalidad avanzada local en dispositivos compatibles, no una garantía de retransmisión multicámara a esa frecuencia.

La entrevista posterior concreta que el flujo inicial no será simplemente un directo retrasado: se delimitará una ejecución con «Iniciar ejecución» y «Revisar».

## 6. Sincronización temporal

Los elementos son breves. Distinguir instante de captura, timestamp de fuente, tiempo de transmisión, recepción, reproducción y desfase estimado entre dispositivos. Recibir dos fotogramas a la vez no implica captura simultánea.

Se desea línea temporal común, compensación de desfases, corrección manual, comparación sincronizada de dos cámaras, registro de calidad temporal y detección de desviaciones anormales. Puede incorporarse calibración manual con palmada, señal visual o evento reconocible desde ambos ángulos. No anunciar precisión biomecánica de laboratorio sin validación.

## 7. Anotaciones y lápiz

Experiencia moderna, extremadamente fluida y pensada para Apple Pencil, manteniendo interfaz y modelos compartidos.

Herramientas iniciales deseadas: lápiz, rotulador, resaltador transparente, borrador, línea recta, horizontal, vertical, círculo, elipse, rectángulo, flecha, polilínea, ángulos o transportador, texto, deshacer/rehacer, selección y movimiento, colores y grosores configurables.

Herramientas especializadas progresivas: ángulo entre tres puntos; alineación hombro-cadera-tobillo; verticales de referencia; ejes corporales; trayectorias de objetos o articulaciones; marcadores de posiciones; comparación entre fotogramas; distancias calibradas con referencia fiable.

Asociar anotaciones a cámara, intervalo temporal o fotograma. Mantener su posición al cambiar vistas, relación de aspecto o zoom. Usar coordenadas normalizadas y transformaciones geométricas correctas.

Primero comprobar si el dibujo compartido de Flutter cumple precisión y fluidez. Integrar PencilKit en Swift solo si aporta ventajas reales, manteniendo controles, modelos y componentes compartidos con Android. No rehacer la interfaz para integrar PencilKit. Evitar interferencias entre dibujo, zoom, desplazamiento y selección.

La entrevista concreta que el lápiz disponible es genérico con rechazo de palma según el usuario; no se ha identificado como Apple Pencil oficial ni se han comprobado sus capacidades físicas.

## 8. Reproductor profesional

Además del replay, importar vídeos de Archivos y Fotos, abrir grabaciones locales, variar velocidad, navegar por fotogramas, mostrar tiempo y número de fotograma cuando se conozca, crear marcadores, recortar, sincronizar dos vídeos, comparar lado a lado y superponer con transparencia, posición y escala ajustables. Permitir zoom, anotaciones no destructivas y exportar una copia con dibujos incorporados. Más adelante, narración de voz y análisis explicados.

Debe existir análisis de grabaciones importadas independiente del directo.

## 9. Biblioteca local de entrenamientos

Modelo conceptual: **Club → Grupos o conjuntos → Sesiones → Ejercicios → Ejecuciones → Análisis**.

Posibles campos: nombre de sesión, fecha, conjunto/deportista, habilidad, cámaras, grabaciones, anotaciones, observaciones técnicas, etiquetas, comparación con ejecuciones anteriores, favoritos e historial de progreso.

Funciona localmente. Nube, exportación/importación, copias de seguridad y perfiles se estudiarán después. No incorporar cuentas ni nube obligatorias a la primera versión. El usuario no ha decidido aún una taxonomía concreta; no imponer formularios largos al primer guardado.

## 10. Biomecánica e inteligencia artificial

Importante, pero no debe retrasar la primera app funcional. Explorar detección corporal, articulaciones, ángulos, trayectorias, comparación de posiciones, estimación de velocidades, fases del ejercicio, estabilidad, reconocimiento de posiciones y asistencia técnica. Considerar Vision, Core ML y modelos locales.

La gimnasia acrobática incluye inversión corporal, agrupamientos, oclusión parcial y personas superpuestas. No asumir que un modelo convencional de pose funciona correctamente en esas condiciones. Mostrar incertidumbre y permitir correcciones manuales.

Investigar ideas innovadoras cuando corresponda; evitar IA superficial. El núcleo de captura y análisis manual debe funcionar sin IA.

## 11. Identidad visual y UX

Producto original, moderno, elegante y profesional. Interfaz minimalista, jerarquía excelente, modo oscuro cuidado, modo claro, tipografía legible, iconografía coherente, animaciones discretas, controles táctiles cómodos, compatibilidad con lápiz, aprovechamiento de las 13 pulgadas y adaptación Android.

Inspirarse en la calidad visual de Apple, aplicaciones deportivas, editores de vídeo y producción audiovisual sin copiar interfaces.

Prioridad de la pantalla de entrenamiento del iPad:

1. Imagen de las cámaras.
2. Controles de reproducción.
3. Línea temporal.
4. Anotaciones.
5. Información técnica esencial.

No saturar con estadísticas irrelevantes. Poder ocultar barras, herramientas y paneles.

Modos: Entrenador, con análisis completo; Cámara, ligero y centrado en captura/conexión/estado; Análisis, para vídeos guardados. Compartir componentes y no crear implementaciones visuales independientes por sistema operativo.

La entrevista fija una distribución inicial de dos cámaras a partes iguales.

## 12. Privacidad y datos

Puede grabarse a menores. Procesamiento local por defecto, sin subidas automáticas, analíticas invasivas ni compartición no autorizada. Emparejamiento seguro, permisos claros de cámara y red local, almacenamiento protegido mediante el sistema, eliminación de grabaciones, retención configurable y exportación explícita.

No incluir vídeos reales en repositorios; usar datos sintéticos o autorizados. Antes de implantación en un club, identificar cuestiones organizativas y legales sobre consentimiento e imágenes de menores, sin inventar garantías normativas. No exponer claves, certificados, perfiles ni contraseñas.

La petición de mover el desarrollo a Cloud no convierte la aplicación deportiva en un producto con almacenamiento de grabaciones en la nube.

## 13. GitHub, compilaciones y ausencia de Mac

Un repositorio privado, nombre sugerido **AcroStella-Analytics**, para ambas plataformas. No multiplicar repositorios sin razón. Android: compilaciones reproducibles con Flutter y herramientas oficiales, APK instalables para pruebas.

iPadOS: configurar ejecutores macOS de GitHub Actions compatibles con Flutter, Xcode y SDK necesario. Primero compilar correctamente; después estudiar IPA, firma e instalación.

Ya existen certificado ArcticSign y archivos de aprovisionamiento asociados al iPad. No recomendar comprar otro sin comprobarlos. No asumir capacidades equivalentes a una cuenta Apple Developer propia. Distinguir compilación, firma, compatibilidad del perfil, instalación y ejecución física.

Antes de solicitar datos sensibles de firma, explicar procedimiento seguro. No incluir secretos en Git ni transmitirlos a servicios externos sin autorización explícita.

CI progresiva: análisis estático, pruebas unitarias y de componentes, Android, iPadOS, artefactos, errores e instrucciones de instalación. Una compilación correcta no prueba funcionamiento físico.

## 14. Arquitectura y calidad del código

Código modular y mantenible, funciones independientes cuando sea razonable, contratos claros y complejidad proporcionada. Separación conceptual entre app/interfaz, sesiones, captura, transporte, sincronización, búfer y reproducción, anotaciones, almacenamiento, exportación, biomecánica, configuración y adaptadores nativos.

Evitar librerías abandonadas si existen alternativas estables. Centralizar versiones/configuración. Documentar solo decisiones que condicionen trabajo futuro. Incluir pruebas de lógica temporal, búfer, persistencia de anotaciones y desconexiones cuando se implementen.

## 15. Primer MVP útil y criterios de aceptación

Capacidades requeridas:

1. Abrir AcroStella en el iPad.
2. Usar su cámara trasera.
3. Mostrar su directo.
4. Conectar un Android.
5. Recibir su transmisión.
6. Mostrar ambas cámaras.
7. Cambiar entre ellas.
8. Conservar temporalmente los últimos segundos.
9. Revisarlos sin detener las capturas.
10. Pausar y avanzar por fotogramas.
11. Dibujar una línea o un ángulo.
12. Guardar una ejecución.
13. Recuperarla después.

El orden interno puede adaptarse a dependencias. IA, reconstrucción 3D y biblioteca extensa no son necesarias antes de este hito.

En hardware debe comprobarse que el iPad sigue capturando durante revisión; Android no necesita transferir archivos manualmente; cambiar vistas no detiene capturas; anotaciones mantienen posición; desconexiones se comunican; se vuelve al directo; vídeos guardados abren; almacenamiento temporal está limitado; no hay subidas por defecto.

Medir latencia, FPS, memoria y estabilidad sin inventar cifras. Empezar con sesiones cortas y aumentar hasta aproximarse al entrenamiento prolongado.

## 16. Funciones posteriores

Multicámara: tres cámaras sincronizadas, comparación paralela, superposición de ángulos, repeticiones sincronizadas, marcadores comunes y cámaras preconfiguradas.

Herramientas del entrenador: comentarios por ejecución, plantillas de corrección, habilidades, historial de conjuntos, explicaciones grabadas, vídeos anotados e informes.

Biomecánica: articulaciones, trayectorias, medidas temporales, referencias, comparación técnica, seguimiento semiautomático y gráficas vinculadas al vídeo.

Innovación: detectar comienzo y final, sugerir momentos para revisión, estabilidad, comparación asistida, reconstrucción multicámara experimental y paneles avanzados. Son oportunidades futuras, no obligaciones inmediatas del primer incremento.

## 17. Investigación técnica aportada por el usuario

Referencias para evitar investigación general repetida:

- Flutter: https://docs.flutter.dev/
- Flutter WebRTC: https://pub.dev/packages/flutter_webrtc
- AVFoundation: https://developer.apple.com/documentation/avfoundation
- Restricciones de salidas de captura: https://developer.apple.com/documentation/avfoundation/avcapturesession/canaddoutput%28_%3A%29
- PencilKit: https://developer.apple.com/documentation/pencilkit/pkcanvasview
- CameraX: https://developer.android.com/media/camera/camerax/architecture
- Servicios de cámara Android: https://developer.android.com/develop/background-work/services/fgs/service-types
- Red local Apple: https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
- Firma en Actions: https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications
- iPad Air M4: https://support.apple.com/es-es/126472

El usuario indicó como referencia observada el 21 de octubre de 2026 `flutter_webrtc 1.6.2+hotfix.4`. **Es una referencia aportada; su compatibilidad no se ha comprobado ni esa dependencia está añadida al proyecto.** Comprobar antes de fijarla.

Consultar documentación adicional solo ante una implementación o incompatibilidad concreta.

## 18. Entrevista obligatoria

Antes del desarrollo definitivo, entrevistar con preguntas específicas de ingeniería y producto; no repetir el propósito de la aplicación ni preguntar genéricamente qué se quiere hacer.

Ámbitos a aclarar:

- Uso en tapiz: soporte del iPad, operador, reproducción automática/manual, retorno al directo, duración de movimientos y anotaciones durante captura o revisión.
- Android, distancias, red, conexión y prioridad entre resolución, FPS y fluidez.
- Línea temporal común, retardo, bucles, comparación histórica y sincronización manual.
- Tipo de lápiz, herramientas, comportamiento temporal y medición de ángulos.
- Organización por conjuntos, personas, habilidades y sesiones.
- Mediciones biomecánicas útiles, movimientos prioritarios y errores técnicos reales, sin limitarse a preguntar por IA.
- Navegación, cámaras, barras, colores, oscuro, ventanas y lápiz; proponer comparaciones visuales si ayudan.
- Permisos, certificado, repositorio, pruebas, versiones y compilación.

Primera ronda decisiva y agrupada. Profundizar donde haya ambigüedad, proponer opciones con consecuencias, diferenciar lo imprescindible de preferencias reversibles y evitar preguntas superficiales. Empezar el desarrollo cuando haya información suficiente. Preguntar después cuando aparezcan decisiones relevantes. Conservar las respuestas para no repetirlas.

El usuario participa activamente en el diseño, no delega el producto para desentenderse de él.

## 19. Trabajo real en ChatGPT Work

Tras las preguntas: resumen breve de requisitos y pendientes; preparar proyecto y repositorio privado con las conexiones disponibles sin alterar repositorios ajenos; configurar entorno; primera funcionalidad mínima ejecutable, preferiblemente cámara local de iPad o captura/visualización compartida; incorporar comunicación y segundo dispositivo; replay y anotación; compilar, probar y corregir.

No emplear trabajo desproporcionado en planes y diagramas previos. Arquitectura breve y actualizada. Entregas comprobables. Ante bloqueo, explicarlo y continuar por partes independientes. No decir que APK/IPA está listo sin el artefacto. Pedir autorización antes de acciones externas sensibles, compras, publicación pública, cambios de permisos o uso de certificados privados.

El 21 de octubre, posteriormente, el usuario solicita expresamente documentación contextual extensa y subida al repositorio privado que ha creado manualmente. Esta ampliación explica el volumen del paquete contextual actual.

## 20. Estándares de calidad

No crear una demostración atractiva pero frágil. Evitar soluciones provisionales que obliguen a rehacerlo todo; reutilizar componentes; documentar errores significativos; no ocultar límites; validar permisos y compatibilidad; evitar consumo innecesario de memoria; optimizar transmisiones; diseñar error/recuperación; automatizar pruebas; mantener fluidez; priorizar estabilidad sobre decoración; evitar Internet innecesario; código legible; separar experimental de estable; no confundir simulación e implementación.

Las herramientas futuras deben integrarse en la arquitectura existente y no formar módulos incompatibles difíciles de mantener.

## 21. Colaboración

Comunicarse en español, con precisión técnica y criterio exigente. No repetir conceptos elementales; justificar decisiones importantes y consecuencias. No dar siempre la razón: proponer mejoras con motivos. No descartar funciones solo por difíciles.

Distinguir imposibilidad comprobada, limitación de plataforma, incompatibilidad, problema de rendimiento, dificultad de implementación y falta de pruebas.

El usuario acepta dedicar tiempo a probar, aportar errores y registros y participar. Esa disponibilidad no sustituye las pruebas del desarrollo. Al terminar una entrega, resumir implementación, pruebas, pendientes y siguiente paso técnico.

## 22. Instrucción para la primera respuesta y continuidad

Confirmar propósito e iPad como cámara; identificar solo decisiones que falten; entrevistar con preguntas profundas y concretas; profundizar en respuestas relevantes; una vez aclarado lo imprescindible, crear el proyecto real.

Prioridad absoluta: cámara de iPad, cámara Android recibida, ambas capturas continuas, revisión de ejecuciones y anotación precisa, compartiendo interfaz.

El nombre es definitivo. Construir progresivamente, con ambición, criterio y detalle, una herramienta que merezca usarse en entrenamiento de gimnasia acrobática.

## Nota de fidelidad y precedencia

Esta es una conservación extensa del contenido del encargo, **no una transcripción literal del mensaje completo ni una certificación de viabilidad técnica**. Las aclaraciones editoriales identifican decisiones posteriores y previenen confundir objetivos con implementación. Para continuar, contrastar este encargo con la entrevista, la matriz de requisitos, las evidencias y el código. Ante duda sustancial, consultar al usuario sin repetir decisiones ya resueltas.
