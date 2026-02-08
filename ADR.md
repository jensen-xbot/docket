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

## ADR-005: Voice-to-Text Architecture (v1.0)
- **Decision:** Apple SpeechAnalyzer (MVP) → OpenAI Whisper (v1.0+)
- **Context:** Adding voice task creation feature. Need on-device option for privacy/speed and cloud option for accuracy.
- **Options Considered:**
  - Apple SpeechAnalyzer only (free, private, iOS 17+, less accurate)
  - OpenAI Whisper API only (high accuracy, requires internet, ongoing cost)
  - Hybrid: Apple for quick commands, Whisper for complex (best of both)
  - OpenAI Realtime API (streaming, voice-in-voice-out, higher cost)
- **Decision:** Start with Apple SpeechAnalyzer for v1.0 foundation, add Whisper as enhanced option in v1.0+
- **Consequences:**
  - MVP voice feature ships without external API costs
  - Privacy-first (on-device processing)
  - May need to upgrade to Whisper for complex natural language
  - Realtime API considered but overkill for MVP
- **Date:** 2026-02-06

## ADR-006: Audio Gateway/Tunnel (v1.0)
- **Decision:** WebSocket (WSS) for real-time streaming
- **Context:** Need secure, persistent connection for audio streaming from device to backend agent
- **Options Considered:**
  - REST API with chunked uploads (simpler, higher latency)
  - WebSocket (real-time, bidirectional, standard)
  - WebRTC (overkill for this use case)
  - MQTT (IoT-focused, not ideal for audio)
- **Decision:** WebSocket on port 443 (WSS) with automatic reconnection
- **Consequences:**
  - Real-time streaming capability
  - Secure by default (TLS)
  - Need reconnection logic for dropped connections
  - Supabase Edge Functions support WebSocket clients
- **Date:** 2026-02-06

## ADR-007: Natural Language Understanding (v1.0)
- **Decision:** LLM function calling (GPT-4o-mini via Supabase Edge Function)
- **Context:** Converting voice transcription to structured task data (title, due date, priority)
- **Options Considered:**
  - Regex/pattern matching only (fast, limited, brittle)
  - Apple's NaturalLanguage framework (on-device, limited task extraction)
  - LLM function calling (flexible, accurate, requires API call)
  - Hybrid: patterns for dates, LLM for complex parsing
- **Decision:** LLM function calling for v1.0 with caching for common patterns
- **Consequences:**
  - High accuracy for complex commands
  - Ongoing API costs (~$0.005 per extraction)
  - Latency ~1-2s for parsing
  - Can fall back to patterns if offline
- **Date:** 2026-02-06

## ADR-008: Task Sharing + Push Notifications (v1.0)
- **Decision:** Auto-accept shares, push notifications via Supabase Edge Function + APNs
- **Context:** Shared tasks must appear instantly for recipients, with a notification that deep-links to the task.
- **Options Considered:**
  - Manual accept/decline flow (adds friction, extra UI)
  - Auto-accept share and allow remove from list (fast, Reminders-like)
  - Local notification only (requires app open, misses real-time push)
  - APNs push via Supabase Edge Function (real push, supports deep-link)
- **Decision:** Auto-accept shares; send APNs push from Edge Function on `task_shares` INSERT.
- **Consequences:**
  - Fast, low-friction sharing for families
  - Requires APNs key setup and Edge Function secrets
  - Simple deep-link: push payload includes `task_id`
- **Date:** 2026-02-08

## Known Risks

1. **SwiftData maturity:** Newer framework, may have undiscovered bugs or limitations
2. **Supabase free tier limits:** Could hit limits if user base grows unexpectedly
3. **iOS-only limitation:** Can't serve Android users, but intentional for this project
4. **Migration complexity:** Moving from SwiftData local to Supabase sync requires careful data migration UX
5. **Apple Developer account:** $99/year cost and potential activation delays
6. **Voice feature complexity:** Audio processing adds significant complexity to codebase
7. **Privacy concerns:** Voice data transmission requires clear user consent and security measures
8. **API costs:** Voice features (Whisper + GPT-4o) add ongoing operational costs
