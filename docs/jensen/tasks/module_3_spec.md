# Module 3 Spec: Expanded Conversation for Low Confidence / Questions

## Overview
When confidence is low or the AI returns a question, expand the CommandBar into a full conversation view where the user can type replies. Continue the conversation until the AI returns a complete response, then route through the confidence flow.

## What's Already Done
- `CommandBarExpanded.swift` exists with conversation UI
- `ConversationView.swift` exists with chat bubbles
- `handleConversationReply()` exists in TaskListView (Module 1)

## What Needs To Be Fixed/Verified

### 1. Update CommandBarExpanded.swift - Wire up the conversation flow

Currently `CommandBarExpanded` takes `onSend: (String) -> Void`. This is already wired to `handleConversationReply`. 

**VERIFY** the flow works:
- User types in CommandBarExpanded → `onSend` called → `handleConversationReply` processes
- AI response appended to `conversationMessages`
- Scroll to bottom happens automatically

### 2. Ensure conversation state is maintained properly

In TaskListView, verify `conversationMessages` state is:
- Initialized when low confidence detected
- Cleared when expanded closes
- Not lost during re-renders

### 3. Fix any edge cases in handleConversationReply

Current `handleConversationReply` needs these improvements:

**Add loading state:**
```swift
@State private var isProcessingConversation = false
```

Update `handleConversationReply` to set this flag:
```swift
private func handleConversationReply(_ text: String) {
    isProcessingConversation = true  // ADD THIS
    Task {
        conversationMessages.append(ConversationMessage(role: "user", content: text))
        
        do {
            let response = try await parser.send(messages: conversationMessages)
            // ... rest of handling
        } catch {
            // ... error handling
        }
        await MainActor.run {
            isProcessingConversation = false  // ADD THIS
        }
    }
}
```

### 4. Pass isProcessing to CommandBarExpanded

Update the CommandBarExpanded call site to pass the processing state:
```swift
CommandBarExpanded(
    isExpanded: $showingCommandBarExpanded,
    messages: $conversationMessages,
    inputText: $viewModel.searchText,
    isProcessing: isProcessingConversation,  // ADD THIS
    onSend: { messageText in
        handleConversationReply(messageText)
    },
    // ... rest
)
```

### 5. Update CommandBarExpanded to accept and use isProcessing

Add parameter:
```swift
struct CommandBarExpanded: View {
    @Binding var isExpanded: Bool
    @Binding var messages: [ConversationMessage]
    @Binding var inputText: String
    var isProcessing: Bool = false  // ADD THIS
    var onSend: (String) -> Void
    // ...
}
```

Pass it to ConversationView (already has `isProcessing` parameter):
```swift
ConversationView(
    messages: messages,
    isProcessing: isProcessing,  // WIRE THIS
    onSend: { text in
        handleSend(text)
    },
    onVoiceTap: onVoiceTap
)
```

### 6. Add dismiss gesture

Add swipe-down to dismiss in CommandBarExpanded (already has DragGesture, verify it works).

## Acceptance Criteria
- [ ] Low confidence opens CommandBarExpanded with initial context
- [ ] Typing a reply sends to Edge Function
- [ ] "Thinking..." indicator appears while processing
- [ ] AI response appended to conversation
- [ ] Multiple turns supported
- [ ] When AI returns "complete", routes through confidence flow
- [ ] Swipe down dismisses expanded view
- [ ] Tap outside dismisses expanded view
- [ ] On dismiss, conversation state cleared

## Files to Modify
1. `Docket/Docket/Views/TaskListView.swift` — Add isProcessingConversation, pass to CommandBarExpanded
2. `Docket/Docket/Views/CommandBarExpanded.swift` — Accept isProcessing, pass to ConversationView

## Files to Verify (no changes needed)
- `Docket/Docket/Views/ConversationView.swift` — Already has isProcessing parameter

## Testing Notes
- Test multi-turn conversation
- Test dismissing mid-conversation (state should clear)
- Test that complete responses route to high/medium/low flow
- Test error handling in conversation
