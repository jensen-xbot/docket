# Docket

Simple, fast iPhone app for managing your daily tasks without the noise.

## Description

Docket replaces scattered notes and mental load with organized, actionable lists. Built for busy professionals who need quick capture and clear organization without friction.

## Why This Exists

This is a learning project — a training ground for building full-stack iOS apps before tackling Closelo Mobile. Focus is on:
- Mastering SwiftUI
- Understanding SwiftData
- Integrating Supabase for cloud sync
- Shipping a complete, polished app

## Tech Stack

- **Frontend:** SwiftUI (iOS 17+)
- **Database:** SwiftData + Supabase (sync)
- **Auth:** Supabase Auth (Apple, email magic link)
- **Notifications:** UserNotifications (local) + APNs (push for shared tasks)
- **Sharing:** MessageUI (email + SMS), Contacts framework (contact picker), Supabase Edge Functions (share push)
- **Platform:** iOS (iPhone)

## Project Structure

```
docket/
├── PRD.md              # Product Requirements Document
├── ADR.md              # Architecture Decision Records
├── TECH-STACK.md       # Technology choices
├── TODO.md             # Living task list
├── QUESTIONNAIRE.md    # Discovery answers
└── Docket/             # Xcode project
```

## Design Inspiration

- Apple Reminders (simplicity)
- Things 3 (polish)
- Clear (gesture-based, RIP)

## Project Links

- **Repository:** https://github.com/jensen-xbot/docket
- **Project Kanban:** https://github.com/users/jensen-xbot/projects/2

## Roadmap

### MVP (Now)
- Create, edit, complete, delete tasks
- Local persistence + cloud sync
- Clean native iOS UI
- Due dates + local notifications
- Categories + priorities
- Pin + manual reorder
- Grocery/Shopping templates + checklists
- Task sharing (email + text invite flow, auto-accept)
- Profile hub (templates, notifications, contacts)

## Getting Started

Requirements:
- Xcode 16+
- iOS 17+ device or simulator
- Apple Developer account (for device testing)

Steps:
1. Open `Docket/Docket.xcodeproj`
2. Add the Supabase SDK via SPM (see `SUPABASE_SETUP.md`)
3. Build + run on a simulator or device

### Sharing + Push Notifications Setup
1. Apply migration `supabase/migrations/010_sharing_v2.sql`
2. Deploy Edge Function: `supabase functions deploy push-share-notification`
3. Add APNs secrets in Supabase Edge Functions settings
4. Create DB webhook for `task_shares` INSERT → Edge Function
5. Enable **Push Notifications** capability in Xcode

## Budget

- Apple Developer Program: $99/year
- Supabase: Free tier (sufficient for v1.0)

---

Built with ⚡ by Jensen for Jon
