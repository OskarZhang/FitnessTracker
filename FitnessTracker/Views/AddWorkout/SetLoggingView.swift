import SwiftUI
import SwiftUIIntrospect

struct SetLoggingView: View {

	private static let bottomActionRowHeight: CGFloat = 110

    let lightImpact = UIImpactFeedbackGenerator(style: .light)
    let confirmationImpact = UIImpactFeedbackGenerator(style: .heavy)
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var showAIGenerationOptions = false
    @ObservedObject var viewModel: SetLoggingViewModel
    let onSave: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SetLoggingViewModel, onSave: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onSave = onSave
    }

    var body: some View {
        addSetView
            .onAppear {
                viewModel.onAppear()
            }
            .onDisappear {
                viewModel.loseFocus()
                if viewModel.persistPendingSessionIfNeeded() {
                    SetLoggingSessionStore.requestRestoreOnNextLaunch(ownerSessionID: AppProcessSession.currentID)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .inactive || newPhase == .background else { return }
                if viewModel.persistPendingSessionIfNeeded() {
                    SetLoggingSessionStore.requestRestoreOnNextLaunch(ownerSessionID: AppProcessSession.currentID)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.shouldShowAIToolbarButton {
                        Button {
                            confirmationImpact.impactOccurred()
                            showAIGenerationOptions = true
                        } label: {
                            if viewModel.isGeneratingRecommendations {
                                ProgressView()
                            } else {
                                Label("AI", systemImage: "sparkles")
                            }
                        }
                        .accessibilityIdentifier("setLogging.aiToolbarButton")
                        .accessibilityLabel("Generate with AI")
                        .disabled(viewModel.isGeneratingRecommendations)
                    }
                }
            }
            .confirmationDialog("Generate with AI", isPresented: $showAIGenerationOptions, titleVisibility: .visible) {
                Button("Append Recommended Sets") {
                    viewModel.generateWeightAndSetSuggestion(insertionMode: .append)
                }
                Button("Replace Current Sets", role: .destructive) {
                    viewModel.generateWeightAndSetSuggestion(insertionMode: .replace)
                }
                Button("Cancel", role: .cancel) { }
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
                if viewModel.shouldShowEndTimeEditor {
                    endTimeEditor
                }
                if viewModel.isEmptyStateForAIRecommendation {
                    aiEmptyStateCard
                        .listRowSeparator(.hidden)
                }
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
								.foregroundColor(viewModel.sets[index].isCompleted ? .accentColor : .secondary)
						}
						.padding(.leading, 8)
                        .buttonStyle(.borderless)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(viewModel.sets[index].isCompleted ? "Set \(index + 1) complete" : "Complete set \(index + 1)")
                        .accessibilityIdentifier("setLogging.completeSetButton.\(index)")
					}
                    .accessibilityIdentifier("setLogging.row.\(index)")
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
                .accessibilityIdentifier("setLogging.addSetButton")
                .listRowSeparator(.hidden)
            }
        }
		.safeAreaPadding(.bottom, Self.bottomActionRowHeight)
        .listStyle(.plain)
    }

    @ViewBuilder
    private var endTimeEditor: some View {
        DatePicker(
            "End time",
            selection: $viewModel.workoutEndedAt,
            displayedComponents: [.date, .hourAndMinute]
        )
        .accessibilityIdentifier("setLogging.endTimePicker")
        .listRowSeparator(.hidden)
    }

	@ViewBuilder
	private var bottomActionRow: some View {

		HStack() {
            stopwatchStatus
				Spacer()

				Button(action: {
                    viewModel.saveWorkout()
                    if let onSave {
                        onSave()
                    } else {
                        dismiss()
                    }
                }) {
					Text("Save")
						.frame(maxHeight: .infinity)
				}
				.buttonStyle(.glassProminent)
				.tint(.accentColor)
                .accessibilityIdentifier("setLogging.saveButton")
			}
		.padding()
		.glassEffect(.clear.tint(.accentColor.opacity(0.08)))
		.padding()
		.frame(height: Self.bottomActionRowHeight)

	}

    @ViewBuilder
    private var stopwatchStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: "stopwatch.fill")
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Rest stopwatch")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.isStopwatchRunning {
                    TimelineView(.periodic(from: .now, by: 1.0)) { context in
                        Text(viewModel.formattedStopwatchElapsed(at: context.date))
                            .font(.headline.monospacedDigit())
                            .contentTransition(.numericText())
                    }
                } else {
                    Text(viewModel.formattedStopwatchElapsed())
                        .font(.headline.monospacedDigit())
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("setLogging.stopwatchStatus")
        .accessibilityLabel("Rest stopwatch")
        .accessibilityValue(viewModel.isStopwatchRunning ? viewModel.formattedStopwatchElapsed() : "stopped")
        .glassEffect(.regular)
    }

    @ViewBuilder
    private var aiEmptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
                    .font(.headline)
                Text("Generate a full recommended set")
                    .font(.headline)
            }
            Text("Use our on-device local LLM model with your weight data to generate a recommended full set.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("setLogging.aiEmptyStateText")

            Button {
                viewModel.generateSuggestedSetForEmptyState()
            } label: {
                if viewModel.isGeneratingRecommendations {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Generate Recommended Set")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glassProminent)
            .tint(Color.accentColor)
            .disabled(viewModel.isGeneratingRecommendations)
            .accessibilityIdentifier("setLogging.aiEmptyStateGenerateButton")
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("setLogging.aiEmptyStateCard")
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
                                .foregroundStyle(colorScheme == .dark ? .white : .accentColor)
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

#Preview {
    SetLoggingView(
		viewModel: SetLoggingViewModel.mocked
    )
}
