# Docket Tutorials & Onboarding Guide

*Track tutorial implementations and user onboarding flows*

---

## Overview

Docket uses **contextual tutorials** — brief, single-use hints that appear the first time a user encounters a feature. No lengthy onboarding screens. Just-in-time education.

**Philosophy:**
- Teach by doing, not by reading
- One hint per feature
- Never show twice
- Dismissible instantly

---

## Tutorial System Architecture

### Data Model
```swift
@Model
class TutorialState {
    @Attribute(.unique) var id: String
    var hasBeenShown: Bool = false
    var firstShownAt: Date?
    var dismissedAt: Date?
    
    init(id: String) {
        self.id = id
    }
}

// Tutorial IDs (add as needed)
extension TutorialState {
    static let progressButton = "progress_button_tutorial"
    static let voiceRecording = "voice_recording_tutorial"
    static let taskSharing = "task_sharing_tutorial"
    static let groceryTemplates = "grocery_templates_tutorial"
    static let pinReorder = "pin_reorder_tutorial"
    static let checklistItems = "checklist_items_tutorial"
}
```

### Tutorial Manager
```swift
@Observable
class TutorialManager {
    static let shared = TutorialManager()
    
    private var shownTutorials: Set<String> = []
    
    func shouldShow(_ tutorialId: String) -> Bool {
        !shownTutorials.contains(tutorialId)
    }
    
    func markAsShown(_ tutorialId: String) {
        shownTutorials.insert(tutorialId)
        // Persist to UserDefaults or SwiftData
        UserDefaults.standard.set(true, forKey: "tutorial_\(tutorialId)")
    }
    
    func resetAllTutorials() {
        shownTutorials.removeAll()
        // Clear UserDefaults
        TutorialState.allCases.forEach { id in
            UserDefaults.standard.removeObject(forKey: "tutorial_\(id)")
        }
    }
}
```

---

## Tutorial Implementations

### ✅ Completed Tutorials

| Tutorial ID | Feature | Status | Date Completed |
|-------------|---------|--------|----------------|
| *None yet* | — | — | — |

---

### 🚧 Planned Tutorials

#### 1. Progress Button Tutorial
**Tutorial ID:** `progress_button_tutorial`  
**Trigger:** First tap on completion button  
**Priority:** 🔴 HIGH (core interaction)

**Design:**
```
┌─────────────────────────────────────────┐
│                                         │
│   [Tooltip Popup]                       │
│   ┌───────────────────────────────┐    │
│   │  💡 New: Progress Tracking    │    │
│   │                               │    │
│   │  Tap ONCE → Set progress      │    │
│   │  Tap TWICE → Complete now     │    │
│   │                               │    │
│   │  [Got it]                     │    │
│   └───────────────────────────────┘    │
│                                         │
│   ◐  Task Title                     📌  │
│      Due tomorrow · Work                │
│   ▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░  25%    │
│                                         │
└─────────────────────────────────────────┘
```

**Implementation:**
```swift
// In TaskRowView
.completionButton(
    onTap: {
        if TutorialManager.shared.shouldShow(.progressButton) {
            showTutorial(.progressButton)
        } else {
            showProgressSlider()
        }
    }
)

func showTutorial(_ id: String) {
    let tooltip = TooltipView(
        title: "💡 New: Progress Tracking",
        message: "Tap ONCE → Set progress\nTap TWICE → Complete now",
        action: "Got it",
        onDismiss: {
            TutorialManager.shared.markAsShown(id)
            showProgressSlider() // Continue with normal action
        }
    )
    present(tooltip)
}
```

---

#### 2. Voice Recording Tutorial
**Tutorial ID:** `voice_recording_tutorial`  
**Trigger:** First tap on mic button  
**Priority:** 🔴 HIGH (key differentiator)

**Design:**
```
┌─────────────────────────────────────────┐
│                                         │
│   [Full-screen overlay]                 │
│                                         │
│        🎤                               │
│                                         │
│   Speak naturally to create tasks       │
│                                         │
│   "Email the client by Friday,          │
│    it's urgent"                         │
│                                         │
│   ↓                                     │
│                                         │
│   AI will ask follow-up questions       │
│   if needed                             │
│                                         │
│        [Start Speaking]                 │
│                                         │
└─────────────────────────────────────────┘
```

**Text:**
- **Title:** "Voice-to-Task"
- **Body:** "Speak naturally. The AI will understand and create tasks. You can even update tasks by voice."
- **Button:** "Try It"
- **Secondary:** "Show me an example"

**Example Flow:**
```
User taps "Show me an example"
→ Play 3-second demo: "Buy groceries tomorrow"
→ Show AI response animation
→ User taps "Try It" → Start real recording
```

---

#### 3. Task Sharing Tutorial
**Tutorial ID:** `task_sharing_tutorial`  
**Trigger:** First tap on share button  
**Priority:** 🟡 MEDIUM

**Design:**
```
┌─────────────────────────────────────────┐
│                                         │
│   ┌───────────────────────────────┐    │
│   │  🤝 Share Tasks               │    │
│   │                               │    │
│   │  Share any task via email     │    │
│   │  or text message.             │    │
│   │                               │    │
│   │  Recipients can edit tasks    │    │
│   │  in real-time.                │    │
│   │                               │    │
│   │  [Got it]                     │    │
│   └───────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

---

#### 4. Grocery Templates Tutorial
**Tutorial ID:** `grocery_templates_tutorial`  
**Trigger:** First open of Profile → Store Templates  
**Priority:** 🟢 LOW (power user feature)

---

#### 5. Pin & Reorder Tutorial
**Tutorial ID:** `pin_reorder_tutorial`  
**Trigger:** First long-press on task  
**Priority:** 🟡 MEDIUM

---

#### 6. Checklist Items Tutorial
**Tutorial ID:** `checklist_items_tutorial`  
**Trigger:** First task with checklist created  
**Priority:** 🟢 LOW

---

## Tutorial UI Components

### Tooltip Popup
```swift
struct TooltipView: View {
    let title: String
    let message: String
    let action: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: onDismiss) {
                Text(action)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding(32)
    }
}
```

### Highlight Overlay
```swift
struct HighlightOverlay: View {
    let targetFrame: CGRect
    let tooltip: TooltipView
    
    var body: some View {
        ZStack {
            // Dimmed background with cutout
            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .mask(
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black)
                                        .frame(width: targetFrame.width + 8, height: targetFrame.height + 8)
                                        .position(x: targetFrame.midX, y: targetFrame.midY)
                                )
                        )
                }
            }
            
            // Tooltip positioned near target
            tooltip
                .position(x: tooltipPosition.x, y: tooltipPosition.y)
        }
    }
}
```

---

## Onboarding Flow (First Launch)

### Option A: Minimal (Recommended)
**No forced onboarding.** Just contextual tutorials as user discovers features.

### Option B: Quick Intro (If Needed)
**3-screen intro, skippable:**

**Screen 1:**
```
Welcome to Docket
Simple task management with AI voice input

[Next] [Skip]
```

**Screen 2:**
```
Track Progress
Tap once to set progress
Tap twice to complete

[Next] [Skip]
```

**Screen 3:**
```
You're Ready
Start adding tasks. We'll show tips as you go.

[Get Started]
```

---

## Settings: Reset Tutorials

**Location:** Profile → Settings → Reset Tips

```swift
Section("Help") {
    Button("Show All Tips Again") {
        TutorialManager.shared.resetAllTutorials()
        // Show confirmation toast
    }
    
    NavigationLink("How to Use Docket") {
        HelpCenterView()
    }
}
```

---

## Analytics

Track tutorial effectiveness:

```swift
Analytics.track("tutorial_shown", [
    "tutorial_id": id,
    "context": "first_use"
])

Analytics.track("tutorial_dismissed", [
    "tutorial_id": id,
    "time_shown": elapsedTime,
    "action": "got_it" // or "dismissed"
])

Analytics.track("tutorial_action_taken", [
    "tutorial_id": id,
    "action": "used_feature_after_tutorial"
])
```

**Success Metrics:**
- % users who see tutorial → use feature
- Time from tutorial → feature use
- % users who dismiss without reading

---

## Implementation Checklist

- [ ] Create TutorialState data model
- [ ] Create TutorialManager
- [ ] Build TooltipView component
- [ ] Build HighlightOverlay component
- [ ] Implement progress button tutorial
- [ ] Implement voice recording tutorial
- [ ] Implement task sharing tutorial
- [ ] Add "Reset Tips" setting
- [ ] Add analytics tracking
- [ ] Test all tutorials on device
- [ ] Localization (if needed)

---

*Document created: 2026-02-10*  
*Related: JENSEN_SUGGESTIONS_2.md (progress system)*
