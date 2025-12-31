import Foundation
import SwiftUI

struct StrengthSetData: Identifiable, Codable {
    let id: UUID
    var weightInLbs: Double
    var reps: Int
    var restSeconds: Int?
    var rpe: Int?
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        weightInLbs: Double,
        reps: Int,
        restSeconds: Int? = nil,
        rpe: Int? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.weightInLbs = weightInLbs
        self.reps = reps
        self.restSeconds = restSeconds
        self.rpe = rpe
        self.isCompleted = isCompleted
    }
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

enum SetLoggingMode {
    case add(exerciseName: String, pendingSession: PendingSetLoggingSession?)
    case edit(exercise: Exercise)
}

struct PendingStrengthSetData: Codable {
    let id: UUID
    var weightInLbs: Double
    var reps: Int
    var restSeconds: Int?
    var rpe: Int?
    var isCompleted: Bool
}

struct PendingSetLoggingSession: Codable {
    let exerciseName: String
    let sets: [PendingStrengthSetData]
    let hasSeenNewExerciseOnboarding: Bool
    let showNewExerciseOnboarding: Bool
    let isNewExercise: Bool
}

enum SetLoggingSessionStore {
    private static let pendingSessionKey = "pendingSetLoggingSession"

    static func load() -> PendingSetLoggingSession? {
        guard let data = UserDefaults.standard.data(forKey: pendingSessionKey) else {
            return nil
        }
        return try? JSONDecoder().decode(PendingSetLoggingSession.self, from: data)
    }

    static func save(_ session: PendingSetLoggingSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: pendingSessionKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: pendingSessionKey)
    }

    static var hasPendingSession: Bool {
        load() != nil
    }
}

@MainActor
class SetLoggingViewModel: ObservableObject {

    @Published var editMode: NumberEditMode = .overwrite

    @Published var selectedExercise: String = ""

    @Published var sets: [StrengthSetData] = [] {
        didSet {
            persistPendingSessionIfNeeded()
        }
    }

    @Published var isGeneratingRecommendations = false

    @Published var currentFocusIndexState: FocusIndex? = nil {
        didSet {
            editMode = .overwrite
        }
    }

    @Published var showNewExerciseOnboarding: Bool = false {
        didSet {
            persistPendingSessionIfNeeded()
        }
    }

    var hasSeenNewExerciseOnboarding: Bool = false {
        didSet {
            persistPendingSessionIfNeeded()
        }
    }

    private let mode: SetLoggingMode
    private var shouldPersistPendingSession = false

    private var timerEndTime: Date?

    @Injected private var exerciseService: ExerciseService

    init(mode: SetLoggingMode) {
        self.mode = mode

        switch mode {
        case .add(let exerciseName, let pendingSession):
            selectedExercise = exerciseName

            if let pendingSession {
                sets = pendingSession.sets.map { StrengthSetData(pendingData: $0) }
                hasSeenNewExerciseOnboarding = pendingSession.hasSeenNewExerciseOnboarding
                showNewExerciseOnboarding = pendingSession.showNewExerciseOnboarding
                shouldPersistPendingSession = pendingSession.isNewExercise
            } else {
                let lastSession = exerciseService.lastExerciseSession(matching: exerciseName)
                sets = lastSession?.sets?.map {
                    StrengthSetData(weightInLbs: $0.weightInLbs, reps: $0.reps)
                } ?? []
                let isNewExercise = lastSession?.sets?.isEmpty ?? true
                hasSeenNewExerciseOnboarding = false
                showNewExerciseOnboarding = false
                shouldPersistPendingSession = isNewExercise
                persistPendingSessionIfNeeded()
            }
        case .edit(let exercise):
            selectedExercise = exercise.name
            sets = exercise.sets?.map {
                StrengthSetData(weightInLbs: $0.weightInLbs, reps: $0.reps, isCompleted: true)
            } ?? []
            hasSeenNewExerciseOnboarding = true
            showNewExerciseOnboarding = false
            shouldPersistPendingSession = false
        }
    }

    func saveWorkout() {
        switch mode {
        case .add:
            let exercise = Exercise(
                name: selectedExercise,
                type: .strength,
                sets: sets.filter { $0.isCompleted }.map {
                    StrengthSet(weightInLbs: $0.weightInLbs, reps: $0.reps, restSeconds: $0.restSeconds, rpe: $0.rpe)
                }
            )
            exerciseService.addExercise(exercise)
            SetLoggingSessionStore.clear()
        case .edit(let exercise):
            let updatedSets = sets.filter { $0.isCompleted }.map {
                StrengthSet(weightInLbs: $0.weightInLbs, reps: $0.reps, restSeconds: $0.restSeconds, rpe: $0.rpe)
            }
            exerciseService.updateExercise(exercise, sets: updatedSets)
        }
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
        timerEndTime = Date().advanced(by: 60)
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
            var focusedIndexId: UUID?
            if let focusedIndex = currentFocusIndexState?.setIndex
            {
                if offsets.contains(focusedIndex) {
                    currentFocusIndexState = nil
                } else {
                    focusedIndexId = sets[focusedIndex].id
                }

            }
            sets.remove(atOffsets: offsets)
            if let setIndex = sets.firstIndex(where: { $0.id == focusedIndexId }),
               let prevFocusedType = currentFocusIndexState?.type {
                currentFocusIndexState = .init(setIndex: setIndex, type: prevFocusedType)
            }

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

    func markOnboardingSeen() {
        hasSeenNewExerciseOnboarding = true
        showNewExerciseOnboarding = false
    }

    func onAppear() {
        if showNewExerciseOnboarding {
            return
        }
        if shouldPersistPendingSession && !hasSeenNewExerciseOnboarding {
            showNewExerciseOnboarding = true
        } else if sets.count > 0 {
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

    var timerPercentage: Double {
        guard let timerEndTime = self.timerEndTime else { return 0 }
        let timerPercentage: Double
        if Date() >= timerEndTime {
            self.timerEndTime = nil
            return 0.0
        } else {
            return timerEndTime.timeIntervalSince(Date()) / 60.0
        }
    }

    var timeInSecLeft: Int {
        return Int(timerPercentage * 60)
    }

    func persistPendingSessionIfNeeded() {
        guard shouldPersistPendingSession else { return }
        guard case .add = mode else { return }

        let session = PendingSetLoggingSession(
            exerciseName: selectedExercise,
            sets: sets.map { $0.pendingData },
            hasSeenNewExerciseOnboarding: hasSeenNewExerciseOnboarding,
            showNewExerciseOnboarding: showNewExerciseOnboarding,
            isNewExercise: shouldPersistPendingSession
        )
        SetLoggingSessionStore.save(session)
    }
}

private extension StrengthSetData {
    init(pendingData: PendingStrengthSetData) {
        self.init(
            id: pendingData.id,
            weightInLbs: pendingData.weightInLbs,
            reps: pendingData.reps,
            restSeconds: pendingData.restSeconds,
            rpe: pendingData.rpe,
            isCompleted: pendingData.isCompleted
        )
    }

    var pendingData: PendingStrengthSetData {
        PendingStrengthSetData(
            id: id,
            weightInLbs: weightInLbs,
            reps: reps,
            restSeconds: restSeconds,
            rpe: rpe,
            isCompleted: isCompleted
        )
    }
}

extension SetLoggingViewModel {
    static var mocked: SetLoggingViewModel {
        let viewModel = SetLoggingViewModel(mode: .add(exerciseName: "Bench Press", pendingSession: nil))
        viewModel.sets = [
            StrengthSetData(weightInLbs: 200, reps: 10),
            StrengthSetData(weightInLbs: 200, reps: 10),
            StrengthSetData(weightInLbs: 200, reps: 10)
        ]
        viewModel.hasSeenNewExerciseOnboarding = true
        return viewModel
    }
}
