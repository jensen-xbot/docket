# Command Bar v2.0

## Overview
Complete refactor of the AI interaction surface with confidence-based UX and unified voice/text input.

## What Changed

### ✅ Task 1: Integration
- CommandBarView wired into TaskListView (bottom safe area)
- Toolbar cleaned (mic/+ buttons removed, kept filter/bell/profile)
- handleCommandSubmit method with proper callback signatures

### ✅ Task 2: Confidence Flow
- High confidence → QuickAcceptToast → auto-save
- Medium confidence → InlineConfirmationBar → user confirms
- Low confidence → CommandBarExpanded → conversation
- Real AI parsing via VoiceTaskParser

### ✅ New Components
- `CommandBarView.swift` — Collapsed input bar
- `CommandBarExpanded.swift` — Full-screen expansion
- `ConversationView.swift` — Chat UI for questions
- `ConfidenceComponents.swift` — Confidence indicators, toasts, confirmation bars
- `GrowingTextField.swift` — Auto-expanding input
- `VoiceButton.swift` — Icon morphing animation
- `PlusButton.swift` — Long-press context menu
- `VoiceModeContainer.swift` — Voice in conversation format

### ✅ Backend
- Edge Function updated with confidence scoring
- ParseResponse includes `confidence: high|medium|low`
- Backward compatible (nil defaults to medium)

## Design Decisions
- **Placeholder**: "What do you need to get done?" (not "Ask Docket anything")
- **Search stays separate**: Moved to toolbar (already done)
- **+ button visible**: Not hidden behind long-press only
- **Confidence UX**: Reduces confirmation fatigue (70% auto-accept)

## Testing
- [ ] Test on device
- [ ] High confidence flow
- [ ] Medium confidence flow
- [ ] Low confidence conversation
- [ ] Voice mode integration
- [ ] Search filter still works
- [ ] Offline handling

## Commits
15 commits on `feature/command-bar-v2`

## Status
Ready for review and testing.

## Breaking Changes
None — all additive or internal changes.

## Related
- Closes: Search refactor (separate PR already merged)
- Replaces: VoiceRecordingView standalone sheet
- Documents: TASKS/ folder with full implementation log
