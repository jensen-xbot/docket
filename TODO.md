# TODO: Docket

**Completed work:** See [TASKS_DONE.md](TASKS_DONE.md)  
**Product roadmap:** See [PRODUCT-ROADMAP.md](PRODUCT-ROADMAP.md)  
**Command Bar spec:** See [UNIFIED-AI-COMMAND-BAR.md](UNIFIED-AI-COMMAND-BAR.md)

---

## v1.1: Voice — Remaining Work

### P0: Active Stability Hotfixes

- [ ] Confirm on device under network latency and long dictation; remove debug instrumentation after validation
  - **Repro matrix (DEBUG build):** Manual vs silence stop | Whisper on/off | Natural TTS on/off | Interruption during listen/speak. Events: speech partial, silence reset/fire, stopRecording entry/exit, message append, transcribedText clear, TTS start/audio-ready/playback/finish.
- [ ] QA: phone call, Siri, AirPods during handoff
- **Residual risk:** Remove `#if DEBUG` VoiceTrace after device validation. Manual QA for interruption + long dictation recommended.

### Phase 10: Personalization — Metrics Dashboard

- [ ] Add metrics dashboard:
  - [ ] edit-after-voice rate
  - [ ] auto-confirm rate
  - [ ] turns-to-complete
  - [ ] TTS fallback rate
  - [ ] personalization hit rate (alias/mapping applied)

### Phase 11: Inline Task Cards in Voice Chat

Voice-created tasks appear as editable cards directly in the chat window. Tasks auto-save immediately AND show as inline cards that phase in one-by-one. Users can expand a card to edit or delete without leaving the voice session. Only one card expands at a time. Delete requires confirmation.

- [ ] ChatTaskCard view
  - [ ] Compact state: full-width card showing title, due date badge, priority indicator, category chip
  - [ ] Expanded state: inline edit fields (title TextField, priority picker, date picker, category chips, notes)
  - [ ] Only one card expanded at a time (tapping another collapses the current)
  - [ ] Update button: saves edits to SwiftData + SyncEngine push, collapses card
  - [ ] Delete button: shows confirmation ("Delete this task?"), removes from SwiftData + Supabase
  - [ ] Smooth expand/collapse animation (spring, ~0.3s)
- [ ] Staggered card appearance
  - [ ] After AI summary + auto-save, cards phase in one-by-one (~0.3s delay between each)
  - [ ] Transition: move from bottom + opacity fade-in
  - [ ] ScrollView auto-scrolls as each card appears
- [ ] Integration with CommandBar (expanded conversation view)
  - [ ] Insert task cards into chat after the AI summary bubble (not in displayMessages — separate rendered section)
  - [ ] Track `@State var savedTaskCards: [Task]` for cards currently visible in chat
  - [ ] Track `@State var expandedCardId: UUID?` for single-expand behavior
  - [ ] Wire up inline edits: update Task fields, push via SyncEngine, trigger voice snapshot correction detection
  - [ ] Wire up inline delete: confirmation dialog, delete from SwiftData, remove card from list
- [ ] Session continuity
  - [ ] Voice session stays open during card editing (state machine unchanged)
  - [ ] "Anything else?" TTS plays after cards finish appearing (not after each card)
  - [ ] Mic auto-restarts after TTS finishes (existing behavior preserved)
  - [ ] Conversation messages[] array intact — user can continue adding tasks or making corrections
- [ ] Voice personalization hook
  - [ ] Inline edits to voice-created tasks trigger correction detection (same as EditTaskView)
  - [ ] Compare edited fields against voiceSnapshotData, fire-and-forget to record-corrections

### Phase 12: Advanced Subtasks (Unlimited Nesting)

Full subtask support: each subtask is a full Task with title, due dates, priority, notes, collaboration — unlimited nesting depth. Voice + manual creation.

- [ ] Data model
  - [ ] Add `parentTaskId: UUID?` to Task (nil = top-level task)
  - [ ] Self-referential relationship for unlimited nesting
  - [ ] Computed helpers: `depth`, `root`, `children` (or query via modelContext)
  - [ ] Progress auto-calculation: parent = completed subtasks / total subtasks when `isProgressEnabled`
- [ ] Database migration
  - [ ] Create `014_add_subtasks.sql`: add `parent_task_id` FK referencing `tasks(id)`, index for hierarchy queries
  - [ ] Update RLS policies for shared subtasks (inherit parent share context)
- [ ] Swift models
  - [ ] Task: `parentTaskId`, init/encode/decode updates
  - [ ] TaskDTO: `parentTaskId` (parent_task_id)
  - [ ] ParsedTask: `subtasks: [ParsedTask]?` for voice-created nested tasks
  - [ ] TaskContext + TaskChanges: include subtask info for voice updates
  - [ ] SubtaskGroup or equivalent helper for flattened tree display
- [ ] UI: Manual creation
  - [ ] AddTaskView / EditTaskView: Nested subtask list (add, reorder, delete subtasks)
  - [ ] TaskRowView: Indented subtask rows with visual hierarchy
  - [ ] TaskListView: Expand/collapse parent rows; show subtask count badge
  - [ ] Progress: Parent task auto-updates from subtask completion when progress enabled
- [ ] UI: Voice creation
  - [ ] Edge Function prompt: Parse "with subtasks", compound tasks ("Plan trip: book flight, reserve hotel, pack bags")
  - [ ] ParsedTask gains `subtasks: [ParsedTask]?` with recursive structure
  - [ ] saveTasks(): Recursive creation — parent first, then children (depth-first)
  - [ ] TaskConfirmationView: Expandable nested preview before confirm
- [ ] Collaboration
  - [ ] Subtasks inherit parent sharing (task_shares via parent)
  - [ ] Shared subtask edits propagate via Realtime; both users see nested updates
- [ ] Sync
  - [ ] SyncEngine: Push parent before children; pull maintains hierarchy
  - [ ] Offline queue: Respect parent-child order on flush

### Phase 13: Unified AI Command Bar

Replace search, toolbar mic, and toolbar "+" with a single bottom-positioned command bar. One input, three modes (voice, text, +), same conversation backend. Full spec: [UNIFIED-AI-COMMAND-BAR.md](UNIFIED-AI-COMMAND-BAR.md).

- [ ] Phase 13a: CommandBarView (collapsed bar, text input, expansion animation)
  - [ ] Bottom-positioned bar via `.safeAreaInset(edge: .bottom)`
  - [ ] Placeholder "Ask Docket anything...", (+) on left, 5-bars icon on right
  - [ ] Tap field → keyboard rises, 5-bars morphs to submit arrow (crossfade ~0.2s)
  - [ ] Field grows vertically like iMessage for multi-line input
  - [ ] Expansion animation: bar grows upward into full conversation view on submit
  - [ ] Keyboard + safe area handling (keyboardLayoutGuide, iPhone SE test)
- [ ] Phase 13b: ConversationView extraction (refactor from VoiceRecordingView)
  - [ ] Extract shared chat UI (bubbles, messages, layout) into `ConversationView`
  - [ ] Shared `displayMessages` pattern, unified ID scheme for bubbles
  - [ ] ConversationView used by both text and voice modes in expanded state
- [ ] Phase 13c: Text AI mode (wire typed input to Edge Function, no TTS)
  - [ ] Send typed text as `messages[]` to `parse-voice-tasks` (skip transcription)
  - [ ] Handle ParseResponse (question, complete, update, delete) same as voice
  - [ ] No TTS in text mode — text bubbles only
  - [ ] saveTasks(), update handler, delete handler — same logic
- [ ] Phase 13d: Voice mode integration (migrate VoiceRecordingView into CommandBar)
  - [ ] Tap 5-bars → full expansion, mic active, TTS active
  - [ ] Absorb SpeechRecognitionManager, TTSManager, IntentClassifier into CommandBar flow
  - [ ] VoiceRecordingView deprecated as standalone sheet
  - [ ] Siri Shortcut opens CommandBar in voice mode instead of sheet
- [ ] Phase 13e: Search filtering (live filter while typing, magnifying glass indicator)
  - [ ] Tasks filter live as user types (always-on, no toggle)
  - [ ] Magnifying glass indicator (blue when filtering active)
  - [ ] Single-line: filtered results prominent; multi-line: results fade
  - [ ] Pull-down within expanded conversation: search through chat history
- [ ] Phase 13f: "+" context menu (Manual Task, Attach Picture)
  - [ ] Long-press (+) → context menu
  - [ ] "Manual Task" → full AddTaskView sheet
  - [ ] "Attach Picture" → camera + photo album access (future phase)
- [ ] Phase 13g: Deprecation cleanup
  - [ ] Remove `.searchable` modifier from TaskListView
  - [ ] Remove mic toolbar button and `showingVoiceRecording` state
  - [ ] Remove "+" toolbar button (AddTaskView still available via "+" menu)
  - [ ] Toolbar: filter, bell, profile only
  - [ ] EmptyListView CTA: "Tap below to create your first task" (point to command bar)
- [ ] Phase 13h: One-shot auto-collapse (success toast for instant completions)
  - [ ] When AI returns `type: "complete"` on first turn → auto-collapse bar
  - [ ] Success toast + haptic feedback
  - [ ] Multi-turn stays open for follow-up
- [ ] Phase 13i: Mid-conversation mode switching (voice ↔ text)
  - [ ] Text input bar visible in expanded view during voice mode
  - [ ] User can type follow-up mid-conversation (and vice versa)
  - [ ] Same `messages[]` array for both modes

### Pre-Launch Hardening

- [ ] Transcription retry logic (auto-retry on transient SFSpeechRecognizer failures, max 2 retries)
- [ ] Haptic refinement (distinct patterns: success, correction, error, speech detected)
- [ ] Audio waveform visualization (animate bars with voice level during recording)
- [ ] Accessibility audit (VoiceOver on VoiceRecordingView, 44pt tap targets, Reduce Motion)
- [ ] Pre-launch test matrix:
  - [ ] Network offline during voice → offline indicator, queue for retry
  - [ ] User interrupts TTS → stops speaking, listens for new input
  - [ ] App backgrounded mid-recording → pauses, resumes on foreground
  - [ ] Very long dictation (2+ min) → no memory issues
  - [ ] Rapid mic button tap → debounces, no crash
  - [ ] AirPods connected → routes audio correctly
  - [ ] Phone call interrupts → stops recording, graceful recovery

### Optimization (post-launch)

- [ ] Task context trimming (send only incomplete + recent 7 days, cap at 20 tasks)
- [ ] Task context hash caching (skip re-sending if task list unchanged between turns)

### Analytics

- [ ] Voice session tracking (duration, tasks created, turns, TTS voice used)
- [ ] Error tracking (transcription failures, AI parse errors, TTS fallback rate)
- [ ] Engagement metrics (voice vs manual creation ratio, edit-after-voice rate)

---

## Sharing System V2 — Phase 6: QA

- [ ] Run verification matrix:
  - [ ] Owner shares to accepted contact → immediate collaboration
  - [ ] Owner shares to new contact → pending invite; recipient accept/decline
  - [ ] Both users edit same task → LWW converges on both devices
  - [ ] Push notification → opens correct destination; badge updates
  - [ ] Manual QA: owner/recipient × online/offline/reconnect

---

## Sharing System V3: Multi-Person Collaboration + Activity Intelligence

Multi-person sharing with per-user change tracking, AI-summarized activity feeds, and per-task notification controls. Transforms Docket from a personal task app into a lightweight team collaboration tool.

### Phase 1: Multi-Person Sharing

- [ ] Data model
  - [ ] `task_shares` supports N recipients per task (already 1:1 rows — extend UI to add multiple)
  - [ ] `task_collaborators` view or query: all users on a given task (owner + all accepted shares)
  - [ ] Role-based permissions: owner (full control), editor (can modify), viewer (read-only)
  - [ ] Assignment: `assignee_id` on task — shared with 5, assigned to 1 (shows assignee avatar prominently)
- [ ] Database migration
  - [ ] Add `role` column to `task_shares` (default: "editor" for backward compatibility)
  - [ ] Add `assignee_id` FK to `tasks` (nullable, references `auth.users`)
  - [ ] RLS: viewers can SELECT but not UPDATE; editors can UPDATE but not DELETE; owners have full control
- [ ] UI
  - [ ] ShareTaskView: multi-select contacts (add/remove collaborators, assign roles)
  - [ ] Task detail: collaborator avatars row (tap to see names + roles)
  - [ ] Assignment picker: "Who's responsible?" — select one assignee from collaborators
  - [ ] Voice: "Share grocery list with Sarah and Mike" → creates multiple task_shares rows

### Phase 2: Task Activity Log + Change Tracking

- [ ] Data model
  - [ ] `task_activity` table: `id`, `task_id`, `user_id`, `action` (created, updated, completed, commented, assigned, shared), `field_changed`, `old_value`, `new_value`, `created_at`
  - [ ] Trigger or Edge Function: on task UPDATE, diff changed fields and insert activity rows per field
  - [ ] Capture: title, due date, priority, category, notes, completion, assignment, progress, checklist items
- [ ] Database migration
  - [ ] Create `task_activity` table with FK to tasks and auth.users
  - [ ] RLS: visible to all collaborators on the task (join through task_shares)
  - [ ] Index on `(task_id, created_at)` for efficient timeline queries
- [ ] UI: In-Task Activity Timeline
  - [ ] ActivityTimelineView: scrollable log within task detail (below notes, above checklist)
  - [ ] Each entry: avatar + "Sarah changed due date from Feb 14 to Feb 18" + timestamp
  - [ ] Grouped by date (Today, Yesterday, Feb 10, etc.)
  - [ ] "Seen by" indicators: dim entries the current user has already viewed
- [ ] Sync
  - [ ] SyncEngine: pull activity log for shared tasks on reconnect
  - [ ] Realtime subscription on `task_activity` for live updates while viewing a task

### Phase 3: AI-Summarized Changelog ("Catch-Up" View)

- [ ] Edge Function: `summarize-task-activity`
  - [ ] Input: activity rows since user's last seen timestamp for a given task
  - [ ] Output: `{ summary: "Sarah moved the due date to Friday and added 3 checklist items. Mike marked it 60% complete.", details: [...] }`
  - [ ] Model: gpt-4.1-mini (same as voice — fast, cheap, structured)
  - [ ] Keep it short: 1-2 sentences max for the summary
- [ ] UI: Catch-Up Card
  - [ ] When user opens a task with unseen changes → show card at top of task detail
  - [ ] Collapsed: AI summary (1-2 lines) + "N changes" badge
  - [ ] Expanded (tap chevron): full activity timeline with before/after diffs per field
  - [ ] "Mark as read" dismisses the card + updates last-seen timestamp
  - [ ] Smooth expand/collapse animation (match ChatTaskCard pattern)
- [ ] Data model
  - [ ] `task_activity_seen`: `user_id`, `task_id`, `last_seen_at` — tracks per-user read position
  - [ ] Unread count: `SELECT COUNT(*) FROM task_activity WHERE task_id = ? AND created_at > last_seen_at`

### Phase 4: Morning Summary Digest

- [ ] Edge Function: `daily-activity-digest`
  - [ ] Input: all task_activity rows across user's shared tasks since last digest
  - [ ] Output: grouped AI summary per task, sorted by most activity
  - [ ] Example: "**Grocery list** — Sarah added 4 items. **Client proposal** — Mike changed due date to Monday and added notes."
  - [ ] Trigger: Supabase cron job (pg_cron) or scheduled Edge Function, runs at user's preferred time
- [ ] Digest preferences (ProfileView)
  - [ ] Timing: Morning (8am), Evening (6pm), Real-time only, Off
  - [ ] Store in `user_profiles`: `digest_preference` ("morning" | "evening" | "realtime" | "off")
  - [ ] Timezone-aware scheduling
- [ ] Delivery
  - [ ] Push notification with summary preview (truncated)
  - [ ] In-app: digest card at top of TaskListView (dismissible, "View all changes")
  - [ ] Tap → opens digest detail with per-task expandable summaries

### Phase 5: Comments + @Mentions

- [ ] Data model
  - [ ] `task_comments` table: `id`, `task_id`, `user_id`, `content`, `created_at`, `updated_at`
  - [ ] `comment_mentions` table: `comment_id`, `mentioned_user_id` (for targeted notifications)
  - [ ] RLS: visible to all task collaborators; only author can UPDATE/DELETE own comments
- [ ] UI
  - [ ] CommentsView: threaded discussion within task detail (between activity log and checklist)
  - [ ] Compose bar: text field + send button at bottom of comments section
  - [ ] @mention autocomplete: type "@" → show collaborator picker → inserts `@Sarah`
  - [ ] Comment bubbles: avatar + name + content + relative timestamp
- [ ] Notifications
  - [ ] New comment → push to all collaborators (unless muted)
  - [ ] @mention → push to mentioned user even if task is muted
  - [ ] Activity log entry: "Sarah commented: 'Can we push this to next week?'"

### Phase 6: Per-Task Notification Controls

- [ ] Data model
  - [ ] `task_notification_preferences`: `user_id`, `task_id`, `level` ("all" | "mentions" | "muted")
  - [ ] Default: "all" — every change generates a notification
  - [ ] "mentions" — only @mentions and assignment changes
  - [ ] "muted" — no notifications (still visible in morning digest unless digest is off)
- [ ] UI
  - [ ] Bell icon in task detail header → tap to cycle: All → Mentions → Muted
  - [ ] Visual indicator on muted tasks in list view (bell-slash icon)
  - [ ] Notification center: filter by task, mark all read, bulk mute
- [ ] Read receipts / "Seen by"
  - [ ] When user views a task with changes, record `last_seen_at` in `task_activity_seen`
  - [ ] Show "Seen by Sarah, Mike" subtle text below catch-up card (optional, default off)
  - [ ] Profile toggle: "Show read receipts" (privacy-respecting, off by default)

### Phase 7: Messaging Platform Integrations

Deliver Docket notifications, digests, and task actions where teams already communicate. Webhook-based architecture supports Slack, Microsoft Teams, Discord, and generic webhooks (Zapier/Make/n8n).

- [ ] Event system (foundation)
  - [ ] `task_events` internal queue: task created, updated, completed, commented, assigned, shared — fires on every mutation
  - [ ] Edge Function: `dispatch-integration-events` — reads events, fans out to connected integrations
  - [ ] Deduplication + retry logic (idempotency key per event)
  - [ ] Rate limiting per platform (Slack: 1 msg/sec/channel, Teams: similar)
- [ ] Data model
  - [ ] `user_integrations` table: `id`, `user_id`, `platform` ("slack" | "teams" | "discord" | "webhook"), `access_token`, `channel_id`, `config` (JSON), `created_at`
  - [ ] `integration_rules` table: `id`, `integration_id`, `scope` ("all_tasks" | "category" | "project"), `scope_value`, `events` (array: which event types to forward)
  - [ ] RLS: users can only see/manage their own integrations
- [ ] Outgoing: Notifications to messaging platforms
  - [ ] Task changes → Slack DM / Teams chat / Discord DM (based on user preference)
  - [ ] @mention in Docket → DM to mentioned user on their connected platform
  - [ ] Rich cards: Slack Block Kit, Teams Adaptive Cards, Discord embeds — show task title, due date, priority, action buttons
  - [ ] Action buttons: "Mark Complete", "Snooze 1hr", "Open in Docket" (deep link)
- [ ] Outgoing: Morning digest to channels
  - [ ] AI daily summary → post to connected Slack channel / Teams channel / Discord channel
  - [ ] Per-integration channel routing: user picks which channel gets the digest
  - [ ] Same AI summary content as Phase 4, reformatted for platform (Block Kit, Adaptive Card, embed)
- [ ] Incoming: Create/update tasks from messaging platforms
  - [ ] Slash commands: `/docket add Call dentist tomorrow at 3pm` → creates task via Edge Function
  - [ ] `/docket list` → shows today's tasks in ephemeral message
  - [ ] `/docket done [task name]` → marks task complete
  - [ ] Bot interaction: button clicks on rich cards trigger task actions (complete, snooze, assign)
- [ ] OAuth + Setup
  - [ ] ProfileView: "Connected Apps" section — Slack, Teams, Discord logos with connect/disconnect
  - [ ] OAuth flow: Slack (Bot Token), Teams (Azure AD), Discord (Bot Token)
  - [ ] Channel picker after auth: which channel for digest, which for all notifications
  - [ ] Test connection: send a "Docket connected!" message on setup
- [ ] Generic webhook (Zapier / Make / n8n)
  - [ ] Outgoing webhook URL: user provides endpoint, Docket POSTs event JSON on task changes
  - [ ] Payload format: `{ event, task, user, timestamp, changes }` — documented schema
  - [ ] Webhook secret for signature verification (HMAC-SHA256)
  - [ ] Enables any custom integration without platform-specific code
- [ ] Voice integration
  - [ ] "Send the grocery list to the family Slack channel" → posts task + checklist to connected channel
  - [ ] "Notify Mike on Teams about the deadline change" → sends targeted DM via integration
  - [ ] Edge Function prompt updated with integration awareness (available platforms per user)

### V3 Design Decisions to Lock

- **Conflict UX with multiple editors:** LWW still applies, but activity log shows "Sarah changed X while you were away" with old/new values — users can manually revert via edit. No merge UI (too complex for v3).
- **AI summary cost:** ~$0.0005 per catch-up summary (few activity rows → tiny prompt). Daily digest slightly more. Acceptable at scale.
- **Activity retention:** 90-day rolling window. Older entries archived/deleted. Keeps queries fast.
- **Privacy:** Activity visible only to task collaborators. Read receipts opt-in. Digest content never leaves Supabase + Edge Function boundary.
- **Integration architecture:** Webhook-first. Platform adapters are thin formatting layers over a shared event stream. Adding a new platform = new formatter, not new plumbing.
- **Integration auth:** OAuth tokens stored encrypted in `user_integrations`. Refresh handled by Edge Function. Tokens never sent to client.

---

## v1.3: Task Progress System

- [ ] Data model: Add `progressPercentage`, `isProgressEnabled`, `lastProgressUpdate` to Task + TaskDTO
- [ ] Supabase migration: `012_add_progress_tracking.sql` (progress columns + shared task Realtime trigger)
- [ ] SyncEngine: Include progress fields in push/pull
- [ ] Profile: "Track progress by default" toggle in Tasks section
- [ ] AddTaskView / EditTaskView: Per-task progress toggle (after category, before checklist/title)
- [ ] ProgressRing: Circular indicator with color coding (grey 0-25, blue 26-99, green 100)
- [ ] ProgressBar: Separator bar fill with percentage text
- [ ] ProgressSlider: Expandable 0-100% slider (single tap to reveal)
- [ ] TaskRowView: Progress ring/bar when enabled; single tap → slider, double tap → complete
- [ ] Voice: TaskContext + TaskChanges include progress; Edge Function prompt for progress voice commands
- [ ] Voice: saveTasks() + update handler apply progressTrackingDefault and progressPercentage
- [ ] Shared tasks: Both users see and update progress; Realtime trigger propagates to recipient

---

## Future / v2.0

- [ ] Widgets
- [ ] Apple Watch app
- [ ] Multiple languages for voice
- [ ] App Store submission (see APP-STORE-GUIDE.md)

---

## Technical Decisions Made

See [.cursorrules](.cursorrules) and project docs. Key references:

- **Voice UX Learnings:** `.cursorrules` § Voice UX Patterns
- **Personalization Methodology:** `.cursorrules` § Personalization Adaptation Guidelines
- **Voice Architecture:** [VOICE-TO-TASK-V2.md](VOICE-TO-TASK-V2.md)
- **Cloud Architecture:** Supabase (PostgreSQL + Auth + Realtime), bi-directional sync, offline queue

---

## Next Steps

1. Phase 10 metrics dashboard (edit-after-voice rate, personalization hit rate)
2. Phase 11: Inline task cards in voice chat
3. Phase 12: Advanced subtasks (unlimited nesting, voice + manual)
4. Sharing V2 Phase 6: QA verification matrix
5. **Sharing V3:** Multi-person collaboration + activity intelligence (see above)
6. App Store submission (see APP-STORE-GUIDE.md)
7. **Phase 13:** Unified AI Command Bar (see [UNIFIED-AI-COMMAND-BAR.md](UNIFIED-AI-COMMAND-BAR.md))
8. **Product roadmap priorities:** Today view, Widgets, Flexible reminders, Calendar view (see [PRODUCT-ROADMAP.md](PRODUCT-ROADMAP.md))
