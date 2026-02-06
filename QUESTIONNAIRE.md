# Docket — Discovery Questionnaire

## Phase 2: Discovery Questionnaire

---

### 📄 PRD.md Questions (Product Requirements)

| # | Question | Answer |
|---|----------|--------|
| 1 | What problem does this solve? (1-2 sentences) | Manage daily tasks and to-dos in a focused, distraction-free iPhone app. Replaces scattered notes and mental load with organized, actionable lists. |
| 2 | Who is it for? (target user — be specific) | Jon — a busy professional juggling sales work, side projects (Closelo), family, and personal routines. Needs quick capture and clear organization without friction. |
| 3 | What does "done" look like for MVP? | Can create, edit, complete, and delete tasks. Tasks persist locally. Clean, native iOS UI. Single user, no backend needed. |
| 4 | What does "done" look like for v1.0? | Sync across devices via backend. Due dates with notifications. Categories/projects for organization. Priority levels (high/medium/low). Recurring tasks. |
| 5 | **Must-have features** (MVP) | 1. Create task with title 2. Edit task 3. Mark complete/incomplete 4. Delete task 5. View all tasks (active + completed) 6. Local persistence |
| 6 | **Should-have features** (v1.0) | 1. Due dates 2. Categories/tags 3. Priority levels 4. Cloud sync 5. Push notifications for due dates |
| 7 | **Could-have features** (future) | 1. Siri shortcuts 2. Widgets 3. Apple Watch app 4. Subtasks 5. Collaboration/sharing |
| 8 | **Won't-have (yet)** | 1. Collaboration/multi-user 2. Natural language input 3. AI suggestions 4. Advanced filtering/search 5. Attachments/files |
| 9 | Success metrics — how do we know it works? | MVP: Can create and complete a task within 3 taps. v1.0: Zero data loss, instant sync, <100ms response time. |
| 10 | Key user flows (step-by-step journeys) | 1. Quick capture: Open app → Tap + → Type → Save (2-3 taps). 2. Daily review: Open app → See today's tasks → Mark done. 3. Organize: Add category → Move tasks → Set priorities. |

---

### 📄 TECH-STACK.md Questions (Architecture & Tools)

| # | Question | Answer |
|---|----------|--------|
| 11 | Platform(s): iOS / Android / Web / Desktop / All? | iOS (iPhone first, iPad later maybe). Native app. |
| 12 | Frontend framework/library? | SwiftUI (Apple's modern declarative UI framework) |
| 13 | Backend/stack? | MVP: Local only (SwiftData/UserDefaults). v1.0: Supabase (already familiar from Closelo) |
| 14 | Database? | MVP: SwiftData (Apple's local persistence). v1.0: PostgreSQL via Supabase |
| 15 | Auth method? | MVP: None (local). v1.0: Supabase Auth (email/password or magic link) |
| 16 | Hosting/deployment target? | App Store for client. Supabase cloud for backend v1.0 |
| 17 | Real-time sync needed? Yes/No → If yes, how? | v1.0 only — Supabase real-time subscriptions |
| 18 | Third-party APIs/integrations? | None for MVP. v1.0: Maybe Apple Calendar integration |
| 19 | Analytics/monitoring tools? | PostHog or Sentry (lightweight, privacy-focused) |
| 20 | CI/CD approach? | Xcode Cloud or GitHub Actions for iOS builds |

---

### 📄 ADR.md Questions (Decision Log)

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| 21 | Why this frontend over alternatives? | SwiftUI over UIKit | Modern, faster development, declarative syntax, Apple is investing heavily, good for learning |
| 22 | Why this backend/database choice? | Supabase over Firebase | Already using for Closelo — consistency, open source, PostgreSQL is robust, good pricing |
| 23 | Why this auth approach? | Supabase Auth | Integrates seamlessly with Supabase backend, supports multiple providers, minimal setup |
| 24 | Key trade-offs we're accepting? | iOS only (no Android), Supabase lock-in for backend, SwiftUI learning curve if UIKit is familiar | |
| 25 | What could come back to bite us? | SwiftData (newer tech) might have bugs; Supabase free tier limits; iOS-only limits market but that's OK for learning project | |

---

### 📄 TODO.md Questions (Project Planning)

| # | Question | Answer |
|---|----------|--------|
| 26 | Hard deadline or soft target? | Soft target — learning project, quality over speed |
| 27 | Current blockers or dependencies? | Need Xcode set up, Apple Developer account for device testing ($99/year) |
| 28 | What can we ship in Week 1? | Working MVP: Create, edit, complete, delete tasks with local persistence |
| 29 | What requires learning/research first? | SwiftData basics, SwiftUI navigation patterns, Supabase Swift SDK (for v1.0) |
| 30 | Risks that could derail timeline? | Xcode/SwiftData version compatibility, Apple Developer account activation delays, learning curve on SwiftUI vs expectations |

---

### 📄 README.md Questions (Project Overview)

| # | Question | Answer |
|---|----------|--------|
| 31 | One-liner description (elevator pitch) | Simple, fast iPhone app for managing your daily tasks without the noise |
| 32 | Is this for learning, portfolio, or production revenue? | Learning — training ground for Jensen + Jon to build full-stack iOS apps before Closelo Mobile |
| 33 | Budget considerations (paid APIs, services)? | Apple Developer Program: $99/year. Supabase free tier (probably sufficient for v1.0) |
| 34 | Design inspiration/reference apps? | Apple Reminders (simplicity), Things 3 (polish), Clear (gesture-based, RIP) |
| 35 | Design system: Custom / Native / Third-party? | Native iOS design — using Apple Human Interface Guidelines |
| 36 | Dark mode from day 1? Yes / No / Later | Yes — SwiftUI makes this trivial |

---

### Appendix A — iOS-Specific Answers

| Question | Answer |
|----------|--------|
| Xcode version target? | Xcode 16+ (latest stable) |
| Minimum iOS version? | iOS 17+ (allows latest SwiftUI features) |
| iPad support? | Not for MVP — iPhone only initially |
| Widgets / Live Activities? | v1.0 consideration — not MVP |
| Push notifications? | v1.0 for due date reminders |

---

*Completed: 2026-02-06*
*Project: Docket*
