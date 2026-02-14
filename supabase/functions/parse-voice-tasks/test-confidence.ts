#!/usr/bin/env deno run --allow-net --allow-env --allow-read
/**
 * Test script for confidence scoring in parse-voice-tasks Edge Function
 * 
 * Usage:
 *   cd /home/jensen/.openclaw/workspace/projects/docket
 *   deno run --allow-net --allow-env --allow-read supabase/functions/parse-voice-tasks/test-confidence.ts
 */

import { config } from "https://deno.land/x/dotenv@v3.2.2/mod.ts";

// Load environment variables from .env file
const env = config({ path: ".env.local" });

const OPENROUTER_API_KEY = env.OPENROUTER_API_KEY || Deno.env.get("OPENROUTER_API_KEY");
const SUPABASE_URL = env.SUPABASE_URL || Deno.env.get("SUPABASE_URL");
const MODEL = env.OPENROUTER_MODEL || "openai/gpt-4.1-mini";

if (!OPENROUTER_API_KEY) {
  console.error("❌ Missing OPENROUTER_API_KEY");
  Deno.exit(1);
}

// Read the system prompt from the Edge Function
const SYSTEM_PROMPT = await Deno.readTextFile("supabase/functions/parse-voice-tasks/index.ts")
  .then(content => {
    const match = content.match(/const SYSTEM_PROMPT = `([\s\S]*?)`;/);
    return match ? match[1] : null;
  });

if (!SYSTEM_PROMPT) {
  console.error("❌ Could not extract SYSTEM_PROMPT from index.ts");
  Deno.exit(1);
}

// Test cases with expected confidence levels
const testCases = [
  {
    utterance: "Call mom tomorrow high priority",
    expected: "high",
    reason: "Clear action verb + clear object + explicit date + no sharing"
  },
  {
    utterance: "meeting with Sarah",
    expected: "medium",
    reason: "Vague title, no date, but clear people context"
  },
  {
    utterance: "add a task",
    expected: "low",
    reason: "Missing title and date"
  },
  {
    utterance: "Costco run next week share with Mike",
    expected: "medium",
    reason: "Relative date + sharing intent"
  },
  {
    utterance: "Submit the quarterly report by Friday at 3pm",
    expected: "high",
    reason: "Clear action verb + clear object + explicit date and time"
  },
  {
    utterance: "Remind me to do something important",
    expected: "low",
    reason: "Vague object ('something'), no date"
  },
  {
    utterance: "Buy groceries this weekend",
    expected: "medium",
    reason: "Relative date (this weekend)"
  },
  {
    utterance: "Book dentist appointment for March 15th urgent",
    expected: "high",
    reason: "Clear action + object + explicit date + inferred priority"
  },
  {
    utterance: "That thing we talked about",
    expected: "low",
    reason: "Extremely vague, no clear task definition"
  },
  {
    utterance: "Walk the dog",
    expected: "medium",
    reason: "Clear action + object but no date mentioned"
  }
];

interface TestResult {
  utterance: string;
  expected: string;
  actual: string;
  correct: boolean;
  response: any;
  latency: number;
}

async function runTest(testCase: typeof testCases[0]): Promise<TestResult> {
  const startTime = performance.now();
  
  const messages = [
    { role: "system" as const, content: SYSTEM_PROMPT + "\n\nToday's date: 2026-02-14\nTimezone: America/New_York" },
    { role: "user" as const, content: testCase.utterance }
  ];

  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
      "Content-Type": "application/json",
      "HTTP-Referer": SUPABASE_URL || "http://localhost",
      "X-Title": "Docket Voice Assistant Test",
    },
    body: JSON.stringify({
      model: MODEL,
      messages,
      response_format: { type: "json_object" },
      temperature: 0.7,
    }),
  });

  const latency = performance.now() - startTime;

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenRouter error: ${error}`);
  }

  const data = await response.json();
  const aiContent = data.choices?.[0]?.message?.content;
  
  if (!aiContent) {
    throw new Error("Empty AI response");
  }

  const parsed = JSON.parse(aiContent);
  const actual = parsed.confidence || "missing";
  
  return {
    utterance: testCase.utterance,
    expected: testCase.expected,
    actual,
    correct: actual === testCase.expected,
    response: parsed,
    latency
  };
}

console.log("🧪 Testing Confidence Scoring in parse-voice-tasks\n");
console.log(`Model: ${MODEL}`);
console.log(`Test cases: ${testCases.length}\n`);
console.log("─".repeat(80));

const results: TestResult[] = [];
let correctCount = 0;
let totalLatency = 0;

for (let i = 0; i < testCases.length; i++) {
  const testCase = testCases[i];
  console.log(`\n${i + 1}. "${testCase.utterance}"`);
  console.log(`   Expected: ${testCase.expected.toUpperCase()} (${testCase.reason})`);
  
  try {
    const result = await runTest(testCase);
    results.push(result);
    
    const status = result.correct ? "✅" : "❌";
    const color = result.correct ? "\x1b[32m" : "\x1b[31m";
    const reset = "\x1b[0m";
    
    console.log(`   ${color}${status} Actual: ${result.actual.toUpperCase()}${reset} (${result.latency.toFixed(0)}ms)`);
    console.log(`   Response type: ${result.response.type}`);
    
    if (result.response.summary) {
      console.log(`   Summary: "${result.response.summary}"`);
    }
    
    if (result.correct) correctCount++;
    totalLatency += result.latency;
    
    // Small delay to avoid rate limiting
    await new Promise(r => setTimeout(r, 500));
    
  } catch (error) {
    console.error(`   ❌ Error: ${error.message}`);
  }
}

// Summary
console.log("\n" + "─".repeat(80));
console.log("\n📊 SUMMARY\n");
console.log(`Accuracy: ${correctCount}/${testCases.length} (${((correctCount/testCases.length)*100).toFixed(0)}%)`);
console.log(`Avg latency: ${(totalLatency/testCases.length).toFixed(0)}ms`);
console.log(`Latency target: <2000ms`);

if (totalLatency/testCases.length > 2000) {
  console.log("\n⚠️  WARNING: Average latency exceeds 2000ms target");
}

console.log("\nDetailed results:");
results.forEach((r, i) => {
  const status = r.correct ? "✅" : "❌";
  console.log(`  ${status} ${i + 1}. "${r.utterance}" → ${r.actual} (expected: ${r.expected})`);
});

// Mismatches analysis
const mismatches = results.filter(r => !r.correct);
if (mismatches.length > 0) {
  console.log("\n🔍 Mismatches to review:");
  mismatches.forEach(m => {
    console.log(`  - "${m.utterance}": got ${m.actual}, expected ${m.expected}`);
  });
}

Deno.exit(0);
