import SwiftUI

// MARK: - Conversation View

/// Displays a conversation with message bubbles, scroll view,
/// and a bottom text input area with voice button
struct ConversationView: View {
    let messages: [ConversationMessage]
    let isProcessing: Bool
    var onSend: (String) -> Void
    var onVoiceTap: () -> Void
    
    @State private var inputText: String = ""
    @State private var isTextFieldFocused: Bool = false
    @FocusState private var textFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        
                        VStack(spacing: 12) {
                            // Display messages
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                MessageBubble(message: message)
                                    .id("msg-\(index)")
                            }
                            
                            // Processing indicator
                            if isProcessing {
                                AIThinkingIndicator(label: "Thinking...")
                                    .padding(.vertical, 4)
                                    .id("processing")
                            }
                            
                            // Bottom anchor for scrolling
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .frame(minHeight: UIScreen.main.bounds.height * 0.5, alignment: .bottom)
                }
                .onChange(of: messages.count) { _, _ in
                    DispatchQueue.main.async {
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: isProcessing) { _, _ in
                    DispatchQueue.main.async {
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            // Bottom input area
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 12) {
                    // Text input field
                    TextField("Type a message...", text: $inputText, axis: .vertical)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .lineLimit(1...5)
                        .focused($textFieldFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    // Send or Voice button
                    Button(action: {
                        if inputText.isEmpty {
                            onVoiceTap()
                        } else {
                            sendMessage()
                        }
                    }) {
                        ZStack {
                            // Voice icon (shown when empty)
                            Image(systemName: "waveform")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(inputText.isEmpty ? .blue : .clear)
                                .opacity(inputText.isEmpty ? 1 : 0)
                            
                            // Submit icon (shown when has text)
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(!inputText.isEmpty ? .blue : .clear)
                                .opacity(!inputText.isEmpty ? 1 : 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: inputText.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        textFieldFocused = false
        onSend(text)
    }
}

// MARK: - AI Thinking Indicator

struct AIThinkingIndicator: View {
    let label: String
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .opacity(isAnimating ? 1.0 : 0.25)
                        .scaleEffect(isAnimating ? 1.0 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.55)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.14),
                            value: isAnimating
                        )
                }
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}

// MARK: - Preview

#Preview("Conversation View") {
    struct PreviewWrapper: View {
        @State private var messages: [ConversationMessage] = [
            ConversationMessage(role: "user", content: "Buy groceries for dinner"),
            ConversationMessage(role: "assistant", content: "When do you need to get groceries?"),
            ConversationMessage(role: "user", content: "Tomorrow at 5pm")
        ]
        @State private var isProcessing = false
        
        var body: some View {
            ConversationView(
                messages: messages,
                isProcessing: isProcessing,
                onSend: { text in
                    messages.append(ConversationMessage(role: "user", content: text))
                    isProcessing = true
                    // Simulate response
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isProcessing = false
                        messages.append(ConversationMessage(role: "assistant", content: "Got it! I'll remind you to buy groceries tomorrow at 5pm."))
                    }
                },
                onVoiceTap: {}
            )
        }
    }
    
    return PreviewWrapper()
}
