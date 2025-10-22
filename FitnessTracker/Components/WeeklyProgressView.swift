//
//  WeeklyProgressView.swift
//  FitnessTracker
//
//  Created by Oskar Zhang
//

import SwiftUI
import SwiftUIIntrospect

struct WeeklyProgressView: View {
    // render 4 weeks of data
    @State private var weeks: [Date]
    @State private var height: CGFloat = 100
    
    init() {
        self.weeks = [-3, -2, -1, 0].compactMap { Self.weekStartDate(offset: $0) }
    }
    
    static private func weekStartDate(offset: Int) -> Date? {
        let today = Date().advanced(by: TimeInterval(offset * 60 * 60 * 24 * 7))
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return nil
        }
        return calendar.startOfDay(for: weekInterval.start)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(weeks, id: \.self) { date in
                            WeekCardView(weekStartDate: date)
                                .frame(width: geo.size.width)
                                .id(date)
                        }
                    }
                    .background(.clear)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    proxy.scrollTo(Self.weekStartDate(offset: 0))
                }
            }
        }
        .frame(height: height)
        .onPreferenceChange(CardHeightsKey.self) { height = $0 }
    }
}

#Preview {
    WeeklyProgressView()
}

struct WeekCardView: View {
    @Injected var exerciseService: ExerciseService

    private let calendar = Calendar.current
    @State var weekStartDate: Date
    
    init(weekStartDate: Date? = nil) {
        if let weekStartDate {
            self.weekStartDate = weekStartDate
        } else {
            let today = Date()
            let calendar = Calendar.current
            self.weekStartDate =  calendar.dateInterval(of: .weekOfYear, for: today)!.start
        }
    }
    
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
        .glassEffect(.clear.tint(.bratGreen.opacity(0.08)), in: .rect(
            corners: .concentric(minimum: 24),
            isUniform: true
        ))
        .padding(.horizontal, 16)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: CardHeightsKey.self,
                                value: geo.size.height)
            }
        )
    }

    private func getWeekdayName(for index: Int) -> String {
        guard let dayDate = calendar.date(byAdding: .day, value: index, to: weekStartDate) else { return "" }
        return weekdayFormatter.string(from: dayDate)
    }

    private func isCurrentDay(dayIndex: Int) -> Bool {
        let today = Date()
        guard let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: weekStartDate) else {
            return false
        }
        return calendar.isDate(today, inSameDayAs: targetDate)
    }

    private func hasExerciseForDay(dayIndex: Int) -> Bool {
        guard let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: weekStartDate) else {
            return false
        }

        return exerciseService.hasExercise(on: targetDate)
    }
}

private struct CardHeightsKey: PreferenceKey {
    static var defaultValue: CGFloat = 100.0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
