import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private let workoutType = HKObjectType.workoutType()
    private let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass)!

    @Published var isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    @Published var workoutAuthorizationStatus: HKAuthorizationStatus = .notDetermined

    func refreshAuthorizationStatus() {
        guard isAvailable else { return }
        workoutAuthorizationStatus = healthStore.authorizationStatus(for: workoutType)
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        let shareTypes: Set<HKSampleType> = [workoutType]
        let readTypes: Set<HKObjectType> = [bodyMassType]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if !success {
                    continuation.resume(throwing: NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit authorization failed"]))
                    return
                }
                continuation.resume(returning: ())
            }
        }
        refreshAuthorizationStatus()
    }

    func writeStrengthWorkout(exercises: [Exercise]) async throws {
        guard isAvailable else { return }
        guard !exercises.isEmpty else { return }

        let startDate = exercises.map { $0.date }.min() ?? Date()
        let totalSets = exercises.reduce(0) { partialResult, exercise in
            partialResult + (exercise.sets?.count ?? 0)
        }
        let estimatedDurationMinutes = max(10, totalSets * 2)
        let endDate = startDate.addingTimeInterval(TimeInterval(estimatedDurationMinutes * 60))

        let bodyWeightInLbs = try await fetchMostRecentBodyMassInPounds()
        let calories = estimateCalories(
            totalSets: totalSets,
            bodyWeightInLbs: bodyWeightInLbs,
            durationMinutes: estimatedDurationMinutes
        )

        let energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: energyBurned,
            totalDistance: nil,
            metadata: [HKMetadataKeyWorkoutBrandName: "FitnessTracker"]
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(workout) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if !success {
                    continuation.resume(throwing: NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to save workout"]))
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private func estimateCalories(totalSets: Int, bodyWeightInLbs: Double?, durationMinutes: Int) -> Double {
        let weightKg = (bodyWeightInLbs ?? 155.0) * 0.45359237
        let hours = Double(durationMinutes) / 60.0
        let met = 3.5
        let setFactor = max(1.0, Double(totalSets) / 10.0)
        let calories = met * weightKg * hours * setFactor
        return max(1.0, calories)
    }

    private func fetchMostRecentBodyMassInPounds() async throws -> Double? {
        guard isAvailable else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let sample = samples?.first as? HKQuantitySample
                let pounds = sample?.quantity.doubleValue(for: .pound())
                continuation.resume(returning: pounds)
            }
            healthStore.execute(query)
        }
    }
}
