# Docket Voice-to-Task (V2T) Feature Plan

## Overview
Enable users to press a button and speak naturally to create tasks. The system transcribes voice, parses intent, and creates structured tasks with confirmation.

---

## Research Summary

### 1. Voice-to-Text Options

| Option | Pros | Cons | Cost | Latency |
|--------|------|------|------|---------|
| **Apple SpeechAnalyzer** (Recommended for MVP) | On-device, free, private, iOS 17+ native | Less accurate for complex commands | Free | Low |
| **OpenAI Whisper API** | High accuracy, handles noise well | Cloud-based, requires internet, API costs | ~$0.006/min | Medium |
| **OpenAI Realtime API** | Streaming support, voice-in-voice-out | Complex integration, higher cost | Higher | Low |

**Recommendation:** Start with Apple SpeechAnalyzer for MVP, add Whisper as fallback for v1.0

### 2. Audio Streaming Architecture

**iOS Side:**
- AVAudioEngine for microphone capture
- Audio buffers (1024-4096 samples per chunk)
- Real-time processing or chunked accumulation
- Format: PCM → AAC/Opus compression for network

**Gateway/Tunnel:**
- WebSocket (port 443, WSS secure)
- Alternative: SSE (Server-Sent Events) for one-way
- Keep-alive for persistent connection
- Reconnection logic for dropped connections

**Backend/Agent:**
- Audio accumulation buffer
- Voice Activity Detection (VAD) for segmenting
- Transcription → Natural Language Understanding (NLU) → Task extraction
- Function calling to create Task objects

### 3. Confirmation Flow (Critical)

User Experience:
```
1. User presses "🎤 Speak" button
2. Visual feedback: Listening... (waveform animation)
3. User speaks: "Remind me to call Mom tomorrow at 3pm, high priority"
4. System transcribes (shows text in real-time)
5. System parses: 
   - Title: "Call Mom"
   - Due: Tomorrow 3pm
   - Priority: High
6. System speaks: "Create task: Call Mom, tomorrow at 3pm, high priority?"
7. User confirms: "Yes" (or taps confirm button)
8. Task created, visual confirmation
```

### 4. Natural Language Parsing

**Entities to extract:**
- Task title/description
- Due date (absolute: "March 5th", relative: "tomorrow", "in 3 days")
- Due time (optional: "at 3pm", "morning", "evening")
- Priority (explicit: "high priority", implicit: "urgent", "ASAP")
- Category (optional: "work", "personal")

**Approaches:**
1. Regex/pattern matching (MVP - fast, limited)
2. LLM function calling (v1.0 - flexible, accurate)
3. Hybrid: Patterns for dates, LLM for complex parsing

---

## Implementation Phases

### Phase 5: Voice Foundation (v1.0-pre)

**5.1 Speech Recognition Setup**
- Add Speech framework entitlement
- Request microphone + speech recognition permissions
- Create SpeechRecognitionManager (ObservableObject)
- Test continuous recognition on device

**5.2 Audio Capture**
- Set up AVAudioEngine
- Configure audio session for recording
- Buffer management (accumulate 2-3 seconds of audio)
- Handle interruptions (calls, Siri)

**5.3 Basic Transcription**
- Integrate SpeechAnalyzer or SFSpeechRecognizer
- Real-time transcription display
- Stop/pause/cancel controls
- Error handling (no speech detected, network issues)

**5.4 Voice UI Components**
- Floating action button with mic icon
- Recording overlay (fullscreen or bottom sheet)
- Waveform visualization (optional but nice)
- Transcription preview text

### Phase 6: Agent Integration (v1.0)

**6.1 Gateway/Tunnel Setup**
- WebSocket client manager
- Secure connection (WSS)
- Reconnection logic
- Heartbeat/ping-pong

**6.2 Audio Streaming**
- Compress audio chunks (Opus or AAC)
- Stream to backend
- Buffer management on both ends

**6.3 NLU Agent**
- Backend service (can be same Supabase + edge functions)
- Whisper transcription (if using cloud)
- Intent classification: "create_task", "update_task", "query"
- Entity extraction for task fields

**6.4 Confirmation System**
- Parsed task preview card
- Voice confirmation (TTS: "Create task: X?")
- Visual confirmation buttons
- Yes/No/Cancel handling

**6.5 Task Creation Integration**
- Agent calls SwiftData createTask function
- Error handling (validation failures)
- Success feedback (visual + audio)

### Phase 7: Polish & Optimization (v1.0+)

**7.1 Voice Shortcuts**
- "Add [task]" quick command
- Siri Shortcuts integration
- Custom intents ("In Docket, add...")

**7.2 Offline Mode**
- Local speech recognition (Apple's on-device)
- Basic pattern matching when offline
- Queue for sync when back online

**7.3 Advanced Parsing**
- Recurring tasks: "every Monday"
- Subtasks: "remind me to buy milk and eggs"
- Context awareness: previous tasks, time of day

**7.4 Voice Feedback Loop**
- Full voice agent (speaks back confirmations)
- "You have 3 high priority tasks due today"
- Voice-based task review

---

## Technical Architecture

```
┌─────────────────┐
│   Docket iOS    │
│                 │
│ ┌─────────────┐ │
│ │ VoiceButton │ │
│ └──────┬──────┘ │
│        │        │
│ ┌──────▼──────┐ │
│ │ SpeechRec   │ │
│ │ Manager     │ │
│ └──────┬──────┘ │
│        │        │
│ ┌──────▼──────┐ │
│ │ AudioStream │ │
│ │ (WebSocket) │ │
│ └──────┬──────┘ │
└────────┼────────┘
         │
         │ WSS (TLS)
         │
┌────────▼────────┐
│   Supabase      │
│   Edge Function │
│                 │
│ ┌─────────────┐ │
│ │ Whisper API │ │
│ │ or Realtime │ │
│ └──────┬──────┘ │
│        │        │
│ ┌──────▼──────┐ │
│ │ NLU Agent   │ │
│ │ (GPT-4o)    │ │
│ └──────┬──────┘ │
│        │        │
│ ┌──────▼──────┐ │
│ │ Task        │ │
│ │ Validator   │ │
│ └──────┬──────┘ │
└────────┼────────┘
         │
         │ Response
         │
┌────────▼────────┐
│   Confirmation  │
│   UI + TTS      │
└─────────────────┘
```

---

## Security Considerations

1. **Audio Privacy**
   - On-device processing preferred for sensitive data
   - Clear user consent for cloud transcription
   - Auto-delete audio after transcription

2. **API Key Management**
   - Supabase edge functions hide OpenAI keys
   - Rate limiting per user
   - Usage tracking/quotas

3. **Transport Security**
   - WSS (WebSocket Secure) only
   - Certificate pinning (optional)
   - No audio storage on server

---

## Cost Estimates (v1.0)

| Component | Usage | Cost/Month (100 users, 10 min/day) |
|-----------|-------|-----------------------------------|
| Whisper API | 1000 min | ~$6 |
| GPT-4o (NLU) | 1000 calls | ~$5 |
| Supabase | Edge function invocations | ~$2 |
| **Total** | | **~$13/month** |

---

## Success Metrics

- Task creation success rate from voice (>90%)
- User confirmation rate (>80%)
- Average latency (transcription <3s, task creation <5s)
- User adoption (% of tasks created via voice)

---

## Open Questions

1. Do we want full voice agent (speaks back) or just visual confirmation?
2. Should we support multiple languages in v1.0?
3. Offline mode priority - wait for v1.5?
4. Use Apple's Speech first, or jump straight to Whisper?

---

*Documented for roadmap planning - 2026-02-06*
