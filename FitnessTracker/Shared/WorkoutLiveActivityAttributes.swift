import ActivityKit
import Foundation

struct WorkoutLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var displayExerciseName: String
        var timerEndDate: Date?
        var nextLikelyExerciseName: String?
        var deepLinkExerciseName: String
        var lastInteractionDate: Date
    }

    var workoutSessionID: String
}
