//
//  ContentView.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 10/1/24.
//
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ExercisesListView()
    }
}
