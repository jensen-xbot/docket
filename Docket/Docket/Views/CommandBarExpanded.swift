import SwiftUI

// MARK: - Command Bar Expanded

/// A full-screen overlay that expands from the bottom when low confidence
/// or when user taps to expand. Contains ConversationView with background dimming.
struct CommandBarExpanded: View {
    @Binding var isExpanded: Bool
    @Binding var messages: [ConversationMessage]
    @Binding var inputText: String
    var isProcessing: Bool = false
    var onSend: (String) -> Void
    var onVoiceTap: () -> Void
    var onClose: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background dimming
            Color.black
                .opacity(isExpanded ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    collapse()
                }
            
            // Content container
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // Drag handle
                    VStack(spacing: 8) {
                        Capsule()
                            .fill(Color(.systemGray3))
                            .frame(width: 36, height: 5)
                        
                        HStack {
                            Text("Task Assistant")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: collapse) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(Color(.systemBackground))
                    
                    // Conversation view
                    ConversationView(
                        messages: messages,
                        isProcessing: isProcessing,
                        onSend: { text in
                            handleSend(text)
                        },
                        onVoiceTap: onVoiceTap
                    )
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
                }
                .background(Color(.systemBackground))
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -5)
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 100 || value.velocity.height > 500 {
                                collapse()
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: dragOffset)
    }
    
    private func handleSend(_ text: String) {
        // Add user message
        messages.append(ConversationMessage(role: "user", content: text))
        inputText = ""
        
        // Call the onSend handler
        onSend(text)
    }
    
    private func collapse() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isExpanded = false
            dragOffset = 0
        }
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
            ConversationMessage(role: "assistant", content: "What would you like to add?")
        ]
        @State private var inputText = ""
        
        var body: some View {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                Text("Background Content")
                
                CommandBarExpanded(
                    isExpanded: $isExpanded,
                    messages: $messages,
                    inputText: $inputText,
                    onSend: { text in
                        messages.append(ConversationMessage(role: "user", content: text))
                    },
                    onVoiceTap: {},
                    onClose: {}
                )
            }
        }
    }
    
    return PreviewWrapper()
}
