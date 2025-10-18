import SwiftUI

struct AddWorkoutView: View {
    @StateObject var viewModel: AddWorkoutViewModel
    @Binding var isPresented: Bool

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: AddWorkoutViewModel(isPresented: isPresented))
    }

    var body: some View {
        NavigationStack() {
            ExercisePickerView(viewModel: viewModel, isPresented: $isPresented)
                .navigationDestination(isPresented: $viewModel.showingSetLogger) {
                    SetLoggingView(viewModel: viewModel)
                }
        }
        .accentColor(.bratGreen)
    }
}

