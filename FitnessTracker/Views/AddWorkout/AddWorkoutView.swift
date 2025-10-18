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
        .sheet(isPresented: $viewModel.showNewExerciseOnboarding, content: {
            VStack(alignment: .leading) {
                Text("First time? ")
                    .multilineTextAlignment(.leading)
                    .font(.largeTitle)
                Text("GTFG AI can recommend you a full set based on your biometrics.")
                    .multilineTextAlignment(.leading)
                    .font(.subheadline)
                Spacer()
                Button {
                    viewModel.showNewExerciseOnboarding = false
                    viewModel.generateWeightAndSetSuggestion()
                } label: {
                    Text("Generate full set")
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                }
                .tint(Color.bratGreen)
                .buttonStyle(.borderedProminent)
                
                Button() {
                    viewModel.showNewExerciseOnboarding = false
                } label: {
                    Text("Nah! Let me log my own")
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .foregroundStyle(Color.bratGreen)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .presentationDetents([.height(240)])
        })
        .accentColor(.bratGreen)
    }
}
