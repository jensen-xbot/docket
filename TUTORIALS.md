# Docket Tutorials & Onboarding Guide

*Tutorial system for progressive feature discovery*  
*Created: 2026-02-10*

---

## Philosophy

**Don't explain everything at once.** Teach features as users encounter them, then never show again.

**Principles:**
1. **Contextual** — Show tutorial when feature is first used
2. **Brief** — 1-2 sentences max, visual demonstration
3. **Dismissible** — Tap to dismiss, never auto-repeat
4. **Trackable** — Log what's been seen, reset in settings

---

## Tutorial Registry

| # | Tutorial | Trigger | Content | Status |
|---|----------|---------|---------|--------|
| T1 | **Welcome** | First app open | "Tap below to create your first task. Type or speak to ask Docket anything." | 📝 Draft |
| T2 | **Completion Button** | First task created | "Tap once for progress • Double-tap to complete" | 📝 Draft |
| T3 | **Voice Input** | First tap on 5-bars in command bar | "Speak naturally • AI will ask follow-ups if needed" | 📝 Draft |
| T4 | **Sharing** | First share button tap | "Share tasks via email or text • Recipients can edit too" | 📝 Draft |
| T5 | **Templates** | First profile hub visit | "Create grocery templates for quick lists" | 📝 Draft |
| T6 | **Checklists** | First checklist added | "Add items • Track progress • Tap to complete each" | 📝 Draft |
| T7 | **Pin & Reorder** | Long press on task | "Hold and drag to reorder • Pin important tasks" | 📝 Draft |
| T8 | **Categories** | First category created | "Customize icons and colors • Organize your way" | 📝 Draft |
| T9 | **Notifications** | First due date set | "Enable notifications for reminders" | 📝 Draft |
| T10 | **Voice Corrections** | First AI mistake | "Tap to edit • AI learns from your corrections" | 📝 Draft |
| T11 | **Command Bar** | First app open (replaces T1) | "Type or speak to create tasks, find tasks, or ask Docket anything." | 📝 Draft |
| T12 | **Search Mode** | First time typing in command bar | "Tasks filter as you type. Hit send to ask the AI." | 📝 Draft |
| T13 | **Voice Mode** | First tap on 5-bars icon | "Speak naturally. AI extracts tasks and asks follow-ups." | 📝 Draft |
| T14 | **"+" Menu** | First long-press on (+) | "Create a manual task or attach a photo." | 📝 Draft |

---

## Tutorial T2: Completion Button (Priority)

**Trigger:** User creates first task (or first tap on completion button)

### Design

```
┌─────────────────────────────────────────┐
│                                         │
│   ┌─────────────────────────────────┐   │
│   │  📋 Progress & Completion       │   │
│   │                                 │   │
│   │  [◐] Tap once                   │   │
│   │      Show progress slider       │   │
│   │                                 │   │
│   │  [◐] → [✓] Double-tap           │   │
│   │      Complete immediately       │   │
│   │                                 │   │
│   │         [Got it]                │   │
│   └─────────────────────────────────┘   │
│                                         │
│   (Backdrop dimmed, modal centered)     │
└─────────────────────────────────────────┘
```

### Content

**Title:** Progress & Completion

**Body:**
```
[Animated GIF or looped video]

◐ Tap once
   Show progress slider

◐ → ✓ Double-tap  
   Complete immediately
```

**Button:** "Got it" (dismisses forever)

**Don't show again:** Store in UserDefaults
```swift
@AppStorage("hasSeenCompletionTutorial") 
var hasSeenCompletionTutorial = false
```

---

## Tutorial T3: Voice Input (Priority)

**Trigger:** First tap on 5-bars icon in command bar (voice mode)

### Design

```
┌─────────────────────────────────────────┐
│                                         │
│   ┌─────────────────────────────────┐   │
│   │  🎤 Voice Tasks                 │   │
│   │                                 │   │
│   │  "Email the client by Friday"   │   │
│   │                                 │   │
│   │  AI will:                       │   │
│   │  • Extract task & due date      │   │
│   │  • Suggest priority             │   │
│   │  • Ask follow-ups if unclear    │   │
│   │                                 │   │
│   │         [Try it]                │   │
│   └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Content

**Title:** 🎤 Voice Tasks

**Body:**
```
Speak naturally. Try:
"Email the client by Friday"

AI will extract:
• Task: Email the client
• Due: Friday
• Priority: Medium

AI asks follow-ups if needed.
```

**Button:** "Try it" (dismisses, starts recording)

---

## Implementation Architecture

### Tutorial Manager

```swift
import SwiftUI

@Observable
class TutorialManager {
    static let shared = TutorialManager()
    
    // MARK: - Tutorial State
    
    @AppStorage("tutorials.completed") 
    private var completedTutorials: [String] = []
    
    @AppStorage("tutorials.dismissed") 
    private var dismissedTutorials: [String] = []
    
    // MARK: - Tutorial Definitions
    
    enum TutorialID: String, CaseIterable {
        case welcome = "T1"
        case completion = "T2"
        case voice = "T3"
        case sharing = "T4"
        case templates = "T5"
        case checklists = "T6"
        case pinReorder = "T7"
        case categories = "T8"
        case notifications = "T9"
        case voiceCorrections = "T10"
        case commandBar = "T11"
        case searchMode = "T12"
        case voiceMode = "T13"
        case plusMenu = "T14"
        
        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .completion: return "Progress & Completion"
            case .voice: return "Voice Tasks"
            case .sharing: return "Share Tasks"
            case .templates: return "Templates"
            case .checklists: return "Checklists"
            case .pinReorder: return "Pin & Reorder"
            case .categories: return "Categories"
            case .notifications: return "Notifications"
            case .voiceCorrections: return "Voice Corrections"
            case .commandBar: return "Ask Docket"
            case .searchMode: return "Search Mode"
            case .voiceMode: return "Voice Mode"
            case .plusMenu: return "\"+\" Menu"
            }
        }
        
        var hasBeenSeen: Bool {
            TutorialManager.shared.hasCompleted(self) || 
            TutorialManager.shared.hasDismissed(self)
        }
    }
    
    // MARK: - Public Methods
    
    func shouldShow(_ tutorial: TutorialID) -> Bool {
        !tutorial.hasBeenSeen
    }
    
    func complete(_ tutorial: TutorialID) {
        if !completedTutorials.contains(tutorial.rawValue) {
            completedTutorials.append(tutorial.rawValue)
            Analytics.track("tutorial_completed", ["id": tutorial.rawValue])
        }
    }
    
    func dismiss(_ tutorial: TutorialID) {
        if !dismissedTutorials.contains(tutorial.rawValue) {
            dismissedTutorials.append(tutorial.rawValue)
            Analytics.track("tutorial_dismissed", ["id": tutorial.rawValue])
        }
    }
    
    func hasCompleted(_ tutorial: TutorialID) -> Bool {
        completedTutorials.contains(tutorial.rawValue)
    }
    
    func hasDismissed(_ tutorial: TutorialID) -> Bool {
        dismissedTutorials.contains(tutorial.rawValue)
    }
    
    func resetAll() {
        completedTutorials.removeAll()
        dismissedTutorials.removeAll()
        Analytics.track("tutorials_reset")
    }
    
    func reset(_ tutorial: TutorialID) {
        completedTutorials.removeAll { $0 == tutorial.rawValue }
        dismissedTutorials.removeAll { $0 == tutorial.rawValue }
    }
    
    // MARK: - Progress
    
    var completionPercentage: Double {
        let total = TutorialID.allCases.count
        let completed = TutorialID.allCases.filter { $0.hasBeenSeen }.count
        return Double(completed) / Double(total) * 100
    }
}
```

### Tutorial View Modifier

```swift
struct TutorialOverlay: ViewModifier {
    let tutorial: TutorialManager.TutorialID
    let content: () -> AnyView
    let onComplete: () -> Void
    
    @State private var isShowing = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if TutorialManager.shared.shouldShow(tutorial) {
                    // Delay slightly so UI settles
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isShowing = true
                    }
                }
            }
            .overlay {
                if isShowing {
                    TutorialModal(
                        tutorial: tutorial,
                        content: content(),
                        onDismiss: {
                            isShowing = false
                            TutorialManager.shared.dismiss(tutorial)
                        },
                        onComplete: {
                            isShowing = false
                            TutorialManager.shared.complete(tutorial)
                            onComplete()
                        }
                    )
                }
            }
    }
}

extension View {
    func tutorial(
        _ tutorial: TutorialManager.TutorialID,
        @ViewBuilder content: @escaping () -> some View,
        onComplete: @escaping () -> Void = {}
    ) -> some View {
        modifier(TutorialOverlay(
            tutorial: tutorial,
            content: { AnyView(content()) },
            onComplete: onComplete
        ))
    }
}
```

### Tutorial Modal Component

```swift
struct TutorialModal: View {
    let tutorial: TutorialManager.TutorialID
    let content: AnyView
    let onDismiss: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Modal
            VStack(spacing: 20) {
                content
                    .padding()
                
                HStack(spacing: 16) {
                    Button("Skip") {
                        onDismiss()
                    }
                    .foregroundColor(.secondary)
                    
                    Button(action: onComplete) {
                        Text("Got it")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(40)
        }
    }
}
```

---

## Usage Examples

### TaskListView — Completion Tutorial

```swift
struct TaskListView: View {
    @State private var showCompletionTutorial = false
    
    var body: some View {
        List {
            ForEach(tasks) { task in
                TaskRowView(task: task)
            }
        }
        .tutorial(.completion) {
            VStack(spacing: 16) {
                Text("📋 Progress & Completion")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    VStack {
                        Circle()
                            .stroke(Color.blue, lineWidth: 3)
                            .frame(width: 44, height: 44)
                            .overlay(Text("◐").font(.title2))
                        Text("Tap once\nfor progress")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 44, height: 44)
                            .overlay(Image(systemName: "checkmark").foregroundColor(.white))
                        Text("Double-tap\nto complete")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }
}
```

### VoiceRecordingView — Voice Tutorial

```swift
struct VoiceRecordingView: View {
    var body: some View {
        // Voice UI...
        .tutorial(.voice) {
            VStack(spacing: 16) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("🎤 Speak Naturally")
                    .font(.headline)
                
                Text("\"Email the client by Friday\"")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Extracts task & due date")
                    Text("• Suggests priority")
                    Text("• Asks follow-ups if needed")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        } onComplete: {
            // Auto-start recording after tutorial
            startRecording()
        }
    }
}
```

---

## Settings Integration

Users can reset tutorials in Settings:

```swift
struct SettingsView: View {
    var body: some View {
        Section("Tutorials") {
            NavigationLink("Viewed Tutorials") {
                TutorialProgressView()
            }
            
            Button("Reset All Tutorials") {
                showResetConfirmation = true
            }
            .foregroundColor(.red)
        }
    }
}

struct TutorialProgressView: View {
    var body: some View {
        List {
            ForEach(TutorialManager.TutorialID.allCases, id: \.self) { tutorial in
                HStack {
                    Text(tutorial.title)
                    Spacer()
                    if tutorial.hasBeenSeen {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Text("Not seen")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Text("\(Int(TutorialManager.shared.completionPercentage))% Complete")
                    .font(.headline)
            }
        }
        .navigationTitle("Tutorials")
    }
}
```

---

## Analytics to Track

```swift
// Tutorial events
Analytics.track("tutorial_shown", ["id": "T2"])
Analytics.track("tutorial_completed", ["id": "T2"])
Analytics.track("tutorial_dismissed", ["id": "T2"])

// Completion rates
Analytics.track("tutorials_progress", [
    "completed": completedCount,
    "total": totalCount,
    "percentage": completionPercentage
])

// Feature usage after tutorial
Analytics.track("feature_used_after_tutorial", [
    "tutorial": "T2",
    "feature": "progress_slider",
    "time_since_tutorial": "2_days"
])
```

---

## Future Tutorials

| Tutorial | When | Content |
|----------|------|---------|
| T15 | First AI mistake | "AI learns from your edits" |
| T16 | First share accepted | "Shared tasks update in real-time" |
| T17 | First recurring task | "Tasks repeat automatically" |
| T18 | First widget added | "See tasks on your home screen" |
| T19 | 30 days usage | "Pro tips: Shortcuts, Siri, Watch" |

---

## Implementation Checklist

- [ ] Create `TutorialManager.swift`
- [ ] Create `TutorialModal.swift`
- [ ] Create `TutorialOverlay` view modifier
- [ ] Add T2 (Completion) to TaskListView
- [ ] Add T3 (Voice) to CommandBar (voice mode)
- [ ] Add Settings > Tutorials screen
- [ ] Add analytics tracking
- [ ] Test tutorial dismissal persists
- [ ] Test reset functionality

---

*Next: Implement TutorialManager and T2 (Completion tutorial) first*
