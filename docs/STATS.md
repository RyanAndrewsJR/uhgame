# STATS.md: Stats, Modifiers & Resource Pools

**Read when:** the task involves any stat, health or mana, champion base stats, or anything that changes stats (gear, buffs, passives, levels), including items that change an ability's numbers.
**Depends on:** CLAUDE.md.
**Used by:** MOVEMENT (move_speed, dash_charges), COMBAT, ABILITIES, LOOT, CHAMPIONS, ENEMIES.

## Current code
- `UnitStats` (`res://scripts/data/unit_stats.gd`): one .tres per unit in `res://data/units/`. Fields: display_name, max_health, attack_damage, attack_range, base_attack_speed, attack_windup, attack_speed_cap, ability_haste, move_speed, gameplay_radius, pathing_radius, dash_charges.
- **Steps 1–4 are built:** `StatModifier`, `StatDefinition`, `StatRegistry` (+ `stat_registry.tres`, all 21 stats) and `StatsComponent`, tested by `res://scenes/tests/stats_test.tscn`. `player.tscn` and `slime.tscn` have a `StatsComponent` node; `Unit.stats_component` points to it and `Unit._ready()` calls `setup(stats, movement)`.
- On `Unit`, `stats` stays the base `UnitStats` export and `stats_component` is the live StatsComponent. Gameplay reads go through `stats_component.get_stat(&"x")`. Only `attack_windup`, `gameplay_radius` and `pathing_radius` are still read from `unit.stats` (identity fields, not stats).
- `MovementComponent.get_move_speed()` returns `get_stat(&"move_speed")` (soft caps included, applied once). `add_speed_modifier(id, flat, percent, duration)` is a thin wrapper: it adds FLAT / PERCENT_ADD `move_speed` modifiers with `source_id = id` (the same id replaces), and only the timer stays on MovementComponent. Without a StatsComponent (`set_stats_component()` not called) MovementComponent uses its old `base_move_speed` math; the stats test uses that path for its parity checks.
- `AutoAttackComponent.bonus_attack_speed` is a thin wrapper too: setting it replaces one PERCENT_ADD `attack_speed` modifier (source `&"bonus_attack_speed"`). Nothing writes it yet; new code adds StatModifiers directly.
- `HealthComponent` holds current and max health. Its max is taken from `get_stat(&"max_health")` once at `_ready()`; following later max_health changes comes with step 5.
- `DashComponent` takes its starting charges when the Unit is ready, since the StatsComponent is set up in `Unit._ready()`, which runs after the children's `_ready()`. A lower max later leaves extra charges until they're spent; a higher max recharges up to it.
- All values are in **LoL units** (see CLAUDE.md, `Units.to_px()`).

## Core principle
- **Stats are what a unit IS. Abilities are what a unit DOES. Combat is how damage resolves.** Keep all three separate.
- One `StatsComponent` per `Unit` (champions, enemies, bosses, summons). No player-only stat code.
- `UnitStats` stays the **base** values. After the migration, nothing reads `unit.stats.x` for gameplay; everything calls `StatsComponent.get_stat(&"x")`.
- Nothing edits a value directly. All changes go through **modifiers** tagged with a `source_id`, so removing an item or ending a buff removes exactly what it added.

## Fill in
- Leveling: [yes, max level __ / no]. If yes, champions get per-level growth.
- Stat points allocated by hand: [no / yes]
- Damage split: **attack_damage + ability_power** (AD vs AP champions). [Keep, or collapse into one stat]

## Stat list
Existing `UnitStats` fields keep their names. New ones get added to `UnitStats`.

| Key | Default | Min / Max | Notes |
|---|---|---|---|
| `max_health` | 600 | 1 / - | exists |
| `health_regen` | 1.5 | 0 / - | per second, new |
| `max_resource` | 300 | 0 / - | mana/energy/fury, new |
| `resource_regen` | 6 | 0 / - | per second, new |
| `attack_damage` | 60 | 0 / - | exists |
| `ability_power` | 0 | 0 / - | new |
| `attack_speed` | base = `UnitStats.base_attack_speed` (0.65) | 0.2 / the unit's `attack_speed_cap` (2.5) | % modifiers = LoL bonus attack speed. `attack_speed_cap` is a per-unit maximum for this stat, not a stat |
| `crit_chance` | 0 | 0 / 1 | new |
| `crit_damage` | 1.5 | 1 / - | multiplier, new |
| `armor` | 30 | - / - | new, formula in COMBAT.md |
| `magic_resist` | 30 | - / - | new |
| `move_speed` | 345 | scaled soft caps | exists. Knight base is 560 (≈179 px/s) for Hades pace; slime stays 285 (MOVEMENT.md) |
| `ability_haste` | 0 | 0 / - | exists: cooldown × 100 / (100 + haste) |
| `dash_charges` | 1 | 1 / 5 | integer. Exists on UnitStats; read by DashComponent (MOVEMENT.md) |
| `attack_range` | 175 | - / - | exists, LoL units edge-to-edge |
| `life_steal` | 0 | 0 / 1 | new |
| `tenacity` | 0 | 0 / 0.8 | reduces crowd control duration, new |
| `knockback_resistance` | 0 | 0 / 1 | *(proposed)* displacement distance × (1 − value); bosses 1. New, WORLD_INTERACTION.md |
| `pickup_radius` | 200 | - / - | LoL units (64 px), new |
| `magic_find` | 0 | 0 / - | new, LOOT.md |
| `gold_find` | 0 | 0 / - | new |

These are **not stats** (they're fixed identity fields and stay plain on UnitStats): `display_name`, `attack_windup`, `attack_speed_cap` (the max for `attack_speed`), `gameplay_radius`, `pathing_radius`.
To add a stat: add a row here, a field to UnitStats, and an entry in the registry. Unknown keys cause a `push_error`, never a silent 0.

## Modifier math
Types: `FLAT`, `PERCENT_ADD` ("increased", summed), `PERCENT_MULT` ("more", each multiplies separately).
```
final = (base + Σ flat) × (1 + Σ percent_add) × Π(1 + percent_mult)
final = clamp(final, min, max)          # integer stats round after the clamp
```
`base` = UnitStats value + growth × (level − 1).

**move_speed special rules** (moved over from MovementComponent): negative PERCENT_ADD modifiers are slows, and **only the strongest slow applies**, as its own `× (1 − slow)` factor (capped at 0.99), not inside Σ percent_add, the same as MovementComponent today. The soft caps are applied last. StatsComponent calls the unit's `MovementComponent.get_soft_capped_speed()`, so the thresholds stay on MovementComponent; with no MovementComponent there are no soft caps. The caps carry over **scaled, not unchanged**: the thresholds are the scaled, tunable values from MovementComponent (defaults 357 / 674 / 795, i.e. LoL's 220 / 415 / 490 × 560/345), computed as "threshold + excess × factor" (factors 0.5 / 0.8 / 0.5). A unit whose MovementComponent overrides the thresholds (slimes keep the LoL values 220 / 415 / 490) keeps those overrides after the migration.

A modifier has: `stat: StringName`, `type`, `value: float`, `source_id: StringName` (e.g. `&"item_4821"`, `&"status_haste"`), and `scope: StringName` (empty = normal stat; see below).

## Items that change abilities
| Kind | Example | Where |
|---|---|---|
| **Numbers** | "Lunge range +30%", "+1 projectile on projectile abilities", "Cleave cooldown −1.5 s" | this doc: scoped modifiers |
| **Behavior** | "Lunge now stuns", "dash leaves a fire trail", "Q becomes a blink" | ABILITIES.md: augments |

### Scoped modifiers
- Ability params are the `@export` numbers on `Ability` (`cooldown`, `cast_time`, `cast_range`, `base_damage`, `ad_ratio`...). Subclasses may add more (`projectile_count`, `radius`, `duration`).
- Each Ability gets `@export var id: StringName` (`<champion>_<ability>`, no slot, e.g. `&"knight_lunge"`; CONVENTIONS.md) and `@export var tags: Array[StringName]` (e.g. `&"projectile"`, `&"movement"`, `&"ultimate"`).
- A modifier's `scope` decides what it affects:
  - `&""`: a normal stat
  - `&"ability:knight_lunge"`: one ability; `stat` = the param name
  - `&"tag:projectile"`: every ability with that tag
- `StatsComponent.get_ability_param(ability: Ability, param: StringName) -> float` reads the base with `ability.get(param)`, applies matching modifiers using the same formula, and caches the result per ability and param.
- Cooldown order: `get_ability_param(ability, &"cooldown")`, then ability haste. `AbilityComponent.get_cooldown_duration()` becomes the one place this happens.
- Damage order: params (base_damage, ratios), then stat scaling, then crit and mitigation (COMBAT.md).
- Tooltips use `get_ability_param()`, so the UI always shows real values.

Example item:
```
modifiers:
  { stat: &"cast_range", type: PERCENT_ADD, value: 0.30, scope: &"ability:knight_lunge" }
  { stat: &"cooldown",   type: FLAT,        value: -1.5, scope: &"ability:knight_cleave" }
  { stat: &"attack_speed", type: PERCENT_ADD, value: 0.10, scope: &"" }
augments:  lunge_stuns   (ABILITIES.md)
```

### Augments (behavior, summary)
Defined fully in ABILITIES.md. An `AbilityAugment` targets an ability id or a tag and is one of:
- **FLAG**: the ability checks `has_augment(&"lunge_stuns")`
- **EVENT**: adds behavior on `cast` / `hit` / `end` / `kill`
- **REPLACE**: swaps in a variant Ability

Equipping an item gives its modifiers to `StatsComponent` and its augments to `AbilityComponent`, both under the item's `source_id`. Unequipping removes both.

## Architecture (new files)
- `res://scripts/data/stat_modifier.gd`: `StatModifier` Resource
- `res://scripts/data/stat_registry.gd` + `res://data/stats/stat_registry.tres`: `StatRegistry`, a list of `StatDefinition`s (`res://scripts/data/stat_definition.gd`), one per stat: key, display name, default, min, max, is_integer, format, plus
  - `base_field`: the UnitStats field holding the base (empty = same as the key; `attack_speed` reads `base_attack_speed`)
  - `max_field`: a UnitStats field used as a per-unit max (`attack_speed` → `attack_speed_cap`)
  - A stat with no UnitStats field yet uses its registry default as the base.
- `res://scripts/components/stats_component.gd`: `StatsComponent` (child of Unit)
  - `setup(base_stats, movement = null, growth = {})`: Unit wires it (step 3); `movement` supplies the soft cap thresholds
  - `get_stat(key)`, `get_ability_param(ability, param)` (step 6): cached. Adding or removing a modifier recalculates only the stats it touches
  - `get_base_value(key)` (base + growth, before modifiers), `get_modifiers_from(source_id)`, `get_level()`: for the overlay and tooltips
  - `add_modifier(mod)`, `add_modifiers(arr)`, `remove_modifiers_from(source_id)`
  - `set_level(n)`, signal `stat_changed(key, old, new)`: emitted only when a value actually changes
  - helpers: `get_attack_interval()`, `get_cooldown(base)`
- `res://scripts/components/resource_component.gd`: mana/energy/fury, same shape as HealthComponent (`spend`, `restore`, `can_afford`, regen, `changed`, `depleted`)
- `HealthComponent` and `ResourceComponent` read their max from stats. When the max goes up, current goes up by the same amount; when it goes down, current is clamped.
- `res://scripts/data/champion_data.gd` + `res://data/champions/<name>.tres`: `stats: UnitStats`, `growth: Dictionary[StringName, float]`, `resource_type` (MANA / ENERGY / FURY / NONE), passive, ability slots. (Details in CHAMPIONS.md.)

## Build order
1. StatModifier and the registry. *(done)*
2. StatsComponent with the math, move_speed rules, caching, and `stat_changed`. Include a test scene that adds/removes modifiers and prints the results. *(done: `res://scenes/tests/stats_test.tscn`, F6. It prints PASS/FAIL per check and includes move_speed parity checks against a real MovementComponent.)*
3. Add StatsComponent to player.tscn and slime.tscn. `Unit._ready()` wires it up. *(done: `Unit.stats_component`, a required child like HealthComponent)*
4. **Migrate reads.** *(done; checked headless against the old formulas for every Unit in the sandbox and room_01)* Every `stats.` read in the code before the migration:

   | File | Reads | After step 4 |
   |---|---|---|
   | `units/unit.gd` `_ready()` | `max_health`, `move_speed` | `get_stat` |
   | `units/unit.gd` `get_gameplay_radius_px()`, `get_pathing_radius_px()` | `gameplay_radius`, `pathing_radius` | stay on UnitStats (not stats) |
   | `components/auto_attack_component.gd` `get_attack_speed()` | `base_attack_speed`, `attack_speed_cap` (+ its own `bonus_attack_speed`) | `get_stat(&"attack_speed")`; the cap is the stat's per-unit max |
   | `components/auto_attack_component.gd` `get_windup_time()` | `attack_windup` | stays on UnitStats (not a stat) |
   | `components/auto_attack_component.gd` `get_range_px()` | `attack_range` | `get_stat` |
   | `components/auto_attack_component.gd` `_land_attack()` | `attack_damage` | `get_stat` |
   | `components/ability_component.gd` `get_cooldown_duration()` | `ability_haste` | `get_stat` |
   | `components/dash_component.gd` (max charges) | `dash_charges` | `get_stat` |
   | `abilities/ability.gd` `get_damage()` | `attack_damage` | `get_stat` |
   | `main.gd` `_process()` (HUD info line) | `player.stats.attack_damage`, `attack_range` | `get_stat` |

   Also move MovementComponent's speed modifiers into StatsComponent (`add_speed_modifier` becomes a thin wrapper, so existing callers keep working). MovementComponent itself reads no `stats.` field; `Unit._ready()` calls `movement.set_stats_component()`, and MovementComponent reads `get_stat(&"move_speed")` live.
5. ResourceComponent, plus the new stat fields on UnitStats.
6. Scoped modifiers, `get_ability_param`, and `id`/`tags` on Ability. Route cooldowns through it.
7. F3 debug overlay (`res://scripts/ui/stat_overlay.gd`): every stat, its base, final value, and each modifier with its source.

**Done means:** a fake item (a modifier array) changes stats and ability params, and removing it restores them exactly; the Knight and slimes behave the same as before step 4; the overlay explains every number.

## Open questions
- Leveling, stat allocation, and the AD/AP split (see Fill in).
- Armor/MR formula: proposed `100 / (100 + armor)`. Decide in COMBAT.md.
- Enemy scaling by dungeon depth via modifiers (source `&"dungeon_scaling"`)? Proposed: yes.
- Champion-specific items dropping for other champions? Proposed: no (LOOT.md).
- Does the same augment from two items stack? Proposed: no (ABILITIES.md).
- *(proposed)* `knockback_resistance` stat, 0–1, scales displacement distance; bosses 1 (WORLD_INTERACTION.md, Knockback).
