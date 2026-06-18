import ActivityKit
import Foundation

struct WorkoutStopwatchAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stopwatchStartedAt: Date
        var completedSetCount: Int
    }

    var exerciseName: String
}
