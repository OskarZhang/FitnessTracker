import ActivityKit
import Foundation

@MainActor
final class WorkoutLiveActivityService {
    private var currentActivity: Activity<WorkoutLiveActivityAttributes>?
    private let exerciseService: ExerciseService
    private let healthKitManager: HealthKitManager

    init(exerciseService: ExerciseService, healthKitManager: HealthKitManager) {
        self.exerciseService = exerciseService
        self.healthKitManager = healthKitManager
        currentActivity = Activity<WorkoutLiveActivityAttributes>.activities.first
    }

    func startOrUpdateForLogging(exerciseName: String) {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let now = Date()
        if let currentActivity {
            let nextState = WorkoutLiveActivityAttributes.ContentState(
                sessionState: .activeLogging,
                displayExerciseName: trimmed,
                timerEndDate: nil,
                suggestedExerciseName: nil,
                deepLinkExerciseName: trimmed,
                sessionStartDate: currentActivity.content.state.sessionStartDate,
                lastInteractionDate: now
            )
            update(currentActivity: currentActivity, with: nextState)
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WorkoutLiveActivityAttributes(workoutSessionID: UUID().uuidString)
        let state = WorkoutLiveActivityAttributes.ContentState(
            sessionState: .activeLogging,
            displayExerciseName: trimmed,
            timerEndDate: nil,
            suggestedExerciseName: nil,
            deepLinkExerciseName: trimmed,
            sessionStartDate: now,
            lastInteractionDate: now
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
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
    }

    func showPostWorkoutPrompt(afterSavedExercise exerciseName: String) {
        guard let currentActivity else { return }

        let nextExercise = exerciseService.nextLikelyExercise(after: exerciseName)
        let deepLinkExercise = nextExercise ?? exerciseName
        let now = Date()
        var nextState = currentActivity.content.state
        nextState.sessionState = .needsPostWorkoutPrompt
        nextState.displayExerciseName = exerciseName
        nextState.suggestedExerciseName = nextExercise
        nextState.deepLinkExerciseName = deepLinkExercise
        nextState.timerEndDate = nil
        nextState.lastInteractionDate = now
        update(currentActivity: currentActivity, with: nextState)
    }

    func recordInteraction() {
        guard let currentActivity else { return }
        var nextState = currentActivity.content.state
        nextState.lastInteractionDate = Date()
        update(currentActivity: currentActivity, with: nextState)
    }

    func endNow() {
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

    func endSessionAndLogToHealthKit() async {
        guard let currentActivity else { return }
        let finalState = currentActivity.content.state

        let sessionExercises = exerciseService.exercises.filter { exercise in
            exercise.date >= finalState.sessionStartDate
        }

        if !sessionExercises.isEmpty,
           healthKitManager.isAvailable
        {
            healthKitManager.refreshAuthorizationStatus()
            if healthKitManager.workoutAuthorizationStatus == .sharingAuthorized {
                do {
                    try await healthKitManager.writeStrengthWorkout(exercises: sessionExercises)
                } catch {
                    print("Failed to export workout session to HealthKit: \(error)")
                }
            }
        }

        await currentActivity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        self.currentActivity = nil
    }

    private func update(
        currentActivity: Activity<WorkoutLiveActivityAttributes>,
        with state: WorkoutLiveActivityAttributes.ContentState
    ) {
        Task {
            await currentActivity.update(
                ActivityContent(state: state, staleDate: nil)
            )
        }
    }
}
