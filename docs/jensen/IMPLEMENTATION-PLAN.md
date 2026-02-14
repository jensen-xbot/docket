# Implementation Plan: Overnight Development Pipeline

**Created:** 2026-02-14  
**Target:** Complete Command Bar v2.0 Foundation  
**Approach:** Parallel sub-agent development with cron-scheduled orchestration

---

## Architecture: Agent Farm

Instead of one long-running agent, I'll spawn **focused sub-agents** for specific tasks. Each runs independently and reports back.

### Sub-Agent Design Pattern

```
Main Session (Me)
    │
    ├── Cron: Every 2 hours → Check task status
    │
    ├── Spawn Agent A → Edge Functions
    │   ├── Task: Update parse-voice-tasks
    │   ├── Duration: ~2 hours
    │   └── Report: PR description + test results
    │
    ├── Spawn Agent B → Swift Models
    │   ├── Task: Update ParseResponse + confidence
    │   ├── Duration: ~1 hour
    │   └── Report: Model changes + tests
    │
    ├── Spawn Agent C → UI Components
    │   ├── Task: CommandBarCollapsed + InlineCard
    │   ├── Duration: ~4 hours
    │   └── Report: Component preview + video/gif
    │
    └── Spawn Agent D → Integration
        ├── Task: TaskListView integration
        ├── Duration: ~2 hours
        └── Report: Integration test results
```

---

## Task Decomposition

### Agent A: Edge Function Confidence (2-3 hours)
**Model:** minimax/minimax-m2.5 (coding specialist)  
**Scope:**
- Modify `supabase/functions/parse-voice-tasks/index.ts`
- Add confidence scoring to system prompt
- Test with 10 utterance variations
- Deploy to staging
- **Deliverable:** Deployed Edge Function with confidence field

### Agent B: Swift Models (1-2 hours)
**Model:** moonshotai/kimi-k2.5 (general purpose)  
**Scope:**
- Update `Models/ParsedTask.swift` → Add `confidence` to ParseResponse
- Backward compatibility handling
- Unit tests for confidence enum
- **Deliverable:** PR with model changes

### Agent C: Collapsed Bar UI (4-5 hours)
**Model:** minimax/minimax-m2.5 (coding specialist)  
**Scope:**
- Create `Views/CommandBarCollapsed.swift`
- Multi-line text input (iMessage-style)
- [+] button with navigation
- Mic/Submit button morph animation
- Styling, layout, safe areas
- **Deliverable:** Working UI component + preview

### Agent D: Integration (2-3 hours)
**Model:** moonshotai/kimi-k2.5 (general purpose)  
**Scope:**
- Main `CommandBarView` container
- State machine enum
- TaskListView safeAreaInset
- Remove deprecated mic/+ buttons
- **Deliverable:** Integrated component in app

---

## Cron Schedule

### Immediate (Now - 09:30 UTC)
- Commit and push documentation
- Create `feature/command-bar-v2` branch
- Merge search refactor branch
- First agent spawn: Edge Functions

### 10:00 UTC (Jon asleep)
- Cron check: Edge Function status
- If complete → Spawn Agent B (Models)
- If not → Wake event to review

### 12:00 UTC (Middle of night)
- Cron check: All agents status
- Spawn Agent C (UI) if Agent A/B complete
- Progress report message (but Jon is asleep)

### 14:00 UTC (Early morning)
- Cron check: UI component status
- Spawn Agent D (Integration)
- Prepare morning summary

### 16:00 UTC (Jon waking up)
- Cron: Send morning summary
- Show progress, blockers, next steps
- Ask for decisions on any issues

### Overnight (2-hour intervals)
- Hourly heartbeat from agents
- Auto-retry failed agents
- Document progress in session logs

---

## Communication Protocol

### Agent Reporting Format

Each sub-agent will report with:

```
## Agent X: [Task Name] Complete

### Deliverables
- [ ] Code written
- [ ] Tests passing
- [ ] Documentation updated

### Files Changed
- File1.swift (lines X-Y)
- File2.ts (lines A-B)

### Video/GIF
[MEDIA: /path/to/demo.gif]

### Blockers
- None / [Description]

### Time Taken
X hours Y minutes

### Next Steps
- [What's needed next]
```

### My Role

I am the **conductor**, not the individual contributor:
- Spawn agents with clear tasks
- Review deliverables
- Resolve conflicts between agents
- Make architectural decisions
- Report to Jon

---

## Risk Mitigation

### Risk: Agent gets stuck
**Mitigation:** 2-hour timeout, then auto-kill and respawn with simpler task

### Risk: Agents conflict on same files
**Mitigation:** Clear file ownership per agent, use edit tool carefully

### Risk: Edge Function deployment fails
**Mitigation:** Agent A retries 3x, then escalates to me for manual review

### Risk: Swift compilation errors
**Mitigation:** Each agent runs `xcodebuild` or `swift build` before completion

---

## Morning Deliverable for Jon

By the time Jon wakes up (~16:00 UTC), I will have:

1. **Phase P0 Complete** (Foundation)
   - [x] Edge Function with confidence scoring
   - [x] Swift models updated
   - [x] CommandBarView shell

2. **Phase P1 Started** (Collapsed Bar)
   - [x] UI component structure
   - [x] Basic animations
   - [~] Text input mode (in progress)

3. **Documentation**
   - [x] Updated ADR-012
   - [x] Implementation notes
   - [x] Known issues / TODOs

4. **Summary Report**
   - What was completed
   - What's in progress
   - Blockers requiring Jon's input
   - Recommendations for next steps

5. **Demo Content**
   - Screenshots/GIFs of progress
   - Test results
   - Confidence calibration examples

---

## Tools & Access

**Available to Agents:**
- Read/Edit/Write tools
- Exec (build, test, git)
- Web search (for SwiftUI patterns)
- Sessions spawn (but not needed for sub-agents)

**Not Available:**
- Browser automation (not needed)
- Direct Supabase dashboard access
- App Store Connect

**I Have Access To:**
- Everything
- Final PR approval
- Merge decisions
- Communication with Jon

---

## Success Criteria for Overnight Work

- [ ] Edge Function confidence scoring deployed
- [ ] Swift models compile with new confidence field
- [ ] CommandBarView structure in place
- [ ] Collapsed bar UI visible in app
- [ ] No breaking changes to existing functionality
- [ ] Documentation complete
- [ ] Morning summary ready for Jon

---

**Total Estimated Progress by Morning:** 40-50% of Command Bar v2.0

**Confidence Level:** High (agents are focused, tasks are clear)

**Jon's Input Needed:** None during overnight (I have authority to implement v2.0 design). Blockers will wait for morning.

---

*Plan created by Jensen*  
*Ready to execute*
