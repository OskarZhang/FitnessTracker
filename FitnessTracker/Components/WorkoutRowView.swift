//
//  WorkoutRowView.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 10/16/25.
//

import SwiftUI

struct WorkoutRowView: View {
    enum ExerciseType {
        case strength(maxWeight: Double, maxRep: Int, setCount: Int)
        case cardio(durationMinutes: Int)
    }

    let name: String
    let type: ExerciseType

    var body: some View {
        VStack(alignment: .leading) {

            Text(name)
                .font(.system(size: 20, weight: .medium))

            switch type {
            case .strength(let maxWeight, let maxRep, let setCount):
                Text("\(Int(maxWeight)) lbs, \(maxRep) reps, \(setCount) sets")
                    .font(.callout)
            case .cardio(let durationMinutes):
                Text("Cardio: \(durationMinutes) minutes")
                    .font(.callout)
            }
        }
    }
}

// Convenience initializer that accepts Exercise
extension WorkoutRowView {
    init(exercise: Exercise) {
        self.name = exercise.name
        
        switch exercise.type {
        case .strength:
            self.type = .strength(
                maxWeight: exercise.maxWeight,
                maxRep: exercise.maxRep,
                setCount: exercise.orderedStrengthSets.count
            )
        case .cardio:
            self.type = .cardio(
                durationMinutes: (exercise.durationInSeconds ?? 0) / 60
            )
        }
    }
}

#Preview {
    WorkoutRowView(
        name: "Bench Press",
        type: .strength(maxWeight: 185, maxRep: 8, setCount: 3)
    )
}
