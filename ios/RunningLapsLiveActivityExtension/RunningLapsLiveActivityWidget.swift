import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Brand colours

@available(iOS 16.1, *)
private extension Color {
  static let brandPurple = Color(red: 0.56, green: 0.14, blue: 0.67)
  static let brandPurpleDark = Color(red: 0.42, green: 0.00, blue: 0.50)
}

// MARK: - Widget entry point

@available(iOS 16.1, *)
struct RunningLapsLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RunningLapsActivityAttributes.self) { context in
      RunningLapsLockScreenView(state: context.state)
        .activityBackgroundTint(Color.brandPurple)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          RunningLapsDILeading(state: context.state)
        }
        DynamicIslandExpandedRegion(.trailing) {
          RunningLapsDITrailing(state: context.state)
        }
        DynamicIslandExpandedRegion(.bottom) {
          RunningLapsDIBottom(state: context.state)
        }
      } compactLeading: {
        RunningLapsCompactLeading(state: context.state)
      } compactTrailing: {
        RunningLapsCompactTrailing(state: context.state)
      } minimal: {
        RunningLapsMinimal(state: context.state)
      }
      .widgetURL(URL(string: "runninglaps://training?action=open"))
      .keylineTint(Color.brandPurple)
    }
  }
}

// MARK: - Lock Screen

@available(iOS 16.1, *)
private struct RunningLapsLockScreenView: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color.brandPurple, Color.brandPurpleDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      if state.phase == "rest" {
        RunningLapsRestView(state: state)
      } else {
        RunningLapsRunningView(state: state)
      }
    }
    .widgetURL(URL(string: "runninglaps://training?action=open"))
  }
}

// MARK: - Lock Screen: Running

@available(iOS 16.1, *)
private struct RunningLapsRunningView: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .center) {
        Text(state.mode == "continuous" ? "En carrera" : "Serie \(state.serie)")
          .font(.headline.weight(.semibold))
          .foregroundStyle(.white)

        Spacer()

        Link(destination: URL(string: state.actionUrl)!) {
          Text(state.actionLabel)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
            .foregroundStyle(.white)
        }
      }

      RunningLapsMetricsRow(state: state)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

// MARK: - Lock Screen: Rest

@available(iOS 16.1, *)
private struct RunningLapsRestView: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    VStack(spacing: 10) {
      Text(formatCountdown(state.restCountdown))
        .font(.system(size: 48, weight: .bold, design: .monospaced))
        .foregroundStyle(.white)

      Text("Descansando · Serie \(state.serie)")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.75))

      Link(destination: URL(string: state.actionUrl)!) {
        Text("Saltar")
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 20)
          .padding(.vertical, 8)
          .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
          .foregroundStyle(.white)
      }
    }
    .padding(.vertical, 14)
  }

  private func formatCountdown(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
  }
}

// MARK: - Dynamic Island: Expanded regions

@available(iOS 16.1, *)
private struct RunningLapsDILeading: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    if state.phase == "rest" {
      VStack(alignment: .leading, spacing: 2) {
        Text("Descanso")
          .font(.headline)
          .foregroundStyle(.primary)
        Text("Serie \(state.serie)")
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
      }
    } else {
      VStack(alignment: .leading, spacing: 2) {
        Text(state.mode == "continuous" ? "En carrera" : "Serie \(state.serie)")
          .font(.headline)
          .foregroundStyle(.primary)
        Text(state.hasGps ? state.distance : state.elapsed)
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
      }
    }
  }
}

@available(iOS 16.1, *)
private struct RunningLapsDITrailing: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    Link(destination: URL(string: state.actionUrl)!) {
      Text(state.phase == "rest" ? "Saltar" : state.actionLabel)
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.brandPurple.opacity(0.12))
        .foregroundStyle(Color.brandPurple)
        .clipShape(Capsule())
    }
  }
}

@available(iOS 16.1, *)
private struct RunningLapsDIBottom: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    if state.phase == "rest" {
      HStack {
        Spacer()
        Text(formatCountdown(state.restCountdown))
          .font(.title2.monospacedDigit().weight(.semibold))
          .foregroundStyle(.primary)
        Spacer()
      }
    } else {
      RunningLapsMetricsRow(state: state)
    }
  }

  private func formatCountdown(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
  }
}

// MARK: - Dynamic Island: Compact

@available(iOS 16.1, *)
private struct RunningLapsCompactLeading: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    Image(systemName: state.phase == "rest" ? "hourglass" : "figure.run")
      .foregroundStyle(Color.brandPurple)
  }
}

@available(iOS 16.1, *)
private struct RunningLapsCompactTrailing: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    if state.phase == "rest" {
      Text(formatCountdown(state.restCountdown))
        .font(.caption2.monospacedDigit())
        .foregroundStyle(Color.brandPurple)
    } else if state.hasGps {
      Text(state.distance.replacingOccurrences(of: " km", with: "k"))
        .font(.caption2.monospacedDigit())
        .foregroundStyle(Color.brandPurple)
    } else {
      RunningLapsElapsedText(state: state)
        .font(.caption2.monospacedDigit())
        .foregroundStyle(Color.brandPurple)
    }
  }

  private func formatCountdown(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
  }
}

// MARK: - Dynamic Island: Minimal

@available(iOS 16.1, *)
private struct RunningLapsMinimal: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    Image(systemName: state.phase == "rest" ? "hourglass" : "figure.run")
      .foregroundStyle(Color.brandPurple)
  }
}

// MARK: - Shared: Metrics row

@available(iOS 16.1, *)
private struct RunningLapsMetricsRow: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    if state.hasGps {
      HStack(spacing: 10) {
        metric(state.distance)
        separator
        RunningLapsElapsedText(state: state)
          .font(.subheadline.monospacedDigit().weight(.semibold))
          .foregroundStyle(.white)
        separator
        metric(state.pace)
      }
    } else {
      HStack {
        Spacer()
        RunningLapsElapsedText(state: state)
          .font(.subheadline.monospacedDigit().weight(.semibold))
          .foregroundStyle(.white)
        Spacer()
      }
    }
  }

  private func metric(_ title: String) -> some View {
    Text(title)
      .font(.subheadline.monospacedDigit().weight(.semibold))
      .foregroundStyle(.white)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
  }

  private var separator: some View {
    Text("\u{00B7}")
      .font(.subheadline.weight(.bold))
      .foregroundStyle(.white.opacity(0.5))
  }
}

// MARK: - Shared: Autonomous elapsed timer

@available(iOS 16.1, *)
private struct RunningLapsElapsedText: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    if state.isPaused {
      Text(state.elapsed)
    } else {
      // Native iOS timer — ticks autonomously without Flutter pushing updates.
      // referenceDate anchors at (now - elapsedSeconds) so it resumes correctly.
      // Use now+86400 instead of distantFuture to avoid display clipping on some iOS versions.
      Text(timerInterval: referenceDate...Date(timeIntervalSinceNow: 86400), countsDown: false)
    }
  }

  private var referenceDate: Date {
    Date(timeIntervalSinceNow: TimeInterval(-state.elapsedSeconds))
  }
}
