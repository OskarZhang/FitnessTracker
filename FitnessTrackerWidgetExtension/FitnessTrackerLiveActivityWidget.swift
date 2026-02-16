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
            HStack(spacing: 10) {
                Image(systemName: context.state.sessionState == .activeLogging ? "figure.strengthtraining.traditional" : "pause.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(lockScreenStatusTitle(for: context.state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lockScreenPrimaryText(for: context.state))
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer()
                if let timerEndDate = context.state.timerEndDate {
                    Text(timerInterval: Date.now...timerEndDate, countsDown: true)
                        .font(.headline.monospacedDigit().weight(.semibold))
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(context.state.sessionState == .activeLogging ? "Active" : "Resume")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.18), in: Capsule())
                }
            }
            .padding(.horizontal)
            .widgetURL(deepLinkURL(for: context.state))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.sessionState == .activeLogging ? "dumbbell.fill" : "pause.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 26, height: 26)
                        .background(Color.accentColor.opacity(0.14), in: Circle())
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dynamicIslandTitle(for: context.state))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(dynamicIslandPrimaryText(for: context.state))
                            .font(.headline)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let timerEndDate = context.state.timerEndDate {
                        Text(timerInterval: Date.now...timerEndDate, countsDown: true)
                            .font(.headline.monospacedDigit())
                    } else {
                        Text(context.state.sessionState == .activeLogging ? "LIVE" : "NEXT")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(context.state.sessionState == .activeLogging ? Color.accentColor : .orange)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.sessionState == .activeLogging ? "dumbbell" : "pause")
            } compactTrailing: {
                compactTrailingContent(state: context.state)
            } minimal: {
                Image(systemName: context.state.sessionState == .activeLogging ? "dumbbell" : "pause")
            }
            .keylineTint(.accentColor)
            .widgetURL(deepLinkURL(for: context.state))
        }
    }

    private func lockScreenStatusTitle(for state: WorkoutLiveActivityAttributes.ContentState) -> String {
        switch state.sessionState {
        case .activeLogging:
            return "Logging now"
        case .needsPostWorkoutPrompt:
            return "Workout paused"
        }
    }

    private func lockScreenPrimaryText(for state: WorkoutLiveActivityAttributes.ContentState) -> String {
        switch state.sessionState {
        case .activeLogging:
            return state.displayExerciseName
        case .needsPostWorkoutPrompt:
            return "Tap to continue your session"
        }
    }

    private func dynamicIslandTitle(for state: WorkoutLiveActivityAttributes.ContentState) -> String {
        switch state.sessionState {
        case .activeLogging:
            return "Workout in progress"
        case .needsPostWorkoutPrompt:
            return "Awaiting action"
        }
    }

    private func dynamicIslandPrimaryText(for state: WorkoutLiveActivityAttributes.ContentState) -> String {
        switch state.sessionState {
        case .activeLogging:
            return state.displayExerciseName
        case .needsPostWorkoutPrompt:
            return "Tap to choose next step"
        }
    }

    private func compactTrailingContent(state: WorkoutLiveActivityAttributes.ContentState) -> AnyView {
        if let timerEndDate = state.timerEndDate {
            return AnyView(
                Text(timerInterval: Date.now...timerEndDate, countsDown: true)
                    .font(.caption2.monospacedDigit())
            )
        }
        return AnyView(
            Group {
                if state.sessionState == .activeLogging {
                    Text("Live")
                } else {
                    Image(systemName: "ellipsis.circle.fill")
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(state.sessionState == .activeLogging ? Color.accentColor : .orange)
        )
    }

    private func deepLinkURL(for state: WorkoutLiveActivityAttributes.ContentState) -> URL {
        var components = URLComponents()
        components.scheme = "fitnesstracker"
        components.host = "live"
        components.queryItems = [
            URLQueryItem(name: "exercise", value: state.deepLinkExerciseName),
            URLQueryItem(name: "state", value: state.sessionState.rawValue)
        ]
        if let url = components.url {
            return url
        }
        return URL(string: "fitnesstracker://add") ?? URL(fileURLWithPath: "/")
    }
}
