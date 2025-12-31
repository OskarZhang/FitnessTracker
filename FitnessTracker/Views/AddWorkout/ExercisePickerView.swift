import SwiftUI
import Combine
import SwiftUIIntrospect

struct ExercisePickerView: View {
    @ObservedObject var viewModel: AddWorkoutViewModel

    @Binding var isPresented: Bool
    @Binding var selectedExercise: String

    @FocusState private var isNameFocused
    @State private var hasSetInitialFocus = false

    @StateObject private var searchContext = SearchContext()
    @State private var allExercises: [String] = []

    let confirmationImpact = UIImpactFeedbackGenerator(style: .medium)

    init(viewModel: AddWorkoutViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self._selectedExercise = Binding(
            get: { viewModel.selectedExercise },
            set: { viewModel.selectedExercise = $0 }
        )
    }

    var body: some View {
            VStack {
                TextField("Enter exercise", text: $searchContext.searchText)
                    .textFieldStyle(.plain)
                    .listRowSeparator(.hidden)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 28))
                    .fontWeight(.medium)
                    .padding()
                    .focused($isNameFocused)
                    .introspect(.textField, on: .iOS(.v26), customize: { textField in
                        // this makes keyboard bring-up significantly faster
                        if !hasSetInitialFocus && isPresented {
                            textField.becomeFirstResponder()
                            hasSetInitialFocus = true
                        }
                    })
                    .onSubmit {
                        if searchContext.searchText.isEmpty {
                            isNameFocused = true
                            return
                        }
                        selectedExercise = searchContext.searchText
                        confirmationImpact.impactOccurred()
                    }
                    .padding(.top, 8)
                
                List(viewModel.getExerciseSuggestions(name: searchContext.searchText), id: \.self) { exerciseName in
                    Button(action: {
                        selectedExercise = exerciseName
                        confirmationImpact.impactOccurred()
                    }) {
                        Text(exerciseName)
                            .font(.system(size: 18))
                    }
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
            .onAppear {
                isNameFocused = true
            }
            .navigationTitle("Select an exercise")
            .navigationBarTitleDisplayMode(.inline)
    }

}

#Preview {
  ExercisePickerView(
	viewModel: AddWorkoutViewModel(),
	isPresented: .constant(true)
  )
}
