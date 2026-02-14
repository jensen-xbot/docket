#!/bin/bash
#
# Test confidence scoring on deployed Supabase Edge Function
#
# Usage:
#   export SUPABASE_ANON_KEY=your_anon_key
#   export SUPABASE_URL=https://your-project.supabase.co
#   ./test-deployed.sh

SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$1}"
SUPABASE_URL="${SUPABASE_URL:-$2}"

if [ -z "$SUPABASE_ANON_KEY" ] || [ -z "$SUPABASE_URL" ]; then
  echo "Usage: SUPABASE_ANON_KEY=<key> SUPABASE_URL=<url> ./test-deployed.sh"
  echo "Or:    ./test-deployed.sh <anon_key> <supabase_url>"
  exit 1
fi

FUNCTION_URL="${SUPABASE_URL}/functions/v1/parse-voice-tasks"

echo "🧪 Testing Deployed Edge Function: parse-voice-tasks"
echo "URL: $FUNCTION_URL"
echo ""

# Test cases
declare -a TESTS=(
  "Call mom tomorrow high priority|high"
  "meeting with Sarah|medium"
  "add a task|low"
  "Costco run next week share with Mike|medium"
  "Submit the quarterly report by Friday at 3pm|high"
)

total_latency=0
correct=0
count=0

for test in "${TESTS[@]}"; do
  IFS='|' read -r utterance expected <<< "$test"
  
  echo "Test $((++count)): \"$utterance\""
  echo "  Expected: $expected"
  
  # Build JSON payload
  payload=$(cat <<EOF
{
  "messages": [{"role": "user", "content": "$utterance"}],
  "today": "2026-02-14",
  "timezone": "America/New_York"
}
EOF
)

  start_time=$(date +%s%N)
  
  response=$(curl -s -X POST "$FUNCTION_URL" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>/dev/null)
  
  end_time=$(date +%s%N)
  latency=$(( (end_time - start_time) / 1000000 )) # Convert to ms
  total_latency=$((total_latency + latency))
  
  # Extract confidence from response
  actual=$(echo "$response" | grep -o '"confidence"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
  
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ Actual: $actual (${latency}ms)"
    ((correct++))
  else
    echo "  ❌ Actual: ${actual:-missing} (${latency}ms)"
  fi
  
  echo "  Response: $response" | head -c 200
  echo "..."
  echo ""
  
  sleep 0.5
done

avg_latency=$((total_latency / count))

echo "────────────────────────────────────────"
echo "📊 SUMMARY"
echo "Accuracy: $correct/$count"
echo "Avg latency: ${avg_latency}ms"
echo "Target: <2000ms"

if [ $avg_latency -gt 2000 ]; then
  echo "⚠️  WARNING: Latency exceeds target"
fi
