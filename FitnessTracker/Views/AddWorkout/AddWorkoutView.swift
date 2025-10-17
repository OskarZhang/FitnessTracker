import SwiftUI

struct AddWorkoutView: View {
    @StateObject var viewModel = AddWorkoutViewModel()
    @Binding var isPresented: Bool

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    var body: some View {
        NavigationStack() {
            ExercisePickerView(
                viewModel: viewModel,
                isPresented: $isPresented
            )
            .navigationDestination(isPresented: $viewModel.showingSetLogger) {
                SetLoggingView(
                    sets: viewModel.lastExerciseSession(),
                    isPresented: $isPresented,
                    exerciseName: viewModel.selectedExercise ?? "",
                    onSave: { sets in
                        viewModel.sets = sets.map { .init(weightInLbs: $0.weightInLbs, reps: $0.reps) }
                        viewModel.saveWorkout()
                        isPresented = false
                    }
                )
            }
        }
        .accentColor(.bratGreen)
    }
}
