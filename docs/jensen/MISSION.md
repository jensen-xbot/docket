# MISSION: Finish Command Bar v2 + Build Today View

**Date:** 2026-02-14
**Agent:** Jensen (main) + Coding sub-agent + QA sub-agent
**Branch:** feature/command-bar-v2 (continue from latest commit)
**Repo:** /home/jensen/.openclaw/workspace/projects/docket

---

## OVERVIEW

Complete the Unified AI Command Bar v2 implementation (Phase 13) and build the Today View (Tier 1 roadmap item). Work autonomously, follow the module-by-module workflow below, then shut down and provide a report.

---

## CRITICAL CONSTRAINT: NO XCODE

You are on Linux. You CANNOT verify Swift builds. This means:
- Write clean, compilable Swift. Use proper imports, follow existing code patterns in the repo.
- NEVER modify Docket.xcodeproj/project.pbxproj — you can't verify it. Instead, document every new .swift file in BUILD_VERIFICATION.md so the human adds them in Xcode.
- Build in small, isolated modules. One concern per commit.
- The human will pull your branch on macOS, build in Xcode, and fix any compile errors.

---

## WORKFLOW (follow for every module)

1. **PLAN:** Write a brief plan for the module (what, why, which files)
2. **IMPLEMENT:** Write the code (one module, one concern)
3. **COMMIT:** Atomic commit: feat(command-bar-v2): Module N — [description]
4. **VERIFY DOC:** Append to docs/jensen/BUILD_VERIFICATION.md
5. **TEST DOC:** Append to docs/jensen/NEEDS_TESTING.md
6. **GITHUB ISSUE:** Create an issue with gh issue create --repo jensen-xbot/docket --title "Module N: [name]" --label "command-bar-v2" --body "[acceptance criteria]"
7. **MOVE TO NEXT MODULE**

---

## PHASE 0: CLEANUP (do first)

### Module 0: Repo cleanup + doc organization

1. Remove node_modules from git tracking:
   - Add "node_modules/" to .gitignore
   - Run: git rm -r --cached node_modules/

2. Move Jensen-specific docs into docs/jensen/:
   - JENSEN_SUGGESTIONS_V3.md → docs/jensen/
   - FINAL_REPORT.md → docs/jensen/reports/
   - CONFIDENCE_IMPLEMENTATION_SUMMARY.md → docs/jensen/
   - CONFIDENCE_SCORING_SUMMARY.md → docs/jensen/
   - IMPLEMENTATION-PLAN.md → docs/jensen/
   - SEARCH_REFACTOR_PLAN.md → docs/jensen/
   - TODO-v2-COMMAND-BAR.md → docs/jensen/COMMAND-BAR-V2-PLAN.md
   - UNIFIED-AI-COMMAND-BAR-v2.md → docs/jensen/
   - ADR-012-UNIFIED-AI-COMMAND-BAR-v2.md → docs/jensen/
   - PR_DESCRIPTION.md → docs/jensen/
   - TASKS/ → docs/jensen/tasks/

3. Create docs/jensen/BUILD_VERIFICATION.md with template header

4. Create docs/jensen/NEEDS_TESTING.md with template header

5. Commit: chore: Clean up repo — remove node_modules from tracking, organize docs into docs/jensen/

---

## PHASE 1: FINISH COMMAND BAR v2

Read these files for full context before starting:
- .cursorrules (project conventions, data models, voice-first mandate)
- UNIFIED-AI-COMMAND-BAR.md (original UX spec — this is your north star)
- docs/jensen/COMMAND-BAR-V2-PLAN.md (your previous plan, after move)
- TODO.md § Phase 13 (task checklist)
- VOICE-TO-TASK-V2.md (voice architecture)

### What's Already Done (don't redo):
- Edge Function confidence scoring (parse-voice-tasks updated with confidence field)
- ParsedTask.swift: ConfidenceLevel enum + ParseResponse confidence property
- CommandBarView.swift (collapsed bar shell)
- CommandBarExpanded.swift (expanded conversation shell)
- ConversationView.swift (chat UI)
- ConfidenceComponents.swift (QuickAcceptToast, InlineConfirmationBar, ConfidenceIndicator)
- GrowingTextField, MessageBubble, PlusButton, SearchBar, VoiceButton, VoiceModeContainer
- Task 1: CommandBarView wired into TaskListView (done + QA'd + fixed)
- Task 2: Confidence flow initial implementation
- ParsedTaskTests.swift

### Remaining Modules:

**Module 1: Wire confidence routing in handleCommandSubmit**

Connect the actual confidence-based response handling in TaskListView:
- Import and use VoiceTaskParser to send messages[] to the parse-voice-tasks Edge Function
- High confidence (type: "complete", confidence: "high") → call saveTasks() immediately → show QuickAcceptToast → auto-collapse bar after ~1s
- Medium confidence (type: "complete", confidence: "medium") → show InlineConfirmationBar above the command bar → user confirms, edits, or cancels
- Low confidence (type: "question" or confidence: "low") → expand into CommandBarExpanded for multi-turn conversation
- Reference existing saveTasks() logic in VoiceRecordingView.swift for how to save ParsedTasks to SwiftData + SyncEngine
- Handle errors gracefully (show error toast, don't crash)

**Module 2: Inline edit mode for medium confidence**

When user taps edit on InlineConfirmationBar:
- Card expands with editable fields: title (TextField), due date (compact DatePicker), priority (segmented picker: low/medium/high), category (chip picker using existing categories)
- Save button: applies edits to the ParsedTask, then saves to SwiftData + SyncEngine, collapses
- Cancel button: dismisses card, returns to idle
- Follow existing EditTaskView.swift patterns for field layout

**Module 3: Expanded conversation for low confidence / questions**

When confidence is low or response type is "question":
- CommandBarExpanded opens with the conversation so far as chat bubbles
- Text input bar at bottom for user to type follow-up replies
- Each reply appends to messages[] array, sends to Edge Function, shows response
- Continue until AI returns type: "complete" → then route through confidence flow (high/medium/low)
- Or user dismisses (swipe down or tap X)
- Reuse ConversationView.swift for the chat bubble display
- Same displayMessages pattern from VoiceRecordingView (unified IDs to prevent flicker)

**Module 4: Voice mode integration into CommandBar**

Absorb VoiceRecordingView's voice logic into CommandBar:
- Tap 5-bars (voice button) → bar expands → mic activates → TTS plays greeting
- Reuse SpeechRecognitionManager for transcription
- Reuse TTSManager for readback
- Reuse IntentClassifier for local intent detection (dismiss, confirm, thanks)
- Live transcription appears as chat bubble (same pattern as VoiceRecordingView)
- After transcription commits → send to Edge Function → route response through confidence flow
- TTS reads back AI responses in voice mode (not in text mode)
- Text input bar visible at bottom during voice mode (user can switch to typing mid-conversation)
- Same messages[] array for both voice and text input
- Reference VoiceRecordingView.swift extensively — you're moving its logic, not rewriting it

**Module 5: Polish + deprecation cleanup**

- Remove toolbar mic button (showingVoiceRecording state and .sheet presentation)
- Remove toolbar "+" button (AddTaskView still accessible via CommandBar's "+" long-press)
- Toolbar should only have: filter, bell, profile
- Update EmptyListView.swift: CTA text should say "Tap below to create your first task" pointing to command bar
- One-shot auto-collapse: when AI returns type "complete" on first turn with high confidence → auto-collapse bar, show toast
- Swipe-down gesture to dismiss expanded view
- Keyboard dismissal handling (tap outside to dismiss keyboard but keep bar)

**Module 6: Integration documentation**

Write docs/jensen/INTEGRATION_GUIDE.md listing:
- Every new .swift file created (full path)
- Every modified .swift file (what changed)
- Every new @State, @Binding, @Environment variable added to existing views
- Every new import statement
- The order files need to be added to project.pbxproj
- Any new SF Symbol names used
- Any new color constants or assets

---

## PHASE 2: TODAY VIEW

After Command Bar v2 is complete, create a NEW branch: feature/today-view (branched from feature/command-bar-v2).

Read PRODUCT-ROADMAP.md § "Today / Upcoming Smart Views" for context.

**Module 7: Today View spec**

Write docs/jensen/TODAY-VIEW-PLAN.md covering:
- Data model (no schema changes — filter existing tasks by dueDate)
- View hierarchy: TodayView with sections (Overdue, Due Today, Later Today if has time, No Due Date)
- Navigation: how Today integrates with TaskListView (tab/segment or filter mode)
- How CommandBar works within Today view (same bottom bar)
- Empty state design

**Module 8: TodayView.swift**

- Sections: "Overdue" (tasks past due, red header), "Due Today" (primary), "No Due Date" (gray, collapsed by default)
- Reuse TaskRowView for each task row
- Empty state: friendly message when nothing is due today
- Pull-to-refresh triggers SyncEngine.shared.pullRemoteChanges()
- CommandBar visible at bottom (same safeAreaInset pattern)
- Support both light and dark mode

**Module 9: Navigation — make Today the default landing**

- Add a view switcher: Today | All Tasks (segment control or tab)
- Today is default on app launch
- "All Tasks" shows current TaskListView behavior (all filters, all tasks)
- Preserve existing filter/sort functionality in All Tasks
- Toolbar stays the same: filter, bell, profile
- CommandBar visible in both views

**Module 10: Upcoming view (if time permits)**

- Tasks grouped by: Tomorrow, This Week, Next Week, Later
- Same section pattern as Today but broader date range
- Accessible via the view switcher: Today | Upcoming | All Tasks

---

## GITHUB PROJECT BOARD

Set up a kanban board at the start:

    gh project create --title "Docket: Command Bar v2 + Today View" --owner jensen-xbot --format board

If the above fails (permissions or feature not available), create a tracking file at docs/jensen/TASK_BOARD.md instead with columns: Backlog | In Progress | Needs Xcode Verification | Done.

Create one GitHub issue per module (Modules 0-10). Label them "command-bar-v2" or "today-view" as appropriate.

---

## DOCUMENTATION REQUIREMENTS

### docs/jensen/BUILD_VERIFICATION.md

Append after each module:

    ## Module N: [Name]
    **Commit:** [hash]
    **New .swift files:** [list each — these MUST be added to project.pbxproj by the human]
    **Modified .swift files:** [list each]
    **New imports/frameworks:** [list any]
    **New @State/@Binding on existing views:** [list variable names and which view]
    **Known gaps:** [anything you couldn't verify]
    **Expected behavior:** [what should happen in Simulator]

### docs/jensen/NEEDS_TESTING.md

Structure:

    ## Must Test Before Merge (build-blocking)
    - [ ] Project builds in Xcode with all new files added to pbxproj
    - [ ] [specific test per module]

    ## Should Test (functional)
    - [ ] [secondary test cases]

    ## Visual QA
    - [ ] Light mode
    - [ ] Dark mode
    - [ ] iPhone SE layout
    - [ ] iPhone 16 Pro Max layout

    ## Edge Cases
    - [ ] Offline text submission
    - [ ] App backgrounding during voice
    - [ ] Rapid mic button taps
    - [ ] Very long text input
    - [ ] Empty submission (should be prevented)

---

## COMMIT MESSAGE FORMAT

For Command Bar modules:

    feat(command-bar-v2): Module N — [short description]

    - [what changed, bullet 1]
    - [what changed, bullet 2]
    - [known limitations]

For Today View modules:

    feat(today-view): Module N — [short description]

---

## DO NOT

- Deploy any Edge Functions to production (flag as "ready to deploy" only)
- Modify project.pbxproj (document new files in BUILD_VERIFICATION.md instead)
- Force push or rewrite git history
- Write complex SwiftUI Previews that depend on model context (keep previews simple with mock data)
- Start work outside Command Bar v2 and Today View scope
- Commit node_modules or build artifacts

---

## WHEN COMPLETELY DONE

1. Push all changes on both branches
2. Write docs/jensen/reports/SESSION_REPORT.md:
   - Summary of all modules completed (with commit hashes)
   - Full list of files created and modified
   - Link to GitHub project board or issues
   - Known issues and compile risks
   - Recommended review order for the human (which module to verify first)
   - Feature recommendations for future sessions
3. Send a summary message via Telegram
4. Shut down

---

## REFERENCE FILES (read before starting)

| File | Purpose |
|------|---------|
| .cursorrules | Project conventions, data models, voice-first mandate, build verification requirement |
| UNIFIED-AI-COMMAND-BAR.md | Original Command Bar UX spec (north star) |
| TODO.md | Full project backlog, Phase 13 tasks |
| PRODUCT-ROADMAP.md | Priority order, Today view spec |
| VOICE-TO-TASK-V2.md | Voice architecture, conversation flow |
| Docket/Docket/Views/VoiceRecordingView.swift | Voice logic to absorb into CommandBar |
| Docket/Docket/Views/TaskListView.swift | Main view to integrate CommandBar into |
| Docket/Docket/Managers/VoiceTaskParser.swift | Edge Function client |
| Docket/Docket/Managers/SpeechRecognitionManager.swift | Mic + transcription |
| Docket/Docket/Managers/TTSManager.swift | Text-to-speech |
| Docket/Docket/Managers/IntentClassifier.swift | Local intent detection |
| Docket/Docket/Models/ParsedTask.swift | AI response models |
