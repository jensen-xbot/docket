# Voice Pipeline Latency Optimization (2026-02-14)

## Summary

Reduced perceived latency from "user stops speaking" to "AI audio starts" by ~1–2 seconds through five changes: faster silence detection, model swap to Gemini 2.5 Flash, streaming LLM response, smarter task context, and TTS overlap for question-type responses.

## Changes Implemented

### 1. Silence Timeout Reduction
- **File:** `Managers/SpeechRecognitionManager.swift`
- Short utterances (1–2 words): 2.2s → 1.5s
- Long utterances (3+ words): 2.8s → 2.2s
- **Impact:** ~0.6s saved on every interaction

### 2. Model Swap to Gemini 2.5 Flash
- **File:** `supabase/functions/parse-voice-tasks/index.ts`
- Default model: `deepseek/deepseek-v3.2` → `google/gemini-2.5-flash-preview`
- Temperature: 0.7 → 0.3 (more deterministic for task parsing)
- **Impact:** Faster TTFT, built-in reasoning for intent resolution
- **Fallback:** Set `OPENROUTER_MODEL=deepseek/deepseek-v3.2` to revert

### 3. Streaming LLM Response
- **Edge Function:** Added `stream: true` to OpenRouter request; proxies SSE stream directly to client
- **VoiceTaskParser:** Replaced `supabase.functions.invoke()` with `URLSession.shared.bytes()` for streaming consumption; parses SSE, accumulates content, normalizes response client-side
- **Impact:** Eliminates OpenRouter buffering delay; client receives tokens as they arrive

### 4. Smarter Task Context
- **Relevance filtering:** When user text contains keywords, send top 10 matching tasks + 15 recent (vs. 70 tasks before)
- **Compact format:** Task context changed from verbose to pipe-delimited: `id|title|dueDate|priority|category|extras`
- **Impact:** Fewer input tokens, faster model processing

### 5. TTS Overlap for Questions
- **VoiceRecordingView:** Uses `sendStreaming(onResponse:)`; for `type == "question"`, starts TTS immediately in callback so playback overlaps with response handling
- **TaskListView:** Completion handler invoked from `onResponse` for earlier delivery
- **VoiceModeContainer:** Now passes `existingTasks` and `groceryStores`; uses `sendStreaming`

## Deployment

```bash
supabase functions deploy parse-voice-tasks --no-verify-jwt
```

## Files Modified

| File | Change |
|------|--------|
| `SpeechRecognitionManager.swift` | Silence timeouts 1.5s / 2.2s |
| `parse-voice-tasks/index.ts` | Gemini Flash, stream:true, compact task format |
| `VoiceTaskParser.swift` | sendStreaming(), URLSession bytes, client normalization |
| `VoiceRecordingView.swift` | sendStreaming + onResponse, buildTaskContext(userText:) |
| `TaskListView.swift` | sendStreaming, buildTaskContext(userText:) |
| `VoiceModeContainer.swift` | @Query tasks/stores, buildTaskContext, buildGroceryStoreContext, sendStreaming |
