import SwiftUI

struct SetLoggingView: View {

    private struct FocusIndex: Equatable, Hashable {
        var setNum: Int
        var type: RecordType

        static let initial = FocusIndex(setNum: 0, type: .weight)

        func next() -> FocusIndex {
            var nextSetNum = setNum
            var nextType = type
            if type == .rep {
                nextSetNum += 1
                nextType = .weight
            } else {
                nextType = .rep
            }
            return Self.init(setNum: nextSetNum, type: nextType)
        }
    }

    let lightImpact = UIImpactFeedbackGenerator(style: .light)
    let confirmationImpact = UIImpactFeedbackGenerator(style: .heavy)
    @Environment(\.colorScheme) var colorScheme

    @Binding var isPresented: Bool

    /// When a number field is initially focused, we will default to overwriting it instead of appending. Since there is always only one keyboard at a time, we will just use one flag for the entire view
    @State private var shouldOverwrite = true
    @State private var currentFocusIndexState: FocusIndex? = .initial {
        didSet {
            shouldOverwrite = true
        }
    }

    @State var weight: Int = 0
    @State var reps: Int = 0
    let exerciseName: String
    let onSave: ([StrengthSet]) -> Void
    @State var showingNumberPad: Bool = true
    @State private var timerRemaining: TimeInterval = 120
    @State private var timerIsActive: Bool = false
    @State private var timer: Timer?

    @State private var sets: [StrengthSet] = [StrengthSet(weightInLbs: 0, reps: 0)]

    init(sets: [StrengthSet]? = nil, isPresented: Binding<Bool>, exerciseName: String, onSave: @escaping ([StrengthSet]) -> Void) {
        self._isPresented = isPresented
        var lastSet = sets ?? [StrengthSet(weightInLbs: 0, reps: 0)]
        if lastSet.count == 0 {
            lastSet = [StrengthSet(weightInLbs: 0, reps: 0)]
        }
        self.sets = lastSet
        self.exerciseName = exerciseName
        self.onSave = onSave
    }

    var body: some View {
        VStack() {
            ZStack {
                addSetView()
                VStack {
                    Spacer()
                    if shouldShowTimerButton {
                        timerButton
                            .padding(.trailing, 8)
                            .padding(.bottom, 8)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom),
                                removal: .opacity
                            ))
                    }
                }
            }

            if let currentFocusIndexState,
                showingNumberPad {
                NumberPad(
                    type: currentFocusIndexState.type,
                    value: Binding(
                        get: {
                            let set = sets[currentFocusIndexState.setNum]
                            return currentFocusIndexState.type == .weight ? Int(set.weightInLbs) : set.reps
                        },
                        set: { value in
                            if currentFocusIndexState.type == .weight {
                                sets[currentFocusIndexState.setNum].weightInLbs = Double(value)
                            } else {
                                sets[currentFocusIndexState.setNum].reps = value
                            }
                        }),
                    shouldOverwrite: $shouldOverwrite
                )
                .onNext {
                    nextButtonTapped()
                }
            }

        }
        .navigationBarItems(
            trailing: Button("Done") {
                confirmationImpact.impactOccurred()
                onSave(sets)
                isPresented = false
            }
        )
        .onDisappear {
            stopTimer()
        }
    }

    private var shouldShowTimerButton: Bool {
        return currentFocusIndexState?.type == .rep
    }
    
    private var timerDisplayText: String {
        let minutes = Int(timerRemaining) / 60
        let seconds = Int(timerRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    @ViewBuilder
    private var timerButton: some View {
        HStack(alignment: .bottom) {
            Spacer()
            Button(action: startRestTimer) {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white : Color.black)
                        .frame(width: 70, height: 70)

                    if timerIsActive {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                            .frame(width: 64, height: 64)

                        Circle()
                            .trim(from: 0, to: CGFloat(1 - (timerRemaining / 120)))
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: timerRemaining)
                    }
                    VStack {
                        Text(timerIsActive ? timerDisplayText : "2:00")
                            .font(.system(size: 18, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        if !timerIsActive {
                            Text("Start")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                }
                .shadow(radius: 4)
                .animation(.easeInOut(duration: 0.2), value: timerIsActive)
            }
        }
    }
    
    private func startRestTimer() {
        lightImpact.impactOccurred()
        
        if timerIsActive {
            stopTimer()
        } else {
            timerIsActive = true
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if timerRemaining > 0 {
                    timerRemaining -= 1
                } else {
                    timerFinished()
                }
            }
        }
    }
    
    private func stopTimer() {
        timerIsActive = false
        timer?.invalidate()
        timerRemaining = 120
        timer = nil
    }
    
    private func timerFinished() {
        stopTimer()
        timerRemaining = 120
        confirmationImpact.impactOccurred()
    }

    @ViewBuilder
    func addSetView() -> some View {

        VStack(alignment: .leading) {
            Text(exerciseName)
                .padding()
                .font(.largeTitle)
                .fontWeight(.medium)

            List {
                ForEach(sets.indices, id: \.self) { index in
                    HStack {
                        Text("Set \(index + 1)")
                        Spacer()
                        numberPadField(index, .weight)
                        numberPadField(index, .rep)
                    }
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: deleteSet)

                Button(action: addSet) {
                    Label("Add Set", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.bratGreen)
                }
                .listRowSeparator(.hidden)
            }

            .listStyle(.plain)
            .selectionDisabled()
        }
    }


    @ViewBuilder
    private func numberPadField(_ index: Int, _ type: RecordType) -> some View {
        HStack {
            Spacer()
            HStack {
                Text("\(type == .weight ? Int(sets[index].weightInLbs) : sets[index].reps)")
                    .lineLimit(1)
                    .foregroundStyle(shouldOverwrite && currentFocusIndexState == FocusIndex(setNum: index, type: type) ? (colorScheme == .dark ? .black : .white) : .primary)
                    .fontWeight(.semibold)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .padding(.leading, 4)
                    .padding(.trailing, 4)
                    .background {
                        if shouldOverwrite && currentFocusIndexState == FocusIndex(setNum: index, type: type){
                            RoundedRectangle(cornerRadius: 8, style: .circular)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                .transition(.opacity)
                        }
                    }
                Text(type.labelForValue(type == .weight ? Int(sets[index].weightInLbs) : sets[index].reps))
                    .padding(.leading, 4)
                    .padding(.trailing, 4)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
                .background {
                    if currentFocusIndexState == FocusIndex(setNum: index, type: type) {
                        RoundedRectangle(cornerRadius: 8, style: .circular)
                            .foregroundStyle(.secondary.opacity(0.1))
                            .transition(.opacity)
                    }
                }

        }
        .onTapGesture {
            lightImpact.impactOccurred()

            withAnimation {
                if showingNumberPad && currentFocusIndexState == FocusIndex(setNum: index, type: type) {
                    // only disappear keyboard in this instance
                    showingNumberPad = false
                    currentFocusIndexState = nil
                } else {
                    showingNumberPad = true
                    currentFocusIndexState = FocusIndex(setNum: index, type: type)
                }
            }
        }
        .frame(width: 100)
    }

    private func nextButtonTapped() {
        let nextFocus = currentFocusIndexState?.next()
        withAnimation {
            currentFocusIndexState = nextFocus
        }

        if let currentFocusIndexState,
           currentFocusIndexState.setNum + 1 > sets.count
        {
            addSet()
        }
    }

    private func addSet() {
        let lastSet = sets.last
        withAnimation {
            sets.append(StrengthSet(weightInLbs: lastSet?.weightInLbs ?? 0, reps: lastSet?.reps ?? 0))
        }
    }

    private func deleteSet(at offsets: IndexSet) {
        withAnimation {
            sets.remove(atOffsets: offsets)
        }
    }
}

extension View {
    func styledNumberPadText(height: CGFloat, colorScheme: ColorScheme) -> some View {
        return self
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.systemGray2) : Color(.white))
                    .shadow(radius: 0.4)
            )
            .foregroundColor(.primary)
    }
}
