//
//  LLMService.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 10/16/25.
//
import FoundationModels

protocol Recommender {
    var systemPrompt: String { get }
    var tools: [any Tool] { get }
    associatedtype GeneratingType: Generable
}

extension Recommender {
    func respond() async throws -> LanguageModelSession.Response<GeneratingType> {
        let session = LanguageModelSession(model: .default, tools: tools, instructions: systemPrompt)
        return try await session.respond(to: "", generating: GeneratingType.self)
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

struct SuggestFirstSet: Recommender {
    
    typealias GeneratingType = SetRecommendation
    let tools: [any Tool] = []
    
    let systemPrompt: String
    init(userWeight: Int, userHeight: String, workoutName: String) {
        self.systemPrompt = """
            The user is weighed \(userWeight) lbs and \(userHeight) tall. The user is experienced at weight lifting.
            Suggest a full set for doing \(workoutName)
            """
    }
}
