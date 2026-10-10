# STATS.md: Stats, Modifiers & Resource Pools

**Read when:** the task involves any stat, health or mana, champion base stats, or anything that changes stats (gear, buffs, passives, levels), including items that change an ability's numbers.
**Depends on:** CLAUDE.md.
**Used by:** MOVEMENT (move_speed, dash_charges), COMBAT.md (damage stats, attack_speed as combo speed), ABILITIES, LOOT, CHAMPIONS, ENEMIES, DUNGEONS (enemy scaling by difficulty tier), ALLIES (party scaling).

## Current code
- `UnitStats` (`res://scripts/data/unit_stats.gd`): one .tres per unit in `res://data/units/`. A field for every stat in the Stat list except `knockback_resistance` (approved 2026-09-30, added with the knockback work), plus the identity fields.
- `StatModifier`, `StatDefinition`, `StatRegistry` (`stat_registry.tres`, 28 stats: `threat` added in ENEMIES_AI AI2, `unempowered_attack_damage` in ARCHETYPES AR4) and `StatsComponent`, tested by `res://scenes/tests/stats_test.tscn`. `player.tscn` and `slime.tscn` have a `StatsComponent` node; `Unit.stats_component` points to it (a required child, like HealthComponent) and `Unit._ready()` calls `setup(stats, movement)`.
- On `Unit`, `stats` stays the base `UnitStats` export and `stats_component` is the live StatsComponent. Gameplay reads go through `stats_component.get_stat(&"x")`. Only `attack_windup`, `gameplay_radius` and `pathing_radius` are still read from `unit.stats` (identity fields, not stats).
- Every Ability has `id` (`knight_cleave`, `knight_iron_resolve`, `knight_lunge`, `knight_judgement`, `slime_elite_slam`...) and `tags` (ABILITIES.md). Ability params go through `StatsComponent.get_ability_param()` / `Ability.get_param()`: every param ABILITIES.md lists as a scoped param (`cooldown`, then ability haste in `AbilityComponent.get_cooldown_duration()`; `cast_range` in range checks, the POINT clamp, the enemy cast check, Cleave's reach and the indicator; `base_damage`, `ad_ratio`, `ap_ratio` and scaling-term ratios in `HitPipeline.from_ability()`; costs, charges, the recast window, charge-up times, projectile params, `hit_knockback_px`), plus any param an ability script reads with `get_param()` / `get_effect_param()` (Judgement's `stun_duration`, Lunge's `flag_stun_duration`; the reads that named inputs and conditional bonuses can change use `get_effect_param()`, ABILITIES.md, Conditions). Others (Cleave's cone angle, the slam radius...) are still read directly; each gets routed when an item first needs it.
- Hit-scoped modifiers (`hit:<tag>`, `target:<tag>`) are read per hit with `StatsComponent.get_scoped_stat(key, scopes)` (COMBAT.md, Architecture).
- `MovementComponent.get_move_speed()` returns `get_stat(&"move_speed")` (soft caps included, applied once). `add_speed_modifier(id, flat, percent, duration)` is a thin wrapper: on a unit with a StatusComponent it applies a slow or haste status (modifier source `&"status_<id>"`, timer on the StatusComponent; COMBAT C9); without one it adds FLAT / PERCENT_ADD `move_speed` modifiers with `source_id = id` (the same id replaces) and keeps the timer itself. Without a StatsComponent (`set_stats_component()` not called) MovementComponent uses its old `base_move_speed` math; the stats test uses that path for its parity checks.
- `AutoAttackComponent.bonus_attack_speed` is a thin wrapper too: setting it replaces one PERCENT_ADD `attack_speed` modifier (source `&"bonus_attack_speed"`). Nothing writes it yet; new code adds StatModifiers directly.
- `HealthComponent`: `Unit._ready()` calls `health.set_stats_component()`: the max follows `max_health` (a raised max adds the difference to current, a lowered max clamps it; a dead unit isn't revived), and `health_regen` heals per second while alive. The old `setup(maximum)` still works for a HealthComponent without stats.
- `ResourceComponent` (`Unit.resource_pool`, optional) works the same way with `max_resource` and `resource_regen`. Only the Knight has one: Fury since CHAMPIONS CH3 (100, no regen, starts empty, +8 per enemy a basic attack hits, drains 20/s after 3 s out of combat; CHAMPIONS.md, Fury). Abilities spend it (`resource_cost`, ABILITIES AB3): Cleave costs 20, the Knight's other abilities 0; the sandbox's cost demo is off. The HUD resource bar shows while the player has a pool (ABILITIES.md, HUD).
- `DashComponent` takes its starting charges when the Unit is ready, since the StatsComponent is set up in `Unit._ready()`, which runs after the children's `_ready()`. A lower max later leaves extra charges until they're spent; a higher max recharges up to it.
- All values are in **LoL units** (see CLAUDE.md, `Units.to_px()`).

## Core principle
- **Stats are what a unit IS. Abilities are what a unit DOES. Combat is how damage resolves.** Keep all three separate.
- One `StatsComponent` per `Unit` (champions, enemies, bosses, summons). No player-only stat code.
- `UnitStats` stays the **base** values. Nothing reads `unit.stats.x` for gameplay; everything calls `StatsComponent.get_stat(&"x")`.
- Nothing edits a value directly. All changes go through **modifiers** tagged with a `source_id`, so removing an item or ending a buff removes exactly what it added.

## Fill in
- Leveling: **no** (decided 2026-09-29). Champions don't level their combat stats; in-run power comes from loot, and the persistent champion level only gates talent points (VISION.md, Game structure). Per-level growth and `set_level()` stay built, unused by champions, kept for future enemy scaling (DUNGEONS.md). DUNGEONS.md (2026-10-03) *(proposed there)* scales enemies with modifiers instead (Open questions, enemy scaling), so `set_level()` stays reserved and unused for now.
- Stat points allocated by hand: [no / yes]
- Damage split: **attack_damage + ability_power** (AD vs AP champions). [Keep, or collapse into one stat]

## Stat list
Existing `UnitStats` fields keep their names. New ones get added to `UnitStats`.

**Neutral defaults (rule):** every stat added from step 5 on defaults to a neutral value that changes nothing in play (0 regen, 0 armor, 0 magic_resist, 0 crit chance, crit_damage 1.75 (nothing changes while crit chance is 0), 0 pickup radius...), in both UnitStats and the registry. A unit only gets a stat when its .tres sets a value. The Default column is that neutral default; per-unit values are in the unit's .tres.

| Key | Default | Min / Max | Notes |
|---|---|---|---|
| `max_health` | 600 | 1 / - | |
| `health_regen` | 0 | 0 / - | per second. The Knight and slimes rely on the default (0; zero sustain, COMBAT.md) |
| `max_resource` | 0 | 0 / - | mana/energy/fury. Knight 300 (placeholder); 100 Fury from CHAMPIONS CH3 |
| `resource_regen` | 0 | 0 / - | per second. Knight 0 since CHAMPIONS CH3 (was 6; Fury decays out of combat instead: a ResourceComponent rule, not a stat) |
| `attack_damage` | 60 | 0 / - | |
| `ability_power` | 0 | 0 / - | |
| `attack_speed` | base = `UnitStats.base_attack_speed` (0.65) | 0.2 / the unit's `attack_speed_cap` (2.5) | % modifiers = LoL bonus attack speed. `attack_speed_cap` is a per-unit maximum for this stat, not a stat |
| `crit_chance` | 0 | 0 / 1 | the average; rolled with PRD, one roll per swing or cast (COMBAT.md, Hits). The Knight: 0.25 (`knight.tres`, since 2026-09-28) |
| `crit_damage` | 1.75 | 1 / - | multiplier; COMBAT.md's default for every unit |
| `unempowered_attack_damage` | 1 | 0 / 1 | × the damage of a basic attack swing that carries no empower (ARCHETYPES D12, weak basic attacks): every champion 0.5 (`knight.tres`, `korsavil.tres`), enemies 1. Read by `AutoAttackComponent.get_unempowered_attack_damage()` at the hit (the dash-strike too); empowered swings (Iron Resolve, the riposte) are full and the resource a hit gives is unchanged. The max 1 is *(proposed)*: a plain swing never deals more than a full one. Built ARCHETYPES AR4 2026-10-09, see CHANGELOG.md |
| `armor` | 0 | - / - | mitigation formula in COMBAT.md (proposed: damage × 100 / (100 + armor)). Negative armor is allowed: × (2 − 100 / (100 − armor)), a core rule (below) |
| `magic_resist` | 0 | - / - | as armor, for MAGIC damage; negative allowed (core rule, below) |
| `move_speed` | 345 | scaled soft caps | Knight base is 375 (120 px/s; 560 until 2026-09-28); slime stays 285 (MOVEMENT.md) |
| `ability_haste` | 0 | 0 / - | cooldown × 100 / (100 + haste) |
| `dash_charges` | 1 | 1 / 5 | integer; read by DashComponent (MOVEMENT.md) |
| `attack_range` | 175 | - / - | LoL units edge-to-edge |
| `life_steal` | 0 | 0 / 1 | × damage taken by the target; basic attacks only *(proposed; built that way in COMBAT C8)*. 0 for every unit (zero sustain; the Knight's 0.01 of 2026-09-28 was reverted 2026-09-29) |
| `tenacity` | 0 | 0 / 0.8 | crowd control duration × (1 − tenacity) for statuses tagged `cc` |
| `knockback_resistance` | 0 | 0 / 1 | displacement distance × (1 − value); bosses 1 (WORLD_INTERACTION.md). Approved 2026-09-30 (WORLD_INTERACTION.md, Knockback). Registry entry only; **not on UnitStats** until the knockback work |
| `pickup_radius` | 0 | - / - | LoL units. The Knight has 200 (64 px) since LOOT L7; `PickupComponent` follows it live (LOOT.md) |
| `threat` | 1 | 0.1 / 10 | enemies' target pick: effective distance = edge distance ÷ threat (ALLIES.md; ENEMIES_AI AI2, 2026-10-04: name and limits approved by Ryan). Registry entry only, no UnitStats field; "enemies prefer you" is a modifier on it |
| `magic_find` | 0 | 0 / - | LOOT.md |
| `gold_find` | 0 | 0 / - | |
| `incoming_damage` | 1 | 0 / - | multiplier on damage after mitigation (the result is "damage taken"). Reductions are negative PERCENT_MULT modifiers, so they multiply (two 20% = × 0.64) |
| `damage_increase` | 0 | - / - | "increased" damage: 0.2 = +20%, so items give FLAT modifiers (a PERCENT_ADD on a base of 0 does nothing). Read with `hit:<tag>` / `target:<tag>` scopes |
| `on_hit_damage` | 0 | 0 / - | × proc_coefficient; extra MAGIC `proc` hit on basic attack and ability hits |
| `life_on_hit` | 0 | 0 / - | heal per hit × proc_coefficient |
| `resource_on_hit` | 0 | 0 / - | resource per hit × proc_coefficient. From CHAMPIONS CH3 read with `hit:` / `target:` scopes (the Knight's Fury: +8 scoped `hit:basic_attack`, source `champion_knight`) |

These are **not stats** (fixed identity fields, plain on UnitStats): `attack_windup`, `attack_speed_cap` (the max for `attack_speed`), `gameplay_radius`, `pathing_radius`. (`display_name` was deleted 2026-09-29: nothing read it; a champion's name goes on ChampionData.)
To add a stat: add a row here, a field to UnitStats, and an entry in the registry, all with a neutral default. Unknown keys cause a `push_error`, never a silent 0: `get_stat()` of an unknown stat, and a modifier for an unknown stat, an unknown ability param or an unknown scope kind (Scoped modifiers, below), which is rejected.

**Negative resistance (core rule, built since COMBAT C1):** `armor` and `magic_resist` have no minimum. Below 0 the damage multiplier is LoL's 2 − 100 / (100 − r) (−100 → × 1.5), so it never divides by zero (`HitPipeline.get_mitigation_multiplier()`).

## Modifier math
Types: `FLAT`, `PERCENT_ADD` ("increased", summed), `PERCENT_MULT` ("more", each multiplies separately).
```
final = (base + Σ flat) × (1 + Σ percent_add) × Π(1 + percent_mult)
final = clamp(final, min, max)          # integer stats round after the clamp
```
`base` = UnitStats value + growth × (level − 1).

**move_speed special rules:** negative PERCENT_ADD modifiers are slows, and **only the strongest slow applies**, as its own `× (1 − slow)` factor (capped at 0.99), not inside Σ percent_add. The soft caps are applied last: StatsComponent calls the unit's `MovementComponent.get_soft_capped_speed()`, so the thresholds stay on MovementComponent; with no MovementComponent there are no soft caps. The thresholds are MovementComponent's scaled, tunable values (defaults 357 / 674 / 795, i.e. LoL's 220 / 415 / 490 × 560/345), computed as "threshold + excess × factor" (factors 0.5 / 0.8 / 0.5). A unit whose MovementComponent overrides the thresholds (slimes keep 220 / 415 / 490) keeps those overrides.

A modifier has: `stat: StringName`, `type`, `value: float`, `source_id: StringName` (e.g. `&"item_4821"`, `&"status_haste"`), and `scope: StringName` (empty = normal stat; see below).

## Items that change abilities
| Kind | Example | Where |
|---|---|---|
| **Numbers** | "Lunge range +30%", "+1 projectile on projectile abilities", "Cleave cooldown −1.5 s" | this doc: scoped modifiers |
| **Behavior** | "Lunge now stuns", "dash leaves a fire trail", "Q becomes a blink" | ABILITIES.md: augments |

### Scoped modifiers
- Ability params are the `@export` numbers on `Ability` (`cooldown`, `cast_time`, `cast_range`, `base_damage`, `ad_ratio`...). Subclasses may add more (`projectile_count`, `radius`, `duration`).
- Each Ability has `@export var id: StringName` (`<champion>_<ability>`, no slot, e.g. `&"knight_lunge"`; CONVENTIONS.md) and `@export var tags: Array[StringName]` (e.g. `&"projectile"`, `&"movement"`, `&"ultimate"`).
- A modifier's `scope` decides what it affects:
  - `&""`: a normal stat
  - `&"ability:knight_lunge"`: one ability; `stat` = the param name
  - `&"tag:projectile"`: every ability with that tag
  - `&"hit:<tag>"` / `&"target:<tag>"`: a stat (`damage_increase`, also `crit_chance` and `crit_damage`, and `resource_on_hit` from CHAMPIONS CH3) that counts only for hits carrying that tag, or against targets with that status tag (e.g. `&"target:burning"`). `stat` must be a registered stat. `get_scoped_stat(key, scopes)` returns the stat with the matching scoped modifiers added (same formula and limits; not cached; `get_stat()` ignores them).
- Keys are checked when a modifier is added, so a typo is never a silent 0: a normal or `hit:` / `target:` modifier's `stat` must be a registered stat; an `ability:` / `tag:` modifier's `stat` must be a number `@export` of the Ability base class (`cooldown`, `cast_range`, `base_damage`...), or a param (a subclass `@export` like `radius`, or a scaling term's param) of an ability the unit holds (its AbilityComponent's slots and REPLACE variants) that the scope reaches; any other scope kind is rejected. A rejected modifier `push_error`s and isn't added (tested per scope type in `stats_test.tscn`).
- `get_ability_param(ability, param)` reads the base with `ability.get_base_param(param)` (an export, or a scaling term's ratio; ABILITIES.md), applies the modifiers whose `stat` is the param and whose `scope` is in `ability.get_modifier_scopes()` (`ability:<id>`, `tag:<tag>` for each tag, `ability:<variant_of>`) with the same formula, never returns below 0, and caches the result per ability and param until a scoped modifier is added or removed. `Ability.get_param(caster, param)` is the shortcut abilities use (the plain value without a caster).
- Cooldown order: `get_ability_param(ability, &"cooldown")`, then ability haste; `AbilityComponent.get_cooldown_duration()` is the one place this happens. Planned exception (COMPANIONS.md): a companion's command (role `companion`) takes no ability haste, and its modifier scopes are only `ability:<its id>`.
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

### Augments (behavior)
Specified in ABILITIES.md, Augments (FLAG / EVENT / REPLACE, added and removed by source id). Equipping an item gives its modifiers to `StatsComponent` and its augments to `AbilityComponent`, both under the item's `source_id`. Unequipping removes both. The same augment from two items doesn't stack (ABILITIES.md).

## Architecture
- `res://scripts/data/stat_modifier.gd`: `StatModifier` Resource.
- `res://scripts/data/stat_registry.gd` + `res://data/stats/stat_registry.tres`: `StatRegistry`, a list of `StatDefinition`s (`res://scripts/data/stat_definition.gd`), one per stat: key, display name, default, min, max, is_integer, format, plus
  - `base_field`: the UnitStats field holding the base (empty = same as the key; `attack_speed` reads `base_attack_speed`)
  - `max_field`: a UnitStats field used as a per-unit max (`attack_speed` → `attack_speed_cap`)
  - A stat with no UnitStats field yet (`knockback_resistance`, `threat`) uses its registry default as the base.
- `res://scripts/components/stats_component.gd`: `StatsComponent` (child of Unit). `setup(base_stats, movement, growth)` (`movement` supplies the soft cap thresholds); `get_stat()` and `get_ability_param()` are cached, `get_scoped_stat()` isn't; adding or removing a modifier recalculates only the stats it touches. Also: `get_base_value()` (base + growth, before modifiers), `get_modifiers_from(source_id)`, `get_level()` / `set_level()` (unused by champions; kept for future enemy scaling, DUNGEONS.md), `add_modifier()`, `add_modifiers()`, `remove_modifiers_from(source_id)`, `replace_modifiers(old, new)` (swaps exact modifier instances in one change; a StatScaling's refresh, CHAMPIONS CH2), `get_cooldown(base)` (the attack interval is `AutoAttackComponent.get_attack_interval()`); signal `stat_changed(key, old, new)`, only when a value actually changes.
- `res://scripts/components/resource_component.gd`: `ResourceComponent`, mana/energy/fury, same shape as HealthComponent: `try_spend()` (returns false on failure, CONVENTIONS), `restore()`, `can_afford()`, `is_empty()`, regen, signals `resource_changed(current, maximum)` (mirrors `health_changed`) and `depleted`. `resource_type` (MANA / ENERGY / FURY; NONE appended in CHAMPIONS CH1) is an export on it, set from ChampionData from CH1; CH3 added the resource rhythm (`starts_empty`, `decay_per_second`, `decay_delay`; `get_time_since_combat()`, `is_in_combat()` from `Events.unit_hit`; CHAMPIONS.md, Fury (CH3)). On Unit it's `resource_pool` (CONVENTIONS.md, Vocabulary).
- `HealthComponent` and `ResourceComponent` read their max from stats (`set_stats_component()`, called by `Unit._ready()`): the max going up raises current by the same amount; going down clamps it.
- *(planned, CHAMPIONS CH1–CH3)* `res://scripts/data/champion_data.gd` + `res://data/champions/<name>.tres`: `stats: UnitStats`, `resource_type` (MANA / ENERGY / FURY / NONE) and its rhythm, `modifiers` (source `champion_<id>`), passive, ability slots, combo, sounds, the champion level fields. No `growth`: champions don't level their stats (Fill in); the full field list is CHAMPIONS.md's.

## Build order
1. StatModifier and the registry. Built 2026-09-25, see CHANGELOG.md.
2. StatsComponent with the math, move_speed rules, caching and `stat_changed`, plus `stats_test.tscn`. Built 2026-09-25, see CHANGELOG.md.
3. StatsComponent on player.tscn and slime.tscn. Built 2026-09-25, see CHANGELOG.md.
4. Migrate reads to `get_stat` and speed modifiers into StatsComponent. Built 2026-09-25, see CHANGELOG.md.
5. ResourceComponent, plus the new stat fields on UnitStats. Built 2026-09-25, see CHANGELOG.md.
6. Scoped modifiers, `get_ability_param`, and `id`/`tags` on Ability; cooldowns routed through it. Built 2026-09-26, see CHANGELOG.md.
7. F3 debug overlay (`res://scripts/ui/stat_overlay.gd`): every stat, its base, final value, and each modifier with its source.

**Done means:** a fake item (a modifier array) changes stats and ability params, and removing it restores them exactly; the Knight and slimes behave the same as before step 4; the overlay explains every number.

## Open questions
- Stat allocation and the AD/AP split (see Fill in). Leveling is decided: no (Fill in).
- Armor/MR formula: proposed `100 / (100 + armor)`; still to confirm (COMBAT.md, Open questions). Negative values are settled (core rule, above).
- Enemy scaling by dungeon depth via modifiers (source `&"dungeon_scaling"`)? ~~Proposed: yes.~~ Proposed since DUNGEONS.md (2026-10-03): **no depth scaling of enemy stats.** Enemies scale by **difficulty tier** (Ryan, 2026-10-03: five per wing, each raising enemy health and damage): PERCENT_MULT `max_health` and `outgoing_damage` modifiers under `&"difficulty_tier"`, applied at spawn next to ALLIES.md's `&"party_scaling"` (different sources, so the two multiply). Depth inside a wing changes loot only (LOOT.md). `&"dungeon_scaling"` and `set_level()` stay unused unless Ryan wants depth to scale enemies too. Note: `outgoing_damage` is ALLIES.md's proposed stat (a "more" multiplier on a unit's hit damage), not in the registry yet; it joins the Stat list when Ryan approves it.
- ~~Champion-specific items dropping for other champions?~~ Answered (Ryan, 2026-10-01; LOOT.md, Principles 3): no. Legendary and Artifact items belong to one champion and drop only for it; Common to Exotic fit any champion.
