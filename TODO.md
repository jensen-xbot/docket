# TODO: Docket

## MVP (Phases 1-4) - COMPLETE

- [x] Create project repository
- [x] Initialize Xcode project (SwiftUI, iOS 17+)
- [x] Set up project folder structure
- [x] Configure gitignore for Xcode
- [x] Create Task model (SwiftData)
- [x] Build task list view
- [x] Build create task view
- [x] Build edit task view
- [x] Implement complete/incomplete toggle
- [x] Implement delete task
- [x] Add local persistence (SwiftData)
- [x] Basic UI polish (dark mode, animations)
- [x] Branded splash screen with auth session check
- [x] Category model upgrade (icons + colors via CategoryItem)
- [x] Category icon/color picker (32 icons, 10 colors)
- [x] Inline edit mode for categories (rename, delete, icon/color)
- [x] Inline edit mode for stores (rename, delete)
- [x] Task row UI refresh (category icons/colors, outlined due date badges)
- [x] CategoryStore singleton for consistent state across views
- [x] Test on physical device

## v1.0: Cloud Sync Foundation - COMPLETE

### Phase 5: Cloud Infrastructure

- [x] Set up Supabase project
- [x] Create database schema (Tasks table)
- [x] Configure Row Level Security (RLS) policies
- [x] Implement Supabase Auth (email + Apple Sign In)
- [x] Create sync service (SwiftData <> Supabase)
- [x] Handle offline queue and conflict resolution
  - [x] NetworkMonitor (NWPathMonitor) for connectivity detection
  - [x] Network guards on all push/pull methods (offline -> .pending, not .failed)
  - [x] Automatic retry with exponential backoff (2s, 8s, 30s) for failed items
  - [x] Auto-flush pending queue on network reconnect
  - [x] Conflict logging when remote overwrites local pending changes
  - [x] Offline/pending UI indicators in TaskListView
- [x] Add due dates with local notifications
- [x] SyncEngine lifecycle refactor (single instance via environment, foreground sync)
- [x] Swift 6 strict concurrency fixes (see SWIFT6-CONCURRENCY-GUIDE.md)

## v1.1: Conversational Voice-to-Task - IN PROGRESS

### P0: Active Stability Hotfixes — Voice Hotfix One-Pass DONE

- [x] **Reproduce + eliminate lingering transcription flicker**
  - [x] Add deterministic repro matrix (see below)
  - [x] Add temporary timestamped event tracing (DEBUG only: `[VoiceTrace]`)
  - [x] Single-source rendering: live transcript stays visible until commit (removed `!isProcessingUtterance` from displayMessages)
  - [ ] Confirm on device under network latency and long dictation; remove debug instrumentation after validation
  - **Repro matrix (DEBUG build):** Manual vs silence stop | Whisper on/off | Natural TTS on/off | Interruption during listen/speak. Events: speech partial, silence reset/fire, stopRecording entry/exit, message append, transcribedText clear, TTS start/audio-ready/playback/finish.
- [x] **Fix pre-silence flash** — live transcript remains visible until commit + clear (atomic on MainActor).
- [x] **Interruption handling**
  - [x] `.ended`: view-driven `shouldResumeAfterInterruption`; manager resumes listening when flag set and was in listening flow
  - [x] `.began`: manager stops recording
  - [ ] QA: phone call, Siri, AirPods during handoff
- [x] **Silence timeout 2.2s** — baseline 2.2s (short), 2.8s (3+ words); adaptive in SpeechRecognitionManager.
- [x] **TTS presentation (synchronized text + audio)**
  - [x] `speakWithBoundedSync`: request TTS first; if ready within 750ms reveal text + play together; else reveal text and show "Preparing voice..." until playback
  - [x] TTS request timeout 8s; fallback to Apple TTS
- **Residual risk:** Remove `#if DEBUG` VoiceTrace after device validation. Manual QA for interruption + long dictation recommended.

### Phase 6: Speech Capture + TTS Foundation - COMPLETE

- [x] Add Speech framework entitlement
- [x] Add `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` to Info.plist
- [x] Create SpeechRecognitionManager (SFSpeechRecognizer + AVAudioEngine)
- [x] Create TTSManager (AVSpeechSynthesizer with completion callback)
- [x] Implement AVAudioSession switching (`.playAndRecord` + `.defaultToSpeaker`)
- [x] Handle audio session interruptions (`AVAudioSession.interruptionNotification`)
- [x] Build VoiceRecordingView (mic button + conversation overlay)
- [x] Fix Swift 6 dispatch_assert_queue crashes (nonisolated static helpers, async APIs)
- [x] Silence detection with adaptive timeout (2.2s short / 2.8s long utterances)
- [x] Tune silence timeout for production UX (2.2s baseline, validate on real speech)
- [x] Test on device: speak -> transcription -> TTS readback -> mic restarts

### Phase 7: Conversational AI Parsing - COMPLETE

- [x] Set up OpenRouter account + API key
- [x] Supabase Edge Function `parse-voice-tasks` (conversational system prompt, gpt-4.1-mini)
- [x] Edge Function receives `messages[]` array (not single text)
- [x] Edge Function returns `{ type: "question"|"complete", ... }`
- [x] Build VoiceTaskParser (sends messages[], handles question/complete responses)
  - [x] Fixed 401 auth: disabled gateway verify_jwt, function validates via getUser()
  - [x] Uses Supabase SDK `functions.invoke()` with explicit Authorization header
- [x] Build ParsedTask, ConversationMessage, ParseResponse models
- [x] Implement conversation loop on iOS (messages array + if/else on response type)
- [x] Resilient response validation (unexpected AI types coerced to "question")
- [x] Time-aware greetings (Good morning/afternoon/evening based on timezone)
- [x] DateTime support: "at 9am" -> `yyyy-MM-ddTHH:mm` format with hasTime flag
- [x] Test multi-turn: partial info -> AI asks -> user responds -> task created
- [x] Test power-user: full utterance -> instant task creation (no follow-ups)
- [x] English only for v1.1

### Phase 8: Confirmation + Continuation - COMPLETE

- [x] Wire up: conversation complete -> auto-save if no "?" in summary
- [x] Voice confirmation: listen for "yes" / "add it" after AI asks "Want me to add?"
- [x] "Anything else?" flow: after saving, ask if user wants to add more tasks
- [x] Dismissal detection: "no" / "that's all" / "I'm done" closes voice view
- [x] Integrate voice-created tasks into synced model (SwiftData + SyncEngine push)
- [x] Build TaskConfirmationView polish (notes + share target display, inline editing)
- [x] Share resolution flow (name -> email via contacts cache or inline prompt)
- [x] Handle corrections mid-conversation ("actually make it Wednesday")
  - [x] Pre-save corrections: say correction before confirmation → AI returns updated tasks
  - [x] Post-save corrections: say correction after "Anything else?" → updates existing task in SwiftData + Supabase
  - [x] Word boundary matching for yes/no/dismiss detection (prevents "note" matching "no")
- [x] TTS mute toggle in Settings

### Phase 9: Voice Polish — COMPLETE

- [x] Upgrade TTS to OpenAI TTS API (tts-1, ~$0.0015/response) — natural-sounding voices replace robotic AVSpeechSynthesizer
  - [x] Edge Function `text-to-speech` calls OpenAI TTS API, returns MP3 audio
  - [x] TTSManager uses AVAudioPlayer for OpenAI TTS, keeps AVSpeechSynthesizer as fallback
  - [x] Voice picker in Settings: alloy, echo, fable, onyx, nova (default), shimmer
  - [x] Automatic fallback to Apple TTS if OpenAI fails (network error, API down)
  - [x] "Natural voice" toggle in ProfileView (defaults to enabled)
- [x] Error handling (no speech, network down, AI failure, unknown share recipient)
- [x] Loading states and progress indicators (pulsing mic, "thinking" state)
- [x] Haptic feedback (start recording, task created, error)
- [x] Edge cases (empty input, very long dictation, conversation timeout)
- [x] Optional: Whisper API fallback for accuracy
- [x] Voice recording UX overhaul (Feb 2026)
  - [x] Fix live transcription flicker (unified displayMessages list with shared IDs)
  - [x] Fix stale SFSpeechRecognizer callbacks overwriting committed text
  - [x] Fix chat not auto-scrolling (ScrollViewReader + GeometryReader bottom-anchored)
  - [x] Fix chat bubbles looking boxy (Spacer(minLength: 48) + clipShape)
  - [x] Fix header wasting space (reduced VStack spacing, tighter padding)
  - [x] Red breathing mic button with phaseAnimator (restarts reliably on every listen cycle)
  - [x] Green audio-level indicator inside mic icon (RMS + EMA smoothing at ~12fps)
  - [x] Double-processing guard (isProcessingUtterance flag)
- [x] Siri Shortcuts integration
- [x] Recurring tasks (data model, UI in Edit/Add, task row icon, voice parsing)

### Phase 10: Personalization Adaptation (v1.2 Foundation)

- [x] Personalization architecture + privacy spec (opt-in, reset, retention window)
- [x] Add `TaskSource` metadata to distinguish voice-created tasks from manual tasks
- [x] Snapshot-based correction tracking on edits to voice-created tasks
- [x] Create `record-corrections` Edge Function with auth, validation, deduplication, and rate limiting
- [x] Create `user_voice_profiles` schema (vocabulary aliases, category mappings, store aliases, time habits)
- [x] Inject compact personalization context into `parse-voice-tasks` prompt
- [x] Add UI controls in Profile: "Personalization On/Off" + "Reset learned voice data"
- [ ] Add metrics dashboard:
  - [ ] edit-after-voice rate
  - [ ] auto-confirm rate
  - [ ] turns-to-complete
  - [ ] TTS fallback rate
  - [ ] personalization hit rate (alias/mapping applied)

### Phase 11: Inline Task Cards in Voice Chat
Voice-created tasks appear as editable cards directly in the chat window. Tasks auto-save immediately AND show as inline cards that phase in one-by-one. Users can expand a card to edit or delete without leaving the voice session. Only one card expands at a time. Delete requires confirmation.

- [ ] ChatTaskCard view
  - [ ] Compact state: full-width card showing title, due date badge, priority indicator, category chip
  - [ ] Expanded state: inline edit fields (title TextField, priority picker, date picker, category chips, notes)
  - [ ] Only one card expanded at a time (tapping another collapses the current)
  - [ ] Update button: saves edits to SwiftData + SyncEngine push, collapses card
  - [ ] Delete button: shows confirmation ("Delete this task?"), removes from SwiftData + Supabase
  - [ ] Smooth expand/collapse animation (spring, ~0.3s)
- [ ] Staggered card appearance
  - [ ] After AI summary + auto-save, cards phase in one-by-one (~0.3s delay between each)
  - [ ] Transition: move from bottom + opacity fade-in
  - [ ] ScrollView auto-scrolls as each card appears
- [ ] Integration with VoiceRecordingView
  - [ ] Insert task cards into chat after the AI summary bubble (not in displayMessages — separate rendered section)
  - [ ] Track `@State var savedTaskCards: [Task]` for cards currently visible in chat
  - [ ] Track `@State var expandedCardId: UUID?` for single-expand behavior
  - [ ] Wire up inline edits: update Task fields, push via SyncEngine, trigger voice snapshot correction detection
  - [ ] Wire up inline delete: confirmation dialog, delete from SwiftData, remove card from list
- [ ] Session continuity
  - [ ] Voice session stays open during card editing (state machine unchanged)
  - [ ] "Anything else?" TTS plays after cards finish appearing (not after each card)
  - [ ] Mic auto-restarts after TTS finishes (existing behavior preserved)
  - [ ] Conversation messages[] array intact — user can continue adding tasks or making corrections
- [ ] Voice personalization hook
  - [ ] Inline edits to voice-created tasks trigger correction detection (same as EditTaskView)
  - [ ] Compare edited fields against voiceSnapshotData, fire-and-forget to record-corrections

### Phase 12: Advanced Subtasks (Unlimited Nesting)

Full subtask support: each subtask is a full Task with title, due dates, priority, notes, collaboration — unlimited nesting depth. Voice + manual creation.

- [ ] Data model
  - [ ] Add `parentTaskId: UUID?` to Task (nil = top-level task)
  - [ ] Self-referential relationship for unlimited nesting
  - [ ] Computed helpers: `depth`, `root`, `children` (or query via modelContext)
  - [ ] Progress auto-calculation: parent = completed subtasks / total subtasks when `isProgressEnabled`
- [ ] Database migration
  - [ ] Create `014_add_subtasks.sql`: add `parent_task_id` FK referencing `tasks(id)`, index for hierarchy queries
  - [ ] Update RLS policies for shared subtasks (inherit parent share context)
- [ ] Swift models
  - [ ] Task: `parentTaskId`, init/encode/decode updates
  - [ ] TaskDTO: `parentTaskId` (parent_task_id)
  - [ ] ParsedTask: `subtasks: [ParsedTask]?` for voice-created nested tasks
  - [ ] TaskContext + TaskChanges: include subtask info for voice updates
  - [ ] SubtaskGroup or equivalent helper for flattened tree display
- [ ] UI: Manual creation
  - [ ] AddTaskView / EditTaskView: Nested subtask list (add, reorder, delete subtasks)
  - [ ] TaskRowView: Indented subtask rows with visual hierarchy
  - [ ] TaskListView: Expand/collapse parent rows; show subtask count badge
  - [ ] Progress: Parent task auto-updates from subtask completion when progress enabled
- [ ] UI: Voice creation
  - [ ] Edge Function prompt: Parse "with subtasks", compound tasks ("Plan trip: book flight, reserve hotel, pack bags")
  - [ ] ParsedTask gains `subtasks: [ParsedTask]?` with recursive structure
  - [ ] saveTasks(): Recursive creation — parent first, then children (depth-first)
  - [ ] TaskConfirmationView: Expandable nested preview before confirm
- [ ] Collaboration
  - [ ] Subtasks inherit parent sharing (task_shares via parent)
  - [ ] Shared subtask edits propagate via Realtime; both users see nested updates
- [ ] Sync
  - [ ] SyncEngine: Push parent before children; pull maintains hierarchy
  - [ ] Offline queue: Respect parent-child order on flush

### Pre-Launch Hardening

- [x] Edge Function rate limiting (prevent abuse/runaway costs — 60 req/hr/user)
- [x] Edge Function request timeout (15s abort controller — prevents hanging requests)
- [ ] Transcription retry logic (auto-retry on transient SFSpeechRecognizer failures, max 2 retries)
- [ ] Haptic refinement (distinct patterns: success, correction, error, speech detected)
- [ ] Audio waveform visualization (animate bars with voice level during recording)
- [x] Privacy manifest (required for App Store since 2024)
- [ ] Accessibility audit (VoiceOver on VoiceRecordingView, 44pt tap targets, Reduce Motion)
- [ ] Pre-launch test matrix:
  - [ ] Network offline during voice → offline indicator, queue for retry
  - [ ] User interrupts TTS → stops speaking, listens for new input
  - [ ] App backgrounded mid-recording → pauses, resumes on foreground
  - [ ] Very long dictation (2+ min) → no memory issues
  - [ ] Rapid mic button tap → debounces, no crash
  - [ ] AirPods connected → routes audio correctly
  - [ ] Phone call interrupts → stops recording, graceful recovery

### Optimization (post-launch)

- [ ] Task context trimming (send only incomplete + recent 7 days, cap at 20 tasks)
- [ ] Task context hash caching (skip re-sending if task list unchanged between turns)

### Analytics

- [ ] Voice session tracking (duration, tasks created, turns, TTS voice used)
- [ ] Error tracking (transcription failures, AI parse errors, TTS fallback rate)
- [ ] Engagement metrics (voice vs manual creation ratio, edit-after-voice rate)

## Sharing System V2 (Epic)

**Locked decisions (2026-02):**

- **Editing model:** Both users can edit shared tasks; last-write-wins conflict behavior.
- **Invite gating:** Require invite/connection acceptance for new contacts; existing accepted contacts can share immediately.
- **Voice latency:** Deterministic control intents stay local; semantic parsing stays in Edge Function.

- [x] Phase 1: UI and visibility (no schema break)
  - [x] Share method sheet: Docket first, larger/bolder with logo
  - [x] Sender-side "shared with" indicator on task rows
  - [x] SyncEngine: pull-on-reconnect
- [x] Phase 2: Invite/connection model (backend migrations)
  - [x] task_shares status lifecycle: pending, accepted, declined
  - [x] Recipient UPDATE policy for accept/decline
- [x] Phase 3: Invite UX + notifications center
  - [x] notifications table + RLS
  - [x] Bell badge + inbox UI
  - [x] Accept/decline in contacts
- [x] Phase 4: Realtime bilateral edits (LWW)
  - [x] Supabase Realtime subscriptions in SyncEngine
- [x] Phase 5: Documentation (TODO, PRD, WORKFLOW)
- [ ] Phase 6: QA — run verification matrix:
  - [ ] Owner shares to accepted contact → immediate collaboration
  - [ ] Owner shares to new contact → pending invite; recipient accept/decline
  - [ ] Both users edit same task → LWW converges on both devices
  - [ ] Push notification → opens correct destination; badge updates
  - [ ] Manual QA: owner/recipient × online/offline/reconnect

## v1.3: Task Progress System

- [ ] Data model: Add `progressPercentage`, `isProgressEnabled`, `lastProgressUpdate` to Task + TaskDTO
- [ ] Supabase migration: `012_add_progress_tracking.sql` (progress columns + shared task Realtime trigger)
- [ ] SyncEngine: Include progress fields in push/pull
- [ ] Profile: "Track progress by default" toggle in Tasks section
- [ ] AddTaskView / EditTaskView: Per-task progress toggle (after category, before checklist/title)
- [ ] ProgressRing: Circular indicator with color coding (grey 0-25, blue 26-99, green 100)
- [ ] ProgressBar: Separator bar fill with percentage text
- [ ] ProgressSlider: Expandable 0-100% slider (single tap to reveal)
- [ ] TaskRowView: Progress ring/bar when enabled; single tap → slider, double tap → complete
- [ ] Voice: TaskContext + TaskChanges include progress; Edge Function prompt for progress voice commands
- [ ] Voice: saveTasks() + update handler apply progressTrackingDefault and progressPercentage
- [ ] Shared tasks: Both users see and update progress; Realtime trigger propagates to recipient

## Future / v2.0

- [x] Voice-aware grocery lists
  - [x] Send user's store names + template item counts as context to Edge Function
  - [x] If grocery is the only ask -> "Do you have a specific store in mind?"
  - [x] If user names a store with a template -> "You have a Costco template with 12 items. Want me to use it?"
  - [x] If "yes" -> create task with checklist items from template (useTemplate field)
  - [x] If "just a few items" -> create task with checklist items from AI-suggested names (checklistItems field)
  - [x] ParsedTask extended with checklistItems and useTemplate fields
  - [x] saveTasks() handles both template loading and ad-hoc item creation
  - Foundation exists: GroceryStore templates, IngredientLibrary, checklist items all in SwiftData + Supabase
- [x] Voice task updates and deletion
  - [x] Send current task titles/IDs as context to Edge Function each call
  - [x] New response types: "update" (modify existing task) and "delete" (remove task)
  - [x] Support: "mark call mom as done", "move dentist to Thursday", "delete the client email"
  - [x] iOS side: match task by title/ID in SwiftData, apply changes or delete
  - [x] Context size: ~50 task titles fit easily in gpt-4.1-mini context window
  - [x] Edge Function updated with task awareness in system prompt
  - [x] TaskContext and TaskChanges models added
  - [x] Update/delete handlers implemented in VoiceRecordingView
- [ ] Widgets
- [ ] Apple Watch app
- [ ] Multiple languages for voice
- [ ] App Store submission (see APP-STORE-GUIDE.md)

## Technical Decisions Made

### Voice UX Learnings (Feb 2026)

- **Live transcription → committed message flicker:** SwiftUI treats views with different `.id()` values as completely separate elements. When the live bubble had `.id("live")` and the committed message got `.id("msg-5")`, SwiftUI would animate one out and one in — even though they had identical text. Fix: use a unified `displayMessages` computed property where the live text gets `id: "msg-\(messages.count)"` — the same ID it will have once committed. SwiftUI sees it as one continuous view.
- **SFSpeechRecognizer stale callbacks:** Calling `endAudio()` or `cancel()` on a recognition request triggers one final result callback on a background thread. That callback dispatches to MainActor and can overwrite `transcribedText` after the view already committed it to messages. Fix: `guard manager.isRecording else { return }` in the recognition handler — once stopped, all late callbacks are dropped.
- **`.animation(.repeatForever)` doesn't restart:** SwiftUI's value-based `.animation(.repeatForever, value:)` only reliably starts on the first value change. When state cycles `.listening` → `.speaking` → `.listening`, the repeat animation doesn't restart. Fix: use `phaseAnimator([false, true], trigger: state)` which restarts the cycle on every trigger change.
- **Audio level visualization:** Calculate RMS from each audio buffer on the IO thread (nonisolated), store in a class wrapper, poll with a MainActor task at ~12fps using exponential moving average (0.3 old + 0.7 new) for smooth visual feedback.
- **ScrollView auto-scroll:** Remove `withAnimation` from scroll onChange handlers — it animates the content insert/remove, not just the scroll. Use `DispatchQueue.main.async { scrollProxy.scrollTo("bottom") }` so the layout commits first.
- **GeometryReader for bottom-anchored chat:** Wrap ScrollView content in `.frame(minHeight: geometry.size.height, alignment: .bottom)` so messages anchor to the bottom when there are few messages (like iMessage), rather than floating at the top.
- **Latency split (client vs function):** Keep deterministic control intents on-device (dismiss/thanks/session-control) and reserve Edge Function calls for semantic task parsing (`question/complete/update/delete`) to avoid unnecessary round-trips.

### Personalization Methodology (v1.2)

- **Learn from corrections, not assumptions:** only learn when users explicitly edit AI output
- **Prioritize high-signal fields first:** title vocabulary, category mapping, store aliases, time habits
- **Keep context compact:** send top ranked mappings by recency/frequency, not full history
- **Ship behind guardrails:** opt-in controls, retention limits, reset button, and no raw audio storage
- **Measure quality with behavior:** success = fewer post-voice edits + faster confirmation, not just model confidence

### Voice Architecture (v1.1) — Updated 2026-02-08

- **Mode:** Conversational multi-turn (AI asks follow-ups when info is missing)
- **Transcription:** Apple SFSpeechRecognizer (on-device, free, fast) with optional Whisper API fallback (better accent accuracy)
- **Parsing:** gpt-4.1-mini via OpenRouter -> Supabase Edge Function
- **Conversation state:** messages[] array managed on iOS, Edge Function is stateless
- **Extraction:** Title, due date (with optional time), priority, category, notes, share target, recurrence (daily/weekly/monthly)
- **Confirmation:** TTS readback (AVSpeechSynthesizer, on-device) + auto-save if no "?" in summary
- **Continuation:** "Anything else?" after each task — user can chain multiple tasks in one session
- **Corrections:** Supported mid-conversation ("actually make it Wednesday") — user can correct after AI returns tasks
- **Sharing:** AI extracts share intent from speech, resolved via contacts cache
- **Language:** English only for v1.1
- **Model:** gpt-4.1-mini (fast, structured output, ~$0.001/turn) — NOT a thinking model
- **Orchestrator:** Not needed — conversation loop is ~15 lines of Swift, no LangChain/LangGraph
- **Dependencies:** Zero new installs (all Apple frameworks + Deno fetch)
- **Cost estimate:** ~$8/month @ 100 users (avg 3 turns per task) + ~$15/month for Whisper @ 100 users (5 tasks/day)
- **Edge Function auth:** verify_jwt disabled at gateway; function validates via getUser() (Swift SDK JWT format incompatible with gateway's strict check)
- **Silence detection:** Adaptive timeout — 2.2s baseline, 2.8s for ongoing dictation
- **Error handling:** Network checks, empty transcription detection, AI failure recovery with TTS feedback
- **Loading states:** Animated processing indicators, pulsing mic button
- **Haptics:** Light impact on start recording, success notification on task save, error notification on failures
- **Conversation timeout:** Auto-dismiss after 60s idle with TTS message
- **Swift 6:** See SWIFT6-CONCURRENCY-GUIDE.md for all concurrency fixes

### Cloud Architecture (v1.0)

- **Backend:** Supabase (PostgreSQL + Auth + Realtime)
- **Sync:** Bi-directional with offline queue
- **Auth:** Apple Sign In + email/password
- **Notifications:** Local notifications for due dates

## Research Completed

- [x] Voice-to-text options (Apple Speech vs Whisper)
- [x] Audio streaming architecture
- [x] WebSocket gateway patterns (for v1.1)
- [x] NLU approaches for task extraction
- [x] Supabase sync strategies
- See [VOICE-TO-TASK-PLAN.md](VOICE-TO-TASK-PLAN.md) for voice details

## Next Steps

1. Phase 11: Advanced subtasks (unlimited nesting, voice + manual — see Phase 11 above)
2. App Store submission (see APP-STORE-GUIDE.md)
3. See [VOICE-TO-TASK-V2.md](VOICE-TO-TASK-V2.md) for full architecture
