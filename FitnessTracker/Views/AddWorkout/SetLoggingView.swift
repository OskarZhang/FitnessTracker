import SwiftUI

struct SetLoggingView: View {

    let lightImpact = UIImpactFeedbackGenerator(style: .light)
    let confirmationImpact = UIImpactFeedbackGenerator(style: .heavy)
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var viewModel: AddWorkoutViewModel

    init(viewModel: AddWorkoutViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack() {
            addSetView
            if viewModel.isFocused,
               let focusedType = viewModel.focusedFieldType,
               let valueBinding = viewModel.numberPadValueBinding
            {
                NumberPad(
                    type: focusedType,
                    value: valueBinding,
                    editMode: $viewModel.editMode
                )
                .onNext {
                    viewModel.setFocusOnNext()
                }
            }
        }
        .navigationBarItems(
            trailing: Button("Done") {
                confirmationImpact.impactOccurred()
                viewModel.saveWorkout()
            }
        )
        .onAppear {
            viewModel.generateWeightAndSetSuggestion()
        }
    }

    @ViewBuilder
    var addSetView: some View {
        VStack(alignment: .leading) {
            Text(viewModel.selectedExercise)
                .padding()
                .font(.largeTitle)
                .fontWeight(.medium)
            List {
                ForEach(viewModel.sets.indices, id: \.self) { index in
                    HStack {
                        Text("Set \(index + 1)")
                        Spacer()
                        recordTextField(index, .weight)
                        recordTextField(index, .rep)
                    }
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: viewModel.deleteSet)

                Button(action: viewModel.addSet) {
                    Label("Add Set", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.primary)
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .selectionDisabled()
        }
    }

    @ViewBuilder
    private func recordTextField(_ index: Int, _ type: RecordType) -> some View {
        HStack {
            Spacer()
            HStack {
                Text("\(type == .weight ? Int(viewModel.sets[index].weightInLbs) : viewModel.sets[index].reps)")
                    .lineLimit(1)
                    .foregroundStyle(viewModel.isFocusedAndOverwriteEnabled(at: index, type: type) ? (colorScheme == .dark ? .black : .white) : .primary)
                    .fontWeight(.semibold)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .padding(.leading, 8)
                    .padding(.trailing, 8)
                    .background {
                        if viewModel.isFocusedAndOverwriteEnabled(at: index, type: type) {
                            RoundedRectangle(cornerRadius: 8, style: .circular)
                                .foregroundStyle(colorScheme == .dark ? .white : .bratGreen)
                                .transition(.opacity)
                        }
                    }
                Text(type.labelForValue(type == .weight ? Int(viewModel.sets[index].weightInLbs) : viewModel.sets[index].reps))
                    .padding(.leading, 8)
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
            .background {
                if viewModel.isFocused(at: index, type: type) {
                    RoundedRectangle(cornerRadius: 8, style: .circular)
                        .foregroundStyle(.secondary.opacity(0.1))
                        .transition(.opacity)
                }
            }

        }
        .onTapGesture {
            lightImpact.impactOccurred()

            withAnimation {
                if viewModel.isFocused(at: index, type: type) {
                    viewModel.loseFoucs()
                } else {
                    viewModel.setFocus(setNum: index, type: type)
                }
            }
        }
        .frame(width: 120)
    }
}
