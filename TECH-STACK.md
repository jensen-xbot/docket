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
- **Current:** Supabase (Auth + Database)
- **API Style:** REST (Supabase client SDK)

## Database
- **Local:** SwiftData (Apple's local persistence framework)
- **Remote:** PostgreSQL via Supabase
- **Caching:** SwiftData local cache + background sync
- **File Storage:** N/A (no attachments)

## Auth
- **Current:** Supabase Auth (Apple Sign-In + email magic link)

## Infrastructure
- **Hosting:** App Store for client, Supabase Cloud for backend (v1.0)
- **CI/CD:** Xcode Cloud or GitHub Actions
- **Monitoring:** PostHog or Sentry (lightweight, privacy-focused)

## Integrations
- **Current:** UserNotifications (local reminders)
- **Current:** MessageUI (email/SMS compose), Contacts (device picker)
- **Near-term:** Supabase Realtime for shared tasks
- **Voice-to-Task:** Siri Shortcuts, Apple Speech framework

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
