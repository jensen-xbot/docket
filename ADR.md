# Architecture Decision Records: Docket

## ADR-001: Frontend Framework
- **Decision:** SwiftUI over UIKit
- **Context:** Building a modern iOS app targeting iOS 17+, need rapid development and clean code
- **Options Considered:**
  - UIKit (mature, well-documented)
  - SwiftUI (modern, declarative, Apple's future direction)
  - React Native (cross-platform, but adds complexity)
- **Decision:** SwiftUI
- **Consequences:** 
  - Faster prototyping and development
  - Native iOS feel with less code
  - Newer framework means some edge cases less documented
  - Learning curve if unfamiliar with declarative UI patterns
- **Date:** 2026-02-06

## ADR-002: Database Choice
- **Decision:** SwiftData (MVP) → Supabase PostgreSQL (v1.0)
- **Context:** MVP needs local persistence; v1.0 needs cloud sync
- **Options Considered:**
  - Core Data (mature, complex)
  - SwiftData (modern, simpler API, built on Core Data)
  - Realm (cross-platform, adds dependency)
  - Firebase (proprietary, different from Closelo stack)
  - Supabase (open source, matches Closelo stack)
- **Decision:** SwiftData for MVP, Supabase for v1.0 sync
- **Consequences:**
  - MVP can ship fast with no backend complexity
  - v1.0 requires migration strategy from local to cloud
  - Consistency with Closelo's Supabase choice
- **Date:** 2026-02-06

## ADR-003: Auth Strategy
- **Decision:** None (MVP) → Supabase Auth (v1.0)
- **Context:** MVP is single-user local; v1.0 needs multi-device sync
- **Options Considered:**
  - Apple Sign In (required for App Store if using 3rd party auth)
  - Supabase Auth (email/password, magic link, OAuth providers)
  - Custom auth (overkill)
- **Decision:** Supabase Auth with email/password or magic link for v1.0
- **Consequences:**
  - Must implement Apple Sign In alongside to comply with App Store guidelines
  - Minimal setup, integrates with Supabase backend
  - Supports multiple providers if needed later
- **Date:** 2026-02-06

## ADR-004: Platform Strategy
- **Decision:** iOS only (no Android)
- **Context:** Learning project, focused on shipping fast and learning SwiftUI
- **Options Considered:**
  - iOS + Android (Flutter or React Native)
  - iOS only (SwiftUI)
- **Decision:** iOS only
- **Consequences:**
  - Limited market, but acceptable for learning project
  - Faster development, better native iOS integration
  - Can expand to iPad later using same codebase
- **Date:** 2026-02-06

## ADR-005: Voice-to-Text Architecture (v1.1)
- **Decision:** Apple SFSpeechRecognizer (primary, on-device) + OpenAI Whisper API (optional fallback)
- **Context:** Adding voice task creation feature. Need on-device option for privacy/speed and cloud option for accuracy.
- **Options Considered:**
  - Apple SFSpeechRecognizer only (free, private, iOS 17+, less accurate for accents)
  - OpenAI Whisper API only (high accuracy, requires internet, ongoing cost)
  - Hybrid: SFSpeechRecognizer primary, Whisper as user-toggleable fallback (best of both)
  - OpenAI Realtime API (streaming, voice-in-voice-out, higher cost)
- **Decision:** SFSpeechRecognizer as default; Whisper API as opt-in "Enhanced transcription" toggle in Profile
- **Consequences:**
  - Voice feature ships without external API costs by default
  - Privacy-first (on-device processing)
  - Whisper fallback available for users who need better accent accuracy
  - Realtime API considered but overkill for task parsing
- **Date:** 2026-02-06 (updated 2026-02-10)

## ADR-006: Voice Transport (v1.1) — SUPERSEDED
- **Original decision:** WebSocket (WSS) for real-time streaming
- **Actual implementation:** HTTPS REST per turn (Supabase `functions.invoke`)
- **Why changed:** Conversational voice uses a turn-based model (user speaks → transcribe on-device → send text to Edge Function → get response). No audio streaming to backend. Each turn is a single REST call with conversation history.
- **Consequences:**
  - Simpler architecture, no WebSocket connection management
  - Latency is acceptable (~1-2s per turn including AI parsing)
  - Audio stays on-device (SFSpeechRecognizer); only text goes to backend
- **Date:** 2026-02-06 (superseded 2026-02-10)

## ADR-007: Natural Language Understanding (v1.1)
- **Decision:** gpt-4.1-mini via OpenRouter → Supabase Edge Function
- **Context:** Converting voice transcription to structured task data (title, due date, priority, category, notes, share target)
- **Options Considered:**
  - Regex/pattern matching only (fast, limited, brittle)
  - Apple's NaturalLanguage framework (on-device, limited task extraction)
  - LLM structured output (flexible, accurate, requires API call)
  - Hybrid: patterns for dates, LLM for complex parsing
- **Decision:** gpt-4.1-mini for all semantic parsing; deterministic control intents handled client-side
- **Consequences:**
  - High accuracy for complex multi-task commands
  - Cost: ~$0.001/turn (~$8/month @ 100 users)
  - Latency ~1-2s per turn
  - Supports create, update, delete, and grocery list flows
- **Date:** 2026-02-06 (updated 2026-02-10)

## ADR-008: Task Sharing + Push Notifications (v1.0 → v2)
- **Original decision:** Auto-accept shares for all recipients
- **Updated decision (v2):** Invite-gated for new contacts; auto-accept only for existing accepted contacts
- **Context:** Auto-accept was too permissive. New contacts should explicitly accept/decline a share invite.
- **Implementation:**
  - `resolve_share_recipient` trigger resolves email → user ID but only auto-accepts if prior accepted share exists
  - `task_shares.status` lifecycle: `pending` → `accepted` / `declined`
  - Recipient can UPDATE own pending invites (RLS policy)
  - `notifications` table stores invite notifications; bell badge + inbox in app
  - Realtime subscriptions on `tasks` and `task_shares` for bilateral edits (LWW)
  - Push notifications route by type: `task_share_invite` → Contacts/Invites, `task_id` → task detail
- **Consequences:**
  - More secure sharing model
  - Requires invite UX in ContactsListView (accept/decline)
  - Notification inbox adds discoverability
  - Realtime sync reduces pull-based latency
- **Date:** 2026-02-08 (updated 2026-02-10 with Sharing System V2)

## ADR-010: TTS Model Migration to gpt-4o-mini-tts with Streaming (v1.1)
- **Decision:** Migrate from tts-1 to gpt-4o-mini-tts with streaming PCM playback
- **Context:** tts-1 does not support streaming; long responses caused timeout and Apple fallback. gpt-4o-mini-tts supports streaming with similar cost (~$0.015/min).
- **Options Considered:**
  - Chunk-and-queue with tts-1 (multiple requests, gaps between chunks)
  - gpt-4o-mini-tts with streaming (single request, low latency)
- **Decision:** gpt-4o-mini-tts + streaming PCM via Edge Function proxy
- **Implementation:**
  - Edge Function: model `gpt-4o-mini-tts`, `response_format: "pcm"`, `stream_format: "audio"`; proxy stream to client
  - iOS: URLSession.bytes for streaming; AVAudioEngine + AVAudioPlayerNode; convert PCM chunks to AVAudioPCMBuffer
  - Fallback: Apple AVSpeechSynthesizer on stream error or timeout
- **Consequences:**
  - Lower perceived latency (audio starts before full generation)
  - Better quality and 13 voices (incl. marin, cedar)
  - Requires AVAudioEngine instead of AVAudioPlayer
- **Date:** 2026-02-11

## ADR-011: TTS Streaming Latency Optimizations (v1.1)
- **Decision:** Reduce time-to-first-audio with cached token, reusable player, smaller first chunk, and engine pre-start
- **Context:** After AI text appears, there was a noticeable delay before TTS audio started. Several sequential bottlenecks added ~130-730ms.
- **Options Considered:**
  - Status quo (acceptable but perceptible lag)
  - Full pipeline rewrite (URLSessionDataDelegate, connection pooling)
  - Targeted optimizations (chosen)
- **Decision:** Four targeted optimizations:
  1. **Cached access token:** `VoiceTaskParser` sets `lastAccessToken` after `send()`; all `speakWithBoundedSync` call sites pass it. TTSManager skips `supabase.auth.session` when token provided. Saves ~50-500ms.
  2. **Reusable TTSStreamingPlayer:** Lazy singleton with `reset()` between uses. Engine graph stays attached; no per-request setup. Saves ~10-30ms.
  3. **Pre-buffer (jitter buffer):** Enqueue 2048-byte chunks but defer `playerNode.play()` until 6144 bytes (~128ms) are queued. This prevents buffer underruns between chunks. Short responses (< 6144 bytes) start playback as soon as the stream ends.
  4. **Engine pre-start:** Start AVAudioEngine before `URLSession.shared.bytes(for:)`. Engine ready when first bytes arrive. Saves ~20-50ms.
- **Implementation:**
  - [TTSManager.swift](Docket/Docket/Managers/TTSManager.swift): `reusableStreamingPlayer`, `reset()`, `prepare()`/`beginPlayback()` split, `accessToken` param, `kTTSStreamChunkSize` (2048), `kTTSStreamPreBufferSize` (6144), engine start before HTTP
  - [VoiceTaskParser.swift](Docket/Docket/Managers/VoiceTaskParser.swift): `lastAccessToken` property
  - [VoiceRecordingView.swift](Docket/Docket/Views/VoiceRecordingView.swift): Pass `parser.lastAccessToken` to all `speakWithBoundedSync` and `speak` calls
- **Consequences:**
  - Total estimated savings: ~130-730ms reduction in time-to-first-audio
  - No API or backend changes
  - Token reuse is safe; same session used for parse and TTS within same turn
  - Minor jitter may still be perceptible due to byte-by-byte async iteration; future improvement could use `URLSessionDataDelegate` for native chunk delivery
- **Date:** 2026-02-11

## ADR-009: Voice Intent Classification Extraction (v1.1)
- **Decision:** Extract deterministic voice intent logic into a dedicated `IntentClassifier` struct in `Managers/`, separate from `VoiceRecordingView`
- **Context:** Intent detection (confirm, reject, dismiss, gratitude) and phrase lists were embedded directly in VoiceRecordingView (~1500 lines). The view mixed UI, orchestration, and classification logic.
- **Options Considered:**
  - Keep logic in VoiceRecordingView (status quo, hard to test, monolithic)
  - Extract to IntentClassifier (pure, testable, single responsibility)
  - Move to Edge Function (adds latency, contradicts ADR-007's "deterministic intents stay local")
- **Decision:** Extract to `IntentClassifier` — a stateless struct with `classify(text:context:)` returning `VoiceIntent` enum. Phrase lists and word-boundary matching live in one file. VoiceRecordingView becomes a thin dispatcher (switch on intent → action).
- **Consequences:**
  - Same latency (on-device, no new allocations)
  - Unit-testable without SwiftUI/SwiftData
  - Single source of truth for phrase lists; maps 1:1 to VOICE-INTENT-RULES.md
  - VoiceRecordingView shrinks; orchestration remains in view
- **Date:** 2026-02-11

## Known Risks

1. **SwiftData maturity:** Newer framework, may have undiscovered bugs or limitations
2. **Supabase free tier limits:** Could hit limits if user base grows unexpectedly
3. **iOS-only limitation:** Can't serve Android users, but intentional for this project
4. **Migration complexity:** Moving from SwiftData local to Supabase sync requires careful data migration UX
5. **Apple Developer account:** $99/year cost and potential activation delays
6. **Voice feature complexity:** Audio processing adds significant complexity to codebase
7. **Privacy concerns:** Voice data transmission requires clear user consent and security measures
8. **API costs:** Voice features (optional Whisper + gpt-4.1-mini + OpenAI TTS) add ongoing operational costs (~$23/month @ 100 users)
