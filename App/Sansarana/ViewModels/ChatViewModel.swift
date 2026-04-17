//
//  ChatViewModel.swift
//  Sansarana
//
//  Created by Chulan Shammi on 2026-03-24.
//

import SwiftUI
import Combine
import FoundationModels

/// ViewModel managing the Foundation Models chat session and state
/// Uses Apple's on-device LLM for intelligent, privacy-preserving conversations
@MainActor
class ChatViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All messages in the current chat session
    @Published var messages: [ChatMessage] = []
    
    /// Text being typed in the input field
    @Published var inputText: String = ""
    
    /// Whether the model is currently generating a response
    @Published var isGenerating: Bool = false
    
    /// Whether Foundation Models is available on this device
    @Published var isModelAvailable: Bool = false
    
    /// User-friendly explanation if model is unavailable
    @Published var unavailabilityReason: String? = nil
    
    /// Whether to show the context warning (approaching limit)
    @Published var showContextWarning: Bool = false
    
    /// Estimated context usage as a percentage (0.0 to 1.0)
    @Published var contextUsagePercentage: Double = 0.0
    
    // MARK: - Private Properties
    
    /// The Foundation Models session
    private var session: LanguageModelSession?
    
    /// Reference to the system language model
    private let model = SystemLanguageModel.default
    
    /// The currently configured statue context
    private var currentStatue: Statue?
    
    /// Whether to use tool calling (more token-efficient) or full knowledge embedding
    private let useToolCalling = true
    
    /// Estimated tokens used in current session (rough approximation)
    /// Note: Foundation Models doesn't expose actual token count, so we estimate
    private var estimatedTokensUsed: Int = 0
    
    /// Maximum context window size
    private let maxContextWindow: Int = 4096
    
    // MARK: - Initialization
    
    init() {
        Task {
            await checkModelAvailability()
        }
    }
    
    // MARK: - Model Availability
    
    /// Checks if Foundation Models is available and updates state accordingly
    func checkModelAvailability() async {
        switch model.availability {
        case .available:
            isModelAvailable = true
            unavailabilityReason = nil
            
        case .unavailable(.deviceNotEligible):
            isModelAvailable = false
            unavailabilityReason = KnowledgeManager.getUnavailabilityMessage(for: .deviceNotEligible)
            
        case .unavailable(.appleIntelligenceNotEnabled):
            isModelAvailable = false
            unavailabilityReason = KnowledgeManager.getUnavailabilityMessage(for: .appleIntelligenceNotEnabled)
            
        case .unavailable(.modelNotReady):
            isModelAvailable = false
            unavailabilityReason = KnowledgeManager.getUnavailabilityMessage(for: .modelNotReady)
            
        case .unavailable:
            isModelAvailable = false
            unavailabilityReason = KnowledgeManager.getUnavailabilityMessage(for: .other)
        }
    }
    
    // MARK: - Session Configuration
    
    /// Configures the chat session for a specific statue
    /// Only reconfigures if the statue has changed to avoid unnecessary resets
    /// - Parameter statue: The statue to configure context for
    func configureSession(for statue: Statue) async {
        // Only reconfigure if statue changed or no session exists
        guard currentStatue != statue || session == nil else {
            return
        }
        
        currentStatue = statue
        
        // Reset session state
        messages.removeAll()
        estimatedTokensUsed = 0
        updateContextUsage()
        
        // Create session with appropriate configuration
        if useToolCalling {
            // Token-efficient approach: Use tool calling
            let instructions = KnowledgeManager.getSystemInstructionsWithTool(for: statue)
            let tool = StatueKnowledgeTool(statue: statue)
            session = LanguageModelSession(tools: [tool], instructions: instructions)
            
            // Estimate system instruction tokens (~200-300)
            estimatedTokensUsed += estimateTokens(instructions)
            
        } else {
            // Fallback approach: Embed full knowledge
            let instructions = KnowledgeManager.getSystemInstructionsWithFullKnowledge(for: statue)
            session = LanguageModelSession(instructions: instructions)
            
            // Estimate system instruction tokens (~700-800)
            estimatedTokensUsed += estimateTokens(instructions)
        }
        
        updateContextUsage()
        
        // Add welcome message
        let welcomeMessage = ChatMessage(
            content: KnowledgeManager.getWelcomeMessage(for: statue),
            isUser: false
        )
        messages.append(welcomeMessage)
    }
    
    // MARK: - Message Sending (Streaming)
    
    /// Sends a user message and gets a response from the model
    /// Uses respond() which reliably handles tool calling
    func sendMessageStreaming() async {
        // Guard checks
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        guard !isGenerating else {
            return
        }
        
        guard let session = session else {
            print("[Chat] No session available")
            return
        }
        
        // Check if we're approaching context limit
        if estimatedTokensUsed > maxContextWindow * 80 / 100 {
            showContextWarning = true
        }
        
        // Prepare user message
        let userMessageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = ChatMessage(content: userMessageText, isUser: true)
        
        // Add user message to chat
        messages.append(userMessage)
        estimatedTokensUsed += estimateTokens(userMessageText)
        updateContextUsage()
        
        // Clear input
        inputText = ""
        
        // Set generating state
        isGenerating = true
        
        do {
            // Use respond() which properly handles tool calling round-trips
            let response = try await session.respond(to: userMessageText)
            
            // Add assistant message with the complete response
            let assistantMessage = ChatMessage(content: response.content, isUser: false)
            messages.append(assistantMessage)
            
            // Estimate tokens in response
            estimatedTokensUsed += estimateTokens(response.content)
            updateContextUsage()
            
        } catch let error as LanguageModelSession.GenerationError {
            // Handle specific generation errors
            await handleGenerationError(error, userMessage: userMessageText)
            
        } catch is CancellationError {
            // User cancelled - no action needed
            
        } catch {
            // Handle generic errors
            await handleGenericError(error)
        }
        
        isGenerating = false
    }
    
    // MARK: - Message Sending (Non-Streaming)
    
    /// Sends a user message and waits for complete response
    /// Use this if you prefer to show the full response at once
    func sendMessage() async {
        // Guard checks
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        guard !isGenerating else {
            return
        }
        
        guard let session = session else {
            return
        }
        
        // Check context limit
        if estimatedTokensUsed > maxContextWindow * 80 / 100 {
            showContextWarning = true
        }
        
        // Prepare user message
        let userMessageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = ChatMessage(content: userMessageText, isUser: true)
        
        // Add user message
        messages.append(userMessage)
        estimatedTokensUsed += estimateTokens(userMessageText)
        updateContextUsage()
        
        // Clear input
        inputText = ""
        
        // Set generating state
        isGenerating = true
        
        do {
            // Generate response
            let response = try await session.respond(to: userMessageText)
            
            // Add assistant message
            let assistantMessage = ChatMessage(content: response.content, isUser: false)
            messages.append(assistantMessage)
            
            estimatedTokensUsed += estimateTokens(response.content)
            updateContextUsage()
            
        } catch let error as LanguageModelSession.GenerationError {
            await handleGenerationError(error, userMessage: userMessageText)
            
        } catch {
            await handleGenericError(error)
        }
        
        isGenerating = false
    }
    
    // MARK: - Context Overflow Handling
    
    /// Handles context window overflow by creating a new session with conversation summary
    private func handleContextOverflow() async {
        guard let statue = currentStatue else { return }
        
        // Generate summary of conversation
        let summary = KnowledgeManager.generateContextSummary(from: messages)
        
        // Create new session with summary included in instructions
        let baseInstructions = useToolCalling
            ? KnowledgeManager.getSystemInstructionsWithTool(for: statue)
            : KnowledgeManager.getSystemInstructionsWithFullKnowledge(for: statue)
        
        let instructionsWithSummary = """
        \(baseInstructions)
        
        PREVIOUS CONVERSATION CONTEXT:
        \(summary)
        """
        
        if useToolCalling {
            let tool = StatueKnowledgeTool(statue: statue)
            session = LanguageModelSession(tools: [tool], instructions: instructionsWithSummary)
        } else {
            session = LanguageModelSession(instructions: instructionsWithSummary)
        }
        
        // Reset token counter with new instructions
        estimatedTokensUsed = estimateTokens(instructionsWithSummary)
        updateContextUsage()
        
        // Add system message to inform user
        let systemMessage = ChatMessage(
            content: "I've refreshed my memory to continue our conversation. Feel free to keep asking questions!",
            isUser: false
        )
        messages.append(systemMessage)
        
        showContextWarning = false
    }
    
    // MARK: - Error Handling
    
    /// Handles Foundation Models generation errors
    private func handleGenerationError(_ error: LanguageModelSession.GenerationError, userMessage: String) async {
        switch error {
        case .exceededContextWindowSize:
            // Context window exhausted - refresh session
            if let lastMessage = messages.last, !lastMessage.isUser {
                messages.removeLast() // Remove empty assistant message
            }
            
            await handleContextOverflow()
            
            // Retry the message
            inputText = userMessage
            await sendMessageStreaming()
            
        default:
            // Other errors (guardrail, cancelled, etc.)
            if let lastMessage = messages.last, !lastMessage.isUser {
                messages.removeLast()
            }
            
            let errorMessage = ChatMessage(
                content: "I encountered an error generating a response. Please try again.",
                isUser: false
            )
            messages.append(errorMessage)
        }
    }
    
    /// Handles generic errors
    private func handleGenericError(_ error: Error) async {
        // Remove empty assistant message if present
        if let lastMessage = messages.last, !lastMessage.isUser, lastMessage.content.isEmpty {
            messages.removeLast()
        }
        
        let errorMessage = ChatMessage(
            content: "I encountered an unexpected error. Please try again.",
            isUser: false
        )
        messages.append(errorMessage)
        
        print("Chat error: \(error.localizedDescription)")
    }
    
    // MARK: - Chat Management
    
    /// Resets the chat session completely
    func resetChat() {
        messages.removeAll()
        session = nil
        currentStatue = nil
        estimatedTokensUsed = 0
        contextUsagePercentage = 0.0
        showContextWarning = false
        inputText = ""
    }
    
    /// Sends a pre-written prompt (for suggestion chips)
    /// - Parameter prompt: The prompt text to send
    func sendSuggestion(_ prompt: String) async {
        inputText = prompt
        await sendMessageStreaming()
    }
    
    // MARK: - Context Usage Estimation
    
    /// Estimates the number of tokens in a text string
    /// Rough approximation: 1 token ≈ 4 characters for English
    /// This is conservative; actual tokenization may vary
    private func estimateTokens(_ text: String) -> Int {
        return text.count / 4 + 1
    }
    
    /// Updates the context usage percentage based on estimated tokens
    private func updateContextUsage() {
        contextUsagePercentage = Double(estimatedTokensUsed) / Double(maxContextWindow)
    }
}



