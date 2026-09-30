# CHAMPIONS.md: Champions, Passives, Resource Rhythms and the Knight's Kit

**Read when:** the task involves a champion's data (ChampionData), a passive, a champion's resource type and how it fills and drains (fury, energy, mana), a champion's level/progress field, or any part of the Knight's kit (Unbroken, Fury, Staggered, Cleave's heal, Judgement's Fury payoff).
**Depends on:** CLAUDE.md, VISION.md (Game structure: champion level, fixed slots), CONVENTIONS.md, STATS.md (StatsComponent, ResourceComponent, scoped modifiers), COMBAT.md (HitPipeline, statuses, Sustain), ABILITIES.md (the toolkit: conditions, conditional bonuses, named inputs, AB14's cast progress), AUDIO.md (hooks).
**Used by:** TALENTS (per-champion trees gated by the champion level), LOOT (champion-specific items, weapons by class), UI (the hub's champion pick, the passive tooltip, the resource bar), PROGRESSION (saving the champion level), DUNGEONS (respawn rules for the resource).

## How to read this doc
Same as COMBAT.md and ABILITIES.md: MUST (never change without asking Ryan), TARGET (start value and allowed range), FREE (your call; tiebreaker: VISION.md's decision priorities). Items marked *(proposed)* are Claude's picks from the approved plan that Ryan hasn't answered yet; each one is also in Open questions.

## Player experience
You pick the Knight at the hub. He starts a fight with an empty red bar. Every swing that lands fills it; you spend it on Cleave, or save it for a Judgement that stuns longer and hits harder. Lunge through a pack and the enemies you cut through reel, Staggered; a Cleave into them hits much harder. The lower your health, the harder the Knight hits, and at the brink a Cleave that connects pulls you back: a desperate swing into three enemies can heal a third of your health. Standing back is never safe (no regen, Fury drains out of combat); diving in and landing hits is how the Knight survives.

## References
- League of Legends. Take: one identity per kit (passive + three abilities + an ultimate); Olaf's passive (stronger the more health is missing, smoothly, no breakpoint); Tryndamere and Renekton's fury (built by hitting, drains out of combat, empowers abilities); Lee Sin's Q1 → Q2 (mark, then cash in the mark). Don't take: per-ability ranks leveled mid-run (no ranks: ABILITIES.md, Ability ranks).
- Diablo 4. Take: the Barbarian's Fury as a generator/spender rhythm (basic attacks build it, core skills spend it); "while injured" bonuses. Don't take: skills gated behind stat checks.
- Hades. Take: each weapon/character's kit reading at a glance, and rewarding aggression.

## Principles
1. **Champions are data.** A champion is a `ChampionData` .tres plus ability scripts, never a subclass of Player (CLAUDE.md). A new champion needs no new framework code.
2. **Passives are built from the toolkit.** Stat modifiers, reaction rules, statuses, empowers, augments and (only for one-offs) a script, all under one source id. Nothing new at the framework level, except `StatScaling` (Passives, below), because a passive has no cast to carry a named input.
3. **Fixed slots.** A champion's four abilities stay in their slots (VISION.md, Build variety). Build variety comes from talents (TALENTS.md) and item augments reshaping those abilities.
4. **Sustain is earned.** No champion heals by default (COMBAT.md, Sustain). A kit heal is tied to landing one ability and serves skill expression (pillar 1).
5. **Resources set the rhythm.** A resource type changes how a kit plays (pillar 2): fury rewards staying in the fight; mana and energy (later champions) reward pacing.

## Current code
What exists before CH1 (the rest is Data and Architecture):
- `Player` (`res://scripts/player/player.gd`, `res://scenes/player/player.tscn`) is the Knight: `stats` = `res://data/units/knight.tres` (650 health, 64 AD, 0.7 attack speed, 0.25 crit, 375 move speed, MANA 300 at 6/s as a placeholder); `AbilityComponent` q/w/e/r = `knight_q_cleave.tres`, `knight_w_iron_resolve.tres`, `knight_e_lunge.tres`, `knight_r_judgement.tres`; `AutoAttackComponent.combo` = `res://data/combos/combo_knight.tres`; `ResourceComponent.resource_type` = MANA; `hurt_sound` and `low_health_sound` exports set in the scene (`death_sound` null).
- `ResourceComponent` (`res://scripts/components/resource_component.gd`): `ResourceType` MANA / ENERGY / FURY (a label only), starts full, regen from `resource_regen`, `try_spend()`, `restore()`, `resource_changed`, `depleted`.
- The toolkit this doc uses is built (ABILITIES AB1–AB13): conditions (`TARGET_HAS_STATUS`, `RESOURCE_AT_LEAST`), `ConditionalBonus`, named inputs (`self_missing_health`), `ChargeScaling` with an `input`, `hit_units()`, statuses, unit reaction rules, augments, `HitPipeline.apply_on_hit()`, `Unit.heal()`.
- Nothing about champions, passives, fury rules or the champion level exists yet.

## Rules
### What a champion is (MUST)
- A `ChampionData` resource ties together: identity (id, name, class), a base stats reference (`UnitStats`), a resource type and its rhythm (MANA / ENERGY / FURY / NONE), four ability slots Q / W / E / R (one clear identity per kit: three abilities and an ultimate), the default basic attack combo, a passive, the champion's sounds, and the champion level fields.
- Slots are fixed and never remixed between champions or reassigned by the player. REPLACE augments and forms (ABILITIES.md) still change what's active in a slot; that's part of a build, not a slot choice.
- The champion's combo is its default until weapons exist (a champion's combo will come from its equipped weapon, limited by its class; COMBAT.md, Open questions; LOOT.md).
- `champion_class` (the Knight: `bruiser`) is the "class" the COMBAT decisions already use for dash-strike power and which weapons a champion can wield *(proposed name; Open questions)*. It isn't a role tag: role tags are ability roles (`generator`, `core`...).

### Champion level (MUST; a hook only)
- Each champion has its own persistent level and progress, separate from every other champion (VISION.md, Game structure): `champion_level` (int, starts 1) and `champion_xp` (int, starts 0: the XP earned toward the next level). Level plus XP-into-level (rather than total XP) means retuning the curve later can never take a level away.
- It only ever gates that champion's talent points (TALENTS.md). It never calls `StatsComponent.set_level()` and never touches combat stats. There is no leveling inside a run.
- Not designed here: the leveling curve, XP sources and rates (TALENTS.md once it exists). Nothing reads the fields yet.
- The fields hold the value while the game runs. A ChampionData .tres is design data (read-only in an exported build), so it always ships level 1 / 0 XP; saving and loading the player's values from `user://` is PROGRESSION's (or TALENTS') *(proposed; Open questions)*.

### Ability ranks
- None (decided 2026-09-29; ABILITIES.md, Ability ranks; DECISIONS.md, Game structure). In-run power comes from loot; cross-run power from the champion level and the talent tree.

### Passives (MUST)
- A passive is a `Passive` resource on the ChampionData, attached when the champion loads under the source id `passive_<champion id>` (the Knight: `&"passive_knight"`), exactly as an item or an augment source attaches its pieces, and removable the same way (every piece removed by that source id restores the unit exactly).
- It bundles only toolkit pieces: StatModifiers (StatsComponent), `StatScaling`s (below), unit reaction rules (`Unit.add_reaction_rule()`), statuses applied until removed (conditions and `target:` scopes can read them: unique state is a status), augments (AbilityComponent), empowers (statuses), and an optional script for anything truly one-off (`Passive` subclass hooks).
- **`StatScaling`**: a stat modifier whose value follows a 0–1 input through a curve ("stronger the more health you're missing"). It exists because a passive has no cast: the named inputs (`self_missing_health`...) live on a CastContext and are filled when a cast starts, so a passive can't read them. It's data because several kits and items will want it (Olaf, Tryndamere, Diablo's "while injured"; the data-or-script rule). Only `self_missing_health` is built in for now; more inputs are added when something needs them.

### Resource rhythms (MUST; answers ABILITIES.md's open question: they live here)
- Each resource type's rhythm is ChampionData data applied to the ResourceComponent: whether the pool starts empty, whether it decays out of combat and how fast, plus the stats it already has (`max_resource`, `resource_regen`, `resource_on_hit`).
- "In combat" = the unit dealt or took a hit that got through (`Events.unit_hit`, not blocked; DoT ticks count) within the last `decay_delay` seconds of game time.
- Mana and energy champions get their numbers when the first one is designed.

### Sustain (MUST)
- Cleave's heal (`heal_on_hit_ratio`) is a kit mechanic tied to one ability, not the `life_steal` stat, and it doesn't contradict zero baseline sustain (COMBAT.md, Sustain; DECISIONS.md, Combat): no champion gets free healing by default; this one is earned by landing Cleave, and it scales hardest exactly when the player is at risk.
- Every heal goes through the one heal path, `Unit.heal()` (clamped to max health, no overheal, a green number only for what was actually healed). There's no second heal path.

## The Knight
A bruiser: heavy swings, dives into packs, gets stronger and harder to kill the closer he is to death. Pillars: skill expression (the Lunge → Cleave combo, low-health risk), build variety (Fury as a generator/spender rhythm), fluid combat.

### Identity
- `id` `&"knight"`, `display_name` "Knight", `champion_class` `&"bruiser"` *(proposed name)*.
- Stats: `data/units/knight.tres`, unchanged except the resource (Fury, below).
- Combo: `combo_knight.tres` (COMBAT.md), dash-strike 1.5 × AD (the bruiser number COMBAT.md already has).
- Role tags: kept as they are *(proposed)*: Cleave `core` (the spender), Iron Resolve `defensive`, Lunge `mobility`, Judgement `ultimate`. The Knight's generator is his basic attack.
- Walls: no Knight ability ignores walls *(proposed)*.
- Ultimate: cooldown, not a meter (ABILITIES.md). The meter is designed when a champion first uses one.
- Sounds: `hurt_sound` `sound_knight_hurt.tres`, `low_health_sound` `sound_knight_low_health.tres`, `death_sound` none (as today). Audio hooks: see AUDIO.md.

### Passive: Unbroken (name is a placeholder)
- As the Knight's health drops he gains bonus attack damage, smoothly (like Olaf's passive, no hard breakpoint).
- One `StatScaling`: `attack_damage` PERCENT_ADD, full value **+0.40** (TARGET 0.25–0.6), input `self_missing_health`, curve `data/curves/curve_knight_unbroken.tres`: linear from 0 at full health to full at 70% missing (30% health), flat after. So +0% at full health, about +14% at 75%, +28.6% at 50%, +40% at 30% or less. On the Knight's 64 AD: 73 / 82 / 90 AD. It multiplies (base + flat) AD, so AD from items grows with it.
- Armor: not in the first build *(proposed: an armor entry, e.g. +20 FLAT on the same curve, stays off; Open questions)*. Cleave's heal already carries low-health survival.
- Tooltip: "The lower your health, the harder you hit: up to +40% attack damage at 30% health or less."

### Fury (the Knight's resource)
Built from landing basic attacks, drained out of combat, meant to be spent fast rather than banked. Replaces the MANA 300 / 6/s placeholder.

| Number | Value (TARGET range) | Where |
|---|---|---|
| `max_resource` | 100 (MUST: a 0–100 bar) | `knight.tres` (was 300) |
| `resource_regen` | 0 | `knight.tres` (was 6) |
| Starts | empty | ChampionData `resource_starts_empty` |
| Gain | +8 per enemy hit by a basic attack (5–12), the dash-strike included; abilities build nothing | a `resource_on_hit` FLAT 8 StatModifier scoped `hit:basic_attack`, source `champion_knight` *(proposed: per enemy hit rather than once per swing; Open questions)* |
| Decay delay | 3.0 s out of combat (2–5) | ChampionData `resource_decay_delay` |
| Decay | 20 per second (10–40): full to empty in 5 s | ChampionData `resource_decay_per_second` |
| Cleave cost | 20 (15–30): about one combo's worth single-target | `knight_q_cleave.tres` `resource_cost` |
| Iron Resolve, Lunge, Judgement cost | 0 (Lunge must open a fight from an empty bar; Judgement reads Fury instead) | their .tres |
| Judgement threshold | 60 (50–80) | Judgement's conditional bonus |

Rhythm, single target: the combo is about 3 swings per second, so about 24 Fury per second of landed swings; a pack of three fills the bar in about 1.5 s. Cleave's 3 s cooldown caps how fast Fury can be spent on it, so the rest builds toward Judgement's threshold or decays.

### The combo: Lunge → Staggered → Cleave (the systemic-conditions showcase)
League's Lee Sin Q1 → Q2 pattern, built from AB12's existing pieces; no new condition kind.
- **Lunge** applies Staggered to every enemy it hits, through a `ConditionalBonus` with no conditions (an empty list always passes) whose `target_statuses` = [`status_staggered`] and `description` "Staggers enemies hit for 2s." Data only; free Lunges (the `cleave_casts_lunge` augment) stagger too.
- **Cleave** gets a `ConditionalBonus`: condition `TARGET_HAS_STATUS` `staggered` (min 1 stack), modifiers `base_damage` PERCENT_ADD +0.5 and `ad_ratio` PERCENT_ADD +0.5 (TARGET +30–60%), `description` "+50% damage to Staggered enemies." It's checked per enemy at its hit (`from_ability()` with the unit hit), so a Cleave through a mix hits the Staggered ones harder.
- No larger cone against Staggered targets: indicators show plain values, so a cone that grows with a bonus would break "what you see is what you get" (ABILITIES principle 2).
- Staggered isn't consumed by Cleave; it runs out *(proposed; Open questions)*. Cleave's 3 s cooldown already prevents a double cash-in.

### Status: Staggered (`res://data/statuses/status_staggered.tres`)
| Field | Value |
|---|---|
| `id` / `display_name` | `&"staggered"` / "Staggered" |
| `tags` | `staggered`, `debuff`. **Not** `cc`: it's a marker, not crowd control, so tenacity doesn't shorten it, unstoppable doesn't refuse it, a `cc` cleanse doesn't remove it and `target:cc` bonuses don't count it |
| `duration` | 2.0 s (TARGET 1.5–3) |
| `stack_rule` | REFRESH (a second Lunge restarts it) |
| `modifiers`, `blocks_*`, DoT, shield, `reaction_rules`, `augments`, empower fields | none |
| `vfx` | a small marker over the enemy (FREE look, e.g. a pale yellow cracked ring; `res://scenes/vfx/staggered_mark.tscn`). It must be readable: the player needs to see who's Staggered (clarity) |
| Dispellable | only by a cleanse naming `debuff` or `staggered` (`RemoveStatusesByTagGameplayEffect`); nothing cleanses enemies today |
| Source | the Knight (whoever landed the Lunge) |
| Audio | Audio hooks: see AUDIO.md |

### Judgement's Fury payoff
- A `ConditionalBonus` on Judgement: condition `RESOURCE_AT_LEAST` 60 (on the Knight); modifiers `stun_duration` FLAT +0.5 (0.75 → 1.25 s), `base_damage` PERCENT_ADD +0.3 and `ad_ratio` PERCENT_ADD +0.3 (TARGET +20–50%); `description` "At 60+ Fury: +30% damage and +0.5s stun, and it consumes your Fury."
- Checked at the effect (AB8 / AB12 rule): the condition reads the Fury when the hit is built, after the channel. Judgement costs nothing, so no cost is taken before the check.
- The empowered Judgement consumes all the Knight's Fury after its hit *(proposed; Open questions)*: without it, holding 60 would be a free buff, against "spent fast rather than banked". A one-off in `judgement.gd` (it spends `resource_pool.current` when the bonus was active for the hit that landed).
- `judgement.gd` reads `stun_duration` with `get_effect_param()` (CONVENTIONS pattern 6), so the bonus reaches it.
- Retimed (Ryan, 2026-09-29): a **0.75 s channel** (`cast_time`, was 1.5 s; runs on cast progress, ABILITIES AB14) and a **30 s cooldown** (was the 5 s default).

### Cleave's heal on hit
- A new general field on Ability, `heal_on_hit_ratio` (default 0; a scoped param, so items can raise it). Cleave's full value is **0.55**, shaped by `self_missing_health` through a curve: a `ChargeScaling` entry on Cleave with `param` `heal_on_hit_ratio`, `input` `self_missing_health`, `min_fraction` 0, curve `data/curves/curve_knight_cleave_heal.tres`.
- The heal is that ratio × the damage taken by each enemy Cleave hits, summed over every enemy it hits (one heal per hit).
- Anchor points (TARGET placeholders; flat through mid-health, bending sharply near death, not a straight line):

| Knight's health | Missing (curve x) | Heal % of damage dealt | Curve y (÷ 0.55) |
|---|---|---|---|
| 100% | 0 | 0% | 0 |
| 75% | 0.25 | 3% | 0.0545 |
| 50% | 0.5 | 8% | 0.1455 |
| 25% | 0.75 | 15% | 0.2727 |
| 10% | 0.9 | 55% | 1.0 |
| below 10% | 0.9–1 | 55% | 1.0 (flat) |

The curve's points use linear tangents so the table's values are exact between neighbors (e.g. 17.5% health heals about 35%).
- Example (placeholders): at 10% health (Unbroken +40%: 89.6 AD), a Cleave does 80 + 0.7 × 89.6 ≈ 143 to each unarmored enemy; into three slimes it heals 3 × 0.55 × 143 ≈ 235 (36% of 650). Against Staggered enemies (+50%) about 350. At 50% health the same Cleave heals about 11 per enemy.
- Cleave Wave (the AB-M REPLACE variant) has no heal and no Staggered bonus: its .tres keeps the defaults *(proposed; Open questions)*.

### Knight ability sheets (targets after CH5; ABILITIES.md, Ability spec sheet)
Only the lines that change or matter here; everything else is ABILITIES.md's example and the .tres files.
```
Cleave / Knight / Q / knight_cleave
Role tag / other tags: core (the Fury spender) / area, cone
Cost: 20 Fury      Cooldown: 3 s      Cast time: 0.2 s (cast progress, AB14)
Damage: 80 + 70% AD, PHYSICAL
Conditional bonuses: TARGET_HAS_STATUS staggered → base_damage +50%, ad_ratio +50% (per enemy, at its hit)
Heal on hit: heal_on_hit_ratio 0.55, scaled by self_missing_health through curve_knight_cleave_heal (min_fraction 0)
Presentation hooks: empty (AB14)
Tooltip template: "Sweep your sword in a wide arc in front of you, dealing {damage} physical damage ({base_damage} {ratios}) and knocking enemies back. Heals you for up to {heal_on_hit_ratio%} of the damage dealt, more the lower your health." + the bonus line

Iron Resolve / Knight / W / knight_iron_resolve
Unchanged (cost 0, cooldown 8 s, cast time 0).

Lunge / Knight / E / knight_lunge
Cost: 0      Cooldown: 8 s      Cast time: 0.05 s (cast progress, AB14)
Conditional bonuses: (no conditions) → target_statuses status_staggered ("Staggers enemies hit for 2s.")
Supported augment flags: lunge_stuns (unchanged)

Judgement / Knight / R / knight_judgement
Cost: 0 (reads Fury)      Cooldown: 30 s      Cast time: 0.75 s CHANNEL (cast progress, AB14; moving cancels)
Damage: 150 + 100% AD + 20% of the target's missing health, PHYSICAL; stun 0.75 s
Conditional bonuses: RESOURCE_AT_LEAST 60 → base_damage +30%, ad_ratio +30%, stun_duration +0.5 s; then consumes all Fury (proposed)
```

## Data (Resources)
Names checked against CONVENTIONS.md (reserved names, vocabulary).

### ChampionData (Resource, `res://scripts/data/champion_data.gd`; `res://data/champions/<name>.tres`, the Knight's `data/champions/knight.tres`)
Every field defaults to "change nothing"; a Player with no ChampionData keeps using its scene's exports.

| Field | Type | Knight | Maps to (existing) |
|---|---|---|---|
| `id` | `StringName` | `&"knight"` | new; source ids `passive_<id>`, `champion_<id>` |
| `display_name` | `String` | "Knight" | new (`UnitStats.display_name` was deleted) |
| `champion_class` | `StringName` | `&"bruiser"` | new *(proposed name)* |
| `stats` | `UnitStats` | `data/units/knight.tres` | `Unit.stats` |
| `resource_type` | `ResourceComponent.ResourceType` | FURY | `ResourceComponent.resource_type`; `NONE` is added last in the enum: the ResourceComponent node is removed at load |
| `resource_starts_empty` | `bool` | true | `ResourceComponent.starts_empty` (CH3) |
| `resource_decay_per_second` | `float` | 20 | `ResourceComponent.decay_per_second` (CH3) |
| `resource_decay_delay` | `float` | 3.0 | `ResourceComponent.decay_delay` (CH3) |
| `modifiers` | `Array[StatModifier]` | `resource_on_hit` +8 scoped `hit:basic_attack` | StatsComponent, source `champion_<id>` (CH3) |
| `q`, `w`, `e`, `r` | `Ability` | the four `knight_*` .tres | `AbilityComponent.q` / `w` / `e` / `r` |
| `combo` | `AttackCombo` | `combo_knight.tres` | `AutoAttackComponent.combo` |
| `passive` | `Passive` | Unbroken (inline) | CH2 |
| `hurt_sound`, `death_sound`, `low_health_sound` | `SoundEvent` | knight hurt, none, knight low health | `Unit.hurt_sound` / `death_sound`, `Player.low_health_sound` (AUDIO.md) |
| `champion_level` | `int` | 1 | new; plain storage, nothing reads it |
| `champion_xp` | `int` | 0 | new; XP toward the next level; plain storage |

No `growth`: champions don't level their stats (STATS.md, Fill in). Enemies keep per-level growth through `StatsComponent.setup()` (DUNGEONS.md).

### Passive (Resource, `res://scripts/data/passive.gd`; inline in the champion's .tres)
| Field | Type | Notes |
|---|---|---|
| `display_name`, `description` | `String` | the tooltip (where it shows is UI.md's) |
| `modifiers` | `Array[StatModifier]` | added under the passive's source id |
| `stat_scalings` | `Array[StatScaling]` | added with `Unit.add_stat_scaling()` |
| `reaction_rules` | `Array[Resource]` (ReactionRule) | unit rules (typed like `StatusEffect.reaction_rules`, to stay out of the preload cycle) |
| `statuses` | `Array[Resource]` (StatusEffect) | applied from the unit itself; a passive's status has `duration` −1 (until removed) |
| `augments` | `Array[Resource]` (AbilityAugment) | added to the AbilityComponent |
Methods: `apply_to(unit, source_id)`, `remove_from(unit, source_id)`; virtual `_on_added(unit, source_id)` / `_on_removed(unit, source_id)` for a subclass script (`res://scripts/abilities/<champion>/<passive>.gd`, next to the kit). Unbroken needs no script.

### StatScaling (Resource, `res://scripts/data/stat_scaling.gd`; inline)
| Field | Type | Notes |
|---|---|---|
| `modifier` | `StatModifier` | the full-strength modifier (its `stat`, `type`, `value`; `scope` allowed; `source_id` ignored: the holder's is used) |
| `input` | `StringName` | `&"self_missing_health"` (the only one built in; an unknown input `push_error`s and counts 0) |
| `curve` | `Curve` | x = the input 0–1, y = the fraction of `value` (0–1); null = linear |
`get_value(unit) -> float` = `modifier.value` × curve(input).

### ResourceComponent additions (CH3; every default changes nothing)
- `enum ResourceType { MANA, ENERGY, FURY, NONE }` (NONE appended; only ChampionData uses it).
- `starts_empty: bool = false`: `setup()` puts current at 0; a raised max doesn't add to current.
- `decay_per_second: float = 0.0`, `decay_delay: float = 0.0`: out of combat for `decay_delay` seconds, current drops by `decay_per_second` × delta, down to 0. Decay isn't spending, so it never emits `depleted`. A pool uses regen or decay, not both (both work, but nothing designs for it).
- `get_time_since_combat() -> float`, `is_in_combat() -> bool` (hit dealt or taken within `decay_delay`).

### Ability and HitContext additions (CH5)
- `Ability.heal_on_hit_ratio: float = 0.0` (ABILITIES.md, Data).
- `HitContext.heal_on_hit_ratio: float = 0.0` (COMBAT.md, HitContext).

### Other files
- `res://data/statuses/status_staggered.tres` (+ `res://scenes/vfx/staggered_mark.tscn`, FREE look).
- `res://data/curves/curve_knight_unbroken.tres`, `res://data/curves/curve_knight_cleave_heal.tres`.
- Knight ability .tres changes: Cleave (cost 20, the Staggered bonus, heal ratio and its scaling), Lunge (the Staggered bonus), Judgement (the Fury bonus, cast time 0.75, cooldown 30).

## Architecture / contracts
### Loading a champion (CH1)
- `Player` gets `@export var champion: ChampionData` (null = the scene's own exports, exactly as before). `player.tscn` sets it to `data/champions/knight.tres`; its old exports stay (the same values) until Ryan confirms CH1, then they can be cleared (disable before deleting).
- `Player._ready()`, **before** `super._ready()`: `_apply_champion()` copies `stats`, the four slots, `combo`, the sounds and the resource rhythm onto the nodes (`self.stats`, `abilities.q...`, `attack.combo`, `resource_pool.resource_type` / `starts_empty` / `decay_*`). The children's `_ready()` has already run, but none of them reads these exports there (checked: AbilityComponent and AutoAttackComponent only cache their unit). For NONE, the ResourceComponent node is freed and `resource_pool` set to null before `Unit._ready()` wires it. Then `Unit._ready()` sets up stats, health and the pool from the champion's stats as usual.
- **After** `super._ready()` (the StatsComponent is set up): the champion's `modifiers` go to StatsComponent under `champion_<id>` (CH3), and the passive attaches (CH2). The hub (later) sets `champion` before the Player enters the tree.
- The champion level fields are never read by the loader.

### The passive (CH2)
- `Passive.apply_to(unit, source_id)`: `stats_component.add_modifiers()` (each a copy with `source_id`), `unit.add_stat_scaling(s, source_id)` for each scaling, `unit.add_reaction_rule(rule, source_id)`, `status_component.apply_status(status, unit)` for each status (its own `duration`, −1 = until removed; its modifiers go under `status_<id>` as usual), `abilities.add_augment(aug, source_id)`, then `_on_added()`. `remove_from()` undoes each by source id (`remove_modifiers_from`, `remove_stat_scalings_from`, `remove_reaction_rules_from`, `remove_status` per status id, `remove_augments_from`), then `_on_removed()`. The same pattern items and SandboxAugments use.
- `Unit.add_stat_scaling(scaling, source_id)` / `remove_stat_scalings_from(source_id)` (mirroring `add_reaction_rule()`): the unit keeps one StatModifier copy per scaling (value `get_value()`, the given source id) in its StatsComponent. On `health_changed` (which also fires when max health changes) it marks the scalings dirty and refreshes them once, deferred to after that physics frame's hits (`call_deferred`): remove that source's scaled copies, add them again with the new values. So every hit of one swing or cast sees the same AD, and `stat_changed` fires only when the value moves.
- Unbroken on the F3 overlay (STATS step 7, later) shows as a modifier from `passive_knight`.

### Fury (CH3)
- `HitPipeline.apply_on_hit()` reads `resource_on_hit` with `get_scoped_stat(&"resource_on_hit", get_hit_scopes(ctx))` instead of `get_stat()`, so `hit:` / `target:` scoped modifiers reach it (the same read as `damage_increase`; nothing else changes: no unit had any `resource_on_hit`). The Knight's `champion_knight` modifier (+8, `hit:basic_attack`) makes every enemy a swing hits add 8 × the swing's `proc_coefficient` (1.0).
- `ResourceComponent` connects to `Events.unit_hit` in `_ready()`: a hit that got through whose `source` or `target` is its unit resets `_since_combat` to 0. `_physics_process(delta)` (game time) adds delta to `_since_combat`; regen as before; then, if `decay_per_second` > 0, current > 0 and `_since_combat` ≥ `decay_delay`: current = max(current − decay × delta, 0) and `resource_changed`.
- Costs are the existing `resource_cost` (paid at cast start, refunded on cancel or interrupt, "not enough resource" fails at once and isn't buffered).
- The sandbox's cost demo (`SandboxAbilities.demo_costs`) is turned off in `sandbox.tscn` (its 30 / 40 / 50 / 80 would stack on the real costs and make every slot uncastable at 0 Fury). The demo code stays.
- **HUD implications (notes only; the work belongs to UI.md or its own step):** the bar is red (fury, already); it starts empty and visibly drains out of combat; a tick mark at the Judgement threshold (60) and a glow while the Knight is at or above it would make the payoff readable; the existing blink on "not enough resource" covers Cleave; R's slot could brighten while the bonus is live.

### Staggered, Cleave, Judgement (CH4)
- All data except two script lines: `judgement.gd` reads `stun_duration` with `get_effect_param(caster, &"stun_duration", ctx, target)`, and (if approved) consumes the Fury after its hit when `get_active_bonuses(caster, ctx, target)` includes the Fury bonus and the hit landed (`resource_pool.try_spend(resource_pool.current)`).
- Lunge's Staggered rides the hit's statuses (`from_ability()` appends passing bonuses' `target_statuses`), so it's applied after the damage, from the Knight, never to a unit the hit killed, and refused by an untargetable unit (AB10).

### Heal on hit (CH5)
1. `Ability.heal_on_hit_ratio` (export, group "Sustain"). A number `@export` of the Ability base class, so it's a scoped param automatically (`is_base_param()`).
2. Cleave's `.tres`: `heal_on_hit_ratio` 0.55 and a `ChargeScaling` (`param` `heal_on_hit_ratio`, `input` `self_missing_health`, `min_fraction` 0, the curve). `ChargeScaling` already reads any named input (AB12), so no new scaling code.
3. `HitPipeline.from_ability(caster, ability, target, cast)`: with a cast, `ctx.heal_on_hit_ratio = ability.get_effect_param(caster, &"heal_on_hit_ratio", cast, target)` (scoped modifiers, the named-input scaling, conditional bonuses). Without a cast it stays 0 (the old path adds nothing new; every toolkit hit passes its cast).
4. `HitPipeline.apply_on_hit(ctx)`: `heal += ctx.heal_on_hit_ratio × ctx.taken_damage`, next to `life_on_hit` and `life_steal`, so it keeps every on-hit rule (only `basic_attack` / `ability` hits, never `proc` or `dot`, not blocked, the source alive) and goes through `Unit.heal()` with one green number per hit.
5. `self_missing_health` is re-read at the effect start (flow step 10), so a hit taken during Cleave's 0.2 s cast time counts *(proposed; Open questions: it changes when ABILITIES' named input is filled)*. One value per cast: every enemy of one Cleave gets the same ratio.

## Audio hooks
See AUDIO.md. Champion sounds (hurt, death, low health) move onto ChampionData in CH1. Fury, Staggered and the heal use existing hooks (the resource bar has no sound; Staggered's apply sound, if any, is a status sound; heals have none) until AUDIO.md adds any.

## How each edge case is handled
| Edge case | Handling |
|---|---|
| Staggered runs out between Lunge and Cleave | Cleave's bonus is checked at its hit (AB12), so an expired Staggered gives nothing. The window is wide: a Cleave pressed during Lunge is buffered and fires as Lunge ends, its effect 0.2 s later, leaving about 1.8 s of the 2 s. |
| Cleave hits Staggered and non-Staggered enemies | Checked per enemy: only the Staggered ones get +50% (and their bigger damage heals more). |
| Lunge kills an enemy | No Staggered on the dead (statuses skip a target the hit killed). |
| A free Lunge from the `cleave_casts_lunge` augment | It staggers too (the bonus is on Lunge's .tres). Cleave's own hits resolve first (the free Lunge's hits come after its dash), so that Cleave never gets the bonus from them. |
| Unstoppable or untargetable enemy | Staggered isn't `cc`, so unstoppable doesn't refuse it; untargetable refuses it (statuses from other units, AB10). |
| Cleave's heal on a killing blow | `apply_on_hit()` runs for killing hits, so it heals. It uses `taken_damage`, overkill included, the same as `life_steal` *(proposed; Open questions)*. |
| Healing at max health | A no-op: `Unit.heal()` clamps at max, returns 0 and shows no "+0"; nothing becomes overheal or a shield. At full health the ratio is 0 anyway (0% missing). If the first enemy's heal fills the Knight, the rest heal nothing. Tested in CH5 (this also tests the existing "heals show no overheal"). |
| Heal from a blocked hit, or while the Knight is dead | None (blocked hits have no on-hit; `apply_on_hit()` stops for a dead source). |
| Heal on a shield-absorbed hit | Counts: `taken_damage` includes the absorbed part (as for life steal). |
| Fury threshold: at cast or at the effect | At the effect (AB8 / AB12): `RESOURCE_AT_LEAST` reads the Fury when Judgement's hit is built, after the channel. It costs nothing, so no cost is taken before the check. |
| Fury drops below 60 during Judgement's channel | No bonus: decay runs only 3 s after the last hit dealt or taken, so a Judgement cast from out of combat can lose it during the channel. The HUD tick (UI.md) makes that readable. |
| Unbroken and Cleave's heal both read missing health | They don't fight: Unbroken refreshes at most once per physics frame, after that frame's hits, so every enemy of one Cleave sees the same AD; the heal's ratio is one value per cast. A heal raises health, so Unbroken's AD drops from the next frame. At low health they compound on purpose (more AD × a higher heal ratio). |
| Max health changes (an item) | `health_changed` fires, so Unbroken re-evaluates; the heal ratio uses the new max at the next cast. |
| Cleave pressed without 20 Fury | "Not enough resource": the bar blinks, nothing spent, not buffered (AB3). |
| Fury at max | `restore()` does nothing past 100. |
| The passive removed (tests; later a form or talent swap) | `remove_from()` removes every piece by `passive_knight`: AD back exactly. |
| The Knight dies or the room restarts | Today a restart reloads the scene (Fury back to 0). Checkpoint respawns (DUNGEONS.md) *(proposed: Fury resets to 0)*. |
| A champion with resource type NONE | The ResourceComponent is freed at load; no costs, no resource bar (ABILITIES.md). |

## Build order (one step per request)
Every step: the Knight's abilities, enemies chasing and the HUD still work; build logs go in CHANGELOG.md (a Champions section); this doc keeps one line per built step. ABILITIES AB14 (cast progress and presentation hooks) comes first.

1. **CH1 – ChampionData and the Knight's migration.** `champion_data.gd` (every field except `passive` and `modifiers`), `ResourceType.NONE`, `data/champions/knight.tres` pointing at the existing files, `Player.champion` and `_apply_champion()`, `player.tscn` set to it, the champion sounds, `champion_level` / `champion_xp`; `res://scenes/tests/champions_test.tscn` + `scripts/tests/champions_test.gd`.
   **Done means:** the game plays exactly as before (the same numbers, slots, combo, sounds); a Player with `champion` null uses its exports; the champions test checks the loaded values against the .tres and that NONE removes the pool; every existing test passes unchanged.
2. **CH2 – The passive framework and Unbroken.** `passive.gd`, `stat_scaling.gd`, `ChampionData.passive`, `Unit.add_stat_scaling()` / `remove_stat_scalings_from()`, the attach after `super._ready()`, Unbroken inline in the Knight's .tres, `curve_knight_unbroken.tres`.
   **Done means:** the Knight's AD is 64 at full health, about 82 at 50%, 90 at 30% and below, following health both ways (damage and a heal); every enemy of one swing or Cleave sees the same AD; removing the passive restores every stat exactly; a test passive with a modifier, a rule, a status and an augment attaches and detaches cleanly.
3. **CH3 – Fury.** `ResourceComponent` (`starts_empty`, decay, combat time), the scoped `resource_on_hit` read in `apply_on_hit()`, `ChampionData.modifiers` and the resource fields, `knight.tres` (max 100, regen 0), Cleave's cost 20, `demo_costs` off in `sandbox.tscn`; the stats, abilities and combat tests that pinned 300 mana read the new data instead (DECISIONS, Testing).
   **Done means:** the bar starts empty; each enemy a swing hits adds 8, ability hits add nothing; 3 s after the last hit dealt or taken it drains at 20/s; Cleave below 20 Fury fails with the bar's blink; Lunge, Iron Resolve and Judgement cast from 0.
4. **CH4 – Staggered, the combo and Judgement's payoff.** `status_staggered.tres` and its marker, Lunge's and Cleave's bonuses, Judgement's Fury bonus, its 0.75 s channel and 30 s cooldown, `judgement.gd` (`stun_duration` through `get_effect_param()`; the Fury consumption if approved).
   **Done means:** enemies Lunge cuts through show the marker for 2 s; Cleave hits them for +50% (and others normally); Judgement at 60+ Fury stuns 1.25 s and hits 30% harder (and empties the bar, if approved), below 60 it's the plain 0.75 s; tooltips list the bonus lines.
5. **CH5 – Cleave's heal on hit.** `Ability.heal_on_hit_ratio`, `HitContext.heal_on_hit_ratio`, `from_ability()` and `apply_on_hit()`, Cleave's ratio and scaling, `curve_knight_cleave_heal.tres`, the effect-start `self_missing_health` read (if approved).
   **Done means:** at full health Cleave heals nothing; at 50% about 8% of its damage per enemy; at 10% about 55%; three enemies heal three times; a killing blow heals; at max health nothing is healed or shown; the heal works with Unbroken without order effects; no other ability heals.

**Milestone CH-M – the Knight's kit** (after CH5): a play test in the sandbox of the whole loop: build Fury with swings, Lunge through a pack, Cleave the Staggered enemies, Judgement an elite at 60+ Fury, and survive a low-health fight on Cleave's heal.
**Done means:** Ryan's play test: the kit reads at a glance and the numbers feel right (then they stop being placeholders).

## Out of scope
The leveling curve, XP sources and talent points (TALENTS.md); saving the champion level (PROGRESSION.md); the hub and champion select (UI.md, NPCS.md); weapons and champion-specific items (LOOT.md); the ultimate meter (here, when a champion uses one); other champions; the HUD's resource-bar tick and glow (UI.md); voice lines (AUDIO.md).

## Open questions
Claude's proposals from the approved plan (written in above as *(proposed)*; Ryan can overrule any):
1. `champion_class` as the field name for bruiser / diver / rogue... (not "role": role tags are ability roles)?
2. Unbroken: AD only (proposed), or armor too (e.g. +20 on the same curve)?
3. Fury: +8 per enemy hit by a basic attack (proposed, through the scoped `resource_on_hit`), or once per swing that lands? Should taking damage build Fury too (proposed: no)?
4. Does the empowered Judgement consume all Fury (proposed: yes), or only read it?
5. Cleave's heal on overkill: the full `taken_damage` like `life_steal` (proposed), or capped at the health the target actually lost?
6. Re-read `self_missing_health` at the effect start (proposed: yes; it changes when ABILITIES' built-in input is filled, for every ability), or keep it at cast start?
7. Does Cleave consume Staggered (proposed: no)?
8. Cleave Wave (the REPLACE variant): no heal and no Staggered bonus (proposed), or the same as Cleave?
9. Champion level: stored in memory on ChampionData, saved to `user://` later by PROGRESSION (proposed)?
10. The Knight's role tags kept as they are, and no Knight ability ignores walls (both proposed)?

Still open:
- The ultimate meter (Hades-style), when a champion first uses one.
- Fury on checkpoint respawn (DUNGEONS.md; proposed: reset to 0).
- Other resource types' rhythms (energy, mana) with their first champion.
- Unbroken's final name.
