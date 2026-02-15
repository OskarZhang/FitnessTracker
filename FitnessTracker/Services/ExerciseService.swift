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
        let schema = Schema(FitnessTrackerSchemaV1.models)
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
        buildTransitionProbabilityMatrix(data: exercises)
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
    
    func removeExerciseBulk(idSet: Set<UUID>) {
        try? modelContext.delete(model: Exercise.self, where: #Predicate { exercise in
            idSet.contains(exercise.id)
        })
        try? modelContext.save()
        exercises = fetchWorkouts()
        buildTransitionProbabilityMatrix(data: exercises)
    }

    /// build a Markov Chain prediction matrix with exercise data
    private func buildTransitionProbabilityMatrix(data: [Exercise]) {
        transitions = [:]
        transitionProbabilities = [:]

        // Group exercises by date
        let calendar = Calendar.current
        let groupedByDate = Dictionary(grouping: data) { entry in
            calendar.startOfDay(for: entry.date)
        }

        // Calculate transitions
        for (_, exercises) in groupedByDate {
            let sortedExercises = exercises.sorted { $0.date < $1.date }

            // allows us to also
            let names = [ExerciseService.StartOfDayWorkoutToken] + sortedExercises.map { $0.name }

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

    func nextLikelyExercise(after exerciseName: String) -> String? {
        let key = transitionProbabilities.keys.first { $0.lowercased() == exerciseName.lowercased() }
        if let key, let prediction = transitionProbabilities[key]?.sorted(by: { $0.value > $1.value }).first?.key {
            return prediction
        }
        return predictNextWorkout().first
    }

    func addExercise(_ exercise: Exercise) {
        modelContext.insert(exercise)
        exercises.insert(exercise, at: 0)
        try? modelContext.save()
        buildTransitionProbabilityMatrix(data: exercises)
    }

    func updateExercise(_ exercise: Exercise, sets: [StrengthSet]) {
        exercise.strengthSets = sets
        try? modelContext.save()
        exercises = fetchWorkouts()
        buildTransitionProbabilityMatrix(data: exercises)
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
}
#else
private extension ExerciseService {
    func applyUITestResetIfNeeded(resetData: Bool, launchArguments: [String]) {}
}
#endif
