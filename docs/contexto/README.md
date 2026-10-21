# Paquete de continuidad — AcroStella Analytics

Este directorio permite continuar el desarrollo desde otro entorno o conversación sin perder el encargo, las respuestas del usuario ni la distinción entre objetivos y resultados. El usuario solicitó expresamente contexto extenso para trasladar el trabajo a ChatGPT Work Cloud y su subida al repositorio privado.

**Conversación y evidencia inicial:** 21 de octubre de 2026, Europe/Madrid. **Paquete completado:** 22 de octubre de 2026. **Producto:** AcroStella Analytics. **Repositorio:** [tecnofifamobile-ai/AcroStella-Analytics](https://github.com/tecnofifamobile-ai/AcroStella-Analytics).

## Lectura recomendada

| Archivo | Contenido | Cuándo leerlo |
| --- | --- | --- |
| [06-continuar-en-cloud.md](06-continuar-en-cloud.md) | Punto de entrada, prompt de continuidad y acciones concretas | Primero al retomar |
| [05-estado-y-evidencias.md](05-estado-y-evidencias.md) | Qué existe, qué se ejecutó y qué no se ha comprobado | Antes de describir el estado |
| [02-entrevista-y-decisiones.md](02-entrevista-y-decisiones.md) | Respuestas literales, decisiones y preguntas abiertas | Antes de preguntar al usuario |
| [01-encargo-maestro.md](01-encargo-maestro.md) | Conservación extensa del encargo inicial | Para entender todo el alcance |
| [03-especificacion-funcional.md](03-especificacion-funcional.md) | Flujos, estados y aceptación del MVP | Al implementar una función |
| [04-arquitectura-y-pendientes.md](04-arquitectura-y-pendientes.md) | Código actual, contratos, decisiones y riesgos concretos | Antes de cámara, transporte y replay |
| [07-matriz-de-requisitos.md](07-matriz-de-requisitos.md) | Trazabilidad de requisitos y estado | Al cerrar un hito |
| [08-pruebas-fisicas.md](08-pruebas-fisicas.md) | Procedimientos y plantillas de medición sin cifras inventadas | Al instalar en dispositivos |
| [estado.json](estado.json) | Resumen estructurado para automatización | Como índice, no como prueba |

## Reglas de interpretación

- El encargo maestro define el producto deseado; no prueba que exista.
- La entrevista concreta las elecciones del usuario y separa lo no respondido.
- La especificación funcional contiene propuestas de comportamiento cuando lo indica; no atribuirlas al usuario.
- La evidencia corresponde a una revisión y un entorno determinados. Volver a medir después de cambios relevantes.
- Las pruebas de componentes y lógica usan dispositivos falsos dentro de tests. La aplicación no muestra cámaras simuladas.
- Los estados de CI deben comprobarse en GitHub; tener un YAML no equivale a una ejecución correcta.
- Los documentos extensos son contexto del traspaso. La continuación debe centrarse en entregas reales, sin reiniciar la definición del producto.

## Autoridad y actualización

Las instrucciones actuales del usuario prevalecen sobre estas notas históricas. Al detectar discrepancias, contrastar entrevista, código, commits y resultados. Registrar decisiones nuevas sin borrar el origen de las antiguas. Las reglas operativas para agentes están en [AGENTS.md](../../AGENTS.md).

No se incluyen certificados, perfiles, contraseñas, grabaciones reales, cachés del SDK ni el APK pesado en Git. El primer APK queda en el equipo local; CI puede generar artefactos cuando su compilación termine correctamente. La ubicación local no implica que un entorno Cloud tenga ese archivo.
