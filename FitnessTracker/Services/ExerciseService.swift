import SwiftData
import Foundation
import Combine

class ExerciseService: ObservableObject {

    static private let StartOfDayWorkoutToken: String = "StartOfDay"

    
    private let modelContext: ModelContext

    private var transitions: [String: [String: Int]] = [:]
    private var transitionProbabilities: [String: [String: Double]] = [:]
    @Published var exercises: [Exercise] = []

    private static func makeContainer() throws -> ModelContainer {
        let schema = Schema(FitnessTrackerSchemaV2.models)
        return try ModelContainer(
            for: schema,
            migrationPlan: FitnessTrackerMigrationPlan.self,
            configurations: .init()
        )
    }
    
    lazy var exerciseNamesFromCSV: [String] = {
        guard let url = Bundle.main.url(forResource: "strength_workout_names", withExtension: "csv") else {
            print("CSV file not found")
            return []
        }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            // Split by newlines, trim whitespace, and filter out empty lines
            var lines = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            lines.removeFirst() // remove column name
            return lines
        } catch {
            print("Error reading CSV: \(error)")
            return []
        }
    }()

    #if DEBUG
    init(resetData: Bool = false) {
        let container = try! Self.makeContainer()
        self.modelContext = ModelContext(container)
        applyUITestResetIfNeeded(
            resetData: resetData,
            launchArguments: ProcessInfo.processInfo.arguments
        )
        finishInitialization()
    }
    #else
    init() {
        let container = try! Self.makeContainer()
        self.modelContext = ModelContext(container)
        finishInitialization()
    }
    #endif

    private func finishInitialization() {
        exercises = fetchWorkouts()
        Task {
            await buildTransitionProbabilityMatrix(data: exercises)
        }
    }

    func groupedWorkouts(query: String = "") -> [(date: Date, exercises: [Exercise])] {
        let groupedDict = Dictionary(grouping: exercises.filter({ exercise in
            query.isEmpty || exercise.name.lowercased().contains(query)
        })) { exercise in
            // Normalize the date to remove time components
            Calendar.current.startOfDay(for: exercise.date)
        }
        // Sort the dates in descending order
        let sortedDates = groupedDict.keys.sorted(by: >)
        // Map the sorted dates to an array of tuples
        let res = sortedDates.map { date in
            (date: date, exercises: groupedDict[date]!)
        }
        return res
    }

    func groupedWorkoutSessions(query: String = "") -> [ExerciseDayGroup] {
        groupedWorkouts(query: query).map { dayGroup in
            ExerciseDayGroup(
                date: dayGroup.date,
                workouts: Self.makeWorkoutGroups(from: dayGroup.exercises)
            )
        }
    }

    private static func makeWorkoutGroups(from exercises: [Exercise]) -> [ExerciseWorkoutGroup] {
        let sortedExercises = exercises.sorted { $0.date < $1.date }
        var groups: [[Exercise]] = []

        for exercise in sortedExercises {
            guard var currentGroup = groups.popLast(),
                  let firstExercise = currentGroup.first,
                  let lastExercise = currentGroup.last
            else {
                groups.append([exercise])
                continue
            }

            let gapFromPreviousExercise = exercise.date.timeIntervalSince(lastExercise.date)
            let durationWithExercise = exercise.date.timeIntervalSince(firstExercise.effectiveStartedAt)
            if gapFromPreviousExercise <= ExerciseWorkoutGroup.maximumGapBetweenExercises
                && durationWithExercise <= ExerciseWorkoutGroup.maximumWorkoutDuration {
                currentGroup.append(exercise)
                groups.append(currentGroup)
            } else {
                groups.append(currentGroup)
                groups.append([exercise])
            }
        }

        return groups
            .map { ExerciseWorkoutGroup(exercises: $0.sorted { $0.date > $1.date }) }
            .sorted { $0.endDate > $1.endDate }
    }
    
    func removeExerciseBulk(idSet: Set<UUID>) {
        try? modelContext.delete(model: Exercise.self, where: #Predicate { exercise in
            idSet.contains(exercise.id)
        })
        try? modelContext.save()
        exercises = fetchWorkouts()   
    }

    /// build a Markov Chain prediction matrix with exercise data
    private func buildTransitionProbabilityMatrix(data: [Exercise]) async {
        // Group exercises by date
        let calendar = Calendar.current
        let groupedByDate = Dictionary(grouping: data) { entry in
            calendar.startOfDay(for: entry.date)
        }

        // Calculate transitions
        for (_, exercises) in groupedByDate {
            let sortedExercises = exercises.sorted { $0.date < $1.date }

            // allows us to also
            let names = [""] + sortedExercises.map { $0.name }

            for idx in 0..<(names.count - 1) {
                let pair = (names[idx], names[idx + 1])
                transitions[pair.0] = transitions[pair.0] ?? [:]
                if let value = transitions[pair.0]?[pair.1] {
                    transitions[pair.0]?[pair.1] = value + 1
                } else {
                    transitions[pair.0]?[pair.1] = 1
                }
            }
        }

        // Calculate probabilities
        for (prevEx, nextExercises) in transitions {
            let total = Double(nextExercises.values.reduce(0, +))
            transitionProbabilities[prevEx] = [:]

            for (nextEx, count) in nextExercises {
                transitionProbabilities[prevEx]?[nextEx] = Double(count) / total
            }
        }
    }

    func getExerciseSuggestions(exerciseName: String) -> [String] {
        if exerciseName.isEmpty {
            return predictNextWorkout()
        } else {
            return matchWorkout(exerciseName: exerciseName).map { $0.name }
        }
    }

    func lastExerciseSession(matching name: String) -> Exercise? {
        return exercises.filter { $0.name.lowercased() == name.lowercased()}.first
    }

    func hasExercise(on date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDayStart = calendar.startOfDay(for: date)
        let targetDayEnd = targetDayStart.advanced(by: 60 * 60 * 24)
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { exercise in
                exercise.date < targetDayEnd && exercise.date >= targetDayStart
            }
        )

        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    private func predictNextWorkout() -> [String] {
        var lastWorkoutName: String = ExerciseService.StartOfDayWorkoutToken
        if let mostRecentWorkout = exercises.first,
           Calendar.current.isDateInToday(mostRecentWorkout.date) {
            lastWorkoutName = mostRecentWorkout.name
        }
        
        let res = (transitionProbabilities[lastWorkoutName] ?? [:])
            .sorted { $0.value > $1.value } // sort exercises by probability
            .map { $0.key } // map to exercise name

        if res.count < 10 {
            let predictionSet = Set(res.map { $0.lowercased() })
            return res + exerciseNamesFromCSV.filter { !predictionSet.contains($0.lowercased()) }
        }
        return res
    }

    func addExercise(_ exercise: Exercise) {
        modelContext.insert(exercise)
        exercises.insert(exercise, at: 0)
        try? modelContext.save()
    }

    func updateExercise(_ exercise: Exercise, sets: [StrengthSet]) {
        exercise.strengthSets = sets
        try? modelContext.save()
        exercises = fetchWorkouts()
    }

    private func matchWorkout(exerciseName: String) -> [Exercise] {
        let existingWorkoutMatch = exercises.filter { $0.name.lowercased().contains(exerciseName.lowercased())}
            .reduce((uniqueWorkoutNames: Set<String>(), list: [Exercise]())) { partialResult, exercise in
                if partialResult.uniqueWorkoutNames.contains(exercise.name) {
                    return partialResult
                }
                var uniqueNames = partialResult.uniqueWorkoutNames
                var list = partialResult.list
                list.append(exercise)
                uniqueNames.insert(exercise.name)
                return (uniqueNames, list)
            }
            .list
        if existingWorkoutMatch.count == 1 && exerciseName == existingWorkoutMatch.first?.name {
            // no need to provide suggestions for the exact match
            return []
        }

        let stockWorkoutMatch = exerciseNamesFromCSV.filter { $0.lowercased().contains(exerciseName.lowercased()) }.map {
            Exercise(name: $0, type: .strength)
        }

        return existingWorkoutMatch + stockWorkoutMatch
    }

    private func fetchWorkouts() -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

}

#if DEBUG
private extension ExerciseService {
    func applyUITestResetIfNeeded(resetData: Bool, launchArguments: [String]) {
        guard resetData else { return }

        resetAllDataForUITests()
        SetLoggingSessionStore.clear()

        if launchArguments.contains("UI_TEST_SEED_ORDERING") {
            seedOrderingUITestData()
        }

        if launchArguments.contains("UI_TEST_SEED_EXISTING_BENCH_PRESS") {
            seedExistingBenchPressUITestData()
        }

        if launchArguments.contains("UI_TEST_SEED_WORKOUT_DURATION_GROUPS") {
            seedWorkoutDurationGroupsUITestData()
        }
    }

    func resetAllDataForUITests() {
        let descriptor = FetchDescriptor<Exercise>()
        guard let existing = try? modelContext.fetch(descriptor) else { return }
        for exercise in existing {
            modelContext.delete(exercise)
        }
        try? modelContext.save()
    }

    func seedOrderingUITestData() {
        let exercise = Exercise(
            name: "Order Check Bench",
            type: .strength,
            strengthSets: [
                StrengthSet(weightInLbs: 35, reps: 10),
                StrengthSet(weightInLbs: 40, reps: 10),
                StrengthSet(weightInLbs: 50, reps: 10),
            ]
        )
        modelContext.insert(exercise)
        try? modelContext.save()
    }

    func seedExistingBenchPressUITestData() {
        let exercise = Exercise(
            name: "Bench Press",
            type: .strength,
            strengthSets: [
                StrengthSet(weightInLbs: 135, reps: 8),
            ]
        )
        modelContext.insert(exercise)
        try? modelContext.save()
    }

    func seedWorkoutDurationGroupsUITestData() {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: Date())

        let seededExercises: [(name: String, minutesFromStartOfDay: Int)] = [
            ("Bench Press", 9 * 60),
            ("Incline Press", 9 * 60 + 10),
            ("Cable Fly", 9 * 60 + 25),
            ("Lat Pulldown", 9 * 60 + 41),
        ]

        for seed in seededExercises {
            let date = dayStart.addingTimeInterval(TimeInterval(seed.minutesFromStartOfDay * 60))
            let startedAt = date.addingTimeInterval(-Exercise.legacyStartedAtFallbackInterval)
            let exercise = Exercise(
                date: date,
                startedAt: startedAt,
                name: seed.name,
                type: .strength,
                strengthSets: [
                    StrengthSetRecord(weightInLbs: 100, reps: 10),
                ]
            )
            exercise.startedAt = startedAt
            modelContext.insert(exercise)
        }

        try? modelContext.save()
    }
}
#else
private extension ExerciseService {
    func applyUITestResetIfNeeded(resetData: Bool, launchArguments: [String]) {}
}
#endif

struct ExerciseDayGroup: Identifiable {
    let date: Date
    let workouts: [ExerciseWorkoutGroup]

    var id: Date { date }
    var exercises: [Exercise] { workouts.flatMap(\.exercises) }
}

struct ExerciseWorkoutGroup: Identifiable {
    static let maximumGapBetweenExercises: TimeInterval = 15 * 60
    static let maximumWorkoutDuration: TimeInterval = 3 * 60 * 60

    let exercises: [Exercise]

    var id: String {
        exercises.map { $0.id.uuidString }.joined(separator: "-")
    }

    var startDate: Date {
        exercises.map(\.effectiveStartedAt).min() ?? .now
    }

    var endDate: Date {
        exercises.map(\.date).max() ?? startDate
    }

    var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }
}

extension Exercise {
    static let legacyStartedAtFallbackInterval: TimeInterval = 10 * 60

    var effectiveStartedAt: Date {
        startedAt ?? date.addingTimeInterval(-Self.legacyStartedAtFallbackInterval)
    }
}
