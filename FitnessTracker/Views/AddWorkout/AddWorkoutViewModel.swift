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

    @Injected private var exerciseService: ExerciseService

    private var isRestoringPendingSession = false
    private var pendingInitialExerciseToStart: String?

    init(initialExerciseName: String? = nil) {
        if let initialExerciseName {
            let trimmed = initialExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                selectedExercise = trimmed
                pendingInitialExerciseToStart = trimmed
                return
            }
        }
        restorePendingSessionIfNeeded()
    }

    func onViewAppear() {
        if let pendingInitialExerciseToStart {
            startLogging(exerciseName: pendingInitialExerciseToStart, pendingSession: nil)
            self.pendingInitialExerciseToStart = nil
            return
        }
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
            mode: .add(exerciseName: exerciseName, pendingSession: pendingSession)
        )
        showingSetLogger = true
    }
}
