# Tech Stack: Docket

## Platforms
- iOS (iPhone first, iPad later)
- Native app

## Frontend
- **Framework:** SwiftUI
- **UI Library:** Native iOS (Apple Human Interface Guidelines)
- **State Management:** SwiftData + @State/@Observable
- **Navigation:** SwiftUI NavigationStack

## Backend
- **MVP:** Local only — no backend
- **v1.0:** Supabase
- **API Style:** REST (Supabase client SDK)

## Database
- **MVP:** SwiftData (Apple's local persistence framework)
- **v1.0:** PostgreSQL via Supabase
- **Caching:** In-memory + SwiftData local cache
- **File Storage:** N/A (no attachments in MVP)

## Auth
- **MVP:** None (local device only)
- **v1.0:** Supabase Auth (email/password or magic link)

## Infrastructure
- **Hosting:** App Store for client, Supabase Cloud for backend (v1.0)
- **CI/CD:** Xcode Cloud or GitHub Actions
- **Monitoring:** PostHog or Sentry (lightweight, privacy-focused)

## Integrations
- **MVP:** None
- **v1.0:** Apple Calendar (potential), Push Notifications
- **v1.0-voice:** Siri Shortcuts, Apple Speech framework

## Voice-to-Task (v1.0)
- **Speech Recognition:** Apple SpeechAnalyzer (on-device) / OpenAI Whisper API (cloud)
- **Audio Capture:** AVAudioEngine with buffer processing
- **Transport:** WebSocket (WSS) for real-time streaming
- **NLU:** GPT-4o-mini via Supabase Edge Functions
- **TTS (Confirmation):** Apple AVSpeechSynthesizer
- **Audio Format:** PCM → Opus compression for network

## Real-Time
- **v1.0:** Supabase real-time subscriptions for sync

## Development Environment
- **Xcode:** 16+ (latest stable)
- **Minimum iOS:** 17+ (allows latest SwiftUI features)
- **Swift Version:** 6.0+
