import SwiftUI
import Combine
import SwiftUIIntrospect

struct ExercisePickerView: View {
    @StateObject var viewModel: AddWorkoutViewModel

    @Binding var isPresented: Bool
    @Binding var selectedExercise: String

    @FocusState private var isNameFocused
    @State private var hasSetInitialFocus = false

    @StateObject private var searchContext = SearchContext()
    @State private var allExercises: [String] = []

    let confirmationImpact = UIImpactFeedbackGenerator(style: .medium)


    var filteredExercises: [String] {
        if searchContext.debouncedSearchText.isEmpty {
            return allExercises
        } else {
            return allExercises.filter { $0.lowercased().contains(searchContext.debouncedSearchText.lowercased()) }
        }
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
                .introspect(.textField, on: .iOS(.v13, .v14, .v15, .v16, .v17, .v18), customize: { textField in
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

            List(viewModel.matchExercise(name: searchContext.searchText), id: \.self) { exercise in
                Button(action: {
                    selectedExercise = exercise.name
                    confirmationImpact.impactOccurred()
                }) {
                    Text(exercise.name)
                        .font(.system(size: 18))
                }
                .listRowSeparator(.hidden)

            }
            .listStyle(.plain)
        }
        .onAppear {
            isNameFocused = true

        }
    }

}
