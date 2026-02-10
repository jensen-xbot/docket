# Jensen's Suggestions — Phase 10 Implementation Reference

*Reviewed: 2026-02-09 | Cleaned: 2026-02-10*
*Actionable items moved to TODO.md. This file is a code blueprint for Phase 10 (Personalization).*

---

## Multi-Field Learning System (Phase 10 Blueprint)

### UserContextManager — Core Swift Implementation

```swift
// UserContextManager.swift
@Observable
class UserContextManager {
    static let shared = UserContextManager()
    
    func trackTaskChanges(task: Task, snapshot: TaskSnapshot) {
        guard task.source == .voice else { return }
        
        var allChanges: [FieldCorrection] = []
        
        // 1. TITLE
        if task.title != snapshot.title {
            let titleChanges = detectWordChanges(
                original: snapshot.title,
                corrected: task.title,
                fieldType: .title
            )
            allChanges.append(contentsOf: titleChanges)
        }
        
        // 2. NOTES
        if task.notes != snapshot.notes {
            let noteChanges = extractVocabularyFromNotes(
                original: snapshot.notes ?? "",
                corrected: task.notes ?? ""
            )
            allChanges.append(contentsOf: noteChanges)
            learnContextualPhrases(from: task.notes, forTask: task)
        }
        
        // 3. CATEGORY
        if task.category != snapshot.category {
            learnCategoryMapping(
                aiSuggested: snapshot.category,
                userCorrected: task.category
            )
        }
        
        // 4. STORE
        if let store = task.store, store != snapshot.store {
            learnStoreName(aiSuggested: snapshot.store, userCorrected: store)
        }
        
        // 5. CHECKLIST ITEMS
        let originalItems = Set(snapshot.checklistItems.map { $0.name })
        let correctedItems = Set(task.checklistItems.map { $0.name })
        for item in correctedItems.subtracting(originalItems) {
            learnIngredientOrItem(item, context: task.category)
        }
        
        // 6. TEMPLATES
        if task.isTemplateEdit {
            learnTemplateModifications(task)
        }
        
        applyCorrections(allChanges)
        syncAllCorrections(allChanges, forTask: task)
    }
}
```

### Data Models

```swift
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
    case title, notes, category, store, checklistItem, ingredient
}

enum TaskSource: String, Codable {
    case voice, manual, shared, template
}
```

### Integration Points

**EditTaskView** — snapshot on appear, compare on disappear:
```swift
.onAppear {
    snapshot = TaskSnapshot(title: task.title, notes: task.notes, ...)
}
.onDisappear {
    if let snapshot { UserContextManager.shared.trackTaskChanges(task: task, snapshot: snapshot) }
}
```

**ChecklistEditorView** — track item add/remove:
```swift
.onChange(of: checklistItems) { oldItems, newItems in
    let snapshot = TaskSnapshot(... checklistItems: oldItems ...)
    UserContextManager.shared.trackTaskChanges(task: task, snapshot: snapshot)
}
```

---

## Edge Function: record-corrections

```typescript
// supabase/functions/record-corrections/index.ts

interface FieldCorrection {
  field: "title" | "notes" | "category" | "store" | "checklistItem";
  original: string;
  corrected: string;
  context?: string;
}

Deno.serve(async (req) => {
  const body = await req.json();
  
  const { data: profile } = await supabase
    .from('user_voice_profiles')
    .eq('user_id', user.id)
    .single();
  
  const updates = {
    custom_terms: profile?.custom_terms || [],
    name_corrections: profile?.name_corrections || [],
    category_mappings: profile?.category_mappings || [],
    store_aliases: profile?.store_aliases || [],
    ingredient_preferences: profile?.ingredient_preferences || [],
  };
  
  for (const correction of body.corrections) {
    switch (correction.field) {
      case "title": case "notes":
        if (looksLikeName(correction.corrected)) {
          updates.name_corrections.push({ spoken: correction.original, actual: correction.corrected, frequency: 1 });
        } else {
          updates.custom_terms.push({ term: correction.corrected, aliases: [correction.original], frequency: 1 });
        }
        break;
      case "category":
        updates.category_mappings.push({ ai_guess: correction.original, user_preference: correction.corrected, frequency: 1 });
        break;
      case "store":
        updates.store_aliases.push({ spoken: correction.original, canonical: correction.corrected });
        break;
      case "checklistItem":
        updates.ingredient_preferences.push({ name: correction.corrected, ai_guess: correction.original, frequency: 1 });
        break;
    }
  }
  
  // Deduplicate, rank by frequency, cap at 100 per field
  await supabase.from('user_voice_profiles').upsert({ user_id: user.id, ...updates });
  return new Response(JSON.stringify({ success: true, learned: body.corrections.length }));
});
```

---

## Database Schema: user_voice_profiles

```sql
CREATE TABLE user_voice_profiles (
  user_id UUID REFERENCES auth.users PRIMARY KEY,
  custom_terms JSONB DEFAULT '[]',           -- [{term, aliases[], category, frequency}]
  name_corrections JSONB DEFAULT '[]',       -- [{spoken, actual, context, frequency}]
  category_mappings JSONB DEFAULT '[]',      -- [{ai_guess, user_preference, trigger_words[], frequency}]
  store_aliases JSONB DEFAULT '[]',          -- [{spoken, canonical, typical_items[], frequency}]
  ingredient_preferences JSONB DEFAULT '[]', -- [{name, category, frequency, often_with[]}]
  contextual_patterns JSONB DEFAULT '[]',    -- [{phrase, associated_categories[], frequency}]
  template_preferences JSONB DEFAULT '[]',   -- [{store, preferred_items[], last_modified}]
  total_corrections INTEGER DEFAULT 0,
  last_correction_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_voice_profiles_user ON user_voice_profiles(user_id);
CREATE INDEX idx_voice_profiles_terms ON user_voice_profiles USING GIN (custom_terms);
```

---

## Learning Flow (Visual)

```
USER: "Add buy groceries at Krogers for dinner party"
  ↓
AI PARSES: Title="Buy groceries at Krogers", Category="Shopping", Store="Krogers"
  ↓
USER EDITS: Title="Buy groceries at Kroger", Category="Groceries", Store="Kroger"
  ↓
APP LEARNS:
  ├─ TITLE: "Krogers" → "Kroger"
  ├─ CATEGORY: "Shopping" → "Groceries" when store mentioned
  └─ STORE: "Krogers" → "Kroger" (canonical)
  ↓
NEXT TIME: AI uses "Kroger", "Groceries" automatically
```

---

## Contextual Learning Dimensions (Phase 10+)

| Dimension | What AI Learns | Smart Behavior |
|-----------|----------------|----------------|
| **Vocabulary** | Proper nouns, spellings | "TuffTek" not "Tough Tech" |
| **Categories** | Word → category mapping | "Milk" → Groceries |
| **Time** | When user adds times | "Meetings" get times, "Groceries" don't |
| **Priority** | Keywords → urgency | "Client" = high priority |
| **Due Dates** | Planning horizon | Work = 3 days, Groceries = today |
| **Sharing** | Who gets what | Groceries → spouse automatically |
| **Stores** | Item → store affinity | "Organic" → Whole Foods |
| **Pins** | What gets pinned | "ASAP" tasks get pinned |
| **Completion** | How fast user works | Set realistic due dates |

---

*This is a reference blueprint for Phase 10 implementation. Task tracking is in TODO.md.*
