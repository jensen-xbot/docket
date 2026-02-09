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

### Phase 6: Speech Capture + TTS Foundation - COMPLETE
- [x] Add Speech framework entitlement
- [x] Add `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` to Info.plist
- [x] Create SpeechRecognitionManager (SFSpeechRecognizer + AVAudioEngine)
- [x] Create TTSManager (AVSpeechSynthesizer with completion callback)
- [x] Implement AVAudioSession switching (`.playAndRecord` + `.defaultToSpeaker`)
- [x] Handle audio session interruptions (`AVAudioSession.interruptionNotification`)
- [x] Build VoiceRecordingView (mic button + conversation overlay)
- [x] Fix Swift 6 dispatch_assert_queue crashes (nonisolated static helpers, async APIs)
- [x] Silence detection with adaptive timeout (2.5s short / 3.5s long utterances)
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

### Phase 8: Confirmation + Continuation - MOSTLY COMPLETE
- [x] Wire up: conversation complete -> auto-save if no "?" in summary
- [x] Voice confirmation: listen for "yes" / "add it" after AI asks "Want me to add?"
- [x] "Anything else?" flow: after saving, ask if user wants to add more tasks
- [x] Dismissal detection: "no" / "that's all" / "I'm done" closes voice view
- [x] Integrate voice-created tasks into synced model (SwiftData + SyncEngine push)
- [ ] Build TaskConfirmationView polish (notes + share target display, inline editing)
- [ ] Share resolution flow (name -> email via contacts cache or inline prompt)
- [x] Handle corrections mid-conversation ("actually make it Wednesday")
  - [x] Pre-save corrections: say correction before confirmation → AI returns updated tasks
  - [x] Post-save corrections: say correction after "Anything else?" → updates existing task in SwiftData + Supabase
  - [x] Word boundary matching for yes/no/dismiss detection (prevents "note" matching "no")
- [x] TTS mute toggle in Settings

### Phase 9: Voice Polish — MOSTLY COMPLETE
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
- [ ] Siri Shortcuts integration
- [ ] Advanced parsing (recurring tasks, subtasks)

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

### Voice Architecture (v1.1) — Updated 2026-02-08
- **Mode:** Conversational multi-turn (AI asks follow-ups when info is missing)
- **Transcription:** Apple SFSpeechRecognizer (on-device, free, fast) with optional Whisper API fallback (better accent accuracy)
- **Parsing:** gpt-4.1-mini via OpenRouter -> Supabase Edge Function
- **Conversation state:** messages[] array managed on iOS, Edge Function is stateless
- **Extraction:** Title, due date (with optional time), priority, category, notes, share target
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
- **Silence detection:** Adaptive timeout — 2.5s for short responses, 3.5s for ongoing dictation
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
1. Polish TaskConfirmationView (inline editing, share targets)
2. Share resolution (voice "share with Sarah" -> contacts lookup)
3. Siri Shortcuts integration
4. Advanced parsing (recurring tasks, subtasks)
5. App Store submission (see APP-STORE-GUIDE.md)
6. See [VOICE-TO-TASK-V2.md](VOICE-TO-TASK-V2.md) for full architecture
