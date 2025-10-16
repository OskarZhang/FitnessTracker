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
        let startTime = Date().timeIntervalSince1970
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
        let endTime = Date().timeIntervalSince1970
        debugPrint("grouping perf \(endTime - startTime)s")
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

    let addWorkoutImpact = UIImpactFeedbackGenerator(style: .medium)
    // health data
    @State var authenticated = false
    @State var trigger = false

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
                                Section(header: Text(ExercisesListView.formattedDate(group.date))) {
                                    ForEach(group.exercises) { exercise in
                                        WorkoutRow(exercise: exercise).background(NavigationLink("", destination: WorkoutDetailView(exercise: exercise))
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
                .navigationTitle("Exercises")
                .toolbar {
                    Button("", systemImage: "gear") {
                        showingSettings = true
                        // todo: re-enable export
//                        exportAndPrepareShare()
                    }

                }
                .confirmationDialog("", isPresented: $showingSettings) {
                    Button("Import") {
                        showingImportFileSelector.toggle()
                        print("tapped")
                    }

                    if let csvURL = exportedCSVFileURL {
                        ShareLink(item: csvURL) {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .font(.title2)
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    } else {
                        EmptyView()
                    }
                }
                .fileImporter(isPresented: $showingImportFileSelector, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            importFrom(fileURL: url)
                        }
                    case .failure(let error):
                        print(error)
                    }
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isAddingWorkout = true
                            addWorkoutImpact.impactOccurred()
                        }) {
                            Image(systemName: "plus")
                                .font(.title)
                                .frame(width: 60, height: 60)
                                .background(colorScheme == .dark ? Color.white : Color.black)
                                .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
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

    private func importFrom(fileURL: URL) {
        let importer = CSVImporter()
        _ = fileURL.startAccessingSecurityScopedResource()

        do {
            let csvInput = try String(contentsOf: fileURL)

            // Parse the CSV
            let exercises = try importer.importCSV(csvString: csvInput)

            // Use the parsed exercises
            for exercise in exercises {
                print("Workout ID: \(exercise.id)")
                print("Name: \(exercise.name)")
              switch exercise.type {
                case .strength:
                    print("Type: Strength")
                case .cardio:
                    print("Type: Cardio")
                }
                modelContext.insert(exercise)
            }
        } catch {
            print("Failed to import CSV: \(error.localizedDescription)")
        }
    }

    /// Function to export exercises to CSV and prepare the shareable file
    private func exportAndPrepareShare() {
        let exporter = CSVExporter()
        let csvString = exporter.export(exercises: exercises)

        // Define the temporary file URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "exercises_\(Date().timeIntervalSince1970).csv"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            // Write the CSV string to the temporary file
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            // Update the state to trigger ShareSheet
            exportedCSVFileURL = fileURL

        } catch {
            print("Failed to write CSV file: \(error.localizedDescription)")
            errorMessage = "Failed to export exercises. Please try again."
            showErrorAlert = true
        }
    }

    private static func recentFilter() -> Predicate<Exercise> {
        let recentCutOffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return #Predicate<Exercise> { $0.date >= recentCutOffDate}
    }

    private static func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium // You can choose .short, .medium, .long, or .full
            return formatter.string(from: date)
        }
    }
}

struct WorkoutRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading) {

            Text(exercise.name)
                .font(.system(size: 20, weight: .medium))

            switch exercise.type {
            case .strength:
                Text("\(Int(exercise.maxWeight)) lbs, \(exercise.maxRep) reps, \(exercise.sets?.count ?? 0) sets")
                    .font(.callout)
            case .cardio:
                Text("Cardio: \((exercise.durationInSeconds ?? 0) / 60) minutes")
                    .font(.callout)
            }
        }

    }
}
