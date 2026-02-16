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
    let isNewExercise: Bool
    // Legacy fields retained for backward-compatible decoding of old sessions.
    let hasSeenNewExerciseOnboarding: Bool?
    let showNewExerciseOnboarding: Bool?

    init(
        exerciseName: String,
        sets: [PendingStrengthSetData],
        isNewExercise: Bool,
        hasSeenNewExerciseOnboarding: Bool? = nil,
        showNewExerciseOnboarding: Bool? = nil
    ) {
        self.exerciseName = exerciseName
        self.sets = sets
        self.isNewExercise = isNewExercise
        self.hasSeenNewExerciseOnboarding = hasSeenNewExerciseOnboarding
        self.showNewExerciseOnboarding = showNewExerciseOnboarding
    }
}

enum AISuggestionInsertionMode {
    case replace
    case append
}

enum SetLoggingSessionStore {
    private static let pendingSessionKey = "pendingSetLoggingSession"
    private static let restoreOnNextLaunchKey = "pendingSetLoggingSession.restoreOnNextLaunch"
    // Restore intent is owned by active add-session logging flow.
    // Only SetLoggingView should request restore after persisting a pending add session.

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
        UserDefaults.standard.removeObject(forKey: restoreOnNextLaunchKey)
    }

    static var hasPendingSession: Bool {
        load() != nil
    }

    static var shouldRestoreOnNextLaunch: Bool {
        UserDefaults.standard.bool(forKey: restoreOnNextLaunchKey) && hasPendingSession
    }

    static func requestRestoreOnNextLaunch() {
        guard hasPendingSession else { return }
        UserDefaults.standard.set(true, forKey: restoreOnNextLaunchKey)
    }

    static func clearRestoreRequest() {
        UserDefaults.standard.removeObject(forKey: restoreOnNextLaunchKey)
    }

    static func consumeRestoreRequest() -> Bool {
        guard shouldRestoreOnNextLaunch else { return false }
        clearRestoreRequest()
        return true
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

    private let mode: SetLoggingMode
    private var shouldPersistPendingSession = false

    @Published private var timerEndTime: Date?
    private var timerSyncTask: Task<Void, Never>?
    private let shouldRelaxCompletionRequirementForUITests =
        ProcessInfo.processInfo.arguments.contains("UI_TEST_SKIP_FIRST_TIME_PROMPT")

    @Injected private var exerciseService: ExerciseService
    @Injected private var healthKitManager: HealthKitManager
    @Injected private var workoutLiveActivityService: WorkoutLiveActivityService

    init(mode: SetLoggingMode) {
        self.mode = mode

        switch mode {
        case .add(let exerciseName, let pendingSession):
            selectedExercise = exerciseName

            if let pendingSession {
                sets = pendingSession.sets.map { StrengthSetData(pendingData: $0) }
                shouldPersistPendingSession = pendingSession.isNewExercise
            } else {
                let lastSession = exerciseService.lastExerciseSession(matching: exerciseName)
                sets = lastSession?.orderedStrengthSets.map {
                    StrengthSetData(weightInLbs: $0.weightInLbs, reps: $0.reps)
                } ?? []
                let isNewExercise = lastSession?.orderedStrengthSets.isEmpty ?? true
                shouldPersistPendingSession = isNewExercise
                persistPendingSessionIfNeeded()
            }
        case .edit(let exercise):
            selectedExercise = exercise.name
            sets = exercise.orderedStrengthSets.map {
                StrengthSetData(weightInLbs: $0.weightInLbs, reps: $0.reps, isCompleted: true)
            }
            shouldPersistPendingSession = false
        }
    }

    func saveWorkout() {
        switch mode {
        case .add:
            let exercise = Exercise(
                name: selectedExercise,
                type: .strength,
                strengthSets: sets
                    .filter { $0.isCompleted }
                    .map { set in
                        StrengthSet(
                            weightInLbs: set.weightInLbs,
                            reps: set.reps,
                            restSeconds: set.restSeconds,
                            rpe: set.rpe
                        )
                }
            )
            exerciseService.addExercise(exercise)
            SetLoggingSessionStore.clear()
            workoutLiveActivityService.showPostWorkoutPrompt(afterSavedExercise: selectedExercise)
        case .edit(let exercise):
            let updatedSets = sets
                .filter { $0.isCompleted }
                .map { set in
                    StrengthSet(
                        weightInLbs: set.weightInLbs,
                        reps: set.reps,
                        restSeconds: set.restSeconds,
                        rpe: set.rpe
                    )
            }
            exerciseService.updateExercise(exercise, sets: updatedSets)
        }
    }

    func getExerciseSuggestions(name: String) -> [String] {
        return exerciseService.getExerciseSuggestions(exerciseName: name)
    }

    var isInAddMode: Bool {
        if case .add = mode {
            return true
        }
        return false
    }

    var isEmptyStateForAIRecommendation: Bool {
        isInAddMode && sets.isEmpty
    }

    var shouldShowAIToolbarButton: Bool {
        isInAddMode && !sets.isEmpty
    }

    func generateSuggestedSetForEmptyState() {
        generateWeightAndSetSuggestion(insertionMode: .replace)
    }

    func generateWeightAndSetSuggestion(insertionMode: AISuggestionInsertionMode) {
        guard !isGeneratingRecommendations else { return }
        isGeneratingRecommendations = true
        Task { [weak self] in
            guard let self else { return }
            let userWeight = await self.resolveUserWeightInLbs()
            let recommender = SuggestFullSetForExercise(
                userWeight: userWeight,
                userHeight: "5 foot 7",
                workoutName: self.selectedExercise
            )
            guard let content = try? await recommender.respond().content else {
                await MainActor.run {
                    self.isGeneratingRecommendations = false
                }
                return
            }

            await MainActor.run {
                self.applyRecommendation(content, insertionMode: insertionMode)
                self.isGeneratingRecommendations = false
            }
        }
    }

    private func resolveUserWeightInLbs() async -> Int {
        guard let weight = await healthKitManager.mostRecentBodyMassInPounds() else {
            return 155
        }
        return max(1, Int(weight.rounded()))
    }

    private func applyRecommendation(
        _ recommendation: SetRecommendation,
        insertionMode: AISuggestionInsertionMode
    ) {
        var recommendedSets: [StrengthSetData] = [
            StrengthSetData(
                weightInLbs: Double(recommendation.warmupWeight),
                reps: Int(recommendation.warmupReps)
            )
        ]
        for _ in 0..<recommendation.setCount {
            recommendedSets.append(
                StrengthSetData(
                    weightInLbs: Double(recommendation.terminalWeight),
                    reps: Int(recommendation.terminalReps)
                )
            )
        }

        switch insertionMode {
        case .replace:
            sets = recommendedSets
        case .append:
            sets.append(contentsOf: recommendedSets)
        }

        if currentFocusIndexState == nil, !sets.isEmpty {
            withAnimation {
                currentFocusIndexState = .initial
            }
        }
    }

    var isFocused: Bool {
        currentFocusIndexState != nil
    }

    var hasCompletedAnySet: Bool {
        if shouldRelaxCompletionRequirementForUITests {
            return !sets.isEmpty
        }
        return sets.first { $0.isCompleted } != nil
    }

    func toggleSetCompletion(setIndex: Int) {
        let isCompleted = sets[setIndex].isCompleted
        withAnimation {
            sets[setIndex].isCompleted = !isCompleted
        }
        markLiveActivityInteractionIfNeeded()
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
        markLiveActivityInteractionIfNeeded()
    }

    func startTimer() {
        timerEndTime = Date().advanced(by: 60)
        workoutLiveActivityService.updateTimer(endDate: timerEndTime)
        markLiveActivityInteractionIfNeeded()

        timerSyncTask?.cancel()
        let expectedTimerEnd = timerEndTime
        timerSyncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 61_000_000_000)
            await MainActor.run {
                guard let self else { return }
                guard self.isAddMode else { return }
                guard let expectedTimerEnd else { return }
                if let timerEndTime = self.timerEndTime, timerEndTime <= Date(), timerEndTime == expectedTimerEnd {
                    self.workoutLiveActivityService.updateTimer(endDate: nil)
                }
            }
        }
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
        markLiveActivityInteractionIfNeeded()
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
        markLiveActivityInteractionIfNeeded()
    }

    func addSet() {
        let lastSet = sets.last
        withAnimation {
            sets.append(StrengthSetData(weightInLbs: lastSet?.weightInLbs ?? 0, reps: lastSet?.reps ?? 0))
        }
        markLiveActivityInteractionIfNeeded()
    }

    func loseFocus() {
        withAnimation {
            currentFocusIndexState = nil
        }
        markLiveActivityInteractionIfNeeded()
    }

    func onAppear() {
        if isAddMode {
            workoutLiveActivityService.startOrUpdateForLogging(exerciseName: selectedExercise)
            workoutLiveActivityService.recordInteraction()
        }
        if sets.count > 0 {
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
        guard Date() < timerEndTime else { return 0 }
        return timerEndTime.timeIntervalSince(Date()) / 60.0
    }

    var timeInSecLeft: Int {
        return Int(timerPercentage * 60)
    }

    var isTimerRunning: Bool {
        guard let timerEndTime else { return false }
        return Date() < timerEndTime
    }

    @discardableResult
    func persistPendingSessionIfNeeded() -> Bool {
        guard shouldPersistPendingSession else { return false }
        guard case .add = mode else { return false }

        let session = PendingSetLoggingSession(
            exerciseName: selectedExercise,
            sets: sets.map { $0.pendingData },
            isNewExercise: shouldPersistPendingSession
        )
        SetLoggingSessionStore.save(session)
        return true
    }

    private var isAddMode: Bool {
        if case .add = mode {
            return true
        }
        return false
    }

    private func markLiveActivityInteractionIfNeeded() {
        guard isAddMode else { return }
        workoutLiveActivityService.recordInteraction()
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
        return viewModel
    }
}
