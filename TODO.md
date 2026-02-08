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

## v1.0: Cloud Sync Foundation (Priority #1)

### Phase 5: Cloud Infrastructure
- [ ] Set up Supabase project
- [ ] Create database schema (Tasks table)
- [ ] Configure Row Level Security (RLS) policies
- [ ] Implement Supabase Auth (email + Apple Sign In)
- [ ] Create sync service (SwiftData ↔ Supabase)
- [ ] Handle offline queue and conflict resolution
- [ ] Add due dates with local notifications
- [ ] Test sync across multiple devices

**Why first:** Foundation must be solid before building voice features on top.

## v1.1: Voice-to-Task (Priority #2)

### Phase 6: Voice Foundation
- [ ] Add Speech framework entitlement
- [ ] Request microphone + speech permissions
- [ ] Create SpeechRecognitionManager (Apple SpeechAnalyzer)
- [ ] Set up AVAudioEngine for capture
- [ ] Implement audio buffer management
- [ ] Build continuous transcription display
- [ ] Create Voice UI (mic button, overlay)

### Phase 7: Agent Integration
- [ ] Supabase Edge Function for NLU (GPT-4o-mini)
- [ ] Natural language → Task parsing
- [ ] Build visual confirmation flow (NOT TTS)
- [ ] Integrate voice-created tasks into synced model
- [ ] English only for v1.1

### Phase 8: Voice Polish
- [ ] Siri Shortcuts integration
- [ ] Advanced parsing (recurring tasks, subtasks)
- [ ] Optional: Whisper API fallback for accuracy
- [ ] Optional: TTS confirmation responses (v1.2)

**Why second:** Built on cloud foundation, uses same Supabase backend.

## Future / v2.0
- [ ] Widgets
- [ ] Apple Watch app
- [ ] Multiple languages for voice
- [ ] App Store submission (see APP-STORE-GUIDE.md)

## Technical Decisions Made

### Voice Architecture (v1.1)
- **Transcription:** Apple SpeechAnalyzer (on-device, free, fast)
- **Parsing:** GPT-4o-mini via Supabase Edge Function (~$5/month)
- **Confirmation:** Visual only (not TTS agent)
- **Language:** English only for v1.1
- **Cost estimate:** ~$5/month @ 100 users (vs $13 with Whisper)

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
1. User tests MVP in Xcode
2. Begin Phase 5.1: Supabase Setup (when ready)
3. Complete cloud sync before starting voice work
