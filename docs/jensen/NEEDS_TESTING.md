# Testing Checklist

**Project:** Docket iOS — Command Bar v2 + Today View  
**Purpose:** Track all testing requirements before merge

---

## Must Test Before Merge (build-blocking)

### Module 0: Repo Cleanup
- [ ] Project builds in Xcode after node_modules removal
- [ ] No git tracking issues with .agent/ or data/

### Module 1: Wire confidence routing
- [ ] High confidence path: type "Remind me to call mom tomorrow" → QuickAcceptToast appears → task auto-saves
- [ ] Medium/low confidence path: type ambiguous task → CommandBarExpanded opens with ChatTaskCard
- [ ] Error handling: simulate network failure → graceful error message

### Module 2: Conversation flow with ChatTaskCard
- [ ] Medium/low confidence: AI returns type "complete" → ChatTaskCard appears below AI bubble
- [ ] Tap "Add" on ChatTaskCard → task saved, confirmation bubble in chat
- [ ] Tap "Edit" on ChatTaskCard → card dismisses, user can type corrections in chat
- [ ] Tap "Cancel" on ChatTaskCard → card dismisses, conversation stays open
- [ ] Type follow-up ("actually make it Wednesday") → AI re-parses → updated ChatTaskCard

### Module 3: Expanded conversation
- [ ] Low confidence opens expanded view with chat bubbles
- [ ] Type reply → sends to Edge Function → response appended
- [ ] Continue conversation until AI returns complete → routes to confidence flow
- [ ] Swipe down or tap X dismisses expanded view

### Module 4: Voice mode integration
- [ ] Tap voice button → VoiceRecordingView sheet opens → **recording auto-starts** (no mic tap)
- [ ] Silence detection: short utterance ("yes") stops within ~1.5s; longer utterance within ~2.2s
- [ ] Speak task → transcription appears as chat bubble
- [ ] AI response plays via TTS
- [ ] Can switch to text input mid-conversation
- [ ] Voice transcription commits → confidence flow triggered
- [ ] Voice UX: "event"/"meeting" terminology works; "lunch" inferred as noon; fewer turns

### Module 5: Polish + deprecation
- [ ] Toolbar has only filter, bell, profile (no mic, no +)
- [ ] EmptyListView text references command bar
- [ ] One-shot high confidence auto-collapses bar
- [ ] Swipe down dismisses expanded view
- [ ] Keyboard dismisses on tap outside (bar stays)

### Module 6: Integration documentation
- [ ] Documentation is complete and accurate

### Module 8: TodayView
- [ ] Today view shows sections: Overdue, Due Today, No Due Date
- [ ] Overdue tasks show red section header
- [ ] Pull-to-refresh triggers sync
- [ ] CommandBar visible at bottom
- [ ] Empty state shows friendly message

### Module 9: Navigation
- [ ] App launches to Today view by default
- [ ] Segment control switches Today | All Tasks
- [ ] CommandBar visible in both views
- [ ] Toolbar consistent across views

### Module 10: Upcoming view (if implemented)
- [ ] Groups: Tomorrow, This Week, Next Week, Later
- [ ] Tasks sorted correctly within groups

---

## Should Test (functional)

### Command Bar v2
- [ ] Task creation via voice in different accents/noise levels
- [ ] Task creation via text with typos/abbreviations
- [ ] Multi-task creation ("Buy milk and eggs tomorrow")
- [ ] Task updates via voice/text
- [ ] Task deletion via voice/text
- [ ] Offline mode: queue tasks, sync when online
- [ ] Rapid mic button taps (debouncing)

### Today View
- [ ] Tasks due at specific times show in "Later Today" section
- [ ] Completed tasks don't appear in Today view
- [ ] Changing due date moves task between sections

### General
- [ ] Deep links open correct task
- [ ] Push notifications open correct task
- [ ] Share extension works

---

## Visual QA

### Light Mode
- [ ] All views render correctly in light mode
- [ ] Priority colors correct: low (gray), medium (orange), high (red)
- [ ] Due date colors correct: far (green), soon (yellow), overdue (red)

### Dark Mode
- [ ] All views render correctly in dark mode
- [ ] Colors adapt properly
- [ ] Text contrast sufficient

### Layouts
- [ ] iPhone SE (small screen) — all elements visible
- [ ] iPhone 16 Pro Max (large screen) — no excessive whitespace
- [ ] Dynamic Type (accessibility sizes) — text doesn't truncate

### Animations
- [ ] Command bar expansion smooth (0.2-0.3s)
- [ ] Toast slides in/out smoothly
- [ ] ChatTaskCard spring animation on appear
- [ ] Keyboard dismissal smooth

---

## Edge Cases

- [ ] **Offline text submission** — queues correctly, syncs when online
- [ ] **App backgrounding during voice** — recording stops gracefully, no crash
- [ ] **Rapid mic button taps** — only one recording session active
- [ ] **Very long text input** — text field expands, no truncation
- [ ] **Empty submission** — prevented, no API call
- [ ] **Invalid date parsing** — graceful error, asks for clarification
- [ ] **Network timeout** — shows error, allows retry
- [ ] **Low storage** — graceful handling
- [ ] **Permission denied (mic)** — shows settings prompt
- [ ] **Permission denied (speech recognition)** — shows settings prompt

---

## Performance

- [ ] Cold start to interactive < 2 seconds
- [ ] Voice transcription latency < 500ms
- [ ] Edge Function response < 2 seconds (streaming SSE)
- [ ] TTS playback starts < 500ms
- [ ] End-to-end voice: silence → AI audio < 2s for simple utterances (post-latency-optimization)
- [ ] Today view scrolls smoothly with 100+ tasks
- [ ] Memory usage stable during voice session

---

## Accessibility

- [ ] VoiceOver labels on all interactive elements
- [ ] Dynamic Type supported
- [ ] Minimum 44pt tap targets
- [ ] High contrast mode supported
- [ ] Reduce motion respected

---

---

## Voice Latency Optimizations (2026-02-14)

See [VOICE_LATENCY_OPTIMIZATION_2026-02-14.md](VOICE_LATENCY_OPTIMIZATION_2026-02-14.md) for full changelog.

- [ ] Voice response feels faster (silence → AI audio < 2s for simple utterances)
- [ ] Question-type responses: TTS starts immediately (overlap with processing)
- [ ] Task updates/deletes work with relevance-filtered context (e.g., "mark dentist done" with many tasks)
- [ ] VoiceModeContainer: task context and grocery stores passed correctly

## Voice UX Improvements (2026-02-14)

See [VOICE_UX_IMPROVEMENTS_2026-02-14.md](VOICE_UX_IMPROVEMENTS_2026-02-14.md) for full changelog.

- [ ] Voice auto-start: tap voice button → recording starts immediately (no second tap)
- [ ] "Make an event" / "schedule a meeting" parsed as task
- [ ] "Lunch time" inferred as noon (no "noon or different time?" question)
- [ ] User correction ("I asked you to meet with David") accepted as title
- [ ] Expanded sheet header shows "Ask Docket" (not "Task Assistant")

---

*Last updated: 2026-02-14*
