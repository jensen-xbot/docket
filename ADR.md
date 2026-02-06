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

## Known Risks

1. **SwiftData maturity:** Newer framework, may have undiscovered bugs or limitations
2. **Supabase free tier limits:** Could hit limits if user base grows unexpectedly
3. **iOS-only limitation:** Can't serve Android users, but intentional for this project
4. **Migration complexity:** Moving from SwiftData local to Supabase sync requires careful data migration UX
5. **Apple Developer account:** $99/year cost and potential activation delays
