import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct RunningLapsActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var title: String
    var distance: String
    var elapsed: String
    var elapsedSeconds: Int
    var pace: String
    var mode: String
    var serie: Int
    var hasGps: Bool
    var isPaused: Bool
    var actionLabel: String
    var actionUrl: String
    var phase: String      // "continuous", "running", "rest"
    var restCountdown: Int // seconds remaining in rest phase
  }

  var sessionId: String
}
#endif
