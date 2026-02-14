#!/usr/bin/env node
/**
 * Test script for confidence scoring in parse-voice-tasks Edge Function
 * 
 * Usage:
 *   cd /home/jensen/.openclaw/workspace/projects/docket
 *   npm install node-fetch
 *   OPENROUTER_API_KEY=your_key node supabase/functions/parse-voice-tasks/test-confidence-node.js
 */

const fetch = require('node-fetch');
const fs = require('fs');
const path = require('path');

const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;
const SUPABASE_URL = process.env.SUPABASE_URL || 'http://localhost';
const MODEL = process.env.OPENROUTER_MODEL || 'openai/gpt-4.1-mini';

if (!OPENROUTER_API_KEY) {
  console.error('❌ Missing OPENROUTER_API_KEY environment variable');
  process.exit(1);
}

// Read the system prompt from the Edge Function
const indexPath = path.join(__dirname, 'index.ts');
const indexContent = fs.readFileSync(indexPath, 'utf-8');
const promptMatch = indexContent.match(/const SYSTEM_PROMPT = `([\s\S]*?)`;/);

if (!promptMatch) {
  console.error('❌ Could not extract SYSTEM_PROMPT from index.ts');
  process.exit(1);
}

const SYSTEM_PROMPT = promptMatch[1];

// Test cases with expected confidence levels
const testCases = [
  {
    utterance: 'Call mom tomorrow high priority',
    expected: 'high',
    reason: 'Clear action verb + clear object + explicit date + no sharing'
  },
  {
    utterance: 'meeting with Sarah',
    expected: 'medium',
    reason: 'Vague title, no date, but clear people context'
  },
  {
    utterance: 'add a task',
    expected: 'low',
    reason: 'Missing title and date'
  },
  {
    utterance: 'Costco run next week share with Mike',
    expected: 'medium',
    reason: 'Relative date + sharing intent'
  },
  {
    utterance: 'Submit the quarterly report by Friday at 3pm',
    expected: 'high',
    reason: 'Clear action verb + clear object + explicit date and time'
  },
  {
    utterance: 'Remind me to do something important',
    expected: 'low',
    reason: 'Vague object ("something"), no date'
  },
  {
    utterance: 'Buy groceries this weekend',
    expected: 'medium',
    reason: 'Relative date (this weekend)'
  },
  {
    utterance: 'Book dentist appointment for March 15th urgent',
    expected: 'high',
    reason: 'Clear action + object + explicit date + inferred priority'
  },
  {
    utterance: 'That thing we talked about',
    expected: 'low',
    reason: 'Extremely vague, no clear task definition'
  },
  {
    utterance: 'Walk the dog',
    expected: 'medium',
    reason: 'Clear action + object but no date mentioned'
  }
];

async function runTest(testCase) {
  const startTime = Date.now();
  
  const messages = [
    { role: 'system', content: SYSTEM_PROMPT + '\n\nToday\'s date: 2026-02-14\nTimezone: America/New_York' },
    { role: 'user', content: testCase.utterance }
  ];

  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': SUPABASE_URL,
      'X-Title': 'Docket Voice Assistant Test',
    },
    body: JSON.stringify({
      model: MODEL,
      messages,
      response_format: { type: 'json_object' },
      temperature: 0.7,
    }),
  });

  const latency = Date.now() - startTime;

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenRouter error: ${error}`);
  }

  const data = await response.json();
  const aiContent = data.choices?.[0]?.message?.content;
  
  if (!aiContent) {
    throw new Error('Empty AI response');
  }

  const parsed = JSON.parse(aiContent);
  const actual = parsed.confidence || 'missing';
  
  return {
    utterance: testCase.utterance,
    expected: testCase.expected,
    actual,
    correct: actual === testCase.expected,
    response: parsed,
    latency
  };
}

async function main() {
  console.log('🧪 Testing Confidence Scoring in parse-voice-tasks\n');
  console.log(`Model: ${MODEL}`);
  console.log(`Test cases: ${testCases.length}\n`);
  console.log('─'.repeat(80));

  const results = [];
  let correctCount = 0;
  let totalLatency = 0;

  for (let i = 0; i < testCases.length; i++) {
    const testCase = testCases[i];
    console.log(`\n${i + 1}. "${testCase.utterance}"`);
    console.log(`   Expected: ${testCase.expected.toUpperCase()} (${testCase.reason})`);
    
    try {
      const result = await runTest(testCase);
      results.push(result);
      
      const status = result.correct ? '✅' : '❌';
      
      console.log(`   ${status} Actual: ${result.actual.toUpperCase()} (${result.latency}ms)`);
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
  console.log('\n' + '─'.repeat(80));
  console.log('\n📊 SUMMARY\n');
  console.log(`Accuracy: ${correctCount}/${testCases.length} (${((correctCount/testCases.length)*100).toFixed(0)}%)`);
  console.log(`Avg latency: ${Math.round(totalLatency/testCases.length)}ms`);
  console.log(`Latency target: <2000ms`);

  if (totalLatency/testCases.length > 2000) {
    console.log('\n⚠️  WARNING: Average latency exceeds 2000ms target');
  }

  console.log('\nDetailed results:');
  results.forEach((r, i) => {
    const status = r.correct ? '✅' : '❌';
    console.log(`  ${status} ${i + 1}. "${r.utterance}" → ${r.actual} (expected: ${r.expected})`);
  });

  // Mismatches analysis
  const mismatches = results.filter(r => !r.correct);
  if (mismatches.length > 0) {
    console.log('\n🔍 Mismatches to review:');
    mismatches.forEach(m => {
      console.log(`  - "${m.utterance}": got ${m.actual}, expected ${m.expected}`);
    });
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
