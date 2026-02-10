# Docket Project - Workflow Documentation

## Project Overview
- **Name:** Docket
- **Type:** iOS Todo App (MVP → v1.0)
- **Purpose:** Learning project for SwiftUI/SwiftData before Closelo Mobile
- **Status:** ✅ MVP Complete, Awaiting Testing

---

## Established Framework

### 1. Modular Build Approach

**Phases:**
- Phase 1: Foundation (Models, Utils, Core)
- Phase 2: Core UI (Views, ViewModels)
- Phase 3: Polish (Animations, UX)
- Phase 4: Testing (Device, Accessibility)

**Each Module:**
1. Prerequisites defined
2. Acceptance criteria clear
3. Files created in proper folders
4. Committed to git
5. Logged in MODULE-LOG.md

### 2. Development Workflow

```
AGENT WORKFLOW:
1. Read docs (DEVELOPMENT.md, .cursorrules)
2. Build module(s)
3. Commit: "Module X.Y: Description"
4. Push to GitHub
5. Update MODULE-LOG.md
6. Notify user

USER WORKFLOW:
1. Pull latest code
2. Build in Xcode
3. Test on device/simulator
4. Report: [PASS] / [FIX] / [CHANGE]
5. Iterate or advance
```

### 3. Documentation Standards

**Required Files:**
- `README.md` - Project overview
- `DEVELOPMENT.md` - Modular roadmap
- `MODULE-LOG.md` - Build progress (MUST update status)
- `.cursorrules` - Coding standards
- `PRD.md`, `ADR.md`, `TECH-STACK.md`, `TODO.md` - Planning docs

**MODULE-LOG.md Format:**
```markdown
## Build Status: ✅ COMPLETE  (or 🔄 IN PROGRESS)
```

### 4. Proactive PM Monitor

**Job:** `docket-proactive-pm`  
**Frequency:** Every 5 minutes  
**Logic:**
- Fast-exit if status is COMPLETE
- Deep check only if IN PROGRESS
- Notify on stalls or issues
- Silent when all good

**Setup for future projects:** See `PROJECT-MONITOR-TEMPLATE.md`

### 5. Communication Protocol

**Agent → User:**
- Module complete: "Phase X Module Y complete. Ready for testing."
- Issues found: "[FIX NEEDED] + details"
- Status update: Brief summary + next step

**User → Agent:**
- `[PASS]` - Move to next module
- `[FIX]` - Issue details + error messages
- `[CHANGE]` - Desired modifications

---

## Lessons Learned

### What Worked
1. ✅ Modular approach - clear scope per module
2. ✅ MODULE-LOG.md - easy status tracking
3. ✅ .cursorrules - consistent code style
4. ✅ Proactive PM - catches stalls automatically
5. ✅ Git-based handoff - no file passing needed

### What to Improve
1. ⚠️ Subagent errors - direct coding more reliable
2. ⚠️ Cron wake delays - need "now" mode for immediate checks
3. ⚠️ Xcode project structure - need .xcodeproj generation

### Critical Xcode Project Lesson (2026-02-06)

**Problem:** App rendered in a tiny "card" with black bars, looking like an iPhone 4 app on modern devices.

**Root cause:** The `.xcodeproj` was missing `INFOPLIST_KEY_UILaunchScreen_Generation = YES` in the target build settings. Without this key, iOS assumes the app was built for legacy screen sizes and runs it in a letterboxed compatibility mode.

**Fix:** Add these keys to **both Debug and Release** target build configurations:

```
INFOPLIST_KEY_UILaunchScreen_Generation = YES;
INFOPLIST_KEY_CFBundleDisplayName = <AppName>;
INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
```

Also ensure `Assets.xcassets` contains an `AppIcon.appiconset/Contents.json` (even if empty) when `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` is set.

**How to verify:** After adding, delete the app from the simulator/device, Clean Build Folder (Shift+Cmd+K), and run again. The app should fill the full screen edge-to-edge.

**Rule for future projects:** When generating an `.xcodeproj` by hand (not through Xcode's "New Project" wizard), always include `UILaunchScreen_Generation = YES`. Xcode sets this automatically when you create a project through the GUI, but it's easy to miss when building the project file programmatically.

### Framework Updates Made
1. Updated PROJECT-MONITOR-TEMPLATE.md to v1.2 (fast-exit)
2. Established MODULE-LOG.md status convention
3. Created reusable PM monitor pattern
4. Documented agent/user workflow

---

## Current State (2026-02-09)

**Build Status:** ✅ COMPLETE  
**Phase:** 1-4 All Done; Sharing System V2 implemented  
**Active Initiative:** Sharing System V2 — invite gating, notifications inbox, realtime sync  
**Next Step:** Phased QA matrix (owner/recipient, online/offline/reconnect)  
**Monitor:** Active, fast-exit mode

---

## Replicating This Framework

For new projects (like Closelo Mobile):

1. **Copy documentation structure:**
   ```
   README.md
   DEVELOPMENT.md (with modular roadmap)
   MODULE-LOG.md
   .cursorrules
   PRD/ADR/TECH-STACK/TODO.md
   ```

2. **Set up PM Monitor:**
   ```bash
   openclaw cron add --name "{project}-pm" \
     --every 5m --isolated \
     --announce telegram:{chat_id} \
     --message "PM logic from TEMPLATE"
   ```

3. **Follow modular workflow:**
   - Build sequentially
   - Commit per module
   - Update MODULE-LOG status
   - User tests before advancing

4. **Iterate and improve:**
   - Document lessons in framework templates
   - Update PROJECT-MONITOR-TEMPLATE.md
   - Refine .cursorrules per project type

---

*This workflow documentation is part of the starter package framework*