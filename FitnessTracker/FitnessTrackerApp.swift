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

    init() {
        Container.shared.registerSingleton(ExerciseService.self) { ExerciseService() }
        Container.shared.registerSingleton(HealthKitManager.self) { HealthKitManager() }
        BackgroundSyncManager.shared.register()
        
        // Large Navigation Title global override
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.bratGreen]
        UINavigationBar.appearance().tintColor = UIColor.bratGreen
    }
    var body: some Scene {
        WindowGroup {
            ExercisesListView()

        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundSyncManager.shared.schedule()
            }
        }
    }
}
