import SwiftUI

// MARK: - Message Bubble

/// A message bubble view for conversation display
/// User bubbles are blue and right-aligned
/// Assistant bubbles are gray and left-aligned
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
    VStack(spacing: 12) {
        MessageBubble(message: ConversationMessage(role: "user", content: "Buy groceries for dinner"))
        MessageBubble(message: ConversationMessage(role: "assistant", content: "When do you need to get groceries?"))
        MessageBubble(message: ConversationMessage(role: "user", content: "Tomorrow at 5pm"))
    }
    .padding()
}
