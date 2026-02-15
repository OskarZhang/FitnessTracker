import ActivityKit
import WidgetKit
import SwiftUI

@main
struct FitnessTrackerLiveActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        FitnessTrackerLiveActivityWidget()
    }
}

struct FitnessTrackerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutLiveActivityAttributes.self) { context in
            HStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.nextLikelyExerciseName == nil ? "Current Exercise" : "Next Likely")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(primaryText(for: context.state))
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer()
                if let timerEndDate = context.state.timerEndDate {
                    Text(timerInterval: Date.now...timerEndDate, countsDown: true)
                        .font(.headline.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal)
            .widgetURL(deepLinkURL(for: context.state.deepLinkExerciseName))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(Color.accentColor)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.nextLikelyExerciseName == nil ? "Workout" : "Next")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(primaryText(for: context.state))
                            .font(.headline)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let timerEndDate = context.state.timerEndDate {
                        Text(timerInterval: Date.now...timerEndDate, countsDown: true)
                            .font(.headline.monospacedDigit())
                    } else {
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell")
            } compactTrailing: {
                compactTrailingContent(state: context.state)
            } minimal: {
                Image(systemName: "dumbbell")
            }
            .keylineTint(.accentColor)
            .widgetURL(deepLinkURL(for: context.state.deepLinkExerciseName))
        }
    }

    private func primaryText(for state: WorkoutLiveActivityAttributes.ContentState) -> String {
        state.nextLikelyExerciseName ?? state.displayExerciseName
    }

    private func compactTrailingContent(state: WorkoutLiveActivityAttributes.ContentState) -> AnyView {
        if let timerEndDate = state.timerEndDate {
            return AnyView(
                Text(timerInterval: Date.now...timerEndDate, countsDown: true)
                    .font(.caption2.monospacedDigit())
            )
        }
        return AnyView(
            Text(primaryText(for: state))
                .font(.caption2)
                .lineLimit(1)
        )
    }

    private func deepLinkURL(for exerciseName: String) -> URL {
        var components = URLComponents()
        components.scheme = "fitnesstracker"
        components.host = "live"
        components.queryItems = [
            URLQueryItem(name: "exercise", value: exerciseName)
        ]
        if let url = components.url {
            return url
        }
        return URL(string: "fitnesstracker://add") ?? URL(fileURLWithPath: "/")
    }
}
