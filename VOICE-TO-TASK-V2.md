# Voice-to-Task V2 Architecture Plan

## Overview

Users can dictate one or many tasks naturally. The system transcribes speech on-device, sends text to a cloud AI for parsing, and presents a visual confirmation list before saving. The AI also suggests improvements (priority, due dates, categories).

---

## User Experience Flow

### Single Task
```
1. Tap mic button
2. Speak: "Call Mom tomorrow, it's important"
3. See transcription appear in real-time
4. AI parses and returns:
   - Title: "Call Mom"
   - Due: Tomorrow
   - Priority: High (inferred from "important")
   - Category: Personal (suggested)
5. Preview card appears with edit controls
6. User confirms (tap or voice "yes")
7. Task saved
```

### Batch Dictation
```
1. Tap mic button
2. Speak: "I need to email the client by Friday, pick up groceries
   after work, and schedule a dentist appointment next week"
3. See transcription in real-time
4. AI parses into 3 tasks:
   - "Email the client" — Due: Friday, Priority: Medium, Category: Work
   - "Pick up groceries" — Due: Today, Priority: Low, Category: Personal
   - "Schedule dentist appointment" — Due: Next week, Priority: Medium, Category: Health
5. Preview list appears, each task editable
6. User can remove/edit individual tasks
7. Tap "Add All" or "Add X Tasks"
8. All tasks saved
```

---

## Technical Architecture

```
┌──────────────────────────────┐
│         Docket iOS App       │
│                              │
│  ┌────────────────────────┐  │
│  │ Mic Button / Voice UI  │  │
│  └───────────┬────────────┘  │
│              │               │
│  ┌───────────▼────────────┐  │
│  │ Apple Speech Framework │  │
│  │ SFSpeechRecognizer     │  │
│  │ (on-device, free)      │  │
│  └───────────┬────────────┘  │
│              │ text          │
│  ┌───────────▼────────────┐  │
│  │ Supabase Client        │  │
│  │ (HTTPS POST)           │  │
│  └───────────┬────────────┘  │
└──────────────┼───────────────┘
               │ HTTPS
               │
┌──────────────▼───────────────┐
│   Supabase Edge Function     │
│   "parse-voice-tasks"        │
│                              │
│  ┌────────────────────────┐  │
│  │ OpenRouter API Call    │  │
│  │ (API key stored here)  │  │
│  │                        │  │
│  │ Model: openai/         │  │
│  │ gpt-4o-mini (primary)  │  │
│  │ or groq/               │  │
│  │ llama-3.1-70b (budget) │  │
│  └───────────┬────────────┘  │
│              │               │
│  ┌───────────▼────────────┐  │
│  │ Validate + Structure   │  │
│  │ Response               │  │
│  └───────────┬────────────┘  │
└──────────────┼───────────────┘
               │ JSON response
               │
┌──────────────▼───────────────┐
│   Docket iOS App             │
│                              │
│  ┌────────────────────────┐  │
│  │ TaskConfirmationView   │  │
│  │ - Editable task list   │  │
│  │ - AI suggestions shown │  │
│  │ - Add All / Cancel     │  │
│  └───────────┬────────────┘  │
│              │               │
│  ┌───────────▼────────────┐  │
│  │ SwiftData (save)       │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
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

### Model Recommendation (Updated Feb 2025)

For task parsing (structured extraction + suggestions), you want a model that's:
- **Fast** (< 1 second response)
- **Structured output** reliable (JSON schema)
- **Cheap** (pennies per call)

❌ **Avoid "Thinking" models** (DeepSeek-R1, Kimi K2.5, o1): They're 3-10x slower, more expensive, and overkill for simple extraction. Task parsing is pattern matching, not complex reasoning.

✅ **Recommended Models:**

| Model | Speed | Cost (per 1M tokens) | Best For |
|-------|-------|---------------------|----------|
| **gpt-4o-mini** ⭐ | Very fast | ~$0.15 in / $0.60 out | **Primary choice** — best structured output |
| **llama-3.1-70b (Groq)** | Ultra fast | ~$0.05 in / $0.10 out | **Budget/fastest** — great for simple parsing |
| **mistral-small** | Fast | ~$0.20 in / $0.60 out | GDPR-friendly alternative |
| **claude-3-5-haiku** | Fast | ~$0.25 in / $1.25 out | If OpenAI unavailable |

| Quirky Model | Speed | Cost | Use Case |
|-------------|-------|------|----------|
| **deepseek-chat** | Fast | ~$0.14 in / $0.28 out | Chat/instructions, not structured JSON |
| **deepseek-r1** | Slow (3-5s) | ~$0.55 in / $2.19 out | ❌ Overkill for extraction |
| **Kimi K2.5** | Slow (3-5s) | ~$0.50+ | ❌ Overkill, slow |

**Primary Recommendation: `openai/gpt-4o-mini` via OpenRouter**
- Lightning fast (<500ms)
- Native JSON mode support
- Reliable schema adherence
- ~$0.001 per task extracted

**Budget Alternative: `groq/llama-3.1-70b-versatile` via OpenRouter**
- Even faster (<200ms)
- 3x cheaper
- Nearly as accurate for simple extraction
- Good if gpt-4o-mini unavailable

**Why not thinking models?** DeepSeek-R1 and Kimi K2.5 spend 3-5 seconds "thinking" before responding. Users don't want to wait 5 seconds after speaking — they want instant task creation.

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
You are a task parser for a todo app called Docket.

Given natural language text from voice input, extract one or more tasks.

For each task, return:
- title: Clear, concise task title
- dueDate: ISO 8601 date string or null
- priority: "low", "medium", or "high"
- category: Suggested category or null
- suggestion: Optional improvement note

Rules:
- Split compound sentences into separate tasks
- Infer priority from urgency words (urgent/ASAP/important = high)
- Infer due dates from relative terms (tomorrow, next week, Friday)
- Suggest a category based on context (Work, Personal, Health, Family, Finance)
- Today's date is provided for relative date calculation
- If unsure about a field, use sensible defaults (medium priority, no due date)

Return valid JSON only. No markdown, no explanation.
```

### Request Format
```json
{
  "text": "Email the client by Friday, pick up groceries after work, and schedule a dentist appointment next week",
  "today": "2026-02-06",
  "timezone": "America/New_York"
}
```

### Response Format
```json
{
  "tasks": [
    {
      "title": "Email the client",
      "dueDate": "2026-02-07",
      "priority": "medium",
      "category": "Work",
      "suggestion": null
    },
    {
      "title": "Pick up groceries",
      "dueDate": "2026-02-06",
      "priority": "low",
      "category": "Personal",
      "suggestion": "Consider adding a recurring reminder for groceries"
    },
    {
      "title": "Schedule dentist appointment",
      "dueDate": "2026-02-13",
      "priority": "medium",
      "category": "Health",
      "suggestion": "You may want to set this as high priority if overdue"
    }
  ]
}
```

---

## iOS Implementation Plan

### New Files to Create

| File | Purpose |
|------|---------|
| `Managers/SpeechRecognitionManager.swift` | Handles mic + Apple Speech |
| `Managers/VoiceTaskParser.swift` | Calls Supabase Edge Function |
| `Views/VoiceRecordingView.swift` | Mic button + recording overlay |
| `Views/TaskConfirmationView.swift` | Parsed task list with edit/confirm |
| `Models/ParsedTask.swift` | Lightweight struct for AI response |

### SpeechRecognitionManager
- Wraps `SFSpeechRecognizer` + `AVAudioEngine`
- `@Observable` for SwiftUI binding
- Properties: `isRecording`, `transcribedText`, `isAvailable`
- Methods: `startRecording()`, `stopRecording()`
- Handles permissions (microphone + speech recognition)

### VoiceRecordingView
- Floating mic button on main task list
- Expands to recording overlay when tapped
- Shows real-time transcription
- "Done" button to send to AI
- Cancel to abort

### TaskConfirmationView
- List of parsed tasks (editable inline)
- Each task shows: title, due date, priority, category
- AI suggestions shown as subtle hints
- "Add All (X)" button
- Individual remove buttons
- "Cancel" to discard all

### VoiceTaskParser
- Calls Supabase Edge Function
- Sends transcribed text + today's date + timezone
- Receives parsed tasks JSON
- Maps to `[ParsedTask]`
- Error handling (network, parse failures, rate limits)

---

## Supabase Edge Function

### Function: `parse-voice-tasks`

```typescript
// Pseudocode for the Edge Function
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req: Request) => {
  // 1. Verify JWT (Supabase Auth)
  // 2. Parse request body { text, today, timezone }
  // 3. Call OpenRouter API with system prompt
  // 4. Parse AI response
  // 5. Validate task structure
  // 6. Return JSON to client
});
```

### Environment Variables (Supabase Secrets)
- `OPENROUTER_API_KEY` — Your OpenRouter API key
- `OPENROUTER_MODEL` — Default model (e.g., `openai/gpt-4o-mini`)

---

## Implementation Phases

### Phase A: Speech Capture (no AI yet)
1. Add Speech + Microphone permissions
2. Build `SpeechRecognitionManager`
3. Build `VoiceRecordingView` (mic button + overlay)
4. Test on device (transcription only)
**Deliverable:** Tap mic, speak, see text

### Phase B: AI Parsing
1. Set up OpenRouter account + API key
2. Create Supabase Edge Function `parse-voice-tasks`
3. Build `VoiceTaskParser` (client-side caller)
4. Build `ParsedTask` model
5. Test end-to-end (text in → tasks out)
**Deliverable:** Transcribed text gets parsed into structured tasks

### Phase C: Confirmation UI
1. Build `TaskConfirmationView`
2. Wire up: recording → parse → confirm → save
3. Add AI suggestion display
4. Add voice confirmation (optional TTS readback)
5. Polish animations and transitions
**Deliverable:** Full voice-to-task flow working

### Phase D: Polish
1. Error handling (no speech, network down, AI failure)
2. Loading states and progress indicators
3. Haptic feedback
4. Edge cases (empty input, very long dictation)
5. Usage analytics
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
| OpenRouter (gpt-4o-mini) | ~50 calls | ~$0.05 |
| Supabase Edge Functions | ~50 invocations | Free tier |
| **Total per user** | | **~$0.05/month** |
| **100 users** | | **~$5/month** |

Much cheaper than the original V1 plan because:
- Speech is on-device (no Whisper costs)
- Only sending text to AI (not audio)
- gpt-4o-mini is cheap for structured extraction

---

## Open Decisions

1. **Supabase Auth first?** Voice feature requires authenticated Edge Function calls. Need to decide: implement auth before or alongside voice.
2. **Offline fallback?** If no internet, should we save raw transcription as a single task (no AI parsing)?
3. **Voice confirm TTS?** iOS has built-in `AVSpeechSynthesizer` for text-to-speech. Worth adding in Phase C or defer to later?

---

*Architecture documented 2026-02-06 — Ready to implement after MVP sign-off*
