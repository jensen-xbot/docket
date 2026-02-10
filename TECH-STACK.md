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
- **Current:** Supabase (Auth + Database + Edge Functions)
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
- **Current:** APNs (push notifications for shared tasks)
- **Current:** MessageUI (email/SMS compose), Contacts (device picker)
- **Current:** Supabase Realtime for shared task sync (tasks + task_shares channels)
- **Planned:** Siri Shortcuts

## Voice-to-Task (v1.1)
- **Speech Recognition:** Apple SFSpeechRecognizer (on-device, primary) / OpenAI Whisper API (opt-in fallback)
- **Audio Capture:** AVAudioEngine with buffer processing
- **Transport:** HTTPS REST per turn (Supabase `functions.invoke`) — no WebSocket
- **NLU:** gpt-4.1-mini via OpenRouter → Supabase Edge Function
- **TTS (Readback):** OpenAI TTS API (primary, natural voices) / Apple AVSpeechSynthesizer (fallback)
- **Audio Format:** PCM on-device; text-only to backend (no audio streaming)

## Real-Time
- **Implemented:** Supabase Realtime subscriptions for tasks and task_shares (postgres_changes)

## Development Environment
- **Xcode:** 16+ (latest stable)
- **Minimum iOS:** 17+ (allows latest SwiftUI features)
- **Swift Version:** 6.0+
