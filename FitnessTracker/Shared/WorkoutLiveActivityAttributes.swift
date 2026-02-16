import ActivityKit
import Foundation

enum WorkoutLiveSessionState: String, Codable, Hashable {
    case activeLogging
    case needsPostWorkoutPrompt
}

struct WorkoutLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var sessionState: WorkoutLiveSessionState
        var displayExerciseName: String
        var timerEndDate: Date?
        var suggestedExerciseName: String?
        var deepLinkExerciseName: String
        var sessionStartDate: Date
        var lastInteractionDate: Date
    }

    var workoutSessionID: String
}
