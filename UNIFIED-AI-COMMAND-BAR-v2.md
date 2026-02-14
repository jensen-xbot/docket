# Unified AI Command Bar v2.0

**Revised design based on UX research and best practices review.**
*Status: Design Document — Implementation in Progress*

---

## The Problem with v1.0

The original "Ask Docket anything" design set wrong expectations. Users expected general AI capabilities (knowledge, open-ended queries) when the system is purpose-built for **task creation and management**. This leads to:
- Mode confusion (search vs AI vs manual entry)
- Confirmation fatigue (asking approval for everything)
- Modal takeover fatigue (full-screen interruption)

---

## v2.0 Design Philosophy

**"Create tasks faster"** — not "Ask Docket anything."

This is a **task creation accelerator**, not a general AI assistant. The design makes this constraint clear and works *with* it, not against it.

**Key Changes:**
1. **Explicit scope** — Clear, constrained prompts that set correct expectations
2. **Separated concerns** — Search stays in toolbar (already done), Command Bar is for task creation only
3. **Confidence-based UX** — Skip confirmation when AI is confident; ask when uncertain
4. **Inline-first conversation** — Keep users in context, only expand for complex flows
5. **Visible manual entry** — Don't hide "+" behind long-press

---

## Revised UX Lifecycle

### Idle State (Collapsed Bar)

```
┌─────────────────────────────────────────────────────────────┐
│  Task list (scrollable)                                     │
│  ...                                                        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [+]  "What do you need to get done?"     [🎤│]            │
└─────────────────────────────────────────────────────────────┘
```

**Changes from v1.0:**
- **Placeholder:** "What do you need to get done?" (not "Ask Docket anything")
- **Visible + button:** Single tap for manual AddTaskView (not long-press)
- **Mic icon:** Primary action on right, clearly distinct from text input
- **Submit button:** Only appears when text entered, morphs from mic

**Rationale:** 
- Manual entry must be one tap away (not hidden)
- Placeholder explicitly scopes to task creation (not general queries)
- Mic is the differentiated feature — make it prominent

---

### Text Input Mode (Single Tap)

```
┌─────────────────────────────────────────────────────────────┐
│  Task list (scrollable)                                     │
│  ...                                                        │
├─────────────────────────────────────────────────────────────┤
│  [+]  "Email client about..."                 [↑] [🎤]      │
│       ────────────────────────                              │
└─────────────────────────────────────────────────────────────┘
```

**Changes from v1.0:**
- **No implicit search** — Tasks do NOT filter while typing (search is in toolbar)
- **Multi-line expansion** — Field grows like iMessage for longer entries
- **Submit button** — Clear affordance for "send to AI"
- **Mic stays visible** — User can switch to voice mid-composition

**Interaction:**
1. Tap field → keyboard rises, placeholder clears
2. Type → no filtering happens on task list behind
3. Tap ↑ (submit) → sends to AI Edge Function
4. OR tap 🎤 → switches to voice mode, keeps text if any
5. OR tap [+] → manual AddTaskView (visible alternative)

**Rationale:**
- Removing implicit search eliminates confusion
- Clear submit action reduces accidental submissions
- Visible mode switching reduces cognitive load

---

### Response: High Confidence (Auto-Collapse with Toast)

When AI returns `complete` with high confidence (clear date, unambiguous title, no sharing):

```
┌─────────────────────────────────────────────────────────────┐
│  Task list (scrollable)                                     │
│  [NEW] Email client — Tomorrow, High priority               │
│  ...                                                        │
├─────────────────────────────────────────────────────────────┤
│  [+]  "What do you need to get done?"     [🎤]             │
└─────────────────────────────────────────────────────────────┘
│  ┌─────────────────────────────────────┐                    │
│  │  ✅ Added: Email client tomorrow    │                    │
│  └─────────────────────────────────────┘                    │
└─────────────────────────────────────────────────────────────┘
```

**Changes from v1.0:**
- **Auto-collapse** — Bar returns to idle immediately
- **Toast notification** — Brief confirmation, auto-dismisses
- **Task appears inline** — New task fades in at top of list
- **No full-screen takeover** — User stays in context

**Confidence Criteria (AI returns `confidence: "high"`):**
- Clear task title (action verb + object)
- Unambiguous date ("tomorrow", explicit date, or "today")
- No share target specified
- No contradictions in utterance

**Rationale:**
- Fast path for common case (70%+ of interactions)
- Reduces friction for power users
- Shows result immediately where user expects it

---

### Response: Medium Confidence (Inline Confirmation)

When AI is reasonably confident but something needs verification:

```
┌─────────────────────────────────────────────────────────────┐
│  Task list (scrollable)                                     │
│  ...                                                        │
├─────────────────────────────────────────────────────────────┤
│  [+]  "What do you need to get done?"     [🎤]             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │  📋 Email client about proposal                     │   │
│  │  📅 Friday (Feb 14)                                │   │
│  │  🚩 High priority                                  │   │
│  │                                                    │   │
│  │  [👍 Looks good]      [✏️ Edit]      [🗑️ Cancel] │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Changes from v1.0:**
- **Inline confirmation card** — Stays in bottom bar, doesn't take over screen
- **Quick actions** — One-tap accept, edit expands inline, cancel dismisses
- **Card persists** — Until user acts or 30s timeout

**Confidence Criteria (`confidence: "medium"`):**
- Title present but vague ("meeting" without context)
- Relative date without context ("next week" — which day?)
- Share target mentioned but needs resolution
- AI inferred priority but user didn't specify

**Rationale:**
- Keeps user in context
- Quick accept for "good enough" cases
- Easy edit for tweaks without full AddTaskView

---

### Response: Low Confidence / Question (Expanded Conversation)

When AI needs more information or significant clarification:

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  You: "Add a meeting"                                       │
│                                                             │
│  Docket: "What's the meeting about?"                       │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [+]  "Type a reply..."                       [↑] [🎤]    │
└─────────────────────────────────────────────────────────────┘
```

**Changes from v1.0:**
- **Reserved for multi-turn** — Only when AI asks follow-up questions
- **Chat bubbles** — Clear back-and-forth visual
- **Mode switching** — Can switch between text/voice at any turn
- **Dismissible** — Swipe down or tap outside to close

**Triggers for expansion:**
- AI returns `type: "question"` (needs clarification)
- AI returns `type: "complete"` with `confidence: "low"`
- User explicitly asks for conversation mode

**Rationale:**
- Full conversation UI only when needed
- Most interactions (70%+) should stay in collapsed/inline modes
- Reduces modal fatigue

---

### Voice Mode (Tap 🎤)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  🎙️ Listening...                                            │
│                                                             │
│  [Pulsing orb visualization]                                │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  "What do you need to get done?"  (TTS readback)           │
│  [Text: Cancel]                                    [🎤│]   │
└─────────────────────────────────────────────────────────────┘
```

**Changes from v1.0:**
- **Visual treatment** — Pulsing orb, different color (blue → red recording)
- **TTS readback** — AI speaks initial prompt (hands-free confirmation)
- **Cancel text** — Tap to cancel or stop speaking (silence timeout)
- **Different state** — Visually distinct from text mode

**Interaction:**
1. Tap 🎤 → Bar expands slightly, TTS says "What do you need to get done?"
2. User speaks → Real-time transcription in chat bubble
3. Silence detection → Auto-submit to AI
4. AI response → TTS readback + text bubble
5. Loop until `complete` or user dismisses

**Rationale:**
- Clear visual distinction (voice vs text)
- Hands-free from start (TTS prompt)
- Silky smooth flow: speak → process → speak

---

## Confidence-Based Confirmation System

**The Problem with v1.0:**
Every task required confirmation, leading to fatigue. Users started tapping confirm without reading.

**v2.0 Solution:** Three-tier system

| Confidence | UX Treatment | When? |
|------------|--------------|-------|
| **High** | Auto-accept, toast + inline task | Clear title, explicit date, no sharing |
| **Medium** | Inline confirmation card (bar stays collapsed) | Vague title, inferred priority, relative date |
| **Low** | Expanded conversation, AI asks follow-up | Missing critical info, ambiguity |

**AI Prompt Addition:**
```
Return confidence level based on:
- "high": Explicit task with clear date and no ambiguity
- "medium": Task inferred but needs user verification
- "low": Missing required info (title or date)
```

---

## State Machine

```
Collapsed (idle)
    │
    ├── Tap [+] ──────→ AddTaskView (traditional manual entry)
    │
    ├── Tap field ────→ Text Mode
    │                       │
    │                       Submit
    │                       │
    │                       ├── High conf ──→ Toast + Collapsed
    │                       ├── Medium conf → Inline Card → Collapsed
    │                       └── Low conf ───→ Expanded Conversation
    │                                           │
    │                                    Multi-turn loop
    │                                           │
    │                                    Complete → Collapsed
    │
    └── Tap 🎤 ───────→ Voice Mode
                            │
                            Speech detected
                            │
                            ├── High conf ──→ TTS confirmation + Collapsed
                            ├── Medium conf → TTS + Inline Card
                            └── Low conf ───→ TTS question + Expanded
```

---

## What Gets Deprecated vs Kept

### Deprecated (v1.0 → v2.0)

| v1.0 | v2.0 |
|------|------|
| "Ask Docket anything" placeholder | "What do you need to get done?" (scoped) |
| Long-press [+] for manual entry | Visible [+] button (single tap) |
| Implicit search while typing | No search in Command Bar (toolbar search only) |
| Always full-screen conversation | Inline-first, expand only for multi-turn |
| Always confirmation view | Confidence-based: auto / inline / expanded |
| Same UI for voice/text | Visually distinct modes |

### Kept

- Bottom-positioned Command Bar via `.safeAreaInset`
- Multi-mode input (voice + text + manual)
- Shared `parse-voice-tasks` Edge Function
- `messages[]` array for conversation state
- Mode switching mid-conversation
- One-shot completions (just with auto-accept added)

---

## Implementation Phases (Revised)

### Phase A: Core Collapsed Bar
- [ ] CommandBarCollapsed view
- [ ] Text input with multi-line expansion
- [ ] Visible [+] button (links to AddTaskView)
- [ ] Mic button with clear iconography
- [ ] Submit button (morphs from mic when text present)

### Phase B: Confidence System
- [ ] Add `confidence` field to ParseResponse
- [ ] Update Edge Function prompt to return confidence
- [ ] High-confidence auto-accept with toast
- [ ] Medium-confidence inline confirmation card

### Phase C: Inline Confirmation Card
- [ ] Task preview card component
- [ ] Inline edit mode (expandable fields)
- [ ] Quick action buttons (accept/edit/cancel)
- [ ] 30s auto-dismiss timeout

### Phase D: Expanded Conversation (Selective)
- [ ] CommandBarExpanded view (chat bubbles)
- [ ] Trigger only for low confidence or questions
- [ ] Swipe to dismiss
- [ ] Keyboard handling for text input while expanded

### Phase E: Voice Mode Polish
- [ ] Visual distinction (pulsing orb, different color)
- [ ] TTS initial prompt "What do you need to get done?"
- [ ] Real-time transcription bubble
- [ ] Silence detection auto-submit

### Phase F: Deprecation Cleanup
- [ ] Remove `.searchable` from TaskListView (already done in branch)
- [ ] Verify toolbar search works independently
- [ ] EmptyListView CTA points to Command Bar
- [ ] Remove mic/+ from toolbar (keeping filter, bell, profile)

---

## Testing Checklist

**Core Flows:**
- [ ] Type "Call mom tomorrow" → High confidence → Auto-accept, toast, task appears
- [ ] Type "meeting" → Medium confidence → Inline card appears → Tap accept → Task added
- [ ] Tap 🎤 → Speak "Add a task" → TTS says "What's the task?" → Speak "Grocery run" → TTS confirms
- [ ] Tap [+] → AddTaskView opens → Create task → Returns to list
- [ ] Type "Call" → No task list filtering → Submit → AI processes

**Edge Cases:**
- [ ] Switch text → voice mid-composition
- [ ] Cancel inline confirmation (should dismiss completely)
- [ ] Edit inline confirmation (should expand editable fields)
- [ ] Timeout on inline confirmation (auto-dismiss)
- [ ] High confidence with sharing (should inline confirm, not auto-accept)

---

## Success Metrics

- **Task creation time:** < 5 seconds for high-confidence cases
- **Confirmation rate:** 70%+ high confidence (auto-accept), 25% medium, 5% low
- **Voice adoption:** 40%+ of task creation via voice
- **Edit rate:** < 10% of tasks edited after voice creation

---

## Related Documents

- Original spec: [UNIFIED-AI-COMMAND-BAR.md](UNIFIED-AI-COMMAND-BAR.md)
- Voice architecture: [VOICE-TO-TASK-V2.md](VOICE-TO-TASK-V2.md)
- Search refactor (already done): [SEARCH_REFACTOR_PLAN.md](SEARCH_REFACTOR_PLAN.md)
- Product roadmap: [PRODUCT-ROADMAP.md](PRODUCT-ROADMAP.md)

---

*Document created: 2026-02-14*  
*Author: Jensen (based on UX research and best practices review)*
