# Incremento 0.2.0+2: clips locales

Fecha: 22 de octubre de 2026, Europe/Madrid. Árbol de trabajo sobre
`e06c389d7b0b1bf3addd3e3e86ae9d1b0788df75`; no se atribuye un nuevo commit
ni una ejecución CI que no se haya realizado.

## Comprobaciones ejecutadas

```text
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
apksigner verify --verbose build/app/outputs/flutter-apk/app-debug.apk
aapt dump badging build/app/outputs/flutter-apk/app-debug.apk
aapt dump permissions build/app/outputs/flutter-apk/app-debug.apk
```

Resultados: resolución correcta; formato sin cambios; análisis sin incidencias;
38 pruebas superadas; APK de depuración construido y firma v2 válida. Tras
excluir el permiso wake lock transitivo de Media3 se repitieron compilación,
verificación de firma e inspección de permisos. No se desactivaron pruebas,
verificación de TLS ni comprobaciones de dependencias.

Las 26 pruebas añadidas cubren concurrencia y ciclo de grabación (11),
archivos/cuotas/recuperación/lectores (11), y controles y reproductor simulado
(4). Incluyen finalizar automáticamente sin cerrar el propietario, salir o
destruir durante el inicio, errores nativos y de disco, apertura tardía del
reproductor, liberación después del decodificador, pausa, seek y velocidad.

APK: `artifacts/acrostella-analytics-0.2.0+2-debug.apk` (ignorado por Git).
SHA-256: `6125971320519e514087f3e6e33a3ce8f1e2c1e86d293c9632ea3eb7778e51c2`.
VersionName 0.2.0, versionCode 2, minSdk 24, targetSdk 36, arm64-v8a,
armeabi-v7a y x86_64. Permisos de cámara y red de depuración, sin micrófono,
almacenamiento externo ni wake lock.

## Límites

Los tests utilizan cámaras y plataforma de vídeo falsas y bytes sintéticos
para el almacén. No comprueban codecs, vídeo real, continuidad del sensor,
latencia ni rendimiento. No hay iOS 0.2.0 compilado, firma Apple, instalación
o pruebas físicas de este incremento. Los clips finitos no son el búfer ni el
replay continuo de dos ángulos. La duración máxima es una petición de control
tras el inicio nativo, y la cuota de bytes se comprueba al finalizar, no sobre
el archivo activo del plugin. Ver `docs/arquitectura.md`.
