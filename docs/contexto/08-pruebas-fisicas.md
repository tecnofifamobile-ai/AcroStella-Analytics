# Pruebas físicas y registro de mediciones

**Estado inicial: ninguna prueba física registrada.** Este documento proporciona procedimientos y campos vacíos; no contiene resultados simulados.

## 1. Identificación mínima de una prueba

Registrar fecha y zona horaria, commit, versión/build, origen del artefacto, dispositivo/modelo, versión del sistema, configuración de cámara, alimentación, estado térmico inicial y pasos reproducidos. Para red: hotspot/router, banda si se conoce, distancia medida, obstáculos y dispositivos participantes.

Usar escena sintética, objetos o material autorizado. No pedir imágenes de menores para diagnosticar permisos o apertura. Los registros técnicos no deben contener contraseñas, tokens, perfiles ni datos personales innecesarios.

## 2. Primera prueba: Android local 0.1.0

1. Instalar el APK de depuración conocido y registrar su origen/hash.
2. Abrir sin pulsar Activar y verificar que no se pide cámara prematuramente.
3. Activar y autorizar cámara. Confirmar que es la trasera y que la imagen cambia en tiempo real.
4. Girar vertical/horizontal; ampliar vista; volver a dos paneles; cambiar tema.
5. Observar deformación, recortes, saltos o congelación. Un test de widgets no cubre esto.
6. Desactivar/reactivar. Salir y volver. Denegar permisos y recuperarlos desde Ajustes.
7. Registrar errores textuales y, si se necesita, logs técnicos autorizados.

No intentar validar replay, guardado ni multicámara: no existen en esta versión.

## 3. Primera prueba iPad

Antes de empezar, confirmar por separado build, procedimiento de firma autorizado, perfil compatible y artefacto instalado. Un ZIP de `Runner.app` sin firma no sirve como prueba de instalación.

Repetir las comprobaciones locales, registrar el iPadOS real y contrastarlo con el inicial declarado. Comprobar el lápiz genérico cuando haya dibujo; no inventar soporte de presión o rechazo de palma a partir del modelo de app.

## 4. Pruebas cuando exista multicámara y replay

- Probar S24 como cámara y hotspot a la vez, sin Internet.
- Delimitar un elemento con los dos controles acordados.
- Durante revisión mover un objeto visible: confirmar después que se conservó esa parte nueva en ambas cámaras.
- Cambiar distribución y ángulo sin reiniciar fuente.
- Cortar la conexión de una remota y comprobar aviso/continuidad local; reconectar y revisar huecos temporales.
- Marcar un evento común para estimar desfase; repetir más tarde para detectar deriva.
- Alcanzar límites de retención y comprobar lectura de una ejecución fijada.
- Guardar, cerrar y reabrir ambos ángulos y anotaciones.
- Empezar con sesiones cortas y aumentar duración solo con resultados registrados. La duración representativa de entrenamiento está por preguntar.

## 5. Plantilla de resultado — copiar por prueba

```text
ID de prueba:
Fecha y zona:
Commit / versión / build:
Origen y hash del artefacto:
Dispositivos y sistemas:
Escena sintética/autorizada:
Alimentación y condiciones térmicas:
Red y distancias:
Perfil solicitado:
Resolución observada:
Duración real de la prueba:
Pasos ejecutados:
Resultado observado:
Errores e interrupciones:
FPS medidos / método / intervalo:
Latencia medida / definición / método:
Desfase entre fuentes / método / incertidumbre:
Memoria / herramienta / intervalo:
Almacenamiento temporal / herramienta / intervalo:
Estabilidad y recuperación:
Evidencia técnica adjunta:
Limitaciones del resultado:
Próximo cambio o repetición justificada:
```

Dejar «sin medir» en campos sin instrumentación. No sustituir FPS reales por `fps: 30` solicitado, ni latencia por intuición, ni memoria por una estimación teórica de bitrate.

## 6. Interpretación

Una instalación correcta no demuestra replay continuo. Una red rápida no demuestra sincronización. Un dibujo alineado en una vista no prueba su persistencia al girar o ampliar. Una sesión corta estable no demuestra duración de entrenamiento. Mantener cada afirmación unida a su procedimiento y evidencia.
