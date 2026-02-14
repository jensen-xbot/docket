# Confidence Scoring Implementation - Summary

## Overview
Added confidence scoring to the `parse-voice-tasks` Edge Function to help the Docket iOS app understand how well the user's voice input was parsed.

## Changes Made

### 1. Modified `supabase/functions/parse-voice-tasks/index.ts`

#### Added `confidence` field to ParseResponse interface:
```typescript
interface ParseResponse {
  type: "question" | "complete" | "update" | "delete";
  text?: string;
  tasks?: ParsedTask[];
  taskId?: string;
  changes?: TaskChanges;
  summary?: string;
  confidence?: "high" | "medium" | "low";  // ← NEW FIELD
}
```

#### Updated SYSTEM_PROMPT with confidence scoring rules:
- Added a new "CONFIDENCE SCORING" section that instructs the AI to assess confidence
- Defined clear rules for each confidence level:
  - **HIGH**: Clear action verb + clear object/task + explicit date + no sharing intent
  - **MEDIUM**: Vague title OR inferred priority OR relative date OR share target mentioned
  - **LOW**: Missing critical info (no clear title OR no date when one seems needed)
- Updated all JSON response examples to include the confidence field

## Confidence Rules

| Level | Criteria | Examples |
|-------|----------|----------|
| **HIGH** | Explicit action verb + clear object + explicit date + no sharing intent | "Call mom tomorrow high priority" |
| **MEDIUM** | Vague title OR inferred priority OR relative date OR share target mentioned | "meeting with Sarah", "Costco run next week share with Mike" |
| **LOW** | Missing critical info (no clear title OR no date when one seems needed) | "add a task", "remind me" |

## Backward Compatibility

✅ **Fully backward compatible** - The `confidence` field is optional in the response. Existing clients that don't expect this field will continue to work without modification.

## Testing

### Test Scripts Created

1. **`test-confidence-node.js`** - Node.js test script that tests the system prompt directly via OpenRouter API
2. **`test-deployed.sh`** - Bash script to test the deployed Edge Function via HTTP requests

### Test Cases (10 scenarios)

| # | Utterance | Expected Confidence |
|---|-----------|-------------------|
| 1 | "Call mom tomorrow high priority" | HIGH |
| 2 | "meeting with Sarah" | MEDIUM |
| 3 | "add a task" | LOW |
| 4 | "Costco run next week share with Mike" | MEDIUM |
| 5 | "Submit the quarterly report by Friday at 3pm" | HIGH |
| 6 | "Remind me to do something important" | LOW |
| 7 | "Buy groceries this weekend" | MEDIUM |
| 8 | "Book dentist appointment for March 15th urgent" | HIGH |
| 9 | "That thing we talked about" | LOW |
| 10 | "Walk the dog" | MEDIUM |

## Deployment Instructions

### Prerequisites
- Supabase CLI installed and authenticated
- OpenRouter API key configured in Supabase secrets

### Deploy Command
```bash
cd /home/jensen/.openclaw/workspace/projects/docket
supabase functions deploy parse-voice-tasks
```

### Verify Deployment
```bash
# Check function status
supabase functions list

# View function logs
supabase functions logs parse-voice-tasks
```

## Testing After Deployment

### Option 1: Using the Bash Script
```bash
export SUPABASE_ANON_KEY=your_anon_key
export SUPABASE_URL=https://your-project.supabase.co
./supabase/functions/parse-voice-tasks/test-deployed.sh
```

### Option 2: Using curl
```bash
curl -X POST "https://your-project.supabase.co/functions/v1/parse-voice-tasks" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Call mom tomorrow high priority"}],
    "today": "2026-02-14",
    "timezone": "America/New_York"
  }'
```

Expected response:
```json
{
  "type": "complete",
  "tasks": [...],
  "summary": "I've created a high priority task to call mom for tomorrow. Will this be all?",
  "confidence": "high"
}
```

## Latency Considerations

The confidence scoring is assessed by the AI model as part of the existing response generation. No additional API calls are made.

- **Target latency**: <2000ms (unchanged)
- **No additional latency** introduced by confidence scoring

## Future Enhancements

The confidence field can be used by the iOS app to:
- Show visual indicators (e.g., green/yellow/red confidence bars)
- Prompt users for clarification on low-confidence parses
- Track and improve voice recognition accuracy over time
- Surface personalization opportunities

## Files Modified

- `supabase/functions/parse-voice-tasks/index.ts` - Added confidence field and updated prompt

## Files Created

- `supabase/functions/parse-voice-tasks/test-confidence.ts` - Deno test script
- `supabase/functions/parse-voice-tasks/test-confidence-node.js` - Node.js test script
- `supabase/functions/parse-voice-tasks/test-deployed.sh` - Bash test script for deployed function
- `CONFIDENCE_SCORING_SUMMARY.md` - This document
