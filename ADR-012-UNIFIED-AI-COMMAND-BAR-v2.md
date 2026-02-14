# ADR-012: Unified AI Command Bar v2.0 — Confidence-Based UX

**Status:** Accepted  
**Date:** 2026-02-14  
**Supercedes:** Unified AI Command Bar v1.0 design philosophy

---

## Context

The original Unified AI Command Bar design (v1.0) aimed to consolidate search, voice, and manual task creation into a single bottom-positioned input. However, early review identified several UX risks:

1. **Over-promising:** "Ask Docket anything" placeholder set expectations for general AI capabilities beyond task management
2. **Mode confusion:** Implicit search while typing created ambiguity between filtering and AI submission
3. **Confirmation fatigue:** Every task required full confirmation, causing users to tap without reading
4. **Modal fatigue:** Full-screen conversation view interrupted task list context unnecessarily

This ADR addresses these issues with a confidence-based, inline-first design.

---

## Decision

Implement **Command Bar v2.0** with the following changes:

1. **Constrained scope:** Change placeholder to "What do you need to get done?" — explicit task creation focus
2. **Separated concerns:** Remove implicit search from Command Bar (search stays in toolbar via SearchBar)
3. **Confidence-based confirmation:** Three-tier system (high/medium/low) with appropriate UX for each
4. **Inline-first:** Keep users in context; only expand to full conversation for multi-turn dialogues
5. **Visible manual entry:** [+] button always visible, single-tap to AddTaskView
6. **Visual mode distinction:** Voice mode has distinct visual treatment (pulsing orb, TTS prompt)

---

## Options Considered

### Option A: Keep v1.0 Design (Status Quo)
- **Pros:** Already documented, conceptually simple
- **Cons:** Over-promises, mode confusion, confirmation/modal fatigue
- **Decision:** Rejected — UX research shows these patterns fail in production

### Option B: Separate Search + Command Bar (Selected)
- **Pros:** Clear separation of concerns, confidence-based flow reduces friction, inline-first preserves context
- **Cons:** More complex state machine, requires confidence calibration tuning
- **Decision:** Accepted — best balance of user experience and technical feasibility

### Option C: Raycast-Style Command Palette
- **Pros:** Familiar pattern, deterministic results
- **Cons:** Doesn't suit AI's probabilistic nature; no place for conversation
- **Decision:** Rejected — AI needs conversation affordances

### Option D: Full-Page Chat (ChatGPT Style)
- **Pros:** Clear AI context, lots of space
- **Cons:** Total context switch; users lose sight of task list
- **Decision:** Rejected — too heavy for quick task capture

---

## Confidence Levels

| Tier | Criteria | UX Treatment | Estimated Frequency |
|------|----------|--------------|---------------------|
| **High** | Clear title + explicit date + no sharing | Auto-accept, toast confirmation, task appears inline | 70% |
| **Medium** | Vague title OR inferred priority OR relative date | Inline confirmation card (bottom bar stays compact) | 25% |
| **Low** | Missing critical info OR significant ambiguity | Expanded conversation, AI asks follow-up | 5% |

### Confidence Detection

Edge Function prompt addition:
```
Assess confidence level:
- "high": User provided explicit, unambiguous task with clear date
- "medium": Task clear but some inference needed (priority, exact date)
- "low": Missing required information or contradictory input

Return: { ..., confidence: "high" | "medium" | "low" }
```

---

## Implementation Changes

### ParseResponse Model Changes
```swift
struct ParseResponse: Codable {
    let type: String           // "question", "complete", "update", "delete"
    let confidence: String?    // "high", "medium", "low" (new)
    let text: String?
    let tasks: [ParsedTask]?
    let summary: String?
    // ... existing fields
}
```

### UI Components

1. **CommandBarView** — Container managing collapsed/expanded states
2. **CommandBarCollapsed** — Idle state, text input, inline confirmation
3. **InlineConfirmationCard** — Medium confidence preview with actions
4. **CommandBarExpanded** — Full conversation (low confidence/questions)
5. **VoiceModeView** — Distinct visual treatment for voice

### State Machine

```
Collapsed
    ├── [+] tapped → AddTaskView
    ├── Field tapped → TextInputMode
    │       └── Submit → ParseResponse
    │               ├── High confidence → Toast + Collapsed
    │               ├── Medium confidence → InlineCard + (Accept→Collapsed)
    │               └── Low confidence → Expanded
    └── Mic tapped → VoiceMode
```

---

## Consequences

### Positive
- **Reduced friction:** 70% of tasks auto-accepted with toast
- **Clear mental model:** Users understand Command Bar = task creation only
- **Context preservation:** Inline-first keeps users in task list
- **Clearer affordances:** Visible [+] button, distinct voice mode

### Negative
- **Increased complexity:** Three-tier confidence system requires tuning
- **State machine complexity:** More states to manage than simple modal
- **Calibration risk:** Confidence thresholds may need adjustment post-launch

### Migration
- Existing voice flows remain valid (use low-confidence expanded mode)
- VoiceRecordingView deprecated; logic absorbed into CommandBarView
- Search refactoring already done (separate branch)

---

## Related Documents
- Full v2.0 spec: [UNIFIED-AI-COMMAND-BAR-v2.md](UNIFIED-AI-COMMAND-BAR-v2.md)
- Original spec: [UNIFIED-AI-COMMAND-BAR.md](UNIFIED-AI-COMMAND-BAR.md)
- Search refactor: [SEARCH_REFACTOR_PLAN.md](SEARCH_REFACTOR_PLAN.md)

---

## Open Questions

1. **Confidence threshold calibration:** May need user testing to tune high/medium/low boundaries
2. **Auto-accept with sharing:** Should sharing intent downgrade to medium confidence automatically?
3. **Progressive disclosure:** Should we show more fields (notes, checklist) inline on confirmation card?

---

**Approved by:** Jensen (with Jon's direction to iterate based on UX review)
