# Task 3: Test End-to-End Flow

## Status: PENDING

## Prerequisites
- Task 1 COMPLETE
- Task 2 COMPLETE

## Objective
Test the complete Command Bar v2.0 flow and verify all components work together.

## Test Scenarios

### Scenario 1: High Confidence Flow
1. Type: "Call mom tomorrow high priority"
2. Expected: QuickAcceptToast appears
3. Expected: Task auto-saves
4. Expected: Toast shows for 3 seconds then dismisses

### Scenario 2: Medium Confidence Flow
1. Type: "meeting with Sarah"
2. Expected: InlineConfirmationBar appears
3. Expected: Shows task preview with confidence indicator
4. Test Confirm button → saves task
5. Test Edit button → opens edit flow
6. Test Cancel button → dismisses

### Scenario 3: Low Confidence Flow
1. Type: "add a task"
2. Expected: CommandBarExpanded opens
3. Expected: AI asks for details
4. Type follow-up: "Call dentist"
5. Continue conversation until complete

### Scenario 4: Voice Mode
1. Tap voice button
2. Speak: "Buy groceries tomorrow"
3. Expected: VoiceRecordingView opens
4. Expected: Transcription shows
5. Expected: AI processes and responds

### Scenario 5: Search + Filter Integration
1. Type in search bar (toolbar): "grocery"
2. Expected: Task list filters
3. Expected: No interference with CommandBar

### Scenario 6: Offline Handling
1. Disconnect network
2. Type task in CommandBar
3. Expected: Offline indicator shows
4. Expected: Task queued for sync

## QA Checklist

### Functionality
- [ ] All confidence levels work correctly
- [ ] Voice mode integrates properly
- [ ] Search remains independent
- [ ] Offline handling works
- [ ] Error states handled gracefully

### Performance
- [ ] No lag when opening CommandBar
- [ ] Smooth animations (60fps)
- [ ] Fast AI response (< 2s)
- [ ] No memory leaks

### Accessibility
- [ ] VoiceOver support
- [ ] Dynamic Type support
- [ ] Reduce Motion support
- [ ] Color contrast adequate

### Device Testing
- [ ] iPhone SE (small screen)
- [ ] iPhone 16 Pro Max (large screen)
- [ ] iOS 17+ compatibility
- [ ] Portrait orientation

## Bug Report Format
```
## Bug [N]: [Title]
- **Severity:** [Critical/High/Medium/Low]
- **Steps:** [Reproduction steps]
- **Expected:** [What should happen]
- **Actual:** [What happens]
- **Screenshot:** [If applicable]
- **Device:** [iPhone model, iOS version]
```

## Sign-Off Criteria
All tests pass OR bugs documented with severity/priority.
