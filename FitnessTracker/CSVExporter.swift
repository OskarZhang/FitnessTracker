//
//  CSVExporter.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 9/25/24.
//

import Foundation

struct CSVExporter {
    // Define the CSV header
    private let header = "id,name,type,weight,repCount,setCount,durationMinutes,date\n"

    // Date formatter for consistent date representation
    private let dateFormatter: DateFormatter

    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }

    /// Escapes special characters in CSV fields
    private func escapeCSVField(_ field: String) -> String {
        var escaped = field
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            escaped = "\"\(escaped)\""
        }
        return escaped
    }

    /// Converts an array of Workout instances to a CSV string
    func export(exercises: [Exercise]) -> String {
        // todo: make export work again
//        var csvString = header
//
//        for exercise in exercises {
//            let id = exercise.id.uuidString
//            let name = escapeCSVField(exercise.name)
//            var type = ""
//            var weight = ""
//            var repCount = ""
//            var setCount = ""
//            var durationMinutes = ""
//
//            switch exercise.v1Type {
//            case .strength(let weightNum, let reps, let sets):
//                type = "strength"
//                weight = "\(weightNum)"
//                repCount = "\(reps)"
//                setCount = "\(sets)"
//            case .cardio(let duration):
//                type = "cardio"
//                durationMinutes = "\(duration)"
//            }
//
//            let date = dateFormatter.string(from: exercise.date)
//
//            // Construct the CSV row
//            let row = "\(id),\(name),\(type),\(weight),\(repCount),\(setCount),\(durationMinutes),\(date)\n"
//            csvString += row
//        }
//
//        return csvString
        return ""
    }
}
