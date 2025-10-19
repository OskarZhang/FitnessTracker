//
//  LLMService.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 10/16/25.
//
import FoundationModels
import Foundation

protocol Recommender {
    var systemPrompt: String { get }
    var tools: [any Tool] { get }
    var userMessage: String { get }
    associatedtype GeneratingType: Generable
}

extension Recommender {
    func respond() async throws -> LanguageModelSession.Response<GeneratingType> {
        let session = LanguageModelSession(model: .default, tools: tools, instructions: systemPrompt)
        return try await session.respond(to: userMessage, generating: GeneratingType.self)
    }
}


@Generable
struct SetRecommendation {
    @Guide(description: "warmup weight in pounds")
    let warmupWeight: Int
    
    @Guide(description: "warmup reps count")
    let warmupReps: Int
    
    
    @Guide(description: "weight in pounds")
    let terminalWeight: Int
    
    @Guide(description: "reps count")
    let terminalReps: Int
    
    @Guide(description: "number of sets user should do")
    let setCount: Int
}

struct SuggestFullSetForExercise: Recommender {
    
    typealias GeneratingType = SetRecommendation
    let tools: [any Tool] = []
    
    let systemPrompt: String
    let userMessage: String
    init(userWeight: Int, userHeight: String, workoutName: String) {
        self.systemPrompt = """
            You are an expert fitness trainer.
            The user is weighed \(userWeight) lbs and \(userHeight) tall. The user is experienced at weight lifting.
            """
        self.userMessage = "Suggest a full set for doing \(workoutName)"
    }
}


@Generable
struct ExerciseSet {
    @Guide(description: "list of exercise")
    let exercises: [String]
}

struct SuggestTodaysWorkout: Recommender {
    
    typealias GeneratingType = ExerciseSet
    let tools: [any Tool] = []
    
    let systemPrompt: String
    let userMessage: String
    
    init(previousExercise: [(date: Date, exercises: [Exercise])]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        let prevExerciseStr = previousExercise.map {
            dateFormatter.string(from: $0.0) + ": " + $0.1.map { $0.name }.joined(separator: ", ")
        }
            .joined(separator: "\n")
            
        self.systemPrompt = """
            You are an expert trainer who is experienced in giving workout suggestions.
            The user is weighed 155 lbs and 5 feet 7 tall. The user is experienced at weight lifting.
            Today is \(dateFormatter.string(from: Date()))
            You MUST suggest exercises based on user's previous history, taking into account the grouping of their exercises for a given day.
            Make sure the exercises are working the same muscle group. 
            You MUST try to suggest muscle groups that the user has not worked on recently.
            User's previous exercise sessions: 
            \(prevExerciseStr)
            """
        
        self.userMessage = """
            Suggest a list of exercises to work on today. 
            """
    }
}


@Generable
struct ExerciseCategory {
    @Guide(description: "list of exercise categories")
    let categories: [String]
}

struct ExerciseCategorizer: Recommender {
    
    typealias GeneratingType = ExerciseCategory
    let tools: [any Tool] = []
    
    let systemPrompt: String
    let userMessage: String
    
    init(exerciseName: String) {
        self.systemPrompt = """
            You are a fitness expert who is responsible for categorizing an exercise; 
            You MUST choose from the following exercise categories: abs, chest, shoulders, arms, legs, glutes, back, fullBody, cardio
            """
        
        self.userMessage = """
            Categorize \(exerciseName).
            """
    }
}
