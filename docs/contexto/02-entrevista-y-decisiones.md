# Entrevista, respuestas y decisiones

Fecha de la conversación fuente: 21 de octubre de 2026, zona Europe/Madrid. Se conservan respuestas literales del usuario y, por separado, su interpretación operativa. No convertir una pregunta no contestada en una decisión.

## 1. Primera ronda: preguntas planteadas

1. **Manejo del iPad durante un ejercicio.** Trípode, sostenido por el entrenador o por otra persona; posible visualización de los gimnastas a distancia. Motivo: ergonomía, tamaño de controles y evitar mover la cámara.
2. **Retardo automático.** Distinguir imagen continuamente retrasada de una reproducción de la última ejecución después de terminar. Se preguntó por un botón para repetir los últimos segundos, duración habitual del elemento y espera entre intentos.
3. **Android y red real.** Modelo, versión, router del gimnasio o punto de acceso propio, distancia, obstáculos y alimentación.
4. **Prioridades de calidad.** Orden entre fluidez, detalle y retraso; importancia de posiciones breves frente a ampliación; necesidad de sonido.
5. **Comportamiento al pausar y cambiar de cámara.** Se propuso mantener un instante compartido de revisión y corregir manualmente el desfase; se preguntó por calibración con una señal.
6. **Lápiz y anotaciones.** Tipo de lápiz, dos primeras herramientas, persistencia del dibujo por fotograma o intervalo, y recolocación de puntos de un ángulo.
7. **Guardado y búsqueda.** Guardar ambos ángulos o solo el seleccionado, margen antes/después del elemento, etiquetas mínimas y duración de la sesión.
8. **Primera entrega y distribución.** Repositorio y cuenta, extensiones de firma sin solicitar secretos, disposición visual y disponibilidad para probar compilaciones.

## 2. Respuesta inicial literal del usuario

> El iPad lo pondré apoyado en alguna superficie seguramente o en algún trípode, puede incluso ser sostenido por alguna persona.
>
> El retardo automático quiero después del elemento al finalizarlo y darle a dejar de grabar por ejemplo poder ver ambos vídeos de manera sincronizada en mi pantalla de 13 pulgadas y que estén enlazados sin retardo.
>
> Un Samsung S24 Ultra, a lo mejor un red mi note 17 pro o algo así y ya. Usaría un punto de acceso propio desde el s24 seguramente y la distancia varía pero obstáculos son 0 literalmente.
>
> Poco retraso entre vídeos y estaría bastante importante poder ampliar detalles. Prioriza todo en general.
>
> No entiendo lo que preguntas en el 5
>
> Asimismo, para dibujar tu elegirás si quieres que se mantenga por x segundos y tengo un Pencil genérico pero que funciona bien y tiene Palm rejection etc.
>
> No sé xd
>
> No existe pero puedes crearlo y los certificados son mobileprovisiom y p12

La frase «No sé xd» no especifica a qué subpregunta responde. No utilizarla como consentimiento a una arquitectura concreta, duración de retención, taxonomía de biblioteca ni política de almacenamiento.

## 3. Aclaraciones del asistente antes de la segunda ronda

- La pregunta de sincronización se explicó con una recepción: ambos ángulos deben mostrar la misma fase; al avanzar, deben hacerlo juntos. La precisión alcanzable se medirá.
- «Dejar de grabar» se reinterpretó como terminar **el intervalo seleccionado**, sin apagar las cámaras ni perder la captura siguiente. Se pidió confirmar el flujo.
- No se solicitaron certificados. Conocer las extensiones no confirma firma ni aprovisionamiento.

## 4. Segunda ronda: elecciones exactas

### Delimitación de una ejecución

Pregunta: «¿Qué secuencia prefieres para registrar y revisar un elemento? En ambas opciones las cámaras siguen capturando durante la revisión.»

Alternativas:

1. Pulsar «Iniciar ejecución» antes y «Revisar» al terminar para abrir ese intervalo de ambas cámaras.
2. Pulsar al terminar «Revisar últimos 15 segundos», con duración ajustable.

Respuesta elegida por el usuario:

> Pulso «Iniciar ejecución» antes del elemento y «Revisar» al terminar; se abre ese intervalo de ambas cámaras.

**Decisión D-01:** comienzo y fin explícitos de la ejecución. No desarrollar como flujo inicial exclusivo un directo siempre retrasado. Marcar el final no equivale a detener la captura nativa.

### Ángulos guardados y vista inicial

Pregunta: «Propongo guardar ambos ángulos juntos, con fecha automática y nombre opcional, y mostrarlos inicialmente a partes iguales. ¿Te sirve para empezar?»

Respuesta elegida:

> Sí, ambos ángulos y vista mitad y mitad.

**Decisión D-02:** una ejecución agrupa ambos ángulos; fecha automática; nombre opcional. **Decisión D-03:** primera disposición con dos áreas iguales. Es una elección inicial, compatible con ampliar una vista después.

### Sonido y versión del dispositivo

Pregunta: «¿Necesitas sonido en las ejecuciones desde la primera versión? Si conoces también la versión de Android del S24 Ultra, puedes escribirla en tu respuesta.»

Respuesta literal:

> Tengo la versión de android com oneuiv8.5

**Hecho H-01:** el usuario comunica One UI 8.5. **No confirma la versión base de Android. No responde a la pregunta de audio.**

El asistente comunicó una decisión de alcance del primer incremento: prueba de cámara sin audio ni solicitud de micrófono. No registrarla como preferencia permanente del usuario. Si el audio pasa a condicionar la siguiente implementación, aclararlo entonces.

## 5. Información consolidada que no debe volver a preguntarse

| Asunto | Información confirmada | Límite de lo conocido |
| --- | --- | --- |
| Nombre | AcroStella Analytics | Definitivo |
| iPad | Air 13 pulgadas, M4, iPadOS inicial declarado 27.0.1 | Sin comprobación física independiente |
| Papel del iPad | Centro de análisis y cámara propia esencial | No reducirlo a monitor |
| Soporte | Superficie, trípode o persona | No fijar un único montaje obligatorio |
| Android inicial | Samsung S24 Ultra | Android base aún sin verificar |
| Software Samsung | One UI 8.5, según usuario | No deducir versión de Android |
| Segundo Android | Quizá Redmi Note 17 Pro o similar | Modelo tentativo, no confirmado |
| Red | Probablemente hotspot del S24 | Conectividad anfitrión-cliente sin verificar |
| Escena | Sin obstáculos; distancias variables | No inventar metros |
| Prioridades | Poco desfase entre vídeos y ampliación de detalles | Sin orden absoluto entre bitrate, FPS y latencia |
| Revisión | Iniciar antes; Revisar después | Capturas continúan |
| Pantalla inicial | Dos vistas iguales | Ampliación posterior permitida |
| Guardado | Ambos ángulos juntos; fecha automática; nombre opcional | Retención y organización fina pendientes |
| Lápiz | Genérico con rechazo de palma según usuario | Presión, inclinación y latencia no probadas |
| Anotaciones | Elegir duración de persistencia en segundos | Herramientas iniciales concretas aún abiertas |
| Firma | Archivos .p12 y .mobileprovision disponibles | No leídos ni validados |
| Mac | No tiene Mac físico | Usar CI macOS para compilar |
| Repositorio | Lo creó manualmente después de la primera entrega | Confirmado privado por GitHub |

## 6. Migración del trabajo a Cloud

Pregunta del usuario:

> Hay forma de pasar esto a chatgpt cloud

Se explicó que Cloud requiere recibir código y contexto, que la carpeta local no se transfiere automáticamente y que se puede continuar en una nueva tarea con GitHub o ZIP. Se indicó que la compilación Apple puede seguir en GitHub Actions y las pruebas físicas necesitan sus dispositivos.

Nueva instrucción literal:

> De acuerdo, prepara tambien archivos contextuales de gran magnitud con la informacion que te proporcione y respondi y sub elos al github ya de acrostella analytics que lo cree manualmente

**Decisión D-04:** preparar contexto amplio y subirlo junto al código al repositorio creado manualmente. Esto autoriza esa subida al repositorio privado. No autoriza subir certificados, grabaciones reales, crear cuentas nuevas, comprar servicios ni publicar el repositorio.

Destino confirmado: `https://github.com/tecnofifamobile-ai/AcroStella-Analytics`, rama predeterminada `main`.

## 7. Ambigüedades que siguen abiertas

- Audio: pendiente, con prueba local inicial sin audio.
- Duración típica del elemento, intervalo entre intentos y duración de la sesión: pendientes.
- Cuota de almacenamiento, tiempo de retención y comportamiento ante falta de espacio: pendientes de propuesta y validación.
- Calibración: aceptable como posibilidad del encargo; el usuario no ha elegido aún palmada frente a señal visual ni un procedimiento concreto.
- Error máximo de alineación entre cámaras: no se ha cuantificado. «Sin retardo» expresa una experiencia deseada, no una garantía física de cero milisegundos.
- Red: sin medición de ancho de banda, aislamiento de clientes, estabilidad o límite térmico del hotspot.
- Herramientas exactas y comportamiento por fotograma: el usuario eligió persistencia temporal configurable; no todas las opciones de dibujo quedaron resueltas.
- Tipo de usuario inicial, nombres de grupos y habilidades reales: aún no aportados.
- Aspectos organizativos del club y consentimiento: a tratar antes de implantación, sin solicitar datos de menores para desarrollar.

No detener trabajos independientes por estas preferencias. Resolverlas cuando afecten a una entrega concreta, con preguntas breves y específicas.

## 8. Interpretaciones que deben evitarse

1. «Prioriza todo» no elimina límites de red, codificación o calor. Proponer perfiles y medirlos.
2. «Dejar de grabar» no contradice ya la captura continua: se aclaró y eligió delimitar una ejecución.
3. «Pencil genérico» no significa Apple Pencil oficial ni permite prometer características de PencilKit.
4. «One UI 8.5» no basta para fijar permisos por una supuesta versión de Android.
5. «Tengo certificado» no confirma perfil compatible, capacidades, instalación ni ejecución.
6. Repositorio privado accesible no significa entorno Cloud ya creado ni conversación migrada.
7. Preferencia por contexto extenso en este traspaso no sustituye la preferencia general por desarrollo real y documentación proporcionada.
