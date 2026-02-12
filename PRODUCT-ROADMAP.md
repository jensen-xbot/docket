# Docket Product Roadmap

Competitive analysis vs Todoist, Things 3, TickTick, Apple Reminders, Any.do, and Microsoft To Do. Last updated Feb 2026.

---

## Docket's Unique Strengths

- **Conversational voice-to-task** — Multi-turn AI, follow-up questions, natural speech capture. No competitor has equivalent.
- **Voice personalization** — Learns vocabulary, category mappings, store aliases from corrections. Improves over time.
- **Voice corrections** — Mid-conversation edits ("actually make it Wednesday"). Seamless.
- **Grocery templates via voice** — "Costco run" → loads template. Store-specific, AI-aware.
- **On-device transcription** — SFSpeechRecognizer, free, fast, privacy-preserving.

---

## Tier 1: High-Impact Gaps (Table Stakes)

### 1. "Today" / "Upcoming" Smart Views
**Status:** Not implemented  
**Competitors:** Todoist (Today, Upcoming), Things 3 (Today, Upcoming, Anytime), TickTick (Today, Tomorrow, Next 7 Days), Apple Reminders (Today, Scheduled)

**Current state:** All / Active / Completed filters only. No date-focused view.

**Proposal:** Add "Today" as default landing view — tasks due today. Add "Upcoming" grouped by date (Tomorrow, This Week, Next Week). This is the screen users live in daily.

### 2. Home Screen & Lock Screen Widgets
**Status:** In TODO  
**Competitors:** All major task apps have widgets

**Proposal:** Home screen widget showing today's tasks + quick-add. Lock screen widget (iOS 16+) with task count. Major engagement driver.

### 3. Calendar View
**Status:** Not implemented  
**Competitors:** TickTick (full calendar), Todoist (date grouping), Things 3 (calendar integration)

**Proposal:** "This week" timeline view or EventKit integration to show tasks alongside calendar events. Critical for busy professionals juggling work, side projects, family.

### 4. Flexible Reminders
**Status:** Partial — Profile has "Default Reminder" (15 min, 1 hr, 1 day before) but NotificationManager only fires at due date

**Competitors:** Multiple reminders per task, location-based, custom snooze

**Proposal:** Wire up Profile's reminder setting to schedule notifications X minutes/hours before due date. Future: location-based reminders, snooze options.

### 5. Apple Watch
**Status:** In TODO  
**Competitors:** Things 3, Todoist both have Watch apps

**Proposal:** Wrist capture for "2–3 taps to create." Voice from wrist via Siri Shortcut integration.

---

## Tier 2: Meaningful Differentiators

### 6. Unified AI Command Bar
**Status:** Planned — full spec in [UNIFIED-AI-COMMAND-BAR.md](UNIFIED-AI-COMMAND-BAR.md), TODO.md § Phase 13  
**Competitors:** Todoist (smart text parsing), ChatGPT (unified voice/text input), Arc (command bar)

**Current state:** Separate search bar, mic toolbar button, "+" toolbar button. Voice and text are disconnected.

**Proposal:** Single bottom-positioned command bar ("Ask Docket"). One input, three modes (voice, text, +). Type or speak to create/find/manage tasks. Same `parse-voice-tasks` Edge Function for both. Search implicit in text mode (always-on filtering while typing). "+" long-press for Manual Task or Attach Picture. Absorbs Smart Text Parsing entirely and partially absorbs Natural Language Quick-Add.

### 7. Projects / Lists (Beyond Single-Category)
**Status:** Not implemented  
**Competitors:** Projects as containers for related tasks

**Current state:** Categories only (Work, Personal). No project-like grouping.

**Proposal:** Add "Projects" or "Lists" — containers for related tasks. Enables "Closelo Launch" with 15 tasks. Categories remain cross-cutting labels.

### 8. Tags (Multi-Label)
**Status:** Not implemented — one category per task only  
**Competitors:** Todoist, Things 3 support multiple tags

**Proposal:** Allow multiple tags per task. Enables filtering like "urgent + Closelo." Becomes important as task count grows.

### 9. Activity Log + AI Catch-Up Summaries (Sharing V3)
**Status:** Planned — full spec in TODO.md § Sharing System V3  
**Competitors:** Todoist (activity log), Asana (activity + comments), Notion (page history), Linear (activity feed)

**Current state:** 1:1 sharing only, LWW, no change history.

**Proposal (6 phases):**
1. **Multi-person sharing** — N collaborators per task, role-based (owner/editor/viewer), assignee
2. **Activity log** — Per-field change tracking (`task_activity` table), who changed what when
3. **AI catch-up card** — When user opens a task with unseen changes, show AI summary ("Sarah moved due date to Friday and added 3 items") with expandable full diff
4. **Morning digest** — Daily push notification with AI summary of all shared task changes, grouped by task
5. **Comments + @mentions** — Threaded discussion within tasks, @mention for targeted notifications
6. **Per-task notification controls** — All / Mentions only / Muted. Read receipts (opt-in). Digest timing preferences.

This is a significant differentiator. No lightweight task app (Todoist, Things 3, TickTick) has AI-summarized activity. Asana/Linear have activity logs but no AI condensation. The "catch-up card" — collapsed AI summary with expandable raw changelog — is genuinely novel for task management.

### 10. Messaging Platform Integrations (Sharing V3, Phase 7)
**Status:** Planned — full spec in TODO.md § Sharing System V3 Phase 7  
**Competitors:** Todoist (Slack, Teams, IFTTT, Zapier), Asana (Slack, Teams, 200+ integrations), Linear (Slack, Discord, Zapier), ClickUp (Slack, Teams, Discord, webhooks)

**Current state:** No external integrations. Notifications are push-only.

**Proposal:**
- **Outgoing:** Task changes, @mentions, AI morning digest → Slack DM/channel, Teams chat, Discord DM/channel
- **Incoming:** Slash commands (`/docket add ...`, `/docket done ...`), bot action buttons (Mark Complete, Snooze)
- **Rich cards:** Slack Block Kit, Teams Adaptive Cards, Discord embeds with task preview + action buttons
- **Generic webhooks:** Zapier/Make/n8n support via documented JSON payload + HMAC-SHA256 signature
- **Voice-aware:** "Send the grocery list to the family Slack channel" or "Notify Mike on Teams"
- **Architecture:** Event system → platform adapters. Adding a new platform = new formatter, not new plumbing.

This is table stakes for team adoption. Every competitor with collaboration features has Slack/Teams integration. The differentiator is voice-triggered cross-platform actions and AI digest delivery to channels.

### 11. Attachments / Images
**Status:** Not implemented  
**Competitors:** Todoist, TickTick, Any.do support photos/files

**Proposal:** Attach photos or files to tasks. Use cases: whiteboard photo, screenshot, receipt.

---

## Tier 3: Nice-to-Have / Competitive Extras

### 12. Natural Language Quick-Add from Anywhere
**Proposal:** Global quick-add — notification center widget or persistent entry point. Type task from any screen without opening app. **Partially absorbed by Unified AI Command Bar** (bar is always visible on main screen).

### 13. Batch Operations
**Proposal:** Select multiple tasks → bulk complete, move category, reschedule, delete. Useful for backlog processing.

### 14. Task Duration / Time Estimates
**Proposal:** "This task will take 30 minutes." Pairs with calendar view for time-blocking. TickTick, Sunsama have this.

### 15. Completed Task Statistics
**Proposal:** "You completed 23 tasks this week" with streaks. Surface Phase 10 metrics to user, not just internal. Drives retention.

### 16. Start Dates vs Due Dates
**Proposal:** Things 3 distinguishes "when to start" from "when it's due." Useful for longer-horizon tasks.

### 17. Undo
**Proposal:** Shake-to-undo or toast with "Undo" after complete/delete. Apple Reminders does this. Prevents accidental data loss.

### 18. Web / Mac App
**Proposal:** Docket is iOS-only. Simple web app or Mac Catalyst for capture from desk. Reduces friction for "pull out phone" moment.

---

## Recommended Priority Order

For Docket's identity as **fast, voice-first daily task manager for busy professionals**:

| Priority | Feature | Rationale |
|----------|---------|-----------|
| 1 | **Unified AI Command Bar** | Primary interaction surface. Absorbs search, mic, +. Voice + text unified. |
| 2 | **Today view** | Default landing page. The screen users open every morning. |
| 3 | **Widgets** | Lock screen + home screen. Keeps Docket visible without opening app. |
| 4 | **Flexible reminders** | Profile setting exists — wire it up in NotificationManager. |
| 5 | **Calendar view** | "Next 7 days" grouped view. Critical for daily planning. |
| 6 | **Sharing V3** | Multi-person + AI catch-up summaries + messaging integrations. Major differentiator. |
| 7 | Apple Watch | Wrist capture. |
| 8 | Projects / Lists | Juggling multiple workstreams. |
| 9 | **Slack / Teams / Discord** | Deliver where teams already work. Table stakes for team adoption. |
| 10 | Tags | Multi-label filtering. |
| 11 | Attachments | Increasingly expected. |

---

## Cross-Reference with TODO.md

- **Phase 13 (Unified AI Command Bar):** Bottom command bar, voice + text unified, search implicit. Full spec in [UNIFIED-AI-COMMAND-BAR.md](UNIFIED-AI-COMMAND-BAR.md).
- **Phase 11 (Inline Task Cards):** Voice UX polish — aligns with "differentiation" not "catch-up"
- **Phase 12 (Advanced Subtasks):** Competitive with Todoist/Things 3 nesting
- **Sharing V3 (6 phases):** Multi-person sharing, activity log, AI catch-up cards, morning digest, comments + @mentions, per-task notification controls. Full spec in TODO.md.
- **v1.3 (Progress System):** Already in data model; UI polish
- **Widgets, Apple Watch, App Store:** In Future / v2.0
