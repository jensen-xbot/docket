# Build Verification Log

**Project:** Docket iOS  
**Purpose:** Track all new files and modifications for Xcode project.pbxproj integration

---

## Module 0: Repo Cleanup
**Commit:** TBD  
**New .swift files:** None  
**Modified .swift files:** None  
**New imports/frameworks:** None  
**New @State/@Binding on existing views:** None  
**Known gaps:** None  
**Expected behavior:** Repo cleanup only — no code changes

---

## Module 1: Wire confidence routing in handleCommandSubmit
**Commit:** TBD  
**New .swift files:** None (modifications only)  
**Modified .swift files:**
- `Docket/Docket/Views/TaskListView.swift` — wire VoiceTaskParser, confidence routing
**New imports/frameworks:** None  
**New @State/@Binding on existing views:** None (already added)  
**Known gaps:** VoiceTaskParser.send() error handling needs testing  
**Expected behavior:** 
- High confidence → QuickAcceptToast → auto-save
- Medium confidence → InlineConfirmationBar
- Low confidence → CommandBarExpanded opens

---

## Module 2: Inline edit mode for medium confidence
**Commit:** TBD  
**New .swift files:**
- `Docket/Docket/Views/InlineTaskEditView.swift` — Editable task card with title, date, priority, category
**Modified .swift files:**
- `Docket/Docket/Views/TaskListView.swift` — add edit flow handler
- `Docket/Docket/Views/InlineConfirmationBar.swift` — wire edit action
**New imports/frameworks:** None  
**New @State/@Binding on existing views:**
- `TaskListView`: `@State private var showingInlineEdit = false`
**Known gaps:** Category picker needs CategoryStore integration test  
**Expected behavior:** Edit card expands with editable fields, save/cancel works

---

## Module 3: Expanded conversation for low confidence / questions
**Commit:** TBD  
**New .swift files:** None (uses existing CommandBarExpanded, ConversationView)  
**Modified .swift files:**
- `Docket/Docket/Views/TaskListView.swift` — wire conversation flow, messages array management
- `Docket/Docket/Views/CommandBarExpanded.swift` — conversation handling, reply flow
**New imports/frameworks:** None  
**New @State/@Binding on existing views:**
- `TaskListView`: `@State private var conversationMessages: [ConversationMessage] = []`
**Known gaps:** Scroll-to-bottom behavior needs verification  
**Expected behavior:** 
- Low confidence opens expanded view with chat
- User can type replies
- AI responses appended to conversation
- On complete, routes through confidence flow

---

## Module 4: Voice mode integration into CommandBar
**Commit:** TBD  
**New .swift files:**
- `Docket/Docket/Views/CommandBarVoiceMode.swift` — Voice mode container (migrated from VoiceRecordingView)
**Modified .swift files:**
- `Docket/Docket/Views/CommandBarView.swift` — add voice button tap handler
- `Docket/Docket/Views/TaskListView.swift` — integrate voice mode state
- `Docket/Docket/Views/CommandBarExpanded.swift` — show voice UI when in voice mode
**New imports/frameworks:**
- `Speech` (if not already imported)
- `AVFoundation` (if not already imported)
**New @State/@Binding on existing views:**
- `TaskListView`: `@State private var isVoiceModeActive = false`
- `CommandBarView`: `@Binding var isVoiceModeActive: Bool`
**Known gaps:** Audio session management (record/playback switching) needs device testing  
**Expected behavior:**
- Tap voice button → expands → mic activates → TTS greeting plays
- Voice transcription appears as chat bubble
- After transcription → send to Edge Function → confidence flow
- TTS reads AI responses
- Text input always available

---

## Module 5: Polish + deprecation cleanup
**Commit:** TBD  
**New .swift files:** None  
**Modified .swift files:**
- `Docket/Docket/Views/TaskListView.swift` — remove toolbar mic button, remove toolbar + button, update EmptyListView CTA
- `Docket/Docket/Views/EmptyListView.swift` — update text to reference command bar
**New imports/frameworks:** None  
**New @State/@Binding on existing views:** None (removing state)
**Known gaps:** Need to verify swipe-down dismiss gesture works  
**Expected behavior:**
- Toolbar only has filter, bell, profile
- EmptyListView points to command bar
- One-shot high confidence auto-collapses bar
- Swipe down dismisses expanded view

---

## Module 6: Integration documentation
**Commit:** TBD  
**New .swift files:**
- `Docket/Docket/Views/INTEGRATION_GUIDE.swift` (documentation file)
**Modified .swift files:** None  
**New imports/frameworks:** None  
**New @State/@Binding on existing views:** None  
**Known gaps:** None  
**Expected behavior:** Documentation only

---

## Module 7: Today View spec
**Commit:** TBD  
**New .swift files:** None (documentation only)  
**Modified .swift files:** None  
**New imports/frameworks:** None  
**New @State/@Binding on existing views:** None  
**Known gaps:** None  
**Expected behavior:** Plan document created at docs/jensen/TODAY-VIEW-PLAN.md

---

## Module 8: TodayView.swift
**Commit:** TBD  
**New .swift files:**
- `Docket/Docket/Views/TodayView.swift` — Today view with sections
**Modified .swift files:** None (new view)  
**New imports/frameworks:** None  
**New @State/@Binding on existing views:** None  
**Known gaps:** Section header styling needs visual QA  
**Expected behavior:**
- Sections: Overdue (red), Due Today, No Due Date (collapsed)
- Reuses TaskRowView
- Pull-to-refresh works
- CommandBar visible at bottom

---

## Module 9: Navigation — make Today the default landing
**Commit:** TBD  
**New .swift files:** None  
**Modified .swift files:**
- `Docket/Docket/DocketApp.swift` — add view switcher, default to Today
- `Docket/Docket/Views/TodayView.swift` — add view switcher UI
- `Docket/Docket/Views/TaskListView.swift` — ensure toolbar consistency  
**New imports/frameworks:** None  
**New @State/@Binding on existing views:**
- `DocketApp`: `@State private var selectedView: ViewTab = .today`
**Known gaps:** State restoration (remember last view) not implemented  
**Expected behavior:**
- Today is default on launch
- Segment control switches between Today | All Tasks
- Both views have CommandBar

---

## Module 10: Upcoming view (if time permits)
**Commit:** TBD  
**New .swift files:**
- `Docket/Docket/Views/UpcomingView.swift` — Upcoming tasks grouped by date
**Modified .swift files:**
- `Docket/Docket/DocketApp.swift` — add Upcoming to view switcher  
**New imports/frameworks:** None  
**New @State/@Binding on existing views:** None  
**Known gaps:** None  
**Expected behavior:**
- Groups: Tomorrow, This Week, Next Week, Later
- Same patterns as Today view

---

## Summary: Files to Add to project.pbxproj

### New Files (in order of addition):
1. `InlineTaskEditView.swift` (Module 2)
2. `CommandBarVoiceMode.swift` (Module 4)
3. `TodayView.swift` (Module 8)
4. `UpcomingView.swift` (Module 10, optional)

### Modified Files (no pbxproj changes needed):
- `TaskListView.swift` (Modules 1-5)
- `CommandBarView.swift` (Module 4)
- `CommandBarExpanded.swift` (Modules 3-4)
- `InlineConfirmationBar.swift` (Module 2)
- `EmptyListView.swift` (Module 5)
- `DocketApp.swift` (Modules 9-10)

### New State Variables (for manual verification):
- `TaskListView.showingInlineEdit: Bool`
- `TaskListView.conversationMessages: [ConversationMessage]`
- `TaskListView.isVoiceModeActive: Bool`
- `DocketApp.selectedView: ViewTab`

---

*Last updated: 2026-02-14*
