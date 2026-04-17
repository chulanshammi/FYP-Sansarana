//
//  StatueKnowledgeTool.swift
//  Sansarana
//
//  Created by Chulan Shammi on 2026-03-24.
//

import Foundation
import FoundationModels

/// Tool for Foundation Models to look up specific statue information on-demand
/// This approach is MORE token-efficient than loading all knowledge upfront
/// because the model only fetches what it needs per question (~100-150 tokens at a time)
struct StatueKnowledgeTool: Tool {
    
    // MARK: - Tool Configuration
    
    var name: String {
        "getStatueInfo"
    }
    
    var description: String {
        "Look up specific information about the statue the user is viewing. Use this tool when you need detailed information to answer the user's question."
    }
    
    // MARK: - Arguments
    
    @Generable
    struct Arguments {
        @Guide(description: "The category of information to look up")
        var category: ToolInfoCategory
    }
    
    @Generable
    enum ToolInfoCategory: String, CaseIterable {
        case generalHistory = "General history of Gal Viharaya"
        case physicalDescription = "Physical description and appearance"
        case buddhistSignificance = "Buddhist meaning and spiritual significance"
        case artisticDetails = "Artistic style and carving techniques"
        case dimensions = "Size and measurements"
        case interestingFacts = "Interesting facts and details"
    }
    
    // MARK: - Properties
    
    /// The statue this tool provides information about
    let statue: Statue
    
    // MARK: - Tool Execution
    
    @MainActor
    func call(arguments: Arguments) async throws -> String {
        // Convert ToolInfoCategory to InfoCategory
        let infoCategory = convertCategory(arguments.category)
        
        // Fetch only the requested section of knowledge
        let knowledge = StatueKnowledge.getSection(for: statue, category: infoCategory)
        
        return knowledge
    }
    
    // MARK: - Helper Methods
    
    /// Converts the tool's category enum to the StatueKnowledge InfoCategory
    private func convertCategory(_ toolCategory: ToolInfoCategory) -> InfoCategory {
        switch toolCategory {
        case .generalHistory:
            return .generalHistory
        case .physicalDescription:
            return .physicalDescription
        case .buddhistSignificance:
            return .buddhistSignificance
        case .artisticDetails:
            return .artisticDetails
        case .dimensions:
            return .dimensions
        case .interestingFacts:
            return .interestingFacts
        }
    }
}


