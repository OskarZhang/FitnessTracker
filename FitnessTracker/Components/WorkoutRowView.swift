//
//  WorkoutRowView.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 10/16/25.
//

import SwiftUI

struct WorkoutRowView: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading) {

            Text(exercise.name)
                .font(.system(size: 20, weight: .medium))

            switch exercise.type {
            case .strength:
                Text("\(Int(exercise.maxWeight)) lbs, \(exercise.maxRep) reps, \(exercise.sets?.count ?? 0) sets")
                    .font(.callout)
            case .cardio:
                Text("Cardio: \((exercise.durationInSeconds ?? 0) / 60) minutes")
                    .font(.callout)
            }
        }
    }
}
