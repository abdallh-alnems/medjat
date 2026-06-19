import CFNetwork
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

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VpnDetector") {
      let channel = FlutterMethodChannel(
        name: "app/vpn",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        if call.method == "isVpnActive" {
          result(AppDelegate.isVpnActive())
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  /// Reliable iOS VPN detection.
  ///
  /// Matching network-interface names (ipsec/ppp/utun) gives false positives:
  /// a *configured but disconnected* IKEv2 VPN leaves an `ipsec0` interface, and
  /// `utun` interfaces exist for Handoff/Hotspot on every iPhone. Instead we read
  /// the system proxy scoped settings, which only contain VPN interface keys when
  /// a tunnel is actually routing traffic.
  static func isVpnActive() -> Bool {
    guard
      let cfSettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue(),
      let settings = cfSettings as? [String: Any],
      let scoped = settings["__SCOPED__"] as? [String: Any]
    else {
      return false
    }
    let vpnKeys = ["tap", "tun", "ppp", "ipsec", "ipsec0", "utun"]
    for key in scoped.keys {
      if vpnKeys.contains(where: { key.contains($0) }) {
        return true
      }
    }
    return false
  }
}
