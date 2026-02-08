# Voice-to-Task Feature - Documentation Summary

## What Was Researched & Documented

### 1. Research Completed

**Voice-to-Text Options:**
- Apple SpeechAnalyzer (iOS 17+, on-device, free, private) ← **Recommended for MVP**
- OpenAI Whisper API (cloud-based, high accuracy, ~$0.006/min)
- OpenAI Realtime API (streaming, higher cost)

**Audio Streaming Architecture:**
- AVAudioEngine for iOS microphone capture
- WebSocket (WSS port 443) for secure real-time streaming
- Audio buffer management (1024-4096 samples per chunk)
- Opus/AAC compression for network efficiency

**Gateway/Tunnel Patterns:**
- WebSocket with automatic reconnection
- TLS encryption required
- Supabase Edge Functions support WebSocket clients
- Keep-alive heartbeat to prevent timeouts

**Natural Language Understanding:**
- LLM function calling (GPT-4o-mini) for task extraction
- Extract: title, due date, time, priority, category
- Alternative: Pattern matching for MVP (faster, less accurate)

### 2. New Documentation Created

**VOICE-TO-TASK-PLAN.md** (6,945 bytes)
- Complete feature architecture
- 3-phase implementation roadmap (Phases 5-7)
- Technical architecture diagram
- Cost estimates (~$13/month for 100 users)
- Security considerations
- Success metrics

**Key Phases:**
- **Phase 5: Voice Foundation** (Speech setup, audio capture, basic transcription)
- **Phase 6: Agent Integration** (WebSocket gateway, NLU, confirmation system)
- **Phase 7: Polish & Optimization** (Siri shortcuts, offline mode, advanced parsing)

### 3. Updated Documentation

| File | Changes |
|------|---------|
| **DEVELOPMENT.md** | Added Phases 5-7 to module roadmap, updated Current Status |
| **TODO.md** | Marked MVP complete, added v1.0 V2T roadmap |
| **ADR.md** | Added ADR-005 (V2T Architecture), ADR-006 (Audio Gateway), ADR-007 (NLU) |
| **TECH-STACK.md** | Added Voice-to-Task section with all components |
| **PRD.md** | Moved Natural Language Input to v1.0, made V2T primary feature |
| **MODULE-LOG.md** | Status: COMPLETE |

### 4. Key Decisions Documented

**ADR-005:** Apple SpeechAnalyzer for transcription (privacy-first, no API costs)
**ADR-006:** HTTPS POST (not WebSocket) for text-to-AI parsing
**ADR-007:** LLM structured output for task extraction (not function calling)

### 5. Key Decisions (Updated 2026-02-08)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **TTS readback** | Yes — AVSpeechSynthesizer | On-device, free, natural readback of AI summary |
| **Notes extraction** | Yes — AI prompt field | Extracts contextual details from speech into `notes` |
| **Voice sharing** | Yes — AI extracts `shareWith` | Resolved via contacts cache → `task_shares` table |
| **Model** | gpt-4.1-mini via OpenRouter | Fast (<500ms), cheap (~$0.001/task), great structured output |
| **Thinking model** | No | Task parsing is pattern extraction, not reasoning |
| **Orchestrator** | No (no LangChain/LangGraph) | Single-shot API call, not a multi-step agent |
| **Dependencies** | Zero new installs | All Apple frameworks + Deno fetch |

### 6. Cost & Resource Planning (Updated)

| Component | Monthly Cost (100 users) |
|-----------|--------------------------|
| Apple Speech (transcription) | Free (on-device) |
| AVSpeechSynthesizer (TTS) | Free (on-device) |
| OpenRouter (gpt-4.1-mini) | ~$3 |
| Supabase Edge Functions | Free tier |
| **Total** | **~$3/month** |

### 7. Confirmation Flow Design (Updated)

```
User → Press mic → Speak naturally (include notes, sharing intent) →
See transcription → AI parses (title, date, priority, category, notes, share) →
TTS reads back summary → Preview card shows (editable) →
User confirms (voice "yes" or tap "Add All") →
Task(s) created + shares resolved → Success feedback
```

### 8. Architecture Overview (Updated)

```
[iOS App]
  ↓ Mic capture (AVAudioEngine)
  ↓ SFSpeechRecognizer (on-device transcription)
  ↓ HTTPS POST to Supabase
[Supabase Edge Function]
  ↓ gpt-4.1-mini via OpenRouter
  ↓ Full task extraction (title, date, priority, category, notes, shareWith)
  ↓ AI-generated summary for TTS
  ↓ JSON response
[iOS App]
  ↓ TTS readback (AVSpeechSynthesizer)
  ↓ Display preview (TaskConfirmationView)
  ↓ User confirms
  ↓ Create SwiftData task(s)
  ↓ Resolve shares (name → email → task_shares)
  ↓ Sync to Supabase
```

### 9. What's NOT Needed

| Technology | Why Not |
|-----------|---------|
| **Thinking models (o1, o3, R1)** | Adds 3-5s latency for zero accuracy gain on pattern extraction |
| **LangChain / LangGraph** | Single API call, no chains/tools/loops/memory |
| **Whisper API** | Apple Speech is free and on-device; Whisper is a fallback |
| **WebSocket** | HTTPS POST is sufficient — text, not audio streaming |
| **New Swift packages** | Speech, AVFoundation, AVSpeechSynthesizer all built into iOS |

---

## Next Steps

1. Begin Phase 6: Voice Foundation (speech capture)
2. Set up OpenRouter account + API key
3. See [VOICE-TO-TASK-V2.md](VOICE-TO-TASK-V2.md) for full architecture and prompt design

---

## All Changes Pushed to GitHub

**Commit:** `b213b78` - "Add Voice-to-Task (V2T) feature plan and update all documentation"

Files modified:
- VOICE-TO-TASK-PLAN.md (created)
- DEVELOPMENT.md (updated)
- TODO.md (updated)
- ADR.md (updated)
- TECH-STACK.md (updated)
- PRD.md (updated)
- MODULE-LOG.md (updated)

---

*Documented for roadmap planning - 2026-02-06*
