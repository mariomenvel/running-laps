import Foundation
import Flutter

#if canImport(ActivityKit)
import ActivityKit
#endif

final class RunningLapsLiveActivityManager {
  static let shared = RunningLapsLiveActivityManager()

  private init() {}

  #if canImport(ActivityKit)
  @available(iOS 16.1, *)
  private var currentActivity: Activity<RunningLapsActivityAttributes>? {
    Activity<RunningLapsActivityAttributes>.activities.first
  }
  #endif

  func start(arguments: Any?) async throws {
    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else { return }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

    let state = try contentState(from: arguments)
    for activity in Activity<RunningLapsActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }

    let attributes = RunningLapsActivityAttributes(sessionId: UUID().uuidString)
    _ = try Activity.request(
      attributes: attributes,
      content: .init(state: state, staleDate: nil),
      pushType: nil
    )
    #endif
  }

  func update(arguments: Any?) async throws {
    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else { return }
    guard let activity = currentActivity else { return }

    let state = try contentState(from: arguments)
    await activity.update(.init(state: state, staleDate: nil))
    #endif
  }

  func stop() async {
    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else { return }

    for activity in Activity<RunningLapsActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
    #endif
  }

  #if canImport(ActivityKit)
  @available(iOS 16.1, *)
  private func contentState(from arguments: Any?) throws -> RunningLapsActivityAttributes.ContentState {
    guard let map = arguments as? [String: Any] else {
      throw FlutterError(
        code: "invalid_args",
        message: "Live Activity payload missing.",
        details: nil
      )
    }

    let title = map["title"] as? String ?? "Running Laps \u{00B7} En carrera"
    let distance = map["distance"] as? String ?? "0.00 km"
    let elapsed = map["elapsed"] as? String ?? "00:00"
    let elapsedSeconds = map["elapsedSeconds"] as? Int ?? 0
    let pace = map["pace"] as? String ?? "--:-- /km"
    let mode = map["mode"] as? String ?? "continuous"
    let serie = map["serie"] as? Int ?? 1
    let hasGps = map["hasGps"] as? Bool ?? true
    let isPaused = map["isPaused"] as? Bool ?? false
    let actionLabel = map["actionLabel"] as? String ?? "Abrir"
    let actionId = map["actionId"] as? String ?? "open"
    let actionUrl = "runninglaps://training?action=\(actionId)"

    return RunningLapsActivityAttributes.ContentState(
      title: title,
      distance: distance,
      elapsed: elapsed,
      elapsedSeconds: elapsedSeconds,
      pace: pace,
      mode: mode,
      serie: serie,
      hasGps: hasGps,
      isPaused: isPaused,
      actionLabel: actionLabel,
      actionUrl: actionUrl
    )
  }
  #endif
}
