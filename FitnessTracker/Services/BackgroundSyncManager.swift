import Foundation
import BackgroundTasks

final class BackgroundSyncManager {
    static let shared = BackgroundSyncManager()
    static let taskIdentifier = "com.oz.fitness.FitnessTracker.healthkitSync"

    private let minimumInterval: TimeInterval = 20 * 60
    private let lastExportedDateKey = "healthKitLastExportedDate"

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            self.handle(task: task as? BGAppRefreshTask)
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = nextEligibleDate()
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(task: BGAppRefreshTask?) {
        guard let task else { return }
        schedule()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            let success = await performSyncIfNeeded()
            task.setTaskCompleted(success: success)
        }
    }

    @MainActor
    private func performSyncIfNeeded() async -> Bool {
        let exerciseService: ExerciseService = Container.shared.resolve(ExerciseService.self)
        let healthKitManager: HealthKitManager = Container.shared.resolve(HealthKitManager.self)

        guard healthKitManager.isAvailable else { return false }

        healthKitManager.refreshAuthorizationStatus()
        guard healthKitManager.workoutAuthorizationStatus == .sharingAuthorized else {
            return false
        }

        guard let latestExercise = exerciseService.exercises.first else { return false }
        let elapsed = Date().timeIntervalSince(latestExercise.date)
        guard elapsed >= minimumInterval else { return false }

        if let lastExportedDate = UserDefaults.standard.object(forKey: lastExportedDateKey) as? Date,
           lastExportedDate >= latestExercise.date {
            return false
        }

        guard let latestDay = exerciseService.groupedWorkouts().first else { return false }

        do {
            try await healthKitManager.writeStrengthWorkout(exercises: latestDay.exercises)
            UserDefaults.standard.set(Date(), forKey: lastExportedDateKey)
            return true
        } catch {
            return false
        }
    }

    private func nextEligibleDate() -> Date? {
        let exerciseService: ExerciseService = Container.shared.resolve(ExerciseService.self)
        guard let latestExercise = exerciseService.exercises.first else {
            return Date().addingTimeInterval(minimumInterval)
        }
        let threshold = latestExercise.date.addingTimeInterval(minimumInterval)
        return max(Date(), threshold)
    }
}
