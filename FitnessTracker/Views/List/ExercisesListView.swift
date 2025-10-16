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

    private var exercises: [Exercise] {
        exerciseService.exercises
    }

    @Injected var exerciseService: ExerciseService

    @Environment(\.colorScheme) var colorScheme

    @State private var isAddingWorkout = false

    @StateObject var searchContext = SearchContext()

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    if exercises.isEmpty {
                        Text("No exercises found in the last 7 days")
                    } else {
                        List {
                            ForEach(exerciseService.groupedWorkouts(query: searchContext.debouncedSearchText.lowercased()), id: \.date) { group in
                                Section(header: Text(group.date.customFormatted)) {
                                    ForEach(group.exercises) { exercise in
                                        WorkoutRowView(exercise: exercise).background(NavigationLink("", destination: WorkoutDetailView(exercise: exercise))
                                            .opacity(0)
                                        )
                                        .listRowSeparator(.hidden)
                                    }
                                    .onDelete(perform: deleteWorkouts)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("GTFG")
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        AddExerciseButton(isAddingWorkout: $isAddingWorkout)
                    }
                }
            }
        }
        .searchable(text: $searchContext.searchText)
        .sheet(isPresented: $isAddingWorkout) {
            AddWorkoutView(isPresented: $isAddingWorkout)
        }
    }

    private func deleteWorkouts(offsets: IndexSet) {
        withAnimation {
            exerciseService.removeExerciseBulk(indexSet: offsets)
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
