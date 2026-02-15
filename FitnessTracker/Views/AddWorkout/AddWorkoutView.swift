import SwiftUI

struct AddWorkoutView: View {
    @StateObject var viewModel: AddWorkoutViewModel
    @Binding var isPresented: Bool

    init(isPresented: Binding<Bool>, initialExerciseName: String? = nil) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: AddWorkoutViewModel(initialExerciseName: initialExerciseName))
    }

    var body: some View {
        NavigationStack {
            ExercisePickerView(viewModel: viewModel, isPresented: $isPresented)
                .navigationDestination(isPresented: $viewModel.showingSetLogger) {
                    if let setLoggingViewModel = viewModel.setLoggingViewModel {
                        SetLoggingView(viewModel: setLoggingViewModel, onSave: { isPresented = false })
                    }
                }
        }
    }

  
}

#Preview {
    AddWorkoutView(isPresented: .constant(true))
}
