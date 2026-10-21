# Especificación funcional de continuidad

Esta especificación ordena los requisitos del encargo y las elecciones de la entrevista. Describe el comportamiento objetivo; **no presenta el MVP como terminado**. Las propuestas de implementación se señalan expresamente.

## 1. Escenario principal

El entrenador prepara el iPad Air M4 de 13 pulgadas de forma estable, aunque puede utilizarlo sostenido. La cámara trasera del iPad ve un ángulo del tapiz. Un Samsung S24 Ultra ve otro y probablemente ofrece además el punto de acceso Wi-Fi. No hay obstáculos declarados; la distancia no se ha cuantificado.

Ambos dispositivos deben poder trabajar sin Internet. El iPad debe seguir siendo útil sin Android. El Android remoto no es un sustituto de la cámara del iPad. Una futura segunda cámara Android se incorpora sin diseñar inicialmente para un modelo no confirmado.

La primera distribución de revisión tendrá dos imágenes de igual tamaño. Vertical y horizontal se admiten; horizontal es la orientación prioritaria del centro de análisis.

## 2. Flujo confirmado de una ejecución

1. Activar las fuentes disponibles y comprobar sus estados.
2. Pulsar **Iniciar ejecución** antes del movimiento.
3. Mantener la captura local y remota durante el elemento.
4. Pulsar **Revisar** al terminar.
5. Abrir el intervalo delimitado en ambos ángulos, con cursor temporal común.
6. Pausar, avanzar por fotogramas y cambiar o ampliar el ángulo sin detener la captura.
7. Dibujar una línea o medir un ángulo, con persistencia temporal seleccionable.
8. Guardar ambos ángulos como una ejecución, con fecha automática y nombre opcional.
9. Volver al directo con un control visible.
10. Recuperar después la ejecución y sus anotaciones.

El botón Revisar termina la selección de una ejecución; no debe ser la misma operación que cerrar la cámara nativa. El texto actual «Desactivar cámara» pertenece a la prueba local 0.1.0 y no implementa este flujo.

## 3. Estados separados

### Captura

Estado por fuente: sin activar, pidiendo/abriendo, activa, interrumpida/suspendida, error y cerrada. Para remotas habrá además descubrimiento, emparejamiento, conexión y reconexión. No sustituir estos estados por un único booleano `isRecording` compartido con el reproductor.

### Selección de ejecución

Propuesta técnica pendiente de implementación: sin selección, inicio marcado, intervalo delimitado, revisión y guardado. La selección guarda tiempos de sesión, no la identidad de un widget visible.

### Reproducción

Directo, revisión reproduciendo, revisión en pausa y retorno al directo. Modos posteriores: velocidad ajustable, bucle entre marcas y retardo configurable. La interfaz no debe mostrar como operativos controles todavía simulados.

### Persistencia

Contenido temporal sujeto a retención; selección pendiente de guardar; copia persistente; fallo de guardado; ejecución guardada y reabierta. No presentar el éxito antes de confirmar que existen medios reproducibles y metadatos coherentes.

Estos estados son una separación propuesta para cumplir el encargo, no una API ya construida.

## 4. Tiempo y sincronización

El deseo del usuario es ver vídeos enlazados, sin desfase perceptible entre ángulos. No se ha definido una tolerancia en milisegundos. Mantener distinción entre retraso de transporte y alineación temporal: una reproducción puede introducir espera para alinear cámaras sin que eso signifique que los fotogramas lleguen con latencia cero.

Cada fuente debe conservar sus tiempos de captura/origen y su relación estimada con la sesión. El cursor común se transforma a los tiempos de cada fuente usando compensación de desfase, deriva y corrección manual. Un hueco de datos no debe ocultarse repitiendo silenciosamente una imagen como si fuera nueva.

La calibración por palmada o señal visible es una posibilidad del encargo, aún sin procedimiento elegido. Registrar calidad/indeterminación de la alineación. No derivar precisión biomecánica absoluta de una coincidencia visual aproximada.

## 5. Búfer y límites

El sistema necesita conservar vídeo continuo reciente sin intervención de transferencia de archivos. Duraciones candidatas: 5, 10, 15, 30 y 60 segundos; el soporte debe confirmarse por perfil y hardware.

Propuestas necesarias para la implementación:

- Límite doble de duración y bytes, no solo un número de segmentos.
- Segmentos comprimidos y referencias temporales; no acumular imágenes crudas en RAM.
- Fijar temporalmente los segmentos utilizados por una revisión para impedir su borrado mientras se leen.
- Ante cuota agotada, fallar de forma explícita o reducir retención según la política acordada. No borrar grabaciones persistentes sin autorización.
- Definir qué ocurre cuando una ejecución dura más que la ventana temporal. No prometer recuperar un inicio que ya se ha eliminado.
- Separar borrado del búfer y eliminación de ejecuciones guardadas.

El usuario no ha establecido duración máxima de un elemento ni cuota. Antes de fijar una política irreversible, acordar el comportamiento con él; mientras tanto, diseñar límites configurables y pruebas con segmentos sintéticos.

## 6. Vídeo y calidad

Comenzar por 720p/1080p a 30 fps según mediciones. La prueba actual solicita 1080p y 30 fps, pero solo muestra dimensiones devueltas por el controlador; no mide FPS reales.

La ampliación de una vista no aumenta por sí sola el detalle capturado. La preferencia por ampliar detalles puede exigir más resolución/bitrate; la preferencia por poco retraso exige controlar cola, red y decodificación. Explicar estos compromisos con evidencia del S24 y el iPad, sin resolver «prioriza todo» con promesas incompatibles.

Evitar copias/codificaciones duplicadas. Reservar alta frecuencia 120/240 fps para captura local avanzada cuando se demuestre soporte.

## 7. Anotación

Primera capacidad del MVP: línea o ángulo. Las herramientas concretas prioritarias aún no se han elegido. El usuario sí quiere seleccionar cuánto permanece un dibujo en segundos.

Modelo propuesto: identificador, fuente/cámara, tipo, puntos normalizados, estilo, intervalo de sesión o fotograma y propiedades editables. Separar coordenadas de vídeo de píxeles de pantalla, márgenes, zoom y desplazamiento.

El ángulo de tres puntos es 2D proyectado: no anunciarlo como ángulo articular tridimensional. Mantener original de vídeo sin modificaciones destructivas. El historial de deshacer/rehacer debe operar sobre anotaciones, no sobre la captura.

El lápiz disponible es genérico. Comprobar realmente rechazo de palma, precisión y gestos en el iPad antes de elegir PencilKit. No convertir el lápiz en requisito para acciones que también pueden resolverse táctilmente.

## 8. Guardado y biblioteca

Una ejecución agrupa ambos ángulos. Fecha automática y nombre opcional están aceptados. No es necesario pedir al usuario club, grupo, habilidad, deportista, etiquetas y observaciones para permitir el primer guardado.

El modelo Club → Grupos → Sesiones → Ejercicios → Ejecuciones → Análisis es el horizonte del encargo, no una taxonomía totalmente decidida. SQLite y archivos locales son las tecnologías de referencia.

La reapertura debe restaurar asociación entre medios y anotaciones. Ante archivo ausente, informar de la fuente que falta y conservar metadatos recuperables. Exportación e importación posteriores deben ser explícitas, sin compartir automáticamente.

## 9. Desconexión y recuperación

Una desconexión remota no debe apagar la cámara local ni la otra fuente. Mostrar qué fuente está afectada. Diferenciar vídeo congelado, conexión perdida y reproducción pausada. Intentar reconectar un dispositivo autorizado según una política acotada, sin emparejar automáticamente equipos desconocidos.

Cuando falten segmentos de un ángulo en una ejecución, registrar el intervalo incompleto. La continuidad de los otros ángulos no demuestra que el ausente se haya recuperado. Definir y probar cómo se incorpora una reconexión a la línea temporal.

El hotspot del S24 puede comportarse de forma distinta de un router. Verificar comunicación entre anfitrión y cliente. Disponer de alternativa manual por dirección/QR si descubrimiento/multicast falla. Sin evidencia adicional, un fallo de conexión debe describirse como posible problema de conectividad o aislamiento, no como diagnóstico seguro de aislamiento.

## 10. Privacidad y operación

No hay cuentas ni servicios externos obligatorios en la primera aplicación. Cámara y micrófono se autorizan por separado y solo cuando se usan. El audio sigue abierto funcionalmente; la prueba inicial lo desactiva.

El modo remoto debe mostrar captura/conexión sin sugerir que está grabando persistentemente si solo transmite. El centro debe distinguir temporal de guardado. Retención y exportación deben ser comprensibles para un entrenador.

Antes de uso en club, tratar responsabilidades, consentimiento y acceso con los responsables adecuados, con fuentes actualizadas cuando se aborde esa fase. No insertar una afirmación legal genérica de cumplimiento.

## 11. Aceptación del MVP

| Prueba | Resultado necesario | Evidencia actual |
| --- | --- | --- |
| Cámara local del iPad | Directo real de la trasera | Código preparado; sin prueba física |
| Segundo ángulo | Android transmite continuamente al iPad | Pendiente |
| Selección | Inicio y fin delimitan el mismo intervalo | Pendiente |
| Revisión | Ambos vídeos siguen capturando mientras se revisa | Pendiente |
| Cambio visual | No reabre/detiene cámaras | Probado con cámara falsa, sin hardware |
| Sincronización | Comparación temporal y ajuste manual | Pendiente |
| Fotogramas | Pausa y avance verificables | Pendiente |
| Anotación | Línea/ángulo permanece correctamente al transformar vista | Pendiente |
| Guardado | Ambos ángulos y metadatos se guardan/reabren | Pendiente |
| Fallo remoto | Se comunica sin parar captura local | Pendiente |
| Retorno | Un control vuelve al directo actual | Pendiente |
| Retención | Se mantiene la cuota de almacenamiento temporal | Pendiente |

La compilación del primer APK no permite cerrar ninguno de los requisitos pendientes de esta tabla.
