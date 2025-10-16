import Foundation
import Combine

class AddWorkoutViewModel: ObservableObject {
    @Published var selectedExercise: String? {
        didSet {
            if selectedExercise != nil && !hasPrefilledExercise {
                isShowingSetLogging = true
            }
        }
    }
    @Published var sets: [StrengthSet] = []

    @Published var isShowingSetLogging = false
    
    let hasPrefilledExercise: Bool

    private let exerciseService: ExerciseService

    init(exerciseService: ExerciseService, prefilledExerciseName: String? = nil) {
        self.exerciseService = exerciseService
        self.hasPrefilledExercise = prefilledExerciseName != nil
        self.selectedExercise = prefilledExerciseName
    }

    func saveWorkout() {
        guard let selectedExercise else {
            return
        }
        let exercise = Exercise(
            name: selectedExercise,
            type: .strength,
            sets: sets
        )
        exerciseService.addExercise(exercise)
    }

    func lastExerciseSession() -> [StrengthSet]? {
        if let selectedExercise,
           let lastExercise = exerciseService.lastExerciseSession(matching: selectedExercise)
        {
            return lastExercise.sets
        }
        return nil
    }

    func matchExercise(name: String) -> [Exercise] {
        return exerciseService.getWorkoutSuggestion(exerciseName: name)
    }
}
