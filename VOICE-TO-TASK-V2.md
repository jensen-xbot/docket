# Voice-to-Task V2 Architecture Plan

## Overview

Docket's voice assistant is a **conversational AI** — users speak naturally and the assistant talks back, asks for missing details, and confirms before saving. It adapts to how much context the user provides: say everything at once and it creates the task immediately; say just a title and it asks follow-up questions.

The system transcribes speech on-device (Apple SFSpeechRecognizer), sends conversation history to a cloud AI (gpt-4.1-mini via Supabase Edge Function), and receives either a follow-up question or completed task(s). TTS (AVSpeechSynthesizer) reads responses aloud so the user can interact hands-free.

---

## User Experience Flow

### Conversational Flow (partial info → AI asks follow-ups)
```
1. Tap mic button
2. User:  "Add a task"
3. AI:    "Sure, what do you need to do?" (TTS + text bubble)
4. User:  "Call Mom"
5. AI:    "When is it due?" (TTS + text bubble)
6. User:  "Tomorrow"
7. AI:    "Any notes or want to share it with someone?" (TTS + text bubble)
8. User:  "Yeah, note she wants to talk about the trip. Share with Sarah."
9. AI:    "Call Mom, tomorrow, high priority. Note: weekend trip.
          Sharing with Sarah. Want me to add it?" (TTS + preview card)
10. User: "Yes" (voice or tap)
11. Task saved + share created
```

### Power User Flow (everything at once → instant creation)
```
1. Tap mic button
2. User:  "Call Mom tomorrow, it's important, note that she wants to
          talk about the weekend trip, and share it with Sarah"
3. AI:    "Call Mom, tomorrow, high priority. Noted: weekend trip.
          Sharing with Sarah. Adding it now." (TTS + preview card)
4. User:  "Sounds good" (voice or tap)
5. Task saved + share created
```

### Batch Dictation
```
1. Tap mic button
2. User:  "I need to email the client by Friday, pick up groceries
          after work, and schedule a dentist appointment next week"
3. AI:    "3 tasks: Email client by Friday, groceries today, and
          dentist next week. Want me to add all three?" (TTS + preview list)
4. User:  "Add all" (voice or tap)
5. All tasks saved
```

### Correction Flow
```
1. (After AI reads back a task summary)
2. User:  "Actually make it Wednesday, not tomorrow"
3. AI:    "Updated — Call Mom on Wednesday. Anything else?"
4. User:  "No, add it"
5. Task saved with corrected date
```

### Key UX Principles
- **Adaptive:** If the user gives everything, skip questions. If partial, ask one question at a time.
- **Brief responses:** AI speaks 1-2 sentences max per turn (it's read aloud — long responses are annoying).
- **Mic auto-restarts:** After TTS finishes speaking, the mic re-activates automatically so the user can respond hands-free.
- **Visual + audio:** Every AI response appears as text AND is spoken via TTS. User can mute TTS in Settings.

---

## Technical Architecture

```
┌─────────────────────────────────────────────┐
│              Docket iOS App                  │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │        Conversation Loop              │  │
│  │                                       │  │
│  │  ┌─────────────┐  ┌───────────────┐  │  │
│  │  │ Mic Button  │  │ messages[]    │  │  │
│  │  │ Voice UI    │  │ (state)       │  │  │
│  │  └──────┬──────┘  └───────────────┘  │  │
│  │         │                             │  │
│  │  ┌──────▼──────────────────────────┐  │  │
│  │  │ SFSpeechRecognizer (on-device)  │  │  │
│  │  │ → transcribes user speech       │  │  │
│  │  └──────┬──────────────────────────┘  │  │
│  │         │ user text                   │  │
│  │         │ appended to messages[]      │  │
│  │  ┌──────▼──────────────────────────┐  │  │
│  │  │ Supabase Client (HTTPS POST)    │  │  │
│  │  │ sends full messages[] + context │  │  │
│  │  └──────┬──────────────────────────┘  │  │
│  └─────────┼─────────────────────────────┘  │
└────────────┼────────────────────────────────┘
             │ HTTPS
             │
┌────────────▼────────────────────────────────┐
│      Supabase Edge Function                  │
│      "parse-voice-tasks"                     │
│                                              │
│  Receives: { messages[], today, timezone }   │
│  Forwards to OpenRouter (gpt-4.1-mini)       │
│  Returns one of:                             │
│    → { type: "question", text: "..." }       │
│    → { type: "complete", tasks: [...],       │
│        summary: "..." }                      │
└────────────┬────────────────────────────────┘
             │ JSON response
             │
┌────────────▼────────────────────────────────┐
│              Docket iOS App                  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ if type == "question":                 │  │
│  │   → TTS speaks the question            │  │
│  │   → Text bubble shown in Voice UI      │  │
│  │   → Append to messages[]               │  │
│  │   → Mic auto-restarts after TTS done   │  │
│  │   → LOOP BACK (user speaks again)      │  │
│  │                                        │  │
│  │ if type == "complete":                 │  │
│  │   → TTS speaks the summary             │  │
│  │   → TaskConfirmationView shown         │  │
│  │   → User confirms (voice or tap)       │  │
│  │   → Save to SwiftData → sync           │  │
│  │   → Resolve shares if needed           │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

### Conversation Loop (pseudocode)
```swift
var messages: [(role: String, content: String)] = []

func handleUserUtterance(_ text: String) async {
    messages.append(("user", text))
    
    let response = await voiceTaskParser.send(messages: messages)
    
    if response.type == "complete" {
        // Done — TTS reads summary, show confirmation
        ttsManager.speak(response.summary)
        showConfirmation(response.tasks)
    } else {
        // AI needs more info — speak question, listen again
        messages.append(("assistant", response.text))
        ttsManager.speak(response.text) {
            // After TTS finishes, re-activate mic
            speechManager.startRecording()
        }
    }
}
```

---

## Why This Architecture

### Speech: Apple SFSpeechRecognizer (on-device)
- Free, no API costs
- Private (audio never leaves device)
- Real-time transcription
- Works offline for transcription
- iOS 17+ has improved accuracy

### AI Parsing: OpenRouter via Supabase Edge Function
- **API key stays on the server** (never in the app binary)
- OpenRouter gives access to multiple models with one API key
- Can switch models without app update
- Supabase Edge Functions are free tier compatible
- Rate limiting and usage tracking built in

### Model Recommendation (Updated Feb 2026)

For task parsing (structured extraction from natural language), the model must be:
- **Fast** (< 1 second response) — users expect instant results after speaking
- **Structured output** reliable (JSON schema adherence)
- **Cheap** (pennies per call)

❌ **Avoid "Thinking" models** (o1, o3, DeepSeek-R1): They're 3-10x slower, more expensive, and overkill. Task parsing is pattern extraction, not complex reasoning. A thinking model "reasoning" about whether "tomorrow" means tomorrow adds latency with zero benefit.

✅ **Recommended Models:**

| Model | Speed | Cost (per 1M tokens) | Best For |
|-------|-------|---------------------|----------|
| **gpt-4.1-mini** ⭐ | Very fast | ~$0.10 in / $0.40 out | **Primary choice** — best structured output, successor to 4o-mini |
| **gpt-4.1-nano** | Ultra fast | ~$0.03 in / $0.10 out | **Budget/fastest** — may be sufficient for simple extraction |
| **llama-3.3-70b (Groq)** | Ultra fast | ~$0.05 in / $0.10 out | **Open-source alternative** — great for simple parsing |
| **claude-3.5-haiku** | Fast | ~$0.25 in / $1.25 out | If OpenAI unavailable |

| Avoid These | Speed | Cost | Why Not |
|-------------|-------|------|---------|
| **o1 / o3** | Slow (3-10s) | ~$15+ out | ❌ Massive overkill, adds seconds of latency |
| **deepseek-r1** | Slow (3-5s) | ~$0.55 in / $2.19 out | ❌ Overkill, "thinks" before responding |
| **gpt-4.1 (full)** | Fast | ~$2 in / $8 out | ❌ Works but 20x more expensive for same quality |

**Primary Recommendation: `openai/gpt-4.1-mini` via OpenRouter**
- Successor to gpt-4o-mini with better instruction following
- Lightning fast (<500ms)
- Native JSON/structured output mode
- Reliable schema adherence (handles notes extraction + sharing intent well)
- ~$0.001 per task extracted

**Budget Alternative: `openai/gpt-4.1-nano` via OpenRouter**
- Even faster and cheaper
- Good for simple single-task extraction
- May struggle with complex multi-task + notes + sharing in one utterance
- Worth testing — if accuracy is sufficient, saves ~70% over mini

**Why not thinking models?** Task parsing is pattern matching:
1. Extract entities (title, date, priority) from natural language — no "reasoning" needed
2. Map relative dates ("tomorrow", "next Friday") to ISO dates — simple calculation
3. Infer category from keywords — pattern matching, not logic
4. Extract notes vs. task content — sentence classification

A thinking model would spend 3-5 seconds "reasoning" and arrive at the same answer. Users don't want to wait after speaking.

**Why not a full orchestrator (LangChain/LangGraph)?**
Even with conversational multi-turn, the architecture is simple:
```
messages[] in → one chat completion call → question or tasks out → loop
```
The "orchestrator" is a ~15-line conversation loop on the iOS side (see pseudocode above). The Edge Function is stateless — it receives the full messages array each turn and returns a response. No tool calling, no parallel chains, no server-side memory, no branching agent decisions. LangChain/LangGraph would add dependency bloat for zero benefit. The conversation state lives in a Swift array on the client.

**Switching models:** Zero app changes required — just update the Edge Function environment variable.

---

## API Key Security

```
NEVER in the app:
  ❌ Hardcoded API keys
  ❌ .env files bundled in app
  ❌ Direct calls to OpenRouter from iOS

ALWAYS through server:
  ✅ API key stored as Supabase Edge Function secret
  ✅ App calls Supabase (authenticated via Supabase Auth)
  ✅ Edge Function calls OpenRouter
  ✅ Rate limiting per user
```

### Setup Steps
1. Add OpenRouter API key to Supabase Edge Function secrets
2. Edge Function reads it via `Deno.env.get("OPENROUTER_API_KEY")`
3. iOS app calls Edge Function via Supabase client (authenticated)
4. No API keys ever touch the client

---

## AI Prompt Design

### System Prompt (in Edge Function)
```
You are Docket's voice assistant. Help users create tasks through natural
conversation. You speak via text-to-speech, so keep responses short and natural.

Behavior:
- If the user provides enough info to create one or more tasks, return
  type "complete" with structured tasks and a TTS summary.
- If critical info is missing (at minimum: a task title), ask ONE short
  follow-up question. Never ask more than one question per turn.
- Keep responses to 1-2 sentences max — they are read aloud via TTS.
- Be conversational but efficient. Don't ask about optional fields
  unless the user seems to want detail or says something vague.
- Accept corrections naturally ("actually make it Wednesday",
  "never mind the note", "change priority to low").
- When the user confirms ("yes" / "add it" / "sounds good"), finalize.
- If the user provides everything in one utterance, skip questions entirely
  and return type "complete" immediately.

For each task in a "complete" response, return:
- title: Clear, concise task title (action-oriented)
- dueDate: ISO 8601 date string or null
- priority: "low", "medium", or "high"
- category: Suggested category or null
- notes: Additional context/details from the user, or null
- shareWith: Email or display name to share with, or null
- suggestion: Optional improvement note for the user

Extraction rules:
- Split compound sentences into separate tasks
- Infer priority from urgency words (urgent/ASAP/important = high)
- Infer due dates from relative terms (tomorrow, next week, Friday)
- Suggest a category based on context (Work, Personal, Health, Family,
  Finance, Shopping)
- Today's date is provided for relative date calculation
- If unsure about a field, use sensible defaults (medium priority, no due date)
- Extract notes from phrases like "note that...", "remember to...",
  "because...", "she said...", "make sure to..."
- Extract share targets from "share with...", "send to...", "assign to..."
- Do NOT fabricate notes or sharing intent — only extract what was said

Return valid JSON only. No markdown, no explanation.
```

### Request Format (conversational — messages array)
```json
{
  "messages": [
    { "role": "user", "content": "Add a task" },
    { "role": "assistant", "content": "Sure, what do you need to do?" },
    { "role": "user", "content": "Call Mom tomorrow, note about the weekend trip" }
  ],
  "today": "2026-02-08",
  "timezone": "America/New_York",
  "contacts": ["sarah@example.com"]
}
```

The messages array contains the full conversation history. The Edge Function
forwards it as chat completion messages to OpenRouter. The optional `contacts`
array helps the AI resolve names to emails.

### Response Format: Follow-up Question
```json
{
  "type": "question",
  "text": "When is it due?"
}
```

### Response Format: Completed Task(s)
```json
{
  "type": "complete",
  "tasks": [
    {
      "title": "Call Mom",
      "dueDate": "2026-02-09",
      "priority": "high",
      "category": "Family",
      "notes": "She wants to talk about the weekend trip",
      "shareWith": null,
      "suggestion": null
    }
  ],
  "summary": "Call Mom tomorrow, high priority. Noted: weekend trip. Want me to add it?"
}
```

The `summary` field is a natural-language sentence for TTS readback.
The AI generates it so it reads naturally (not just field values).

### Full Example: Multi-turn Conversation
```
Turn 1:
  Request:  { messages: [{ role: "user", content: "I need to add some tasks" }], ... }
  Response: { type: "question", text: "Sure, what do you need to do?" }

Turn 2:
  Request:  { messages: [...prev, { role: "assistant", content: "Sure, what do you need to do?" },
              { role: "user", content: "Email the client by Friday with the proposal numbers and schedule a dentist next week, note I haven't been in 6 months" }], ... }
  Response: {
    type: "complete",
    tasks: [
      { title: "Email the client", dueDate: "2026-02-13", priority: "medium",
        category: "Work", notes: "Include the proposal numbers", shareWith: null, suggestion: null },
      { title: "Schedule dentist appointment", dueDate: "2026-02-15", priority: "medium",
        category: "Health", notes: "Haven't been in 6 months", shareWith: null,
        suggestion: "You may want to set this as high priority if overdue" }
    ],
    summary: "2 tasks: Email client by Friday with proposal numbers, and dentist next week. It's been 6 months. Want me to add both?"
  }

Turn 3:
  Request:  { messages: [...prev, { role: "assistant", content: "2 tasks: ..." },
              { role: "user", content: "Actually make the dentist high priority" }], ... }
  Response: {
    type: "complete",
    tasks: [
      { title: "Email the client", dueDate: "2026-02-13", priority: "medium", ... },
      { title: "Schedule dentist appointment", dueDate: "2026-02-15", priority: "high", ... }
    ],
    summary: "Updated — dentist is now high priority. Adding both tasks."
  }
```

---

## iOS Implementation Plan

### New Files to Create

| File | Purpose |
|------|---------|
| `Managers/SpeechRecognitionManager.swift` | Handles mic + Apple Speech |
| `Managers/VoiceTaskParser.swift` | Calls Supabase Edge Function |
| `Managers/TTSManager.swift` | AVSpeechSynthesizer wrapper for readback |
| `Views/VoiceRecordingView.swift` | Mic button + recording overlay |
| `Views/TaskConfirmationView.swift` | Parsed task list with edit/confirm |
| `Models/ParsedTask.swift` | Lightweight struct for AI response |

### SpeechRecognitionManager
- Wraps `SFSpeechRecognizer` + `AVAudioEngine`
- `@Observable` for SwiftUI binding
- Properties: `isRecording`, `transcribedText`, `isAvailable`
- Methods: `startRecording()`, `stopRecording()`
- Handles permissions (microphone + speech recognition)

### TTSManager
- Wraps `AVSpeechSynthesizer` (on-device, free)
- `@Observable` for SwiftUI binding
- Properties: `isSpeaking`
- Methods: `speak(_ text: String)`, `stop()`
- Uses the AI-generated `summary` field for natural readback
- Respects system voice/language settings
- Can be muted via user preference (Settings toggle)

### VoiceRecordingView
- Floating mic button on main task list
- Expands to conversation overlay when tapped
- Shows conversation history (user bubbles + assistant bubbles)
- Shows real-time transcription of current speech
- Mic auto-restarts after TTS finishes (hands-free loop)
- "Done" button to manually stop recording and send to AI
- Cancel to abort entire conversation

### TaskConfirmationView
- List of parsed tasks (editable inline)
- Each task shows: title, due date, priority, category, notes, share target
- Notes shown as expandable/editable text under each task
- Share recipient shown with option to remove or change
- AI suggestions shown as subtle hints
- "Add All (X)" button
- Individual remove buttons
- "Cancel" to discard all

### VoiceTaskParser
- Calls Supabase Edge Function with full `messages` array (not single text)
- Sends messages + today's date + timezone + contacts list
- Receives either a follow-up question or completed tasks
- Returns `ParseResponse` (type: "question" or "complete")
- Error handling (network, parse failures, rate limits)

### ParsedTask Model
```swift
struct ParsedTask: Codable, Identifiable {
    let id: UUID  // generated client-side
    var title: String
    var dueDate: Date?
    var priority: String  // "low", "medium", "high"
    var category: String?
    var notes: String?
    var shareWith: String?  // email or display name
    var suggestion: String?
}

struct ConversationMessage: Codable {
    let role: String   // "user" or "assistant"
    let content: String
}

struct ParseResponse: Codable {
    let type: String       // "question" or "complete"
    let text: String?      // follow-up question (when type == "question")
    let tasks: [ParsedTask]? // extracted tasks (when type == "complete")
    let summary: String?   // TTS readback (when type == "complete")
}
```

### Share Resolution Flow
When `shareWith` contains a name (not email), the app resolves it:
1. Check local contacts cache for matching display name
2. If found → use their email for `task_shares.shared_with_email`
3. If not found → show inline prompt: "Who is Sarah?" with contact picker
4. Share is created via existing `task_shares` table (same as manual sharing)

This leverages the existing `resolve_share_recipient()` trigger in the database
which auto-resolves `shared_with_email` → `shared_with_id`.

---

## Supabase Edge Function

### Function: `parse-voice-tasks`

```typescript
// Pseudocode for the Edge Function
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req: Request) => {
  // 1. Verify JWT (Supabase Auth)
  // 2. Parse request body { messages[], today, timezone, contacts? }
  // 3. Build chat completion request:
  //    - System prompt (conversational task assistant)
  //    - Append all messages from the client
  //    - Include today's date and timezone in system prompt
  // 4. Call OpenRouter API (gpt-4.1-mini)
  // 5. Parse AI response as JSON
  // 6. Validate: must have { type: "question"|"complete", ... }
  // 7. Return JSON to client
});
```

The Edge Function is **stateless** — it doesn't store conversation history.
The iOS app sends the full messages array on every turn. This keeps the
server simple and avoids session management.

### Environment Variables (Supabase Secrets)
- `OPENROUTER_API_KEY` — Your OpenRouter API key
- `OPENROUTER_MODEL` — Default model (e.g., `openai/gpt-4.1-mini`)

---

## Implementation Phases

### Phase A: Speech Capture + TTS Foundation
1. Add Speech + Microphone permissions (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`)
2. Build `SpeechRecognitionManager` (SFSpeechRecognizer + AVAudioEngine)
3. Build `TTSManager` (AVSpeechSynthesizer with completion callback)
4. Implement audio session switching:
   - Recording: `.playAndRecord` category with `.defaultToSpeaker`
   - TTS playback: same category, stop recording during TTS
   - Handle `AVAudioSession.interruptionNotification`
5. Build `VoiceRecordingView` (mic button + conversation overlay)
6. Test on device: speak → see transcription → TTS reads it back → mic restarts
**Deliverable:** Working mic + TTS loop with clean audio session handoff

### Phase B: Conversational AI Parsing
1. Set up OpenRouter account + API key
2. Create Supabase Edge Function `parse-voice-tasks` (conversational system prompt)
3. Build `VoiceTaskParser` (sends messages[], receives question or tasks)
4. Build `ParsedTask` + `ParseResponse` + `ConversationMessage` models
5. Implement conversation loop on iOS:
   - User speaks → append to messages → send to Edge Function
   - If response type == "question" → TTS speaks it → mic restarts
   - If response type == "complete" → TTS speaks summary → show confirmation
6. Test multi-turn: "Add a task" → "What?" → "Call Mom" → "When?" → "Tomorrow" → task created
**Deliverable:** Full conversational flow: speak → AI asks → speak → AI creates

### Phase C: Confirmation UI + Sharing
1. Build `TaskConfirmationView` (notes + share target display, inline editing)
2. Wire up: conversation complete → preview card(s) → user confirms → save to SwiftData
3. Add share resolution flow (name → email via contacts cache or inline prompt)
4. Handle corrections mid-conversation ("actually make it Wednesday")
5. Voice confirmation: listen for "yes" / "add it" / "sounds good" after summary
6. Polish animations and transitions
**Deliverable:** End-to-end voice-to-task with sharing and corrections

### Phase D: Polish
1. Error handling (no speech, network down, AI failure, share resolution failure)
2. Loading states and progress indicators (pulsing mic, "thinking" state)
3. Haptic feedback (start recording, task created, error)
4. Edge cases (empty input, very long dictation, unknown share recipient)
5. TTS mute toggle in Settings
6. Conversation timeout (auto-cancel if no speech for 30s)
7. Usage analytics
**Deliverable:** Production-ready feature

---

## Prerequisites

Before starting this feature:
- [ ] MVP sign-off (current state)
- [ ] Supabase project set up (for Edge Functions)
- [ ] OpenRouter account + API key
- [ ] Supabase Auth working (to secure Edge Function)

---

## Cost Estimate

| Component | Usage (per user/month) | Cost |
|-----------|----------------------|------|
| Apple Speech | Unlimited | Free |
| AVSpeechSynthesizer (TTS) | Unlimited | Free (on-device) |
| OpenRouter (gpt-4.1-mini) | ~150 calls (~50 tasks × ~3 turns avg) | ~$0.08 |
| Supabase Edge Functions | ~150 invocations | Free tier |
| **Total per user** | | **~$0.08/month** |
| **100 users** | | **~$8/month** |

Conversational adds ~2-3x more API calls vs single-shot (follow-up questions),
but still very cheap because:
- Speech is on-device (no Whisper costs)
- TTS is on-device via AVSpeechSynthesizer (no cloud TTS costs)
- Only sending text to AI (not audio)
- gpt-4.1-mini is cheap for chat completion
- Power users who say everything at once use only 1 call (same as single-shot)
- Average conversation is 2-4 turns, not 10

---

## Decisions Made

1. **Conversational AI:** Yes — multi-turn dialogue, not single-shot. AI asks follow-up questions when info is missing, skips questions when user provides everything at once. ✅
2. **Supabase Auth:** Already implemented in v1.0. Edge Function calls will use existing auth tokens. ✅
3. **TTS readback:** Yes — on every AI response (questions and summaries). Uses on-device `AVSpeechSynthesizer` (free). User can mute via Settings.
4. **Mic auto-restart:** After TTS finishes speaking, mic re-activates automatically for hands-free conversation loop.
5. **Notes extraction:** Yes — AI prompt extracts contextual details into `notes` field.
6. **Voice-initiated sharing:** Yes — AI extracts share targets from speech. Resolved via contacts cache or inline prompt.
7. **Corrections:** Supported — user can say "actually make it Wednesday" mid-conversation and AI updates accordingly.
8. **Model choice:** `openai/gpt-4.1-mini` via OpenRouter. Fast, cheap, excellent structured output. No thinking model needed.
9. **Orchestrator:** Not needed even for conversational. Conversation state is a messages array on the iOS client. Edge Function is stateless. No LangChain/LangGraph.
10. **Dependencies:** Zero new installs. Apple Speech, AVFoundation, AVSpeechSynthesizer are all built into iOS. Edge Function uses native Deno `fetch()`.
11. **Audio session:** Use `.playAndRecord` category with `.defaultToSpeaker` override. Stop AVAudioEngine during TTS playback, restart after TTS completion callback.

## Open Decisions

1. **Offline fallback?** If no internet, should we save raw transcription as a single task (no AI parsing)?
2. **Contact resolution:** Should the app send the user's contacts list to the Edge Function, or resolve names client-side after parsing?
3. **Conversation timeout:** How long to wait with no speech before auto-canceling? (Suggested: 30 seconds)

---

*Architecture documented 2026-02-06 — Updated 2026-02-08 with conversational AI, notes, sharing, TTS, model update*
