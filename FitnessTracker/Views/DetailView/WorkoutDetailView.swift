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
    @State private var isEditing = false
    @StateObject private var editViewModel: SetLoggingViewModel

    init(exercise: Exercise) {
        self.exercise = exercise
        self._editViewModel = StateObject(wrappedValue: SetLoggingViewModel(mode: .edit(exercise: exercise)))
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
                        StrengthSetView(weight: Int(sets[setIndex].weightInLbs), repCount: sets[setIndex].reps, setIndexber: setIndex + 1)
                    }
                }


                Text("Progress Chart")
                    .font(.title3)
                    .fontWeight(.medium)
                    .padding(.top)

                WorkoutChartView(exercise.name)
                    .frame(height: 300)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    isEditing = true
                }
            }
        }
        .navigationDestination(isPresented: $isEditing) {
            SetLoggingView(viewModel: editViewModel)
        }
    }
}

struct StrengthSetView: View {
    let weight: Int
    let repCount: Int
    let setIndexber: Int

    var body: some View {
        HStack {
          Text("Set \(setIndexber)")
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

#Preview {
  let exercise = Exercise(name: "Bench Press", type: .strength)
  WorkoutDetailView(exercise: exercise)
}
