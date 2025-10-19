import SwiftUI
import SwiftData
import HealthKitUI
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

    @StateObject var searchContext = SearchContext()
    @Namespace var animation
    
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
                                WeeklyProgressView()
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            ForEach(groupedExercises, id: \.date) { group in
                                Section(header: Text(group.date.customFormatted)) {
                                    ForEach(group.exercises) { exercise in
                                        NavigationLink {
                                            WorkoutDetailView(exercise: exercise)
                                                .navigationTransition(.zoom(sourceID: exercise.id, in: animation))
                                        } label: {
                                            WorkoutRowView(exercise: exercise)
                                                .matchedTransitionSource(id: exercise.id, in: animation)
                                        }
                                        .navigationLinkIndicatorVisibility(.hidden)
                                        .listRowSeparator(.hidden)
                                    }
                                    .onDelete { offsets in
                                        deleteWorkouts(date: group.date, offsets: offsets)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("GTFG")
                .tint(.bratGreen)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        AddExerciseButton(isAddingWorkout: $isAddingWorkout)
                    }
                }
            }
        }
        .searchable(text: $searchContext.searchText, placement: .navigationBarDrawer)
        .sheet(isPresented: $isAddingWorkout) {
            AddWorkoutView(isPresented: $isAddingWorkout)
        }
        .onReceive(exerciseService.objectWillChange) { _ in
            fetchGroupedExercises()
        }
        .onAppear {
            fetchGroupedExercises()
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
