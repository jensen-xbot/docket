import SwiftUI

// MARK: - Growing Text Field

struct GrowingTextField: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String
    
    @State private var textHeight: CGFloat = 22
    private let minHeight: CGFloat = 22
    private let maxHeight: CGFloat = 120
    
    var body: some View {
        GeometryReader { geometry in
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .font(.body)
                .frame(height: min(max(textHeight, minHeight), maxHeight))
                .onChange(of: text) { oldValue, newValue in
                    calculateHeight(for: geometry.size.width)
                }
                .onAppear {
                    calculateHeight(for: geometry.size.width)
                }
        }
        .frame(height: min(max(textHeight, minHeight), maxHeight))
    }
    
    private func calculateHeight(for width: CGFloat) {
        let size = CGSize(width: width, height: .infinity)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body)
        ]
        let boundingRect = (text as NSString).boundingRect(
            with: size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        textHeight = max(minHeight, ceil(boundingRect.height) + 8)
    }
}

// MARK: - Plus Button

struct PlusButton: View {
    var onLongPress: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Image(systemName: "plus.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(.blue)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .onLongPressGesture(minimumDuration: 0.3) {
                onLongPress()
            } onPressingChanged: { pressing in
                isPressed = pressing
            }
    }
}

// MARK: - Voice Button

struct VoiceButton: View {
    var hasText: Bool
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Waveform icon (shown when empty)
                Image(systemName: "waveform")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(hasText ? .clear : .blue)
                    .opacity(hasText ? 0 : 1)
                
                // Submit arrow (shown when has text)
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(hasText ? .blue : .clear)
                    .opacity(hasText ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: hasText)
    }
}

// MARK: - Command Bar Collapsed

struct CommandBarCollapsed: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String = "What do you need to get done?"
    var onVoiceTap: () -> Void
    var onSubmit: () -> Void
    var onPlusLongPress: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Plus button with long-press
            PlusButton(onLongPress: onPlusLongPress)
            
            // Text input field
            GrowingTextField(
                text: $text,
                isFocused: $isFocused,
                placeholder: placeholder
            )
            
            // Voice/Submit button
            VoiceButton(hasText: !text.isEmpty, onTap: {
                if text.isEmpty {
                    onVoiceTap()
                } else {
                    onSubmit()
                }
            })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Command Bar View (Container)

struct CommandBarView: View {
    @Binding var text: String
    var onSubmit: (String, @escaping (ParseResponse) -> Void) -> Void
    var onVoiceTap: () -> Void
    var placeholder: String = "What do you need to get done?"
    
    // MARK: - State
    
    @State private var isExpanded: Bool = false
    @State private var messages: [ConversationMessage] = []
    @State private var isFocused: Bool = false
    @State private var showingContextMenu: Bool = false
    @State private var showingQuickAcceptToast: Bool = false
    @State private var showingInlineConfirmation: Bool = false
    @State private var lastParsedTasks: [ParsedTask] = []
    @State private var lastResponse: ParseResponse?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var syncEngine
    
    var body: some View {
        ZStack {
            // Main command bar
            CommandBarCollapsed(
                text: $text,
                isFocused: $isFocused,
                placeholder: placeholder,
                onVoiceTap: onVoiceTap,
                onSubmit: handleSubmit,
                onPlusLongPress: {
                    showingContextMenu = true
                }
            )
            .frame(minHeight: 56)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Color(.systemBackground)
                    .ignoresSafeArea(edges: .bottom)
            )
            
            // Context menu overlay
            if showingContextMenu {
                contextMenuOverlay
            }
            
            // Quick Accept Toast (high confidence)
            if showingQuickAcceptToast, let task = lastParsedTasks.first {
                VStack {
                    Spacer()
                    QuickAcceptToast(
                        taskTitle: task.title,
                        onUndo: {
                            showingQuickAcceptToast = false
                            undoLastSave()
                        }
                    )
                    .padding(.bottom, 80)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Inline Confirmation Bar (medium confidence)
            if showingInlineConfirmation, let task = lastParsedTasks.first, let response = lastResponse {
                VStack {
                    Spacer()
                    InlineConfirmationBar(
                        task: task,
                        confidence: response.effectiveConfidence,
                        onConfirm: {
                            showingInlineConfirmation = false
                            saveTasks(lastParsedTasks)
                            text = ""
                        },
                        onEdit: {
                            showingInlineConfirmation = false
                            expandForEditing()
                        },
                        onCancel: {
                            showingInlineConfirmation = false
                            lastParsedTasks = []
                        }
                    )
                    .padding(.bottom, 72)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            // Expanded overlay for low confidence
            if isExpanded {
                CommandBarExpanded(
                    isExpanded: $isExpanded,
                    messages: $messages,
                    inputText: $text,
                    onSend: { messageText in
                        handleExpandedSend(messageText)
                    },
                    onVoiceTap: onVoiceTap,
                    onClose: {
                        isExpanded = false
                    }
                )
            }
        }
    }
    
    // MARK: - Context Menu Overlay
    
    private var contextMenuOverlay: some View {
        Color.black.opacity(0.001)
            .ignoresSafeArea()
            .onTapGesture {
                showingContextMenu = false
            }
            .overlay(
                VStack(spacing: 0) {
                    Button {
                        showingContextMenu = false
                        // Handle manual task - could trigger add task flow
                    } label: {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Manual Task")
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                    
                    Button {
                        showingContextMenu = false
                        // Handle attach picture
                    } label: {
                        HStack {
                            Image(systemName: "photo")
                            Text("Attach Picture (Beta)")
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                    .buttonStyle(.plain)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                .frame(width: 200)
                .position(x: 60, y: -80)
            )
    }
    
    // MARK: - Actions
    
    private func handleSubmit() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Add user message to conversation history
        messages.append(ConversationMessage(role: "user", content: trimmedText))
        
        // Call the submit handler
        onSubmit(trimmedText) { response in
            handleParseResponse(response)
        }
    }
    
    private func handleExpandedSend(_ messageText: String) {
        messages.append(ConversationMessage(role: "user", content: messageText))
        
        onSubmit(messageText) { response in
            handleParseResponse(response)
        }
    }
    
    private func handleParseResponse(_ response: ParseResponse) {
        lastResponse = response
        
        switch response.type {
        case "complete":
            if let tasks = response.tasks {
                lastParsedTasks = tasks
                
                // Handle based on confidence
                switch response.effectiveConfidence {
                case .high:
                    // Auto-save and show toast
                    saveTasks(tasks)
                    withAnimation {
                        showingQuickAcceptToast = true
                    }
                    // Auto-hide toast after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showingQuickAcceptToast = false
                        }
                    }
                    text = ""
                    isExpanded = false
                    
                case .medium:
                    // Show inline confirmation
                    withAnimation {
                        showingInlineConfirmation = true
                    }
                    
                case .low:
                    // Expand to show conversation
                    messages.append(ConversationMessage(role: "assistant", content: response.summary ?? "I need a bit more information about that task."))
                    withAnimation {
                        isExpanded = true
                    }
                }
            }
            
        case "question":
            // Expand and show question
            messages.append(ConversationMessage(role: "assistant", content: response.text ?? "Can you tell me more?"))
            withAnimation {
                isExpanded = true
            }
            
        default:
            // For other types, show summary or text
            if let summary = response.summary {
                messages.append(ConversationMessage(role: "assistant", content: summary))
            } else if let text = response.text {
                messages.append(ConversationMessage(role: "assistant", content: text))
            }
            withAnimation {
                isExpanded = true
            }
        }
    }
    
    private func expandForEditing() {
        // Add context to messages for editing
        messages.append(ConversationMessage(role: "assistant", content: "What would you like to change?"))
        withAnimation {
            isExpanded = true
        }
    }
    
    private func saveTasks(_ tasks: [ParsedTask]) {
        Task {
            for parsedTask in tasks {
                let priority: Priority = {
                    switch parsedTask.priority.lowercased() {
                    case "low": return .low
                    case "high": return .high
                    default: return .medium
                    }
                }()
                
                let task = Task(
                    title: parsedTask.title,
                    dueDate: parsedTask.dueDate,
                    hasTime: parsedTask.hasTime,
                    priority: priority,
                    category: parsedTask.category,
                    notes: parsedTask.notes,
                    syncStatus: .pending
                )
                
                modelContext.insert(task)
                
                // Schedule notification if due date exists
                if parsedTask.dueDate != nil {
                    await NotificationManager.shared.scheduleNotification(for: task)
                }
                
                // Push to sync engine
                await syncEngine.pushTask(task)
            }
            
            try? modelContext.save()
        }
    }
    
    private func undoLastSave() {
        // Implementation for undoing last save
        // This would require tracking the last saved task IDs
    }
}

// MARK: - Preview

#Preview("Command Bar - Empty") {
    struct PreviewWrapper: View {
        @State private var text = ""
        
        var body: some View {
            VStack {
                Spacer()
                CommandBarView(
                    text: $text,
                    onSubmit: { text, callback in
                        // Simulate response
                        let response = ParseResponse(
                            type: "complete",
                            text: nil,
                            tasks: [ParsedTask(
                                id: UUID(),
                                title: text,
                                dueDate: Date(),
                                hasTime: false,
                                priority: "medium",
                                category: nil
                            )],
                            taskId: nil,
                            changes: nil,
                            summary: "Added task",
                            confidence: .high
                        )
                        callback(response)
                    },
                    onVoiceTap: {}
                )
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    return PreviewWrapper()
}

#Preview("Command Bar - With Text") {
    struct PreviewWrapper: View {
        @State private var text = "Buy groceries for dinner tonight"
        
        var body: some View {
            VStack {
                Spacer()
                CommandBarView(
                    text: $text,
                    onSubmit: { _, _ in },
                    onVoiceTap: {}
                )
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    return PreviewWrapper()
}
