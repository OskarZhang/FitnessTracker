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
    }
    var body: some Scene {
        WindowGroup {
            ExercisesListView()
        }
//        .modelContainer(for: Exercise.self)
        
    }
}
