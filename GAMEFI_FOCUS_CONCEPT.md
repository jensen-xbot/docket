# GameFi Focus Mode: Town Builder Concept

*Exploratory document for gamified focus system*  
*Created: 2026-02-11*

---

## Your Vision (Captured)

**Core Loop:**
```
Focus Session (25 min) → Gather Resources → Build Town → Battle Other Towns
```

**Resources:**
- Wood, Stone, Gold (different focus types?)
- Food (daily streaks?)
- Special resources (rare focus achievements)

**Buildings:**
- Houses (population)
- Barracks (armies)
- Walls (defense)
- Markets (trading)

**Combat:**
- PvP battles between towns
- Resource raiding
- Territory expansion

**Concern:** "Too complicated, requires game design skills"

---

## Reality Check: AI CAN Build This

**Yes, AI can help design games.** Here's how:

### What AI Can Do
✅ Generate game mechanics and balancing  
✅ Create resource economies (gathering rates, costs)  
✅ Design progression curves (when to unlock what)  
✅ Write building/army stat sheets  
✅ Create battle algorithms (simple math)  
✅ Balance PvP (prevent pay-to-win)  

### What You Need to Provide
🎯 **Theme** (Medieval? Space? Cyberpunk?)  
🎯 **Tone** (Serious? Playful? Minimalist?)  
🎯 **Session length** (15 min? 25 min? Variable?)  
🎯 **Social aspect** (Friends only? Global leaderboard?)  

---

## Complexity Breakdown

### Simplified Version (MVP - 2-3 weeks)

**Scope:** Single-player town, no PvP combat yet

**Core Loop:**
```
Focus 25 min → Get 10 Wood → Build House → Population +1
```

**Features:**
- 3 resources (Wood, Stone, Gold)
- 5 building types
- Population growth
- Simple visuals (icons, not 3D)
- Local only (no server)

**UI:**
```
┌─────────────────────────────────┐
│  🏰 My Town          Days: 12   │
│  Pop: 24            Level: 3    │
├─────────────────────────────────┤
│                                 │
│      [🏠][🏠][🏠]               │
│      [🏠][🏭][⚔️]               │
│      [🌲][🗿][💰]               │
│                                 │
│  Wood: 45  Stone: 12  Gold: 8   │
│                                 │
│  [Start Focus Session]          │
│  → Gather resources for 25 min  │
└─────────────────────────────────┘
```

**Pros:**
- Actually achievable
- No multiplayer server needed
- Still gamifies focus
- Can add PvP later

---

### Full Version (v2.0 - 2-3 months)

**Adds:**
- PvP battles (async, not real-time)
- Alliances with friends
- Seasonal events
- Leaderboards
- Cosmetic customization

**Tech needed:**
- Supabase for user towns
- Battle resolution logic
- Anti-cheat (validate focus sessions)

---

## The Honest Assessment

### Why It MIGHT Be Too Much

1. **Scope creep risk** — Games are endless rabbit holes
2. **Balancing takes forever** — Fun vs fair vs rewarding
3. **Art assets** — Even simple icons need design
4. **Server costs** — Multiplayer = ongoing expenses
5. **Maintenance** — Games need constant updates

### Why It Might Work

1. **AI generation** — I can design the entire economy
2. **SwiftUI + SpriteKit** — Native iOS, no Unity complexity
3. **Existing infrastructure** — Use Supabase, same as Docket
4. **Phased approach** — Start simple, add complexity if popular

---

## Alternative: Focus "Companions" (Simpler)

Instead of full town builder, what about:

```
Focus Session → Companion grows/evolves
```

**Examples:**
- 🌱 Plant that grows with each focus session
- 🐱 Virtual pet that levels up
- 🏠 Room that gets decorated
- 🎨 Art piece that completes pixel by pixel

**Pros:**
- Personal (not competitive)
- Simpler to balance
- Still motivating
- No PvP complexity

---

## Recommended Path (If You Want GameFi)

### Phase 1: Personal Rewards (v1.x)
- Focus streaks → Unlock themes/colors
- Focus stats → Achievement badges
- Simple: "7 day streak = Gold theme"

### Phase 2: Companion Mode (v2.0)
- Choose companion (plant/pet/art)
- Grows with focus time
- No multiplayer needed

### Phase 3: Town Builder (v3.0 - if demand)
- Only if Phases 1-2 are popular
- Start with single-player
- Add PvP if users beg for it

---

## My Honest Recommendation

**Don't build the town builder yet.**

**Reasoning:**
1. Docket v1.1 (voice) is already ambitious
2. Town builder = 2-3 months minimum
3. Focus features work WITHOUT games
4. Game complexity might delay launch 6+ months

**Better approach:**
1. Ship v1.1 with solid focus mode (timer + stats)
2. See if users actually use focus features
3. If yes → Add simple companion (Phase 2)
4. If companions popular → Consider town builder

**Compromise option:**
- Build simple "focus garden" in v2.0
- Plant grows with focus time
- Takes 2 weeks, not 2 months
- Tests if users want gamification

---

## Decision Matrix

| Option | Effort | Fun Factor | Risk | Launch Impact |
|--------|--------|-----------|------|---------------|
| No game | 0 days | Low | None | Fast launch |
| Focus timer only | 3 days | Medium | Low | Fast launch |
| Focus companion | 2 weeks | High | Low | Medium delay |
| Town builder (MVP) | 2 months | Very high | Medium | Big delay |
| Town builder (full) | 4 months | Very high | High | Missed market |

---

## My Suggestion

**Start with:** Focus timer + simple stats (3 days work)

```
Focus Session Complete!
━━━━━━━━━━━━━━━━━━━━━━
⏱️  25 minutes focused
📊  12th session this week
🔥  5 day streak!
```

**Then evaluate:** Are users actually using focus mode?

**If yes →** Add companion mode in v2.0
**If no →** Focus on other features (voice, sync, etc.)

**Town builder = v3.0 dream**, not v1.1 reality.

---

## However...

**If you're passionate about the town builder:**

I CAN help design it. AI can:
- Create balanced economy spreadsheets
- Generate building stats and costs
- Design battle algorithms
- Write all the copy

**But:** It will delay Docket's launch by 2-3 months minimum.

**Question:** Is the town builder THE reason you're building Docket? Or is it a nice-to-have?

If it's THE reason — let's design it properly.
If it's nice-to-have — ship focus timer first, town later.

---

What's your gut feeling? Is gamification core to Docket's identity, or should we nail the basics first?
