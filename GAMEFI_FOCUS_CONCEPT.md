# GameFi Focus Mode: Town Builder Concept V3

*Final specification with economy design, progression, and subscription bundling*  
*Created: 2026-02-11*  
*Last Updated: 2026-02-11*  
*Status: V3 — Ready for Implementation*

*References: [GAMEFI_FOCUS_PLAN.md](GAMEFI_FOCUS_PLAN.md) (how we're building it) | [GAMEFI_FOCUS_TODO.md](GAMEFI_FOCUS_TODO.md) (step-by-step tasks)*

---

## Core Vision

**Focus Session Flow:**
```
Task Row → Focus Button → Full-Screen Focus Zone → Pick Timer → Pick Resource → Focus → Gather Resources
```

**Entry Point:** Focus button (SF Symbol `scope` or `flame.fill`) appears at the right end of the progress slider row on any task. Tapping it opens a full-screen focus experience with hero transition.

**Monetization (Bundled Subscription):**
- Free: Standard gathering rates + 5 voice tasks/month
- Pro ($8.99/month): Accelerated gathering (2x rate + bonus resources) + unlimited voice-to-task

**Visual Style:**
- Pixel art for focus session (parallax background, resource icons) — the "wow" moment
- Emojis for town grid (charming, ships fast, pixel art upgrade later)
- Breathing pulse on progress ring
- Infinity/parallax scrolling background during focus

---

## Focus Session UI

### Entry Point (Task List)

```
┌─────────────────────────────────────────────┐
│ ◐ Buy groceries                        📌   │
│ ↑med  🛒 Shopping  📅 Tomorrow              │
│                                              │
│  [──────────Slider──────────] [🎯]          │  ← Focus button on slider row
│                                  ↑           │
│                           Tap to focus       │
└─────────────────────────────────────────────┘
```

### Main Focus View (Pre-Session)

```
┌─────────────────────────────────────────┐
│                                         │
│  🪵 142  ⚒️ 58  💰 23  🌾 89  🪨 12    │  ← Total resources (top)
│  🔥 Day 7 Streak                        │  ← Streak counter
│                                         │
│        ╭─────────────────╮              │
│       ╱                   ╲             │
│      │         ◐           │            │  ← Giant progress ring
│      │       Pulsing       │            │     (breathing animation)
│      │       0%            │            │
│       ╲                   ╱             │
│        ╰─────────────────╯              │
│                                         │
│    [ 30 ]  [+]  (15 min steps, max 2h)  │  ← Timer: tap + to add 15 min; hold to accelerate
│                                         │
│         Pick your resource:             │
│                                         │
│  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐   │
│  │ 🪵  │  │ ⚒️  │  │ 💰  │  │ 🌾  │   │  ← Resource selection
│  │Wood │  │Iron │  │Gold │  │Food │   │     (pixel art icons)
│  │ 30  │  │ 15  │  │ 6   │  │ 60  │   │  ← Estimated yield
│  └─────┘  └─────┘  └─────┘  └─────┘   │
│                       ┌─────┐           │
│                       │ 🪨  │           │
│                       │Stone│           │
│                       │ 9   │           │
│                       └─────┘           │
│                                         │
│         [Start Focus Session]           │
│                                         │
└─────────────────────────────────────────┘
```

### Active Focus View (Timer Running)

```
┌─────────────────────────────────────────┐
│  🪵 144  ⚒️ 58  💰 23  🌾 89  🪨 12    │  ← Top bar updates LIVE
│       ↑                                 │     (142 + 2 earned so far)
│ ╔═══════════════════════════════════════╗│
│ ║  Pixel art parallax landscape        ║│  ← Scrolling pixel art
│ ║  Mountains → Hills → Grass → Clouds  ║│     (medieval theme)
│ ╚═══════════════════════════════════════╝│
│                                         │
│        ╭─────────────────╮              │
│       ╱    ◐──╮           ╲             │  ← Ring fills over time
│      │   │ 28:45 │          │            │  ← Countdown timer
│       ╲    ╰──╯           ╱             │
│        ╰─────────────────╯              │
│                                         │
│      Gathering: 🪵 Wood                 │
│      Rate: 1 per minute                 │
│                                         │
│        ╭──────────────╮                 │
│        │  +2 🪵       │                 │  ← Live accumulation counter
│        │  of 30       │                 │     ticks up in real-time
│        ╰──────────────╯                 │
│                                         │
│         [Cancel]   [Pause]              │
│                                         │
└─────────────────────────────────────────┘
```

**Completion alarm:** When the timer reaches 0, trigger a sound or vibration alarm — respect the user's phone settings (e.g. `UIImpactFeedbackGenerator` for haptics, `AudioServicesPlaySystemSound` or system alert sound for audio; check silent mode / ringer state).

### Live Resource Accumulation

Resources tick up **in real-time** during a focus session, not awarded all at once at the end. This gives continuous dopamine hits and makes the session feel productive.

**How it works:**
- A fractional accumulator runs on a `TimelineView` (updates every ~5 seconds)
- The displayed count increments by 1 each time the fractional accumulator crosses a whole number
- The top resource bar updates live (e.g., Wood goes from 142 → 143 → 144...)
- A "+N" counter below the ring shows session earnings so far
- When timer completes OR is cancelled, accumulation stops immediately
- On cancellation, the 75% penalty is applied to the already-earned amount (resources are **not** taken back — you just stop earning at the penalized rate going forward)

**Visual flourish:** Each time a resource unit is earned, a small "+1 🪵" floats upward and fades out (subtle, not distracting). The top bar number does a quick scale-bounce animation.

```swift
// Accumulation logic (conceptual)
// Tick runs every 5 seconds for smooth feel without battery drain
let elapsedMinutes = elapsedSeconds / 60.0
let rawEarned = elapsedMinutes * effectiveRate  // fractional
let displayEarned = Int(rawEarned)              // whole units shown

// On completion:
let finalEarned = isCompleted ? displayEarned : Int(Double(displayEarned) * 0.75)
```

**Pause behavior:** Accumulation pauses when timer is paused. Resumes when unpaused. No penalty for pausing.

### Session Complete View

```
┌─────────────────────────────────────────┐
│                                         │
│           ✨ Session Complete! ✨        │
│                                         │
│            +30 🪵 Wood                  │  ← Resources earned
│                                         │
│        🔥 7-day streak! (+25%)          │  ← Streak status
│        📊 45 min focused today          │  ← Daily total
│                                         │
│      ┌──────────────────────────┐       │
│      │ Mark task complete?  [✓] │       │  ← Quick completion prompt
│      └──────────────────────────┘       │
│                                         │
│         [Back to Tasks]                 │
│                                         │
└─────────────────────────────────────────┘
```

---

## Pixel Art Focus Experience

### Parallax Layers (right-to-left scrolling)

| Layer | Asset | Scroll Speed | Content |
|-------|-------|-------------|---------|
| **Background** | Sky strip | Very slow (0.25x) | Gradient sky, sun/moon |
| **Layer 1** | Mountain silhouettes | Slow (0.5x) | Distant dark mountains |
| **Layer 2** | Hills + castle | Medium (1x) | Rolling green hills, occasional castle |
| **Layer 3** | Foreground | Fast (1.5x) | Grass, flowers, rocks |
| **Overlay** | Cloud sprites | Independent random | 2-3 drifting clouds |

All layers are **static tileable PNGs** — animation is code-driven via `TimelineView` in SwiftUI.

### Resource Icons (Pixel Art)

Each resource has a pixel art icon used in:
- Resource selection grid
- Top resource bar
- Session complete screen
- Town inventory

---

## Timer System

### Timer Picker

- **Increment:** 15 minutes per step
- **UI:** Display current duration (e.g. "30 min"); a "+" button adds 15 min each tap
- **Hold to accelerate:** Long-press "+" to rapidly add 15 min increments (e.g. every 0.3s while held)
- **Minimum:** 15 min
- **Maximum:** 2 hours (120 min)
- **Default:** 30 min

**Example flow:** Start at 30 min → tap + twice → 60 min → hold + to jump to 90 or 120 min.

### Timer Options (Reference)

| Duration | Base Gathering | Use Case |
|----------|---------------|----------|
| **15 min** | 15 resources | Quick focus |
| **30 min** ⭐ | 30 resources | Standard pomodoro (default) |
| **45 min** | 45 resources | Deep work |
| **60 min** | 60 resources | Hour block |
| **90 min** | 90 resources | Extended deep work |
| **120 min** | 120 resources | Max session (2 hours) |

**Formula:** `Resources = Minutes × Base Rate × Pro Multiplier × Bonus Multiplier × Streak Multiplier × Completion Multiplier`

### Completion Alarm

When the countdown reaches 0:
- **Sound:** Play system alert sound (or customizable tone) — respect silent mode / ringer state
- **Vibration:** Use `UIImpactFeedbackGenerator` for haptic feedback
- **Behavior:** Honor user's phone settings (e.g. if device is muted, use haptics only; if haptics disabled, use sound only)

### Resource Rates (Per Minute)

| Resource | Base Rate | Pro Rate (2x) | Pro + 1hr Bonus | Pro + Bonus + 7-day Streak |
|----------|-----------|---------------|-----------------|---------------------------|
| 🪵 Wood | 1/min | 2/min | 2.5/min | 3.13/min |
| ⚒️ Iron | 0.5/min | 1/min | 1.25/min | 1.56/min |
| 💰 Gold | 0.2/min | 0.4/min | 0.5/min | 0.63/min |
| 🌾 Food | 2/min | 4/min | 5/min | 6.25/min |
| 🪨 Stone | 0.3/min | 0.6/min | 0.75/min | 0.94/min |

### Incomplete Session Penalty

If a session is cancelled before completion, resources are awarded at **75% rate** for the elapsed time:

```
Example: 30-min Wood session, cancelled at 12 min
Normal: 12 min × 1/min = 12 Wood
With penalty: 12 × 1 × 0.75 = 9 Wood

Message: "Session ended early. You gathered 9 Wood (75% rate for incomplete sessions)."
```

### 1+ Hour Daily Bonus (Accelerated Gathering)

**Trigger:** Cumulative focus time > 60 minutes in one calendar day

**Effect:** +25% gathering rate for rest of day

**Example Day (Free User):**
- 9:00 AM: 30 min Wood → 30 🪵
- 11:00 AM: 30 min Iron → 15 ⚒️
- **Total: 60 min** → Bonus activated!
- 2:00 PM: 30 min Wood (bonus) → 37 🪵 (30 × 1.25)

**Example Day (Pro User):**
- 9:00 AM: 30 min Wood (2x) → 60 🪵
- 11:00 AM: 30 min Iron (2x) → 30 ⚒️
- **Total: 60 min** → Bonus activated!
- 2:00 PM: 30 min Wood (2x + 25%) → 75 🪵 (30 × 2 × 1.25)

---

## Streak System

### Daily Focus Streak

Consecutive days with at least one completed focus session:

| Streak | Bonus | Milestone |
|--------|-------|-----------|
| Day 1 | +0% | — |
| Day 2 | +5% | — |
| Day 3 | +10% | — |
| Day 5 | +15% | — |
| Day 7 | +25% | Weekly milestone! |
| Day 14 | +30% | — |
| Day 30 | +50% | Monthly milestone! |

**Rules:**
- Miss a day → streak resets to 0
- Pro users get **streak protection**: 1 missed day per week without losing streak
- Streak bonus stacks with all other multipliers
- Minimum 1 completed session (not cancelled) counts for the day

### Streak Display

Visible on the focus pre-session screen: `🔥 Day 7 Streak (+25%)`

---

## Resource System

### Core Resources (5 Types)

| Resource | Emoji | Primary Use | Base Storage Cap |
|----------|-------|------------|-----------------|
| **Wood** | 🪵 | Buildings, upgrades | 500 |
| **Iron** | ⚒️ | Advanced buildings, tools | 250 |
| **Gold** | 💰 | Grid expansion, premium buildings, army upkeep | 100 |
| **Food** | 🌾 | Population growth + maintenance | 1000 |
| **Stone** | 🪨 | Walls, fortifications, upgrades | 300 |

### Storage & Warehouse

- When storage is full, excess resources are **lost** (not earned)
- Notification: *"Your wood storage is full! Build something or resources will be wasted."*
- **Warehouse** building increases storage caps:

| Warehouse Level | Storage Bonus | Cost |
|-----------------|--------------|------|
| Lv 1 | +25% all caps | 80 Wood, 40 Stone |
| Lv 2 | +50% all caps | 150 Wood, 80 Stone, 20 Gold |
| Lv 3 | +100% all caps | 300 Wood, 150 Stone, 50 Gold |

- Pro users get +50% storage caps (stacks with Warehouse)

### Resource Detail (Tap to View)

```
Tap Wood 🪵 →
┌────────────────────────────┐
│ 🪵 Wood                    │
│ Storage: 142/500           │
│ Gathering rate: 1/min      │
│ Passive income: +3/day     │  ← From Lumber Mills
│ Focus today: 60 🪵         │
│ Time to cap: ~6 hours      │
└────────────────────────────┘
```

---

## Food Economy

### The Growth Loop

Food serves two purposes — **maintenance** (keeping population alive) and **growth** (recruiting new population). This keeps food permanently relevant.

**Passive farms** produce just enough to sustain current population (net zero).
**Active focus gathering** is the only way to generate food surplus for growth.

### How It Works

```
Town has: 10 pop, 2 Farms (produce 4 food/day passive)
Maintenance cost: 10 pop × 0.4 food/day = 4 food/day
Net passive: 0 (farms barely keep people fed)

To recruit 5 new population: costs 50 food
Only way to get surplus food: focus sessions (pick Food resource)

After recruiting: 15 pop, still 2 Farms (produce 4 food/day)
Maintenance: 15 × 0.4 = 6 food/day
Net passive: -2/day ← DEFICIT! Population will decline!

Fix: Build a 3rd Farm (costs Wood + Food) → produces 6 food/day = balanced
```

### The Push-Pull Dynamic

| Game Phase | Focus Priority | Why |
|------------|---------------|-----|
| **Early** | Food + Wood | Grow population, build first buildings |
| **Mid** | Wood + Stone | Build farms to keep up with growing population |
| **Late** | Iron + Gold | Barracks, army, grid expansion |
| **Always** | Food periodically | Population growth always requires active surplus |

**Key rule:** Food is never "solved." Every population increase creates a new deficit that requires either more farms or more active food gathering.

---

## Town Building System (Phase 2)

### Building Types (7 total, max Level 20 each)

| Building | Emoji | Base Cost (Lv 1) | Effect (Lv 1) | Scaling |
|----------|-------|-------------------|---------------|---------|
| **Hut** | 🏚→🏠→🏘 | 50 Wood | +2 pop capacity | +2 pop/level |
| **Farm** | 🌾 | 30 Wood, 20 Food | +2 food/day passive | +1.5 food/level |
| **Lumber Mill** | 🪵 | 40 Wood, 20 Stone | +3 wood/day passive | +2 wood/level |
| **Mine** | ⛏ | 50 Stone, 30 Iron | +1 iron, +2 stone/day | +1 each/level |
| **Warehouse** | 🏗 | 80 Wood, 40 Stone | +10% storage caps | +5% per level |
| **Barracks** | ⚔️ | 100 Wood, 80 Iron, 50 Gold | +5 army capacity | +5/level |
| **Castle** | 🏰 | 200 Wood, 150 Stone, 100 Gold | Town hall — unlocks town levels | Unique milestones |

### Upgrade Prerequisites (Dependency Chain)

No building can be upgraded in isolation — the **Castle is the level cap** for all other buildings, and the Castle itself requires population + Warehouse milestones. This forces balanced, strategic development.

**The Rule:**
```
All buildings max level ≤ Castle level
Castle upgrade requires:  Warehouse ≥ Castle's current level
                          Population ≥ threshold for next level
```

**Dependency chain:** Population + Warehouse → Castle → Everything else

| Castle Target Level | Warehouse Required | Population Required |
|--------------------|-------------------|-------------------|
| 1 → 2 | Warehouse Lv 1 | 10 pop |
| 2 → 3 | Warehouse Lv 2 | 15 pop |
| 3 → 4 | Warehouse Lv 3 | 20 pop |
| 4 → 5 | Warehouse Lv 4 | 30 pop |
| 5 → 6 | Warehouse Lv 5 | 40 pop |
| 6 → 7 | Warehouse Lv 6 | 55 pop |
| 7 → 8 | Warehouse Lv 7 | 70 pop |
| 8 → 9 | Warehouse Lv 8 | 90 pop |
| 9 → 10 | Warehouse Lv 9 | 115 pop |
| 10 → 11 | Warehouse Lv 10 | 140 pop |
| 11 → 12 | Warehouse Lv 11 | 170 pop |
| 12 → 13 | Warehouse Lv 12 | 200 pop |
| 13 → 14 | Warehouse Lv 13 | 235 pop |
| 14 → 15 | Warehouse Lv 14 | 270 pop |
| 15 → 16 | Warehouse Lv 15 | 310 pop |
| 16 → 17 | Warehouse Lv 16 | 350 pop |
| 17 → 18 | Warehouse Lv 17 | 400 pop |
| 18 → 19 | Warehouse Lv 18 | 450 pop |
| 19 → 20 | Warehouse Lv 19 | 500 pop |

**What this means in practice:**

1. **Early game:** You build Huts and Farms freely up to Lv 1, then hit the Castle wall
2. **To upgrade Castle:** You must first level up the Warehouse to match, AND hit the population threshold
3. **Warehouse becomes the gatekeeper:** It costs Wood + Stone + Gold — so you need Lumber Mills and Mines
4. **Population gates the Castle:** You need Huts (for capacity) and Farms (for food) to grow pop
5. **Castle unlocks everything else:** Once Castle hits Lv 3, all other buildings can go up to Lv 3

**Example progression path:**
```
Start: Castle Lv 1 → all buildings capped at Lv 1
Goal:  Upgrade Castle to Lv 2

Step 1: Build Huts to get 10 population         (need Huts + Food)
Step 2: Upgrade Warehouse to Lv 1               (need Wood + Stone)
Step 3: Upgrade Castle to Lv 2                   (need Wood + Stone + Gold)
Step 4: Now all buildings can upgrade to Lv 2!   (cap lifted)
```

**UI hint:** When a building is at its max (= Castle level), show a lock icon with text: *"Upgrade Castle to unlock higher levels"*. When Castle can't upgrade, show: *"Need: Warehouse Lv X, Population Y"*.

```swift
/// Check if a building can be upgraded
func canUpgrade(building: Building, currentLevel: Int, castleLevel: Int) -> UpgradeStatus {
    if building == .castle {
        // Castle needs Warehouse + Population
        if warehouseLevel < currentLevel {
            return .blocked(reason: "Warehouse must reach Lv \(currentLevel)")
        }
        let popNeeded = populationRequirement(for: currentLevel + 1)
        if population < popNeeded {
            return .blocked(reason: "Need \(popNeeded) population (have \(population))")
        }
        return .available
    } else {
        // All other buildings capped by Castle level
        if currentLevel >= castleLevel {
            return .blocked(reason: "Upgrade Castle to Lv \(castleLevel + 1) first")
        }
        return .available
    }
}
```

---

### Upgrade Cost Formula

Uses **exponential scaling** — the standard in town-builder games (Clash of Clans, Travian, Age of Empires). Each level costs ~20% more than the previous, creating a smooth but accelerating curve that rewards long-term play.

```swift
/// Exponential cost scaling — industry standard for town builders
/// Base cost grows by `growthRate` per level, floored to nearest 5 for clean numbers
func upgradeCost(baseCost: Int, level: Int, growthRate: Double = 1.20) -> Int {
    let raw = Double(baseCost) * pow(growthRate, Double(level - 1))
    return Int((raw / 5).rounded()) * 5  // Round to nearest 5
}
```

**Growth rate by building type:**

| Building | Growth Rate | Why |
|----------|------------|-----|
| Hut | 1.18 | Housing should be accessible — population is the engine |
| Farm | 1.20 | Standard — food is always needed |
| Lumber Mill | 1.20 | Standard — wood is the most-used resource |
| Mine | 1.22 | Slightly steeper — iron/stone are mid-tier resources |
| Warehouse | 1.25 | Storage is a luxury, not urgent |
| Barracks | 1.28 | Military is prestige — should feel expensive |
| Castle | 1.35 | Milestone building — big jumps feel earned |

### Sample Cost Tables

**Hut (Growth Rate: 1.18)**

| Level | Wood Cost | Pop Capacity | Total Pop (cumulative) |
|-------|-----------|-------------|----------------------|
| 1 | 50 | +2 | 2 |
| 2 | 60 | +4 | 6 |
| 3 | 70 | +6 | 12 |
| 5 | 95 | +10 | 30 |
| 10 | 215 | +20 | 110 |
| 15 | 480 | +30 | 240 |
| 20 | 1,070 | +40 | 420 |

**Farm (Growth Rate: 1.20) — Primary resource: Wood + Food**

| Level | Wood | Food | Food/Day Passive | Notes |
|-------|------|------|-----------------|-------|
| 1 | 30 | 20 | 2.0 | Sustains ~5 pop |
| 2 | 35 | 25 | 3.5 | |
| 3 | 45 | 30 | 5.0 | |
| 5 | 65 | 40 | 8.0 | |
| 10 | 155 | 100 | 15.5 | Sustains ~39 pop |
| 15 | 370 | 245 | 23.0 | |
| 20 | 890 | 590 | 30.5 | Sustains ~76 pop |

**Lumber Mill (Growth Rate: 1.20) — Primary resource: Wood + Stone**

| Level | Wood | Stone | Wood/Day Passive |
|-------|------|-------|-----------------|
| 1 | 40 | 20 | 3 |
| 5 | 85 | 40 | 11 |
| 10 | 205 | 100 | 21 |
| 15 | 500 | 245 | 31 |
| 20 | 1,200 | 590 | 41 |

**Mine (Growth Rate: 1.22) — Primary resource: Stone + Iron**

| Level | Stone | Iron | Iron/Day | Stone/Day |
|-------|-------|------|----------|-----------|
| 1 | 50 | 30 | 1 | 2 |
| 5 | 110 | 65 | 5 | 6 |
| 10 | 300 | 180 | 10 | 11 |
| 15 | 815 | 490 | 15 | 16 |
| 20 | 2,215 | 1,330 | 20 | 21 |

**Warehouse (Growth Rate: 1.25) — Primary resource: Wood + Stone + Gold**

| Level | Wood | Stone | Gold | Storage Bonus |
|-------|------|-------|------|--------------|
| 1 | 80 | 40 | 0 | +10% |
| 5 | 195 | 95 | 10 | +30% |
| 10 | 600 | 300 | 30 | +55% |
| 15 | 1,835 | 915 | 90 | +80% |
| 20 | 5,600 | 2,800 | 280 | +105% |

**Barracks (Growth Rate: 1.28) — Primary resource: Wood + Iron + Gold**

| Level | Wood | Iron | Gold | Army Capacity |
|-------|------|------|------|--------------|
| 1 | 100 | 80 | 50 | 5 |
| 5 | 270 | 215 | 135 | 25 |
| 10 | 1,080 | 860 | 540 | 50 |
| 15 | 4,310 | 3,450 | 2,155 | 75 |
| 20 | 17,220 | 13,775 | 8,610 | 100 |

**Castle (Growth Rate: 1.35) — Milestone building, unique unlock thresholds**

| Level | Wood | Stone | Gold | Unlocks |
|-------|------|-------|------|---------|
| 1 | 200 | 150 | 100 | Town Level 2 (4×4 grid) |
| 2 | 270 | 200 | 135 | — |
| 3 | 365 | 275 | 180 | Town Level 3 (5×5 grid) |
| 5 | 665 | 500 | 330 | Town Level 4 (6×6 grid) |
| 8 | 1,635 | 1,225 | 815 | Town Level 5 (7×7 grid) |
| 10 | 2,980 | 2,235 | 1,490 | — |
| 12 | 5,430 | 4,075 | 2,715 | Town Level 6 (8×8 grid) |
| 15 | 13,340 | 10,005 | 6,670 | — |
| 17 | 24,300 | 18,225 | 12,150 | Town Level 7 (9×9 grid) |
| 20 | 59,650 | 44,740 | 29,825 | Max town — "Citadel" title |

### Town Level Progression (Expanded)

| Town Level | Icon | Required | Grid Size | Unlocks |
|------------|------|----------|-----------|---------|
| **1** Camp | 🏕 | Start | 3×3 (9 tiles) | Huts, Farms, Lumber Mills |
| **2** Village | 🏘 | Castle Lv1 + 10 pop | 4×4 (16 tiles) | Mines, Warehouse |
| **3** Town | 🏰 | Castle Lv3 + 25 pop | 5×5 (25 tiles) | Barracks |
| **4** Fortress | 🏯 | Castle Lv5 + 50 pop | 6×6 (36 tiles) | Map exploration, rank titles |
| **5** Stronghold | 🏯 | Castle Lv8 + 100 pop | 7×7 (49 tiles) | Advanced army |
| **6** Kingdom | 👑 | Castle Lv12 + 200 pop | 8×8 (64 tiles) | Kingdom title on leaderboard |
| **7** Empire | 🌟 | Castle Lv17 + 350 pop | 9×9 (81 tiles) | Empire title, max prestige |

Castle Lv20 unlocks the **"Citadel"** cosmetic title — the ultimate flex on the leaderboard.

**Grid expansion costs Gold** — paid automatically as part of the Castle upgrade cost.

### Upgrade Time Estimates

To keep players grounded in reality — here's roughly how long each level takes to earn via focus sessions (free user, 30 min/day average):

| Building | Lv 1 | Lv 5 | Lv 10 | Lv 15 | Lv 20 |
|----------|------|------|-------|-------|-------|
| Hut | 1 day | 3 days | 1 week | 2 weeks | 1 month |
| Farm | 1 day | 2 days | 5 days | 2 weeks | 1 month |
| Castle | 1 week | 3 weeks | 2 months | 6 months | 2+ years |

This pacing means:
- **Casual players** (30 min/day) can reach Town Lv 3-4 in a few months
- **Power users** (1-2 hrs/day) can push to Lv 5-6 within months
- **Lv 20 Castle / "Citadel"** is a long-term prestige goal (1-2 years) — the whale chase
- **Pro subscribers** cut all timelines roughly in half (2x gathering rate)

### Passive Income (Collect on App Open)

Buildings generate resources passively over time. Resources accumulate while the app is closed and are collected when the user opens the app:

```
"Welcome back! Your town produced while you were away:"
+12 🪵 (2 Lumber Mills)
+6 ⚒️ (1 Mine)
+8 🌾 (2 Farms — consumed by 20 pop maintenance)
Net food: 0 (balanced)

[Collect]
```

Passive income is **much smaller** than active focus gathering — it's a bonus, not a replacement for focusing.

---

## Army System (Phase 3 — Prestige Only Initially)

### How It Works

- Barracks building unlocks army recruitment
- Soldiers cost **Gold upkeep** (passive drain)
- Army size is a prestige/point stat — no combat in early versions
- Displayed on leaderboard as military strength

### Future: Auto-Battle PvE

- Tap enemy tile on map → outcome calculated instantly based on army size vs. difficulty
- No real-time combat, no PvP initially
- Winning PvE battles earns bonus resources + leaderboard points

---

## Leaderboard

### Scoring Formula

```
Town Points = (Town Level × 100) + (Total Buildings × 10) + (Population × 5) 
            + (Army Size × 3) + (Total Focus Minutes)
```

Focus minutes are part of the score — consistent focus climbs the leaderboard even without a massive town. This is fundamentally a **"who's the most productive" competition**.

### Leaderboard Display

```
🏆 Leaderboard

#1  🏯 Winterfell         — Lv 4 · Pop 52 · 2,340 pts
#2  🏰 Sarah's Town       — Lv 3 · Pop 28 · 1,120 pts
#3  🏘 Fort Productivity   — Lv 2 · Pop 18 ·   890 pts
#4  🏕 Mike's Camp         — Lv 1 · Pop 6  ·   480 pts

[Tap player to view their town]
```

Tapping a player shows their town grid (read-only). Social proof + friendly competition.

### Leaderboard Privacy (Game Settings)

Users choose their visibility in Game Settings:
- **Public** — visible to all Docket users
- **Friends only** — visible only to contacts (uses existing contacts system)
- **Hidden** — opted out of leaderboard entirely

Default: **Hidden** (opt-in)

### Custom Town Name

- Free users: "[Name]'s Town" (auto-generated)
- Pro users: Custom town name (e.g., "Winterfell", "Fort Productivity")

---

## Pro Membership ($8.99/month)

### Bundled Benefits (Focus Game + Voice AI)

| Feature | Free | Pro |
|---------|------|-----|
| **Task management** | Unlimited | Unlimited |
| **Voice-to-task** | 5 voice tasks/month | Unlimited |
| **Focus timer** | Yes | Yes |
| **Gathering rate** | 1x | 2x |
| **Resources per session** | 1 | 2 (pick 2 resources!) |
| **Max daily sessions** | 10 | Unlimited |
| **1+ hour daily bonus** | +25% | +25% (stacks: 2x × 1.25 = 2.5x) |
| **Streak protection** | No | 1 missed day/week forgiven |
| **Storage caps** | Base | +50% bonus |
| **Exclusive buildings** | No | Barracks, Castle Lv3 |
| **Custom town name** | No | Yes |
| **Leaderboard** | View only | Full rank + town showcase |
| **Pixel art theme** | Focus session only | Future: pixel art town grid |

### Pro Gathering Example

**30-min session, Pro user, 7-day streak, after 1hr bonus:**
```
Pick 2 resources: 🪵 Wood + ⚒️ Iron

Wood: 30 min × 2.0 (Pro) × 1.25 (1hr Bonus) × 1.25 (Streak) = 93 🪵
Iron: 30 min × 1.0 (Pro) × 1.25 (1hr Bonus) × 1.25 (Streak) = 46 ⚒️
─────────────────────────────────────────────────────────────────────
Total: 93 🪵 + 46 ⚒️ (139 resources!)
```

**Same session, Free user, no streak:**
```
Pick 1 resource: 🪵 Wood

Wood: 30 min × 1.0 = 30 🪵
───────────────────────────
Total: 30 🪵
```

**Pro advantage with streak:** ~4.6x more resources per session

---

## Achievements / Milestones

One-time achievements that grant bonus resources:

| Achievement | Trigger | Reward |
|-------------|---------|--------|
| First Focus | Complete 1 session | 50 🪵 |
| Getting Started | Complete 10 sessions | 100 🪵, 50 ⚒️ |
| Hour Power | 1 hour focused in a single day | 25 💰 |
| Week Warrior | 7-day streak | 50 💰 |
| Month Master | 30-day streak | 200 💰 |
| Village Founded | Reach Town Level 2 | 200 🪵, 100 🪨 |
| Town Builder | Reach Town Level 3 | 300 🪵, 200 🪨, 50 💰 |
| Fortress Lord | Reach Town Level 4 | 500 of each resource |
| Populous | Reach 50 population | 100 💰 |
| Commander | Recruit first army unit | Leaderboard title: "Commander" |

---

## Notifications (Tasteful)

### Game Notification Types

| Notification | Trigger | Max Frequency |
|-------------|---------|---------------|
| Passive collection ready | Resources accumulated > threshold | 1x/day |
| Streak at risk | No session today, evening time | 1x/day |
| Food deficit | Population declining | 1x/day |
| Storage full | Any resource at cap | 1x/day |

**Rules:**
- Max 2-3 game notifications per day total
- **Game Notifications toggle** in Game Settings (on/off) — separate from task notifications
- No notification for achievements (shown in-app only)

---

## Game Settings (in Profile)

```
┌────────────────────────────────┐
│ ⚙️ Game Settings               │
│                                │
│ Game Notifications     [ON/OFF]│
│ Leaderboard Visibility         │
│   ○ Public                     │
│   ○ Friends Only               │
│   ● Hidden                     │  ← Default
│                                │
│ Town Name: Jon's Town    [Edit]│  ← Pro only
│                                │
│ [Reset Game Progress]          │  ← Destructive, requires confirm
└────────────────────────────────┘
```

---

## Implementation Priority

### Phase 1 — Focus Mode MVP (Week 1-2)

**New Files:**
- `Views/FocusView.swift` — Pre-session setup (timer + resource selection)
- `Views/ActiveFocusView.swift` — Running timer with parallax + breathing ring
- `Views/FocusCompleteView.swift` — Session results + task completion prompt
- `Views/FocusBreathingRing.swift` — Giant pulsing progress ring
- `Views/ParallaxBackground.swift` — Pixel art scrolling landscape
- `Managers/FocusSessionManager.swift` — Timer logic, resource calculation, streak tracking
- `Managers/ResourceManager.swift` — Resource inventory, storage caps, persistence
- `Managers/SubscriptionManager.swift` — StoreKit 2, Pro status
- `Models/FocusSession.swift` — Session data model
- `Models/Resource.swift` — Resource types, rates, caps

**Supabase:**
- `focus_sessions` table (user_id, resource, duration, earned, completed_at)
- `user_resources` table (user_id, wood, iron, gold, food, stone)
- `user_game_state` table (user_id, streak, last_focus_date, town_level, etc.)

**Features:**
- [ ] Focus button on progress slider row
- [ ] Timer picker: 15 min steps, "+" button, hold to accelerate, max 2 hours
- [ ] Resource selection (5 types, pixel art icons)
- [ ] Countdown timer with breathing ring
- [ ] Pixel art parallax background
- [ ] Resource calculation (base + Pro + bonus + streak + completion penalty)
- [ ] Resource totals display (top bar)
- [ ] 1hr daily bonus logic
- [ ] Streak tracking + display
- [ ] Incomplete session penalty (75%)
- [ ] Session complete view with task completion prompt
- [ ] Completion alarm (sound or haptic based on phone settings)
- [ ] Pro subscription (StoreKit 2)
- [ ] Voice-to-task gated behind subscription (5 free/month)

### Phase 2 — Town Grid (Week 3-4)

- [ ] Expandable grid (3×3 → 4×4 → 5×5 → 6×6)
- [ ] 7 building types (emoji-based) with 3 upgrade levels each
- [ ] Tap to build / upgrade UI
- [ ] Population system (housing capacity)
- [ ] Food economy (maintenance + growth)
- [ ] Passive building income (collect on app open)
- [ ] Warehouse building (storage cap upgrades)
- [ ] Town level progression (Camp → Village → Town → Fortress)
- [ ] Game Settings in Profile
- [ ] Game notifications (tasteful, toggleable)

### Phase 3 — Social + Prestige (Month 2)

- [ ] Leaderboard (scoring formula)
- [ ] Leaderboard privacy (public / friends-only / hidden)
- [ ] View other players' towns (read-only)
- [ ] Custom town name (Pro)
- [ ] Achievements / milestones
- [ ] Army system (prestige only — Barracks + Gold upkeep)

### Phase 4 — Exploration (Month 3+)

- [ ] World map (expandable grid)
- [ ] Map exploration (costs resources)
- [ ] Auto-battle PvE
- [ ] Music / ambient sounds during focus
- [ ] Pixel art town grid (Pro cosmetic upgrade)

---

## Technical Notes

### Data Persistence

- **Local:** SwiftData for offline-first resource/game state
- **Cloud:** Supabase tables for sync + leaderboard
- **Conflict resolution:** Server-authoritative for resources (prevent cheating)

### Gathering Calculation (Final Formula — Live Accumulation)

Resources are calculated and displayed **live** during the session. The effective rate determines how often the counter ticks up.

```swift
/// Effective gathering rate (resources per minute) — used for live accumulation
func effectiveRate(
    resource: Resource,
    isPro: Bool,
    dailyFocusMinutes: Int,
    streakDays: Int
) -> Double {
    let baseRate = resource.baseRate
    let proMultiplier = isPro ? 2.0 : 1.0
    let bonusMultiplier = dailyFocusMinutes >= 60 ? 1.25 : 1.0
    let streak = streakMultiplier(for: streakDays)
    
    return baseRate * proMultiplier * bonusMultiplier * streak
}

/// Live accumulation — called every ~5 seconds by TimelineView
func liveAccumulated(elapsedSeconds: TimeInterval, rate: Double) -> Int {
    return Int((elapsedSeconds / 60.0) * rate)
}

/// Final tally on session end — applies 75% penalty if incomplete
func finalGathering(
    elapsedSeconds: TimeInterval,
    totalSeconds: TimeInterval,
    rate: Double
) -> Int {
    let raw = liveAccumulated(elapsedSeconds: elapsedSeconds, rate: rate)
    let isComplete = elapsedSeconds >= totalSeconds
    return isComplete ? raw : Int(Double(raw) * 0.75)
}

func streakMultiplier(for days: Int) -> Double {
    switch days {
    case 0...1: return 1.0
    case 2: return 1.05
    case 3...4: return 1.10
    case 5...6: return 1.15
    case 7...13: return 1.25
    case 14...29: return 1.30
    default: return 1.50  // 30+ days
    }
}
```

### Upgrade Cost Calculation

```swift
/// Exponential cost scaling for building upgrades (max level 20)
func upgradeCost(baseCost: Int, level: Int, growthRate: Double) -> Int {
    let raw = Double(baseCost) * pow(growthRate, Double(level - 1))
    return Int((raw / 5).rounded()) * 5  // Round to nearest 5
}

/// Multi-resource cost (most buildings cost 2-3 resource types)
struct BuildingCost {
    let resources: [(Resource, Int)]  // e.g. [(.wood, 50), (.stone, 30)]
    
    static func forLevel(building: Building, level: Int) -> BuildingCost {
        let costs = building.baseCosts.map { (resource, base) in
            (resource, upgradeCost(baseCost: base, level: level, growthRate: building.growthRate))
        }
        return BuildingCost(resources: costs)
    }
}
```
```

---

## Cross-References

- **How we're building it:** [GAMEFI_FOCUS_PLAN.md](GAMEFI_FOCUS_PLAN.md)
- **Step-by-step tasks:** [GAMEFI_FOCUS_TODO.md](GAMEFI_FOCUS_TODO.md)
- **Economy numbers:** [GAMEFI_BALANCE_SHEET.md](GAMEFI_BALANCE_SHEET.md)

---

**V3 finalized. Phase 1 implementation ready to begin.**
