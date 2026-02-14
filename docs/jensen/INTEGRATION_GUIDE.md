# Command Bar v2 + Today View Integration Guide

## Overview

This guide lists all files created/modified for the Command Bar v2 and Today View implementation. Use this when adding files to `project.pbxproj`.

---

## New Files (MUST add to project.pbxproj)

### Command Bar v2

1. **Docket/Docket/Views/ChatTaskCard.swift** (Command Bar UX Rework)
   - Elevated task preview card in conversation view (replaces InlineConfirmationBar)
   - Dependencies: ParsedTask, DueDateChip (ConfidenceComponents)

2. **Docket/Docket/Views/InlineTaskEditView.swift** (Module 2) — deprecated from flow
   - Inline editable card (no longer used; InlineConfirmationBar removed)

3. **Docket/Docket/Views/CommandBarVoiceMode.swift** (Module 4)
   - Voice mode UI for CommandBar
   - Dependencies: SpeechRecognitionManager, TTSManager

### Today View

3. **Docket/Docket/Views/TodayView.swift** (Module 8)
   - Today view with sections (Overdue, Due Today, Later Today, No Due Date)
   - Dependencies: CommandBarView, CommandBarExpanded

---

## Modified Files (NO pbxproj changes needed)

### Core Integration

- **Docket/Docket/Views/TaskListView.swift**
  - Added: @State showingInlineEdit, parsedTaskToEdit, isProcessingConversation
  - Added: @Query groceryStores
  - Modified: handleCommandSubmit with conversation initialization
  - Modified: InlineConfirmationBar.onEdit → opens InlineTaskEditView
  - Modified: saveParsedTasks with checklist/template support
  - Added: handleConversationReply for multi-turn dialogue
  - Added: InlineTaskEditView overlay
  - Added: isProcessing passed to CommandBarExpanded

- **Docket/Docket/Views/CommandBarExpanded.swift**
  - Added: isProcessing parameter (was @State, now passed in)
  - Title: "Ask Docket" (was "Task Assistant")

- **Docket/Docket/Views/EmptyListView.swift**
  - Added: showCommandBarCTA parameter
  - Updated: CTA text references command bar

---

## State Variables Added to Existing Views

### TaskListView

```swift
@State private var showingInlineEdit = false
@State private var parsedTaskToEdit: ParsedTask?
@State private var isProcessingConversation = false
```

---

## Imports Added

No new framework imports required — all use existing frameworks:

- SwiftUI
- SwiftData
- \_Concurrency
- Combine

---

## SF Symbols Used

### InlineTaskEditView

- `calendar` — Due date button
- `clock` — Time button
- `xmark.circle.fill` — Cancel/Clear
- `arrow.down`, `minus`, `arrow.up` — Priority icons

### CommandBarVoiceMode

- `xmark.circle.fill` — Cancel
- `mic.fill` — Mic active
- `stop.fill` — Stop recording
- `checkmark.circle.fill` — Confirm

### TodayView

- `calendar.badge.checkmark` — Empty state
- `exclamationmark.triangle.fill` — Overdue section
- `calendar` — Due Today section
- `clock` — Later Today section
- `infinity` — No Due Date section

---

## pbxproj Addition Order

1. Add `InlineTaskEditView.swift` to `PBXFileReference`
2. Add `InlineTaskEditView.swift` to `PBXBuildFile`
3. Add file ref to `PBXGroup` (Views/)
4. Add build file to `PBXSourcesBuildPhase`
5. Repeat for `CommandBarVoiceMode.swift`
6. Repeat for `TodayView.swift`

---

## Testing Checklist

### Before Merge

- [ ] Project builds with all new files added to pbxproj
- [ ] No compiler warnings/errors
- [ ] App launches without crash

### Command Bar v2

- [ ] High confidence → QuickAcceptToast → auto-save
- [ ] Medium confidence → InlineConfirmationBar
- [ ] Medium confidence → Edit → InlineTaskEditView
- [ ] Low confidence → CommandBarExpanded with chat
- [ ] Multi-turn conversation works
- [ ] Voice mode activates (mic UI shows)

### Today View

- [ ] Sections display correctly
- [ ] Overdue tasks show red header
- [ ] Pull-to-refresh triggers sync
- [ ] CommandBar visible at bottom

---

## Known Limitations

1. **TodayView.handleCommandSubmit** — Not fully implemented (returns stub response)
2. **CommandBarVoiceMode** — Audio session management simplified (needs device testing)
3. **UpcomingView** — Not implemented (Module 10 optional)

---

## GitHub Issues

| Module   | Issue # |
| -------- | ------- |
| Module 0 | #11     |
| Module 1 | #12     |
| Module 2 | #13     |

---

---

## Voice UX Improvements (2026-02-14)

- **VoiceRecordingView:** Auto-start recording when sheet opens; prefetch voice profile in parallel
- **CommandBarExpanded:** Title "Ask Docket"
- **parse-voice-tasks:** Prompt updates for fewer turns (see [VOICE_UX_IMPROVEMENTS_2026-02-14.md](VOICE_UX_IMPROVEMENTS_2026-02-14.md))

---

_Generated: 2026-02-14_
