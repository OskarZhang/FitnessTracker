import SwiftUI
import SwiftData
import Combine

class SearchContext: ObservableObject {

    @Published var searchText: String = ""
    @Published var debouncedSearchText: String = ""

    init() {
        $searchText
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .assign(to: &$debouncedSearchText)
    }
}

struct ExercisesListView: View {
    @StateObject private var exerciseService: ExerciseService = Container.shared.resolve(ExerciseService.self)
    private let workoutLiveActivityService: WorkoutLiveActivityService = Container.shared.resolve(WorkoutLiveActivityService.self)
    @Environment(\.scenePhase) private var scenePhase
    
    @Environment(\.colorScheme) var colorScheme

    @State private var isAddingWorkout = false
    @State private var isShowingSettings = false
    @State private var hasAutoRestoredPendingSession = false
    @State private var liveDeepLinkExerciseName: String?
    @State private var livePromptContext: LiveWorkoutPromptContext?
    @State private var liveSetLoggingContext: LiveSetLoggingContext?
    @State private var navigationPath: [NavigationTarget] = []
    @State private var hasBecomeActiveInProcess = false
    @State private var didEnterBackgroundInProcess = false
    @State private var justResumedFromBackgroundInProcess = false

    @StateObject var searchContext = SearchContext()
    
    @State var groupedExercises: [(date: Date, exercises: [Exercise])] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                VStack {
                    if exerciseService.exercises.isEmpty {
                        EmptyExercisesStateView()
                    } else {
                        List {
                            Section {
                                Text("GTFG")
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 44))
                                    .fontWeight(.heavy)
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(Color.accentColor)
                                    .padding()
                                WeeklyProgressView()
                                    .padding(.vertical)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            ForEach(groupedExercises, id: \.date) { group in
                                Section(header:
                                    Text(group.date.customFormatted)
                                    .foregroundStyle(Color.accentColor)
                                ) {
                                    ForEach(group.exercises) { exercise in
                                        NavigationLink(value: NavigationTarget.workoutDetail(exercise.id)) {
                                            WorkoutRowView(exercise: exercise)
                                        }
                                        .accessibilityIdentifier("home.workoutRow.\(exercise.name)")
                                        .navigationLinkIndicatorVisibility(.hidden)
                                        .listRowSeparator(.hidden)
                                    }
                                    .onDelete { offsets in
                                        deleteWorkouts(date: group.date, offsets: offsets)
                                    }
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.grouped)
                    }
                }
                .tint(.accentColor)
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Spacer()
                        AddExerciseButton(isAddingWorkout: $isAddingWorkout)
                            .padding(.bottom, exerciseService.exercises.isEmpty ? 34 : 0)
                            .overlay(alignment: .leading) {
                                if exerciseService.exercises.isEmpty {
                                    EmptyStateAddHintView(screenWidth: UIScreen.main.bounds.width)
                                        .offset(
                                            x: -(min(max(UIScreen.main.bounds.width * 0.46, 164), 206)),
                                            y: -80
                                        )
                                }
                            }
                    }
                }
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            isShowingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(10)
                                .background(Color(.systemBackground).opacity(0.9), in: Circle())
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("home.settingsButton")
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }
                    Spacer()
                }
            }
            .navigationDestination(for: NavigationTarget.self) { target in
                switch target {
                case let .workoutDetail(id):
                    if let exercise = exercise(withID: id) {
                        WorkoutDetailView(exercise: exercise)
                    } else {
                        Text("Workout not found")
                    }
                case let .workoutEdit(id):
                    if let exercise = exercise(withID: id) {
                        SetLoggingView(viewModel: SetLoggingViewModel(mode: .edit(exercise: exercise)))
                    } else {
                        Text("Workout not found")
                    }
                }
            }
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .sheet(isPresented: $isAddingWorkout, onDismiss: {
            liveDeepLinkExerciseName = nil
        }) {
            AddWorkoutView(isPresented: $isAddingWorkout, initialExerciseName: liveDeepLinkExerciseName)
                .id(liveDeepLinkExerciseName ?? "manual-add")
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(item: $liveSetLoggingContext, onDismiss: {
            liveSetLoggingContext = nil
        }) { context in
            SetLoggingView(
                viewModel: SetLoggingViewModel(mode: .add(exerciseName: context.exerciseName, pendingSession: nil)),
                onSave: {
                    liveSetLoggingContext = nil
                }
            )
        }
        .sheet(item: $livePromptContext) { context in
            LiveWorkoutPromptSheet(
                suggestedExerciseName: context.suggestedExerciseName,
                onEndWorkout: {
                    livePromptContext = nil
                    Task {
                        await workoutLiveActivityService.endSessionAndLogToHealthKit()
                    }
                },
                onSuggestNextExercise: {
                    let exerciseName = context.suggestedExerciseName
                    livePromptContext = nil
                    SetLoggingSessionStore.clearRestoreRequest()
                    navigationPath.removeAll()
                    workoutLiveActivityService.startOrUpdateForLogging(exerciseName: exerciseName)
                    workoutLiveActivityService.recordInteraction()
                    liveSetLoggingContext = LiveSetLoggingContext(exerciseName: exerciseName)
                }
            )
        }
        .onChange(of: exerciseService.exercises) { _, _ in
            fetchGroupedExercises()
        }
        .onChange(of: searchContext.debouncedSearchText) { _, _ in
            fetchGroupedExercises()
        }
        .onAppear {
            fetchGroupedExercises()
            if !hasAutoRestoredPendingSession, SetLoggingSessionStore.shouldRestoreOnNextLaunch {
                isAddingWorkout = true
                hasAutoRestoredPendingSession = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if hasBecomeActiveInProcess && (newPhase == .inactive || newPhase == .background) {
                didEnterBackgroundInProcess = true
            }

            if newPhase == .active {
                if didEnterBackgroundInProcess {
                    justResumedFromBackgroundInProcess = true
                    didEnterBackgroundInProcess = false
                    DispatchQueue.main.async {
                        justResumedFromBackgroundInProcess = false
                    }
                }
                hasBecomeActiveInProcess = true
            }
        }
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
    }
    
    private func fetchGroupedExercises() {
        groupedExercises = exerciseService.groupedWorkouts(query: searchContext.debouncedSearchText.lowercased())
    }

    private func deleteWorkouts(date: Date, offsets: IndexSet) {
        withAnimation {
            guard let exercises = groupedExercises.first(where: { $0.date == date })?.exercises else {
                return
            }
            var idSet = Set<UUID>()
            for index in offsets {
                guard index < exercises.count else {
                    fatalError("Something in the index is seriously off")
                }
                let exercise = exercises[index]
                idSet.insert(exercise.id)
            }
            exerciseService.removeExerciseBulk(idSet: idSet)
        }
    }

    private func exercise(withID id: UUID) -> Exercise? {
        exerciseService.exercises.first { $0.id == id }
    }

    private func latestExerciseID() -> UUID? {
        exerciseService.exercises.first?.id
    }

    private func handleDeepLink(url: URL) {
        guard let target = DeepLinkTarget(url: url, latestExerciseID: latestExerciseID()) else {
            return
        }

        isAddingWorkout = false
        isShowingSettings = false
        livePromptContext = nil
        liveSetLoggingContext = nil

        switch target {
        case .home:
            navigationPath.removeAll()
            liveDeepLinkExerciseName = nil
        case .addWorkout:
            SetLoggingSessionStore.clearRestoreRequest()
            navigationPath.removeAll()
            liveDeepLinkExerciseName = nil
            isAddingWorkout = true
        case .settings:
            navigationPath.removeAll()
            liveDeepLinkExerciseName = nil
            isShowingSettings = true
        case let .liveWorkout(exerciseName, presentation):
            SetLoggingSessionStore.clearRestoreRequest()
            navigationPath.removeAll()
            if presentation == .prompt {
                liveDeepLinkExerciseName = nil
                let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                let promptExercise = trimmed.isEmpty ? "Continue your active workout" : trimmed
                livePromptContext = LiveWorkoutPromptContext(suggestedExerciseName: promptExercise)
            } else {
                livePromptContext = nil
                liveDeepLinkExerciseName = nil
                if justResumedFromBackgroundInProcess {
                    // In-process resume from Dynamic Island should not alter navigation.
                    return
                }
                let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    workoutLiveActivityService.startOrUpdateForLogging(exerciseName: trimmed)
                    workoutLiveActivityService.recordInteraction()
                    liveSetLoggingContext = LiveSetLoggingContext(exerciseName: trimmed)
                }
            }
        case let .workoutDetail(id):
            liveDeepLinkExerciseName = nil
            livePromptContext = nil
            liveSetLoggingContext = nil
            navigationPath = [.workoutDetail(id)]
        case let .workoutEdit(id):
            liveDeepLinkExerciseName = nil
            livePromptContext = nil
            liveSetLoggingContext = nil
            navigationPath = [.workoutEdit(id)]
        }
    }
}

private struct LiveWorkoutPromptContext: Identifiable {
    let id = UUID()
    let suggestedExerciseName: String
}

private struct LiveSetLoggingContext: Identifiable {
    let id = UUID()
    let exerciseName: String
}

private enum NavigationTarget: Hashable {
    case workoutDetail(UUID)
    case workoutEdit(UUID)
}

private enum DeepLinkTarget {
    enum LivePresentation: Equatable {
        case direct
        case prompt
    }

    case home
    case addWorkout
    case liveWorkout(String, LivePresentation)
    case settings
    case workoutDetail(UUID)
    case workoutEdit(UUID)

    init?(url: URL, latestExerciseID: UUID?) {
        guard let scheme = url.scheme?.lowercased(), scheme == "fitnesstracker" else {
            return nil
        }

        let host = url.host?.lowercased() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "home":
            self = .home
        case "add":
            self = .addWorkout
        case "live":
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let exercise = components.queryItems?.first(where: { $0.name == "exercise" })?.value,
                  !exercise.isEmpty else {
                return nil
            }
            let sessionState = components.queryItems?.first(where: { $0.name == "state" })?.value
            let presentation: LivePresentation = sessionState == WorkoutLiveSessionState.needsPostWorkoutPrompt.rawValue
                ? .prompt
                : .direct
            self = .liveWorkout(exercise, presentation)
        case "settings":
            self = .settings
        case "workout":
            guard let first = pathComponents.first else { return nil }
            let id: UUID?
            if first.lowercased() == "latest" {
                id = latestExerciseID
            } else {
                id = UUID(uuidString: first)
            }
            guard let resolvedID = id else { return nil }
            if pathComponents.dropFirst().first?.lowercased() == "edit" {
                self = .workoutEdit(resolvedID)
            } else {
                self = .workoutDetail(resolvedID)
            }
        default:
            return nil
        }
    }
}

private struct EmptyExercisesStateView: View {
    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 24)

            Text("No exercises found")
                .font(.system(size: 16))
                .foregroundStyle(Color.primary.opacity(0.42))
                .accessibilityIdentifier("home.emptyStateText")

            Spacer()
        }
        .padding(.horizontal, 12)
    }
}

private struct LiveWorkoutPromptSheet: View {
    let suggestedExerciseName: String?
    let onEndWorkout: () -> Void
    let onSuggestNextExercise: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Continue your workout?")
                        .font(.title3.bold())

                    Text("You're between exercises. Choose your next step.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Next likely exercise")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(nextLikelyExerciseText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    dismiss()
                    onSuggestNextExercise()
                } label: {
                    Label("Suggest Next Exercise", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("livePrompt.suggestNextButton")

                Button {
                    dismiss()
                    onEndWorkout()
                } label: {
                    Label("End Workout", systemImage: "stop.circle")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1.5)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("livePrompt.endWorkoutButton")

                Text("You can still end later from home.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemBackground))
        }
    }

    private var nextLikelyExerciseText: String {
        let fallback = "Continue your active workout"
        guard let suggestedExerciseName else { return fallback }
        let trimmed = suggestedExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return trimmed
    }
}

private struct EmptyStateAddHintView: View {
    let screenWidth: CGFloat

    private var fontSize: CGFloat {
        min(max(screenWidth * 0.06, 18), 24)
    }

    private var arrowWidth: CGFloat {
        fontSize * 2.1
    }

    private var arrowHeight: CGFloat {
        fontSize * 1.6
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text("Tap + to begin")
                .font(.custom("Noteworthy-Bold", size: fontSize))
                .foregroundStyle(Color.accentColor.opacity(0.95))
                .rotationEffect(.degrees(-4))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: false)
                .offset(y: 2)

            ScribbleArrow()
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                )
                .frame(width: arrowWidth, height: arrowHeight)
                .offset(y: 7)
        }
        .accessibilityHidden(true)
    }
}

private struct ScribbleArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let start = CGPoint(x: rect.minX + 2, y: rect.midY - 8)
        let tip = CGPoint(x: rect.maxX - 16, y: rect.midY + 8)
        path.move(to: start)
        path.addLine(to: tip)

        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - 14, y: tip.y - 2))
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - 8, y: tip.y - 14))

        return path
    }
}

#Preview {
    ExercisesListView()
}

private extension Date {
    var customFormatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: self)
        }

    }
}
