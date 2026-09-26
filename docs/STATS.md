# STATS.md: Stats, Modifiers & Resource Pools

**Read when:** the task involves any stat, health or mana, champion base stats, or anything that changes stats (gear, buffs, passives, levels), including items that change an ability's numbers.
**Depends on:** CLAUDE.md.
**Used by:** MOVEMENT (move_speed, dash_charges), COMBAT, ABILITIES, LOOT, CHAMPIONS, ENEMIES.

## Current code
- `UnitStats` (`res://scripts/data/unit_stats.gd`): one .tres per unit in `res://data/units/`. Fields: display_name, max_health, attack_damage, attack_range, base_attack_speed, attack_windup, attack_speed_cap, ability_haste, move_speed, gameplay_radius, pathing_radius, dash_charges.
- Code reads `unit.stats.<field>` directly, e.g. in `Unit._ready()` and `Ability.get_damage()`.
- `MovementComponent` has its own speed modifiers: flat, then additive %, then **only the strongest slow**, then soft caps. After MOVEMENT.md step 1 the soft cap thresholds are `@export`s on MovementComponent, scaled ×560/345 for Hades pace (357 / 674 / 795 instead of LoL's 220 / 415 / 490).
- `HealthComponent` holds current and max health.
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
| `attack_speed` | from `base_attack_speed` (0.65) | 0.2 / `attack_speed_cap` (2.5) | % modifiers = LoL bonus attack speed |
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
| `pickup_radius` | 200 | - / - | LoL units (64 px), new |
| `magic_find` | 0 | 0 / - | new, LOOT.md |
| `gold_find` | 0 | 0 / - | new |

These are **not stats** (they're fixed identity fields and stay plain on UnitStats): `display_name`, `attack_windup`, `gameplay_radius`, `pathing_radius`.
To add a stat: add a row here, a field to UnitStats, and an entry in the registry. Unknown keys cause a `push_error`, never a silent 0.

## Modifier math
Types: `FLAT`, `PERCENT_ADD` ("increased", summed), `PERCENT_MULT` ("more", each multiplies separately).
```
final = (base + Σ flat) × (1 + Σ percent_add) × Π(1 + percent_mult)
final = clamp(final, min, max)          # integer stats round after the clamp
```
`base` = UnitStats value + growth × (level − 1).

**move_speed special rules** (moved over from MovementComponent): negative PERCENT_ADD modifiers are slows, and **only the strongest slow applies**. The soft caps are applied last. The caps carry over **scaled, not unchanged**: the thresholds are the scaled, tunable values from MovementComponent (defaults 357 / 674 / 795, i.e. LoL's 220 / 415 / 490 × 560/345), computed as "threshold + excess × factor" (factors 0.5 / 0.8 / 0.5). A unit whose MovementComponent overrides the thresholds (slimes keep the LoL values 220 / 415 / 490) keeps those overrides after the migration.

A modifier has: `stat: StringName`, `type`, `value: float`, `source_id: StringName` (e.g. `&"item_4821"`, `&"buff_haste"`), and `scope: StringName` (empty = normal stat; see below).

## Items that change abilities
| Kind | Example | Where |
|---|---|---|
| **Numbers** | "Lunge range +30%", "+1 projectile on projectile abilities", "Cleave cooldown −1.5 s" | this doc: scoped modifiers |
| **Behavior** | "Lunge now stuns", "dash leaves a fire trail", "Q becomes a blink" | ABILITIES.md: augments |

### Scoped modifiers
- Ability params are the `@export` numbers on `Ability` (`cooldown`, `cast_time`, `cast_range`, `base_damage`, `ad_ratio`...). Subclasses may add more (`projectile_count`, `radius`, `duration`).
- Each Ability gets `@export var id: StringName` and `@export var tags: Array[StringName]` (e.g. `&"projectile"`, `&"movement"`, `&"ultimate"`).
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
- `res://scripts/data/stat_registry.gd` + `res://data/stats/stat_registry.tres`: per stat: default, min, max, is_integer, display name, format
- `res://scripts/components/stats_component.gd`: `StatsComponent` (child of Unit)
  - `get_stat(key)`, `get_ability_param(ability, param)`: cached, recalculated when dirty
  - `add_modifier(mod)`, `add_modifiers(arr)`, `remove_modifiers_from(source_id)`
  - `set_level(n)`, signal `stat_changed(key, old, new)`
  - helpers: `get_attack_interval()`, `get_cooldown(base)`
- `res://scripts/components/resource_component.gd`: mana/energy/fury, same shape as HealthComponent (`spend`, `restore`, `can_afford`, regen, `changed`, `depleted`)
- `HealthComponent` and `ResourceComponent` read their max from stats. When the max goes up, current goes up by the same amount; when it goes down, current is clamped.
- `res://scripts/data/champion_data.gd` + `res://data/champions/<name>.tres`: `stats: UnitStats`, `growth: Dictionary[StringName, float]`, `resource_type` (MANA / ENERGY / FURY / NONE), passive, ability slots. (Details in CHAMPIONS.md.)

## Build order
1. StatModifier and the registry.
2. StatsComponent with the math, move_speed rules, caching, and `stat_changed`. Include a test scene that adds/removes modifiers and prints the results.
3. Add StatsComponent to player.tscn and slime.tscn. `Unit._ready()` wires it up.
4. **Migrate reads:** Unit, Ability.get_damage, AutoAttackComponent, and MovementComponent use `get_stat`. Move MovementComponent's speed modifiers into StatsComponent (`add_speed_modifier` becomes a thin wrapper, so existing callers keep working).
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
