import SwiftUI
import SwiftUIIntrospect

struct SetLoggingView: View {

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
            .navigationBarItems(
                trailing: Button("Done") {
                    confirmationImpact.impactOccurred()
                    viewModel.saveWorkout()
                }
            )
            .sheet(isPresented: $viewModel.showNewExerciseOnboarding, content: { aiSuggestionModal })
            .introspect(.list, on: .iOS(.v26)) { collectionView in
                // swiftui defaults to giving you a ~24 section header top padding which is annoying. This introspect hack fixes it
                var layoutConfig = UICollectionLayoutListConfiguration(appearance: .plain)
                layoutConfig.headerMode = .supplementary
                layoutConfig.headerTopPadding = 0
                let listLayout = UICollectionViewCompositionalLayout.list(using: layoutConfig)
                collectionView.collectionViewLayout = listLayout
            }
            .onAppear {
                viewModel.displayModalIfNeeded()
            }
            .onDisappear {
                viewModel.loseFoucs()
            }
    }
    
    @ViewBuilder
    var addSetView: some View {
        VStack(spacing: 0) {
            recordGridView
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
    }

    @ViewBuilder
    var recordGridView: some View {
        List {
            Section(header:HStack(spacing: 0) {
                Text(viewModel.selectedExercise)
                    .shimmer(enabled: viewModel.isGeneratingRecommendations)
                    .padding()
                    .foregroundStyle(colorScheme == .light ? .black : .white)
                    .font(.largeTitle)
                    .fontWeight(.medium)
                Spacer()
            }
                .listRowInsets(.init())
            ) {
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
        }
        .listStyle(.plain)
        .selectionDisabled()
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

struct InnerHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
