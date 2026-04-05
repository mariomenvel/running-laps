import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct RunningLapsLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RunningLapsActivityAttributes.self) { context in
      RunningLapsExpandedView(state: context.state)
        .activityBackgroundTint(Color.white)
        .activitySystemActionForegroundColor(
          Color(red: 0.56, green: 0.14, blue: 0.67)
        )
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            Text(
              context.state.mode == "continuous"
                ? "En carrera"
                : "Serie \(context.state.serie)"
            )
            .font(.headline)
            .foregroundStyle(.primary)

            Text(context.state.hasGps ? context.state.distance : context.state.elapsed)
              .font(.subheadline.monospacedDigit())
              .foregroundStyle(.secondary)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          Link(destination: URL(string: context.state.actionUrl)!) {
            Text(context.state.actionLabel)
              .font(.caption.weight(.semibold))
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(
                Color(red: 0.56, green: 0.14, blue: 0.67).opacity(0.12)
              )
              .foregroundStyle(Color(red: 0.56, green: 0.14, blue: 0.67))
              .clipShape(Capsule())
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          RunningLapsMetricsRow(state: context.state)
        }
      } compactLeading: {
        Image(systemName: "figure.run")
          .foregroundStyle(Color(red: 0.56, green: 0.14, blue: 0.67))
      } compactTrailing: {
        if context.state.hasGps {
          Text(context.state.distance.replacingOccurrences(of: " km", with: "k"))
            .font(.caption2.monospacedDigit())
        } else {
          RunningLapsElapsedText(state: context.state)
            .font(.caption2.monospacedDigit())
        }
      } minimal: {
        Image(systemName: "figure.run")
          .foregroundStyle(Color(red: 0.56, green: 0.14, blue: 0.67))
      }
      .widgetURL(URL(string: context.state.actionUrl))
      .keylineTint(Color(red: 0.56, green: 0.14, blue: 0.67))
    }
  }
}

@available(iOS 16.1, *)
private struct RunningLapsExpandedView: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .center) {
        Text(state.title)
          .font(.headline.weight(.semibold))
          .foregroundStyle(.primary)

        Spacer()

        Link(destination: URL(string: state.actionUrl)!) {
          Text(state.actionLabel)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
              Color(red: 0.56, green: 0.14, blue: 0.67).opacity(0.12)
            )
            .foregroundStyle(Color(red: 0.56, green: 0.14, blue: 0.67))
            .clipShape(Capsule())
        }
      }

      RunningLapsMetricsRow(state: state)
    }
    .padding(.horizontal, 4)
    .widgetURL(URL(string: state.actionUrl))
  }
}

@available(iOS 16.1, *)
private struct RunningLapsMetricsRow: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    if state.hasGps {
      HStack(spacing: 10) {
        metric(title: state.distance)
        separator
        elapsedMetric
        separator
        metric(title: state.pace)
      }
    } else {
      HStack {
        Spacer()
        elapsedMetric
        Spacer()
      }
    }
  }

  private var elapsedMetric: some View {
    RunningLapsElapsedText(state: state)
      .font(.subheadline.monospacedDigit().weight(.semibold))
      .foregroundStyle(.primary)
  }

  private func metric(title: String) -> some View {
    Text(title)
      .font(.subheadline.monospacedDigit().weight(.semibold))
      .foregroundStyle(.primary)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
  }

  private var separator: some View {
    Text("\u{00B7}")
      .font(.subheadline.weight(.bold))
      .foregroundStyle(.secondary)
  }
}

@available(iOS 16.1, *)
private struct RunningLapsElapsedText: View {
  let state: RunningLapsActivityAttributes.ContentState

  var body: some View {
    if state.isPaused {
      Text(state.elapsed)
    } else {
      Text(timerInterval: referenceDate...Date.distantFuture, countsDown: false)
    }
  }

  private var referenceDate: Date {
    Date(timeIntervalSinceNow: TimeInterval(-state.elapsedSeconds))
  }
}
