import Foundation
import SwiftUI

@MainActor
class AddWorkoutViewModel: ObservableObject {

    @Published var showingSetLogger = false

    @Published var selectedExercise: String = "" {
        didSet {
            guard !selectedExercise.isEmpty else { return }
            guard !isRestoringPendingSession else { return }
            startLogging(exerciseName: selectedExercise, pendingSession: nil)
        }
    }

    @Published var setLoggingViewModel: SetLoggingViewModel?

    private let exerciseService: any ExerciseServing
    private let healthKitManager: any HealthKitManaging

    private var isRestoringPendingSession = false

    init(
        exerciseService: any ExerciseServing,
        healthKitManager: any HealthKitManaging
    ) {
        self.exerciseService = exerciseService
        self.healthKitManager = healthKitManager
        restorePendingSessionIfNeeded()
    }

    func getExerciseSuggestions(name: String) -> [String] {
        return exerciseService.getExerciseSuggestions(exerciseName: name)
    }

    private func restorePendingSessionIfNeeded() {
        guard SetLoggingSessionStore.consumeRestoreRequest() else { return }
        guard let pendingSession = SetLoggingSessionStore.load() else { return }
        isRestoringPendingSession = true
        selectedExercise = pendingSession.exerciseName
        startLogging(exerciseName: pendingSession.exerciseName, pendingSession: pendingSession)
        isRestoringPendingSession = false
    }

    private func startLogging(exerciseName: String, pendingSession: PendingSetLoggingSession?) {
        setLoggingViewModel = SetLoggingViewModel(
            mode: .add(exerciseName: exerciseName, pendingSession: pendingSession),
            exerciseService: exerciseService,
            healthKitManager: healthKitManager
        )
        showingSetLogger = true
    }
}
