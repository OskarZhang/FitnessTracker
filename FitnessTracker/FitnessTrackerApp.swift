//
//  FitnessTrackerApp.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 9/2/24.
//

import SwiftUI
import SwiftData

@main
struct FitnessTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorID = AppAccentColor.brat.rawValue
    @State private var didEnterBackgroundInProcess = false
    @State private var hasBecomeActiveOnce = false
    private let isUITestSession: Bool
    private let forceOnboardingForIntegrationTests: Bool
    private let completeOnboardingForIntegrationTests: Bool

    init() {
        let launchArguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let shouldResetForUITests = launchArguments.contains("UI_TEST_RESET")
        let shouldResetForIntegrationTests = launchArguments.contains("INT_TEST_RESET_DATA")
        self.forceOnboardingForIntegrationTests = launchArguments.contains("INT_TEST_FORCE_ONBOARDING")
        self.completeOnboardingForIntegrationTests = launchArguments.contains("INT_TEST_COMPLETE_ONBOARDING")
        self.isUITestSession = shouldResetForUITests
            || launchArguments.contains("UITEST")
            || environment["XCTestConfigurationFilePath"] != nil

        if forceOnboardingForIntegrationTests {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        } else if completeOnboardingForIntegrationTests {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        #if DEBUG
        Container.shared.registerSingleton(ExerciseService.self) {
            ExerciseService(resetData: shouldResetForUITests || shouldResetForIntegrationTests)
        }
        #else
        Container.shared.registerSingleton(ExerciseService.self) { ExerciseService() }
        #endif
        Container.shared.registerSingleton(HealthKitManager.self) { HealthKitManager() }
        Container.shared.registerSingleton(WorkoutLiveActivityService.self) {
            WorkoutLiveActivityService(exerciseService: Container.shared.resolve(ExerciseService.self))
        }
        BackgroundSyncManager.shared.register()
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if shouldShowOnboarding && !isUITestSession {
                    OnboardingView(accentColor: AppAccentColor.fromStoredValue(appAccentColorID).color) {
                        hasCompletedOnboarding = true
                    }
                } else {
                    ExercisesListView()
                }
            }
            .tint(AppAccentColor.fromStoredValue(appAccentColorID).color)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if hasBecomeActiveOnce && (newPhase == .inactive || newPhase == .background) {
                didEnterBackgroundInProcess = true
            }

            if newPhase == .background {
                BackgroundSyncManager.shared.schedule()
                let liveActivityService: WorkoutLiveActivityService = Container.shared.resolve(WorkoutLiveActivityService.self)
                liveActivityService.endIfInactive()
            } else if newPhase == .active, didEnterBackgroundInProcess {
                // App resumed in the same process; this was not a kill/relaunch restore case.
                SetLoggingSessionStore.clearRestoreRequest()
                didEnterBackgroundInProcess = false
                let liveActivityService: WorkoutLiveActivityService = Container.shared.resolve(WorkoutLiveActivityService.self)
                liveActivityService.endIfInactive()
            }

            if newPhase == .active {
                let liveActivityService: WorkoutLiveActivityService = Container.shared.resolve(WorkoutLiveActivityService.self)
                liveActivityService.endIfInactive()
                hasBecomeActiveOnce = true
            }
        }
    }

    private var shouldShowOnboarding: Bool {
        if completeOnboardingForIntegrationTests {
            return false
        }
        return !hasCompletedOnboarding
    }
}

private struct OnboardingView: View {
    let accentColor: Color
    let onFinish: () -> Void
    @StateObject private var healthKitManager: HealthKitManager = Container.shared.resolve(HealthKitManager.self)
    @State private var isRequestingHealthKit = false
    @State private var healthKitMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accentColor.opacity(0.15),
                    Color(.systemBackground),
                    accentColor.opacity(0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 20)

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .padding(24)
                    .glassEffect(.regular.tint(accentColor.opacity(0.08)))

                VStack(spacing: 10) {
                    Text("Enable HealthKit Sync")
                        .font(.system(size: 34, weight: .heavy))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("onboarding.title")

                    Text("Allow FitnessTracker to use your Health app workout data to auto-add exercises.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .accessibilityIdentifier("onboarding.message")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("How your data is used")
                        .font(.headline)
                    Text("• Workout type and date are used to auto-add matching exercise entries.")
                        .foregroundStyle(.secondary)
                    Text("• Estimated duration and calories help prefill suggested set context.")
                        .foregroundStyle(.secondary)
                    Text("• Data stays on-device unless you explicitly export to Health.")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 24)

                if let healthKitMessage {
                    Text(healthKitMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .accessibilityIdentifier("onboarding.healthkitMessage")
                }

                Button {
                    enableHealthKitAndFinish()
                } label: {
                    if isRequestingHealthKit {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("Enable HealthKit Sync")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .disabled(isRequestingHealthKit)
                .background(
                    Capsule(style: .continuous)
                        .fill(accentColor)
                )
                .clipShape(Capsule(style: .continuous))
                .padding(.horizontal, 24)
                .accessibilityIdentifier("onboarding.enableHealthKitButton")

                Button("Not now") {
                    onFinish()
                }
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 18)
                .accessibilityIdentifier("onboarding.notNowButton")

                Spacer()
            }
        }
    }

    private func enableHealthKitAndFinish() {
        guard !isRequestingHealthKit else { return }
        isRequestingHealthKit = true
        healthKitMessage = nil
        Task {
            defer { isRequestingHealthKit = false }
            do {
                try await healthKitManager.requestAuthorization()
                onFinish()
            } catch {
                healthKitMessage = error.localizedDescription
            }
        }
    }
}
