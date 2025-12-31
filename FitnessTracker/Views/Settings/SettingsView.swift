import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Injected private var healthKitManager: HealthKitManager
    @Injected private var exerciseService: ExerciseService

    @State private var isAuthorizing = false
    @State private var isExporting = false
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Health") {
                    HStack {
                        Text("HealthKit")
                        Spacer()
                        Text(healthKitStatusLabel)
                            .foregroundStyle(.secondary)
                    }

                    if !isHealthKitAuthorized {
                        Button {
                            authorizeHealthKit()
                        } label: {
                            if isAuthorizing {
                                ProgressView()
                            } else {
                                Text("Enable HealthKit")
                            }
                        }
                        .disabled(isAuthorizing || !healthKitManager.isAvailable)
                    }

                    Button {
                        exportLatestWorkout()
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            Text("Export latest workout day")
                        }
                    }
                    .disabled(!isHealthKitAuthorized || isExporting)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                healthKitManager.refreshAuthorizationStatus()
            }
        }
    }

    private var healthKitStatusLabel: String {
        guard healthKitManager.isAvailable else { return "Unavailable" }
        switch healthKitManager.workoutAuthorizationStatus {
        case .sharingDenied:
            return "Denied"
        case .notDetermined:
            return "Not enabled"
        case .sharingAuthorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }

    private var isHealthKitAuthorized: Bool {
        healthKitManager.workoutAuthorizationStatus == .sharingAuthorized
    }

    private func authorizeHealthKit() {
        statusMessage = nil
        isAuthorizing = true
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                statusMessage = "HealthKit enabled."
            } catch {
                statusMessage = error.localizedDescription
            }
            isAuthorizing = false
        }
    }

    private func exportLatestWorkout() {
        statusMessage = nil
        isExporting = true
        Task {
            defer { isExporting = false }
            guard let latestDay = exerciseService.groupedWorkouts().first else {
                statusMessage = "No workouts to export yet."
                return
            }
            do {
                try await healthKitManager.writeStrengthWorkout(exercises: latestDay.exercises)
                statusMessage = "Workout exported to Health."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    SettingsView()
}
