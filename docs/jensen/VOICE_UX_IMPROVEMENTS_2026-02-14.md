# Voice Task UX Improvements

**Date:** 2026-02-14  
**Branch:** feature/command-bar-v2

---

## Summary

Improvements to reduce conversational turns, improve AI inference, and make voice capture faster when the user taps the voice button.

---

## 1. Edge Function Prompt Updates

**File:** `supabase/functions/parse-voice-tasks/index.ts`

### 1.1 Terminology (Event / Meeting / Appointment)

- "Event", "meeting", "appointment", "reminder" now treated identically as "task"
- User can say "make an event" or "schedule a meeting" — same extraction logic
- Responses use natural language ("I've added...", "I've scheduled...")

### 1.2 Time Phrase Inference

- "lunch" / "lunchtime" → 12:00 (noon)
- "morning" → 9:00
- "afternoon" → 14:00 or 15:00
- "evening" → 18:00
- "dinnertime" / "dinner" → 18:00 or 19:00
- "breakfast" → 8:00 or 9:00
- Only asks "what time?" when truly ambiguous ("sometime tomorrow", "later")

### 1.3 User Correction Handling

- Phrases like "I asked you to X", "I said X", "I meant X" are treated as the missing information
- Example: "I asked you to meet with David" → title = "Meeting with David", proceed

### 1.4 Consolidated Follow-Up Questions

- When multiple fields are missing, asks in one question when possible
- Example: "What would you like to schedule for tomorrow, and what time?" instead of two separate questions

### 1.5 Multi-Turn Consolidation

- Consolidates partial info across turns
- Example: Turn 1 "tomorrow" + Turn 2 "lunch with David" → date + time (noon) + title → return type "complete" immediately

### 1.6 Closing Question Wording

- For type "complete": "Anything else?" or "Anything to change?" (replaces "Would you like to make any changes?")
- Consistency with update/delete flows

---

## 2. iOS UI Changes

### 2.1 Command Bar Expanded Title

**File:** `Docket/Docket/Views/CommandBarExpanded.swift`

- Changed header from "Task Assistant" to "Ask Docket" (per UNIFIED-AI-COMMAND-BAR.md design)

### 2.2 Voice Auto-Start

**File:** `Docket/Docket/Views/VoiceRecordingView.swift`

- When user taps voice button in command bar → VoiceRecordingView sheet opens
- **Auto-starts recording** immediately after permissions granted (no mic tap required)
- **Optimized sequence:**
  1. Prefetch voice profile (runs in parallel — ready by first utterance)
  2. Request microphone + speech recognition permissions
  3. Auto-start recording so user can speak immediately

---

## 3. Deployment

- Edge Function deployed: `supabase functions deploy parse-voice-tasks --no-verify-jwt`
- iOS build verified: `xcodebuild -project Docket.xcodeproj -scheme Docket -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

---

## 4. Manual Test Flow

Expected flow for "meeting with David tomorrow at noon":

1. "Hey, could you make an event for tomorrow"
2. "I asked you to meet with David"
3. "Lunch time"

**Before:** 5 turns (AI asked for title, then time, then "noon or different time?")  
**After:** 2–3 turns max (lunch inferred as noon, no redundant questions)

---

## Cross-References

- [UNIFIED-AI-COMMAND-BAR.md](UNIFIED-AI-COMMAND-BAR.md) — Command bar design
- [NEEDS_TESTING.md](NEEDS_TESTING.md) — Test checklist
- [VOICE-TO-TASK-V2.md](../../VOICE-TO-TASK-V2.md) — Voice architecture
