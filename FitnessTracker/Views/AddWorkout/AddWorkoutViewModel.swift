import Foundation
import SwiftUI
import Combine

struct StrengthSetData {
    var weightInLbs: Double
    var reps: Int
    var restSeconds: Int?
    var rpe: Int?
}

private struct FocusIndex: Equatable, Hashable {
    var setNum: Int
    var type: RecordType

    static let initial = FocusIndex(setNum: 0, type: .weight)

    func next() -> FocusIndex {
        var nextSetNum = setNum
        var nextType = type
        if type == .rep {
            nextSetNum += 1
            nextType = .weight
        } else {
            nextType = .rep
        }
        return Self.init(setNum: nextSetNum, type: nextType)
    }
}


class AddWorkoutViewModel: ObservableObject {

    @Published var editMode: NumberEditMode = .overwrite

    var showingSetLogger = false

    @Binding var isPresented: Bool

    @Published var selectedExercise: String = "" {
        didSet {
            if !selectedExercise.isEmpty {
                sets = lastExerciseSession() ?? [StrengthSetData(weightInLbs: 0, reps: 0)]
                showingSetLogger = true
            }
        }
    }

    @Published var sets: [StrengthSetData] = []

    @Injected private var exerciseService: ExerciseService

    private var currentFocusIndexState: FocusIndex? = .initial {
        didSet {
            editMode = .overwrite
        }
    }

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    func saveWorkout() {
        let exercise = Exercise(
            name: selectedExercise,
            type: .strength,
            sets: sets.map {
                StrengthSet(weightInLbs: $0.weightInLbs, reps: $0.reps, restSeconds: $0.restSeconds, rpe: $0.rpe)
            }
        )
        exerciseService.addExercise(exercise)
        isPresented = false
    }

    func getExerciseSuggestions(name: String) -> [String] {
        return exerciseService.getExerciseSuggestions(exerciseName: name)
    }

    func generateWeightAndSetSuggestion() {
        // todo: Add some UI for loading state, and maybe separate into a view model as this view is getting big
        guard sets.first?.weightInLbs == 0.0 else {
            return
        }
        Task { @MainActor in
            let recommender = SuggestFirstSet(userWeight: 155, userHeight: "5 foot 7", workoutName: selectedExercise)
            if let content = try? await recommender.respond().content {
                sets[0].weightInLbs = Double(content.warmupWeight)
                sets[0].reps = content.warmupReps
                
                for _ in 0..<content.setCount {
                    sets.append(StrengthSetData(weightInLbs: Double(content.terminalWeight), reps: Int(content.terminalReps)))
                }
            }
        }
    }

    var isFocused: Bool {
        currentFocusIndexState != nil
    }

    var focusedFieldType: RecordType? {
        return currentFocusIndexState?.type
    }

    func isFocused(at setNum: Int, type: RecordType) -> Bool {
        currentFocusIndexState == FocusIndex(setNum: setNum, type: type)
    }

    func isFocusedAndOverwriteEnabled(at setNum: Int, type: RecordType) -> Bool {
        currentFocusIndexState == FocusIndex(setNum: setNum, type: type) && editMode == .overwrite
    }

    func setFocus(setNum: Int, type: RecordType) {
        currentFocusIndexState = FocusIndex(setNum: setNum, type: type)
    }

    func setFocusOnNext() {
        let nextFocus = currentFocusIndexState?.next()
        withAnimation {
            currentFocusIndexState = nextFocus
        }
        if let currentFocusIndexState,
           currentFocusIndexState.setNum + 1 > sets.count
        {
            addSet()
        }
    }

    func deleteSet(at offsets: IndexSet) {
        withAnimation {
            sets.remove(atOffsets: offsets)
        }
    }

    func addSet() {
        let lastSet = sets.last
        withAnimation {
            sets.append(StrengthSetData(weightInLbs: lastSet?.weightInLbs ?? 0, reps: lastSet?.reps ?? 0))
        }
    }

    func loseFoucs() {
        currentFocusIndexState = nil
    }

    var numberPadValueBinding: Binding<Int>? {
        guard let currentFocusIndexState else {
            return nil
        }
        return Binding<Int>(
            get: { [weak self] in
                guard let self else {
                    return 0
                }
                let set = sets[currentFocusIndexState.setNum]
                return currentFocusIndexState.type == .weight ? Int(set.weightInLbs) : set.reps
            },
            set: { [weak self] value in
                if currentFocusIndexState.type == .weight {
                    self?.sets[currentFocusIndexState.setNum].weightInLbs = Double(value)
                } else {
                    self?.sets[currentFocusIndexState.setNum].reps = value
                }
            })
    }

    private func lastExerciseSession() -> [StrengthSetData]? {
        if let lastExercise = exerciseService.lastExerciseSession(matching: selectedExercise)
        {
            return lastExercise.sets?.map { StrengthSetData(weightInLbs: $0.weightInLbs, reps: $0.reps)}
        }
        return nil
    }

}
