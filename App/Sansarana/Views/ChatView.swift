//
//  ChatView.swift
//  Sansarana
//
//  Created by Chulan Shammi on 2026-03-18.
//  Updated by Chulan Shammi on 2026-03-24 - Foundation Models integration
//

import SwiftUI

/// Main chat interface for conversing with the AI guide about statues
/// Uses Apple's Foundation Models for on-device, privacy-preserving chat
struct ChatView: View {
    
    // MARK: - Properties
    
    /// The chat view model managing the LLM session
    @ObservedObject var chatViewModel: ChatViewModel
    
    /// The currently detected statue (from AR system)
    let statue: Statue?
    
    /// For dismissing the view
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient for visual appeal
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Model availability check
                    if !chatViewModel.isModelAvailable {
                        unavailabilityBanner
                    }
                    
                    // No statue detected warning
                    if statue == nil {
                        noStatueBanner
                    }
                    
                    // Context usage warning (when approaching limit)
                    if chatViewModel.showContextWarning {
                        contextWarningBanner
                    }
                    
                    // Messages list
                    messagesScrollView
                    
                    Divider()
                    
                    // Suggestion chips (shown when there are no user messages yet)
                    if shouldShowSuggestions {
                        suggestionChips
                    }
                    
                    // Input field
                    inputField
                }
            }
            .navigationTitle("Chat with Sansarana")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                // Check model availability when view appears
                await chatViewModel.checkModelAvailability()
                
                // Configure session if a statue is detected
                if let statue = statue {
                    await chatViewModel.configureSession(for: statue)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Scrollable messages list with auto-scroll to bottom
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(chatViewModel.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    // Typing indicator
                    if chatViewModel.isGenerating {
                        typingIndicator
                            .transition(.opacity)
                    }
                }
                .padding()
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: chatViewModel.messages)
            }
            .onChange(of: chatViewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatViewModel.messages.last?.content) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatViewModel.isGenerating) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onTapGesture {
                // Dismiss keyboard when tapping the messages area
                hideKeyboard()
            }
        }
    }
    
    /// Banner shown when Foundation Models is unavailable
    private var unavailabilityBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            
            Text(chatViewModel.unavailabilityReason ?? "AI chat unavailable")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    /// Banner shown when no statue is detected yet
    private var noStatueBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.title3)
                .foregroundStyle(.blue)
            
            Text("Point your camera at a statue to start chatting!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    /// Banner shown when approaching context window limit
    private var contextWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Approaching context limit")
                    .font(.subheadline.bold())
                Text("I'll refresh my memory after the next message")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                chatViewModel.showContextWarning = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    /// Suggestion chips for first-time prompts
    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SuggestionPrompt.allCases, id: \.self) { suggestion in
                    SuggestionChip(
                        text: suggestion.displayText,
                        action: {
                            Task {
                                await chatViewModel.sendSuggestion(suggestion.displayText)
                            }
                        }
                    )
                    .disabled(chatViewModel.isGenerating || statue == nil || !chatViewModel.isModelAvailable)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    /// Typing indicator (animated dots)
    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                        .opacity(0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: chatViewModel.isGenerating
                        )
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            
            Spacer(minLength: 50)
        }
    }
    
    /// Input field with send button
    private var inputField: some View {
        VStack(spacing: 0) {
            // Context usage indicator (optional - shows progress bar)
            if chatViewModel.contextUsagePercentage > 0 {
                ProgressView(value: chatViewModel.contextUsagePercentage)
                    .tint(chatViewModel.contextUsagePercentage > 0.8 ? .orange : .blue)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .opacity(chatViewModel.contextUsagePercentage > 0.5 ? 1 : 0)
            }
            
            HStack(spacing: 12) {
                TextField("Ask about this statue...", text: $chatViewModel.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .disabled(chatViewModel.isGenerating || statue == nil || !chatViewModel.isModelAvailable)
                    .onSubmit {
                        Task {
                            await chatViewModel.sendMessageStreaming()
                        }
                    }
                
                Button(action: {
                    Task {
                        await chatViewModel.sendMessageStreaming()
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSendMessage ? .blue : .gray)
                }
                .disabled(!canSendMessage)
                .scaleEffect(chatViewModel.isGenerating ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: chatViewModel.isGenerating)
            }
            .padding()
            .background(.regularMaterial)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether suggestions should be shown
    private var shouldShowSuggestions: Bool {
        chatViewModel.messages.filter { $0.isUser }.isEmpty && !chatViewModel.isGenerating
    }
    
    /// Whether the send button should be enabled
    private var canSendMessage: Bool {
        !chatViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !chatViewModel.isGenerating
            && statue != nil
            && chatViewModel.isModelAvailable
    }
    
    // MARK: - Helper Methods
    
    /// Scrolls to the bottom of the messages list
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = chatViewModel.messages.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    /// Hides the keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - ChatBubble

/// A single message bubble in the chat
struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(12)
                    .background {
                        if message.isUser {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.blue)
                        } else {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .foregroundStyle(message.isUser ? .white : .primary)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if !message.isUser {
                Spacer(minLength: 50)
            }
        }
    }
}

// MARK: - SuggestionChip

/// A suggestion chip for pre-written prompts
struct SuggestionChip: View {
    let text: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Previews

#Preview("Chat View - With Statue") {
    ChatView(
        chatViewModel: ChatViewModel(),
        statue: .seatedBuddha
    )
}
#Preview("Chat View - No Statue") {
    ChatView(
        chatViewModel: ChatViewModel(),
        statue: nil
    )
}

