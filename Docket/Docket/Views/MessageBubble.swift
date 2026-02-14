import SwiftUI

/// A reusable message bubble component for conversation UI
struct MessageBubble: View {
    let message: ConversationMessage
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer(minLength: 48)
            }
            
            Text(message.content)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    message.role == "user" ? Color.blue : Color(.systemGray5)
                )
                .foregroundStyle(
                    message.role == "user" ? .white : .primary
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
            
            if message.role == "assistant" {
                Spacer(minLength: 48)
            }
        }
    }
}

// MARK: - Preview

#Preview("Message Bubbles") {
    VStack(spacing: 16) {
        MessageBubble(message: ConversationMessage(role: "user", content: "Buy groceries for dinner tonight"))
        MessageBubble(message: ConversationMessage(role: "assistant", content: "I've created a task to buy groceries for dinner tonight."))
        MessageBubble(message: ConversationMessage(role: "user", content: "What time?"))
        MessageBubble(message: ConversationMessage(role: "assistant", content: "You didn't specify a time. Would you like to add one?"))
    }
    .padding()
}
