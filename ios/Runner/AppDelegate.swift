import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AcroStellaStudio") else { return }
    registrar.register(StudioGlassFactory(), withId: "acrostella/liquid-glass")
    let channel = FlutterMethodChannel(name: "acrostella/studio", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method == "keepAwake" {
        let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
        UIApplication.shared.isIdleTimerDisabled = enabled && UIApplication.shared.applicationState == .active
        result(nil)
      } else { result(FlutterMethodNotImplemented) }
    }
  }
}


// UIKit's public system material, including Reduce Transparency handling.
private final class StudioGlassFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    StudioGlassView(frame: frame, arguments: args as? [String: Any] ?? [:])
  }
}

private final class StudioGlassView: NSObject, FlutterPlatformView {
  private let effectView: UIVisualEffectView
  private let dark: Bool
  init(frame: CGRect, arguments: [String: Any]) {
    dark = arguments["dark"] as? Bool ?? true
    effectView = UIVisualEffectView(frame: frame)
    super.init()
    effectView.overrideUserInterfaceStyle = dark ? .dark : .light
    effectView.layer.cornerRadius = arguments["radius"] as? CGFloat ?? 28
    effectView.layer.cornerCurve = .continuous
    effectView.clipsToBounds = true
    effectView.isUserInteractionEnabled = false
    updateMaterial()
    NotificationCenter.default.addObserver(self, selector: #selector(updateMaterial),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
  }
  @objc private func updateMaterial() {
    if UIAccessibility.isReduceTransparencyEnabled {
      effectView.effect = nil
      effectView.backgroundColor = dark ? UIColor(white: 0.12, alpha: 1) : .secondarySystemBackground
    } else {
      effectView.backgroundColor = .clear
      if #available(iOS 26.0, *) {
        effectView.effect = UIGlassEffect(style: .regular)
      } else {
        effectView.effect = UIBlurEffect(style: .systemMaterial)
      }
    }
  }
  func view() -> UIView { effectView }
  deinit { NotificationCenter.default.removeObserver(self) }
}
