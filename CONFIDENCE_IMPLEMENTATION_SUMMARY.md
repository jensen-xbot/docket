# Confidence Scoring Implementation - Summary

## ✅ Completed

### 1. Edge Function Updated
**File:** `supabase/functions/parse-voice-tasks/index.ts`

**Changes Made:**
- Added `confidence?: "high" | "medium" | "low"` to `ParseResponse` interface
- Updated `SYSTEM_PROMPT` with comprehensive confidence scoring rules:
  - **HIGH**: Clear action verb + clear object + explicit date + no sharing intent
  - **MEDIUM**: Vague title OR inferred priority OR relative date OR share target mentioned
  - **LOW**: Missing critical info (no clear title OR no date when needed)

### 2. Confidence Scoring Rules in System Prompt
```
CONFIDENCE SCORING: Every response MUST include a "confidence" field set to "high", "medium", or "low":
- "high": Clear action verb + clear object/task + explicit date + no sharing intent
  Examples: "Call mom tomorrow high priority", "Submit report by Friday 3pm"
- "medium": Vague title OR inferred priority OR relative date (next week, this weekend) OR share target mentioned OR minor ambiguity
  Examples: "meeting with Sarah", "Costco run next week share with Mike"
- "low": Missing critical info (no clear title OR no date when one seems needed) OR high ambiguity
  Examples: "add a task", "remind me", "do that thing"
```

### 3. Response Format Examples Updated
All response format examples in the system prompt now include the `confidence` field:
```json
{"type": "question", "text": "...", "confidence": "low"}
{"type": "complete", "tasks": [...], "summary": "...", "confidence": "high"}
{"type": "update", "taskId": "...", "changes": {...}, "summary": "...", "confidence": "high"}
```

### 4. Test Script Created
**File:** `supabase/functions/parse-voice-tasks/test-confidence.ts`

Includes 10 test cases covering:
- High confidence (clear action, object, date)
- Medium confidence (vague title, relative date, sharing)
- Low confidence (missing info, ambiguous)

## 📊 Test Cases

| # | Utterance | Expected | Reason |
|---|-----------|----------|--------|
| 1 | "Call mom tomorrow high priority" | HIGH | Clear task + explicit date |
| 2 | "meeting with Sarah" | MEDIUM | Vague, no date, people context |
| 3 | "add a task" | LOW | Missing title and date |
| 4 | "Costco run next week share with Mike" | MEDIUM | Relative date + sharing |
| 5 | "Submit quarterly report by Friday 3pm" | HIGH | Clear action + date/time |
| 6 | "Remind me to do something important" | LOW | Vague object, no date |
| 7 | "Buy groceries this weekend" | MEDIUM | Relative date |
| 8 | "Book dentist for March 15th urgent" | HIGH | Clear + explicit date |
| 9 | "That thing we talked about" | LOW | Extremely vague |
| 10 | "Walk the dog" | MEDIUM | Clear but no date |

## 🚀 Deployment Instructions

### Prerequisites
Ensure you have:
- Supabase CLI installed
- Access to the Docket Supabase project
- `OPENROUTER_API_KEY` environment variable set

### Deploy Command
```bash
cd /home/jensen/.openclaw/workspace/projects/docket
supabase login
supabase link --project-ref <your-project-ref>
supabase functions deploy parse-voice-tasks
```

### Testing After Deploy
```bash
cd /home/jensen/.openclaw/workspace/projects/docket
# Create .env.local with OPENROUTER_API_KEY
deno run --allow-net --allow-env --allow-read supabase/functions/parse-voice-tasks/test-confidence.ts
```

## ⚙️ Constraints Met

| Constraint | Status | Notes |
|------------|--------|-------|
| Backward compatibility | ✅ | New optional field, existing behavior unchanged |
| Latency < 2000ms | ⏳ | To be verified after deployment |
| Existing prompt behavior | ✅ | No breaking changes to existing functionality |

## 📝 API Response Example

After deployment, responses will include the confidence field:

```json
{
  "type": "complete",
  "tasks": [{
    "id": "uuid",
    "title": "Call mom",
    "dueDate": "2026-02-15",
    "priority": "high"
  }],
  "summary": "I've created a high priority task to call mom for tomorrow. Will this be all?",
  "confidence": "high"
}
```

## 🔄 Next Steps

1. **Deploy** the Edge Function using `supabase functions deploy parse-voice-tasks`
2. **Run tests** using the test script to verify confidence accuracy
3. **Update iOS app** Swift models to include the new `confidence` field (Agent B task)
4. **Monitor** latency metrics to ensure <2000ms requirement

## 📁 Files Changed

- `supabase/functions/parse-voice-tasks/index.ts` - Added confidence scoring
- `supabase/functions/parse-voice-tasks/test-confidence.ts` - Test script (created)
- `supabase/config.toml` - Initialized for deployment

---
*Implementation complete. Ready for deployment.*
