import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FitnessTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutStopwatchLiveActivityWidget()
    }
}

struct WorkoutStopwatchLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutStopwatchAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.accentColor)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(context.state.completedSetCount)", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    elapsedText(from: context.state.stopwatchStartedAt)
                        .font(.headline.monospacedDigit())
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text("Rest stopwatch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "stopwatch.fill")
                    .foregroundStyle(.green)
            } compactTrailing: {
                elapsedText(from: context.state.stopwatchStartedAt)
                    .font(.caption2.monospacedDigit())
                    .frame(minWidth: 34, alignment: .trailing)
            } minimal: {
                Image(systemName: "stopwatch.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<WorkoutStopwatchAttributes>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "stopwatch.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.exerciseName)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(context.state.completedSetCount) sets logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            elapsedText(from: context.state.stopwatchStartedAt)
                .font(.title3.monospacedDigit().weight(.semibold))
        }
        .padding()
    }

    private func elapsedText(from startedAt: Date) -> Text {
        Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
    }
}
