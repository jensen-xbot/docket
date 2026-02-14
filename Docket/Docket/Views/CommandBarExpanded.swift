import SwiftUI

// MARK: - Command Bar Expanded

/// Sheet content for the Task Assistant conversation.
/// Presented as a native `.sheet` so it fills the screen properly.
struct CommandBarExpanded: View {
    @Binding var isExpanded: Bool
    @Binding var messages: [ConversationMessage]
    var pendingTasks: [ParsedTask]
    @Binding var inputText: String
    var isProcessing: Bool = false
    var tasksSaved: Bool = false
    var onSend: (String) -> Void
    var onVoiceTap: () -> Void
    var onSaveTasks: ([ParsedTask]) -> Void
    var onCancelTasks: () -> Void
    var onDeleteTasks: () -> Void = {}
    var onUpdateTask: (ParsedTask) -> Void = { _ in }
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Ask Docket")
                    .font(.headline)
                
                Spacer()
                
                Button(action: collapse) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            Divider()
            
            // Conversation view
            ConversationView(
                messages: messages,
                pendingTasks: pendingTasks,
                isProcessing: isProcessing,
                tasksSaved: tasksSaved,
                onSend: { text in
                    handleSend(text)
                },
                onVoiceTap: onVoiceTap,
                onSaveTasks: onSaveTasks,
                onCancelTasks: onCancelTasks,
                onDeleteTasks: onDeleteTasks,
                onUpdateTask: onUpdateTask
            )
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    private func handleSend(_ text: String) {
        messages.append(ConversationMessage(role: "user", content: text))
        inputText = ""
        onSend(text)
    }
    
    private func collapse() {
        isExpanded = false
        onClose()
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview("Command Bar Expanded") {
    struct PreviewWrapper: View {
        @State private var isExpanded = true
        @State private var messages: [ConversationMessage] = [
            ConversationMessage(role: "user", content: "Meet with David"),
            ConversationMessage(role: "assistant", content: "When would you like to meet with David?")
        ]
        @State private var inputText = ""
        
        var body: some View {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
                .sheet(isPresented: $isExpanded) {
                    CommandBarExpanded(
                        isExpanded: $isExpanded,
                        messages: $messages,
                        pendingTasks: [],
                        inputText: $inputText,
                        onSend: { text in
                            messages.append(ConversationMessage(role: "user", content: text))
                        },
                        onVoiceTap: {},
                        onSaveTasks: { _ in },
                        onCancelTasks: {},
                        onClose: {}
                    )
                }
        }
    }
    
    return PreviewWrapper()
}
