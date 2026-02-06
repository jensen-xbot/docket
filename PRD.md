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
- Voice-to-task: Press button, speak naturally, confirm → task created
- Agent confirmation: System confirms task details before creation
- Natural language parsing: Extract title, due date, priority from speech
- Cloud sync across devices (Supabase)
- Due dates with notifications
- Priority levels (high/medium/low)
- Categories for organization

## Feature Requirements

### Must-Have (MVP)
1. Create task with title
2. Edit task
3. Mark complete/incomplete
4. Delete task
5. View all tasks (active + completed)
6. Local persistence (SwiftData)

### Should-Have (v1.0)
1. **Voice-to-Task (Primary v1.0 Feature)**
2. Due dates
3. Categories/tags
4. Priority levels
5. Cloud sync (Supabase)

### Could-Have (Future)
1. Push notifications for due dates
2. Siri shortcuts
3. Widgets
4. Apple Watch app
5. Subtasks
6. Recurring tasks
7. Collaboration/sharing

### Won't-Have (Explicitly Out of Scope)
1. Collaboration/multi-user
2. AI suggestions beyond voice parsing
3. Advanced filtering/search
4. Attachments/files

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
