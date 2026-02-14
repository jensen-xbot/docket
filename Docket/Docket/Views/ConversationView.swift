import SwiftUI

/// Chat UI for low-confidence interactions
/// Displays messages in a scrollable list with a bottom input bar
struct ConversationView: View {
    @Binding var messages: [ConversationMessage]
    @Binding var inputText: String
    var onSubmit: (String) -> Void
    var onVoiceTap: () -> Void
    
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages scroll view
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Spacer(minLength: 20)
                        
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            MessageBubble(message: message)
                                .id(index)
                        }
                        
                        // Bottom anchor for scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal)
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: inputText) { _, _ in
                    // Keep scrolled to bottom while typing
                    if !inputText.isEmpty {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                    scrollToBottom(proxy: proxy)
                }
            }
            
            // Bottom input bar
            inputBar
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            // Voice button
            Button(action: onVoiceTap) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Text input
            TextField("Type a message...", text: $inputText, axis: .vertical)
                .focused($isInputFocused)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Send button (only when has text)
            if !inputText.isEmpty {
                Button(action: submitText) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private func submitText() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        onSubmit(text)
        inputText = ""
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

// MARK: - Preview

#Preview("Conversation View") {
    struct PreviewWrapper: View {
        @State private var messages: [ConversationMessage] = [
            ConversationMessage(role: "user", content: "Call mom tomorrow"),
            ConversationMessage(role: "assistant", content: "What time would you like to call your mom?")
        ]
        @State private var inputText = ""
        
        var body: some View {
            ConversationView(
                messages: $messages,
                inputText: $inputText,
                onSubmit: { text in
                    messages.append(ConversationMessage(role: "user", content: text))
                },
                onVoiceTap: {
                    print("Voice tapped")
                }
            )
        }
    }
    
    return PreviewWrapper()
}

#Preview("Empty Conversation") {
    struct PreviewWrapper: View {
        @State private var messages: [ConversationMessage] = []
        @State private var inputText = ""
        
        var body: some View {
            ConversationView(
                messages: $messages,
                inputText: $inputText,
                onSubmit: { text in
                    messages.append(ConversationMessage(role: "user", content: text))
                },
                onVoiceTap: {
                    print("Voice tapped")
                }
            )
        }
    }
    
    return PreviewWrapper()
}
