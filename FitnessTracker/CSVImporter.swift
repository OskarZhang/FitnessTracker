//
//  CSVImporter.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 9/25/24.
//

import Foundation

struct CSVImporter {
    // Define the expected CSV header
    private let expectedHeader = ["id", "name", "type", "weight", "repCount", "setCount", "durationMinutes", "date"]

    // Date formatter matching the exporter
    private let dateFormatter: DateFormatter

    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }

    /// Represents errors that can occur during CSV import
    enum CSVImportError: Error, LocalizedError {
        case invalidHeader(expected: [String], found: [String])
        case invalidRow(index: Int, reason: String)

        var errorDescription: String? {
            switch self {
            case .invalidHeader(let expected, let found):
                return "Invalid CSV header. Expected: \(expected), Found: \(found)"
            case .invalidRow(let index, let reason):
                return "Invalid data at row \(index): \(reason)"
            }
        }
    }

    /// Parses a CSV string into an array of Workout instances
    ///
    /// - Parameter csvString: The CSV data as a string
    /// - Throws: CSVImportError if parsing fails
    /// - Returns: Array of Workout instances
    func importCSV(csvString: String) throws -> [Exercise] {
        var exercises: [Exercise] = []

        // Split the CSV into lines
        let lines = csvString.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !lines.isEmpty else {
            return exercises // Empty CSV
        }

        // Parse header
        let headerLine = lines[0]
        let headers = parseCSVLine(headerLine)

        guard headers == expectedHeader else {
            throw CSVImportError.invalidHeader(expected: expectedHeader, found: headers)
        }

        // Parse each subsequent line
        for (index, line) in lines.enumerated() where index > 0 {
            let rowNumber = index + 1 // For user-friendly error messages
            let fields = parseCSVLine(line)

            guard fields.count == expectedHeader.count else {
                throw CSVImportError.invalidRow(index: rowNumber, reason: "Incorrect number of fields. Expected \(expectedHeader.count), found \(fields.count).")
            }

            // Extract fields
            let idString = fields[0]
            let name = fields[1]
            let typeString = fields[2]
            let weightString = fields[3]
            let repCountString = fields[4]
            let setCountString = fields[5]
            let durationMinutesString = fields[6]
            let dateString = fields[7]

            // Parse UUID
            guard let id = UUID(uuidString: idString) else {
                throw CSVImportError.invalidRow(index: rowNumber, reason: "Invalid UUID: \(idString)")
            }

            // Parse Date
            guard let date = dateFormatter.date(from: dateString) else {
                throw CSVImportError.invalidRow(index: rowNumber, reason: "Invalid date format: \(dateString)")
            }

            // Parse WorkoutType
            var sets: [StrengthSet]? = nil
            var durationSeconds: Int? = nil
            let type: ExerciseType
            switch typeString.lowercased() {
            case "strength":
                guard let weight = Int(weightString),
                      let repCount = Int(repCountString),
                      let setCount = Int(setCountString) else {
                    throw CSVImportError.invalidRow(index: rowNumber, reason: "Invalid strength parameters.")
                }
                type = .strength
                sets = (0..<setCount).map { _ in StrengthSet(weightInLbs: Double(weight), reps: repCount) }

            case "cardio":
                type = .cardio
                if let durationMinutes = Int(durationMinutesString) {
                    durationSeconds = durationMinutes * 60
                }

            default:
                throw CSVImportError.invalidRow(index: rowNumber, reason: "Unknown exercise type: \(typeString)")
            }

            // Create Workout instance
            exercises.append(Exercise(date: date, name: name, type: type, sets: sets, durationInSeconds: durationSeconds))
        }

        return exercises
    }

    /// Parses a single CSV line into an array of fields, handling escaped characters
    ///
    /// - Parameter line: The CSV line as a string
    /// - Returns: Array of field strings
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var iterator = line.makeIterator()

        while let char = iterator.next() {
            if char == "\"" {
                if insideQuotes {
                    // Peek next character
                    if let nextChar = iterator.next() {
                        if nextChar == "\"" {
                            // Escaped quote
                            currentField.append("\"")
                        } else {
                            // End of quoted field
                            insideQuotes = false
                            if nextChar == "," {
                                fields.append(currentField)
                                currentField = ""
                            } else {
                                currentField.append(nextChar)
                            }
                        }
                    } else {
                        // End of line
                        insideQuotes = false
                        fields.append(currentField)
                    }
                } else {
                    // Start of quoted field
                    insideQuotes = true
                }
            } else if char == "," && !insideQuotes {
                // Field separator
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }

        // Append the last field
        fields.append(currentField)

        return fields
    }
}
