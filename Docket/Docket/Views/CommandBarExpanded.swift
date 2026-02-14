import SwiftUI

/// Full-screen expansion container for the command bar
/// Shows ConversationView when expanded with background dimming of task list
struct CommandBarExpanded: View {
    @Binding var isExpanded: Bool
    @Binding var messages: [ConversationMessage]
    @Binding var inputText: String
    var onSubmit: (String) -> Void
    var onDismiss: () -> Void
    var onVoiceTap: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let dragThreshold: CGFloat = 100
    private let springAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.85)
    
    var body: some View {
        ZStack {
            // Background dimming
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Content container
            VStack(spacing: 0) {
                // Drag handle indicator
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                
                // Conversation view
                ConversationView(
                    messages: $messages,
                    inputText: $inputText,
                    onSubmit: { text in
                        onSubmit(text)
                    },
                    onVoiceTap: onVoiceTap
                )
            }
            .background(
                Color(.systemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .ignoresSafeArea(edges: .bottom)
            )
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        // Only allow dragging down
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        let velocity = value.predictedEndLocation.y - value.location.y
                        
                        // Dismiss if dragged past threshold or with significant velocity
                        if dragOffset > dragThreshold || velocity > 500 {
                            dismiss()
                        } else {
                            // Snap back
                            withAnimation(springAnimation) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .transition(.move(edge: .bottom))
    }
    
    private var backgroundOpacity: Double {
        let maxOpacity: Double = 0.5
        let progress = 1.0 - Double(dragOffset / UIScreen.main.bounds.height)
        return max(0, min(maxOpacity, maxOpacity * progress))
    }
    
    private func dismiss() {
        withAnimation(springAnimation) {
            dragOffset = UIScreen.main.bounds.height
        }
        
        // Delay actual dismissal to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
            isExpanded = false
        }
    }
}

// MARK: - Preview

#Preview("Command Bar Expanded") {
    struct PreviewWrapper: View {
        @State private var isExpanded = true
        @State private var messages: [ConversationMessage] = [
            ConversationMessage(role: "user", content: "Call mom tomorrow"),
            ConversationMessage(role: "assistant", content: "What time would you like to call your mom?")
        ]
        @State private var inputText = ""
        
        var body: some View {
            ZStack {
                // Simulated task list background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                Text("Task List Background")
                    .foregroundStyle(.secondary)
                
                if isExpanded {
                    CommandBarExpanded(
                        isExpanded: $isExpanded,
                        messages: $messages,
                        inputText: $inputText,
                        onSubmit: { text in
                            messages.append(ConversationMessage(role: "user", content: text))
                        },
                        onDismiss: {
                            print("Dismissed")
                        },
                        onVoiceTap: {
                            print("Voice tapped")
                        }
                    )
                }
            }
        }
    }
    
    return PreviewWrapper()
}
