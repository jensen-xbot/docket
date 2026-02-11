# GameFi Focus Mode: Balance Sheet

*Pure data reference for tuning — no narrative. See [GAMEFI_FOCUS_CONCEPT.md](GAMEFI_FOCUS_CONCEPT.md) for context.*

---

## Timer Picker

| Parameter | Value |
|-----------|-------|
| Increment | 15 min |
| Min | 15 min |
| Max | 120 min (2 hours) |
| Default | 30 min |
| Hold accelerate | ~0.3s per 15 min while held |

---

## Resource Rates (Per Minute)

| Resource | Base | Pro | 1hr Bonus | Pro + Bonus | 7-day Streak | Pro + Bonus + 7-day |
|----------|------|-----|-----------|-------------|--------------|---------------------|
| Wood | 1.0 | 2.0 | 1.25 | 2.5 | 1.25 | 3.125 |
| Iron | 0.5 | 1.0 | 1.25 | 1.25 | 1.25 | 1.5625 |
| Gold | 0.2 | 0.4 | 1.25 | 0.5 | 1.25 | 0.625 |
| Food | 2.0 | 4.0 | 1.25 | 5.0 | 1.25 | 6.25 |
| Stone | 0.3 | 0.6 | 1.25 | 0.75 | 1.25 | 0.9375 |

---

## Streak Multipliers

| Streak Days | Bonus |
|-------------|-------|
| 0–1 | 1.0 |
| 2 | 1.05 |
| 3–4 | 1.10 |
| 5–6 | 1.15 |
| 7–13 | 1.25 |
| 14–29 | 1.30 |
| 30+ | 1.50 |

---

## Storage Caps

| Resource | Base Cap | Pro Cap (+50%) |
|----------|----------|----------------|
| Wood | 500 | 750 |
| Iron | 250 | 375 |
| Gold | 100 | 150 |
| Food | 1000 | 1500 |
| Stone | 300 | 450 |

**Warehouse bonus:** +10% per level (Lv 1 = +10%, Lv 20 = +105%). Stacks with Pro.

---

## Session Multipliers

| Multiplier | Value |
|------------|-------|
| Incomplete session penalty | 0.75 |
| 1hr daily bonus | 1.25 |
| Pro gathering rate | 2.0 |

---

## Food Economy

| Parameter | Value |
|-----------|-------|
| Food maintenance per pop per day | 0.4 |
| Population recruitment cost | 10 food per pop |

---

## Building Growth Rates

| Building | Growth Rate |
|----------|-------------|
| Hut | 1.18 |
| Farm | 1.20 |
| Lumber Mill | 1.20 |
| Mine | 1.22 |
| Warehouse | 1.25 |
| Barracks | 1.28 |
| Castle | 1.35 |

---

## Upgrade Cost Formula

```
cost = round(baseCost * growthRate^(level - 1) / 5) * 5
```

---

## Building Base Costs (Lv 1)

| Building | Wood | Iron | Gold | Food | Stone |
|----------|------|------|------|------|-------|
| Hut | 50 | — | — | — | — |
| Farm | 30 | — | — | 20 | — |
| Lumber Mill | 40 | — | — | — | 20 |
| Mine | — | 30 | — | — | 50 |
| Warehouse | 80 | — | — | — | 40 |
| Barracks | 100 | 80 | 50 | — | — |
| Castle | 200 | — | 100 | — | 150 |

---

## Castle Upgrade: Population + Warehouse Prerequisites

| Castle Lv → | Warehouse Lv | Population |
|-------------|-------------|------------|
| 1 → 2 | 1 | 10 |
| 2 → 3 | 2 | 15 |
| 3 → 4 | 3 | 20 |
| 4 → 5 | 4 | 30 |
| 5 → 6 | 5 | 40 |
| 6 → 7 | 6 | 55 |
| 7 → 8 | 7 | 70 |
| 8 → 9 | 8 | 90 |
| 9 → 10 | 9 | 115 |
| 10 → 11 | 10 | 140 |
| 11 → 12 | 11 | 170 |
| 12 → 13 | 12 | 200 |
| 13 → 14 | 13 | 235 |
| 14 → 15 | 14 | 270 |
| 15 → 16 | 15 | 310 |
| 16 → 17 | 16 | 350 |
| 17 → 18 | 17 | 400 |
| 18 → 19 | 18 | 450 |
| 19 → 20 | 19 | 500 |

---

## Building Effects (Per Level)

| Building | Effect@Lv1 | Scaling/Level |
|----------|------------|---------------|
| Hut | +2 pop cap | +2 |
| Farm | +2 food/day | +1.5 |
| Lumber Mill | +3 wood/day | +2 |
| Mine | +1 iron, +2 stone/day | +1 each |
| Warehouse | +10% storage | +5% |
| Barracks | +5 army cap | +5 |
| Castle | Town level gate | — |

---

## Town Level Grid Sizes

| Town Level | Grid | Tiles |
|------------|------|-------|
| 1 (Camp) | 3×3 | 9 |
| 2 (Village) | 4×4 | 16 |
| 3 (Town) | 5×5 | 25 |
| 4 (Fortress) | 6×6 | 36 |
| 5 (Stronghold) | 7×7 | 49 |
| 6 (Kingdom) | 8×8 | 64 |
| 7 (Empire) | 9×9 | 81 |

---

## Leaderboard Scoring

```
score = (town_level × 100) + (total_buildings × 10) + (population × 5) + (army_size × 3) + total_focus_minutes
```

---

## Achievement Rewards

| Achievement | Reward |
|-------------|--------|
| First Focus | 50 Wood |
| Getting Started | 100 Wood, 50 Iron |
| Hour Power | 25 Gold |
| Week Warrior | 50 Gold |
| Month Master | 200 Gold |
| Village Founded | 200 Wood, 100 Stone |
| Town Builder | 300 Wood, 200 Stone, 50 Gold |
| Fortress Lord | 500 each |
| Populous | 100 Gold |
| Commander | Title "Commander" |

---

## Cross-References

- **Concept:** [GAMEFI_FOCUS_CONCEPT.md](GAMEFI_FOCUS_CONCEPT.md)
- **Plan:** [GAMEFI_FOCUS_PLAN.md](GAMEFI_FOCUS_PLAN.md)
- **TODO:** [GAMEFI_FOCUS_TODO.md](GAMEFI_FOCUS_TODO.md)
