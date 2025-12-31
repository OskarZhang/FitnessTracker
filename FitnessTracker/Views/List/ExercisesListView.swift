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


    @Injected var exerciseService: ExerciseService
    
    @Environment(\.colorScheme) var colorScheme

    @State private var isAddingWorkout = false
    @State private var isShowingSettings = false
    @State private var hasAutoRestoredPendingSession = false

    @StateObject var searchContext = SearchContext()
    
    @State var groupedExercises: [(date: Date, exercises: [Exercise])] = []

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    if exerciseService.exercises.isEmpty {
                        Text("No exercises found in the last 7 days")
                    } else {
                        List {
                            Section {
                                Text("GTFG")
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 44))
                                    .fontWeight(.heavy)
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(Color.bratGreen)
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
                                    .foregroundStyle(Color.bratGreen)
                                ) {
                                    ForEach(group.exercises) { exercise in
                                        NavigationLink {
                                            WorkoutDetailView(exercise: exercise)
                                        } label: {
                                            WorkoutRowView(exercise: exercise)
                                        }
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
                .tint(.bratGreen)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        AddExerciseButton(isAddingWorkout: $isAddingWorkout)
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
                                .foregroundStyle(Color.bratGreen)
                                .padding(10)
                                .background(Color(.systemBackground).opacity(0.9), in: Circle())
                        }
                        .accessibilityLabel("Settings")
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }
                    Spacer()
                }
            }
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .sheet(isPresented: $isAddingWorkout) {
            AddWorkoutView(isPresented: $isAddingWorkout)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .onReceive(exerciseService.objectWillChange) { _ in
            fetchGroupedExercises()
        }
        .onAppear {
            fetchGroupedExercises()
            if !hasAutoRestoredPendingSession, SetLoggingSessionStore.hasPendingSession {
                isAddingWorkout = true
                hasAutoRestoredPendingSession = true
            }
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
