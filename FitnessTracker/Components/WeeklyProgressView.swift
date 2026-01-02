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
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack {
                    ForEach(weeks, id: \.self) { date in
                        WeekCardView(weekStartDate: date)
                            .containerRelativeFrame(.horizontal)
                            .id(date)
                    }
                }
                .scrollTargetLayout()
                .background(.clear)
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .onAppear {
                proxy.scrollTo(Self.weekStartDate(offset: 0))
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
    @ObservedObject private var exerciseService: ExerciseService

    private let calendar = Calendar.current
    @State var weekStartDate: Date
    @State private var animateSymbols = false
    
    init(weekStartDate: Date? = nil, exerciseService: ExerciseService = Container.shared.resolve(ExerciseService.self)) {
        self._exerciseService = ObservedObject(wrappedValue: exerciseService)
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
                    let shouldFill = hasExerciseForDay(dayIndex: index)
                    let showsFill = animateSymbols && shouldFill
                    Image(systemName: showsFill ? "checkmark.rectangle.portrait.fill" : "checkmark.rectangle.portrait")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.bratGreen)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showsFill)
                }
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 32)
        .glassEffect(.clear.tint(.bratGreen.opacity(0.08)), in: .rect(
            corners: .concentric(minimum: 24),
            isUniform: true
        ))
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: CardHeightsKey.self,
                                value: geo.size.height)
            }
        )
        .onAppear {
            triggerIconAnimation()
        }
        .onReceive(exerciseService.$exercises) { _ in
            triggerIconAnimation()
        }
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

        let targetDayStart = calendar.startOfDay(for: targetDate)
        let exerciseDays = Set(exerciseService.exercises.map { calendar.startOfDay(for: $0.date) })
        return exerciseDays.contains(targetDayStart)
    }

    private func triggerIconAnimation() {
        animateSymbols = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            animateSymbols = true
        }
    }
}

private struct CardHeightsKey: PreferenceKey {
    static var defaultValue: CGFloat = 100.0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
