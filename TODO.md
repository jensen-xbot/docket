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
- [ ] Test on physical device (AWAITING USER)

## v1.0: Voice-to-Task (Phases 5-7)

### Phase 5: Voice Foundation
- [ ] Add Speech framework entitlement
- [ ] Request microphone + speech permissions
- [ ] Create SpeechRecognitionManager
- [ ] Set up AVAudioEngine for capture
- [ ] Implement audio buffer management
- [ ] Build continuous transcription display
- [ ] Create Voice UI (mic button, overlay)

### Phase 6: Agent Integration
- [ ] Design WebSocket gateway architecture
- [ ] Implement secure WebSocket client
- [ ] Audio compression (Opus/AAC)
- [ ] Set up backend NLU service
- [ ] Natural language → Task parsing
- [ ] Build confirmation flow (visual + TTS)
- [ ] Integrate task creation with agent

### Phase 7: Polish & Advanced Features
- [ ] Siri Shortcuts integration
- [ ] Offline mode (on-device recognition)
- [ ] Advanced parsing (recurring, subtasks)
- [ ] Full voice agent feedback loop

## Future / v2.0
- [ ] Set up Supabase project
- [ ] Implement Supabase Auth
- [ ] Add cloud sync (Supabase real-time)
- [ ] Push notifications for due dates
- [ ] Data migration from local to cloud
- [ ] App Store submission

## Research Completed
- [x] Voice-to-text options (Apple Speech vs Whisper)
- [x] Audio streaming architecture
- [x] WebSocket gateway patterns
- [x] NLU approaches for task extraction
- See [VOICE-TO-TASK-PLAN.md](VOICE-TO-TASK-PLAN.md) for details

## Next Steps
1. User tests MVP in Xcode
2. Review Voice-to-Task plan
3. Prioritize v1.0 features
4. Decide: Apple Speech vs Whisper API
