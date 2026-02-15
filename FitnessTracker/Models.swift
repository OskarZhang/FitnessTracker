//
//  Data.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 9/2/24.
//

import SwiftData
import SwiftUI

enum ExerciseType: String, Codable {
    case strength
    case cardio
}

struct StrengthSetRecord: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var weightInLbs: Double
    var reps: Int
    var restSeconds: Int?
    var rpe: Int?

    init(
        id: UUID = UUID(),
        weightInLbs: Double,
        reps: Int,
        restSeconds: Int? = nil,
        rpe: Int? = nil
    ) {
        self.id = id
        self.weightInLbs = weightInLbs
        self.reps = reps
        self.restSeconds = restSeconds
        self.rpe = rpe
    }
}

enum FitnessTrackerSchemaV0: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Exercise.self, StrengthSet.self]
    }

    @Model
    final class Exercise {
        @Attribute(.unique) var id: UUID = UUID()
        var type: ExerciseType
        var name: String
        var date: Date
        var notes: String?

        @Relationship(deleteRule: .cascade) var sets: [StrengthSet]?

        var distanceInMiles: Double?
        var durationInSeconds: Int?
        var averageHeartRate: Int?

        init(
            date: Date = .now,
            notes: String? = nil,
            name: String,
            type: ExerciseType,
            sets: [StrengthSet]? = nil,
            distanceInMiles: Double? = nil,
            durationInSeconds: Int? = nil,
            averageHeartRate: Int? = nil
        ) {
            self.date = date
            self.notes = notes
            self.name = name
            self.type = type
            self.sets = sets
            self.distanceInMiles = distanceInMiles
            self.durationInSeconds = durationInSeconds
            self.averageHeartRate = averageHeartRate
        }
    }

    @Model
    final class StrengthSet {
        var weightInLbs: Double
        var reps: Int
        var restSeconds: Int?
        var rpe: Int?

        init(weightInLbs: Double, reps: Int, restSeconds: Int? = nil, rpe: Int? = nil) {
            self.weightInLbs = weightInLbs
            self.reps = reps
            self.restSeconds = restSeconds
            self.rpe = rpe
        }
    }
}

enum FitnessTrackerSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Exercise.self, StrengthSet.self]
    }

    @Model
    final class Exercise {
        @Attribute(.unique) var id: UUID = UUID()
        var type: ExerciseType
        var name: String
        var date: Date
        var notes: String?

        // Legacy relationship retained for migration + fallback backfill.
        @Relationship(deleteRule: .cascade) var sets: [StrengthSet]?

        var strengthSets: [StrengthSetRecord] = []

        var distanceInMiles: Double?
        var durationInSeconds: Int?
        var averageHeartRate: Int?

        init(
            date: Date = .now,
            notes: String? = nil,
            name: String,
            type: ExerciseType,
            sets: [StrengthSet]? = nil,
            strengthSets: [StrengthSetRecord] = [],
            distanceInMiles: Double? = nil,
            durationInSeconds: Int? = nil,
            averageHeartRate: Int? = nil
        ) {
            self.date = date
            self.notes = notes
            self.name = name
            self.type = type
            self.sets = sets
            self.strengthSets = strengthSets
            self.distanceInMiles = distanceInMiles
            self.durationInSeconds = durationInSeconds
            self.averageHeartRate = averageHeartRate
        }
    }

    @Model
    final class StrengthSet {
        var weightInLbs: Double
        var reps: Int
        var restSeconds: Int?
        var rpe: Int?

        init(weightInLbs: Double, reps: Int, restSeconds: Int? = nil, rpe: Int? = nil) {
            self.weightInLbs = weightInLbs
            self.reps = reps
            self.restSeconds = restSeconds
            self.rpe = rpe
        }
    }
}

enum FitnessTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FitnessTrackerSchemaV0.self, FitnessTrackerSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        [migrateV0toV1]
    }

    static let migrateV0toV1 = MigrationStage.custom(
        fromVersion: FitnessTrackerSchemaV0.self,
        toVersion: FitnessTrackerSchemaV1.self,
        willMigrate: nil,
        didMigrate: { context in
            let descriptor = FetchDescriptor<FitnessTrackerSchemaV1.Exercise>()
            let exercises = try context.fetch(descriptor)

            for exercise in exercises where exercise.strengthSets.isEmpty {
                let legacySets = exercise.sets ?? []
                guard !legacySets.isEmpty else { continue }

                exercise.strengthSets = legacySets.map { set in
                    StrengthSetRecord(
                        weightInLbs: set.weightInLbs,
                        reps: set.reps,
                        restSeconds: set.restSeconds,
                        rpe: set.rpe
                    )
                }
            }

            try context.save()
        }
    )
}

typealias Exercise = FitnessTrackerSchemaV1.Exercise
typealias StrengthSet = StrengthSetRecord

extension Exercise {
    var orderedStrengthSets: [StrengthSetRecord] {
        strengthSets
    }

    var maxWeight: Double {
        orderedStrengthSets.map { $0.weightInLbs }.max() ?? 0.0
    }

    var maxRep: Int {
        orderedStrengthSets.map { $0.reps }.max() ?? 0
    }
}
