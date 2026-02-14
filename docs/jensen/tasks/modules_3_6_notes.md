# Modules 3-6 Implementation Notes

## Module 3: Expanded Conversation (Already mostly done)

Changes needed in TaskListView.swift for isProcessing state:

```swift
// Update CommandBarExpanded call to pass isProcessing:
CommandBarExpanded(
    isExpanded: $showingCommandBarExpanded,
    messages: $conversationMessages,
    inputText: $viewModel.searchText,
    isProcessing: isProcessingConversation,  // ADD
    onSend: { messageText in
        handleConversationReply(messageText)
    },
    onVoiceTap: { /* Module 4 */ },
    onClose: {
        showingCommandBarExpanded = false
        conversationMessages = []
    }
)
```

Update CommandBarExpanded.swift to accept isProcessing and pass to ConversationView (already has isProcessing).

## Module 4: Voice Mode Integration

Create CommandBarVoiceMode.swift that wraps VoiceRecordingView logic:
- SpeechRecognitionManager for transcription
- TTSManager for readback
- IntentClassifier for local intents
- Reuse existing VoiceRecordingView patterns

Integration points:
- CommandBarView.onVoiceTap → show CommandBarVoiceMode
- CommandBarExpanded.onVoiceTap → activate voice in expanded mode

## Module 5: Polish + Deprecation

Remove from TaskListView toolbar:
- showingVoiceRecording sheet → remove
- AddTask button → remove (keep CommandBar plus long-press)

Update EmptyListView:
- Change CTA text to reference command bar

Add to CommandBarExpanded:
- Auto-collapse on one-shot high confidence
- Swipe-down dismiss (already has, verify works)

## Module 6: Integration Documentation

Write docs/jensen/INTEGRATION_GUIDE.md with:
- All new/modified files
- State variables added
- pbxproj addition order

---

I'll implement these directly for speed.
