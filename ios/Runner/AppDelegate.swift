import Flutter
import Network
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
    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)
    if let registrar = registry.registrar(forPlugin: "LocalNetworkPermissionPlugin") {
      LocalNetworkPermissionPlugin.register(with: registrar)
    }
  }
}

private final class LocalNetworkPermissionPlugin: NSObject, FlutterPlugin {
  private var authorizer: LocalNetworkAuthorizer?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "ccviewer/local_network",
      binaryMessenger: registrar.messenger()
    )
    let instance = LocalNetworkPermissionPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestAccess":
      requestAccess(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestAccess(result: @escaping FlutterResult) {
    authorizer?.cancel()

    let authorizer = LocalNetworkAuthorizer()
    self.authorizer = authorizer
    authorizer.requestAccess { [weak self] granted, message in
      self?.authorizer = nil
      result([
        "granted": granted,
        "message": message ?? ""
      ])
    }
  }
}

private final class LocalNetworkAuthorizer: NSObject, NetServiceDelegate {
  private var browser: NWBrowser?
  private var service: NetService?
  private var completion: ((Bool, String?) -> Void)?
  private var finished = false

  func requestAccess(completion: @escaping (Bool, String?) -> Void) {
    self.completion = completion

    let parameters = NWParameters()
    parameters.includePeerToPeer = true

    let browser = NWBrowser(
      for: .bonjour(type: "_http._tcp", domain: nil),
      using: parameters
    )
    self.browser = browser
    browser.stateUpdateHandler = { [weak self] state in
      switch state {
      case .ready:
        self?.finish(granted: true, message: nil)
      case .failed(let error):
        self?.finish(granted: false, message: error.localizedDescription)
      case .waiting(let error):
        self?.finish(granted: false, message: error.localizedDescription)
      default:
        break
      }
    }
    browser.browseResultsChangedHandler = { _, _ in }

    let service = NetService(
      domain: "local.",
      type: "_http._tcp.",
      name: "CCTV-\(UUID().uuidString)",
      port: 9
    )
    self.service = service
    service.delegate = self

    browser.start(queue: .main)
    service.publish(options: .listenForConnections)

    DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
      self?.finish(
        granted: false,
        message: "Local network permission request timed out."
      )
    }
  }

  func cancel() {
    cleanup()
  }

  func netServiceDidPublish(_ sender: NetService) {}

  func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
    finish(granted: false, message: "Unable to publish local network probe.")
  }

  private func finish(granted: Bool, message: String?) {
    if finished { return }
    finished = true
    cleanup()
    completion?(granted, message)
    completion = nil
  }

  private func cleanup() {
    browser?.cancel()
    browser = nil
    service?.stop()
    service = nil
  }
}
