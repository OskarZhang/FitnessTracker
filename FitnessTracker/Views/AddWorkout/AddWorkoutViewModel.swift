import Foundation
import SwiftUI
import Combine

struct StrengthSetData {
	let id: UUID = UUID()
    var weightInLbs: Double
    var reps: Int
    var restSeconds: Int?
    var rpe: Int?
    var isCompleted: Bool = false
}

struct FocusIndex: Equatable, Hashable {
    var setIndex: Int
    var type: RecordType

    static let initial = FocusIndex(setIndex: 0, type: .weight)

    func next() -> FocusIndex {
        var nextsetIndex = setIndex
        var nextType = type
        if type == .rep {
            nextsetIndex += 1
            nextType = .weight
        } else {
            nextType = .rep
        }
        return Self.init(setIndex: nextsetIndex, type: nextType)
    }
}

@MainActor
class AddWorkoutViewModel: ObservableObject {

    @Published var editMode: NumberEditMode = .overwrite

    var showingSetLogger = false

    @Binding var isPresented: Bool

    @Published var selectedExercise: String = "" {
        didSet {
            if !selectedExercise.isEmpty {
                sets = lastExerciseSession() ?? []
                showingSetLogger = true
            }
        }
    }

    @Published var sets: [StrengthSetData] = []

    @Published var isGeneratingRecommendations = false
    
    var hasSeenNewExerciseOnboarding = false

    @Injected private var exerciseService: ExerciseService

    @Published var currentFocusIndexState: FocusIndex? = nil {
        didSet {
            editMode = .overwrite
        }
    }
    
    @Published var showNewExerciseOnboarding: Bool = false

	var timer: Timer?
	@Published var timerPercentage: CGFloat = 0.0
	@Published var activeTimerSetId: UUID?

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    func saveWorkout() {
        let exercise = Exercise(
            name: selectedExercise,
            type: .strength,
            sets: sets.filter { $0.isCompleted }.map {
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
        isGeneratingRecommendations = true
        Task {
            let recommender = SuggestFullSetForExercise(userWeight: 155, userHeight: "5 foot 7", workoutName: selectedExercise)
            guard let content = try? await recommender.respond().content else {
                await MainActor.run {
                    isGeneratingRecommendations = false
                }
                return
            }

            await MainActor.run {
                sets = []
                sets.append(
                    StrengthSetData(weightInLbs: Double(content.warmupWeight), reps: Int(content.warmupReps))
                )
                
                withAnimation {
                    currentFocusIndexState = .initial
                }

                for _ in 0..<content.setCount {
                    sets.append(StrengthSetData(weightInLbs: Double(content.terminalWeight), reps: Int(content.terminalReps)))
                }

                isGeneratingRecommendations = false
            }
        }
    }

    var isFocused: Bool {
        currentFocusIndexState != nil
    }

	var hasCompletedAnySet: Bool { sets.first { $0.isCompleted } != nil }

    func toggleSetCompletion(setIndex: Int) {
        let isCompleted = sets[setIndex].isCompleted
        withAnimation {
            sets[setIndex].isCompleted = !isCompleted
        }
    }

    var focusedFieldType: RecordType? {
        return currentFocusIndexState?.type
    }

    func isFocused(at setIndex: Int, type: RecordType) -> Bool {
        currentFocusIndexState == FocusIndex(setIndex: setIndex, type: type)
    }

    func isFocusedAndOverwriteEnabled(at setIndex: Int, type: RecordType) -> Bool {
        currentFocusIndexState == FocusIndex(setIndex: setIndex, type: type) && editMode == .overwrite
    }

    func setFocus(setIndex: Int, type: RecordType) {
        assert(setIndex < sets.count)
        withAnimation {
            currentFocusIndexState = FocusIndex(setIndex: setIndex, type: type)
        }
    }

	func startTimer() {
		// grab the last set index that is completed
		let completedSet = sets.last { $0.isCompleted }
		guard let completedSet else { return }
		activeTimerSetId = completedSet.id
		timerPercentage = 1.0
		timer?.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true, block: { [weak self] _ in
			DispatchQueue.main.async {
				guard let self else { return }
				if self.timerPercentage <= 0.0 {
					self.timer?.invalidate()
					self.timer = nil
					self.activeTimerSetId = nil
				} else {
					self.timerPercentage = max(0, self.timerPercentage - 1.0 / 60.0 / 120.0)
				}
			}
		})

	}

    func onNumberPadReturn() {
        let nextFocus = currentFocusIndexState?.next()
        withAnimation {
            if currentFocusIndexState?.type == .rep,
               let setIndex = currentFocusIndexState?.setIndex
            {
                sets[setIndex].isCompleted = true
            }
            currentFocusIndexState = nextFocus
        }
        if let currentFocusIndexState,
           currentFocusIndexState.setIndex + 1 > sets.count
        {
            addSet()
        }
    }

    func deleteSet(at offsets: IndexSet) {
        withAnimation {
            currentFocusIndexState = nil
            sets.remove(atOffsets: offsets)
        }
    }

    func addSet() {
        let lastSet = sets.last
        withAnimation {
            sets.append(StrengthSetData(weightInLbs: lastSet?.weightInLbs ?? 0, reps: lastSet?.reps ?? 0))
        }
    }

    func loseFocus() {
        withAnimation {
            currentFocusIndexState = nil
        }
    }
    
    func onAppear() {
        showNewExerciseOnboarding = !hasSeenNewExerciseOnboarding && (lastExerciseSession()?.isEmpty ?? true)
        if !showNewExerciseOnboarding,
           sets.count > 0
        {
            // auto-focus at 0,0
            currentFocusIndexState = .initial
        }
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
                let set = sets[currentFocusIndexState.setIndex]
                return currentFocusIndexState.type == .weight ? Int(set.weightInLbs) : set.reps
            },
            set: { [weak self] value in
                if currentFocusIndexState.type == .weight {
                    self?.sets[currentFocusIndexState.setIndex].weightInLbs = Double(value)
                } else {
                    self?.sets[currentFocusIndexState.setIndex].reps = value
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
