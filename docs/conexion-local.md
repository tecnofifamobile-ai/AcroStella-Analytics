# Dos cámaras por red local — 0.5.0

Esta entrega coordina **grabaciones finitas** con el propietario de cámara existente en cada dispositivo. Transfiere el vídeo comprimido original del segundo ángulo al terminar y permite revisar y guardar los dos archivos como un ejercicio. No incorpora vídeo remoto en directo, WebRTC ni captura continua durante la revisión. No acumula imágenes sin comprimir en Dart.

## Usarlo

1. Instalar 0.5.0 en ambos dispositivos. Conectarlos a la misma Wi-Fi o conectar el iPad al hotspot del Android. Mantener ambas aplicaciones abiertas y las pantallas desbloqueadas.
2. En Android, abrir **Dispositivos → Usar como segunda cámara**. Se activa su cámara y aparecen los enlaces de la red local. Copiar o escribir en el iPad el enlace correspondiente a esa red; el código es privado para esa sesión.
3. En el iPad, abrir **Dispositivos**, introducir el enlace y pulsar **Conectar con Android**. Autorizar red local y cámara cuando lo solicite iPadOS. Un error de conexión no demuestra aislamiento del hotspot: comprobar dirección, permisos y red.
4. Volver a Captura. **Iniciar · dos ángulos** prepara ambos dispositivos y programa el comienzo con margen de 1,5 segundos. **Terminar ejercicio** finaliza los archivos y muestra el progreso de recepción. Esperar a que termine la transferencia.
5. La revisión abre los dos ángulos con controles comunes. Comprobar una palmada o recepción visible; si hace falta, utilizar **Alinear los dos ángulos**. Guardar conserva ambos juntos; eliminar retira ambos del iPad. La copia de seguridad del Android se conserva y se elimina desde su biblioteca.

Se puede trabajar con una sola cámara sin emparejamiento. El centro y la cámara son roles elegidos por el usuario; se han desarrollado para el flujo iPad + Android, pero no se deduce hardware físico de las pruebas con simulaciones.

## Sincronización y sus límites

Siete intercambios de cuatro timestamps estiman el desfase entre relojes monotónicos de control; se elige la muestra de menor ida y vuelta, descontando el procesamiento remoto. Se conserva la incertidumbre del intercambio y del intervalo anterior/posterior al inicio nativo. Esos timestamps **no miden exposición ni el primer PTS del archivo**. La alineación inicial es una estimación: la corrección visual es necesaria para comprobarla.

El desfase guardado transforma tiempo del vídeo primario a tiempo del secundario. La revisión limita la búsqueda al intervalo común, espera las búsquedas de ambos decodificadores antes de reproducir y aplica la misma velocidad. Consulta las posiciones conjuntamente cada 300 ms, descarta muestras de consulta lenta y corrige diferencias observadas superiores a 80 ms como máximo una vez por segundo. Si un decodificador informa buffering o error, se pausan ambos. Esto no garantiza presentación física simultánea, precisión de un fotograma ni cero milisegundos de error. Los pasos de 0,03 s son saltos de tiempo aproximados; el contador muestra milisegundos, no una medición de precisión biomecánica.

## Transferencia y recuperación

El enlace contiene un secreto aleatorio de 128 bits. Un intercambio de retos frescos deriva dos claves direccionales con HKDF-SHA256. Cada trama se autentica y cifra mediante AES-256-GCM, con secuencia comprobada y longitud limitada a 100 KiB. El secreto no se envía en claro por el socket ni se guarda en el repositorio. Un solo centro puede conectarse al anfitrión y los intentos de autenticación están limitados. Los enlaces aceptan exclusivamente direcciones IPv4 privadas o de enlace local (loopback para pruebas); no se utiliza nube, descubrimiento externo ni credenciales de GitHub.

El archivo viaja por bloques de hasta 48 KiB, con escritura a disco y contrapresión. Se verifican longitud y SHA-256 antes de adjuntarlo a la biblioteca. Máximo por ángulo: 256 MiB; transferencia limitada a cinco minutos. No se publica un segundo ángulo incompleto.

Durante una transferencia el archivo primario está fijado. Si falla, se intenta guardarlo y la copia finalizada permanece en Android. Mientras sigue conectada la misma sesión se puede **Reintentar transferencia pendiente**; **Continuar con el vídeo local** conserva el primer ángulo y libera el flujo para otro ejercicio. No se ha implementado reanudación de bytes, recuperación automática tras reiniciar la app ni emparejamiento persistente. Para recuperar archivos de otra sesión se puede exportar/importar la biblioteca. Con cuota agotada, un guardado puede fallar y el vídeo queda pendiente: guardar o liberar espacio antes de seguir grabando.

## Biblioteca y revisión

Los manifiestos schema 1 conservan compatibilidad con 0.4.0 mediante campos opcionales de sesión, etiquetas, ruta/tamaño del segundo ángulo, ajuste e incertidumbre. La ruta adicional se deriva del ID local, nunca de la red. Un manifiesto representa ambos archivos y sus bytes combinados. Guardar, fijar para lectura y eliminar operan sobre ese ejercicio. Hasta tres pendientes/512 MiB y 200 guardados/2 GiB; guardados sin expulsión automática. Adjuntar un ángulo puede desalojar otros pendientes antiguos que no estén abiertos. Una copia en preparación puede necesitar espacio adicional.

Los dibujos identifican el ángulo y su tiempo de medio; se amplían junto con el vídeo y mantienen coordenadas normalizadas. Mover/ampliar y dibujar son modos separados para evitar confundir un trazo con un gesto de zoom. Se puede cambiar la disposición de los ángulos y ocultar los controles.

La biblioteca filtra sesiones y busca etiquetas, nombres y notas; permite ordenar y comparar dos intentos sin modificar sus archivos. La comparación utiliza dos lectores y un ajuste temporal de revisión; no convierte dos intentos distintos en una ejecución multicámara ni modifica la alineación guardada del original.

**Exportar biblioteca** crea un archivo `.acrostella` con los vídeos ya comprimidos, metadatos, momentos y dibujos. Compartir permite guardarlo donde el usuario elija. La copia no está cifrada; tratarla como los vídeos originales. Importar comprueba límites, estructura y hashes de toda la copia antes de incorporar registros con IDs nuevos; nunca sustituye ejercicios existentes ni desaloja pendientes. Cada registro se publica al final de su copia. Una interrupción de escritura puede dejar una importación parcial, que se comunica con el número incorporado. Importar la misma copia otra vez crea duplicados. Se necesita espacio temporal adicional; no equivale a nube ni sincronización.

## Verificación

Pruebas automatizadas: dos propietarios de cámara simulados, sockets TCP reales en loopback, dos grabaciones consecutivas, autenticación incorrecta, límites de trama, interrupción durante grabación, conservación de originales, biblioteca de dos ángulos, exportación/importación y copias corruptas, reproducción con decodificadores simulados, zoom/dibujo y disposiciones móvil/tableta. La compilación y distribución se registran por separado en las evidencias de la entrega. Sigue pendiente la prueba física con el iPad y el S24: permisos, hotspot, cámara, transferencia, temperatura y alineación del movimiento.
