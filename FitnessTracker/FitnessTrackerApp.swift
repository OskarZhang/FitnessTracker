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
    init() {
        Container.shared.registerSingleton(ExerciseService.self) { ExerciseService() }
        
        // Large Navigation Title global override
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.bratGreen]
    }
    var body: some Scene {
        WindowGroup {
            ExercisesListView()

        }
    }
}
