# Materiales del estudio — fuentes consultadas

Consulta realizada el 23 de octubre de 2026, a petición explícita del usuario:

- [Apple, Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/liquid-glass).
- [Apple HIG, Materials](https://developer.apple.com/design/human-interface-guidelines/materials).
- [API público UIGlassEffect](https://developer.apple.com/documentation/uikit/uiglasseffect).
- [Flutter Liquid Glass, código y documentación](https://github.com/whynotmake-it/flutter_liquid_glass), MIT.
- [Paquete fijado 0.2.0-dev.4](https://pub.dev/packages/liquid_glass_renderer/versions/0.2.0-dev.4).

Apple sitúa este material en la capa funcional de controles/navegación que flota sobre el contenido. El vídeo de análisis debe seguir despejado; no se aplica un filtro a sus píxeles. Se simplifican jerarquía, acento azul, formas continuas, separaciones y controles de captura. Las dos cámaras aparecen por defecto en el centro conectado, a partes iguales, en fila cuando hay anchura y en columna en móvil vertical.

En iOS se usa `UIVisualEffectView` con el efecto de sistema, y desenfoque de sistema en versiones anteriores a iOS 26. No se añaden APIs privadas ni fuentes descargadas de Apple. En Android, el shader del paquete incorpora refracción y borde óptico; es una implementación Flutter, no el material nativo de iOS. El paquete está marcado experimental; se fija la versión compatible y se limita a una capa de controles por pantalla para contener coste GPU. La versión 1.0 investigada exige APIs Flutter GPU más experimentales; no se adopta solo por ser más reciente.

`ImageFilter.isShaderFilterSupported` selecciona una superficie opaca en software/Skia. La compilación avisa de shaders SkSL incompatibles: no se cargan en esa ruta. Alto contraste, navegación accesible y animaciones desactivadas evitan el efecto. La vista UIKit observa Reducir transparencia y cambia a superficie opaca; un cambio de tema reconstruye el material, sin reabrir la cámara.

Los tests verifican tamaños y navegación en móvil vertical/horizontal y tablet. No miden rendimiento óptico ni del compositor nativo. Faltan revisión visual real en iPad/S24, presupuesto GPU con dos cámaras, consumo y comodidad con lápiz. Compilar no demuestra esas propiedades.
