import ActivityKit
import Foundation

@MainActor
final class WorkoutStopwatchLiveActivityController {
    static let shared = WorkoutStopwatchLiveActivityController()

    private var currentActivityID: String?

    private init() {}

    func restartStopwatch(
        exerciseName: String,
        completedSetCount: Int,
        startedAt: Date
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let content = ActivityContent(
            state: WorkoutStopwatchAttributes.ContentState(
                stopwatchStartedAt: startedAt,
                completedSetCount: completedSetCount
            ),
            staleDate: nil
        )

        Task { @MainActor in
            if let activity = currentActivity(for: exerciseName) {
                await activity.update(content)
                currentActivityID = activity.id
                return
            }

            do {
                let activity = try Activity.request(
                    attributes: WorkoutStopwatchAttributes(exerciseName: exerciseName),
                    content: content,
                    pushType: nil
                )
                currentActivityID = activity.id
            } catch {
                currentActivityID = nil
            }
        }
    }

    func stopStopwatch() {
        Task { @MainActor in
            for activity in Activity<WorkoutStopwatchAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            currentActivityID = nil
        }
    }

    private func currentActivity(for exerciseName: String) -> Activity<WorkoutStopwatchAttributes>? {
        if let currentActivityID,
           let activity = Activity<WorkoutStopwatchAttributes>.activities.first(where: { $0.id == currentActivityID }) {
            return activity
        }

        return Activity<WorkoutStopwatchAttributes>.activities.first {
            $0.attributes.exerciseName == exerciseName
        }
    }
}
