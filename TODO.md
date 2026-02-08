# TODO: Docket

## MVP (Phases 1-4) - ✅ COMPLETE
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
- [ ] Test on physical device (AWAITING USER)

## v1.0: Cloud Sync Foundation - ✅ COMPLETE

### Phase 5: Cloud Infrastructure
- [x] Set up Supabase project
- [x] Create database schema (Tasks table)
- [x] Configure Row Level Security (RLS) policies
- [x] Implement Supabase Auth (email + Apple Sign In)
- [x] Create sync service (SwiftData ↔ Supabase)
- [x] Handle offline queue and conflict resolution
  - [x] NetworkMonitor (NWPathMonitor) for connectivity detection
  - [x] Network guards on all push/pull methods (offline → .pending, not .failed)
  - [x] Automatic retry with exponential backoff (2s, 8s, 30s) for failed items
  - [x] Auto-flush pending queue on network reconnect
  - [x] Conflict logging when remote overwrites local pending changes
  - [x] Offline/pending UI indicators in TaskListView
- [x] Add due dates with local notifications
- [x] SyncEngine lifecycle refactor (single instance via environment, foreground sync)
- [ ] Test sync across multiple devices (AWAITING USER)

## v1.1: Conversational Voice-to-Task

### Phase 6: Speech Capture + TTS Foundation
- [ ] Add Speech framework entitlement
- [ ] Add `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` to Info.plist
- [ ] Create SpeechRecognitionManager (SFSpeechRecognizer + AVAudioEngine)
- [ ] Create TTSManager (AVSpeechSynthesizer with completion callback)
- [ ] Implement AVAudioSession switching (`.playAndRecord` + `.defaultToSpeaker`)
- [ ] Handle audio session interruptions (`AVAudioSession.interruptionNotification`)
- [ ] Build VoiceRecordingView (mic button + conversation overlay)
- [ ] Test on device: speak → transcription → TTS readback → mic restarts

### Phase 7: Conversational AI Parsing
- [ ] Set up OpenRouter account + API key
- [ ] Supabase Edge Function `parse-voice-tasks` (conversational system prompt, gpt-4.1-mini)
- [ ] Edge Function receives `messages[]` array (not single text)
- [ ] Edge Function returns `{ type: "question"|"complete", ... }`
- [ ] Build VoiceTaskParser (sends messages[], handles question/complete responses)
- [ ] Build ParsedTask, ConversationMessage, ParseResponse models
- [ ] Implement conversation loop on iOS (messages array + if/else on response type)
- [ ] Test multi-turn: partial info → AI asks → user responds → task created
- [ ] Test power-user: full utterance → instant task creation (no follow-ups)
- [ ] English only for v1.1

### Phase 8: Confirmation UI + Sharing
- [ ] Build TaskConfirmationView (notes + share target display, inline editing)
- [ ] Wire up: conversation complete → preview card(s) → confirm → save to SwiftData
- [ ] Share resolution flow (name → email via contacts cache or inline prompt)
- [ ] Handle corrections mid-conversation ("actually make it Wednesday")
- [ ] Voice confirmation: listen for "yes" / "add it" / "sounds good" after summary
- [ ] Integrate voice-created tasks into synced model
- [ ] TTS mute toggle in Settings

### Phase 9: Voice Polish
- [ ] Error handling (no speech, network down, AI failure, unknown share recipient)
- [ ] Loading states and progress indicators (pulsing mic, "thinking" state)
- [ ] Haptic feedback (start recording, task created, error)
- [ ] Edge cases (empty input, very long dictation, conversation timeout)
- [ ] Siri Shortcuts integration
- [ ] Advanced parsing (recurring tasks, subtasks)
- [ ] Optional: Whisper API fallback for accuracy

**Why second:** Built on cloud foundation, uses same Supabase backend.
**No new dependencies:** Apple Speech, AVFoundation, AVSpeechSynthesizer built into iOS. Edge Function uses native Deno fetch().
**No orchestrator needed:** Conversation state is a messages array on iOS. Edge Function is stateless. No LangChain/LangGraph.

## Future / v2.0
- [ ] Widgets
- [ ] Apple Watch app
- [ ] Multiple languages for voice
- [ ] App Store submission (see APP-STORE-GUIDE.md)

## Technical Decisions Made

### Voice Architecture (v1.1) — Updated 2026-02-08
- **Mode:** Conversational multi-turn (AI asks follow-ups when info is missing)
- **Transcription:** Apple SFSpeechRecognizer (on-device, free, fast)
- **Parsing:** gpt-4.1-mini via OpenRouter → Supabase Edge Function
- **Conversation state:** messages[] array managed on iOS, Edge Function is stateless
- **Extraction:** Title, due date, priority, category, notes, share target
- **Confirmation:** TTS readback (AVSpeechSynthesizer, on-device) + visual preview
- **Corrections:** Supported mid-conversation ("actually make it Wednesday")
- **Sharing:** AI extracts share intent from speech, resolved via contacts cache
- **Language:** English only for v1.1
- **Model:** gpt-4.1-mini (fast, structured output, ~$0.001/turn) — NOT a thinking model
- **Orchestrator:** Not needed — conversation loop is ~15 lines of Swift, no LangChain/LangGraph
- **Dependencies:** Zero new installs (all Apple frameworks + Deno fetch)
- **Cost estimate:** ~$8/month @ 100 users (avg 3 turns per task)

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
1. User tests on physical device
2. Test sync across multiple devices
3. Begin Phase 6: Voice Foundation (speech capture)
4. Set up OpenRouter account + API key for Phase 7
5. See [VOICE-TO-TASK-V2.md](VOICE-TO-TASK-V2.md) for full architecture
