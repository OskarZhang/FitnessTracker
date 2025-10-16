import Foundation
import SwiftUI
import Combine

struct StrengthSetData {
    var weightInLbs: Double
    var reps: Int
    var restSeconds: Int?
    var rpe: Int?

}

class AddWorkoutViewModel: ObservableObject {

    enum State: String, Hashable {
        case picker
        case logger
    }
    var showingSetLogger = false

    @Published var selectedExercise: String? {
        didSet {
            if selectedExercise != nil {
                showingSetLogger = true
            }
        }
    }
    @Published var sets: [StrengthSetData] = []

    @Injected private var exerciseService: ExerciseService

    func saveWorkout() {
        guard let selectedExercise else {
            return
        }
        let exercise = Exercise(
            name: selectedExercise,
            type: .strength,
            sets: sets.map {
                StrengthSet(weightInLbs: $0.weightInLbs, reps: $0.reps, restSeconds: $0.restSeconds, rpe: $0.rpe)
            }
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

    func getExerciseSuggestions(name: String) -> [String] {
        return exerciseService.getExerciseSuggestions(exerciseName: name)
    }
}
