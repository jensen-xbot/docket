# PRD: Docket

## Overview
Simple, fast iPhone app for managing daily tasks without the noise. Replaces scattered notes and mental load with organized, actionable lists.

## Target User
Jon — a busy professional juggling sales work, side projects (Closelo), family, and personal routines. Needs quick capture and clear organization without friction.

## Success Criteria

### MVP Definition of Done
- Can create, edit, complete, and delete tasks
- Tasks persist locally
- Clean, native iOS UI
- Single user, no backend needed

### v1.0 Definition of Done (Cloud Sync Foundation)
- Cloud sync across devices (Supabase)
- User authentication (Apple Sign In + email)
- Bi-directional sync with offline support
- Due dates with local notifications (date + optional time)
- Priority levels (high/medium/low)
- Categories for organization
- Pin + manual reorder
- Grocery/Shopping templates + checklists
- Task sharing with contacts (invite-gated for new contacts; immediate for accepted contacts; bilateral edits)
- Push notifications for new shared tasks (APNs)
- Profile hub for templates + notifications + contacts
- Zero data loss guarantee

### v1.1 Definition of Done (Voice-to-Task)
- Voice-to-task: Press button, speak naturally, confirm → task created
- Visual confirmation (preview card, tap to confirm)
- Natural language parsing: Extract title, due date, priority, category, notes, share target
- Apple SFSpeechRecognizer for transcription (on-device) with optional Whisper fallback
- gpt-4.1-mini via OpenRouter → Supabase Edge Function for parsing
- OpenAI TTS for natural voice readback (AVSpeechSynthesizer fallback)
- Voice task updates ("move dentist to Thursday") and deletion ("delete the Costco task")
- Voice grocery list management (templates + ad-hoc items)
- English only for v1.1

## Feature Requirements

### Must-Have (MVP)
1. Create task with title
2. Edit task
3. Mark complete/incomplete
4. Delete task
5. View all tasks (active + completed)
6. Local persistence (SwiftData)

### Should-Have (v1.0) - Cloud Sync Foundation
1. **Cloud sync across devices** (Primary v1.0 Feature)
2. User authentication (Apple Sign In)
3. Due dates + time toggle
4. Categories/tags
5. Priority levels
6. Local notifications
7. Pin + manual reorder
8. Grocery/Shopping templates + checklist items
9. Task sharing (email + text invite flow; invite-gated for new contacts, immediate for accepted contacts)
10. Push notifications for shared tasks
11. Profile hub (templates, notifications, contacts)

### Should-Have (v1.1) - Voice-to-Task
1. **Voice-to-Task** (Primary v1.1 Feature)
2. Apple SFSpeechRecognizer transcription (on-device) with optional Whisper fallback
3. Visual confirmation flow
4. Natural language task parsing (gpt-4.1-mini via Edge Function)
5. OpenAI TTS readback (natural voices) with Apple AVSpeechSynthesizer fallback
6. Voice task updates and deletion
7. Voice grocery list management (templates + ad-hoc items)
8. Notification inbox/bell with invite accept/decline
9. Bilateral edits on shared tasks (last-write-wins)
10. Supabase Realtime subscriptions for shared tasks

### Could-Have (v1.2+)
1. Siri shortcuts
2. Advanced voice parsing (recurring, subtasks)
3. Personalization adaptation loop (learn from corrections)
4. Widgets
5. Apple Watch app
6. Multiple languages for voice

### Won't-Have (Explicitly Out of Scope)
1. AI suggestions beyond voice parsing
2. Advanced filtering/search
3. Attachments/files

## User Flows

### 1. Quick Capture
Open app → Tap + → Type → Save (2-3 taps)

### 2. Daily Review
Open app → See today's tasks → Mark done

### 3. Organize
Add category → Move tasks → Set priorities

## Success Metrics

### MVP
- Can create and complete a task within 3 taps

### v1.0
- Zero data loss
- Instant sync (<1s)
- <100ms UI response time
