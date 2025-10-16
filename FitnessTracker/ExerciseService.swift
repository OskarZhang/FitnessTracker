import SwiftData
import Foundation

class ExerciseService {

    static private let StartOfDayWorkoutToken: String = "StartOfDay"

    private let modelContext: ModelContext

    private var transitions: [String: [String: Int]] = [:]
    private var transitionProbabilities: [String: [String: Double]] = [:]
    private var exercises: [Exercise] = []


    lazy var exerciseNamesFromCSV: [String] = {
        guard let url = Bundle.main.url(forResource: "strength_workout_names", withExtension: "csv") else {
            print("CSV file not found")
            return []
        }
        do {
            let content = try String(contentsOf: url)
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

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.exercises = fetchWorkouts()
        Task {
            await buildTransitionProbabilityMatrix(data: self.exercises)
        }
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

    func getWorkoutSuggestion(exerciseName: String) -> [Exercise] {
        if exerciseName.isEmpty && exercises.isEmpty {
            // completely new user we just return the stock exercise names
            return exerciseNamesFromCSV.map {
                Exercise(name: $0, type: .strength)
            }
        } else if exerciseName.isEmpty {
            return predictNextWorkout()
        } else {
            return matchWorkout(exerciseName: exerciseName)
        }
    }

    func lastExerciseSession(matching name: String) -> Exercise? {
        return exercises.filter { $0.name.lowercased() == name.lowercased()}.first
    }

    private func predictNextWorkout() -> [Exercise] {
        var lastWorkoutName: String = ExerciseService.StartOfDayWorkoutToken
        if let mostRecentWorkout = exercises.first,
           Calendar.current.isDateInToday(mostRecentWorkout.date) {
            lastWorkoutName = mostRecentWorkout.name
        }
        guard let nextExercises = transitionProbabilities[lastWorkoutName] else {
            return Array(exercises.prefix(10))
        }

        // Sort exercises by probability
        let res = nextExercises.sorted { $0.value > $1.value }.map { $0.key }.compactMap { getMostRecentWorkout(exerciseName: $0)}

        return res
    }

    func addExercise(_ exercise: Exercise) {
        modelContext.insert(exercise)
        exercises.insert(exercise, at: 0)
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

    private func getMostRecentWorkout(exerciseName: String) -> Exercise? {
        var descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == exerciseName }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func fetchWorkouts() -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

}
