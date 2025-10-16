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

@Model
class Exercise {
    @Attribute(.unique) var id: UUID = UUID()
    var type: ExerciseType
    var name: String
    var date: Date
    var notes: String?

    // Strength-specific
    @Relationship(deleteRule: .cascade) var sets: [StrengthSet]?

    // Cardio-specific
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
class StrengthSet {
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

extension Exercise {
    var maxWeight: Double {
        sets?.map { $0.weightInLbs }.max() ?? 0.0
    }
    var maxRep: Int {
        sets?.map { $0.reps }.max() ?? 0
    }
}

