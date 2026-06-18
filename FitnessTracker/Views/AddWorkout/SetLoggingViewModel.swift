import Foundation
import SwiftUI

@MainActor
protocol ExerciseServing: AnyObject {
    func addExercise(_ exercise: Exercise)
    func updateExercise(_ exercise: Exercise, sets: [StrengthSet], endedAt: Date)
    func getExerciseSuggestions(exerciseName: String) -> [String]
    func lastExerciseSession(matching name: String) -> Exercise?
}

extension ExerciseService: ExerciseServing {}

@MainActor
protocol HealthKitManaging: AnyObject {
    func mostRecentBodyMassInPounds() async -> Double?
}

extension HealthKitManager: HealthKitManaging {}

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
    let startedAt: Date?
    let stopwatchStartedAt: Date?
    // Legacy metadata retained for backward-compatible decoding.
    let isNewExercise: Bool
    // Legacy fields retained for backward-compatible decoding of old sessions.
    let hasSeenNewExerciseOnboarding: Bool?
    let showNewExerciseOnboarding: Bool?

    init(
        exerciseName: String,
        sets: [PendingStrengthSetData],
        startedAt: Date? = nil,
        stopwatchStartedAt: Date? = nil,
        isNewExercise: Bool,
        hasSeenNewExerciseOnboarding: Bool? = nil,
        showNewExerciseOnboarding: Bool? = nil
    ) {
        self.exerciseName = exerciseName
        self.sets = sets
        self.startedAt = startedAt
        self.stopwatchStartedAt = stopwatchStartedAt
        self.isNewExercise = isNewExercise
        self.hasSeenNewExerciseOnboarding = hasSeenNewExerciseOnboarding
        self.showNewExerciseOnboarding = showNewExerciseOnboarding
    }
}

enum AISuggestionInsertionMode {
    case replace
    case append
}

enum AppProcessSession {
    static let currentID = ProcessInfo.processInfo.globallyUniqueString
}

enum SetLoggingSessionStore {
    private static let pendingSessionKey = "pendingSetLoggingSession"
    private static let legacyRestoreOnNextLaunchKey = "pendingSetLoggingSession.restoreOnNextLaunch"
    private static let restoreOwnerSessionIDKey = "pendingSetLoggingSession.restoreOwnerSessionID"
    // Restore intent is owned by active add-session logging flow.
    // Only SetLoggingView should request restore after persisting a pending add session.

    private static var restoreOwnerSessionID: String? {
        UserDefaults.standard.string(forKey: restoreOwnerSessionIDKey)
    }

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
        clearRestoreRequest()
    }

    static var hasPendingSession: Bool {
        load() != nil
    }

    static var shouldRestoreOnNextLaunch: Bool {
        hasPendingSession
            && (
                restoreOwnerSessionID != nil
                    || UserDefaults.standard.bool(forKey: legacyRestoreOnNextLaunchKey)
            )
    }

    static func requestRestoreOnNextLaunch(ownerSessionID: String) {
        guard hasPendingSession else { return }
        UserDefaults.standard.set(ownerSessionID, forKey: restoreOwnerSessionIDKey)
        UserDefaults.standard.removeObject(forKey: legacyRestoreOnNextLaunchKey)
    }

    static func clearRestoreRequest() {
        UserDefaults.standard.removeObject(forKey: restoreOwnerSessionIDKey)
        UserDefaults.standard.removeObject(forKey: legacyRestoreOnNextLaunchKey)
    }

    static func clearRestoreRequestIfOwned(by ownerSessionID: String) {
        guard restoreOwnerSessionID == ownerSessionID else { return }
        clearRestoreRequest()
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
    @Published var workoutEndedAt: Date = .now

    @Published var currentFocusIndexState: FocusIndex? = nil {
        didSet {
            editMode = .overwrite
        }
    }

    private let mode: SetLoggingMode
    private let exerciseService: any ExerciseServing
    private let healthKitManager: any HealthKitManaging
    private var shouldPersistPendingSession = false
    private var isNewExerciseSession = false
    private var startedAt: Date?
    @Published private(set) var stopwatchStartedAt: Date?

    private let shouldRelaxCompletionRequirementForUITests =
        ProcessInfo.processInfo.arguments.contains("UI_TEST_SKIP_FIRST_TIME_PROMPT")

    init(
        mode: SetLoggingMode,
        exerciseService: any ExerciseServing,
        healthKitManager: any HealthKitManaging
    ) {
        self.mode = mode
        self.exerciseService = exerciseService
        self.healthKitManager = healthKitManager

        switch mode {
        case .add(let exerciseName, let pendingSession):
            selectedExercise = exerciseName
            workoutEndedAt = Date()

            if let pendingSession {
                sets = pendingSession.sets.map { StrengthSetData(pendingData: $0) }
                startedAt = pendingSession.startedAt ?? Date()
                stopwatchStartedAt = pendingSession.stopwatchStartedAt
                isNewExerciseSession = pendingSession.isNewExercise
                shouldPersistPendingSession = true
            } else {
                startedAt = Date()
                let lastSession = exerciseService.lastExerciseSession(matching: exerciseName)
                sets = lastSession?.orderedStrengthSets.map {
                    StrengthSetData(weightInLbs: $0.weightInLbs, reps: $0.reps)
                } ?? []
                let isNewExercise = lastSession?.orderedStrengthSets.isEmpty ?? true
                isNewExerciseSession = isNewExercise
                shouldPersistPendingSession = true
                persistPendingSessionIfNeeded()
            }
        case .edit(let exercise):
            selectedExercise = exercise.name
            workoutEndedAt = exercise.date
            sets = exercise.orderedStrengthSets.map {
                StrengthSetData(weightInLbs: $0.weightInLbs, reps: $0.reps, isCompleted: true)
            }
            shouldPersistPendingSession = false
        }
    }

    func saveWorkout() {
        switch mode {
        case .add:
            let completedAt = Date()
            let startedAt = startedAt ?? completedAt.addingTimeInterval(-Exercise.legacyStartedAtFallbackInterval)
            stopStopwatch()
            let exercise = Exercise(
                date: completedAt,
                startedAt: startedAt,
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
            exercise.startedAt = startedAt
            exerciseService.addExercise(exercise)
            shouldPersistPendingSession = false
            SetLoggingSessionStore.clear()
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
            exerciseService.updateExercise(exercise, sets: updatedSets, endedAt: workoutEndedAt)
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

    var shouldShowEndTimeEditor: Bool {
        if case .edit = mode {
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
        if !isCompleted {
            restartStopwatchAfterLoggedSet()
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

    func onNumberPadReturn() {
        let nextFocus = currentFocusIndexState?.next()
        withAnimation {
            if currentFocusIndexState?.type == .rep,
               let setIndex = currentFocusIndexState?.setIndex
            {
                let wasCompleted = sets[setIndex].isCompleted
                sets[setIndex].isCompleted = true
                if !wasCompleted {
                    restartStopwatchAfterLoggedSet()
                }
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

    func onAppear() {
        if isInAddMode && sets.count > 0 {
            currentFocusIndexState = .initial
        }
        if isInAddMode, let stopwatchStartedAt {
            WorkoutStopwatchLiveActivityController.shared.restartStopwatch(
                exerciseName: selectedExercise,
                completedSetCount: completedSetCount,
                startedAt: stopwatchStartedAt
            )
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

    var isStopwatchRunning: Bool {
        stopwatchStartedAt != nil
    }

    var completedSetCount: Int {
        sets.filter(\.isCompleted).count
    }

    func stopwatchElapsedSeconds(at date: Date = Date()) -> Int {
        guard let stopwatchStartedAt else { return 0 }
        return max(0, Int(date.timeIntervalSince(stopwatchStartedAt)))
    }

    func formattedStopwatchElapsed(at date: Date = Date()) -> String {
        let elapsedSeconds = stopwatchElapsedSeconds(at: date)
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func restartStopwatchAfterLoggedSet() {
        guard isInAddMode else { return }
        let startedAt = Date()
        stopwatchStartedAt = startedAt
        WorkoutStopwatchLiveActivityController.shared.restartStopwatch(
            exerciseName: selectedExercise,
            completedSetCount: completedSetCount,
            startedAt: startedAt
        )
        persistPendingSessionIfNeeded()
    }

    private func stopStopwatch() {
        stopwatchStartedAt = nil
        WorkoutStopwatchLiveActivityController.shared.stopStopwatch()
    }

    @discardableResult
    func persistPendingSessionIfNeeded() -> Bool {
        guard shouldPersistPendingSession else { return false }
        guard case .add = mode else { return false }

        let session = PendingSetLoggingSession(
            exerciseName: selectedExercise,
            sets: sets.map { $0.pendingData },
            startedAt: startedAt,
            stopwatchStartedAt: stopwatchStartedAt,
            isNewExercise: isNewExerciseSession
        )
        SetLoggingSessionStore.save(session)
        return true
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
        let exerciseService: ExerciseService = Container.shared.resolve(ExerciseService.self)
        let healthKitManager: HealthKitManager = Container.shared.resolve(HealthKitManager.self)
        let viewModel = SetLoggingViewModel(
            mode: .add(exerciseName: "Bench Press", pendingSession: nil),
            exerciseService: exerciseService,
            healthKitManager: healthKitManager
        )
        viewModel.sets = [
            StrengthSetData(weightInLbs: 200, reps: 10),
            StrengthSetData(weightInLbs: 200, reps: 10),
            StrengthSetData(weightInLbs: 200, reps: 10)
        ]
        return viewModel
    }
}
