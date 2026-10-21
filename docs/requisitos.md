# AcroStella Analytics — requisitos acordados

Fuente: entrevista del proyecto, 21 de octubre de 2026. Este archivo distingue respuestas confirmadas de propuestas pendientes.

## Confirmado

- Producto local de análisis de gimnasia acrobática, con interfaz compartida Flutter/Dart y adaptadores nativos cuando se necesiten.
- El iPad Air de 13 pulgadas M4 es centro de análisis y cámara; debe poder funcionar solo.
- La captura de todas las fuentes continúa durante la revisión y los cambios de vista.
- El iPad puede apoyarse en una superficie, instalarse en un trípode o sostenerse en la mano.
- Primera cámara Android: Samsung S24 Ultra. Segundo Android tentativo: un Redmi cuyo modelo exacto no está confirmado.
- Red prevista: punto de acceso del propio S24 Ultra, sin obstáculos; distancia variable. Debe verificarse la comunicación entre el móvil anfitrión y el iPad.
- Se priorizan el poco desfase entre vídeos y el detalle para ampliar. La combinación de resolución, frecuencia y latencia está pendiente de mediciones reales.
- Al terminar un elemento, el entrenador quiere pulsar un control y revisar ambos vídeos sincronizados en el iPad.
- Flujo confirmado: «Iniciar ejecución» antes del elemento y «Revisar» al terminar; ambos controles delimitan el intervalo sin detener las capturas.
- Guardado confirmado: ambos ángulos juntos, fecha automática y nombre opcional.
- Distribución inicial confirmada: dos cámaras a partes iguales.
- El S24 Ultra utiliza One UI 8.5 según el usuario; versión de Android aún sin verificar.
- Las anotaciones deben poder mantenerse durante un intervalo configurable.
- El usuario dispone de un lápiz genérico que, según indica, tiene rechazo de palma. No se presupone soporte de presión ni capacidades de Apple Pencil oficiales.
- Biblioteca y organización: sin preferencia decidida; evitar campos obligatorios innecesarios.
- No existe repositorio del proyecto. El usuario autoriza crear un repositorio privado.
- Se dispone de archivos de firma con extensiones .p12 y .mobileprovision; compatibilidad, capacidades y firma sin comprobar.
- No subir grabaciones por defecto ni incluirlas en Git. No utilizar archivos de firma ni enviarlos a servicios sin autorización explícita.
- MVP: captura local de iPad y remota Android, vista de ambas fuentes, búfer temporal limitado, revisión independiente, pausa y avance por fotogramas, líneas/ángulos, guardado y reapertura.
- Registrar por separado implementación, compilación, pruebas automatizadas y pruebas físicas; no atribuir cifras de rendimiento sin medirlas.

## Pendiente de respuesta

- Necesidad de audio en la primera entrega.

## Pendiente para pruebas o fases posteriores

- Versión de Android del S24 Ultra, modelo real del segundo Android y distancias habituales.
- Duración típica del elemento y de la sesión; política de retención y presupuesto de almacenamiento.
- Precisión temporal alcanzable, compatibilidad del punto de acceso, recuperación de conexión y rendimiento térmico.
- Herramientas de dibujo prioritarias, respuesta real del lápiz, estilo visual y organización definitiva de la biblioteca.
- Mediciones biomecánicas concretas, fuera del primer hito.
- Validación de compilación iPadOS en macOS CI y, después, procedimiento de firma e instalación.
