import SwiftUI
import SwiftUIIntrospect

struct SetLoggingView: View {

	private static let bottomActionRowHeight: CGFloat = 110

    let lightImpact = UIImpactFeedbackGenerator(style: .light)
    let confirmationImpact = UIImpactFeedbackGenerator(style: .heavy)
    @Environment(\.colorScheme) var colorScheme

    @State private var sheetHeight: CGFloat = .zero
    @ObservedObject var viewModel: AddWorkoutViewModel

    init(viewModel: AddWorkoutViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        addSetView
            .sheet(isPresented: $viewModel.showNewExerciseOnboarding, content: { aiSuggestionModal })
            .onAppear {
                viewModel.onAppear()
            }
            .onDisappear {
                viewModel.loseFocus()
            }
    }
    
    @ViewBuilder
    var addSetView: some View {
        VStack(spacing: 0) {
			ZStack {
				ScrollViewReader { proxy in
					recordGridView
						.onChange(of: viewModel.currentFocusIndexState) { oldValue, newValue in
							if let setIndex = newValue?.setIndex {
								withAnimation {
									proxy.scrollTo(setIndex)
								}
							}
						}
				}
				if viewModel.hasCompletedAnySet {
					VStack {
						Spacer()

						bottomActionRow
					}
				}
			}
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
                    viewModel.onNumberPadReturn()
                }

            }
        }
    }

    @ViewBuilder
    var recordGridView: some View {
        List {
			Section(header: HStack(spacing: 0) {
				VStack(alignment: .leading, spacing: 0) {
					if viewModel.isGeneratingRecommendations {
						Text("Generating a full set for")
							.multilineTextAlignment(.leading)
							.foregroundStyle(.secondary)
							.font(.title3)
					}
					Text(viewModel.selectedExercise)
						.multilineTextAlignment(.leading)
						.shimmer(enabled: viewModel.isGeneratingRecommendations)
						.foregroundStyle(colorScheme == .light ? .black : .white)
						.font(.largeTitle)
						.fontWeight(.medium)
				}
				.padding()
				Spacer()
			}
                .listRowInsets(.init())
            ) {
                ForEach(viewModel.sets.indices, id: \.self) { index in
					HStack {
						Text("Set \(index + 1)")
							.foregroundStyle(recordColor(at: index))
						Spacer()
						recordTextField(index, .weight)
						recordTextField(index, .rep)

						Button(action: {
							viewModel.toggleSetCompletion(setIndex: index)
						}) {
							Image(systemName: viewModel.sets[index].isCompleted ? "checkmark.rectangle.fill" : "checkmark.rectangle") // SF Symbol
								.font(.system(size: 22))
								.foregroundColor(viewModel.sets[index].isCompleted ? .bratGreen : .secondary)
						}
						.padding(.leading, 8)
					}
					.listRowSeparator(.hidden)
					.id(viewModel.sets[index].id)
                }
                .onDelete(perform: viewModel.deleteSet)
            }
            Section {
                Button(action: viewModel.addSet) {
                    Label("Add Set", systemImage: "plus")
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)
                }
				.buttonStyle(.borderless)
                .listRowSeparator(.hidden)
            }
        }
		.safeAreaPadding(.bottom, Self.bottomActionRowHeight)
        .listStyle(.plain)
    }

	@ViewBuilder
	private var bottomActionRow: some View {

		HStack() {
				Button(action: viewModel.startTimer) {
				Label("Start timer", systemImage: "timer")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.foregroundStyle(colorScheme == .light ? .black : .white)
					.opacity(viewModel.timerPercentage > 0.0 ? 0.0 : 1.0)
					.background {
						GeometryReader { geo in
							if viewModel.timerPercentage > 0.0 {
								ZStack(alignment: .leading) {
									HStack(spacing: 0) {
										Rectangle()
											.fill(Color.bratGreen)
											.frame(width: geo.size.width * viewModel.timerPercentage)
										Spacer()
									}
									// inverted color text when timer progress moves
									Text("\(viewModel.timeInSecLeft)s")
										.multilineTextAlignment(.center)
										.font(.headline.monospaced())
										.foregroundStyle(.white)
										.frame(width: geo.size.width)
									Text("\(viewModel.timeInSecLeft)s")
										.multilineTextAlignment(.center)
										.font(.headline.monospaced())
										.foregroundStyle(Color.black)
										.frame(width: geo.size.width)
										.mask(Rectangle().offset(x: geo.size.width * viewModel.timerPercentage, y: 0))
								}
							}
						}
					}

				}
				.clipShape(Capsule())
				.glassEffect(.regular.interactive(true))
				Spacer()

				Button(action: viewModel.saveWorkout) {
					Text("Save")
						.frame(maxHeight: .infinity)
				}
				.buttonStyle(.glassProminent)
				.tint(.bratGreen)
			}
		.padding()
		.glassEffect(.clear.tint(.bratGreen.opacity(0.08)))
		.padding()
		.frame(height: Self.bottomActionRowHeight)

	}

    @ViewBuilder
    private var aiSuggestionModal: some View {
        VStack(alignment: .leading) {
            Text("First time? ")
                .multilineTextAlignment(.leading)
                .font(.title)
                .fontWeight(.medium)
                .padding(.top)
            Text("GTFG AI can recommend you a full set based on your data.")
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

    }

    private func recordColor(at index: Int) -> Color {
        if viewModel.sets[index].isCompleted {
            return .primary
        } else {
            return .secondary
        }
    }
    @ViewBuilder
    private func recordTextField(_ index: Int, _ type: RecordType) -> some View {
        HStack {
            Spacer()
			HStack(spacing: 0) {
                Text("\(type == .weight ? Int(viewModel.sets[index].weightInLbs) : viewModel.sets[index].reps)")
                    .lineLimit(1)
                    .foregroundStyle(viewModel.isFocusedAndOverwriteEnabled(at: index, type: type) ? (colorScheme == .dark ? .black : .white) : (recordColor(at: index)))
                    .fontWeight(.semibold)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
					.padding(.leading, viewModel.isFocused(at: index, type: type) ? 8 : 4)
                    .padding(.trailing, viewModel.isFocused(at: index, type: type) ? 8 : 4)
                    .background {
                        if viewModel.isFocusedAndOverwriteEnabled(at: index, type: type) {
                            RoundedRectangle(cornerRadius: 8, style: .circular)
                                .foregroundStyle(colorScheme == .dark ? .white : .bratGreen)
                                .transition(.opacity)
                        }
                    }
                Text(type.labelForValue(type == .weight ? Int(viewModel.sets[index].weightInLbs) : viewModel.sets[index].reps))
                    .foregroundStyle(recordColor(at: index))
                    .padding(.leading, 4)
                    .padding(.trailing, 4)
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

                if viewModel.isFocused(at: index, type: type) {
                    viewModel.loseFocus()
                } else {
                    viewModel.setFocus(setIndex: index, type: type)
                }
        }
        .frame(width: 120)
    }
}

struct InnerHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    SetLoggingView(
		viewModel: AddWorkoutViewModel.mocked
    )
}


fileprivate extension AddWorkoutViewModel {
  static var mocked: AddWorkoutViewModel {

	  let vm = AddWorkoutViewModel(isPresented: .constant(true))

	  vm.selectedExercise = "Bench Press"

	  vm.sets = [
		StrengthSetData(weightInLbs: 200, reps: 10),
		StrengthSetData(weightInLbs: 200, reps: 10),
		StrengthSetData(weightInLbs: 200, reps: 10)
	  ]
	  vm.hasSeenNewExerciseOnboarding = true
	  return vm
  }
}
