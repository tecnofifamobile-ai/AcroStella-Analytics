# Matriz de requisitos y trazabilidad

Fotografía del primer incremento y del encargo de continuidad. Estado «código» no equivale a «verificado físicamente». El objetivo del MVP completo sigue pendiente.

Leyenda: **Base** = presente en el incremento; **Automático** = existe prueba de lógica/interfaz; **Compilado** = build real; **Pendiente** = no implementado/validado; **Futuro** = posterior al MVP; **Decidido** = requisito confirmado, no código.

## 1. Producto, plataformas y modos

| ID | Requisito | Prioridad | Estado/evidencia |
| --- | --- | --- | --- |
| PROD-01 | Nombre AcroStella Analytics | Fijo | Decidido y usado en app |
| PROD-02 | Interfaz Flutter/Dart compartida | Base | Proyecto Android/iOS existente |
| PROD-03 | iPad como cámara y centro | MVP | Preview local en código; prueba física pendiente |
| PROD-04 | iPad autónomo sin Android | MVP | Preview local disponible; flujo completo pendiente |
| PROD-05 | Android como cámara | MVP | Preview local en código; transmisión pendiente |
| PROD-06 | Android como centro de análisis futuro | Extensibilidad | Arquitectura no debe excluirlo |
| PROD-07 | Adaptación tablet/móvil y giro | Base | Automático en tres tamaños; giro físico pendiente |
| PROD-08 | Modos Entrenador/Cámara/Análisis | Progresivo | Pantalla de prueba local; modos completos pendientes |
| PROD-09 | Modo claro y oscuro | Base | Implementado; cambios ejercitados en tests |
| PROD-10 | Paneles ocultables y foco en vídeo | Progresivo | Ampliación de vista local; resto pendiente |

## 2. Captura y transporte

| ID | Requisito | Prioridad | Estado/evidencia |
| --- | --- | --- | --- |
| CAP-01 | Cámara trasera iPad con preview | MVP | Código y compilación iOS sin firma; hardware pendiente |
| CAP-02 | Cámara trasera Android con preview | Base | Código y APK local compilado; hardware pendiente |
| CAP-03 | Un propietario por cámara | Estructural | `CaptureSession`; concurrencia probada con fake |
| CAP-04 | Cambio de distribución no detiene captura | MVP | Propietario conservado en test; hardware pendiente |
| CAP-05 | Captura continúa durante revisión | MVP | Pendiente; no hay replay aún |
| CAP-06 | Dos fuentes simultáneas | MVP | Pendiente; segundo panel informativo |
| CAP-07 | Tercera fuente Android | Posterior | Pendiente |
| CAP-08 | Lentes, enfoque, exposición y calidad | Progresivo | Perfil inicial fijo; controles pendientes |
| CAP-09 | Controlar permisos y ciclo de vida | Base | Implementado y probado con fake; hardware pendiente |
| CAP-10 | Audio configurable | Abierto | Usuario no contestó; prueba sin audio |
| CAP-11 | Derivación nativa sin duplicar cámara/encoder | Estructural | Investigación concreta pendiente |
| NET-01 | WebRTC en red local sin Internet | MVP | Pendiente; dependencia sin añadir |
| NET-02 | Emparejamiento por código/QR | MVP | Pendiente |
| NET-03 | Descubrimiento y alternativa manual | MVP | Pendiente |
| NET-04 | Identidad autorizada persistente | MVP | Pendiente |
| NET-05 | Control permitido desde centro | Progresivo | Pendiente |
| NET-06 | Mostrar conexión, latencia y fallo | MVP | Pendiente para remoto |
| NET-07 | Reconexión sin detener otras cámaras | MVP | Pendiente |
| NET-08 | Diagnóstico de conectividad/aislamiento | MVP | Pendiente; no asumir causa por un timeout |
| NET-09 | Hotspot del S24 como red y cámara | Prueba esencial | Escenario confirmado; sin prueba física |

## 3. Temporalidad, revisión y almacenamiento temporal

| ID | Requisito | Prioridad | Estado/evidencia |
| --- | --- | --- | --- |
| TIME-01 | Línea temporal común | MVP | Pendiente |
| TIME-02 | Separar captura, fuente, recepción y reproducción | Estructural | Requisito documentado; pendiente |
| TIME-03 | Estimar desfase/deriva e incertidumbre | MVP/progresivo | Pendiente |
| TIME-04 | Corrección manual de sincronización | MVP | Pendiente |
| TIME-05 | Calibración por evento reconocible | Progresivo | Procedimiento no elegido |
| TIME-06 | Detectar desviaciones y huecos | Robustez | Pendiente |
| BUF-01 | Vídeo comprimido temporal de cada cámara | MVP | Pendiente |
| BUF-02 | Retención limitada por tiempo y bytes | MVP | Pendiente; cuota sin elegir |
| BUF-03 | Opciones 5/10/15/30/60 s según soporte | Progresivo | Candidatas del encargo, sin validar |
| BUF-04 | Revisar sin borrar segmentos en uso | MVP | Propuesta técnica; pendiente |
| BUF-05 | Gestionar falta de espacio y recuperación | MVP | Pendiente |
| REV-01 | Iniciar ejecución antes, Revisar después | MVP | Decidido por usuario; sin implementar |
| REV-02 | Abrir intervalo de ambos ángulos | MVP | Pendiente |
| REV-03 | Vista mitad y mitad | MVP | Decidida; contenedor visual base |
| REV-04 | Cursor enlazado entre ángulos | MVP | Pendiente |
| REV-05 | Pausa y fotograma siguiente | MVP | Pendiente |
| REV-06 | Fotograma anterior | Progresivo | Pendiente |
| REV-07 | Cámara lenta | Progresivo | Pendiente |
| REV-08 | Retorno inmediato al directo | MVP | Pendiente |
| REV-09 | Bucle entre marcadores | Progresivo | Pendiente |
| REV-10 | Retardo automático configurable | Progresivo | Pendiente; no confundir con flujo inicial elegido |
| REV-11 | Guardar últimos segundos | Progresivo | Pendiente |
| REV-12 | Ventanas flotantes, etiquetas y reorganización | Progresivo | Pendiente |

## 4. Anotaciones, reproductor y biblioteca

| ID | Requisito | Prioridad | Estado/evidencia |
| --- | --- | --- | --- |
| ANN-01 | Dibujar línea o ángulo | MVP | Pendiente |
| ANN-02 | Duración de anotación configurable | MVP | Decidida; sin implementar |
| ANN-03 | Asociación a cámara/fotograma/intervalo | MVP | Pendiente |
| ANN-04 | Coordenadas normalizadas y transformaciones | Estructural | Pendiente |
| ANN-05 | Dibujo libre, formas, flechas y texto | Progresivo | Pendiente |
| ANN-06 | Selección/movimiento y deshacer/rehacer | Progresivo | Pendiente |
| ANN-07 | Comparar Flutter y PencilKit en hardware | Evaluación | Pendiente; no elegir por suposición |
| ANN-08 | Lápiz genérico y gestos sin interferencias | Prueba esencial | Dispositivo declarado; sin validar |
| ANN-09 | Ángulos, alineaciones y referencias | Progresivo | Pendiente |
| ANN-10 | Trayectorias y distancias calibradas | Posterior | Pendiente |
| LIB-01 | Guardar ejecución con ambos ángulos | MVP | Decidido; sin persistencia |
| LIB-02 | Fecha automática y nombre opcional | MVP | Decidido; sin implementar |
| LIB-03 | Reabrir vídeo y anotaciones | MVP | Pendiente |
| LIB-04 | SQLite y archivos locales | Arquitectura | Tecnología de referencia; sin añadir |
| LIB-05 | Club/grupos/sesiones/ejercicios/análisis | Progresivo | Modelo conceptual; detalles abiertos |
| LIB-06 | Habilidades, etiquetas, favoritos e historial | Posterior | Pendiente |
| PLAY-01 | Importar desde Fotos/Archivos | Progresivo | Pendiente |
| PLAY-02 | Comparación lado a lado de importados | Progresivo | Pendiente |
| PLAY-03 | Superposición con transparencia/escala | Posterior | Pendiente |
| PLAY-04 | Tiempo y número de fotograma cuando se conozca | Progresivo | Pendiente |
| EXP-01 | Original intacto y anotaciones no destructivas | Estructural | Requisito; sin exportador |
| EXP-02 | Exportar copia anotada | Posterior | Pendiente |
| EXP-03 | Narración e informes | Futuro | Pendiente |

## 5. Privacidad, rendimiento, pruebas y distribución

| ID | Requisito | Prioridad | Estado/evidencia |
| --- | --- | --- | --- |
| PRIV-01 | Sin cuentas, telemetría ni subidas por defecto | Fijo | Ninguno de esos servicios en el código inicial |
| PRIV-02 | No versionar secretos ni vídeos reales | Fijo | Exclusiones y revisión de archivos; ningún material real añadido |
| PRIV-03 | Firma solo con autorización específica | Fijo | No se han utilizado certificados |
| PRIV-04 | Retención/eliminación/exportación explícitas | Progresivo | Pendiente de persistencia |
| PRIV-05 | Protección local de grabaciones | Progresivo | Pendiente; todavía no hay grabaciones |
| PRIV-06 | Consentimiento y organización del club | Antes de implantación | Pendiente; sin afirmación legal de cumplimiento |
| PERF-01 | Perfiles realistas 720p/1080p30 | MVP | Perfil pedido 1080p30; capacidad sin medir |
| PERF-02 | Medir FPS, latencia, memoria y estabilidad | MVP | Pendiente de hardware e instrumentación |
| PERF-03 | Evitar RAM cruda indefinida | Fijo | No existe búfer; condición para implementarlo |
| PERF-04 | Sesiones de duración creciente | Aceptación | Pendiente |
| TEST-01 | Concurrencia y ciclo de cámara | Base | Ocho casos unitarios con fake |
| TEST-02 | Componentes y disposición | Base | Cuatro casos de interfaz |
| TEST-03 | Temporalidad, búfer y anotaciones | Al implementarlos | Sin tests porque no existen todavía |
| TEST-04 | Desconexiones remotas | Al implementar red | Pendiente |
| DIST-01 | Código privado en un repositorio | Base | Subido a `tecnofifamobile-ai/AcroStella-Analytics` |
| DIST-02 | APK real para pruebas | Base | Compilado localmente y en CI; artefacto publicado en Actions |
| DIST-03 | Build Apple sin Mac físico | Base | CI iOS sin firma confirmada |
| DIST-04 | Perfil, firma e IPA instalable | Próximo hito | Pendiente; no hay IPA instalable |
| DIST-05 | Instalación/ejecución en iPad | MVP | Sin prueba física |
| DIST-06 | Continuidad en Cloud | Traspaso | Contexto y fuentes preparados; tarea nueva aún no creada |
| BIO-01 | Pose/ángulos/trayectorias/velocidad | Futuro | No retrasar núcleo manual |
| BIO-02 | Incertidumbre, inversión y oclusiones | Fijo para IA futura | Sin modelo ni evaluación |
| BIO-03 | Reconstrucción 3D experimental | Futuro | Sin implementar ni prometer precisión |

## 6. Cierre del MVP

No dar el MVP por terminado por cerrar un subconjunto de filas. Deben verificarse físicamente las 13 capacidades del encargo y su combinación, especialmente revisión de dos ángulos mientras ambas capturas continúan. Mantener evidencias por revisión, dispositivo y duración de prueba.
