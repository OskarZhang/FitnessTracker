//
//  ContentView.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 10/1/24.
//
import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var defaultTabIndex = 1

    var body: some View {
        TabView(selection: $defaultTabIndex) {
            ExercisesListView(exerciseService: ExerciseService(modelContext: modelContext))
                .tabItem {
                    Image(systemName: "dumbbell")
                    Text("Exercises")
                }
                .tag(1)
            TrendsView()
                .tabItem {
                    Image(systemName: "chart.xyaxis.line")
                    Text("Trends")
            }
                .tag(2)
        }
        .tint(colorScheme == .dark ? Color.white : Color(UIColor.black))
    }
}
