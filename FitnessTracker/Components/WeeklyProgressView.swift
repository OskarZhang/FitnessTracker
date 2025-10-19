//
//  WeeklyProgressView.swift
//  FitnessTracker
//
//  Created by Oskar Zhang
//

import SwiftUI

struct WeeklyProgressView: View {
    @Injected var exerciseService: ExerciseService

    private let calendar = Calendar.current
    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 8) {
            // First row: Weekday names
            HStack(spacing: 0) {
                ForEach(0..<7) { index in
                    Text(getWeekdayName(for: index))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isCurrentDay(dayIndex: index) ? .bratGreen : .primary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Second row: Checkmarks
            HStack(spacing: 0) {
                ForEach(0..<7) { index in
                    Image(systemName: hasExerciseForDay(dayIndex: index) ? "checkmark.rectangle.portrait.fill" : "checkmark.rectangle.portrait")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.bratGreen)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 32)
        .glassEffect(.regular.tint(.bratGreen.opacity(0.08)), in: .rect(
            corners: .concentric(minimum: 24),
            isUniform: true
        ))
        .padding(.horizontal, 16)
    }

    private func getWeekdayName(for index: Int) -> String {
        guard let weekStartDate = getWeekStartDate() else { return "" }
        guard let dayDate = calendar.date(byAdding: .day, value: index, to: weekStartDate) else { return "" }
        return weekdayFormatter.string(from: dayDate)
    }

    private func getWeekStartDate() -> Date? {
        let today = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return nil
        }
        return weekInterval.start
    }

    private func isCurrentDay(dayIndex: Int) -> Bool {
        let today = Date()
        guard let weekStartDate = getWeekStartDate(),
              let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: weekStartDate) else {
            return false
        }
        return calendar.isDate(today, inSameDayAs: targetDate)
    }

    private func hasExerciseForDay(dayIndex: Int) -> Bool {
        guard let weekStartDate = getWeekStartDate(),
              let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: weekStartDate) else {
            return false
        }

        return exerciseService.hasExercise(on: targetDate)
    }
}
