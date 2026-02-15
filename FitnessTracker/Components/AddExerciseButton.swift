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
            // Manual add flow should always start from exercise picker.
            SetLoggingSessionStore.clearRestoreRequest()
            isAddingWorkout = true
            addWorkoutImpact.impactOccurred()
        }) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .frame(width: 64, height: 64)
                .foregroundColor(.accentColor)
        }
        .glassEffect(.regular.tint(.accentColor.opacity(0.08)).interactive(true))
        .accessibilityIdentifier("home.addWorkoutButton")
        .padding()
    }
}
