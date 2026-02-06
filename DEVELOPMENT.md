# Docket Development Framework

## Workflow (The Loop)

```
1. REVIEW → Check documentation, current state, previous work
2. PLAN  → Define next module, acceptance criteria, edge cases  
3. CODE  → Write implementation following .cursorrules
4. PUSH  → Commit to GitHub with clear message
5. CHECK → CI validation (if available) or self-review
6. NOTIFY → Inform user module is ready for testing
7. TEST  → User builds, tests on device/simulator
8. FEEDBACK → User reports: [PASS / FIX / CHANGE]
9. ITERATE → If FIX/CHANGE: modify, push, notify again
10. ADVANCE → If PASS: move to next module
```

## Communication Protocol

**When I notify you:**
- Module name and description
- Files changed/created
- What to test specifically
- Expected behavior
- Known limitations (if any)

**When you respond:**
- [PASS] → Move to next module
- [FIX] → Describe issue, include error message or screenshot
- [CHANGE] → Describe desired change, reference acceptance criteria if different

## Module Structure

Each module has:
- **Prerequisites:** What must be complete before starting
- **Acceptance Criteria:** How we know it's done
- **Test Checklist:** Specific things to verify
- **Est. Complexity:** Low / Medium / High

---

## Module Roadmap

### Phase 1: Foundation
| # | Module | Description | Complexity | Prerequisites |
|---|--------|-------------|------------|---------------|
| 1.1 | **Project Setup** | Xcode project, folder structure, gitignore | Low | None |
| 1.2 | **Data Model** | Task model with SwiftData, Priority enum | Low | 1.1 |
| 1.3 | **Color System** | Priority colors, due date colors, theme support | Low | 1.2 |
| 1.4 | **Date Utilities** | Due date formatting, relative dates, color logic | Low | 1.3 |

### Phase 2: Core UI
| # | Module | Description | Complexity | Prerequisites |
|---|--------|-------------|------------|---------------|
| 2.1 | **Task Row** | Individual task cell with complete toggle | Medium | 1.4 |
| 2.2 | **Task List** | Main list view with filtering (All/Active/Completed) | Medium | 2.1 |
| 2.3 | **Add Task** | Sheet for creating new tasks with title/priority/due | Medium | 2.2 |
| 2.4 | **Edit Task** | Sheet for editing existing tasks | Low | 2.3 |

### Phase 3: Polish
| # | Module | Description | Complexity | Prerequisites |
|---|--------|-------------|------------|---------------|
| 3.1 | **Animations** | Add/delete animations, transitions | Medium | 2.4 |
| 3.2 | **Empty States** | Friendly empty list UI | Low | 2.4 |
| 3.3 | **Swipe Actions** | Delete, quick complete gestures | Medium | 2.4 |
| 3.4 | **Search/Filter** | Search tasks, filter by category/priority | Medium | 2.4 |

### Phase 4: Device Testing
| # | Module | Description | Complexity | Prerequisites |
|---|--------|-------------|------------|---------------|
| 4.1 | **Dark Mode** | Verify all screens in dark/light | Low | 3.x |
| 4.2 | **Accessibility** | Dynamic type, VoiceOver, large text | Medium | 3.x |
| 4.3 | **Device Testing** | Physical device, different sizes | Medium | 4.2 |

---

## Current Status

**Phase:** 4 - Device Testing  
**Next Module:** 4.3 - Device Testing  
**Status:** MVP Complete (Phases 1-4), awaiting user testing

### Post-MVP Roadmap: Voice-to-Task (v1.0)

See [VOICE-TO-TASK-PLAN.md](VOICE-TO-TASK-PLAN.md) for detailed architecture.

### Phase 5: Voice Foundation (v1.0-pre)
| # | Module | Description | Complexity | Prerequisites |
|---|--------|-------------|------------|---------------|
| 5.1 | **Speech Recognition Setup** | Speech framework, permissions, SpeechRecognitionManager | High | 4.3 |
| 5.2 | **Audio Capture** | AVAudioEngine, buffer management, interruptions | High | 5.1 |
| 5.3 | **Basic Transcription** | Real-time transcription display, controls | High | 5.2 |
| 5.4 | **Voice UI Components** | Mic button, recording overlay, waveform | Medium | 5.3 |

### Phase 6: Agent Integration (v1.0)
| # | Module | Description | Complexity | Prerequisites |
|---|--------|-------------|------------|---------------|
| 6.1 | **Gateway/Tunnel Setup** | WebSocket client, secure connection, reconnection | High | 5.4 |
| 6.2 | **Audio Streaming** | Compress chunks, stream to backend, buffer management | High | 6.1 |
| 6.3 | **NLU Agent** | Backend intent classification, entity extraction | High | 6.2 |
| 6.4 | **Confirmation System** | Parsed task preview, TTS confirmation, Yes/No handling | High | 6.3 |
| 6.5 | **Task Creation Integration** | Agent creates SwiftData tasks, error handling | Medium | 6.4 |

### Phase 7: Polish & Optimization (v1.0+)
| # | Module | Description | Complexity | Prerequisites |
|---|--------|-------------|------------|---------------|
| 7.1 | **Voice Shortcuts** | Siri integration, custom intents | Medium | 6.5 |
| 7.2 | **Offline Mode** | On-device recognition, local parsing | High | 7.1 |
| 7.3 | **Advanced Parsing** | Recurring tasks, subtasks, context | High | 7.2 |
| 7.4 | **Voice Feedback Loop** | Full voice agent, task review by voice | Medium | 7.3 |

## Documentation Review

✅ PRD.md - Product requirements defined
✅ ADR.md - Architecture decisions documented  
✅ TECH-STACK.md - Tech choices confirmed
✅ TODO.md - High-level tasks listed
✅ QUESTIONNAIRE.md - Discovery complete
✅ .cursorrules - Coding standards defined
✅ README.md - Project overview complete

**Decision:** Stay with Supabase for consistency with Closelo
**Decision:** SwiftData for MVP, migrate to Supabase for v1.0

---

## Ready to Start Module 1.1?

**Module 1.1: Project Setup**
- Create Xcode project (SwiftUI, iOS 17+, SwiftData)
- Set up folder structure (Models, Views, ViewModels, Utilities)
- Configure gitignore for Xcode
- Create initial DocketApp.swift with SwiftData container

**Acceptance Criteria:**
- [ ] Project opens in Xcode without errors
- [ ] Builds successfully
- [ ] Runs in simulator
- [ ] Folder structure matches .cursorrules
- [ ] SwiftData container initializes

**Reply with:** [START 1.1] to begin