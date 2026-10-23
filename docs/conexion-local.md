# Dos cámaras por red local — 0.6.0

El iPad conserva su propia cámara y recibe la vista del Android en directo. Cada cámara tiene un único propietario nativo; la misma captura alimenta textura, directo WebRTC y archivo MP4. Los originales comprimidos se reúnen al terminar para revisar y guardar ambos ángulos como un ejercicio. No hay cuentas, nube ni body tracking.

## Uso

1. Actualizar **ambos dispositivos a 0.6.0**. El protocolo de conexión cambió; 0.5.x no es compatible. Conectar a la misma Wi-Fi o el iPad al hotspot del Android. Autorizar cámara y red local.
2. Android: **Dispositivos → Usar como segunda cámara**. La primera vez muestra seis cifras y un identificador corto. El código admite ceros iniciales, caduca a los cinco minutos y bloquea cinco intentos incorrectos; puede regenerarse.
3. iPad: **Dispositivos → Buscar cámaras → tocar la cámara**. El panel de código se abre directamente; **Conectar y recordar** evita buscar un campo más abajo. En reconexiones, los dispositivos recordados no solicitan el código. Si Bonjour no funciona, usar **Conexión manual por IP** con una dirección de la pantalla del Android; puerto 45872 por defecto.
4. Volver al estudio: el centro conectado muestra ambas cámaras automáticamente, a partes iguales, en fila o columna según el espacio. **Reintentar vídeo** recupera el directo sin borrar la confianza. Un fallo del directo no equivale a que el canal de grabación esté desconectado.
5. **Iniciar · dos ángulos** comprueba las cámaras y programa el comienzo con margen de 1,5 segundos. **Revisar** finaliza ambos archivos y muestra el progreso de transferencia del segundo ángulo. Esperar a reunirlo: el directo y el archivo original tienen usos diferentes.
6. La revisión comparte cursor, velocidad e intervalo. Comprobar una palmada o movimiento común; **Alinear los dos ángulos** permite corregir visualmente. Guardar/eliminar gestiona ambos archivos del iPad. La copia del Android se conserva y se elimina desde su biblioteca.

El iPad también puede actuar como segunda cámara desde la opción avanzada explícita. No se anuncia como cámara mientras actúa de centro. Se puede entrenar con una sola cámara sin emparejamiento.

## Confianza y reconexión

Las seis cifras iniciales usan SRP-6a (grupo RFC 5054 de 3072 bits, SHA-256, parámetros fijos y efímeros seguros). La clave AES no procede directamente de las seis cifras. Después de autenticar, se intercambia una clave aleatoria de 256 bits **dentro del canal cifrado**. Se guarda en Keychain / almacenamiento seguro Android junto con un ID público aleatorio y el último rol, hasta ocho pares. **Olvidar dispositivo** elimina su confianza local; para conectar otra vez se necesita un código nuevo.

La reanudación del protocolo v3 usa nonces frescos y pruebas HMAC-SHA256 ligadas a ambos identificadores. HKDF-SHA256 deriva claves direccionales nuevas; los mensajes usan AES-256-GCM, secuencias verificadas y tramas de hasta 100 KiB. No se reutiliza la clave AES anterior ni se degrada silenciosamente al código. La negociación tiene límite de doce segundos y frames previos de 2048 bytes.

Bonjour (`_acrostella._tcp`, `nsd` 5.0.1) publica protocolo, puerto e ID público; no publica claves ni códigos. Solo se anuncia el rol cámara. La búsqueda inicial es explícita y acotada a treinta segundos. Tras una conexión recordada, la reconexión puede buscar el mismo ID cuando cambie la IP: el anuncio no autoriza nada, la prueba criptográfica sigue siendo obligatoria. El canal de control solo admite IPv4 privada/enlace local; loopback se usa en tests. No hay STUN/TURN, sondeos de subred ni servicios externos. Un hotspot puede aislar clientes; la IP manual no evita ese aislamiento.

Salir al segundo plano finaliza el archivo y libera cámara/transporte, **sin borrar la confianza**. Al regresar se recupera el rol; el centro reintenta la conexión y reúne una ejecución pendiente si encuentra la misma cámara autorizada. Las pantallas evitan apagarse automáticamente mientras la cámara está activa en primer plano. El sistema operativo puede suspenderla al bloquear o abandonar la app: no se promete grabación en segundo plano.

## Tiempo del vídeo y precisión

Siete intercambios de cuatro marcas estiman los relojes monotónicos de control; se elige el de menor ida y vuelta, descontando procesamiento remoto. El MP4 conserva tiempos fuente: Android presenta el timestamp del frame a EGL y drena el encoder antes de cerrar; iOS usa los timestamps del frame y la orientación inicial del archivo.

El inicio se ancla a la edad nativa del primer fotograma aceptado por el writer, acotada entre las marcas anteriores/posteriores a consultar esa edad. Se conserva la correlación de esa ejecución aunque los controladores se reconstruyan. El retraso del directo **no** se utiliza para alinear archivos. Estas marcas no miden exposición del sensor ni ofrecen sincronización de laboratorio. Comprobar visualmente la alineación sigue siendo necesario.

`LinkedPlayback` espera ambos seeks antes de reproducir y limita el cursor al intervalo común. Consulta posiciones cada 300 ms; descarta consultas lentas y corrige diferencias observadas mayores de 80 ms, como máximo una vez por segundo. Buffering/error pausa ambos. No hay presentación atómica entre decodificadores ni garantía de cero milisegundos. Los pasos de 0,03 s son saltos temporales aproximados, no stepping exacto del decodificador.

## Transferencia y recuperación

El archivo original se envía con contrapresión por bloques de 48 KiB, hasta 256 MiB por ángulo y cinco minutos de transferencia. Se verifica longitud y SHA-256 antes de adjuntarlo; un secundario incompleto no se publica en la biblioteca. La vista de directo no sustituye ese archivo. Se mantienen el primario fijado durante la transferencia y la copia finalizada en Android.

Si falla, se conserva el local y la ejecución pendiente. **Reintentar transferencia pendiente** recibe de nuevo el archivo completo; no se reanudan bytes. Al recuperar una pareja recordada se intenta reunir el pendiente automáticamente. **Continuar con el vídeo local** permite conservar un solo ángulo y liberar el flujo. Los acuses finales pendientes también se recuperan, evitando bloquear el siguiente ejercicio si se perdió la última respuesta.

Un pequeño diario atómico guarda IDs de clips ya finalizados, par autorizado y su correlación original de tiempos. Puede recuperar el grupo al reconstruir el controlador; no repara un MP4 que el sistema cerró antes de finalizarlo ni recupera archivos borrados. Los clips durables permanecen en soporte privado. Con cuota agotada, guardar/adjuntar puede fallar: liberar espacio o conservar el local antes de continuar. No se sustituyen ni expulsan guardados automáticamente.

## Biblioteca y dibujos

Un manifiesto representa ambos archivos. Guardar, fijar para lectura, exportar y eliminar operan sobre el ejercicio agrupado. Los dibujos identifican ángulo y tiempo de su propio medio, con coordenadas normalizadas y zoom compartido con el vídeo. Seis herramientas, estilos, duración, deshacer/rehacer, visibilidad, momentos y bucle A–B. Mover/ampliar es un modo separado de dibujar.

Sesiones, etiquetas, nombres, notas, favoritos, filtros y ordenación siguen disponibles. Comparar dos intentos abre dos lectores sin convertirlos en una ejecución multicámara. **Exportar biblioteca** crea una copia `.acrostella` con medios comprimidos, dibujos y metadata; importar valida límites/hashes y añade IDs nuevos sin sustituir ejercicios. La copia no está cifrada y puede duplicarse si se importa otra vez. No equivale a nube ni sincronización.

## Verificación

Las pruebas utilizan sockets TCP reales en loopback, cámaras sintéticas y decodificadores simulados: códigos, autenticación/rechazos, confianza persistente, suspensión/reconexión, recuperación al reconstruir controladores, desfase con respuestas nativas de distinta duración, corte del acuse final, integridad y agrupación, búsqueda/cancelación nativa simulada y layouts. [Evidencias de 0.6.0](evidencias/2026-10-23-directo-y-reconexion.md).

La compilación real Android/iOS no sustituye la prueba conjunta iPad/S24: orientación del MP4, permisos, hotspot, directo, calor, consumo, estabilidad y alineación del movimiento siguen pendientes de esa prueba física. Tampoco se ha implementado todavía un búfer comprimido circular o replay continuo.
