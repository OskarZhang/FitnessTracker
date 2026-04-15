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
    @StateObject private var healthKitManager: HealthKitManager = Container.shared.resolve(HealthKitManager.self)
    
    @Environment(\.colorScheme) var colorScheme

    @State private var isAddingWorkout = false
    @State private var isShowingSettings = false
    @State private var hasAutoRestoredPendingSession = false
    @State private var navigationPath: [NavigationTarget] = []

    @StateObject var searchContext = SearchContext()
    
    @State var groupedExercises: [ExerciseDayGroup] = []

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
                            ForEach(groupedExercises) { group in
                                Section(header:
                                    Text(group.date.customFormatted)
                                    .foregroundStyle(Color.accentColor)
                                ) {
                                    ForEach(group.workouts) { workout in
                                        WorkoutDurationHeaderView(workout: workout)

                                        ForEach(workout.exercises) { exercise in
                                            NavigationLink(value: NavigationTarget.workoutDetail(exercise.id)) {
                                                WorkoutRowView(exercise: exercise)
                                            }
                                            .accessibilityIdentifier("home.workoutRow.\(exercise.name)")
                                            .navigationLinkIndicatorVisibility(.hidden)
                                            .listRowSeparator(.hidden)
                                        }
                                        .onDelete { offsets in
                                            deleteWorkouts(workout: workout, offsets: offsets)
                                        }
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
                        SetLoggingView(
                            viewModel: SetLoggingViewModel(
                                mode: .edit(exercise: exercise),
                                exerciseService: exerciseService,
                                healthKitManager: healthKitManager
                            )
                        )
                    } else {
                        Text("Workout not found")
                    }
                }
            }
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .sheet(isPresented: $isAddingWorkout) {
            AddWorkoutView(
                isPresented: $isAddingWorkout,
                exerciseService: exerciseService,
                healthKitManager: healthKitManager
            )
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
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
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
    }
    
    private func fetchGroupedExercises() {
        groupedExercises = exerciseService.groupedWorkoutSessions(query: searchContext.debouncedSearchText.lowercased())
    }

    private func deleteWorkouts(workout: ExerciseWorkoutGroup, offsets: IndexSet) {
        withAnimation {
            var idSet = Set<UUID>()
            for index in offsets {
                guard index < workout.exercises.count else {
                    fatalError("Something in the index is seriously off")
                }
                let exercise = workout.exercises[index]
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

        switch target {
        case .home:
            navigationPath.removeAll()
        case .addWorkout:
            SetLoggingSessionStore.clearRestoreRequest()
            navigationPath.removeAll()
            isAddingWorkout = true
        case .settings:
            navigationPath.removeAll()
            isShowingSettings = true
        case let .workoutDetail(id):
            navigationPath = [.workoutDetail(id)]
        case let .workoutEdit(id):
            navigationPath = [.workoutEdit(id)]
        }
    }
}

private enum NavigationTarget: Hashable {
    case workoutDetail(UUID)
    case workoutEdit(UUID)
}

private enum DeepLinkTarget {
    case home
    case addWorkout
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

private struct WorkoutDurationHeaderView: View {
    let workout: ExerciseWorkoutGroup

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .semibold))

            Text("Workout duration · \(workout.duration.formattedWorkoutDuration)")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.14), in: Capsule())
        .accessibilityIdentifier("home.workoutDuration.\(workout.id)")
        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 2, trailing: 20))
        .listRowSeparator(.hidden)
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

private extension TimeInterval {
    var formattedWorkoutDuration: String {
        let totalMinutes = Int((self / 60).rounded())
        guard totalMinutes > 0 else { return "<1 min" }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(minutes) min"
        }

        if minutes == 0 {
            return "\(hours) hr"
        }

        return "\(hours) hr \(minutes) min"
    }
}
