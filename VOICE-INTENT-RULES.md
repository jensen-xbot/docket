# Voice Intent Rules

How Docket's voice assistant decides what the user means — without making an API call.

## Implementation Structure

As of ADR-009 (2026-02-11), intent classification is handled by:

- **`IntentClassifier`** (`Managers/IntentClassifier.swift`) — Pure, stateless struct. Takes `(text, context)` and returns `VoiceIntent` enum. All phrase lists and word-boundary matching live here.
- **`VoiceRecordingView`** — Calls `classifier.classify(text, context:)`, then dispatches via a `switch` on the result. No phrase logic in the view.

This separation keeps the view focused on orchestration (TTS, state, recording) while the classifier is a single, testable unit for intent rules.

## Design Principle

All control intents (confirm, reject, dismiss, gratitude) are resolved **on-device** for instant response. Only semantic task operations (create, update, delete) go to the Edge Function. This keeps the conversation snappy: "yes" after a prompt should feel instant, not wait 300–500ms for a round-trip.

---

## Conversation States

### 1. Normal Flow
The user is creating, updating, or correcting tasks. Utterances go to the AI parser.

### 2. Pending Confirmation
The AI returned parsed tasks and is waiting for the user to confirm.

**Triggers:** `parsedTasks` array is non-empty.

| User says | Intent | Action |
|---|---|---|
| "yes", "yeah", "sure", "ok", "add it", "confirm", "sounds good" | Confirm | Save tasks |
| "no", "cancel", "never mind", "forget it" | Reject | Dismiss view |
| Anything else | Correction | Send to parser as follow-up |

### 3. Closing Flow
The assistant has asked "Anything else?" or "Will this be all?" — the conversation is winding down.

**Triggers:** `isInClosingFlow = true`, set whenever we ask:
- "Done! Anything else?"
- "All N added! Anything else?"
- "Updated! Anything else?"
- "Got it. Anything else?"
- "You're welcome. Will this be all?"
- After update/delete: "I've updated X to 70%. Will this be all?" (or AI summary + client-appended "Will this be all?")

| User says | Intent | Action |
|---|---|---|
| Long response (>5 words) | New task | Reset `isInClosingFlow`, send to parser |
| Explicit dismissal (see list below) | Dismiss | Close voice view |
| Short response (≤5 words) that isn't a dismissal or self-correction | Dismiss | Close voice view (assumed affirmative) |
| Self-correction phrase (e.g. "oh sorry", "wait") | New task | Send to parser (user mid-sentence) |

**Word count is checked first.** Long responses (>5 words) are always treated as new task requests, even if they start with "no" (e.g. "No I'd like to change the Lucky Martin GB to 90%"). This prevents the window from closing when the user answers "No" to "Will this be all?" and then continues with another request.

**Why ≤5 words?** After "Anything else?" or "Will this be all?", short replies are almost always session-closing ("yes", "nope", "I'm good", "yes thank you", "that's all thanks"). A genuine new task request will be longer ("actually add a meeting with Sarah tomorrow at 3pm"). The 5-word threshold catches all common closing phrases without needing an exhaustive phrase list.

**Self-correction exclusion:** If the user says "oh sorry", "wait", "actually", "hold on", etc. (especially after a pause mid-sentence), we treat it as a new task request — they're correcting themselves, not closing. This prevents the window from closing when silence detection fires during a self-correction.

### 4. Gratitude Shortcut
When the user says "thank you" (and no tasks are pending), we don't send it to the parser. Instead, we respond warmly and ask if they need anything else.

**Triggers:** `parsedTasks` is empty AND `isGratitude(text)` matches.

**Response:** "You're welcome. Will this be all?" → enters Closing Flow.

---

## Phrase Lists

### Confirmations (`isConfirmation`)
Used in Pending Confirmation state to accept parsed tasks.

```
yes, yeah, yep, sure, ok, okay, add it, add them, add all,
confirm, sounds good, that's right, correct
```

### Rejections (`isRejection`)
Used in Pending Confirmation state to cancel.

```
no, nope, cancel, never mind, forget it, don't, stop
```

### Dismissals (`isDismissal`)
Explicit session-ending phrases. Work in any state.

```
no, nope, no thanks,
that's all, that's it,
i'm done, i'm good,
nothing, all done, all good,
bye, goodbye, see you, talk to you later
```

### Self-corrections (`isSelfCorrectionPhrase`)
Excluded from closing-flow short-reply dismiss. User is mid-sentence correcting, not closing.

```
oh sorry, sorry, wait, actually, hold on,
i mean, no wait, correction
```

### Gratitude (`isGratitude`)
Triggers the warm acknowledgment + "Will this be all?" flow.

```
thanks, thank you,
thanks a lot, thank you very much,
appreciate it, much appreciated
```

---

## Word Boundary Matching

All phrase matching uses `\b` regex word boundaries to prevent substring false positives:
- "no" does NOT match "note" or "notice"
- "done" does NOT match "undone"
- "thanks" does NOT match "thanksgiving"

Implementation: `matchesPhrase(_:phrases:)` in `IntentClassifier.swift`.

---

## Check Order in `IntentClassifier.classify()`

The order of intent checks matters. `IntentClassifier` evaluates in this sequence:

```
1. hasPendingTasks?
   a. Confirmation phrase? → .confirm
   b. Rejection phrase? → .reject
   c. Other → .taskRequest (correction)
2. isInClosingFlow?
   a. >5 words? → .taskRequest (long reply = new task, e.g. "No I'd like to change X to 90%")
   b. Explicit dismissal? → .dismiss
   c. Self-correction? → .taskRequest
   d. ≤5 words (short, not dismissal) → .dismiss (assumed affirmative closing)
3. Explicit dismissal? → .dismiss
4. Gratitude? → .gratitude
5. Default → .taskRequest
```

`VoiceRecordingView.stopRecording()` handles empty transcription first, then calls `classify()`, then dispatches via `switch intent`.

---

## State Lifecycle

```
isInClosingFlow:
  Set TRUE  → after any "Anything else?" or "Will this be all?" prompt
  Set FALSE → when user responds (either dismiss or new task)
  
  Never persists across multiple turns. Always reset on the next
  user utterance so stale state can't cause mis-classification.
```

---

## Adding New Phrases

When adding new phrases to any list:

1. **Check for overlaps.** A phrase in `isDismissal` that also matches `isConfirmation` could cause issues depending on check order.
2. **Test word boundaries.** Make sure the phrase doesn't accidentally match inside longer words.
3. **Prefer short, unambiguous phrases.** "I'm done" is better than "I think I'm done for now" (the word-count heuristic handles the long version).
4. **Don't add task-like phrases.** Never add something to dismissals that could be a task request (e.g., "nothing else, but remind me tomorrow" — the 5-word heuristic handles this by sending it to the parser).

---

## Why Not Send Everything to the AI?

Tempting, but:
- **Latency:** 300–500ms round-trip for gpt-4.1-mini. "Yes" should dismiss in <50ms, not half a second.
- **Cost:** ~$0.001/turn adds up for simple yes/no responses that don't need reasoning.
- **Reliability:** Network failures shouldn't prevent dismissing the voice view.
- **Architecture:** The `.cursorrules` spec says "deterministic control intents stay local; semantic parsing stays in Edge Function." This split keeps each layer doing what it's good at.
