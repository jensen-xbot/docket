# GameFi Focus Mode: Implementation TODO

*Phased checklist for integrating the Town Builder gamification into Docket*  
*References: [GAMEFI_FOCUS_CONCEPT.md](GAMEFI_FOCUS_CONCEPT.md) (what we're building) | [GAMEFI_FOCUS_PLAN.md](GAMEFI_FOCUS_PLAN.md) (how we're building it)*

---

## Phase 1 — Focus Mode MVP

### 1a: Foundation

| # | Task | Ref |
|---|------|-----|
| 1.1 | Create `Models/Resource.swift` — enum ResourceType (wood, iron, gold, food, stone), baseRate, baseStorageCap, emoji | CONCEPT § Resource System |
| 1.2 | Create `Models/GameState.swift` — SwiftData @Model for user_game_state; singleton per user | PLAN § 2.2 |
| 1.3 | Create `Models/FocusSession.swift` — SwiftData @Model for focus_sessions | PLAN § 2.2 |
| 1.4 | Register GameState, FocusSession in ModelContainer (DocketApp.swift) | PLAN § 2.5 |
| 1.5 | Create migration `013_gamefi_focus_tables.sql` — user_game_state, focus_sessions, buildings, achievements, RLS | PLAN § 3.1 |
| 1.6 | Add `ResourceManager.swift` — resource CRUD, storage cap logic, effectiveRate() stub | PLAN § 2.3 |
| 1.7 | Add `GameStateManager.swift` — load/create GameState for current user, streak stub | PLAN § 2.3 |
| 1.8 | Add `FocusSessionManager.swift` — timer state, session lifecycle stub | PLAN § 2.3 |
| 1.9 | Inject managers into DocketApp environment | PLAN § 2.5 |
| 1.10 | Add SyncEngine methods: pushGameState, pullGameState, pushFocusSessions, pullFocusSessions | PLAN § 2.5 |

### 1b: Focus UI

| # | Task | Ref |
|---|------|-----|
| 1.11 | Create `FocusView.swift` — layout: resource bar, timer picker (+ button, 15-min steps, max 2h), resource picker, Start button | CONCEPT § Main Focus View, § Timer Picker |
| 1.12 | Create `ResourceBarView.swift` — horizontal bar with 5 resource icons + counts; tap for detail | PLAN § 2.4 |
| 1.13 | Create `ActiveFocusView.swift` — countdown display, Cancel/Pause buttons, placeholder background | CONCEPT § Active Focus View |
| 1.14 | Create `FocusCompleteView.swift` — earned resources, Back to Tasks, placeholder for mark-complete | CONCEPT § Session Complete View |
| 1.15 | Create `FocusBreathingRing.swift` — large progress ring, breathing pulse when active | CONCEPT § Breathing Animation Spec |
| 1.16 | Wire FocusView → ActiveFocusView → FocusCompleteView flow (state-driven) | PLAN § 2.1 |
| 1.17 | Add full-screen presentation (sheet or fullScreenCover) for Focus flow | PLAN § 2.5 |

### 1c: Pixel Art

| # | Task | Ref |
|---|------|-----|
| 1.18 | Generate pixel art resource icons (5 types) — add to Assets.xcassets | CONCEPT § Resource Icons |
| 1.19 | Generate pixel art parallax layers: sky, mountains, hills, foreground | CONCEPT § Parallax Layers |
| 1.20 | Generate 2–3 cloud sprites for overlay | CONCEPT § Parallax Layers |
| 1.21 | Create `ParallaxBackground.swift` — TimelineView-driven scrolling, 4 layers + clouds | PLAN § 2.4 |
| 1.22 | Integrate ParallaxBackground into ActiveFocusView | CONCEPT § Active Focus View |
| 1.23 | Use pixel art icons in ResourceBarView and resource picker | CONCEPT § Main Focus View |

### 1d: Resource System

| # | Task | Ref |
|---|------|-----|
| 1.24 | Implement `ResourceManager.effectiveRate()` — base × Pro × 1hr bonus × streak | CONCEPT § Gathering Calculation |
| 1.25 | Implement `ResourceManager.storageCap(for:)` — base caps, Pro +50%, Warehouse (Phase 2) | CONCEPT § Storage & Warehouse |
| 1.26 | Implement `ResourceManager.addResources()` — enforce cap, clamp to max | CONCEPT § Resource System |
| 1.27 | Implement live accumulation in FocusSessionManager — TimelineView tick ~5s | CONCEPT § Live Resource Accumulation |
| 1.28 | Update ResourceBarView in real-time during session (top bar) | CONCEPT § Active Focus View |
| 1.29 | Add "+N of X" counter below ring in ActiveFocusView | CONCEPT § Active Focus View |
| 1.30 | Apply 75% penalty on cancel; show message in FocusCompleteView | CONCEPT § Incomplete Session Penalty |
| 1.31 | Pause accumulation when timer paused; no penalty | CONCEPT § Live Resource Accumulation |

### 1e: Streaks + Bonuses

| # | Task | Ref |
|---|------|-----|
| 1.32 | Implement streak tracking in GameStateManager — last focus date, consecutive days | CONCEPT § Streak System |
| 1.33 | Implement streak multiplier lookup (Day 1–30+) | CONCEPT § Streak System |
| 1.34 | Implement 1hr daily bonus — dailyFocusMinutes, reset on new day | CONCEPT § 1+ Hour Daily Bonus |
| 1.35 | Display streak on FocusView ("Day N Streak (+X%)") | CONCEPT § Streak Display |
| 1.36 | Update streak on session complete; reset on missed day | CONCEPT § Streak System |
| 1.37 | (Pro) Streak protection: 1 missed day per week | CONCEPT § Pro Membership |

### 1f: Subscription

| # | Task | Ref |
|---|------|-----|
| 1.38 | Create `SubscriptionManager.swift` — StoreKit 2 load product, purchase, restore | PLAN § 2.3 |
| 1.39 | Add Pro product ID `com.docket.pro.monthly` to App Store Connect (document) | CONCEPT § Pro Membership |
| 1.40 | Expose `isPro` as @Published; check on app launch | PLAN § 1.3 |
| 1.41 | Gate 2 resources per session for Pro in FocusView resource picker | PLAN § 1.3 |
| 1.42 | Gate 2x rate in ResourceManager.effectiveRate(isPro:) | PLAN § 1.3 |
| 1.43 | Gate max 10 daily sessions for free users in FocusSessionManager | CONCEPT § Pro Membership |
| 1.44 | Add voice-to-task monthly counter to GameState; enforce in VoiceTaskParser | PLAN § 1.4 |
| 1.45 | Add "Upgrade to Pro" CTA in FocusView when limit hit | CONCEPT § Pro Membership |

### 1g: Integration

| # | Task | Ref |
|---|------|-----|
| 1.46 | Add Focus button (SF Symbol `scope` or `flame.fill`) to TaskRowView at right of ProgressSlider | PLAN § 2.5, CONCEPT § Entry Point |
| 1.47 | Pass optional `task` to FocusView for mark-complete prompt | CONCEPT § Session Complete View |
| 1.48 | Add "Mark task complete?" to FocusCompleteView; call task completion on confirm | CONCEPT § Session Complete View |
| 1.49 | Add Game Settings section to ProfileView — placeholder for Phase 2 | CONCEPT § Game Settings |
| 1.50 | Persist completed session to Supabase (focus_sessions, user_game_state) | PLAN § 3.1 |
| 1.51 | Create Edge Function `complete-focus-session` for server-authoritative resource grant (optional Phase 1) | PLAN § 3.3 |

### 1h: Polish + Build

| # | Task | Ref |
|---|------|-----|
| 1.52 | Add "+1" float animation when resource unit earned | CONCEPT § Live Resource Accumulation |
| 1.52a | Implement completion alarm (sound or haptic based on phone settings) when timer reaches 0 | CONCEPT § Completion Alarm |
| 1.53 | Add scale-bounce on top bar number update | CONCEPT § Live Resource Accumulation |
| 1.54 | Verify dark mode for all focus views | .cursorrules |
| 1.55 | Add #Preview for FocusView, ActiveFocusView, FocusCompleteView | .cursorrules |
| 1.56 | Run xcodebuild verification | .cursorrules |
| 1.57 | Add new Swift files to project.pbxproj | .cursorrules |

---

## Phase 2 — Town Grid

| # | Task | Ref |
|---|------|-----|
| 2.1 | Create `Models/Building.swift` — SwiftData @Model for buildings | PLAN § 2.2 |
| 2.2 | Create `TownGridView.swift` — expandable grid (3×3 → 9×9 by town level) | CONCEPT § Town Level Progression |
| 2.3 | Implement 7 building types with emoji display | CONCEPT § Building Types |
| 2.4 | Implement upgrade cost formula (exponential, growth rate per building) | CONCEPT § Upgrade Cost Formula |
| 2.5 | Implement upgrade prerequisites: Castle cap, Warehouse + population for Castle | CONCEPT § Upgrade Prerequisites |
| 2.6 | Create build/upgrade UI — tap empty tile → build menu; tap building → upgrade | CONCEPT § Town View |
| 2.7 | Implement population system: housing capacity from Huts, recruitment cost | CONCEPT § Food Economy |
| 2.8 | Implement food economy: maintenance, growth cost, deficit behavior | CONCEPT § Food Economy |
| 2.9 | Implement passive building income — calculate on app open, "Collect" UI | CONCEPT § Passive Income |
| 2.10 | Implement Warehouse building — storage cap bonuses | CONCEPT § Warehouse |
| 2.11 | Implement town level progression (Camp → Empire) | CONCEPT § Town Level Progression |
| 2.12 | Add Game Settings to Profile: notifications toggle, leaderboard visibility | CONCEPT § Game Settings |
| 2.13 | Add game notifications (passive ready, streak at risk, food deficit, storage full) | CONCEPT § Notifications |
| 2.14 | Sync buildings to Supabase; extend SyncEngine | PLAN § 3.1 |
| 2.15 | Add GameStateManager.canBuild(), canUpgrade() with prerequisite checks | PLAN § 2.3 |

---

## Phase 3 — Social + Prestige

| # | Task | Ref |
|---|------|-----|
| 3.1 | Create migration `014_leaderboard.sql` — leaderboard_scores function | PLAN § 3.2 |
| 3.2 | Create `LeaderboardView.swift` — list ranked players, tap to view town | CONCEPT § Leaderboard |
| 3.3 | Implement scoring formula: town_level×100 + buildings×10 + pop×5 + army×3 + focus_minutes | CONCEPT § Leaderboard |
| 3.4 | Implement leaderboard privacy: public / friends_only / hidden | CONCEPT § Leaderboard Privacy |
| 3.5 | Filter leaderboard by friends when friends_only (use contacts table) | PLAN § 3.2 |
| 3.6 | Create `TownDetailView.swift` — read-only view of another player's town | CONCEPT § Leaderboard |
| 3.7 | Add custom town name for Pro users in Game Settings | CONCEPT § Custom Town Name |
| 3.8 | Create `Models/Achievement.swift` — SwiftData @Model | PLAN § 2.2 |
| 3.9 | Implement achievement unlock logic and bonus resource grants | CONCEPT § Achievements |
| 3.10 | Create achievements UI — list unlocked, claim rewards | CONCEPT § Achievements |
| 3.11 | Implement Barracks building — army capacity | CONCEPT § Army System |
| 3.12 | Implement army recruitment — Gold upkeep, prestige display | CONCEPT § Army System |
| 3.13 | Add army to leaderboard display | CONCEPT § Leaderboard Display |
| 3.14 | Gate Barracks, Castle Lv3 for Pro | CONCEPT § Pro Membership |

---

## Phase 4 — Exploration

| # | Task | Ref |
|---|------|-----|
| 4.1 | Create `MapView.swift` — world map grid (5×5+), tile types | CONCEPT § Map View |
| 4.2 | Implement exploration — tap adjacent tile, cost resources | CONCEPT § Map View |
| 4.3 | Implement auto-battle PvE — tap enemy, outcome by army vs difficulty | CONCEPT § Future: Auto-Battle PvE |
| 4.4 | Add ambient music/sounds during focus (bundled loops) | CONCEPT § Phase 4 |
| 4.5 | Add pixel art town grid as Pro cosmetic upgrade | CONCEPT § Phase 4 |

---

## Cross-References

- **What we're building:** [GAMEFI_FOCUS_CONCEPT.md](GAMEFI_FOCUS_CONCEPT.md)
- **How we're building it:** [GAMEFI_FOCUS_PLAN.md](GAMEFI_FOCUS_PLAN.md)
- **Economy numbers:** [GAMEFI_BALANCE_SHEET.md](GAMEFI_BALANCE_SHEET.md)
