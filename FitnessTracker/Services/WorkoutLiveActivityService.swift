import ActivityKit
import Foundation

@MainActor
final class WorkoutLiveActivityService {
    private let inactivityInterval: TimeInterval = 20 * 60
    private var currentActivity: Activity<WorkoutLiveActivityAttributes>?
    private var inactivityTask: Task<Void, Never>?
    private let exerciseService: ExerciseService

    init(exerciseService: ExerciseService) {
        self.exerciseService = exerciseService
        currentActivity = Activity<WorkoutLiveActivityAttributes>.activities.first
        scheduleInactivityCheck()
    }

    func startOrUpdateForLogging(exerciseName: String) {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let now = Date()
        if let currentActivity {
            let nextState = WorkoutLiveActivityAttributes.ContentState(
                displayExerciseName: trimmed,
                timerEndDate: nil,
                nextLikelyExerciseName: nil,
                deepLinkExerciseName: trimmed,
                lastInteractionDate: now
            )
            update(currentActivity: currentActivity, with: nextState)
            scheduleInactivityCheck()
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WorkoutLiveActivityAttributes(workoutSessionID: UUID().uuidString)
        let state = WorkoutLiveActivityAttributes.ContentState(
            displayExerciseName: trimmed,
            timerEndDate: nil,
            nextLikelyExerciseName: nil,
            deepLinkExerciseName: trimmed,
            lastInteractionDate: now
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: now.addingTimeInterval(inactivityInterval))
            )
            scheduleInactivityCheck()
        } catch {
            print("Failed to start workout live activity: \(error)")
        }
    }

    func updateTimer(endDate: Date?) {
        guard let currentActivity else { return }
        var nextState = currentActivity.content.state
        nextState.timerEndDate = endDate
        nextState.lastInteractionDate = Date()
        update(currentActivity: currentActivity, with: nextState)
        scheduleInactivityCheck()
    }

    func showNextLikely(afterSavedExercise exerciseName: String) {
        guard let currentActivity else { return }

        let nextExercise = exerciseService.nextLikelyExercise(after: exerciseName)
        let deepLinkExercise = nextExercise ?? exerciseName
        let now = Date()
        var nextState = currentActivity.content.state
        nextState.displayExerciseName = deepLinkExercise
        nextState.nextLikelyExerciseName = nextExercise
        nextState.deepLinkExerciseName = deepLinkExercise
        nextState.timerEndDate = nil
        nextState.lastInteractionDate = now
        update(currentActivity: currentActivity, with: nextState)
        scheduleInactivityCheck()
    }

    func recordInteraction() {
        guard let currentActivity else { return }
        var nextState = currentActivity.content.state
        nextState.lastInteractionDate = Date()
        update(currentActivity: currentActivity, with: nextState)
        scheduleInactivityCheck()
    }

    func endIfInactive() {
        guard let currentActivity else { return }
        let deadline = currentActivity.content.state.lastInteractionDate.addingTimeInterval(inactivityInterval)
        if Date() >= deadline {
            endNow()
        } else {
            scheduleInactivityCheck()
        }
    }

    func endNow() {
        inactivityTask?.cancel()
        inactivityTask = nil

        guard let currentActivity else { return }
        let finalState = currentActivity.content.state
        Task {
            await currentActivity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        self.currentActivity = nil
    }

    private func update(
        currentActivity: Activity<WorkoutLiveActivityAttributes>,
        with state: WorkoutLiveActivityAttributes.ContentState
    ) {
        Task {
            await currentActivity.update(
                ActivityContent(state: state, staleDate: state.lastInteractionDate.addingTimeInterval(inactivityInterval))
            )
        }
    }

    private func scheduleInactivityCheck() {
        inactivityTask?.cancel()
        guard let currentActivity else { return }

        let deadline = currentActivity.content.state.lastInteractionDate.addingTimeInterval(inactivityInterval)
        let delay = max(1, deadline.timeIntervalSinceNow)

        inactivityTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.endIfInactive()
        }
    }
}
