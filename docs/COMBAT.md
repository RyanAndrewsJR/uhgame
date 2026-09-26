# COMBAT.md: Basic Attacks, Hits, Damage and Status Effects

**Read when:** the task involves basic attacks, the hit pipeline and damage, damage types, crit and mitigation, status effects and crowd control, i-frames, hitstop, shake and hit flash, damage numbers, reaction rules, or enemy attack damage and telegraphs.
**Depends on:** CLAUDE.md, CONVENTIONS.md (reserved names), STATS.md (stats, modifiers), MOVEMENT.md (input buffer, dash, i-frames, knockback curve), WORLD_INTERACTION.md (WorldQuery, impacts, kill credit).
**Used by:** ABILITIES, CHAMPIONS, LOOT, ENEMIES_AI, DUNGEONS, WORLD_INTERACTION (hazards, reaction rules).

## How to read this doc
- MUST: rules, names and order of operations. Never change these without asking Ryan.
- TARGET: a starting number and an allowed range. Tune inside the range; ask before going outside it.
- FREE: your call (VFX shapes, colors, implementation details). Tiebreaker: VISION.md's decision priorities.

## Player experience
A fight is a short, readable brawl. You click and the Knight swings toward the cursor almost instantly. Each swing plants you for a moment, just long enough to feel the weight, and a dash is always your way out. Hits land with a white flash, a tiny freeze and a push. Swarms chip at you if you stand still; elites wind up big, clearly telegraphed attacks that really hurt, and dodging them is the skill. Numbers pop off enemies, crits are unmistakable, and packs burst apart. You win by reading the fight and moving well, and your build decides how.

## References
- Hades. Take: a click becomes a swing within ~0.1 s; an aimed 3-hit combo; hit enemies flash white; a micro-freeze on heavy hits; floor telegraphs that fill up before the hit; the dash goes through everything; dash-strikes.
- League of Legends. Take: every ability's indicator shows exactly where it lands; readable cooldowns; one clear identity per kit; physical/magic/true damage; on-hit as a build path; tenacity. Don't take: click-an-enemy targeting for basic attacks, attack-move, last-hitting.
- Diablo. Take: packs that burst apart; damage numbers where crits stand out; conditional damage and on-hit build paths; the screen stays readable in chaos. Don't take: stat-check fights where you stand and trade hits; random dodge or block chance.

## Principles
1. The player's input is the authority. Presses fire now or as soon as allowed (input buffer, MOVEMENT.md). Nothing attacks or moves that the player didn't ask for.
2. Commitment is short, deliberate and readable. Every swing roots briefly; a dash is the way out.
3. Motion has shape: knockback uses the knockback curve (MOVEMENT.md F2).
4. Clarity over flash: the player's position, enemy telegraphs and the player's health are always readable. VFX never change gameplay state.
5. Forgiveness goes to the player: player attack hitboxes are slightly bigger than they look, enemy attack hitboxes slightly smaller.
6. Skill over stat checks: threats can be dodged, and sustain comes from build choices, not a baseline.
7. One set of rules for every Unit: one hit pipeline, one status system.

## Rules (MUST)
### Basic attack
- Left mouse = an aimed basic attack toward the cursor (Hades-style): a 3-hit combo; hit 3 is the finisher.
- Every swing roots the attacker for its duration (see Numbers).
- A dash cancels a swing before its hit lands (windup) or during its recovery. The moment the hit lands can't be cancelled. Cancelling resets the combo.
- Pressing attack during a swing queues the next combo hit (input buffer). Each swing needs its own press; holding the button doesn't repeat. The combo resets after combo_reset_time with no attack.
- Q/W/E/R interrupt a swing only if that ability allows it, set per ability: never, after the hit lands (the default; all four Knight abilities), or anytime. Otherwise the press waits for the swing to end (input buffer).
- attack_speed is a combo-speed multiplier for the player: every swing timing is divided by attack_speed ÷ base attack speed (1.0 at base; +20% bonus attack speed = swings 20% faster).
- Dash-strike (proposed): an attack within dash_strike_window after a dash (existing hook) does a stronger variant. Numbers under TARGET.
- attack vs select on left mouse: attack owns left mouse; select is unbound (disabled, not deleted).
- "Your next attack" effects (Iron Resolve) mean the next basic attack swing that hits, and they apply to every enemy that swing hits.

### Hits
- Every application of damage or effects is one Hit, described by a HitContext. In new code all damage goes through the hit pipeline; existing direct take_damage() calls get wrapped, not rewritten.
- Pipeline order: base → stat scaling (ratios) → conditional damage ("increased" by hit tags, `damage_increase`) → crit → mitigation (armor / magic_resist) → incoming_damage ("more": each reduction multiplies separately) → shields → health. "Raw damage" = before mitigation; "damage taken" = after.
- Damage types: PHYSICAL (armor), MAGIC (magic_resist), TRUE (ignores both). Proposed mitigation: damage × 100 / (100 + armor).
- Invulnerability (dash i-frames, post-hit i-frames) blocks the whole hit: damage, knockback, statuses and on-hit.
- Hit tags: basic_attack, ability, proc, dot, crit, the damage type, plus the source ability's tags.
- On-hit: basic attack and ability hits trigger on-hit effects; dot ticks and proc hits never do (loop guard). Each Ability has proc_coefficient (1.0 default, lower for multi-hit or area abilities), which scales on-hit chances and effects. Numbers (on_hit_damage, life_on_hit, resource_on_hit) are stats (STATS.md, planned); behaviors are augments or ReactionRules.
- Events: every hit emits Events.unit_hit(ctx), damage emits unit_damaged(ctx), death emits unit_died(unit, ctx). Reserved names only (CONVENTIONS.md).
- Line of sight: basic attacks never hit through walls. Abilities don't either, unless the ability is marked to ignore walls (e.g. a meteor shower).

### Enemies
- Two kinds of threat: swarms (small chip hits, short or no telegraph) and elites/bosses (big, telegraphed hits). Any enemy attack above the trash damage band has a floor telegraph.
- How fast the player dies is set per enemy, by its damage band (see Numbers).
- Enemy attacks can be walked out of: a hit lands only if the target is still in reach at the moment of the hit.

### Status effects
- One system: StatusComponent plus StatusEffect Resources. Crowd control = statuses tagged cc (stun, root, silence, slow). The existing Unit.apply_stun() and add_speed_modifier() become thin wrappers that create statuses.
- Refresh or stack is decided per StatusEffect (data).
- tenacity shortens crowd control duration; it doesn't affect damage over time.
- DoT kill credit goes to whoever applied the status.

### Sustain
- Every champion starts with zero sustain (health_regen 0). Healing comes only from build choices: abilities, passives and items (life on hit, life steal, regen).

### Damage numbers
- Every hit shows a number above the target.
- Crits use a distinct font (proposed) and are larger.
- DoT ticks use a smaller style and are merged per target over a short window so they don't flood the screen.
- Size grows with the amount, in a few discrete pixel-font steps on a log scale, so late-game numbers don't all hit max size.
- Colors: by damage type (FREE, but readable); damage the player takes is red; healing is green.

## Numbers (TARGET: start, range)
Knight basic attack:
- windup (click to hit): 0.08 s (0.05–0.12)
- root per swing: 0.3 s (0.2–0.35); finisher 0.4 s (0.3–0.5)
- combo_reset_time: 0.6 s (0.4–0.9)
- damage: 1.0 / 1.0 / 1.6 × attack_damage
- reach: 175 u (56 px) from the Knight's feet to the target's edge; arc 110°; finisher arc 140°
- knockback: 6 / 6 / 20 px, using the knockback curve
- dash-strike (proposed): 1.5 × attack_damage, a 16 px lunge

Crit multiplier: 1.75 (the `crit_damage` default for every unit).

Feel per hit (basic attacks, and the default for other hits; abilities set their own):
- hitstop: light 0.03 s (0–0.05); finisher/heavy 0.06 s (0.04–0.08); kill 0.08 s (0.05–0.10). Overlapping hitstops don't stack: take the longest.
- shake: light 0; heavy 2 px; kill 3 px (0–4)
- hit flash: white, 0.06 s

Player getting hit:
- post-hit i-frames: 0.5 s (0.3–0.8), starting from the first hit in a frame (the other hits in that frame are blocked). DoT ticks don't start them.
- knockback on the player: 12 px (0–24); no loss of control beyond the push itself

Enemy damage bands (per hit, as % of the player's max health; a tuning guide for each enemy's damage number, not a formula in-game):
- swarm chip: 2–5%, telegraph 0–0.3 s
- elite: 12–20%, telegraph 0.6–0.9 s
- boss big hit: 25–40%, telegraph 0.9 s or more
- Telegraph: a floor shape that fills up until the hit; one consistent enemy-threat color (FREE which).

Hit forgiveness: player attack hitboxes +10% over their visuals, enemy attack hitboxes −10% (each 0–20%).
Damage numbers: rise 12 px and fade over 0.6 s; 3 size steps.

## Edge cases (MUST: "How each edge case is handled" below says how)
- Stunned mid-swing: the swing is cancelled with no hit, and the combo resets.
- Hit during i-frames: nothing happens (no damage, knockback, status or on-hit).
- A kill during hitstop; several hits in the same frame; overlapping hitstops (take the longest).
- Two knockbacks at once: the stronger one wins.
- The target dies before the swing lands (the swing whiffs); the attacker dies mid-swing.
- Attacks don't go through walls (line of sight via WorldQuery). Abilities: per ability, blocked by default.
- A shield absorbing a hit doesn't stop its knockback.
- DoT ticks can't crit (proposed).

## Current code
What exists today and what happens to each piece (see Build order for when).

| Code | What it does today | Status |
|---|---|---|
| `res://scripts/components/auto_attack_component.gd` (`AutoAttackComponent`, `Unit.attack`) | LoL basic attacks: chase a target, windup (move lock `&"attack_windup"`), then `target.take_damage()` wherever the target is. Backswing doesn't lock movement. Next-attack modifiers (Iron Resolve). Locks by id (`&"stun"`, `&"casting"`). | **Kept and extended.** Enemies keep the LoL attack. C2 adds a combo mode for the player (`combo` export). The player's LoL orders (right-click, attack-move) stay dormant. C4 makes enemy hits whiff out of reach. |
| `Unit.take_damage(amount, source, highlight)` | Checks alive and invulnerable, lowers health, emits `damaged`, spawns a number, flashes. `Player.take_damage` adds a 2 px shake. Called by `AutoAttackComponent._land_attack`, `cleave.gd`, `lunge.gd`, `judgement.gd` and `Unit._on_hurtbox_hurt`. | **Wrapped** (C1): builds a `HitContext` and enters the pipeline at mitigation. Armor is 0 everywhere, so nothing changes in play. |
| `res://scripts/components/hitbox.gd`, `hurtbox.gd` | Area2D damage on overlap. `player.tscn` and `slime.tscn` have a Hurtbox (0.2 s own invincibility); **no scene has a Hitbox**. | **Kept, dormant.** `Unit._on_hurtbox_hurt` builds a `HitContext` (C1), so a future contact-damage enemy or projectile goes through the pipeline. |
| `Unit.add_invulnerability(id)` | Dash i-frames (`&"dash"`) block `take_damage()` and Hurtbox hits. | **Kept.** `Unit.on_hit` checks it first. Post-hit i-frames add `&"hit_iframes"` (C4). |
| `res://scripts/autoload/game_feel.gd` (`GameFeel`) | `hitstop(duration)`: `Engine.time_scale` 0.05; a second hitstop during one is ignored. `shake(amount)`: camera shake in px (the camera keeps the largest). | **Kept.** C3 changes `hitstop()` so the longest wins. |
| `Unit._flash()` | Body modulate ×3, back to white over 0.12 s. | **Kept**, retuned to 0.06 s (C3). |
| `res://scripts/ui/damage_number.gd` | Label: 2 sizes (10 / 13 px), orange when `highlight`, red on the player, rises 18 px over 0.6 s, fades 0.2 s. | **Kept**, restyled in C6. |
| `Unit.apply_stun()` + `res://scripts/vfx/stun_effect.gd` | A `StunEffect` child node holds `&"stun"` move and attack locks; re-stunning keeps the longer time. `is_stunned()` = has that node. | **Wrapped** (C9): creates `status_stun`; the stars become that status's VFX. |
| `MovementComponent.add_speed_modifier()` | Wrapper over `move_speed` StatModifiers; only the timer is on MovementComponent. | **Wrapped** (C9): timed modifiers become statuses; the timer moves to StatusComponent. |
| `MovementComponent.displace()` | A new displacement replaces the running one. | **Changed** (C4): the stronger displacement wins. |
| `res://scripts/enemies/enemy.gd` | Wander, aggro, chase, attack. `passive` = training dummy. Aggro on `damaged`. | **Kept.** C5 adds an optional ability cast for the elite. |
| `res://scripts/main.gd` | "You died – press Backspace to restart" (`restart`), "Room cleared!". | **Kept.** Already covers "die and restart". |
| `res://scripts/abilities/ability_util.gd` | Cone, segment, circle queries using the target's gameplay radius. No line of sight. | **Kept.** C7 adds a line-of-sight filter. |

## Data (Resources)
Names checked against CONVENTIONS.md. `HitContext`, `StatusEffect`, `StatusComponent`, `ReactionRule` and `GameplayEffect` are reserved names; `HitPipeline`, `AttackSwing`, `AttackCombo` and `Telegraph` are new (CONVENTIONS.md, Reserved names).

### HitContext (RefCounted, `res://scripts/combat/hit_context.gd`)
One per hit. Built by the attacker, filled in by the pipeline.

| Field | Type | Notes |
|---|---|---|
| `source` | `Unit` | null = the environment. Kill credit. For a DoT tick: whoever applied the status. |
| `target` | `Node` | a Unit or an interactable (`on_hit(ctx)`) |
| `ability` | `Ability` | null for basic attacks, statuses, hazards, knockback |
| `base_damage`, `ad_ratio`, `ap_ratio` | `float` | stage 1–2 inputs |
| `damage_type` | `HitContext.DamageType` | enum `PHYSICAL`, `MAGIC`, `TRUE` (the reserved `DamageType`, same pattern as `Ability.Targeting`) |
| `tags` | `Array[StringName]` | `&"basic_attack"`, `&"ability"`, `&"proc"`, `&"dot"`, `&"crit"`, `&"physical"` / `&"magic"` / `&"true"`, plus the ability's tags (from STATS step 6) |
| `can_crit` | `bool` | false for DoT ticks and wrapped `take_damage()` calls |
| `proc_coefficient` | `float` | 1.0 default |
| `knockback_px`, `knockback_duration`, `knockback_curve` | `float`, `float`, `Curve` | 0 = none; null curve = the target's `knockback_curve` |
| `knockback_from` | `Vector2` | push away from this point (default: the source's position) |
| `statuses` | `Array[StatusEffect]` | applied after damage (C9) |
| `feel` | `HitContext.Feel` | `NONE`, `LIGHT`, `HEAVY`; a kill upgrades it (C3) |
| `highlight` | `bool` | kept from `take_damage()` for number styling until abilities build their own contexts |
| **filled in by the pipeline:** `raw_damage` (before mitigation), `taken_damage` (after mitigation and `incoming_damage`), `absorbed` (by shields), `health_lost`, `is_crit`, `blocked` (i-frames), `killed` | | read by listeners, numbers, feel and on-hit |

### AttackSwing and AttackCombo (combo data)
- `AttackSwing` (Resource, `res://scripts/data/attack_swing.gd`): one hit of the combo.
  - `windup` (s), `duration` (s, the whole swing = root time), `ad_ratio`
  - `reach_multiplier` (× the `attack_range` stat, 1.0), `arc_deg`
  - `knockback_px`, `knockback_duration`
  - `feel` (`LIGHT` / `HEAVY`), `lunge_px` (0; dash-strike 16)
  - `proc_coefficient` (1.0)
- `AttackCombo` (Resource, `res://scripts/data/attack_combo.gd`): `swings: Array[AttackSwing]`, `combo_reset_time`, `dash_strike: AttackSwing` (null until C12), `hit_forgiveness` (0.10).
- Knight: `res://data/combos/combo_knight.tres` with the three swings from Numbers (0.08 / 0.3 s, 0.08 / 0.3 s, 0.08 / 0.4 s; 1.0 / 1.0 / 1.6; 110° / 110° / 140°; 6 / 6 / 20 px over 0.1 s; LIGHT / LIGHT / HEAVY).

### New fields on Ability
- `damage_type: HitContext.DamageType` (PHYSICAL; the Knight's descriptions already say physical)
- `proc_coefficient: float` (1.0)
- `cancels_swing: Ability.SwingCancel`: `NEVER`, `AFTER_HIT` (default; the Knight's four abilities use it), `ANYTIME`
- `ignores_walls: bool` (false): true = hits don't need line of sight (e.g. a meteor shower)

### StatusEffect (Resource, `res://scripts/data/status_effect.gd`; files `res://data/statuses/status_<name>.tres`)
- `id: StringName` (`&"stun"`; its modifier source id is `&"status_stun"`, CONVENTIONS), `display_name`
- `tags: Array[StringName]`: `&"cc"`, `&"stun"`, `&"root"`, `&"silence"`, `&"slow"`, `&"buff"`, `&"debuff"`, `&"dot"`, `&"shield"`...
- `duration` (s; −1 = until removed)
- `stack_rule`: `REFRESH_LONGER` (keep the longer remaining time; the stun today), `REFRESH` (restart), `STACK` (add a stack up to `max_stacks`, each with its own time), `IGNORE`
- `modifiers: Array[StatModifier]` (slows and hastes are `move_speed` modifiers)
- `blocks_move`, `blocks_attack`, `blocks_cast`, `blocks_dash` (stun: all four; root: move and dash; silence: cast)
- DoT: `tick_interval`, `tick_damage`, `tick_ad_ratio`, `tick_damage_type`. Damage is snapshotted from the applier's stats when applied.
- `shield_amount` (absorb, C10)
- `vfx: PackedScene` (visuals only)

### ReactionRule and GameplayEffect (`res://scripts/data/`; rules in `res://data/reactions/reaction_<name>.tres`)
- `ReactionRule`: `trigger` (`IMPACT`, `HIT`, `HAZARD_ENTERED`, `HAZARD_EXITED`, `STATUS_APPLIED`, `UNIT_DIED`, `HAZARD_OVERLAP`), `required_hit_tags`, `required_unit_tags` (the affected unit's status tags), `required_surface_tags`, `min_impact_speed_px`, `chance` (for `HIT`: × the hit's `proc_coefficient`), `effects: Array[GameplayEffect]`.
- `GameplayEffect` (base): `apply(target: Unit, source: Unit, trigger_ctx: RefCounted) -> void`. First subclasses: `ApplyStatusGameplayEffect`, `DealDamageGameplayEffect` (always tagged `proc`), `KnockbackGameplayEffect`, `HealGameplayEffect`.
- Only `HIT`, `UNIT_DIED` and `STATUS_APPLIED` are built in C11. `IMPACT` and the hazard triggers come with WORLD_INTERACTION's impacts and Hazards.

### New stats (STATS.md; neutral defaults, added in C8)
`incoming_damage` (base 1.0; reductions are negative PERCENT_MULT modifiers, so two 20% reductions give × 0.64), `damage_increase` (0; read with `hit:<tag>` and `target:<tag>` scopes), `on_hit_damage`, `life_on_hit`, `resource_on_hit` (all 0). `crit_damage` defaults to 1.75.

## Architecture / contracts
### New scripts
- `res://scripts/autoload/events.gd`, autoload **`Events`** (C1). Signals (reserved names): `unit_hit(ctx: HitContext)`, `unit_damaged(ctx: HitContext)`, `unit_died(unit: Unit, ctx: HitContext)`, `status_applied(unit: Unit, status: StatusEffect)`, `status_removed(unit: Unit, status: StatusEffect)`. Existing local signals (`Unit.died`, `Unit.damaged`) stay.
- `res://scripts/combat/hit_pipeline.gd`, **`HitPipeline`** (static functions, C1).
  - `static func resolve(ctx: HitContext) -> HitContext`: stages 1–4 (base, stat scaling from the source's StatsComponent, `damage_increase`, crit), then `ctx.target.on_hit(ctx)`.
  - `static func basic_attack(source: Unit, target: Unit, swing: AttackSwing) -> HitContext` and `static func from_ability(caster: Unit, ability: Ability, target: Unit) -> HitContext`: builders that fill tags, type, ratios and feel.
- `Unit.on_hit(ctx: HitContext) -> void` (C1), the same method name interactables use (WORLD_INTERACTION.md). In order:
  1. `blocked` if not alive or invulnerable → return (nothing else happens).
  2. Mitigation by type, then × the target's `incoming_damage`.
  3. Shields (`StatusComponent.absorb_damage()`, C10), then `health.take_damage()`.
  4. Knockback (`movement.displace()`, even if a shield took all of it), then statuses.
  5. `damaged.emit()`, `Events.unit_hit`, `Events.unit_damaged` (when `taken_damage` > 0).
  6. On-hit (only `basic_attack` or `ability` hits, never `proc` or `dot`): `on_hit_damage` as a `proc` hit, `life_on_hit` and `resource_on_hit` × `proc_coefficient`, `life_steal` × `taken_damage` (basic attacks only, proposed).
  7. Death: `Events.unit_died(self, ctx)`; kill credit = `ctx.source`.
  8. Feel (C3) and the damage number (C6).
- `Unit.take_damage(amount, source, highlight)` stays, as a wrapper: a `HitContext` with `base_damage = amount`, PHYSICAL, `can_crit = false`, feel `NONE` (callers keep their own shake and hitstop), then `on_hit()` directly (the amount is already scaled). `Player`'s "got hit" shake moves to a `Player.on_hit` override so pipeline hits get it too.
- `res://scripts/components/status_component.gd`, **`StatusComponent`** (C9), a child of every Unit (`Unit.status_component`, optional so old scenes still load).
  - `apply_status(effect: StatusEffect, source: Unit, duration_override: float = -1.0) -> bool` (tenacity: × (1 − tenacity) for `cc`-tagged statuses only), `remove_status(id)`, `has_status(id)`, `has_tag(tag)`, `get_tags()`, `absorb_damage(amount) -> float`.
  - Signals `status_applied(effect)`, `status_removed(effect)`, re-emitted on Events.
  - Locks through the existing `add_move_lock` / `AutoAttackComponent.add_lock` ids. DoT ticks are `dot` hits through `HitPipeline`.
- `res://scripts/autoload/world_query.gd`, autoload **`WorldQuery`** (C7), with only `has_line_of_sight(from: Vector2, to: Vector2) -> bool` (world layer 1) for now. The rest of its API stays in WORLD_INTERACTION.md.
- `res://scripts/vfx/telegraph.gd`, **`Telegraph`** (Node2D, C5): a floor shape (circle or cone) whose fill grows until the hit time, in the enemy-threat color. VFX only: the ability's own query decides the hit.

### Changes to existing scripts (additive)
- **AutoAttackComponent** (C2): `@export var combo: AttackCombo` (null = LoL mode).
  - Methods: `try_swing(direction: Vector2, dash_strike: bool = false) -> bool`, `can_swing()`, `is_swinging()`, `is_in_recovery()`, `cancel_swing()` (no hit, combo resets), `get_combo_index()`.
  - Signals: `swing_started(index, direction, swing)`, `swing_landed(index, targets)`, `swing_cancelled`, `swing_finished`.
  - A swing: move lock `&"attack_swing"` for `duration / speed`; the aim is locked at the start; at `windup / speed` it queries `AbilityUtil.in_cone()` from the feet with reach and arc × (1 + `hit_forgiveness`), keeps targets in line of sight, and runs `HitPipeline` on each.
  - Next-attack modifiers (Iron Resolve) are used up by the first swing that hits anything and apply to every target it hits.
  - `speed = attack_speed ÷ base attack_speed` (`StatsComponent.get_base_value(&"attack_speed")`). The combo index advances when a swing ends; `combo_reset_time` counts from the end of the swing's recovery.
  - `reset_attack_timer()` (`Ability.resets_auto_attack`) does nothing in combo mode.
- **PlayerInput** (C2): `attack_pressed` → `player.attack.try_swing(player.get_aim_direction(), dash_strike)`.
  - Attack is legal when not stunned, casting, dashing or swinging.
  - An ability press during a swing is legal only if its `cancels_swing` allows it at that moment (then the swing is cancelled first).
  - The buffer timer also pauses while a swing plays out, so a press early in a 0.3 s swing isn't lost after 0.15 s.
- **DashComponent** (C2): `try_dash()` cancels a swing in windup or recovery (not on the hit frame; the hit resolves inside one physics frame, so there's nothing to cancel).
- **Player** (C2): facing = the swing's aim, locked at swing start (same slot as "attack windup" today); `State.ATTACK` = the whole swing.
- **Input map** (C2): `select` loses its left mouse binding (the action and the attack-move code stay).
- **GameFeel** (C3): `hitstop()` keeps one end time (real time); a new call extends it if it ends later.
- **MovementComponent** (C4): `displace()` keeps the running displacement if its remaining distance is larger than the new one's total distance.
- **AutoAttackComponent, LoL mode** (C4): `@export var hit_knockback_px` (slime 12). `@export var enemy_hit_forgiveness` (0.10): the windup starts, and the hit lands, only within `attack_range × (1 − forgiveness)`; out of reach at the hit moment = whiff (no damage, the attack timer still runs).
- **Unit** (C4): `@export var post_hit_iframes: float` (0 = none; the player 0.5). A hit that gets through adds `&"hit_iframes"` for that long; DoT ticks don't start it.
- **MovementComponent / DashComponent** (C4): knockback from `Unit.on_hit` is marked as hit knockback (`is_hit_knockback()`). `DashComponent.can_dash()` allows a dash during it, and the dash replaces the displacement. Any other displacement still blocks the dash.
- **Enemy** (C5): optional AbilityComponent use. When an ability is ready and the target is in its range, cast it (its `cast_time` is the telegraph).

## How each edge case is handled
| Edge case | Handling |
|---|---|
| Stunned mid-swing | A stun adds the `&"stun"` attack lock; `AutoAttackComponent.add_lock()` calls `cancel_swing()`: no hit, root released, combo index back to 0. |
| Hit during i-frames | `Unit.on_hit` returns at step 1 with `blocked = true`: no damage, number, knockback, status, on-hit, events or reaction rules. `take_damage()` does the same through the wrapper. |
| Kill during hitstop | The hit resolves normally; `unit_died` fires at once. The kill hitstop (0.08 s) extends the running one. The death tween runs in scaled time, so it plays out after the freeze. |
| Several hits in the same frame | On enemies all of them resolve in order, each with its own number; hitstop = the longest; shake = the largest (the camera already keeps the max). On the player the first hit lands and starts post-hit i-frames, and the rest are blocked. |
| Overlapping hitstops | `GameFeel` keeps one end time and only extends it. |
| Two knockbacks | `displace()` keeps whichever has more distance left to cover (C4). A stun doesn't stop a knockback (DECISIONS, Movement). |
| Target dies before the swing lands | Swings aren't target-locked: the cone query at the hit moment takes whoever is there; with nobody there the swing whiffs (full animation, no hitstop). Enemy LoL attacks: a dead target cancels the windup (existing). |
| Attacker dies mid-swing | `Unit._on_died()` calls `attack.cancel()`, which also cancels the swing: no hit. Hits that already resolved stay. |
| Walls | Swing targets need `WorldQuery.has_line_of_sight(feet → target feet)`. Abilities filter the same way unless `ignores_walls`; UNIT abilities also need line of sight to start the cast. |
| Shield absorbs a hit | Knockback and statuses still apply; `taken_damage` still counts for life steal; the number shows the absorbed part in a shield style. |
| DoT ticks can't crit | DoT contexts have `can_crit = false`. |
| Knockback on the player | The 12 px push (~0.1 s) is a hit knockback: walking waits for it, but a dash replaces it at once (i-frames as usual). Other displacements (Lunge, pulls, knockback from anything but being hit) still block the dash; a press then is buffered and fires as they end. |

## Build order (one step per request)
Combat starts now, before STATS step 6. Until step 6 adds `id` / `tags` to Ability, hits carry no ability tags. STATS step 6 runs before C8 (C8's `hit:<tag>` scopes need scoped modifiers); STATS step 7 (the F3 overlay) comes after M1.

1. **C1 – Hit pipeline.** `Events`, `HitContext`, `HitPipeline`, `Unit.on_hit`; `take_damage()` and `_on_hurtbox_hurt` wrapped; `damage_type` and `proc_coefficient` on Ability. A test scene `res://scenes/tests/combat_test.tscn` (script in `scripts/tests/`).
   **Done means:** the test passes: mitigation for all three types at 0 / 100 armor, `incoming_damage`, i-frames block everything, the events fire. In play nothing changes: abilities deal the same numbers and slimes chase and hit as before.
2. **C2 – Knight combo.** `AttackSwing`, `AttackCombo`, `combo_knight.tres`, the combo mode, PlayerInput/Dash/Player changes, `cancels_swing`, `select` unbound, Iron Resolve through swings.
   **Done means:**
   - A click swings toward the cursor within 0.08 s; three clicks give the three swings (the third wider and stronger); 0.6 s without attacking resets the combo.
   - Each swing roots; a dash during windup or recovery cancels it and resets the combo.
   - A click during a swing queues the next one; Q during a swing waits for it to end.
   - Iron Resolve's next swing slows every slime it hits; a stun mid-swing cancels it.
   - The Knight's abilities, enemies chasing and the HUD still work.
3. **C3 – Hit feel.** Feel tiers from `HitContext.feel` (light / heavy / kill), longest-wins hitstop, 0.06 s flash, shake per tier.
   **Done means:** swings 1–2 freeze briefly with no shake; the finisher and kills freeze longer and shake; abilities feel as before.
4. **C4 – Getting hit.** Post-hit i-frames, 12 px knockback on the player (marked as hit knockback, which a dash replaces), enemy whiffs out of reach, stronger-knockback-wins, slime windup retuned into 0–0.3 s.
   **Done means:** walking out of a slime's lunge avoids it; three slimes hitting at once cost one hit; after a hit the player is safe for 0.5 s (visible); a hit pushes the player 12 px, and pressing dash during the push dashes at once.
5. **C5 – Elite.** `slime_elite.tscn` (inherits `slime.tscn`) + `data/units/slime_elite.tres` (starting values: 900 health, 100 damage = 15% of the Knight's 650), a telegraphed slam ability (0.75 s telegraph, about 40 px circle), `Telegraph`, the Enemy cast hook, one elite in the sandbox.
   **Done means:** the elite shows a filling floor circle before each slam; dashing or walking out avoids it; standing in it costs about 15% health.
6. **C6 – Damage numbers.** 3 log-scale size steps, crit style (placeholder until the font), colors by type, the player's damage red, healing green, DoT merge, rise 12 px / fade 0.6 s.
   **Done means:** finisher numbers are visibly bigger than swings 1–2; the player's damage shows red; nothing overlaps unreadably with 5 slimes.
7. **C7 – Line of sight.** Minimal `WorldQuery`, the filter in swings and `AbilityUtil`, `ignores_walls` on Ability.
   **Done means:** swings and Cleave don't hit a dummy behind the sandbox pillar; an ability with `ignores_walls` does.

**Milestone M1 – a one-room fight in the sandbox:** the Knight fights with the combo, slimes chip, one elite telegraphs a slam, and the player can die ("You died", Backspace restarts) and win ("Room cleared!").

8. **C8 – Crits and on-hit.** Crit (1.75 default), `damage_increase` scopes, `incoming_damage`, the on-hit stats, `proc_coefficient`. Migrate the Knight's 4 abilities from `take_damage()` to `HitPipeline.from_ability()`, so ability hits get crits, `damage_increase`, on-hit and proper tags.
   **Done means:** the ability numbers are unchanged with no crit or bonuses, and they crit once `crit_chance` > 0.
9. **C9 – Statuses.** `StatusComponent`, `StatusEffect`, `status_stun` / `status_slow` / `status_haste`, the `apply_stun()` and `add_speed_modifier()` wrappers, tenacity, DoT with kill credit.
10. **C10 – Shields** (shield statuses; absorb order: the one expiring soonest first, proposed).
11. **C11 – Reaction rules** (`HIT`, `UNIT_DIED`, `STATUS_APPLIED`; the four GameplayEffects).
12. **C12 – Dash-strike** (after its open question is answered).

For every step: no errors; the Knight's 4 abilities, enemies chasing and the HUD still work. If a step needs removing or rewriting existing code, stop and explain why first.

## Out of scope
Items and affixes (LOOT.md); ability costs, recasts and augments (ABILITIES.md); enemy AI beyond one telegraphed attack (ENEMIES_AI.md); elite affixes; pits; controller support.

## Open questions
- Dash-strike behavior and numbers.
- What attack_speed means for enemies (AutoAttackComponent).
- Sustain caps (life steal cap? regen during combat?).
- Healing between rooms (DUNGEONS.md).
- The crit font asset.
- Confirm the armor formula; is penetration needed? Negative armor *(proposed: LoL's 2 − 100 / (100 − armor))*.
- Life steal: basic attacks only *(proposed)*, or every hit?
- "Your next <ability>" empowers (e.g. "your next Heavy Slam deals 30% bonus true damage") belong in ABILITIES.md (augments or ability buffs).
- Which Knight abilities should ignore walls: CHAMPIONS.md / ABILITIES.md.
- Post-hit i-frames (0.5 s) cap swarm pressure at about 2 hits per second whatever the swarm size. Tune against swarms in M1 (try 0.3 s).
