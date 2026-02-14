# Module 2 Spec: Inline Edit Mode for Medium Confidence

## Overview
When the user taps "Edit" on the InlineConfirmationBar (medium confidence), open an inline editable card that lets them modify the task before saving.

## File Already Created (needs wiring)
- `Docket/Docket/Views/InlineTaskEditView.swift` — Created but NOT integrated

## What Needs To Be Done

### 1. Update TaskListView.swift

Add new state variables (around line 55, with other confidence flow state):
```swift
@State private var showingInlineEdit = false
@State private var taskToEdit: ParsedTask? = nil
```

### 2. Replace the current InlineConfirmationBar edit action

Current code (around line 240):
```swift
onEdit: {
    // Open expanded mode for editing
    showingInlineConfirmation = false
    showingCommandBarExpanded = true
}
```

Replace with:
```swift
onEdit: {
    showingInlineConfirmation = false
    taskToEdit = lastParsedTasks.first
    showingInlineEdit = true
}
```

### 3. Add InlineTaskEditView overlay

Add this overlay in the ZStack (after the InlineConfirmationBar block, around line 260):

```swift
// Inline Edit Card (medium confidence → edit)
if showingInlineEdit, var task = taskToEdit {
    VStack {
        Spacer()
        InlineTaskEditView(
            task: Binding(
                get: { task },
                set: { taskToEdit = $0 }
            ),
            onSave: {
                if let finalTask = taskToEdit {
                    saveParsedTasks([finalTask])
                }
                showingInlineEdit = false
                taskToEdit = nil
                viewModel.searchText = ""
            },
            onCancel: {
                showingInlineEdit = false
                taskToEdit = nil
            }
        )
        .padding(.bottom, 80)
    }
    .transition(.move(edge: .bottom).combined(with: .opacity))
}
```

### 4. Verify InlineTaskEditView.swift imports

Ensure these imports are at the top:
```swift
import SwiftUI
import SwiftData
```

### 5. Fix any compilation issues

Check that `ParsedTask` has the `toVoiceSnapshot()` method (should exist from VoiceRecordingView usage).

## Acceptance Criteria
- [ ] Tapping "Edit" on InlineConfirmationBar opens InlineTaskEditView
- [ ] Edit view shows: title field, due date picker, time picker, priority segmented picker, category chips
- [ ] Title is auto-focused on appear
- [ ] "Cancel" dismisses without saving
- [ ] "Save" calls saveParsedTasks with modified task
- [ ] Task is saved with edited values to SwiftData + Supabase

## Testing Notes
- Test editing title, date, time, priority, category
- Test cancel (should not create task)
- Test save (should create task with edited values)

## Files to Modify
1. `Docket/Docket/Views/TaskListView.swift` — Add state, wire InlineTaskEditView

## Files to Verify (no changes needed, but check they compile)
- `Docket/Docket/Views/InlineTaskEditView.swift`
