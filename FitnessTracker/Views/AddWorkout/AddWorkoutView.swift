import SwiftUI

struct AddWorkoutView: View {
    @StateObject var viewModel: AddWorkoutViewModel
    @Binding var isPresented: Bool
    @State private var sheetHeight: CGFloat = .zero

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
                    .font(.title)
                    .fontWeight(.medium)
                    .padding(.top)
                Text("GTFG AI can recommend you a full set based on your biometrics.")
                    .multilineTextAlignment(.leading)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 16)
                Button {
                    viewModel.showNewExerciseOnboarding = false
                    viewModel.generateWeightAndSetSuggestion()
                } label: {
                    Text("Generate full set")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                }
                .tint(Color.bratGreen)
                .buttonStyle(.glassProminent)
                
                Button() {
                    viewModel.showNewExerciseOnboarding = false
                } label: {
                    Text("Nah! Let me log my own")
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.bratGreen)
                }
                .buttonStyle(.glass)
            }
            .padding()
            .overlay {
                GeometryReader { geometry in
                    Color.clear.preference(key: InnerHeightPreferenceKey.self, value: geometry.size.height)
                }
            }
            .onPreferenceChange(InnerHeightPreferenceKey.self) { newHeight in
                sheetHeight = newHeight
            }
            .presentationDetents([.height(sheetHeight)])

        })
        .accentColor(.bratGreen)
    }
}

struct InnerHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
