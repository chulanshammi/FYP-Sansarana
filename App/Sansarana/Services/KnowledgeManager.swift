//
//  KnowledgeManager.swift
//  Sansarana
//
//  Created by Chulan Shammi on 2026-03-24.
//

import Foundation

/// Manages knowledge formatting and system instructions for Foundation Models chat
enum KnowledgeManager {
    
    // MARK: - System Instructions (With Tool Calling)
    
    /// Generates token-efficient system instructions for use WITH StatueKnowledgeTool
    /// This approach saves ~400-500 tokens by not loading full knowledge upfront
    /// - Parameter statue: The statue the user is viewing
    /// - Returns: Formatted system instruction string optimized for tool calling
    static func getSystemInstructionsWithTool(for statue: Statue) -> String {
        return """
        You are Sansarana, a friendly and knowledgeable guide for Gal Viharaya, a UNESCO World Heritage Site in Sri Lanka featuring magnificent 12th-century Buddhist rock sculptures.
        
        The user is currently viewing: \(statue.title) (\(statue.subtitle))
        
        IMPORTANT GUIDELINES:
        1. Use the 'getStatueInfo' tool to look up specific information when needed
        2. Keep responses to 2-3 sentences unless the user asks for more detail
        3. Be engaging and tell stories to bring history alive
        4. ONLY answer based on information from the tool or general knowledge of Gal Viharaya
        5. If asked something outside your knowledge, say so honestly
        6. Be conversational and warm, like a knowledgeable friend sharing their passion
        7. When appropriate, encourage the user to explore other statues or features
        
        RESPONSE STYLE:
        - Default: Brief and focused (2-3 sentences)
        - When asked to elaborate: Provide more depth
        - Use vivid language to help users visualize and connect emotionally
        - Relate Buddhist concepts to universal human experiences when appropriate
        
        Remember: You're not just sharing facts, you're helping people connect with 800 years of cultural heritage and spiritual wisdom.
        """
    }
    
    // MARK: - System Instructions (Without Tool Calling)
    
    /// Generates system instructions with full knowledge embedded (fallback approach)
    /// Uses ~700-800 tokens but doesn't require tool calling support
    /// - Parameter statue: The statue the user is viewing
    /// - Returns: Formatted system instruction string with embedded knowledge
    static func getSystemInstructionsWithFullKnowledge(for statue: Statue) -> String {
        let knowledge = StatueKnowledge.getKnowledge(for: statue)
        
        return """
        You are Sansarana, a friendly and knowledgeable guide for Gal Viharaya, a UNESCO World Heritage Site in Sri Lanka.
        
        The user is currently viewing: \(statue.title) (\(statue.subtitle))
        
        Here is your knowledge base:
        
        \(knowledge)
        
        IMPORTANT GUIDELINES:
        1. Keep responses to 2-3 sentences unless the user asks for more detail
        2. Be engaging and tell stories to bring history alive
        3. ONLY answer based on the provided knowledge
        4. If asked something outside this knowledge, say so honestly
        5. Be conversational and warm, like a knowledgeable friend
        6. Encourage the user to explore other statues or features
        
        RESPONSE STYLE:
        - Default: Brief and focused (2-3 sentences)
        - When asked to elaborate: Provide more depth
        - Use vivid language to help users visualize and connect emotionally
        - Relate Buddhist concepts to universal human experiences
        
        Remember: You're helping people connect with 800 years of cultural heritage and spiritual wisdom.
        """
    }
    
    // MARK: - Welcome Message
    
    /// Generates a personalized welcome message for a statue
    /// - Parameter statue: The statue the user is viewing
    /// - Returns: Friendly greeting message
    static func getWelcomeMessage(for statue: Statue) -> String {
        switch statue {
        case .seatedBuddha:
            return "Welcome! I'm Sansarana, your guide to the Seated Buddha. This magnificent sculpture depicts the Buddha in deep meditation—the moment of enlightenment. Ask me anything about this masterpiece!"
            
        case .standingBuddha:
            return "Welcome! I'm Sansarana, your guide to the Standing Buddha. This unique sculpture has puzzled scholars for centuries—is it Buddha or his devoted disciple Ananda? Ask me anything!"
            
        case .recliningBuddha:
            return "Welcome! I'm Sansarana, your guide to the Reclining Buddha. At 14 metres long, this depicts the Buddha's final moment of liberation—Parinirvana. Ask me anything about this profound sculpture!"
        }
    }
    
    // MARK: - Context Summary
    
    /// Generates a brief context summary when refreshing a session
    /// Used when context window is exhausted to preserve conversation history
    /// - Parameter messages: Previous chat messages
    /// - Returns: Concise summary of conversation
    static func generateContextSummary(from messages: [ChatMessage]) -> String {
        // Take only user messages from the last few exchanges
        let recentUserMessages = messages
            .filter { $0.isUser }
            .suffix(3)
            .map { $0.content }
        
        if recentUserMessages.isEmpty {
            return "This is a fresh conversation."
        }
        
        return """
        Previous conversation topics:
        \(recentUserMessages.joined(separator: " | "))
        """
    }
    
    // MARK: - Availability Messages
    
    /// Returns user-friendly message explaining why Foundation Models isn't available
    /// - Parameter reason: The unavailability reason
    /// - Returns: Formatted explanation for the user
    static func getUnavailabilityMessage(for reason: UnavailabilityReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "Apple Intelligence is not available on this device. You'll need an iPhone 15 Pro or later to use the AI chat feature."
            
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Please enable it in Settings > Apple Intelligence & Siri to use the AI chat feature."
            
        case .modelNotReady:
            return "The AI model is still downloading or preparing. Please try again in a few moments."
            
        case .other:
            return "The AI chat feature is temporarily unavailable. Please try again later."
        }
    }
}

// MARK: - Supporting Types

/// Represents reasons why Foundation Models might not be available
enum UnavailabilityReason {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case other
}
