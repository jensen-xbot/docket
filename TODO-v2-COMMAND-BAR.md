# TODO: Unified AI Command Bar v2.0

**Priority: P0 (Critical Path for Product Differentiation)**  
**Status: In Progress**  
**Branch:** `feature/command-bar-v2`

---

## Phase P0: Foundation (Hours 1-4)

### P0.1: Edge Function Confidence Scoring
- [ ] Update Supabase Edge Function `parse-voice-tasks`
  - [ ] Modify system prompt to assess confidence level
  - [ ] Add `confidence` field to ParseResponse schema
  - [ ] Confidence rules:
    - High: Explicit title + explicit date + no share target
    - Medium: Vague title OR inferred priority OR relative date OR share target
    - Low: Missing title OR missing date (required for complete)
  - [ ] Deploy and test with sample utterances
- **Deliverable:** Edge Function returns `confidence: "high" | "medium" | "low"`

### P0.2: Swift Models Update
- [ ] Update `ParseResponse` struct
  - [ ] Add `confidence: String?` field
  - [ ] Backward compatibility (nil = treat as medium)
  - [ ] Update unit tests
- [ ] Update `ParsedTask` if needed for new fields
- **Deliverable:** Swift models handle confidence field

### P0.3: CommandBarView Shell
- [ ] Create `Views/CommandBarView.swift`
  - [ ] State machine enum: `idle | textInput | inlineConfirm | expanded | voice`
  - [ ] Main container with @State for current state
  - [ ] Integration with TaskListView (safeAreaInset)
  - [ ] Basic layout structure
- **Deliverable:** CommandBarView compiles, shows placeholder

---

## Phase P1: Collapsed Bar (Hours 5-8)

### P1.1: CommandBarCollapsed Component
- [ ] Create `Views/CommandBarCollapsed.swift`
  - [ ] [+] button on left (single tap → AddTaskView)
  - [ ] Text field in center with placeholder "What do you need to get done?"
  - [ ] Mic icon on right (morphs to submit arrow when text present)
  - [ ] Multi-line expansion (max 4 lines) like iMessage
  - [ ] `.textFieldStyle(.roundedBorder)` or custom
- [ ] Animation: Mic icon crossfades to submit arrow (~0.2s)
- **Deliverable:** Collapsed bar functional, matches spec

### P1.2: Text Input Mode
- [ ] Handle text field focus
  - [ ] Keyboard rises, placeholder clears
  - [ ] No task list filtering (already removed)
  - [ ] Return key submits
- [ ] Submit action
  - [ ] Send text to Edge Function
  - [ ] Show loading indicator
  - [ ] Handle response (route to appropriate state)
- **Deliverable:** Text input creates tasks via Edge Function

### P1.3: Mode Switching
- [ ] Mic button in text mode
  - [ ] Keeps any typed text
  - [ ] Switches to voice mode
  - [ ] Passes existing text as first user message
- **Deliverable:** Can switch text → voice keeping context

---

## Phase P2: Confidence System (Hours 9-14)

### P2.1: High Confidence Auto-Accept
- [ ] Implement auto-accept flow
  - [ ] Detect `confidence: "high"` in ParseResponse
  - [ ] Immediately call `saveTasks()`
  - [ ] Show toast notification (system or custom)
  - [ ] Animate new task appearing at top of list
  - [ ] Auto-collapse bar after brief delay (~1s)
- [ ] Toast component
  - [ ] "✅ Added: [task title]"
  - [ ] Auto-dismiss after 2s
  - [ ] Haptic feedback (light success)
- **Deliverable:** High confidence tasks auto-accept with toast

### P2.2: Inline Confirmation Card
- [ ] Create `Views/InlineConfirmationCard.swift`
  - [ ] Task preview (title, date, priority, category)
  - [ ] Action buttons: [👍 Looks good] [✏️ Edit] [🗑️ Cancel]
  - [ ] Compact layout (fits in collapsed bar height or slightly taller)
  - [ ] Smooth appearance animation (slide up + fade)
- [ ] Handle medium confidence
  - [ ] Detect `confidence: "medium"`
  - [ ] Show card inline above/beside input bar
  - [ ] Keep bar in collapsed state
- **Deliverable:** Medium confidence shows inline card

### P2.3: Edit Mode
- [ ] Inline edit expansion
  - [ ] Tap ✏️ → Card expands with editable fields
  - [ ] Title TextField
  - [ ] Due date picker (compact)
  - [ ] Priority picker (segmented)
  - [ ] Category picker (chips)
  - [ ] [Save] [Cancel] buttons
- [ ] Save updates the ParsedTask in state
- [ ] [👍 Looks good] uses edited version
- **Deliverable:** Can edit medium-confidence tasks inline

### P2.4: Cancel/Timeout
- [ ] Cancel action
  - [ ] [🗑️ Cancel] dismisses entire flow
  - [ ] Clear state, return to idle
  - [ ] Discard parsed task
- [ ] Auto-timeout
  - [ ] 30s timer on inline confirmation
  - [ ] Auto-cancel if no action
- **Deliverable:** Proper cancel/timeout handling

---

## Phase P3: Expanded Conversation (Hours 15-18)

### P3.1: CommandBarExpanded
- [ ] Create `Views/CommandBarExpanded.swift`
  - [ ] Full-height bottom sheet (~60% of screen)
  - [ ] Chat bubbles (user + assistant)
  - [ ] ScrollView with auto-scroll
  - [ ] Shared conversation UI (reuse VoiceRecordingView UI)
- [ ] Trigger conditions
  - [ ] `confidence: "low"`
  - [ ] `type: "question"`
  - [ ] User explicitly requests conversation mode (optional)
- **Deliverable:** Expanded view for low confidence/questions

### P3.2: Chat Bubbles
- [ ] User message bubbles
  - [ ] Right-aligned, blue background
  - [ ] Shows user text
- [ ] Assistant message bubbles
  - [ ] Left-aligned, gray background
  - [ ] Shows AI text
- [ ] Shared ID scheme (no flicker on transition)
- **Deliverable:** Smooth chat UI in expanded mode

### P3.3: Dismissal
- [ ] Swipe down to dismiss
  - [ ] Any downward swipe ≥ 20% of height dismisses
  - [ ] Animation: slides down + fades
- [ ] Tap outside
  - [ ] Tap on task list behind dismisses expanded view
- [ ] Cancel button (optional)
- **Deliverable:** Easy dismissal of expanded view

---

## Phase P4: Voice Mode Distinction (Hours 19-22)

### P4.1: Voice Visual Treatment
- [ ] Create `Views/VoiceModeView.swift`
  - [ ] Distinct from text mode (different colors)
  - [ ] Pulsing orb during recording (red, breathing animation)
  - [ ] Audio level visualization (green waveform/bars)
  - [ ] Listening / Processing / Speaking states
- [ ] State machine for voice
  - [ ] idle → listening → processing → speaking → (loop or complete)
- **Deliverable:** Voice mode visually distinct

### P4.2: TTS Prompt
- [ ] Initial TTS greeting
  - [ ] On entering voice mode: "What do you need to get done?"
  - [ ] Wait for TTS completion before starting mic
  - [ ] Skip if user already started speaking
- [ ] Confidence-based responses
  - [ ] High: "Added. Anything else?" (or just success sound)
  - [ ] Medium: Read task back, wait for confirmation
  - [ ] Low: Read question, wait for response
- **Deliverable:** Voice mode has full TTS flow

### P4.3: Silence Detection
- [ ] Auto-submit on silence
  - [ ] ~2-3 seconds of silence after speech
  - [ ] Submit transcription to AI
  - [ ] Avoid submitting on initial silence (before speech)
- **Deliverable:** Smooth voice flow with silence detection

---

## Phase P5: Integration & Polish (Hours 23-26)

### P5.1: TaskListView Integration
- [ ] Update `TaskListView.swift`
  - [ ] Add CommandBarView via `safeAreaInset(edge: .bottom)`
  - [ ] Remove `showingVoiceRecording` sheet trigger
  - [ ] Remove mic/+ from toolbar (keep filter, bell, profile)
  - [ ] Point EmptyListView CTA to Command Bar
- **Deliverable:** Command Bar is main interaction surface

### P5.2: Siri Shortcut Update
- [ ] Update OpenVoiceTaskIntent
  - [ ] Opens CommandBarView in voice mode (not VoiceRecordingView sheet)
- **Deliverable:** Siri shortcut uses new Command Bar

### P5.3: State Persistence
- [ ] Handle app backgrounding
  - [ ] Pause recording state
  - [ ] Resume on foreground
- [ ] Handle interruptions
  - [ ] Phone call: cancel voice, save partial state
  - [ ] Notification: continue unless user taps away
- **Deliverable:** Robust state management

---

## Phase P6: Testing & QA (Hours 27-30)

### P6.1: Unit Tests
- [ ] Test confidence scoring logic
- [ ] Test state machine transitions
- [ ] Test UI component rendering
- **Deliverable:** Test coverage for new components

### P6.2: UI Tests
- [ ] Test high confidence auto-accept
- [ ] Test medium confidence inline card
- [ ] Test low confidence expansion
- [ ] Test mode switching
- [ ] Test cancellation
- **Deliverable:** UI tests passing

### P6.3: Manual QA Matrix
| Scenario | Expected |
|----------|----------|
| Type "Call mom tomorrow" | High confidence → Toast → Task appears |
| Type "meeting" | Medium → Inline card → Accept → Task added |
| Type "add task" + Submit | Low → Expanded → AI asks "What's the task?" |
| Tap 🎤 | Voice mode → TTS prompt → Listen → Process |
| Tap voice, then type | Switches to text mode, keeps any spoken text |
| Cancel inline card | Returns to idle, no task created |
| Background during voice | Pauses, resumes on foreground |
| Very long dictation | Handles gracefully, no memory issues |

### P6.4: Edge Cases
- [ ] Empty input submission (disable submit)
- [ ] Network failure (offline indicator, retry)
- [ ] TTS failure (fallback to text only)
- [ ] Rapid mic taps (debounce)
- [ ] Keyboard dismisses unexpectedly (safeguard)

---

## Phase P7: Documentation & Handoff (Hours 31-32)

### P7.1: Update Documentation
- [ ] Update PRD.md with new Command Bar v2.0 section
- [ ] Update ADR-012 with any implementation changes
- [ ] Update VOICE-TO-TASK-V2.md where relevant
- [ ] Add inline code comments for complex state logic
- **Deliverable:** Documentation reflects shipped implementation

### P7.2: Metrics Setup
- [ ] Add analytics tracking
  - [ ] Task creation method (voice/text/manual)
  - [ ] Confidence level distribution
  - [ ] Auto-accept rate
  - [ ] Inline edit rate
  - [ ] Mode switch frequency
- **Deliverable:** Metrics dashboard showing adoption

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Confidence calibration wrong | Medium | High | Launch with conservative thresholds, tune in v2.1 |
| Users confused by inline vs expanded | Low | Medium | Animation + clear visual distinction |
| Voice recognition accuracy drops | Low | High | Maintain Whisper fallback toggle |
| State machine complexity bugs | Medium | Medium | Extensive unit tests, clear state enum |
| Performance issues on iPhone SE | Low | Medium | Test on smallest device, optimize layouts |

---

## Dependencies

- ✅ Search refactor completed (branch: `feature/move-search-to-toolbar`)
- 🔄 Edge Function deployment (Phase P0.1)
- ⏳ VoiceRecordingView logic (being refactored into CommandBarView)
- ⏳ TTSManager streaming stability (pre-requisite for P4)

---

## Estimated Timeline

- **Phase P0-P1:** Day 1 (Hours 1-8) — Foundation + Collapsed Bar
- **Phase P2:** Day 2 (Hours 9-14) — Confidence System
- **Phase P3:** Day 2 (Hours 15-18) — Expanded Conversation
- **Phase P4:** Day 3 (Hours 19-22) — Voice Mode
- **Phase P5-P6:** Day 3-4 (Hours 23-30) — Integration + Testing
- **Phase P7:** Day 4 (Hours 31-32) — Documentation

**Total: ~32 hours of focused development**

---

## Success Criteria

- [ ] 70%+ of tasks auto-accepted (high confidence)
- [ ] < 10% edit rate on accepted tasks
- [ ] 40%+ of task creation via voice
- [ ] 0 critical bugs in production
- [ ] User feedback: "Faster than typing" (qualitative)

---

**Next Actions:**
1. Start P0.1: Update Edge Function confidence scoring
2. Merge search refactor branch into command-bar-v2 branch
3. Begin Swift model updates

**Document Owner:** Jensen  
**Last Updated:** 2026-02-14
