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

### v1.0 Definition of Done
- Sync across devices via backend
- Due dates with notifications
- Categories/projects for organization
- Priority levels (high/medium/low)
- Recurring tasks

## Feature Requirements

### Must-Have (MVP)
1. Create task with title
2. Edit task
3. Mark complete/incomplete
4. Delete task
5. View all tasks (active + completed)
6. Local persistence (SwiftData)

### Should-Have (v1.0)
1. Due dates
2. Categories/tags
3. Priority levels
4. Cloud sync (Supabase)
5. Push notifications for due dates

### Could-Have (Future)
1. Siri shortcuts
2. Widgets
3. Apple Watch app
4. Subtasks
5. Collaboration/sharing

### Won't-Have (Explicitly Out of Scope)
1. Collaboration/multi-user
2. Natural language input
3. AI suggestions
4. Advanced filtering/search
5. Attachments/files

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
