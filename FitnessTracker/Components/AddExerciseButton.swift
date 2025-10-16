//
//  AddButton.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 10/15/25.
//

import SwiftUI

struct AddExerciseButton: View {
    @Binding private var isAddingWorkout: Bool
    @Environment(\.colorScheme) var colorScheme

    let addWorkoutImpact = UIImpactFeedbackGenerator(style: .medium)

    init(isAddingWorkout: Binding<Bool>) {
        self._isAddingWorkout = isAddingWorkout
    }
    var body: some View {
        Button(action: {
            isAddingWorkout = true
            addWorkoutImpact.impactOccurred()
        }) {
            Image(systemName: "plus")
                .font(.title)
                .frame(width: 60, height: 60)
                .foregroundColor(.bratGreen)
        }
        .glassEffect(.regular.tint(.bratGreen.opacity(0.3)).interactive(true))
        .padding()
    }
}
