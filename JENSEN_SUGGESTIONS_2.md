# Jensen's Suggestions 2: Interactive Progress & Completion System

*Documented: 2026-02-10*  
*Based on: Voice-to-Task v1.1+ implementation*

---

## 1. Recurring Tasks (Simple Implementation)

### Placement
- **Location:** Inside task edit view, near Calendar/Time settings
- **Icon:** 🔄 Recurring loop icon
- **UI:** Toggle switch or picker

### Design
```
Due Date: [Tomorrow] [🕐 3:00 PM]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[🔄] Recurring: [Weekly ▼]
```

### Behavior
- Tap recurring icon → Show recurrence options (Daily, Weekly, Monthly)
- Simple implementation first — no complex recurrence patterns
- Store as `recurrenceRule: String?` (nil = not recurring)

---

## 2. Interactive Progress System (Primary Feature)

### Philosophy
- **All tasks have progress** — not just checklist tasks
- **Quick tracking** — users don't need to define activities, just track % done
- **Zero clutter** — progress shown inline, no extra UI elements

---

## 3. Task Row Design (Current → New)

### Current TaskRowView
```
┌─────────────────────────────────────────┐
│ ○  Task Title                       📌  │
│    Due date · Priority · Category       │
│ ──────────────────────────────────────  │  ← Grey separator bar
└─────────────────────────────────────────┘
```

### New TaskRowView with Progress
```
┌─────────────────────────────────────────┐
│ ◐  Task Title                       📌  │  ← Progress ring in button
│    Due date · Priority · Category       │
│ ▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░  35%  │  ← Grey bar + light blue progress
└─────────────────────────────────────────┘
```

**Visual Elements:**
1. **Progress Ring (◐)** — Inside completion button, shows %
2. **Progress Bar** — Grey separator bar fills with light blue from left
3. **Percentage** — Shown inside progress bar (e.g., "35%")

---

## 4. Interaction Model

### Single Tap (Tap Once)
**Action:** Reveal interactive progress slider below task

```
┌─────────────────────────────────────────┐
│ ◐  Task Title                       📌  │
│    Due date · Priority · Category       │
│ ▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░  35%  │
│                                         │
│ ┌──────────────────────────────────┐   │
│ │  ○━━━━━━━●━━━━━━━━━━━━━━━━━━━━━○ │   │  ← Slider 0-100%
│ │        35%                       │   │
│ └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Slider Behavior:**
- Drag left-to-right to set progress
- Real-time update of ring + bar above
- Percentage updates as you drag
- Tap elsewhere or swipe to dismiss

### Double Tap (Tap Twice Quickly)
**Action:** Immediately mark task complete (100%)

```
┌─────────────────────────────────────────┐
│ ✓  Task Title (strikethrough)       📌  │
│    Due date · Priority · Category       │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 100%│  ← Full bar, green or blue
└─────────────────────────────────────────┘
```

**Animation:**
- Ring fills to 100%
- Bar fills completely
- Checkmark appears (✓)
- Task strikethrough
- 0.3s spring animation

### Hold & Drag (Existing)
**Preserved:** Current drag-and-drop reorder system remains unchanged

---

## 5. Color System

### Progress Colors
| State | Color | Usage |
|-------|-------|-------|
| 0-25% | Light grey | Just started |
| 26-50% | Light blue | In progress |
| 51-75% | Medium blue | Getting there |
| 76-99% | Bright blue | Almost done |
| 100% | Green or checkmark | Complete |

### Progress Ring
- **Stroke:** 2-3pt
- **Color:** Matches progress bar
- **Background:** Grey track
- **Filled portion:** Blue gradient

### Progress Bar (Separator)
- **Background:** Light grey (#E5E5E5)
- **Fill:** Light blue (#007AFF or app accent)
- **Height:** 2-3pt (same as current separator)
- **Percentage text:** White or dark, centered in fill

---

## 6. Checklist Integration (Future v1.3+)

### Phase 1: Simple Tasks (Now)
- Single progress slider
- No defined activities
- User tracks mental progress

### Phase 2: Checklist Tasks (Future)
**Dropdown Reveal:**
```
┌─────────────────────────────────────────┐
│ ◐  Task Title                       📌  │
│    Due date · Priority · Category       │
│ ▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░  35%  │  ← Aggregate progress
│                                         │
│ ▼ Activities (3)                        │  ← Tap to expand
│ ──────────────────────────────────────  │
│   ○━━━●━━━━━━○ Email Carol          30% │
│   ◐░░░░░░░░░░░ Call TuffTek team     40% │
│   ○○○○○○○○○○○○ Get approval           0% │
└─────────────────────────────────────────┘
```

**Each Activity:**
- Has own progress ring (◐ ◑ ◒ ◓ ◔ ◕)
- Has own mini progress bar
- Swipe to set progress (same interaction)
- **Aggregate progress** = average of all activities

**Example:**
- Activity 1: 30%
- Activity 2: 40%  
- Activity 3: 0%
- **Task Progress:** (30+40+0)/3 = 23%

---

## 7. Data Model Updates

### Task Model (Addition)
```swift
@Model
class Task {
    // Existing fields...
    
    // NEW: Progress tracking
    var progressPercentage: Double = 0.0  // 0.0 - 100.0
    var lastProgressUpdate: Date?
    
    // Recurring
    var recurrenceRule: String?  // nil = not recurring
    
    // Computed
    var isCompleted: Bool {
        progressPercentage >= 100.0
    }
}
```

### Activity Model (Future - Phase 2)
```swift
@Model
class TaskActivity {
    @Attribute(.unique) var id: UUID
    var task: Task?
    var title: String
    var progressPercentage: Double = 0.0
    var sortOrder: Int = 0
    
    init(title: String, sortOrder: Int) {
        self.id = UUID()
        self.title = title
        self.sortOrder = sortOrder
    }
}
```

---

## 8. UI Implementation Details

### Progress Ring (Inside Button)
```swift
struct ProgressRing: View {
    let progress: Double  // 0.0 - 100.0
    let lineWidth: CGFloat = 3
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: lineWidth)
            
            // Progress arc
            Circle()
                .trim(from: 0, to: progress / 100)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Center icon
            if progress >= 100 {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
            } else if progress > 0 {
                Text("\(Int(progress))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
    
    var progressColor: Color {
        switch progress {
        case 0..<25: return .gray
        case 25..<50: return .blue.opacity(0.5)
        case 50..<75: return .blue.opacity(0.7)
        case 75..<100: return .blue
        default: return .green
        }
    }
}
```

### Progress Bar (Separator)
```swift
struct ProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                
                // Fill
                Rectangle()
                    .fill(progressColor)
                    .frame(width: geometry.size.width * (progress / 100))
                
                // Percentage text (if room)
                if progress > 15 {
                    Text("\(Int(progress))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                }
            }
        }
        .frame(height: 3)
    }
}
```

### Interactive Slider (Expandable)
```swift
struct ProgressSlider: View {
    @Binding var progress: Double
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Slider(value: $progress, in: 0...100, step: 5)
                .tint(.blue)
            
            HStack {
                Text("0%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(progress))%")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("100%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
```

---

## 9. Gesture Handling

```swift
struct CompletionButton: View {
    @Binding var progress: Double
    let onComplete: () -> Void
    
    @State private var tapCount = 0
    @State private var lastTapTime: Date?
    
    var body: some View {
        ProgressRing(progress: progress)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }
    }
    
    private func handleTap() {
        let now = Date()
        
        // Check for double tap (within 0.3 seconds)
        if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) < 0.3 {
            // Double tap = complete immediately
            withAnimation(.spring()) {
                progress = 100
            }
            onComplete()
            tapCount = 0
        } else {
            // Single tap = show progress slider
            tapCount = 1
            showProgressSlider()
        }
        
        lastTapTime = now
    }
    
    private func showProgressSlider() {
        // Emit event to parent view to show slider
        // Use NotificationCenter or binding
    }
}
```

---

## 10. Summary of Interactions

| Gesture | Action | Result |
|---------|--------|--------|
| **Single Tap** | Show progress slider | Interactive 0-100% control |
| **Double Tap** | Complete immediately | 100% + checkmark |
| **Hold + Drag** | Reorder task | Current drag-and-drop preserved |
| **Swipe Right** | Quick actions | Pin/complete (existing) |
| **Swipe Left** | Delete | Existing behavior |

---

## 11. Benefits

1. **No Clutter** — Uses existing button + separator space
2. **Universal** — Works for ALL tasks, not just checklist tasks
3. **Flexible** — User decides what "35%" means mentally
4. **Scalable** — Future checklist items integrate naturally
5. **Fast** — Double-tap to complete, single-tap for precision
6. **Visual** — At-a-glance progress on task list

---

*Next: See TUTORIALS.md for onboarding flow to teach these interactions*
