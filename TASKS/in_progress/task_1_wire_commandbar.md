# Task 1: Wire CommandBarView into TaskListView

## Status: IN PROGRESS

## Objective
Integrate CommandBarView into TaskListView so the command bar appears at the bottom of the task list and functions properly.

## Requirements

### 1. Add CommandBarView to TaskListView
Location: `Docket/Docket/Views/TaskListView.swift`

Current code (around line 144):
```swift
.safeAreaInset(edge: .bottom) {
    if !networkMonitor.isConnected {
        offlinePendingBanner
    }
}
```

Change to:
```swift
.safeAreaInset(edge: .bottom) {
    VStack(spacing: 0) {
        if !networkMonitor.isConnected {
            offlinePendingBanner
        }
        
        CommandBarView(
            text: $viewModel.searchText,
            onSubmit: { text in
                handleCommandSubmit(text)
            },
            onVoiceTap: {
                showingVoiceRecording = true
            }
        )
    }
}
```

### 2. Remove Toolbar Buttons
In `toolbarContent` (around line 190):
- Comment out or remove the mic button
- Comment out or remove the + button
- Keep: filter, bell, profile buttons

### 3. Add Handler Method
Add to TaskListView:
```swift
private func handleCommandSubmit(_ text: String) {
    // TODO: Task 2 - Implement confidence flow
    // For now, just print or show alert
    print("Submitted: \(text)")
}
```

## Acceptance Criteria
- [ ] CommandBarView appears at bottom of TaskListView
- [ ] CommandBarView is visible and functional
- [ ] Toolbar no longer has mic/+ buttons
- [ ] Filter, bell, profile buttons remain
- [ ] Typing in CommandBarView updates viewModel.searchText
- [ ] Submit action triggers handleCommandSubmit

## Apple Best Practices
- Use `.safeAreaInset(edge: .bottom)` for bottom-positioned controls
- Keep toolbar minimal - only essential actions
- Maintain visual hierarchy - command bar below content
- Support Dynamic Type and accessibility

## Related Files
- `/home/jensen/.openclaw/workspace/projects/docket/Docket/Docket/Views/TaskListView.swift`
- `/home/jensen/.openclaw/workspace/projects/docket/Docket/Docket/Views/CommandBarView.swift`

## QA Checklist
- [ ] Verify CommandBarView appears at bottom
- [ ] Verify toolbar buttons removed
- [ ] Verify no compilation errors
- [ ] Verify CommandBarView is interactive
- [ ] Check against Apple Human Interface Guidelines
