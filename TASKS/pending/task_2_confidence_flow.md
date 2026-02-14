# Task 2: Implement Confidence Flow in TaskListView

## Status: PENDING

## Prerequisites
- Task 1 must be COMPLETE

## Objective
Implement the confidence-based response handling when user submits text via CommandBarView.

## Requirements

### 1. Update handleCommandSubmit
Replace placeholder with actual implementation:

```swift
@State private var showingQuickAcceptToast = false
@State private var showingInlineConfirmation = false
@State private var showingCommandBarExpanded = false
@State private var lastParsedTasks: [ParsedTask] = []
@State private var lastParseResponse: ParseResponse?

private func handleCommandSubmit(_ text: String) {
    Task {
        let messages = [ConversationMessage(role: "user", content: text)]
        
        do {
            let response = try await parser.send(messages: messages)
            await MainActor.run {
                self.lastParseResponse = response
                
                switch response.effectiveConfidence {
                case .high:
                    // Auto-accept with toast
                    if let tasks = response.tasks {
                        self.lastParsedTasks = tasks
                        self.showingQuickAcceptToast = true
                        // Auto-save after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.saveTasks(tasks)
                        }
                    }
                    
                case .medium:
                    // Show inline confirmation
                    if let tasks = response.tasks {
                        self.lastParsedTasks = tasks
                        self.showingInlineConfirmation = true
                    }
                    
                case .low:
                    // Expand for conversation
                    self.showingCommandBarExpanded = true
                }
            }
        } catch {
            print("Parse error: \(error)")
        }
    }
}

private func saveTasks(_ tasks: [ParsedTask]) {
    // Save to SwiftData
    // Sync with Supabase
    // Show confirmation
}
```

### 2. Add UI State Variables
Add to TaskListView:
```swift
@State private var showingQuickAcceptToast = false
@State private var showingInlineConfirmation = false
@State private var showingCommandBarExpanded = false
@State private var lastParsedTasks: [ParsedTask] = []
@State private var lastParseResponse: ParseResponse?
```

### 3. Add UI Overlay
Add ZStack overlay in body:
```swift
ZStack {
    // Existing content
    
    // Quick Accept Toast
    if showingQuickAcceptToast, let task = lastParsedTasks.first {
        VStack {
            Spacer()
            QuickAcceptToast(taskTitle: task.title) {
                // Undo action
                showingQuickAcceptToast = false
            }
        }
        .transition(.move(edge: .bottom))
    }
    
    // Inline Confirmation
    if showingInlineConfirmation, let task = lastParsedTasks.first {
        InlineConfirmationBar(
            task: task,
            confidence: .medium,
            onConfirm: {
                saveTasks(lastParsedTasks)
                showingInlineConfirmation = false
            },
            onEdit: {
                // Open edit flow
                showingInlineConfirmation = false
            },
            onCancel: {
                showingInlineConfirmation = false
            }
        )
    }
}
```

## Acceptance Criteria
- [ ] High confidence triggers QuickAcceptToast
- [ ] Medium confidence triggers InlineConfirmationBar
- [ ] Low confidence triggers CommandBarExpanded
- [ ] Tasks auto-save on high confidence
- [ ] Tasks can be confirmed/edited/cancelled on medium confidence
- [ ] Errors handled gracefully

## Apple Best Practices
- Use proper error handling (do-catch)
- Show loading state during async operations
- Provide feedback for all user actions
- Support accessibility announcements

## References
- [Apple HIG - Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts)
- [Swift Concurrency](https://developer.apple.com/documentation/swift/concurrency)
