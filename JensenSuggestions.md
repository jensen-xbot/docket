# Jensen's Suggestions for Docket v1.1

*Reviewed: 2026-02-09*  
*Based on: Voice-to-Task v1.1 implementation*

---

## 🎯 Executive Summary

This is **production-quality code**. The architecture is sound, edge cases are handled, and the documentation is excellent. The Swift 6 concurrency guide alone shows deep platform understanding.

**Overall verdict:** Ready for TestFlight with minor polish.

---

## ✅ What's Excellent

1. **Conversational AI Design** - Multi-turn with follow-ups works naturally
2. **Dual TTS System** - Apple fallback + OpenAI premium voices
3. **Swift 6 Concurrency** - Proper `@MainActor` and `nonisolated static` usage
4. **Cost Efficiency** - ~$8-18/month for 100 users (well within budget)
5. **Documentation** - SWIFT6-CONCURRENCY-GUIDE.md is gold

---

## 🔧 Priority 1: Performance & Battery

### 1.1 Throttle Audio Level Polling
**File:** `SpeechRecognitionManager.swift`

Current: 50ms polling interval drains battery.

```swift
// Current (line ~165 in levelPollTask)
try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

// Suggested: Reduce to 100ms or make adaptive
// 100ms is still smooth for UI but uses 50% less CPU
try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
```

**Impact:** ~20-30% battery savings during voice recording.

---

### 1.2 Optimize displayMessages Computed Property
**File:** `VoiceRecordingView.swift`

Current: Rebuilds the entire message array on every view update.

```swift
// Current: Computed property runs on every SwiftUI evaluation
private var displayMessages: [DisplayMessage] { ... }

// Suggested: Use explicit state transitions
// Add a @State private var liveTranscription: String?
// Only append to messages[] when utterance is complete
// This eliminates the computed property overhead
```

**Impact:** Smoother scrolling, less CPU during active conversation.

---

## 🔧 Priority 2: Edge Function Hardening

### 2.1 Add Rate Limiting
**File:** `supabase/functions/parse-voice-tasks/index.ts`

Prevent abuse and runaway costs:

```typescript
// Add after user verification (~line 160)
const RATE_LIMIT = 60; // requests per hour per user
const rateLimitKey = `rate_limit:${user.id}`;

// Simple implementation using Supabase Redis or edge cache
const { data: rateData } = await supabase
  .from('rate_limits')
  .select('count, reset_at')
  .eq('user_id', user.id)
  .single();

if (rateData && rateData.count > RATE_LIMIT) {
  return new Response(
    JSON.stringify({ error: "Rate limit exceeded. Try again later." }),
    { status: 429 }
  );
}
```

**Impact:** Prevents runaway costs from abuse or bugs.

---

### 2.2 Add Request Timeout
**File:** `supabase/functions/parse-voice-tasks/index.ts`

OpenRouter can hang:

```typescript
// Add abort controller to fetch (~line 200)
const controller = new AbortController();
const timeoutId = setTimeout(() => controller.abort(), 15000); // 15s timeout

const openRouterResponse = await fetch("...", {
  signal: controller.signal,
  // ... rest of config
});

clearTimeout(timeoutId);
```

**Impact:** Prevents hanging requests, better UX with timeout messages.

---

## 🔧 Priority 3: Conversation Context Optimization

### 3.1 Trim Task Context
**File:** `supabase/functions/parse-voice-tasks/index.ts`

Currently sending ALL task titles every turn (~50 tasks). This increases token costs.

```typescript
// Current: Sends all existingTasks
// Suggested: Only send incomplete + recently completed

const relevantTasks = existingTasks
  .filter(t => !t.isCompleted || isRecent(t)) // Last 7 days
  .slice(0, 20); // Cap at 20 tasks

// Also consider: Only re-send if task list changed since last request
// Use a hash of task IDs + titles to detect changes
```

**Impact:** ~30-40% reduction in token usage for heavy users.

---

### 3.2 Cache Task Context Hash
**File:** `VoiceRecordingView.swift`

Avoid re-sending identical context:

```swift
// Add to VoiceRecordingView
private var lastTaskContextHash: String?

private func taskContextHash() -> String {
    let taskStrings = activeTasks.map { "\($0.id):\($0.title):\($0.isCompleted)" }
    return taskStrings.joined().sha256() // Or simple hash
}

// Only include full task list if hash changed
// Otherwise send empty array (server can use cached context)
```

**Impact:** Faster responses, lower token costs for repeat interactions.

---

## 🔧 Priority 4: Error Handling Improvements

### 4.1 Handle OpenAI TTS Failures Better
**File:** `TTSManager.swift`

Current fallback works but has edge cases:

```swift
// Current: Falls back to Apple TTS on any error
// Suggested: Distinguish failure types

// If network error: Fallback to Apple TTS (current behavior)
// If invalid voice name: Log to analytics, use default "nova"
// If rate limited: Switch to Apple TTS + show subtle UI hint
// If auth error: Trigger re-auth flow

// Add analytics tracking:
Analytics.track("tts_failure", [
    "reason": error.localizedDescription,
    "voice": openAITTSVoice,
    "fallback_used": true
])
```

---

### 4.2 Add Retry Logic for Transcription
**File:** `SpeechRecognitionManager.swift`

Apple Speech can fail intermittently:

```swift
// Add retry count to startRecording()
private var transcriptionRetryCount = 0
private let maxRetries = 2

// If recognition fails with specific errors, auto-retry
// Only retry on: .retryError, .notFound, .networkError
// Don't retry on: .denied, .noPermissions, .alreadyRecording
```

---

## 🔧 Priority 5: UX Polish

### 5.1 Tap-to-Edit on Confirmation View
**File:** `TaskConfirmationView.swift` (per TODO.md)

Users need to fix AI mistakes before saving:

```swift
// Add inline editing capabilities:
// - Tap title to edit
// - Tap due date to open picker
// - Tap priority to show segmented control
// - Swipe to delete individual tasks from batch
// - "Add note" button for extra context
```

**Impact:** Reduces frustration when AI makes small errors.

---

### 5.2 Haptic Feedback Refinement
**File:** `VoiceRecordingView.swift`

Current haptics are good but could be richer:

```swift
// Add these haptic moments:
// - Light tap when user starts speaking (speech detected)
// - Success pattern when task confirmed (not just saved)
// - Warning pattern when correction detected
// - Error pattern when something fails

// Use UINotificationFeedbackGenerator for success/error
// Use UIImpactFeedbackGenerator for lighter interactions
```

---

### 5.3 Visual Audio Waveform
**File:** `VoiceRecordingView.swift`

Replace/amend the static mic icon with a waveform:

```swift
// Simple implementation using audioLevel from SpeechRecognitionManager:
// - Animate bar heights based on audioLevel
// - Color changes: blue (normal) → orange (loud) → red (clipping)
// - Fades out during processing/speaking states
```

**Impact:** Users know the app is "hearing" them.

---

## 🔧 Priority 6: Pre-Launch Checklist

### 6.1 Privacy Compliance
- [ ] Add "Microphone Usage" description to Info.plist (✓ done)
- [ ] Add "Speech Recognition Usage" description (✓ done)
- [ ] Review VoiceRecordingView for accidental logging of personal data
- [ ] Ensure transcription text not sent to analytics/logs
- [ ] Add privacy manifest (required for App Store as of 2024)

### 6.2 Accessibility
- [ ] Test VoiceOver on VoiceRecordingView
- [ ] Ensure button sizes meet 44pt minimum
- [ ] Add accessibility labels to all interactive elements
- [ ] Test with Reduce Motion enabled

### 6.3 Testing Scenarios
Test these edge cases before TestFlight:

| Scenario | Expected | Status |
|----------|----------|--------|
| Network offline during voice | Shows offline indicator, queues for retry | ? |
| User interrupts TTS | Stops speaking, listens for new input | ? |
| App backgrounded mid-recording | Pauses, resumes on foreground | ? |
| Very long dictation (2+ min) | Handles gracefully, no memory issues | ? |
| Rapid tap mic button | Debounces, doesn't crash | ? |
| AirPods connected | Routes audio correctly | ? |
| Phone call interrupts | Stops recording, graceful recovery | ? |

---

## 🔧 Priority 7: Learning from Task Edits (CRITICAL)

**The Problem:** Voice-only interface means users can't correct spelling in the chat. They fix errors by editing the task directly. Your app needs to **learn from these edits**.

### 7.1 Detect and Learn Corrections (ALL Fields)

Track corrections across **every customizable field** to build comprehensive user context:

```swift
// UserContextManager.swift
@Observable
class UserContextManager {
    static let shared = UserContextManager()
    
    // MARK: - Track All Field Changes
    
    func trackTaskChanges(task: Task, snapshot: TaskSnapshot) {
        guard task.source == .voice else { return }
        
        var allChanges: [FieldCorrection] = []
        
        // 1. TITLE (highest priority)
        if task.title != snapshot.title {
            let titleChanges = detectWordChanges(
                original: snapshot.title,
                corrected: task.title,
                fieldType: .title
            )
            allChanges.append(contentsOf: titleChanges)
        }
        
        // 2. NOTES (extract vocabulary, names, context)
        if task.notes != snapshot.notes {
            let noteChanges = extractVocabularyFromNotes(
                original: snapshot.notes ?? "",
                corrected: task.notes ?? ""
            )
            allChanges.append(contentsOf: noteChanges)
            
            // Also learn contextual phrases
            learnContextualPhrases(from: task.notes, forTask: task)
        }
        
        // 3. CATEGORY (learn user-specific category names)
        if task.category != snapshot.category {
            learnCategoryMapping(
                aiSuggested: snapshot.category,
                userCorrected: task.category
            )
        }
        
        // 4. STORE (for grocery tasks)
        if let store = task.store, store != snapshot.store {
            learnStoreName(
                aiSuggested: snapshot.store,
                userCorrected: store
            )
        }
        
        // 5. CHECKLIST ITEMS / INGREDIENTS
        let originalItems = Set(snapshot.checklistItems.map { $0.name })
        let correctedItems = Set(task.checklistItems.map { $0.name })
        
        let newItems = correctedItems.subtracting(originalItems)
        let removedItems = originalItems.subtracting(correctedItems)
        
        for item in newItems {
            learnIngredientOrItem(item, context: task.category)
        }
        
        // 6. STORE TEMPLATES (if user edits template contents)
        if task.isTemplateEdit {
            learnTemplateModifications(task)
        }
        
        // Apply all learned corrections
        applyCorrections(allChanges)
        
        // Sync to server
        syncAllCorrections(allChanges, forTask: task)
    }
    
    // MARK: - Field-Specific Learning
    
    private func extractVocabularyFromNotes(original: String, corrected: String) -> [FieldCorrection] {
        // Notes often contain: names, places, project codes, meeting IDs
        // Extract capitalized words and unusual terms
        
        let correctedWords = corrected.components(separatedBy: .whitespacesAndNewlines)
        
        return correctedWords.compactMap { word in
            // Look for: Proper nouns, camelCase, unusual capitalizations
            if isLikelyProperNoun(word) || containsMixedCase(word) {
                return FieldCorrection(
                    field: .notes,
                    originalTerm: findOriginalSpelling(of: word, in: original),
                    correctedTerm: word,
                    context: extractContext(from: corrected, around: word),
                    confidence: calculateConfidence(original: original, corrected: corrected)
                )
            }
            return nil
        }
    }
    
    private func learnCategoryMapping(aiSuggested: String?, userCorrected: String?) {
        guard let suggested = aiSuggested, let corrected = userCorrected else { return }
        
        // AI thought it was "Work" but user prefers "Client Work"
        // Store this mapping for future voice commands
        CategoryLearning.shared.recordMapping(
            aiGuess: suggested,
            userPreference: corrected,
            triggerWords: extractTriggerWords(from: corrected)
        )
    }
    
    private func learnStoreName(aiSuggested: String?, userCorrected: String) {
        // User said "Krogers" but meant "Kroger"
        // Or AI heard "Whole Foods" but user prefers "Whole Foods Market"
        
        StoreNameLearning.shared.addAlias(
            spoken: aiSuggested ?? userCorrected,
            canonical: userCorrected,
            type: .groceryStore
        )
        
        // Also update grocery context for better ingredient suggestions
        GroceryContext.shared.learnStorePreferences(
            store: userCorrected,
            typicalItems: getRecentItems(forStore: userCorrected)
        )
    }
    
    private func learnIngredientOrItem(_ item: String, context: String?) {
        // Track: "bananas" vs "plantains", "milk" vs "oat milk"
        // Build user's personal ingredient vocabulary
        
        IngredientLearning.shared.addTerm(
            name: item,
            category: inferCategory(from: item, context: context),
            frequency: 1
        )
    }
    
    private func learnTemplateModifications(_ task: Task) {
        // User edited a grocery template (added/removed items)
        // Learn their preferences for this store
        
        guard let storeName = task.store else { return }
        
        let currentItems = task.checklistItems.map { $0.name }
        
        TemplateLearning.shared.updateTemplate(
            forStore: storeName,
            preferredItems: currentItems,
            timestamp: Date()
        )
    }
    
    private func learnContextualPhrases(from notes: String?, forTask task: Task) {
        // Extract patterns like:
        // - "Discuss Q4 roadmap with Sarah"
        // - "Follow up on proposal"
        // - "Prep for standup"
        
        guard let notes = notes else { return }
        
        // Learn recurring phrases
        ContextualLearning.shared.extractPatterns(
            text: notes,
            associatedWith: task.category,
            priority: task.priority
        )
    }
}

// MARK: - Data Models

struct TaskSnapshot {
    let title: String
    let notes: String?
    let category: String?
    let store: String?
    let priority: TaskPriority
    let checklistItems: [ChecklistItemSnapshot]
    let isTemplateEdit: Bool
}

struct FieldCorrection {
    let field: CorrectableField
    let originalTerm: String
    let correctedTerm: String
    let context: String?
    let confidence: Double
    let timestamp: Date
}

enum CorrectableField: String {
    case title
    case notes
    case category
    case store
    case checklistItem
    case ingredient
}

enum TermCategory {
    case personName      // Mathilde, Sarah
    case companyName     // TuffTek, Closelo
    case productName     // iPhone, Tesla
    case placeName       // Kroger, Whole Foods
    case projectCode     // Q4-2024, PROJ-123
    case generalVocabulary
}

struct SpellingChange {
    let original: String      // "tough"
    let corrected: String     // "TuffTek"
    let category: TermCategory // .company, .name, etc.
}
```

### 7.2 Show Visual Feedback

Users should know the app is learning:

```swift
// In TaskListView or wherever users edit tasks
.taskModifier {
    // After edit is saved
    if learnedSomething {
        // Subtle toast: "Learned: 'TuffTek'"
        showToast("💡 Learned '\(correctedTerm)' for next time")
    }
}

// Alternative: Subtle shimmer on the edited task row
// with a small "AI learned this" badge that fades after 2 seconds
```

### 7.3 Add "Source" Tracking to Tasks

You need to know which tasks came from voice:

```swift
// In Task.swift (SwiftData model)
enum TaskSource: String, Codable {
    case voice      // Created via voice
    case manual     // Created by typing
    case shared     // Received from another user
    case template   // Created from grocery template
}

@Model
class Task {
    // ... existing fields ...
    
    var source: TaskSource = .manual
    var createdViaVoice: Bool { source == .voice }
}
```

### 7.4 Integration Points (Capture All Fields)

**In EditTaskView:**
```swift
struct EditTaskView: View {
    @Bindable var task: Task
    
    // Snapshot before editing
    @State private var snapshot: TaskSnapshot?
    
    var body: some View {
        Form {
            // All your editing fields...
        }
        .onAppear {
            // Capture snapshot when view appears
            snapshot = TaskSnapshot(
                title: task.title,
                notes: task.notes,
                category: task.category,
                store: task.store,
                priority: task.priority,
                checklistItems: task.checklistItems.map { 
                    ChecklistItemSnapshot(name: $0.name, isChecked: $0.isChecked) 
                },
                isTemplateEdit: false
            )
        }
        .onDisappear {
            // Compare and learn on exit
            if let snapshot = snapshot {
                UserContextManager.shared.trackTaskChanges(
                    task: task,
                    snapshot: snapshot
                )
            }
        }
    }
}
```

**In TaskRowView (inline editing):**
```swift
.onSubmit {
    if editedTitle != task.title {
        // Create snapshot of current state
        let snapshot = TaskSnapshot(
            title: task.title,
            notes: task.notes,
            category: task.category,
            store: task.store,
            priority: task.priority,
            checklistItems: task.checklistItems.map { 
                ChecklistItemSnapshot(name: $0.name, isChecked: $0.isChecked) 
            },
            isTemplateEdit: false
        )
        
        // Apply the change
        task.title = editedTitle
        
        // Track the change
        UserContextManager.shared.trackTaskChanges(
            task: task,
            snapshot: snapshot
        )
    }
}
```

**In ChecklistEditorView:**
```swift
// When user adds/removes/reorders items
.onChange(of: checklistItems) { oldItems, newItems in
    let snapshot = TaskSnapshot(
        title: task.title,
        notes: task.notes,
        category: task.category,
        store: task.store,
        priority: task.priority,
        checklistItems: oldItems.map { 
            ChecklistItemSnapshot(name: $0.name, isChecked: $0.isChecked) 
        },
        isTemplateEdit: task.isTemplateEdit
    )
    
    UserContextManager.shared.trackTaskChanges(
        task: task,
        snapshot: snapshot
    )
}
```

**In GroceryTemplateListView:**
```swift
// When user modifies a store template
.onTemplateModified { store, originalItems, newItems in
    // Mark as template edit
    let snapshot = TaskSnapshot(
        title: "Template: \(store.name)",
        notes: nil,
        category: "Groceries",
        store: store.name,
        priority: .medium,
        checklistItems: originalItems.map { 
            ChecklistItemSnapshot(name: $0, isChecked: false) 
        },
        isTemplateEdit: true
    )
    
    // Create temporary task for learning
    let tempTask = Task(title: "Template Update", category: "Groceries")
    tempTask.store = store.name
    tempTask.source = .voice // So it triggers learning
    
    UserContextManager.shared.trackTaskChanges(
        task: tempTask,
        snapshot: snapshot
    )
}
```

### 7.5 Edge Function Update (Multi-Field)

Update the endpoint to handle corrections across all fields:

```typescript
// supabase/functions/record-corrections/index.ts

interface FieldCorrection {
  field: "title" | "notes" | "category" | "store" | "checklistItem";
  original: string;
  corrected: string;
  context?: string;
  confidence?: number;
}

interface CorrectionBatchRequest {
  corrections: FieldCorrection[];
  taskContext: {
    category?: string;
    store?: string;
    priority?: string;
  };
  timestamp: string;
}

Deno.serve(async (req) => {
  // Verify auth...
  const body: CorrectionBatchRequest = await req.json();
  
  // Get current profile
  const { data: profile } = await supabase
    .from('user_voice_profiles')
    .eq('user_id', user.id)
    .single();
  
  const updates: any = {
    custom_terms: profile?.custom_terms || [],
    name_corrections: profile?.name_corrections || [],
    category_mappings: profile?.category_mappings || [],
    store_aliases: profile?.store_aliases || [],
    ingredient_preferences: profile?.ingredient_preferences || [],
    contextual_patterns: profile?.contextual_patterns || []
  };
  
  for (const correction of body.corrections) {
    switch (correction.field) {
      case "title":
      case "notes":
        // Determine if it's a name or general vocabulary
        if (looksLikeName(correction.corrected)) {
          updates.name_corrections.push({
            spoken: correction.original,
            actual: correction.corrected,
            context: correction.context,
            frequency: 1
          });
        } else {
          updates.custom_terms.push({
            term: correction.corrected,
            aliases: [correction.original],
            category: guessCategory(correction.corrected),
            context: body.taskContext.category
          });
        }
        break;
        
      case "category":
        updates.category_mappings.push({
          ai_guess: correction.original,
          user_preference: correction.corrected,
          frequency: 1,
          last_used: new Date().toISOString()
        });
        break;
        
      case "store":
        updates.store_aliases.push({
          spoken: correction.original,
          canonical: correction.corrected,
          type: "grocery_store",
          typical_items: [] // Populated from task context
        });
        break;
        
      case "checklistItem":
        updates.ingredient_preferences.push({
          name: correction.corrected,
          ai_guess: correction.original,
          category: body.taskContext.category,
          frequency: 1
        });
        break;
    }
  }
  
  // Deduplicate and rank by frequency
  updates.name_corrections = deduplicateAndRank(updates.name_corrections);
  updates.custom_terms = deduplicateAndRank(updates.custom_terms);
  updates.category_mappings = deduplicateAndRank(updates.category_mappings);
  
  // Save back
  await supabase
    .from('user_voice_profiles')
    .upsert({ 
      user_id: user.id, 
      ...updates,
      updated_at: new Date().toISOString()
    });
    
  return new Response(JSON.stringify({ 
    success: true,
    learned: body.corrections.length 
  }));
});

// Helper: Keep top N most frequent/recent
function deduplicateAndRank(items: any[], maxItems = 100) {
  // Group by actual/corrected value
  const grouped = items.reduce((acc, item) => {
    const key = item.actual || item.user_preference || item.canonical || item.name;
    if (!acc[key]) {
      acc[key] = { ...item, frequency: 0 };
    }
    acc[key].frequency += (item.frequency || 1);
    return acc;
  }, {});
  
  // Sort by frequency and take top N
  return Object.values(grouped)
    .sort((a: any, b: any) => b.frequency - a.frequency)
    .slice(0, maxItems);
}
```

### 7.6 The Learning Flow (Visual - ALL Fields)

```
USER: "Add buy groceries at Krogers for dinner party, get bananas
       plantains avocados and stuff from Costco list" (voice)
   ↓
AI PARSES:
   Title: "Buy groceries at Krogers"
   Category: "Shopping"
   Store: "Krogers"
   Notes: "for dinner party"
   Items: ["bananas", "plantains", "avocados"]
   └─ AI adds: "Costco template" (misunderstood context)
   ↓
TASK CREATED with AI's interpretation
   ↓
USER EDITS TASK:
   Title: "Buy groceries at Kroger" (dropped 's')
   Category: "Groceries" (changed from "Shopping")
   Store: "Kroger" (canonical name)
   Notes: "for Sarah's dinner party" (added host name)
   Items: ["bananas", "plantains", "avocados", "salsa", "chips"]
   └─ Removed: Costco template reference
   └─ Added: "salsa", "chips" (user preferences)
   ↓
APP DETECTS & LEARNS:
   ┌─ TITLE: "Krogers" → "Kroger"
   ├─ CATEGORY: "Shopping" → "Groceries" (for grocery tasks)
   ├─ STORE: "Krogers" → "Kroger" (canonical)
   ├─ NOTES: Learned "Sarah" as person name
   ├─ ITEMS: Learned user prefers these 5 items together
   ├─ TEMPLATES: User doesn't want auto-Costco for this context
   └─ CONTEXT: "dinner party" = social event, not routine shopping
   ↓
LEARNING ACTIONS:
   ├─ Add "Kroger" to SFCustomLanguageModel
   ├─ Map: "Shopping" → "Groceries" when store mentioned
   ├─ Learn: "Sarah" is a person (for future sharing/context)
   ├─ Learn: Dinner party context = specific items, not templates
   ├─ Store: User's preferred Kroger items list
   ├─ Context: "dinner party" triggers social event parsing
   └─ Show: "💡 Learned Kroger, Sarah, and dinner party preferences"
   ↓
NEXT TIME USER SAYS:
   "Get stuff from Kroger for dinner with Sarah"
   ↓
AI NOW KNOWS:
   ├─ "Kroger" not "Krogers"
   ├─ Category = "Groceries" not "Shopping"
   ├─ "Sarah" = person context
   ├─ "dinner" + "Sarah" = social event
   ├─ Suggest: previous Kroger items + social event staples
   └─ Notes: Include Sarah in context automatically
   ↓
RESULT: Task created with all correct fields ✓
```

### 7.7 Database Schema (Updated for Multi-Field)

```sql
-- Extended user_voice_profiles for multi-field learning
CREATE TABLE user_voice_profiles (
  user_id UUID REFERENCES auth.users PRIMARY KEY,
  
  -- Vocabulary & Spelling
  custom_terms JSONB DEFAULT '[]',           -- [{term, aliases[], category, frequency}]
  name_corrections JSONB DEFAULT '[]',       -- [{spoken, actual, context, frequency}]
  
  -- Category Learning
  category_mappings JSONB DEFAULT '[]',      -- [{ai_guess, user_preference, trigger_words[], frequency}]
  
  -- Store Learning
  store_aliases JSONB DEFAULT '[]',          -- [{spoken, canonical, typical_items[], frequency}]
  
  -- Ingredient/Item Preferences
  ingredient_preferences JSONB DEFAULT '[]', -- [{name, category, frequency, often_with[]}]
  
  -- Contextual Patterns
  contextual_patterns JSONB DEFAULT '[]',    -- [{phrase, associated_categories[], frequency}]
  
  -- Template Learning
  template_preferences JSONB DEFAULT '[]',   -- [{store, preferred_items[], last_modified}]
  
  -- Metadata
  total_corrections INTEGER DEFAULT 0,
  last_correction_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast lookups
CREATE INDEX idx_voice_profiles_user ON user_voice_profiles(user_id);
CREATE INDEX idx_voice_profiles_terms ON user_voice_profiles USING GIN (custom_terms);

-- Helper function to update correction count
CREATE OR REPLACE FUNCTION increment_correction_count()
RETURNS TRIGGER AS $$
BEGIN
  NEW.total_corrections = COALESCE(OLD.total_corrections, 0) + 1;
  NEW.last_correction_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER correction_count_trigger
  BEFORE UPDATE ON user_voice_profiles
  FOR EACH ROW
  WHEN (NEW.custom_terms != OLD.custom_terms OR 
        NEW.name_corrections != OLD.name_corrections OR
        NEW.category_mappings != OLD.category_mappings OR
        NEW.store_aliases != OLD.store_aliases)
  EXECUTE FUNCTION increment_correction_count();
```

### 7.8 Bulk Learning (Existing Tasks)

For users with existing tasks, add a one-time import:

```swift
// In Settings or onboarding
func learnFromExistingTasks() {
    // Find all tasks that might be company/product names
    // Look for capitalized words, unusual spellings, etc.
    let candidates = allTasks.filter { task in
        let words = task.title.components(separatedBy: .whitespaces)
        return words.contains { word in
            // Heuristic: Unusual capitalization or mixed case
            word.rangeOfCharacter(from: .uppercaseLetters) != nil &&
            word.rangeOfCharacter(from: .lowercaseLetters) != nil &&
            word.count > 3
        }
    }
    
    // Present to user: "Teach me these terms?"
    // User selects which ones to add to vocabulary
}
```

---

## 🔮 Priority 8: Additional Contextual Use Cases (From Code Review)

Based on deeper review of Task.swift, CategoryStore.swift, ShareTaskView.swift, and migrations, here are additional contextual patterns to learn:

### 8.1 Time Pattern Learning
**What to learn:** When does this user typically add time to tasks?

```swift
// In UserContextManager
func learnTimePatterns(from task: Task) {
    guard task.source == .voice else { return }
    
    let patterns = TimePatternLearning.shared
    
    // Learn: User adds time to "meetings" and "calls" but not "groceries"
    if let category = task.category {
        patterns.recordTimeUsage(
            category: category,
            hasTime: task.hasTime
        )
    }
    
    // Learn: User prefers specific times for certain task types
    // "Morning" = 9am, "Afternoon" = 2pm, "Evening" = 6pm
    if task.hasTime, let dueDate = task.dueDate {
        let hour = Calendar.current.component(.hour, from: dueDate)
        patterns.recordPreferredTime(
            taskType: inferTaskType(from: task.title),
            hour: hour
        )
    }
}

// AI can now ask:
// "You usually schedule meetings at 9am. Should I set that?"
// vs
// "You don't typically add times to grocery tasks. Keep it date-only?"
```

**Database:**
```sql
time_patterns: {
  category: "Work",
  time_likelihood: 0.85,  // 85% of Work tasks have time
  preferred_hours: [9, 14, 16],  // Most common times
  inferred_from: 47  // Learned from 47 tasks
}
```

---

### 8.2 Priority Pattern Learning
**What to learn:** What triggers high priority for this specific user?

```swift
func learnPriorityPatterns(from task: Task) {
    // Extract keywords that correlate with high priority
    let words = task.title.components(separatedBy: .whitespaces)
    
    for word in words {
        PriorityLearning.shared.record(
            word: word.lowercased(),
            priority: task.priority,
            category: task.category
        )
    }
    
    // Also learn from NOTES context
    if let notes = task.notes {
        // "ASAP" in notes → likely high priority
        // "whenever" in notes → likely low priority
        PriorityLearning.shared.recordContextualPriority(
            notes: notes,
            actualPriority: task.priority
        )
    }
}

// AI can now infer:
// User says: "Email the client about the proposal"
// AI knows: "client" + "proposal" historically = high priority (0.8)
// Result: Auto-suggests high priority without asking
```

**Database:**
```sql
priority_patterns: {
  word: "client",
  high_priority_correlation: 0.82,
  category_boost: {"Work": 0.9, "Personal": 0.3}
}
```

---

### 8.3 Due Date Pattern Learning
**What to learn:** How far in advance does user plan?

```swift
func learnDueDatePatterns(from task: Task) {
    guard let dueDate = task.dueDate else { return }
    
    let daysInAdvance = Calendar.current.dateComponents(
        [.day],
        from: task.createdAt,
        to: dueDate
    ).day ?? 0
    
    // Learn by category
    if let category = task.category {
        DueDateLearning.shared.recordPlanningHorizon(
            category: category,
            daysInAdvance: daysInAdvance
        )
    }
    
    // Learn by task type (inferred from title)
    let taskType = inferTaskType(from: task.title)
    DueDateLearning.shared.recordPlanningHorizon(
        taskType: taskType,
        daysInAdvance: daysInAdvance
    )
}

// Examples learned:
// - "Groceries": Same day (0 days)
// - "Work meetings": 2-3 days ahead
// - "Dentist": 14+ days ahead
// - "Birthday gifts": 7-14 days ahead

// AI can now:
// User: "Call mom"
// AI: "You usually call family same day. Set for today?"
// vs
// User: "Plan team offsite"
// AI: "You usually plan work events 5-7 days ahead. Set for next Friday?"
```

---

### 8.4 Category Association Learning
**What to learn:** What words trigger which categories for THIS user?

```swift
func learnCategoryAssociations(from task: Task) {
    guard let category = task.category else { return }
    
    let words = task.title.lowercased().components(separatedBy: .whitespaces)
    
    for word in words {
        CategoryLearning.shared.recordAssociation(
            word: word,
            category: category,
            icon: CategoryStore.shared.find(byName: category)?.icon,
            color: CategoryStore.shared.find(byName: category)?.color
        )
    }
    
    // Also learn from CHECKLIST items
    if let items = task.checklistItems {
        for item in items {
            CategoryLearning.shared.recordItemCategoryAssociation(
                itemName: item.name,
                parentCategory: category
            )
        }
    }
}

// Examples:
// "Milk" → Groceries (but if in "Shopping" category, learn exception)
// "Meeting" → Work (but if said "family meeting", learn context)
// "Doctor" → Health
// "Costco" → Groceries (not Shopping)

// AI asks better follow-ups:
// User: "Get milk"
// AI: "Groceries like usual, or different category?"
// vs guessing wrong or asking generically
```

---

### 8.5 Sharing Pattern Learning
**What to learn:** Who does user share with and for what?

```swift
func learnSharingPatterns(from share: TaskShare) {
    // Learn: User shares "Groceries" with spouse
    // Learn: User shares "Work" tasks with specific colleagues
    
    SharingLearning.shared.record(
        recipient: share.sharedWithEmail,
        taskCategory: share.task.category,
        taskTitle: share.task.title
    )
}

// AI can proactively suggest:
// User: "Buy groceries for dinner"
// AI: "You usually share grocery lists with sarah@email.com. Share this one too?"
// vs making user manually share every time

// Also learn CONTACT NAME variations:
// User says: "Share with my wife"
// AI needs to resolve: "wife" → "sarah@email.com"
// Store: relationship_aliases {"wife": "sarah@email.com"}
```

**Database:**
```sql
sharing_patterns: {
  recipient_email: "sarah@email.com",
  category_frequency: {"Groceries": 0.9, "Family": 0.7},
  relationship_alias: "wife"
}
```

---

### 8.6 Pin Pattern Learning
**What to learn:** What types of tasks does user pin?

```swift
func learnPinPatterns(from task: Task) {
    guard task.isPinned else { return }
    
    PinLearning.shared.record(
        category: task.category,
        title: task.title,
        priority: task.priority,
        triggerWords: extractKeywords(from: task.title)
    )
}

// Learn:
// - User pins "ASAP" tasks
// - User pins high priority + due today
// - User pins specific categories ("Work")

// AI can suggest:
// "This looks urgent. Pin it to the top?"
```

---

### 8.7 Recurrence Detection (Pre-v1.2)
**What to learn:** Even before building recurrence, detect patterns

```swift
func detectRecurringPatterns(tasks: [Task]) {
    // Group similar titles
    let grouped = Dictionary(grouping: tasks) { 
        normalizeTitle($0.title) 
    }
    
    for (normalizedTitle, similarTasks) in grouped {
        guard similarTasks.count >= 3 else { continue }
        
        // Check for weekly pattern
        let dates = similarTasks.map { $0.dueDate ?? $0.createdAt }
        if hasWeeklyPattern(dates) {
            RecurrenceLearning.shared.recordPattern(
                titlePattern: normalizedTitle,
                frequency: "weekly",
                preferredDay: mostCommonDay(dates)
            )
        }
    }
}

// AI can say:
// "You create 'Weekly report' every Friday. Want me to suggest this next week?"
// (Even before full recurrence feature is built)
```

---

### 8.8 Location/Store Affinity
**What to learn:** Which items for which stores?

```swift
func learnStoreItemAffinity(task: Task) {
    guard let store = task.store, let items = task.checklistItems else { return }
    
    for item in items {
        StoreLearning.shared.recordItemAffinity(
            itemName: item.name,
            storeName: store,
            wasStarred: item.isStarred,
            quantity: item.quantity
        )
    }
}

// Learn:
// - "Organic milk" → Whole Foods (not Costco)
// - "Bulk items" → Costco
// - "Specialty cheese" → Trader Joe's

// AI suggests:
// User: "Add milk to my grocery list"
// AI: "You usually get milk at Whole Foods. Add there?"
```

---

### 8.9 Completion Time Learning
**What to learn:** How long does user take to complete different tasks?

```swift
func learnCompletionPatterns(task: Task) {
    guard let completedAt = task.completedAt else { return }
    
    let completionTime = completedAt.timeIntervalSince(task.createdAt)
    let hours = completionTime / 3600
    
    CompletionLearning.shared.record(
        category: task.category,
        title: task.title,
        hoursToComplete: hours,
        wasPinned: task.isPinned,
        hadDueDate: task.dueDate != nil
    )
}

// Learn:
// - "Groceries": Completed same day (4-8 hours)
// - "Work tasks": Completed within 48 hours
// - "Personal": Takes 3-7 days

// AI can set realistic due dates:
// User: "Fix the leaky faucet"
// AI: "You usually complete home tasks within 3 days. Set due date for Wednesday?"
```

---

### 8.10 Conversation Style Learning
**What to learn:** How does THIS user talk to the AI?

```swift
func learnConversationStyle(messages: [ConversationMessage]) {
    // Learn user's preferred verbosity
    let avgUserMessageLength = messages
        .filter { $0.role == "user" }
        .map { $0.content.count }
        .average()
    
    // Learn: User prefers short commands vs full sentences
    // Learn: User says "please" often (polite tone preference)
    // Learn: User uses specific filler words
    
    ConversationLearning.shared.record(
        avgMessageLength: avgUserMessageLength,
        politenessMarkers: detectPoliteness(messages),
        preferredConfirmationStyle: detectConfirmationPreference(messages)
    )
}

// AI adapts:
// Concise user: "Groceries. Today." → AI responds concisely
// Verbose user: "I need to buy some groceries for dinner tonight..." → AI matches energy
```

---

## Summary: All Contextual Dimensions

| Dimension | What AI Learns | Example Smart Behavior |
|-----------|----------------|------------------------|
| **Vocabulary** | Proper nouns, spellings | "TuffTek" not "Tough Tech" |
| **Categories** | Word → category mapping | "Milk" → Groceries |
| **Time** | When user adds times | "Meetings" get times, "Groceries" don't |
| **Priority** | Keywords → urgency | "Client" = high priority |
| **Due Dates** | Planning horizon | Work = 3 days, Groceries = today |
| **Sharing** | Who gets what | Groceries → spouse automatically |
| **Stores** | Item → store affinity | "Organic" → Whole Foods |
| **Pins** | What gets pinned | "ASAP" tasks get pinned |
| **Recurrence** | Hidden patterns | "Weekly report" every Friday |
| **Completion** | How fast user works | Set realistic due dates |
| **Conversation** | User's style | Match verbosity/politeness |

**Result:** After 2-3 weeks, the AI feels like it "gets" this specific user.

---

## 💡 Future Considerations (v1.2+)

### Not Urgent But Nice

1. **Live Transcription Streaming**
   - Current: Waits for silence, then sends
   - Future: Stream partial transcription for "live subtitles" effect

2. **Voice Authentication**
   - Use voice biometrics for sensitive operations
   - "Share with Sarah" requires voice match

3. **Offline Mode**
   - Queue voice requests when offline
   - Process when connection restored

4. **Custom Wake Words**
   - "Hey Docket" instead of tapping mic
   - Requires Always-On microphone permission

---

## 📊 Analytics to Add

Track these metrics to understand usage:

```swift
// In VoiceRecordingView
Analytics.track("voice_session_started")
Analytics.track("voice_session_ended", [
    "duration_seconds": elapsed,
    "tasks_created": taskCount,
    "turns": messages.count,
    "used_tts": ttsManager.isSpeaking,
    "tts_voice": ttsManager.openAITTSVoice
])

// Track errors
Analytics.track("voice_error", [
    "type": "transcription_failed",
    "retry_count": retryCount
])
```

**Why:** Understand if users actually use voice vs tap-to-create.

---

## 🎉 Summary

| Priority | Category | Effort | Impact |
|----------|----------|--------|--------|
| P1 | Audio polling throttle | 5 min | High (battery) |
| P1 | Rate limiting | 30 min | High (cost protection) |
| P1 | Multi-field learning | 4 hours | **Critical (retention)** |
| P2 | Request timeout | 10 min | Medium (UX) |
| P2 | Context trimming | 20 min | Medium (cost) |
| P3 | Retry logic | 30 min | Medium (reliability) |
| P3 | Confirmation editing | 2 hours | High (UX) |
| P3 | Contextual use cases (P8) | 3 hours | **High (differentiation)** |
| P4 | Pre-launch testing | 4 hours | Critical |

**Total effort to address P1-P3:** ~9 hours  
**Time to TestFlight-ready:** ~2-3 days (with full learning system)

---

## 🎯 Multi-Field Learning: The Big Picture

This is not just about fixing typos. It's about building a **personal AI** that understands:

| Field | What AI Learns | Example |
|-------|----------------|---------|
| **Title** | Proper nouns, company names, project codes | "TuffTek" not "Tough Tech" |
| **Notes** | Context patterns, person names, meeting details | "Discuss Q4 roadmap with Sarah" |
| **Category** | User's preferred categorization | "Groceries" not "Shopping" for food |
| **Store** | Canonical names, aliases, typical items | "Kroger" not "Krogers" |
| **Items** | Ingredient preferences, frequently bought together | User always gets "salsa + chips" |
| **Templates** | When to use vs. when to ask | Dinner party ≠ auto-Costco |

**Result:** After 2-3 weeks of use, the AI knows the user better than any generic assistant.

---

*Questions or want to discuss any of these? Ping me!* ⚡
