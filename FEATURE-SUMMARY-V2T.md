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

**ADR-005:** Apple SpeechAnalyzer for MVP (privacy-first, no API costs)
**ADR-006:** WebSocket (WSS) for real-time audio streaming
**ADR-007:** LLM function calling for natural language parsing

### 5. Cost & Resource Planning

| Component | Monthly Cost (100 users, 10 min/day) |
|-----------|--------------------------------------|
| Whisper API | ~$6 |
| GPT-4o (NLU) | ~$5 |
| Supabase Edge Functions | ~$2 |
| **Total** | **~$13/month** |

### 6. Confirmation Flow Design

```
User → Press 🎤 Button → Speak → See transcription →
Agent parses → Preview card shows → TTS confirms →
User confirms (voice or tap) → Task created → Success feedback
```

### 7. Open Questions for Review

1. Full voice agent (speaks back) or just visual confirmation?
2. Multiple languages in v1.0 or start with English only?
3. Offline mode priority - wait for v1.5?
4. Apple Speech first, or jump straight to Whisper?

### 8. Architecture Overview

```
[iOS App]
  ↓ Mic capture (AVAudioEngine)
  ↓ Audio buffers
  ↓ WebSocket (WSS)
[Supabase Edge Function]
  ↓ Whisper transcription
  ↓ GPT-4o NLU parsing
  ↓ Task entity extraction
  ↓ Confirmation response
[iOS App]
  ↓ Display preview
  ↓ TTS confirmation (optional)
  ↓ User confirms
  ↓ Create SwiftData task
```

---

## Next Steps (For Later Review)

1. **Review VOICE-TO-TASK-PLAN.md** in detail
2. **Answer open questions** (confirmation style, languages, offline priority)
3. **Decide on V2T approach**: Apple Speech vs Whisper vs Hybrid
4. **Prioritize v1.0 features**: Voice first or cloud sync first?
5. **Estimate timeline**: Phases 5-7 complexity
6. **When ready**: Begin Phase 5.1 (Speech Recognition Setup)

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
