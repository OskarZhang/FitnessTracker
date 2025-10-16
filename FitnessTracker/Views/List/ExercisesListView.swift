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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.date, order: .reverse) private var exercises: [Exercise]

    let exerciseService: ExerciseService

    init(exerciseService: ExerciseService) {
        self.exerciseService = exerciseService
    }

    var groupedWorkouts: [(date: Date, exercises: [Exercise])] {
        let groupedDict = Dictionary(grouping: exercises.filter({ exercise in
            searchContext.debouncedSearchText.isEmpty || exercise.name.lowercased().contains(searchContext.debouncedSearchText.lowercased())
        })) { exercise in
            // Normalize the date to remove time components
            Calendar.current.startOfDay(for: exercise.date)
        }
        // Sort the dates in descending order
        let sortedDates = groupedDict.keys.sorted(by: >)
        // Map the sorted dates to an array of tuples
        let res = sortedDates.map { date in
            (date: date, exercises: groupedDict[date]!)
        }
        return res
    }
    @Environment(\.colorScheme) var colorScheme

    @State private var isAddingWorkout = false
    @State private var isPresentingExperimentalAdd = false
    @State private var showingSettings = false
    @State private var showingImportFileSelector = false

    @State private var isShareSheetPresented: Bool = false
    @State private var exportedCSVFileURL: URL?
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    @StateObject var searchContext = SearchContext()

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    if exercises.isEmpty {
                        Text("No exercises found in the last 7 days")
                    } else {
                        List {
                            ForEach(groupedWorkouts, id: \.date) { group in
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
            AddWorkoutView(isPresented: $isAddingWorkout, exerciseService: exerciseService)
        }
    }

    private func deleteWorkouts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                print("deleting index \(index)")
                modelContext.delete(exercises[index])
            }
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
            formatter.dateStyle = .medium // You can choose .short, .medium, .long, or .full
            return formatter.string(from: self)
        }

    }
}
