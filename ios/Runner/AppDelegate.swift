import Flutter
import UIKit
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let liveActivityChannelName = "running_laps/live_activity"
  private let liveActivityActionsChannelName = "running_laps/live_activity_actions"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureGoogleSignIn()
    GeneratedPluginRegistrant.register(with: self)
    configureLiveActivityChannels()

    if let url = launchOptions?[.url] as? URL {
      _ = handleCustomURL(url)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }

    if handleCustomURL(url) {
      return true
    }

    return super.application(app, open: url, options: options)
  }

  private func configureGoogleSignIn() {
    guard
      let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
      let plist = NSDictionary(contentsOfFile: plistPath),
      let clientID = plist["CLIENT_ID"] as? String,
      !clientID.isEmpty
    else {
      assertionFailure("GoogleService-Info.plist missing CLIENT_ID for Google Sign-In.")
      return
    }

    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
  }

  private func configureLiveActivityChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let methodChannel = FlutterMethodChannel(
      name: liveActivityChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    methodChannel.setMethodCallHandler { call, result in
      Task {
        do {
          switch call.method {
          case "start":
            try await RunningLapsLiveActivityManager.shared.start(arguments: call.arguments)
            result(nil)
          case "update":
            try await RunningLapsLiveActivityManager.shared.update(arguments: call.arguments)
            result(nil)
          case "stop":
            await RunningLapsLiveActivityManager.shared.stop()
            result(nil)
          default:
            result(FlutterMethodNotImplemented)
          }
        } catch {
          result(
            FlutterError(
              code: "live_activity_error",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }

    let eventChannel = FlutterEventChannel(
      name: liveActivityActionsChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    eventChannel.setStreamHandler(LiveActivityActionStreamHandler.shared)
  }

  private func handleCustomURL(_ url: URL) -> Bool {
    guard url.scheme == "runninglaps" else {
      return false
    }

    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let action = components?.queryItems?.first(where: { $0.name == "action" })?.value
    guard let action, !action.isEmpty, action != "open" else {
      return true  // "open" just foregrounds the app — no action emitted
    }

    LiveActivityActionStreamHandler.shared.emit(action: action)
    return true
  }
}

final class LiveActivityActionStreamHandler: NSObject, FlutterStreamHandler {
  static let shared = LiveActivityActionStreamHandler()

  private var sink: FlutterEventSink?
  private var pendingActions: [String] = []

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    pendingActions.forEach { events($0) }
    pendingActions.removeAll()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func emit(action: String) {
    if let sink {
      sink(action)
    } else {
      pendingActions.append(action)
    }
  }
}
