# GameFi Focus Mode: Town Builder Concept V2

*Updated specification based on user feedback*  
*Created: 2026-02-11*  
*Status: MVP Design Complete*

---

## Core Vision (Updated)

**Focus Session Flow:**
```
Select Timer (15/30/45 min) → Pick Resource → Focus Timer → Gather Resources
```

**Monetization:**
- Free: Standard gathering rates
- Pro ($8.99/month): Accelerated gathering (2x rate + bonus resources)

**Visual Style:**
- Emojis + SF Symbols (no custom art needed)
- Simple grid map (future: pixel art)
- Infinity/moving background during focus
- Breathing pulse on progress ring

---

## Focus Session UI

### Main Focus View

```
┌─────────────────────────────────────────┐
│                                         │
│  🪵 142  ⚒️ 58  💰 23  🌾 89  🪨 12    │  ← Total resources (top)
│                                         │
│                                         │
│        ╭─────────────────╮              │
│       ╱                   ╲             │
│      │         ◐           │            │  ← Giant progress ring
│      │       Pulsing       │            │     (breathing animation)
│      │       0%            │            │
│       ╲                   ╱             │
│        ╰─────────────────╯              │
│                                         │
│         ┌─────────┐                     │
│         │  ⏱️ 30  │                     │  ← Timer selector
│         │  min    │                     │
│         └─────────┘                     │
│                                         │
│    [15]    [30]★    [45]                │  ← 15 / 30 / 45 min options
│                                         │
│         Pick your resource:             │
│                                         │
│  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐   │
│  │ 🪵  │  │ ⚒️  │  │ 💰  │  │ 🌾  │   │  ← Resource selection
│  │Wood │  │Iron │  │Gold │  │Food │   │
│  │ 30  │  │ 15  │  │ 6   │  │ 60  │   │  ← Amount (30 min × rate)
│  └─────┘  └─────┘  └─────┘  └─────┘   │
│                                         │
│         [Start Focus Session]           │
│                                         │
└─────────────────────────────────────────┘
        ↓ (Background: Infinity/warp)
```

### Active Focus View (Timer Running)

```
┌─────────────────────────────────────────┐
│  🪵 142  ⚒️ 58  💰 23  🌾 89  🪨 12    │
│                                         │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  ◄═════◄═════◄ Infinity Warp ►═════►  │  ← Moving background
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                         │
│        ╭─────────────────╮              │
│       ╱    ◐──╮         ╲             │  ← Ring fills over time
│      │    /    \         │            │
│      │   │ 28:45 │        │            │  ← Countdown timer
│      │    \    /         │            │
│       ╲    ╰──╯         ╱             │
│        ╰─────────────────╯              │
│                                         │
│      Gathering: 🪵 Wood                 │
│      Rate: 1 per minute                 │
│      Est. gain: 30 wood                 │
│                                         │
│         [Cancel]   [Pause]              │
│                                         │
└─────────────────────────────────────────┘
```

### Background Animation

**Infinity/Warp Effect:**
```swift
// SwiftUI implementation concept
struct InfinityBackground: View {
    @State private var phase: Double = 0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                // Draw flowing lines converging to center
                // Phase shifts over time for movement
                let t = timeline.date.timeIntervalSinceReferenceDate
                
                for i in 0..<20 {
                    let angle = Double(i) * .pi / 10 + sin(t + Double(i)) * 0.1
                    let path = createWarpLine(angle: angle, phase: t)
                    context.stroke(path, with: .color(.blue.opacity(0.3)), lineWidth: 2)
                }
            }
        }
    }
}
```

**Alternative:** Starfield particles moving toward center (simpler)

---

## Timer System

### Timer Options

| Duration | Base Gathering | Use Case |
|----------|---------------|----------|
| **15 min** | 15 resources | Quick focus, small tasks |
| **30 min** ⭐ | 30 resources | Standard pomodoro |
| **45 min** | 45 resources | Deep work sessions |

**Formula:** `Resources = Minutes × Base Rate`

### Resource Rates (Per Minute)

| Resource | Base Rate | Pro Rate (2x) | Pro + 1hr Bonus |
|----------|-----------|---------------|-----------------|
| 🪵 Wood | 1/min | 2/min | 2.5/min |
| ⚒️ Iron | 0.5/min | 1/min | 1.25/min |
| 💰 Gold | 0.2/min | 0.4/min | 0.5/min |
| 🌾 Food | 2/min | 4/min | 5/min |
| 🪨 Stone | 0.3/min | 0.6/min | 0.75/min |

### 1+ Hour Daily Bonus (Accelerated Gathering)

**Trigger:** Cumulative focus time > 60 minutes in one day

**Effect:** +25% gathering rate for rest of day

**Example Day (Free User):**
- 9:00 AM: 30 min Wood → 30 🪵
- 11:00 AM: 30 min Iron → 15 ⚒️
- **Total: 60 min** → Bonus activated! 🎉
- 2:00 PM: 30 min Wood (bonus) → 37 🪵 (30 × 1.25)
- 4:00 PM: 15 min Gold (bonus) → 3.75 💰 (15 × 0.2 × 1.25)

**Example Day (Pro User):**
- 9:00 AM: 30 min Wood (2x) → 60 🪵
- 11:00 AM: 30 min Iron (2x) → 30 ⚒️
- **Total: 60 min** → Bonus activated! 🎉
- 2:00 PM: 30 min Wood (2x + 25%) → 75 🪵 (30 × 2 × 1.25)
- **Daily Total:** 165 🪵 + 30 ⚒️ (vs 60 🪵 + 15 ⚒️ free user)

---

## Pro Membership ($8.99/month)

### Pro Benefits

| Feature | Free | Pro |
|---------|------|-----|
| Gathering rate | 1x | 2x |
| Resource choices per session | 1 | 2 (pick 2 resources!) |
| Max daily sessions | 10 | Unlimited |
| 1+ hour bonus | +25% | +25% (stacks: 2x × 1.25 = 2.5x) |
| Exclusive buildings | ❌ | ✅ |
| Cloud backup | ❌ | ✅ |
| Ad-free | N/A | ✅ |

### Pro Gathering Example

**30-min session, Pro user, after 1hr bonus:**
```
Pick 2 resources: 🪵 Wood + ⚒️ Iron

Wood: 30 min × 2 (Pro) × 1.25 (Bonus) = 75 🪵
Iron: 30 min × 1 (Pro) × 1.25 (Bonus) = 37 ⚒️
─────────────────────────────────────────────
Total: 75 🪵 + 37 ⚒️ (112 resources!)
```

**Same session, Free user:**
```
Pick 1 resource: 🪵 Wood

Wood: 30 min × 1 (Free) = 30 🪵
─────────────────────────────────
Total: 30 🪵
```

**Pro advantage:** 3.7x more resources per session

---

## Resource System

### Core Resources (5 Types)

| Resource | Emoji | Use | Storage Cap |
|----------|-------|-----|-------------|
| **Wood** | 🪵 | Buildings, crafting | 500 |
| **Iron** | ⚒️ | Tools, weapons | 250 |
| **Gold** | 💰 | Premium items, speed-ups | 100 |
| **Food** | 🌾 | Population upkeep | 1000 (consumes daily) |
| **Stone** | 🪨 | Walls, fortifications | 300 |

### Visual Display

```
Top Bar (always visible):
┌─────────────────────────────────────────┐
│ 🪵 142  ⚒️ 58  💰 23  🌾 89  🪨 12    │
│                                         │
│ [Tap resource for details]              │
└─────────────────────────────────────────┘

Tap Wood 🪵 → Shows:
- Gathering rate: 1/min (2/min Pro)
- Storage: 142/500
- Daily production: ~60 (if consistent)
- Time to cap: 6 hours
```

---

## Town View (Future Feature)

### Simple Grid Layout (No 3D)

```
Town Level 3 (Population: 24)

    A    B    C    D    E
   ━━━━━━━━━━━━━━━━━━━━━━━━
1 │ 🏚️ │ 🏚️ │ 🌲 │ ⛏️ │ 🌾 │
2 │ 🏭 │ 🏰 │ ⬜️ │ ⬜️ │ ⬜️ │
3 │ 🌲 │ ⬜️ │ ⬜️ │ ⬜️ │ 🐄 │
4 │ ⬜️ │ ⬜️ │ ⬜️ │ ⚔️ │ ⬜️ │
   ━━━━━━━━━━━━━━━━━━━━━━━━

Legend:
🏚️ Hut      🏭 Workshop  🏰 Town Hall
🌲 Lumber   ⛏️ Mine      🌾 Farm
⚔️ Barracks 🐄 Pasture   ⬜️ Empty
```

**Visual Style:**
- 2D grid (like classic SimCity)
- Emojis on colored squares (SF Symbols for buildings)
- Tap empty square → Build menu
- Tap building → Upgrade/Info

**No pixel art needed** — clean emoji + color squares work great!

---

## Map View (Future Feature)

### Simple Grid (5×5)

```
World Map

   1     2     3     4     5
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
A │ 🌲 │ 🌲 │ ⛰️ │ ⛰️ │ 💎 │
B │ 🌲 │ 🏠 │ ➡️ │ ⛰️ │ 💎 │  ← You are at B2
C │ 🌾 │ 🌾 │ 🌊 │ 🌊 │ 🏴‍☠️ │
D │ ⬜️ │ ⬜️ │ 🌊 │ 🏴‍☠️ │ 🏴‍☠️ │
E │ ⬜️ │ ⬜️ │ ⬜️ │ 🏴‍☠️ │ 👹 │
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Legend:
🏠 Your Town    🌲 Forest (+Wood)  ⛰️ Mountain (+Iron/Stone)
🌾 Plains (+Food)  🌊 Water (need boats)  💎 Hills (+Gold)
🏴‍☠️ Unexplored  👹 Enemy Stronghold
```

**Movement:** Tap adjacent square to explore (costs resources)
**Combat:** Tap enemy to attack (async, not real-time)

---

## Implementation Priority

### MVP (Week 1-2): Focus Mode Only

**Files to create:**
- `FocusView.swift` - Main focus UI
- `FocusTimerManager.swift` - Timer logic
- `ResourceManager.swift` - Track resources
- `InfinityBackground.swift` - Moving background
- `ProgressRing.swift` - Giant pulsing ring

**Features:**
- ✅ Timer selection (15/30/45)
- ✅ Resource selection (5 types)
- ✅ Countdown timer
- ✅ Resource calculation
- ✅ Infinity background
- ✅ Breathing progress ring
- ✅ Resource totals display
- ✅ 1+ hour bonus logic

### Phase 2 (Week 3-4): Town Grid

- Simple 5×5 grid
- 5 building types (emoji-based)
- Tap to build/upgrade
- No combat yet

### Phase 3 (Month 2): Map + Combat

- 5×5 world map
- Exploration costs
- Async PvP battles
- Pro membership unlocks

---

## Monetization Integration

### StoreKit Purchase

```swift
class SubscriptionManager: ObservableObject {
    @Published var isPro: Bool = false
    
    let proProductId = "com.docket.pro.monthly"
    
    func purchasePro() async throws {
        // StoreKit 2 implementation
    }
    
    func checkProStatus() {
        // Verify receipt, update isPro
    }
}
```

### Pro Check in Resource Calculation

```swift
func calculateGathering(
    duration: Int,        // minutes
    resource: Resource,
    isPro: Bool,
    dailyFocusMinutes: Int
) -> Int {
    let baseRate = resource.baseRate
    let proMultiplier = isPro ? 2.0 : 1.0
    let bonusMultiplier = dailyFocusMinutes >= 60 ? 1.25 : 1.0
    
    return Int(Double(duration) * baseRate * proMultiplier * bonusMultiplier)
}
```

---

## Breathing Animation Spec

### Progress Ring Pulse

```swift
struct BreathingProgressRing: View {
    let progress: Double  // 0.0 - 1.0
    let isActive: Bool    // true when timer running
    
    @State private var breathPhase: Double = 0
    
    var body: some View {
        ZStack {
            // Base ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 20)
            
            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.blue.gradient,
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Breathing glow (when active)
            if isActive {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 20 + sin(breathPhase) * 5)
                    .blur(radius: 10)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breathPhase = .pi * 2
            }
        }
    }
}
```

**Effect:** Ring subtly expands/contracts (4 second cycle) when timer active — calming, meditative

---

## Summary of Changes

| Feature | Original | Updated |
|---------|----------|---------|
| Timer | Fixed 25 min | 15/30/45 min choice |
| Resources | Session-based | Minute-based calculation |
| Pro price | Not specified | $8.99/month |
| Pro benefit | Not specified | 2x rate + 2 resources + bonus |
| Bonus | Per session | 1+ hour daily = +25% |
| Background | None | Infinity/warp animation |
| Ring | Static | Breathing pulse when active |
| Resources top bar | Not specified | Always visible |
| Map | Hex grid | Simple square grid |
| Art style | Unclear | Emojis + SF Symbols |

---

**Ready to implement?** Start with FocusView.swift (timer + resource selection), then add the infinity background and breathing ring.
