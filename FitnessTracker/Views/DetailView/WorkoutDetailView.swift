//
//  WorkoutDetailView.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 9/3/24.
//

import SwiftUI
import SwiftData
import Charts

struct WorkoutDetailView: View {
    let exercise: Exercise

    init(exercise: Exercise) {
        self.exercise = exercise
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(exercise.name)
                    .font(.largeTitle)
                    .fontWeight(.medium)
                Text(exercise.date.formatted(date: .long, time: .omitted))
                    .foregroundStyle(.gray)
                    .fontWeight(.semibold)
                if case .strength = exercise.type,
                   let sets = exercise.sets {
                    ForEach(sets.indices, id: \.self) { setIndex in
                        StrengthSetView(weight: Int(sets[setIndex].weightInLbs), repCount: sets[setIndex].reps, setNumber: setIndex + 1)
                    }
                }


                Text("Progress Chart")
                    .font(.title3)
                    .fontWeight(.medium)
                    .padding(.top)

                WorkoutChartView(exercise.name)
                    .frame(height: 300)
                .padding()

                Text("Pinch to zoom on the chart")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StrengthSetView: View {
    let weight: Int
    let repCount: Int
    let setNumber: Int

    var body: some View {
        HStack {
            Text("Set \(setNumber)")
                .foregroundStyle(.gray)
            Spacer()
            Text("\(weight) lb")
                .fontWeight(.semibold)
            Spacer()
            Text("\(repCount) reps")
                .fontWeight(.semibold)
        }
    }
}
