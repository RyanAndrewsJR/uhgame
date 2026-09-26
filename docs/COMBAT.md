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
- Every swing roots the attacker for its duration (see Numbers). Melee swings still step during the root, and walking can end the recovery early (Melee basic attacks, below).
- A dash cancels a swing before its hit lands (windup) or during its recovery. The moment the hit lands can't be cancelled. Cancelling resets the combo.
- Pressing attack during a swing queues the next combo hit (input buffer). Each swing needs its own press; holding the button doesn't repeat. The combo resets after combo_reset_time with no attack.
- Q/W/E/R interrupt a swing only if that ability allows it, set per ability: never, after the hit lands (the default; all four Knight abilities), or anytime. Otherwise the press waits for the swing to end (input buffer).
- attack_speed is a combo-speed multiplier for the player: every swing timing is divided by attack_speed ÷ base attack speed (1.0 at base; +20% bonus attack speed = swings 20% faster), times the combo's `speed_scale`.
- Attack pace comes from the swings themselves, not a cooldown: the next swing starts when the current one ends, plus that swing's `pause_after` (a breather, e.g. after a finisher, like Hades' sword). Only attacking waits during it; moving, dashing and abilities don't, and a click during it fires when it ends. There's no global cooldown between attacks and abilities.
- Dash-strike (proposed): an attack within dash_strike_window after a dash (existing hook) does a stronger variant. Numbers under TARGET.
- attack vs select on left mouse: attack owns left mouse; select is unbound (disabled, not deleted).
- "Your next attack" effects (Iron Resolve) mean the next basic attack swing that hits, and they apply to every enemy that swing hits.

#### Melee basic attacks
The rule for every combo with `attack_style` MELEE (the default; the Knight is the first). Any future melee champion gets it by having a combo, with no new code. RANGED combos get none of 1–2 (ranged basic attacks are designed later); 3 applies to both. Enemies (League-style attacks) are unchanged.
1. **Swing step:** every swing moves the attacker forward along its aim during its windup, by the swing's `lunge_px`. It's a `displace()` with the dash curve (ease-out), so it follows the displacement rules: it moves the attacker through the swing's root, slides along walls (a head-on wall stops it), is stopped by unit bodies and never pushes enemies or passes through them. A dash during the step replaces it; a stun (or anything else that cancels the swing) ends it.
2. **Target pull** (only when aiming at an enemy): at swing start, the aimed enemy is the one whose edge is within reach + `assist_range_bonus_px` of the attacker's feet and within `assist_angle_deg` of the aim, in line of sight (WorldQuery). The smallest angle off the aim wins; ties go to the nearer one. If there is one:
   - **Aim snap:** the swing's aim turns toward it by up to `assist_snap_deg`. Facing and the hit cone use the snapped aim.
   - The step goes toward it instead of along the aim, and stretches so the swing ends with its edge at `stop_at_reach_fraction` × reach, capped at the swing's `lunge_max_px`. If it's already closer than that, the step is just `lunge_px`, and never goes into its body (it stops at its edge).
   - Nothing aimed at: the plain `lunge_px` step along the aim.
3. **Walking cuts recovery** (`walk_cancels_recovery`): after the hit, a movement press or a held direction ends the rest of the root once `recovery_move_cancel_after` has passed since the hit. The swing still runs out its duration, so the next swing waits for it (walking never attacks faster than standing) and the combo index is kept: walk → swing → walk → swing still reaches the finisher within `combo_reset_time`. A dash still cancels the recovery at any time (and resets the combo).

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
- breather after the finisher (`pause_after`): 0.25 s (0–0.4); none after swings 1–2. `speed_scale` 1.0
- Per-champion pace (FREE per champion, decided in CHAMPIONS.md): bruisers heavier (e.g. ~1.4 s for 3 hits), divers and rogues snappier (~0.75 s); the Knight's combo takes 1.0 s + the breather
- damage: 1.0 / 1.0 / 1.6 × attack_damage
- reach: 175 u (56 px) from the Knight's feet to the target's edge; arc 110°; finisher arc 140°
- knockback: 6 / 6 / 20 px, using the knockback curve
- dash-strike (proposed): 1.5 × attack_damage, a 16 px lunge

Melee basic attacks (the class defaults; the Knight's combo uses them):
- swing step `lunge_px`: 6 / 6 / 10 px for swings 1 / 2 / 3 (0–12)
- `lunge_max_px`: 24 / 24 / 32 px (0–40)
- assist range: reach + 40 px (`assist_range_bonus_px` 40; reach + 0–64)
- `assist_angle_deg`: 35° (0–45)
- `assist_snap_deg`: 20° (0–30)
- `stop_at_reach_fraction`: 0.7 (0.5–0.9); for the Knight the pull ends with the enemy's edge 39 px from his feet
- `recovery_move_cancel_after`: 0.1 s (0–0.2)

Crit multiplier: 1.75 (the `crit_damage` default for every unit).

Feel per hit (basic attacks, and the default for other hits; abilities set their own):
- hitstop: light 0.03 s (0–0.05); finisher/heavy 0.06 s (0.04–0.08); kill 0.08 s (0.05–0.10). Overlapping hitstops don't stack: take the longest.
- shake: light 0; heavy 2 px; kill 3 px (0–4)
- hit flash: white, 0.06 s

Player getting hit:
- post-hit i-frames: 0.5 s (0.3–0.8), starting from the first hit in a frame (the other hits in that frame are blocked). DoT ticks don't start them.
- knockback on the player: 12 px (0–24); no loss of control beyond the push itself

Enemy damage bands (per hit, as % of the player's max health; a tuning guide for each enemy's damage number, not a formula in-game):
- swarm chip: 2–5%, telegraph 0–0.3 s. Slimes: 22 damage (3.4% of the Knight's 650), 0.25 s windup (`attack_windup` 0.175 at 0.7 attack speed; was 0.5 s), 12 px push
- elite: 12–20%, telegraph 0.6–0.9 s. Elite slime slam: 100 (15.4% of the Knight's 650), 0.75 s telegraph, 40 px circle, 20 px push; its basic attack is 30 (4.6%), no telegraph
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
- Melee: the target moves or dies during the step (the step keeps going to its planned point; nothing re-targets).
- Melee: several enemies in the assist cone (the one closest to the aim line wins).
- Melee: a wall or pillar in the way (the step stops or slides; line of sight rules out targets behind walls).
- Melee: a step that would end inside an enemy (it stops at its edge).

## Current code
What exists today and what happens to each piece (see Build order for when).

| Code | What it does today | Status |
|---|---|---|
| `res://scripts/components/auto_attack_component.gd` (`AutoAttackComponent`, `Unit.attack`) | LoL basic attacks: chase a target, windup (move lock `&"attack_windup"`), then `target.take_damage()` wherever the target is. Backswing doesn't lock movement. Next-attack modifiers (Iron Resolve). Locks by id (`&"stun"`, `&"casting"`). | **Kept and extended.** Enemies keep the LoL attack. Combo mode for the player (`combo` export; C2, built). The player's LoL orders (right-click, attack-move) stay dormant. C4 (built): enemy attacks push (`hit_knockback_px`), reach 10% short of `attack_range` (`enemy_hit_forgiveness`) and whiff out of reach (`attack_whiffed`). |
| `Unit.take_damage(amount, source, highlight)` | Checks alive and invulnerable, lowers health, emits `damaged`, spawns a number, flashes. `Player.take_damage` adds a 2 px shake. Called by `AutoAttackComponent._land_attack`, `cleave.gd`, `lunge.gd`, `judgement.gd` and `Unit._on_hurtbox_hurt`. | **Wrapped** (C1, built): `make_hit_context()` builds a `HitContext` and `on_hit()` runs it from mitigation on. Armor is 0 everywhere, so nothing changes in play. `Player.take_damage`'s override is replaced by a `Player.on_hit` override with the same 2 px shake. |
| `res://scripts/components/hitbox.gd`, `hurtbox.gd` | Area2D damage on overlap. `player.tscn` and `slime.tscn` have a Hurtbox (0.2 s own invincibility); **no scene has a Hitbox**. | **Kept, dormant.** `Unit._on_hurtbox_hurt` builds a `HitContext` (C1, built; the push is `Hitbox.knockback` px/s × 0.12 s, as before), so a future contact-damage enemy or projectile goes through the pipeline. |
| `Unit.add_invulnerability(id)` | Dash i-frames (`&"dash"`) block `take_damage()` and Hurtbox hits. | **Kept.** `Unit.on_hit` checks it first. Post-hit i-frames add `&"hit_iframes"` (`Unit.HIT_IFRAMES_ID`; C4, built); `has_invulnerability(id)`. |
| `res://scripts/autoload/game_feel.gd` (`GameFeel`) | `hitstop(duration)`: `Engine.time_scale` 0.05 (`hitstop_time_scale`). `shake(amount)`: camera shake in px (the camera keeps the largest). | **Kept, extended** (C3, built): the longest hitstop wins (a later call that ends later extends the running one); `play_hit_feel(ctx)` plays a hit's tier from `hit_feel`; `is_hitstop_active()`, `get_hitstop_left()`. |
| `Unit._flash()` | Body modulate ×3, back to white over `hit_feel.flash_time` (0.12 s before C3). | **Kept**, retuned to 0.06 s for every hit (C3, built). |
| `res://scripts/ui/damage_number.gd` | Label: 2 sizes (10 / 13 px), orange when `highlight`, red on the player, rises 18 px over 0.6 s, fades 0.2 s. | **Kept**, restyled in C6. |
| `Unit.apply_stun()` + `res://scripts/vfx/stun_effect.gd` | A `StunEffect` child node holds `&"stun"` move and attack locks; re-stunning keeps the longer time. `is_stunned()` = has that node. | **Wrapped** (C9): creates `status_stun`; the stars become that status's VFX. |
| `MovementComponent.add_speed_modifier()` | Wrapper over `move_speed` StatModifiers; only the timer is on MovementComponent. | **Wrapped** (C9): timed modifiers become statuses; the timer moves to StatusComponent. |
| `MovementComponent.displace()` | A new displacement replaced the running one. | **Changed** (C4, built): the stronger displacement wins; `displace()` returns false when it's dropped. |
| `res://scripts/enemies/enemy.gd` | Wander, aggro, chase, attack. `passive` = training dummy. Aggro on `damaged`. | **Kept.** C5 (built): an enemy with an AbilityComponent (the elite) casts a ready ability when the player is within its `cast_range` and in sight, never mid-windup; a whiff still lunges (C4). |
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
  - `feel` (`LIGHT` / `HEAVY`)
  - `lunge_px` (6): melee swing step along the aim; `lunge_max_px` (24): the longest target-pull step. The dash-strike swing's step is its own `lunge_px` (16, C12).
  - `proc_coefficient` (1.0)
  - `pause_after` (0): seconds after this swing ends before the next can start (the finisher's breather)
- `AttackCombo` (Resource, `res://scripts/data/attack_combo.gd`): `attack_style` (`AttackCombo.AttackStyle.MELEE` default / `RANGED`), `swings: Array[AttackSwing]`, `combo_reset_time`, `dash_strike: AttackSwing` (null until C12), `hit_forgiveness` (0.10), `speed_scale` (1.0: one knob that scales every swing timing; × attack speed).
  - Melee assist: `assist_range_bonus_px` (40, added to the swing's reach), `assist_angle_deg` (35), `assist_snap_deg` (20), `stop_at_reach_fraction` (0.7).
  - Recovery: `walk_cancels_recovery` (true), `recovery_move_cancel_after` (0.1 s).
- Knight: `res://data/combos/combo_knight.tres` with the three swings from Numbers (0.08 / 0.3 s, 0.08 / 0.3 s, 0.08 / 0.4 s; 1.0 / 1.0 / 1.6; 110° / 110° / 140°; 6 / 6 / 20 px over 0.1 s; LIGHT / LIGHT / HEAVY; steps 6 / 6 / 10 px, pull up to 24 / 24 / 32 px; MELEE with the default assist and recovery settings).

### HitFeel (Resource, `res://scripts/data/hit_feel.gd`; `res://data/hit_feels/hit_feel_default.tres`)
The hit feel per tier (Numbers, "Feel per hit"), held by `GameFeel.hit_feel`: `light_hitstop` 0.03, `heavy_hitstop` 0.06, `kill_hitstop` 0.08 (s); `light_shake` 0, `heavy_shake` 2, `kill_shake` 3 (px); `flash_time` 0.06 s, `flash_modulate` (3, 3, 3). Built in C3.

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
- `res://scripts/autoload/events.gd`, autoload **`Events`** (C1, built). Signals (reserved names): `unit_hit(ctx: HitContext)`, `unit_damaged(ctx: HitContext)`, `unit_died(unit: Unit, ctx: HitContext)`; `status_applied(unit: Unit, status: StatusEffect)` and `status_removed(unit: Unit, status: StatusEffect)` come with C9 (the type doesn't exist yet). Existing local signals (`Unit.died`, `Unit.damaged`) stay.
- `res://scripts/combat/hit_pipeline.gd`, **`HitPipeline`** (static functions, C1).
  - `static func resolve(ctx: HitContext) -> HitContext`: stages 1–4 (base, stat scaling from the source's StatsComponent, `damage_increase`, crit), then `ctx.target.on_hit(ctx)`. A target without `on_hit()` = `blocked`. Built in C1: base and scaling; `damage_increase` and crit come in C8.
  - Helpers (C1): `get_scaled_damage(ctx)`, `get_mitigation_multiplier(resistance)`, `mitigate(amount, type, target_stats)`.
  - `static func basic_attack(source: Unit, target: Unit, swing: AttackSwing) -> HitContext` and `static func from_ability(caster: Unit, ability: Ability, target: Unit) -> HitContext`: builders that fill tags, type, ratios and feel.
- `Unit.on_hit(ctx: HitContext) -> void` (C1), the same method name interactables use (WORLD_INTERACTION.md). In order:
  1. `blocked` if not alive or invulnerable → return (nothing else happens).
  2. Mitigation by type, then × the target's `incoming_damage`.
  3. Shields (`StatusComponent.absorb_damage()`, C10), then `health.take_damage()`.
  4. Knockback (`movement.displace()`, even if a shield took all of it), then statuses.
  5. `damaged.emit()`, `Events.unit_hit`, `Events.unit_damaged` (when `taken_damage` > 0).
  6. On-hit (only `basic_attack` or `ability` hits, never `proc` or `dot`): `on_hit_damage` as a `proc` hit, `life_on_hit` and `resource_on_hit` × `proc_coefficient`, `life_steal` × `taken_damage` (basic attacks only, proposed).
  7. Death: `Events.unit_died(self, ctx)`; kill credit = `ctx.source`.
  8. Feel: `GameFeel.play_hit_feel(ctx)` (C3, built): the hit's tier (a kill uses the kill tier) sets the hitstop and shake; feel NONE plays nothing, so abilities and enemy basic attacks keep their own. Every hit that gets through flashes. The damage number comes in C6.
- `Unit.take_damage(amount, source, highlight)` stays, as a wrapper (built in C1 through `Unit.make_hit_context()`): a `HitContext` with `base_damage = amount`, PHYSICAL, `can_crit = false`, feel `NONE` (callers keep their own shake and hitstop), then `on_hit()` directly (the amount is already scaled). `Player`'s "got hit" shake moves to a `Player.on_hit` override so pipeline hits get it too.
- `res://scripts/components/status_component.gd`, **`StatusComponent`** (C9), a child of every Unit (`Unit.status_component`, optional so old scenes still load).
  - `apply_status(effect: StatusEffect, source: Unit, duration_override: float = -1.0) -> bool` (tenacity: × (1 − tenacity) for `cc`-tagged statuses only), `remove_status(id)`, `has_status(id)`, `has_tag(tag)`, `get_tags()`, `absorb_damage(amount) -> float`.
  - Signals `status_applied(effect)`, `status_removed(effect)`, re-emitted on Events.
  - Locks through the existing `add_move_lock` / `AutoAttackComponent.add_lock` ids. DoT ticks are `dot` hits through `HitPipeline`.
- `res://scripts/autoload/world_query.gd`, autoload **`WorldQuery`** (built early, with the melee target pull), with only `has_line_of_sight(from: Vector2, to: Vector2, mask = 1) -> bool` (world layer 1; units don't block it) for now. The rest of its API stays in WORLD_INTERACTION.md.
- `res://scripts/vfx/telegraph.gd`, **`Telegraph`** (Node2D, C5, built): `Telegraph.circle(anchor, center, radius, time, color)` draws a true circle (not squashed, so it matches the hit area) with a faint fill, an outline and a fill that grows until the hit; `finish()` flashes and frees it; `get_progress()`. It goes on the room's floor (a child of the room just before `Entities`, like the click marker), under every unit. `THREAT_COLOR` = orange-red (1, 0.35, 0.15). VFX only: the ability's own query decides the hit.

### Changes to existing scripts (additive)
- **AutoAttackComponent** (C2): `@export var combo: AttackCombo` (null = LoL mode).
  - Methods: `try_swing(direction: Vector2, dash_strike: bool = false) -> bool`, `can_swing()`, `is_swinging()`, `is_in_recovery()`, `cancel_swing()` (no hit, combo resets), `get_combo_index()`.
  - Signals: `swing_started(index, direction, swing)`, `swing_landed(index, targets)`, `swing_cancelled`, `swing_finished`.
  - A swing: move lock `&"attack_swing"` for `duration / speed`; the aim is locked at the start; at `windup / speed` it queries `AbilityUtil.in_cone()` from the feet with reach and arc × (1 + `hit_forgiveness`), keeps targets in line of sight, and runs `HitPipeline` on each.
  - Next-attack modifiers (Iron Resolve) are used up by the first swing that hits anything and apply to every target it hits.
  - `speed = attack_speed ÷ base attack_speed` (`StatsComponent.get_base_value(&"attack_speed")`). The combo index advances when a swing ends; `combo_reset_time` counts from the end of the swing's recovery.
  - `reset_attack_timer()` (`Ability.resets_auto_attack`) does nothing in combo mode.
  - Also built: `get_current_swing()`, `get_swing_speed()`, `get_swing_reach_px(swing)`. `add_lock()` (stun, casting) and `cancel()` (death) cancel a swing. Swing timers don't count the physics frame the swing started in, and treat ≤ 0.0001 s as done, so a 0.3 s swing is exactly 18 frames.
  - An attack press also drops a queued walk-into-range cast (R), like the dash does.
- **PlayerInput** (C2): `attack_pressed` → `player.attack.try_swing(player.get_aim_direction(), dash_strike)`.
  - Attack is legal when not stunned, casting, dashing or swinging.
  - An ability press during a swing is legal only if its `cancels_swing` allows it at that moment (then the swing is cancelled first).
  - The buffer timer also pauses while a swing plays out, so a press early in a 0.3 s swing isn't lost after 0.15 s.
- **DashComponent** (C2): `try_dash()` cancels a swing in windup or recovery (not on the hit frame; the hit resolves inside one physics frame, so there's nothing to cancel).
- **Player** (C2): facing = the swing's aim, locked at swing start (the slot "attack windup" had); `State.ATTACK` = the whole swing. `can_interrupt_swing(slot)` applies `cancels_swing` for both `request_cast()` and the buffer. Swing visuals: the sword pulls back during the windup and a slash the size of the swing's reach and arc plays at the hit (brighter and longer on the finisher).
- **Input map** (C2): `select` loses its left mouse binding (the action and the attack-move code stay).
- **Melee basic attacks** (built after C2):
  - **AutoAttackComponent:** at swing start a MELEE combo picks the aimed enemy (`get_assist_target()`), snaps the aim and starts the step: `movement.displace(..., step_curve, dash_cancelable = true)` over the windup (÷ combo speed). `step_curve` export = `curve_dash.tres`. `cancel_swing()` ends the step only if it's still the running displacement (`get_displacement_serial()`); a knockback or dash that replaced it stays. `is_swing_rooted()`: swinging and walking hasn't ended the root. `debug_draw`: the assist cone (grey), the snapped aim (white), the aimed enemy (red) and the planned step (yellow), on a child Node2D of the unit.
  - **MovementComponent:** `displace(velocity, duration, curve = null, dash_cancelable = false)`, `is_displacement_dash_cancelable()`, `get_displacement_serial()`, `stop_displacement()` (for a caller's own displacement; no `displacement_finished`).
  - **DashComponent:** `can_dash()` allows a dash during a dash-cancelable displacement; the dash replaces it.
  - **Player:** a rooted swing shows `State.ATTACK` over DISPLACED (its step is a displacement), and facing follows the swing while it roots. Once walking ends the root, state and facing follow walking.
  - The movement VFX knockback stretch also plays on the step (it reads as a lunge).
- **GameFeel** (C3, built): `hitstop()` keeps one end time in real time (`Time.get_ticks_msec()`); a new call only extends it if it ends later. `play_hit_feel(ctx)` picks the tier; `hit_feel` and `hitstop_time_scale` are exports.
- **MovementComponent** (C4, built): `displace()` is dropped (returns false) if the running displacement still has more distance to cover than the new one's whole distance (`get_displacement_remaining_px()`). `dash()` always replaces. A melee swing step dropped this way has nothing to stop when the swing is cancelled.
- **AutoAttackComponent, LoL mode** (C4, built): `hit_knockback_px` (slime 12) and `hit_knockback_duration` (0.1 s). `enemy_hit_forgiveness` (0.10): `is_in_range()` uses `attack_range × (1 − forgiveness)`, so the windup starts, and the hit lands, only within it; out of reach when the windup ends = a whiff (`attack_whiffed(target)`; no damage, the attack timer still runs; slimes still lunge). The hit goes through `make_hit_context()` + `on_hit()`; a blocked hit skips next-attack on-hit effects.
- **Unit** (C4, built): `@export var post_hit_iframes: float` (0 = none; `player.tscn` 0.5). A hit that gets through adds `&"hit_iframes"` for that long in game time (it follows hitstop and pausing); DoT ticks don't start it. **Player** blinks while it lasts (`hit_iframes_blink_period` 0.1 s; visual only).
- **Unit / MovementComponent** (C4, built): every knockback from `Unit.on_hit` uses `displace(..., dash_cancelable = true)`, so a unit that can dash (the player) dashes out of it at once. Any other displacement still blocks the dash.
- **Enemy** (C5, built): `_try_cast_ability()` in AGGRO: for each ready slot (q, w, e, r), cast at the player's position if the player is within `cast_range` of the enemy's center and in sight, and the enemy isn't mid-windup. The cast time is the telegraph; the cast roots it (and a stun at the end of the cast time interrupts it, as for every ability).
- **Ability / CastContext / AbilityComponent** (C5, built): `Ability.on_cast_started(caster, ctx)` (virtual, called right after `cast_started`) lets an ability show a telegraph during its cast time; it sets `CastContext.telegraph`, and AbilityComponent frees it if the cast is cancelled (dash, move) or interrupted (stun, death).
- **Elite slam** (`res://scripts/abilities/slime/slam.gd`, `res://data/abilities/slime_elite_q_slam.tres`, C5): POINT at the player's position at cast start (cast_range 250 u = 80 px), 0.75 s cast (the telegraph), 40 px circle (hit radius × 0.9, enemy forgiveness), 100 PHYSICAL through `HitPipeline.from_ability()`, 20 px push away from the elite, its own hitstop 0.06 s and 3 px shake when it lands, 4 s cooldown.

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
| Melee: target moves or dies during the step | The step's end point is planned at swing start (velocity × windup); it keeps going there. Nothing re-targets; the hit cone at the hit moment takes whoever is there. |
| Melee: several enemies in the assist cone | Smallest angle off the aim wins, then the nearer one. |
| Melee: wall or pillar in the way | `WorldQuery.has_line_of_sight()` rules out enemies behind walls (no pull, no snap). The step itself is a `displace()`: it slides along a wall at an angle and stops on a head-on one. |
| Melee: step would end inside an enemy | The planned step is clamped to the gap between the two units' pathing radii; the unit bodies also collide, so the step stops at its edge and never pushes it. |
| Knockback on the player | The 12 px push (~0.1 s) is a hit knockback: walking waits for it, but a dash replaces it at once (i-frames as usual). Other displacements (Lunge, pulls, knockback from anything but being hit) still block the dash; a press then is buffered and fires as they end. |

## Build order (one step per request)
Combat starts now, before STATS step 6. Until step 6 adds `id` / `tags` to Ability, hits carry no ability tags. STATS step 6 runs before C8 (C8's `hit:<tag>` scopes need scoped modifiers); STATS step 7 (the F3 overlay) comes after M1.

1. **C1 – Hit pipeline.** `Events`, `HitContext`, `HitPipeline`, `Unit.on_hit`; `take_damage()` and `_on_hurtbox_hurt` wrapped; `damage_type` and `proc_coefficient` on Ability. A test scene `res://scenes/tests/combat_test.tscn` (script in `scripts/tests/`).
   **Done means:** the test passes: mitigation for all three types at 0 / 100 armor, i-frames block everything, the events fire (`incoming_damage` is checked in C8, where the stat is added). In play nothing changes: abilities deal the same numbers and slimes chase and hit as before.
   **Built** (awaiting play test): `combat_test.tscn` 50/50; stats test 143/143; a headless in-game check in the sandbox 11/11 (Cleave 124.8, Lunge 82, Judgement's damage and stun, Iron Resolve's haste, a slime chasing and hitting for 22 through `Events.unit_hit`, i-frames, the HUD); room_01 runs with no errors.
2. **C2 – Knight combo.** `AttackSwing`, `AttackCombo`, `combo_knight.tres`, the combo mode, PlayerInput/Dash/Player changes, `cancels_swing`, `select` unbound, Iron Resolve through swings.
   **Done means:**
   - A click swings toward the cursor within 0.08 s; three clicks give the three swings (the third wider and stronger); 0.6 s without attacking resets the combo.
   - Each swing roots; a dash during windup or recovery cancels it and resets the combo.
   - A click during a swing queues the next one; Q during a swing's windup waits for the hit, then cuts the recovery (AFTER_HIT).
   - Iron Resolve's next swing slows every slime it hits; a stun mid-swing cancels it.
   - The Knight's abilities, enemies chasing and the HUD still work.
   **Built** (awaiting play test): combat test 109/109 (59 new C2 checks: hit 5 frames after the click, swing 18 frames, 64 / 64 / 102.4 damage, the finisher's 20 px push, reach 70 / 78 px hit and 82 px miss, arc, reset after 0.6 s, a click 1 frame into a swing starts swing 2 right as it ends, dash / stun / Q / death cancels, Iron Resolve on two slimes, +50% attack speed = 12-frame swings); stats test 143/143; headless in-game check 15/15 (a real left click swings and hits for 64; the Knight's abilities, slimes chasing and hitting, i-frames and the HUD unchanged); room_01 runs with no errors.
- **Melee basic attacks** (between C2 and C3): swing step, target pull with aim snap, walk-cancel of the recovery, `attack_style`, minimal `WorldQuery`.
   **Done means:** swinging at empty air moves the Knight forward a few px per swing; aiming roughly at a slime from a bit outside reach pulls the Knight in and the swing connects; aiming 60° away doesn't pull; a slime behind the pillar is never pulled toward; after a swing lands, a direction starts walking almost at once and the next click continues the combo; setting the Knight's combo to RANGED turns off the step, pull and snap (walk-cancel still works); enemies attack exactly as before; the dash, the Knight's 4 abilities and the HUD still work.
   **Built** (awaiting play test): combat test 153/153 (44 new checks: steps 6 / 6 / 10 px in the air, a slime 15° off and 95 px away aimed at with the aim snapped onto it, a capped 24 px pull that connects, a stretched 18.2 px step ending at 39.2 px, 6 px when already close, stopping at a touching slime's edge, no pull at 60°, a 20° max snap at 30°, the aim-line pick of two, no pull through a wall, dash and stun during the step, the root ending 6 frames after the hit with the combo continuing, RANGED); stats test 143/143; headless in-game check 21/21 (a real click 12° off a slime 97 px away pulls 24 px and connects; the sandbox's own pillar blocks the pull; enemies, abilities, i-frames and the HUD unchanged); room_01 runs with no errors.
3. **C3 – Hit feel.** Feel tiers from `HitContext.feel` (light / heavy / kill), longest-wins hitstop, 0.06 s flash, shake per tier.
   **Done means:** swings 1–2 freeze briefly with no shake; the finisher and kills freeze longer and shake; abilities feel as before.
   **Built** (awaiting play test): combat test 173/173 (20 new C3 checks: the tier numbers; overlapping hitstops 0.03 → 0.08 → 0.02 end at 0.08 s; swings 1–2 freeze 0.03 s with no shake, the finisher 0.06 s with a 2 px shake, a kill 0.08 s with 3 px, a whiff nothing; `take_damage()` hits and a blocked hit play no feel; Cleave shakes only its own 3 px; the flash is white at the hit and gone after 0.06 s). The C2 swing-length check now measures game time, since a hit's hitstop adds physics frames but almost no game time. Stats test 143/143; headless in-game check 21/21; room_01 runs with no errors.
4. **C4 – Getting hit.** Post-hit i-frames, 12 px knockback on the player (marked as hit knockback, which a dash replaces), enemy whiffs out of reach, stronger-knockback-wins, slime windup retuned into 0–0.3 s.
   **Done means:** walking out of a slime's lunge avoids it; three slimes hitting at once cost one hit; after a hit the player is safe for 0.5 s (visible); a hit pushes the player 12 px, and pressing dash during the push dashes at once.
   **Built** (awaiting play test): combat test 205/205 (32 new C4 checks: the numbers; the first of two same-frame hits lands and the second is blocked; i-frames last 0.5 s and the Knight blinks; a DoT tick starts none; a slime winds up 0.25 s, hits for 22 and pushes 12 px away; the push is dash-cancelable and a dash replaces it; teleporting out of reach mid-windup is a whiff; a 6 px push during a 20 px one is dropped, a 30 px one replaces a 6 px one; a swing during a stronger knockback leaves it alone); stats test 143/143; headless in-game check 27/27 (the real slime AI hits, pushes 12 px and starts 0.5 s of i-frames; walking away with a real key press during its windup makes it miss); room_01 runs with no errors.
5. **C5 – Elite.** `slime_elite.tscn` (inherits `slime.tscn`) + `data/units/slime_elite.tres` (starting values: 900 health, 100 damage = 15% of the Knight's 650), a telegraphed slam ability (0.75 s telegraph, about 40 px circle), `Telegraph`, the Enemy cast hook, one elite in the sandbox.
   **Done means:** the elite shows a filling floor circle before each slam; dashing or walking out avoids it; standing in it costs about 15% health.
   **Built** (awaiting play test): `scenes/enemies/slime_elite.tscn` (inherits `slime.tscn`: purple, ×1.4 body, 19 px collider, AbilityComponent with the slam) + `data/units/slime_elite.tres` (900 health, 30 basic attack damage = 4.6% (swarm band) with a 0.25 s windup, 260 move speed); `Elite1` in the sandbox's open top-right corner (784, 112). Combat test 225/225 (20 new C5 checks: the numbers; a telegraph where the Knight stands, half full at 0.37 s; 100 damage and a 20 px push at 0.75 s; the telegraph gone after; walking and dashing out; a stunned elite's slam doesn't go off, its telegraph is removed and its cooldown refunded; the elite AI casting the slam by itself). Stats test 143/143; headless in-game check 33/33 (the sandbox elite casts at the real player, its telegraph is on the room floor under the units, standing in it costs 100, walking out with a real key press avoids it); room_01 and the sandbox run with no errors.
6. **C6 – Damage numbers.** 3 log-scale size steps, crit style (placeholder until the font), colors by type, the player's damage red, healing green, DoT merge, rise 12 px / fade 0.6 s.
   **Done means:** finisher numbers are visibly bigger than swings 1–2; the player's damage shows red; nothing overlaps unreadably with 5 slimes.
7. **C7 – Line of sight.** The filter in swing hits and `AbilityUtil`, `ignores_walls` on Ability (`WorldQuery.has_line_of_sight()` already exists, built with the melee pull).
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
- Weapons: a champion's combo will come from its equipped weapon, and its class limits which weapons it can wield (e.g. a bruiser like Darus can't use daggers); bruiser weapons are heavier, diver and rogue weapons snappier. Today the combo is set on AutoAttackComponent (LOOT.md / CHAMPIONS.md).
- A stun during a cast interrupts it only if the caster is still stunned when the cast time ends (AbilityComponent checks then), though its header says "during the cast time". A short stun mid-cast lets the cast go off. Decide in ABILITIES.md.
- Ranged basic attacks: design later (RANGED combos only get walk-cancel for now).
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
