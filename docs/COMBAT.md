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
- Left mouse = an aimed basic attack toward the cursor (Hades-style): a combo of swings; the last one is the finisher. The Knight's is 3 hits; the number of swings is per champion (2, 3, 5...), all data (`AttackCombo.swings`). The Knight's current pace reads as a rogue or diver (M1).
- Every swing roots the attacker for its duration (see Numbers). Melee swings still step during the root, and walking can end the recovery early (Melee basic attacks, below).
- A dash cancels a swing before its hit lands (windup) or during its recovery. The moment the hit lands can't be cancelled.
- A swing counts once its hit has landed (Ryan, 2026-09-27). A cancel the player chooses after the hit (walking out of the recovery, a dash, an ability that cuts the recovery: `cancels_swing` AFTER_HIT or ANYTIME) keeps the combo: the index advances as if the swing had finished, and `combo_reset_time` counts from the cancel (walking doesn't cancel the swing, so there it counts from the swing's end). A finisher cancelled after its hit still gets its breather (`pause_after`); the next swing is swing 1. A cancel during the windup (before the hit) and forced interruptions (stun, death) reset the combo.
- Pressing attack during a swing queues the next combo hit (input buffer). Each swing needs its own press; holding the button doesn't repeat. The combo resets after combo_reset_time with no attack.
- Q/W/E/R interrupt a swing only if that ability allows it, set per ability: never, after the hit lands (the default; all four Knight abilities), or anytime. Otherwise the press waits for the swing to end (input buffer).
- attack_speed is a combo-speed multiplier for the player: every swing timing is divided by attack_speed ÷ base attack speed (1.0 at base; +20% bonus attack speed = swings 20% faster), times the combo's `speed_scale`.
- Attack pace comes from the swings themselves, not a cooldown: the next swing starts when the current one ends, plus that swing's `pause_after` (a breather, e.g. after a finisher, like Hades' sword). Only attacking waits during it; moving, dashing and abilities don't, and a click during it fires when it ends. There's no global cooldown between attacks and abilities.
- Dash-strike: an attack pressed during a dash, or within `dash_strike_window` (0.15 s) after it ends, is the combo's `dash_strike` swing: its own strong swing, the same every time (Hades' sword), defined per champion. It doesn't count as a combo hit: the combo index and the reset timer are kept, so the next click continues the combo where it was. How strong it is depends on the champion's class (CHAMPIONS.md). (Ryan, 2026-09-27.)
- attack vs select on left mouse: attack owns left mouse. The LoL `select` action was disabled at C2 and deleted 2026-09-29 with the rest of the LoL input (MOVEMENT.md).
- "Your next attack" effects (Iron Resolve) mean the next basic attack swing that hits, and they apply to every enemy that swing hits.

#### Melee basic attacks
The rule for every combo with `attack_style` MELEE (the default; the Knight is the first). Any future melee champion gets it by having a combo, with no new code. RANGED combos get none of 1–2 (ranged basic attacks are designed later); 3 applies to both. Enemies (League-style attacks) are unchanged.
1. **Swing step:** every swing moves the attacker forward along its aim during its windup, by the swing's `lunge_px`. It's a `displace()` with the dash curve (ease-out), so it follows the displacement rules: it moves the attacker through the swing's root, slides along walls (a head-on wall stops it), is stopped by unit bodies and never pushes enemies or passes through them. A dash during the step replaces it; a stun (or anything else that cancels the swing) ends it.
2. **Target pull** (only when aiming at an enemy): at swing start, the aimed enemy is the one whose edge is within reach + `assist_range_bonus_px` of the attacker's feet and within `assist_angle_deg` of the aim, in line of sight (WorldQuery). The smallest angle off the aim wins; ties go to the nearer one. If there is one:
   - **Aim snap:** the swing's aim turns toward it by up to `assist_snap_deg`. Facing and the hit cone use the snapped aim.
   - The step goes toward it instead of along the aim, and stretches so the swing ends with its edge at `stop_at_reach_fraction` × reach, capped at the swing's `lunge_max_px`. If it's already closer than that, the step is just `lunge_px`, and never goes into its body (it stops at its edge).
   - Nothing aimed at: the plain `lunge_px` step along the aim.
3. **Walking cuts recovery** (`walk_cancels_recovery`): after the hit, a movement press or a held direction ends the rest of the root once `recovery_move_cancel_after` has passed since the hit. The swing still runs out its duration, so the next swing waits for it (walking never attacks faster than standing) and the combo index is kept: walk → swing → walk → swing still reaches the finisher within `combo_reset_time`. A dash still cancels the recovery at any time (after the hit the combo moves on, as above).

### Hits
- Every application of damage or effects is one Hit, described by a HitContext. In new code all damage goes through the hit pipeline; existing direct take_damage() calls get wrapped, not rewritten.
- Pipeline order: base → stat scaling (ratios) → conditional damage ("increased" by hit tags, `damage_increase`) → crit → mitigation (armor / magic_resist) → incoming_damage ("more": each reduction multiplies separately) → shields → health. "Raw damage" = before mitigation; "damage taken" = after.
- Crits use PRD (pseudo-random distribution, as in League and Dota): the Nth roll since the attacker's last crit crits with chance C × N, where C is picked so the average is exactly `crit_chance` (25% → C 0.0847: 8.5%, 17%, 25%... a crit at the latest on the 12th roll). One roll per swing or ability cast: every enemy it hits crits, or none does, and the counter moves once. Ryan's call (2026-09-26).
- Damage types: PHYSICAL (armor), MAGIC (magic_resist), TRUE (ignores both). Proposed mitigation: damage × 100 / (100 + armor).
- Negative armor and magic_resist (core rule, built since C1): the multiplier is LoL's 2 − 100 / (100 − r) (−100 → × 1.5), so it never divides by zero (`HitPipeline.get_mitigation_multiplier()`; STATS.md).
- Invulnerability (dash i-frames, post-hit i-frames) blocks the whole hit: damage, knockback, statuses and on-hit.
- Hit tags: basic_attack, ability, proc, dot, crit, the damage type, plus the source ability's tags. Planned with the 3D terrain (3D.md, P9): `melee`, added to MELEE combo swings and abilities tagged `melee` (the Knight's Cleave and Lunge; not Judgement or Cleave Wave). Planned with Korsavil (CHAMPIONS.md, designed 2026-10-04): `finisher`, added to the hits of a combo's last swing (`AttackSwing.hit_tags`), which her detonation's HIT rule reads.
- **Elevated targets (built in 3D pivot P9, 3D.md, Terrain and height 2):** hits use 2D distance whatever the terrain, so melee reaches an enemy at a plateau's edge. The one exception: a target tagged `elevated` (standing on a perch) can't be hit by a `melee` hit unless the attacker is `elevated` too. `AbilityUtil.can_reach()` decides it, in target picks and in `HitPipeline.resolve()` (the last guard: the hit is blocked); never inside abilities.
- On-hit: basic attack and ability hits trigger on-hit effects; dot ticks and proc hits never do (loop guard). Each Ability has proc_coefficient (1.0 default, lower for multi-hit or area abilities), which scales on-hit chances and effects. Numbers (on_hit_damage, life_on_hit, resource_on_hit) are stats (STATS.md); behaviors are augments or ReactionRules. On-hit damage is a separate MAGIC proc hit *(proposed)*.
- Events: every hit emits Events.unit_hit(ctx), damage emits unit_damaged(ctx), death emits unit_died(unit, ctx). Reserved names only (CONVENTIONS.md).
- Line of sight: basic attacks never hit through walls. Abilities don't either, unless the ability is marked to ignore walls (e.g. a meteor shower).

### Enemies
- Two kinds of threat: swarms (small chip hits, short or no telegraph) and elites/bosses (big, telegraphed hits). Any enemy attack above the trash damage band has a floor telegraph.
- How fast the player dies is set per enemy, by its damage band (see Numbers).
- Enemy attacks can be walked out of: a hit lands only if the target is still in reach at the moment of the hit.
- **How enemies fight** is ENEMIES_AI.md's (written 2026-10-03; Ryan's decisions): ranks (fodder, regular, elite, boss) and roles (fodder, brute, skirmisher, caster). Fodder is the swarm above; regulars (brutes, skirmishers, casters with 1–2 abilities) sit between the two kinds of threat. **The damage bands don't change** *(proposed there)*: a regular's basic attack sits in the swarm chip band, and any ability of its above that band is telegraphed, in the elite band's lower part.
- **Tells come before telegraphs** (ENEMIES_AI.md, Tells): every smart enemy decision (a dive, a punish, raising a shield) shows as a pose before it acts, body language only, no icons; the attack's floor telegraph follows as this doc says.
- **Enemies that dodge** (ENEMIES_AI.md, Dodging): elites and bosses may sidestep a dodgeable attack (a skillshot, a charge-up, a VECTOR line, a slow area) after a reaction time, with a cooldown, never while casting or crowd-controlled. It's a visible move, not a "random dodge chance": a hit that lands always counts (References, Diablo). UNIT-targeted abilities and fast casts are never dodged.
- **Punishes and finishers** (ENEMIES_AI.md, Bosses): a boss's attack on a whiff or a low target is telegraphed for at least 0.6 s and can be left with one dash *(proposed there)*: a dash always answers it.

### Status effects
- One system: StatusComponent plus StatusEffect Resources. Crowd control = statuses tagged cc (stun, root, silence, slow). `Unit.apply_stun()` and `add_speed_modifier()` are thin wrappers that create statuses.
- Refresh or stack is decided per StatusEffect (data).
- tenacity shortens crowd control duration; it doesn't affect damage over time. **Except airborne** (planned): a knock-up's duration isn't shortened (`ignores_tenacity`), so its arc keeps its shape.
- **Airborne** (built in 3D pivot P9, 3D.md, Terrain and height 1a): `status_airborne` (tags `cc`, `airborne`, `debuff`) blocks moving, attacking, casting and dashing, REFRESH_LONGER, its duration from the hit. I-frames block it (they block the whole hit); being airborne gives no i-frames (juggles). A cleanse and unstoppable don't end it (`cleansable` false; Ryan, 2026-10-01), though unstoppable refuses a new one. Its knockback can't be dash-cancelled (airborne blocks the dash). While airborne and displaced, a unit's mask drops layers 6, 7 and 11 (pits, low obstacles, ledges). **Enemies don't knock up the player in v1.** The model's rise and fall is view-only.
- DoT kill credit goes to whoever applied the status.
- A status that blocks casting (stun, silence) applied during a cast time or a charge-up interrupts the cast at once, refunding its cost and cooldown (ABILITIES.md, Casting).
- **Unstoppable** (status tag `unstoppable`): immune to new cc, and applying it removes every cc status; it also blocks knockback from hits and `KnockbackGameplayEffect` (not the unit's own dashes and swing steps). ABILITIES.md.
- **Untargetable** (status tag `untargetable`): `Unit.on_hit()` blocks every new hit except damage-over-time ticks (a DoT applied before keeps ticking, the League rule), statuses from other units are refused, and `Unit.is_targetable()` is false, so targeting, projectiles and aggro skip the unit (aggroed enemies keep chasing without attacking). ABILITIES.md.
- **Empowers** ("your next attack / next ability") are statuses tagged `empower` whose bonus HitPipeline adds into the hit (`HitPipeline.add_empowers()`, hit tag `empowered`; ABILITIES.md, Empowers). Iron Resolve's is one (`empower_iron_resolve`).
- **Fear** (Ryan, 2026-10-04, from Korsavil's Umbral Stalker; planned, not built): `status_fear` (tags `cc`, `fear`, `debuff`): the unit walks away from the status's source and can't act (it blocks attacking, casting and dashing, and takes over walking instead of blocking it). Being `cc`, tenacity shortens it, unstoppable refuses it and a `cc` cleanse removes it. **Bosses ignore it** (Ryan): *(proposed)* through a new `StatusEffect.refused_by_tags` (the status isn't applied to a unit carrying any of them) and a permanent status tagged `boss` that ENEMIES_AI's rank rules give every boss. The flee itself and what the brain does meanwhile are ENEMIES_AI.md's (Fear). *(proposed)* Enemies don't fear the player in v1, as with knock-ups. Spec: ABILITIES.md, Later toolkit pieces (the fear status).

### Sustain
- Every champion starts with zero sustain (health_regen 0). Healing comes only from build choices: abilities, passives and items (life on hit, life steal, regen).
- A kit heal tied to one ability (`Ability.heal_on_hit_ratio`, CHAMPIONS CH5, and `Ability.heal_missing_health_ratio`, CH5b: the Knight's Cleave) doesn't break this: it's not a stat, no champion has it by default, and it's earned by landing that ability (CHAMPIONS.md, Sustain). Every heal goes through `Unit.heal()` (clamped to max health, no overheal, a green number only for what was healed).

### Damage numbers
- Every hit shows a number above the target.
- Crits use a distinct font (proposed) and are larger.
- DoT ticks use a smaller style and are merged per target over a short window so they don't flood the screen.
- **Hits in a row stack** (Ryan, 2026-10-03; revisited with UI.md): a unit's new number starts `stack_step_px` (11) above its previous number while that one still shows (its `lifetime`), up to `stack_levels` (4) high, then at the bottom again. Equal hits (a combo's swings) read as a rising column, not one number drawn twice. The same in 2D and on the 3D overlay (`Unit._stack_lift()`).
- Size grows with the amount, in a few discrete pixel-font steps on a log scale, so late-game numbers don't all hit max size.
- Colors: by damage type (FREE, but readable); damage the player takes is red; healing is green; damage a shield absorbed is its own silver-blue number.
- **In 3D (3D.md, P7; built 2026-10-03):** numbers and health bars draw on the screen overlay (`ScreenOverlay`), placed above the unit's model with `unproject_position()`; their sizes are screen sizes, as today. `Unit._add_number()` gets the overlay path while the 2D path stays.

### In the 3D view (3D.md; the view never changes gameplay state)
- **Telegraphs** stay exact circles and bands on the floor: `FloorOverlay` draws them (built in P7: a slam's outline lies on its sim circle within 0.4 screen px), and the floor's shader shows them on slopes. Seen through the tilted camera a circle looks like an ellipse, but it covers exactly the hit area (P0a: within the measurement's resolution on a ramp).
- **Hit flash:** the model's material flashes white for `UnitView.flash_time` on `damaged`, instead of the Body's modulate. The 2D flash and `HitFeel.flash_time` / `flash_modulate` were deleted in the 3D pivot's cleanup C3.
- **Shake:** `GameFeel.shake()` keeps its numbers (screen px); `GameCamera3D` turns them into a camera offset.

## Numbers (TARGET: start, range)
Knight basic attack:
- windup (click to hit): 0.08 s (0.05–0.12)
- root per swing: 0.3 s (0.2–0.35); finisher 0.4 s (0.3–0.5)
- combo_reset_time: 0.6 s (0.4–0.9)
- breather after the finisher (`pause_after`): 0.25 s (0–0.4); none after swings 1–2
- `speed_scale` 1.266 (Ryan's tuning; every timing above is before it: each is ÷ 1.266, so a 0.3 s swing takes 0.237 s = 15 frames)
- Per-champion pace (FREE per champion, decided in CHAMPIONS.md): bruisers heavier (e.g. ~1.4 s for 3 hits), divers and rogues snappier (~0.75 s); the Knight's combo takes 1.0 s + the 0.25 s breather before `speed_scale`, about 0.79 s + 0.2 s at 1.266
- damage: 1.0 / 1.0 / 1.6 × attack_damage
- reach: 175 u (56 px) from the Knight's feet to the target's edge; arc 110°; finisher arc 140°
- knockback: 6 / 6 / 20 px, using the knockback curve
- dash-strike (the Knight's; other champions by class, CHAMPIONS.md): 1.5 × attack_damage (1.2–2.0), a 16 px step (0–24; pull up to 32), heavy feel, a thrust: 80° arc (60–110), reach × 1.15 (1.0–1.3), 0.35 s (0.3–0.45), 16 px push (6–24), no breather

Melee basic attacks (the class defaults; the Knight's combo uses them):
- swing step `lunge_px`: 6 / 6 / 10 px for swings 1 / 2 / 3 (0–12)
- `lunge_max_px`: 24 / 24 / 32 px (0–40)
- assist range: reach + 40 px (`assist_range_bonus_px` 40; reach + 0–64)
- `assist_angle_deg`: 35° (0–45)
- `assist_snap_deg`: 20° (0–30)
- `stop_at_reach_fraction`: 0.7 (0.5–0.9); for the Knight the pull ends with the enemy's edge 39 px from his feet
- `recovery_move_cancel_after`: 0.1 s (0–0.2)

Crit multiplier: 1.75 (the `crit_damage` default for every unit). Crit chance is rolled with PRD, one roll per swing or cast (Rules, Hits).

Feel per hit (basic attacks, and the default for other hits; abilities set their own):
- hitstop: light 0.03 s (0–0.05); finisher/heavy 0.06 s (0.04–0.08); kill 0.08 s (0.05–0.10). Overlapping hitstops don't stack: take the longest.
- shake: light 0; heavy 2 px; kill 3 px (0–4)
- hit flash: white, 0.06 s

Player getting hit:
- post-hit i-frames: 0.3 s (0.3–0.8; was 0.5 s until M1), starting from the first hit in a frame (the other hits in that frame are blocked). DoT ticks don't start them.
- knockback on the player: 12 px (0–24); no loss of control beyond the push itself

Enemy damage bands (per hit, as % of the player's max health; a tuning guide for each enemy's damage number, not a formula in-game):
- swarm chip: 2–5%, telegraph 0–0.3 s. Slimes: 22 damage (3.4% of the Knight's 650), 0.25 s windup (`attack_windup` 0.175 at 0.7 attack speed; was 0.5 s), 12 px push
- elite: 12–20%, telegraph 0.6–0.9 s. Elite slime slam (a test elite): 100 (15.4% of the Knight's 650), 0.65 s telegraph, 72 px circle, 20 px push (was 0.75 s / 40 px until M1: too easy to walk out of); its basic attack is 30 (4.6%), no telegraph
- boss big hit: 25–40%, telegraph 0.9 s or more
- Telegraph: a floor shape that fills up until the hit; one consistent enemy-threat color (FREE which).

Hit forgiveness: player attack hitboxes +10% over their visuals, enemy attack hitboxes −10% (each 0–20%).
Damage numbers: rise 12 px and fade over 0.6 s; 3 size steps; hits in a row stack 11 px apart, up to 4 high.

## Current code
What exists today (the rest of the design is in Data and Architecture).

| Code | What it does now |
|---|---|
| `res://scripts/components/auto_attack_component.gd` (`AutoAttackComponent`, `Unit.attack`) | **Kept and extended.** Enemies: LoL basic attacks (chase a target, windup with move lock `&"attack_windup"`, the hit through `make_attack_context()` + `HitPipeline.resolve()` since 2026-09-29, a whiff out of reach, a push; the backswing doesn't lock movement). The player: combo mode (`combo` export). Locks by id (`&"stun"`, `&"casting"`) cancel a windup or swing. Next-attack effects are empower statuses (ABILITIES.md). The player's LoL orders (right-click, attack-move) were deleted 2026-09-29. |
| `Unit.take_damage(amount, source)` | **Wrapped:** `make_hit_context()` builds a `HitContext` and `on_hit()` runs it from mitigation on. No gameplay code calls it any more (abilities use `HitPipeline.from_ability()` / `Ability.hit_units()`; the League-style enemy attack uses `HitPipeline.resolve()`; `_on_hurtbox_hurt` uses `make_hit_context()` + `on_hit()` directly); tests do. `Player.on_hit` adds a 2 px shake. |
| `res://scripts/components/hitbox.gd`, `hurtbox.gd` | **Kept, dormant.** Area2D damage on overlap. `player.tscn` and `slime.tscn` have a Hurtbox (0.2 s own invincibility); no scene has a Hitbox. `Unit._on_hurtbox_hurt` builds a `HitContext` (the push is `Hitbox.knockback` px/s × 0.12 s), so a future contact-damage enemy or projectile goes through the pipeline. |
| `Unit.add_invulnerability(id)` | **Kept.** Dash i-frames (`&"dash"`) and post-hit i-frames (`&"hit_iframes"`, `Unit.HIT_IFRAMES_ID`) block the hit; `Unit.on_hit` checks it first. `has_invulnerability(id)`. |
| `res://scripts/autoload/game_feel.gd` (`GameFeel`) | **Kept, extended.** `hitstop(duration)`: `Engine.time_scale` 0.05 (`hitstop_time_scale`); the longest wins. `shake(amount)`: camera shake in px (the camera keeps the largest). `play_hit_feel(ctx)`, `is_hitstop_active()`, `get_hitstop_left()`. |
| `Unit._flash()` | **Kept**, then **deleted** in the 3D pivot's cleanup C3 (2026-10-03): it was Body modulate ×3, back to white over `hit_feel.flash_time` (0.06 s) on every hit; the 3D model flashes instead (`UnitView`, on `damaged`). |
| `res://scripts/ui/damage_number.gd` | **Restyled:** look and motion from a `DamageNumberStyle`; kinds DAMAGE / CRIT / DOT / HEAL / SHIELD; `add_amount()` merges DoT ticks. The pre-C6 path (`Unit._spawn_damage_number()` and the number's `big` field) was deleted 2026-09-28. |
| `Unit.apply_stun()` | **Wrapped:** `apply_stun(duration, source = null)` applies `status_stun` (tenacity shortens it); its stars are `scenes/vfx/stun_stars.tscn`, that status's VFX. `is_stunned()` = any status tagged `stun`. The pre-C9 `StunEffect` fallback was deleted 2026-09-29: a unit without a StatusComponent can't be stunned (every Unit scene has one). |
| `MovementComponent.add_speed_modifier()` | **Wrapped:** with a StatusComponent each call applies a copy of `status_slow` (any negative part) or `status_haste` with that id, those `move_speed` modifiers (source `&"status_<id>"`) and that duration (−1 = until removed), REFRESH (the same id replaces); `remove_speed_modifier(id)` removes it. Without one, the old path (StatModifiers, its own timer) runs; the stats test uses it. |
| `MovementComponent.displace()` | **Changed:** the stronger displacement wins; `displace()` returns false when it's dropped. |
| `res://scripts/enemies/enemy.gd` | **Kept.** Wander, aggro (also on `damaged`), chase, attack. `passive` = training dummy. An enemy with an AbilityComponent (the elite) casts a ready ability (Architecture, Enemy), skipping slots that can't be cast (a failing condition, a cost); an untargetable player is chased without attacking (ABILITIES.md). ENEMIES_AI.md (2026-10-03) plans the brain that replaces the cast loop; the loop stays behind `Enemy.naive_casting` until its milestone. |
| `res://scripts/main.gd` | **Kept.** "You died – press Backspace to restart" (`restart`), "Room cleared!". |
| `res://scripts/abilities/ability_util.gd` | **Kept, extended.** Cone, segment, circle queries using the target's gameplay radius; `in_sight(from, units)` keeps only the units in line of sight (walls block, units don't; feet to feet). The shape queries themselves ignore walls; callers filter. |

## Data (Resources)
Names checked against CONVENTIONS.md. `HitContext`, `StatusEffect`, `StatusComponent`, `ReactionRule` and `GameplayEffect` are reserved names; `HitPipeline`, `AttackSwing`, `AttackCombo` and `Telegraph` are new (CONVENTIONS.md, Reserved names).

Audio hooks: see AUDIO.md.

### HitContext (RefCounted, `res://scripts/combat/hit_context.gd`)
One per hit. Built by the attacker, filled in by the pipeline.

| Field | Type | Notes |
|---|---|---|
| `source` | `Unit` | null = the environment. Kill credit. For a DoT tick: whoever applied the status. |
| `target` | `Node` | a Unit or an interactable (`on_hit(ctx)`) |
| `ability` | `Ability` | null for basic attacks, statuses, hazards, knockback |
| `base_damage`, `ad_ratio`, `ap_ratio` | `float` | stage 1–2 inputs |
| `damage_type` | `HitContext.DamageType` | enum `PHYSICAL`, `MAGIC`, `TRUE` (the reserved `DamageType`, same pattern as `Ability.Targeting`) |
| `tags` | `Array[StringName]` | `&"basic_attack"`, `&"ability"`, `&"proc"`, `&"dot"`, `&"crit"`, `&"physical"` / `&"magic"` / `&"true"`, plus the ability's tags (`from_ability()` adds them). League-style enemy attacks are tagged `basic_attack` too |
| `can_crit` | `bool` | false for DoT ticks and wrapped `take_damage()` calls |
| `crit_roll` | `HitContext.CritRoll` | shared by the hits of one swing or cast (the first hit rolls, the rest copy it); null = the hit rolls on its own |
| `proc_coefficient` | `float` | 1.0 default |
| `knockback_px`, `knockback_duration` | `float` | 0 = none; the push follows the target's `MovementComponent.knockback_curve` (`HitContext.knockback_curve` was deleted 2026-09-29: nothing set it) |
| `knockback_from` | `Vector2` | push away from this point (default: the source's position) |
| `statuses` | `Array[StatusEffect]` | applied after damage |
| `feel` | `HitContext.Feel` | `NONE`, `LIGHT`, `HEAVY`; a kill upgrades it |
| `target_tags` | `Array[StringName]` | the target's status tags just before the hit (filled in by `Unit.on_hit`; reaction rules read it) |
| `chain_depth` | `int` | the reaction chain depth of a free cast's hits (ABILITIES.md) |
| `heal_on_hit_ratio` | `float` | CHAMPIONS CH5: the ability's `heal_on_hit_ratio` for this hit (`from_ability()` with a cast: `get_effect_param()` for the unit hit; 0 without a cast and for every other hit). `apply_on_hit()` heals the source for it × `taken_damage` |
| `heal_missing_health_ratio` | `float` | CHAMPIONS CH5b: the ability's `heal_missing_health_ratio` for this hit (`from_ability()` with a cast, like `heal_on_hit_ratio`). `apply_on_hit()` heals the source for it × its missing health, once per cast (the first hit that gets through) |
| `cast` | `CastContext` | CHAMPIONS CH5b: the cast this hit belongs to (`from_ability()` with a cast); null for swings, Hurtbox hits, procs and DoTs. Used for once-per-cast effects (`CastContext.missing_health_healed`) |
| **filled in by the pipeline:** `raw_damage` (before mitigation), `taken_damage` (after mitigation and `incoming_damage`), `absorbed` (by shields), `health_lost`, `is_crit`, `blocked` (i-frames), `killed` | | read by listeners, numbers, feel and on-hit |

### AttackSwing and AttackCombo (combo data)
- `AttackSwing` (Resource, `res://scripts/data/attack_swing.gd`): one hit of the combo.
  - `windup` (s), `duration` (s, the whole swing = root time), `ad_ratio`
  - `reach_multiplier` (× the `attack_range` stat, 1.0), `arc_deg`
  - `knockback_px`, `knockback_duration`
  - `feel` (`LIGHT` / `HEAVY`)
  - `lunge_px` (6): melee swing step along the aim; `lunge_max_px` (24): the longest target-pull step. The dash-strike swing's step is its own `lunge_px` (16).
  - `proc_coefficient` (1.0)
  - `pause_after` (0): seconds after this swing ends before the next can start (the finisher's breather)
  - Presentation hooks (ABILITIES AB14, export group "Presentation"; empty = nothing, like an ability's `cast_vfx` / `impact_vfx` / `cast_anim`, named for swings): `swing_vfx` (`PackedScene`, at swing start next to `swing_sound`, whiffs included), `impact_vfx` (`PackedScene`, on each enemy whose hit got through in `_land_swing()`), `swing_anim` (`StringName`, a clip of the attacker's 3D model, which `UnitView` positions by the swing's progress: start to strike frame until the hit, strike to end after; on a 2D `Body/AnimationPlayer` until the 3D pivot's cleanup C3). Swing progress (`AutoAttackComponent.get_swing_progress()`) = time since the swing started ÷ (`duration` ÷ combo speed), so the hooks follow `attack_speed` (and `speed_scale`), never cast speed. The dash-strike swing has its own. A cancelled swing ends its clip at once. Scenes spawn through `VFX.spawn_scene()` with `setup(attacker, swing)` / `setup(attacker, hit)`. Built in ABILITIES AB14 (2026-09-29). League-style enemy attacks (not swings) have no hooks yet (ENEMIES_AI.md).
  - Sound cues *(AUDIO A4: approved 2026-10-04, not built)*: `sound_cues: Array[SoundCue]` (export group "Sounds"), each played by AutoAttackComponent on the tick the swing's progress (`get_swing_progress()`, the same progress `swing_anim` is positioned by) reaches its `progress`, so it follows `attack_speed` and stays on its frame of the motion; `swing_sound` stays as the cue at 0. A swing cancelled or interrupted before a cue skips it; a one-shot already started plays out. Variants on a swing's sounds read self = the attacker, target = the aimed enemy (AUDIO.md, Conditional audio). Hit tags per swing (`hit_tags`, e.g. `finisher`, added to its hits so a HIT reaction rule can tell which swing landed) are *(proposed)* by AUDIO.md's ring-out example; Ryan (2026-10-04): noted here for later, not part of A4 (Open questions). Korsavil is the champion that needs it (designed 2026-10-04): the last swing of each of her two cycles gets `finisher`. **Built in her K1 (2026-10-04):** `AttackSwing.hit_tags` (empty by default), added to the swing's hits by `HitPipeline.basic_attack()`.
- `AttackCombo` (Resource, `res://scripts/data/attack_combo.gd`): `attack_style` (`AttackCombo.AttackStyle.MELEE` default / `RANGED`), `swings: Array[AttackSwing]`, `combo_reset_time`, `dash_strike: AttackSwing` (null = dash-strikes use the normal next swing), `hit_forgiveness` (0.10), `speed_scale` (default 1.0; one knob that scales every swing timing; × attack speed; the Knight's is 1.266).
  - Melee assist: `assist_range_bonus_px` (40, added to the swing's reach), `assist_angle_deg` (35), `assist_snap_deg` (20), `stop_at_reach_fraction` (0.7).
  - Recovery: `walk_cancels_recovery` (true), `recovery_move_cancel_after` (0.1 s).
- Knight: `res://data/combos/combo_knight.tres` with the three swings from Numbers (0.08 / 0.3 s, 0.08 / 0.3 s, 0.08 / 0.4 s; 1.0 / 1.0 / 1.6; 110° / 110° / 140°; 6 / 6 / 20 px over 0.1 s; LIGHT / LIGHT / HEAVY; steps 6 / 6 / 10 px, pull up to 24 / 24 / 32 px; MELEE with the default assist and recovery settings, `speed_scale` 1.266) and the dash-strike swing from Numbers.

### HitFeel (Resource, `res://scripts/data/hit_feel.gd`; `res://data/hit_feels/hit_feel_default.tres`)
The hit feel per tier, held by `GameFeel.hit_feel`: `light_hitstop` 0.03, `heavy_hitstop` 0.06, `kill_hitstop` 0.08 (s); `light_shake` 0, `heavy_shake` 2, `kill_shake` 3 (px). (Its `flash_time` 0.06 s and `flash_modulate` (3, 3, 3) went with the 2D flash in the 3D pivot's cleanup C3; the model's flash is `UnitView`'s.)

### DamageNumberStyle (Resource, `res://scripts/data/damage_number_style.gd`; `res://data/damage_number_styles/damage_number_style_default.tres`)
`size_thresholds` 0 / 100 / 1000 → `font_sizes` 10 / 12 / 14 (steps of 10×, a log scale); crits +3 sizes, their own outline color, a "!" suffix and `crit_font` (null until the asset exists); DoT ticks size 8, merged per target within `dot_merge_window` 0.3 s; colors: physical orange (1, 0.72, 0.35), magic blue (0.55, 0.7, 1), true white, damage the player takes red (1, 0.3, 0.28), healing green (0.4, 1, 0.45), shield-absorbed silver-blue (0.78, 0.84, 0.92) (`shield_color`); motion: pop in at 1.35×, rise 12 px, fade over the second half of 0.6 s, ±6 px sideways spread. `get_font_size(amount)`, `get_damage_type_color(type)`.

### Fields on Ability (combat)
- `damage_type: HitContext.DamageType` (PHYSICAL; the Knight's descriptions already say physical)
- `proc_coefficient: float` (1.0)
- `cancels_swing: Ability.SwingCancel`: `NEVER`, `AFTER_HIT` (default; the Knight's four abilities use it), `ANYTIME`
- `ignores_walls: bool` (false): true = hits don't need line of sight (e.g. a meteor shower). `filter_by_walls()` / `can_reach_through_walls()` apply it.

### StatusEffect (Resource, `res://scripts/data/status_effect.gd`; files `res://data/statuses/status_<name>.tres`)
- `id: StringName` (`&"stun"`; its modifier source id is `&"status_stun"`, CONVENTIONS), `display_name`
- `tags: Array[StringName]`: `&"cc"`, `&"stun"`, `&"root"`, `&"silence"`, `&"slow"`, `&"buff"`, `&"debuff"`, `&"dot"`, `&"shield"`...
- `duration` (s; −1 = until removed)
- `stack_rule`: `REFRESH_LONGER` (keep the longer remaining time; the stun), `REFRESH` (restart, with the new numbers and source), `STACK` (add a stack up to `max_stacks`, each with its own time; at max the one closest to running out restarts), `IGNORE`
- `get_source_id()` = `&"status_<id>"`, `is_cc()`, `is_dot()`
- `modifiers: Array[StatModifier]` (slows and hastes are `move_speed` modifiers)
- `blocks_move`, `blocks_attack`, `blocks_cast`, `blocks_dash` (stun: all four; root: move and dash; silence: cast). `blocks_dash` stops every move of the unit's own, not just the dash key: abilities that move their caster fail ("Rooted"), `dash()`, `leap()` and `blink()` refuse, and a swing doesn't step; forced movement still moves it (roots are roots, Ryan 2026-10-04; ABILITIES.md, Roots).
- DoT: `tick_interval` (0 = none), `tick_damage`, `tick_ad_ratio`, `tick_damage_type` (MAGIC default). Damage is snapshotted from the applier's stats when applied (a new stack or refresh takes a new snapshot for every stack).
- `shield_amount`: damage it absorbs after mitigation and `incoming_damage`, per application (each stack has its own); 0 = not a shield (`is_shield()`). Used up = that stack ends (the status with its last stack). REFRESH restores the full amount, REFRESH_LONGER keeps the bigger one. Template: `data/statuses/status_shield.tres` (100, 3 s, tags `shield` + `buff`, REFRESH).
- `vfx: PackedScene` (visuals only)
- ABILITIES.md adds `reaction_rules`, `augments` and the empower fields.
- Built in 3D pivot P9: `ignores_tenacity` (false; airborne true) and `cleansable` (true; airborne false: `StatusComponent.remove_statuses_with_tags()` skips it). Files `status_airborne.tres`, `status_elevated.tres`.
- Planned with Korsavil (designed 2026-10-04, not built; the names *(proposed)*; specified in ABILITIES.md, Later toolkit pieces), each defaulting to today's behavior:
  - stack rule `STACK_SHARED`: a new application adds a stack (up to `max_stacks`) and restarts the one timer every stack shares; the stacks end together (Inevitable Demise: "a new Blade restarts the 5 s");
  - `tick_by_stacks` (an array): a DoT tick at n stacks deals × entry n − 1 instead of × n (Demise's replacing tiers);
  - `stat_scalings`: StatScalings added under the status's source id while it's on (the orbit's numbers following the Blades' count);
  - `ends_on_cast`, `ends_on_swing`, `ends_on_dash`: the status ends when its holder starts a cast, a swing or a dash (Vanish; ALLIES' stealth *(proposed)*);
  - `refused_by_tags`: the status isn't applied to a unit carrying any of these tags (fear and the `boss` tag);
  - the empower fields (ABILITIES.md) get `empower_uses` (a basic attack empower lasting several swings) and `empower_damage_type` (the whole empowered hit of that type: Ryan, 2026-10-04, for the full Vanish's TRUE swings);
  - `combo_override` (an `AttackCombo`): while the status is on, a new chain of the unit's basic attack uses it, kept to the chain's end (Korsavil's 4-swing cycle from Vanish; Ryan, 2026-10-04, two cycles switched by state).
  - File: `status_fear.tres` (Status effects, Fear).
- Files: `status_stun.tres` (tags cc / stun / debuff, blocks all four, REFRESH_LONGER, 1.0 s default (`apply_stun()` passes its own), VFX `res://scenes/vfx/stun_stars.tscn`), `status_slow.tres` (cc / slow / debuff, −30% `move_speed`, REFRESH, 1.5 s), `status_haste.tres` (haste / buff, +20% `move_speed`, REFRESH, 2 s).

### ReactionRule and GameplayEffect (`res://scripts/data/`; rules in `res://data/reactions/reaction_<name>.tres`)
- `ReactionRule`: `id`, `trigger` (8 in the enum: `IMPACT`, `HIT`, `HAZARD_ENTERED`, `HAZARD_EXITED`, `STATUS_APPLIED`, `UNIT_DIED`, `HAZARD_OVERLAP`, `ABILITY_CAST` (added last; ABILITIES.md); 4 of them built, see below), `required_hit_tags`, `required_unit_tags` (the affected unit's status tags), `required_status_tags` (STATUS_APPLIED: the applied status's tags), `required_surface_tags`, `min_impact_speed_px`, `chance` (for `HIT`: × the hit's `proc_coefficient`), `effects: Array[GameplayEffect]`, plus:
  - `effect_target`: `AFFECTED` (default) or `OTHER`. Every event has an affected unit and an other unit: HIT = the unit hit / the attacker; UNIT_DIED = the unit that died / the killer; STATUS_APPLIED = the unit that got it / who applied it.
  - `owner_role` (unit rules only): `SOURCE` (default; the owner is the other unit: "when I hit / kill / apply…") or `AFFECTED` ("when I'm hit / die / get…").
  - `chain_limit` (1–5, default 1): how many reactions in a row the rule may take part in; set by the ability, passive or item that grants it. `ReactionRule.MAX_CHAIN` = 5 caps every chain (Ryan, 2026-09-27).
  - `conditions: Array[Condition]`: the shared condition resource; all must pass after the tag filters and before `chance` (ABILITIES.md, Conditions).
  - `required_ability_scope` (ABILITIES.md).
- Two kinds of rules, the same Resource (Ryan, 2026-09-27):
  - **World rules** apply to everyone: every `.tres` in `res://data/reactions/world/` (loaded at start), plus `Reactions.add_world_rule(rule, source_id)` / `remove_world_rules_from(source_id)` (rooms, hazards, run modifiers later). Their effects' source is the event's other unit.
  - **Unit rules** belong to one unit, from its items, passives or buffs: `Unit.add_reaction_rule(rule, source_id)`, `remove_reaction_rules_from(source_id)`, `get_reaction_rules()`. Their effects' source is the owner.
- Autoload **`Reactions`** (`res://scripts/autoload/reactions.gd`) listens to `Events.unit_hit`, `unit_died`, `status_applied` (and `ability_cast`, ABILITIES.md) and fires every matching rule: trigger, chain depth, all required tags, conditions, then `chance` (rolled on `Reactions.rng`, seedable). Unit tags for HIT and UNIT_DIED come from `HitContext.target_tags` (a kill clears the statuses). Because HIT's chance is × `proc_coefficient`, DoT ticks and procs (coefficient 0) never trigger HIT rules.
- Chains: effects run synchronously, so an event they cause is one link deeper (`Reactions.get_chain_depth()`); a rule fires on an event at depth d only if d < min(`chain_limit`, 5). Later consequences (the ticks of a DoT a rule applied) start again at depth 0.
- `GameplayEffect` (base): `apply(target: Unit, source: Unit, trigger_ctx: RefCounted) -> void` (`trigger_ctx`: the HitContext for HIT and UNIT_DIED, the StatusEffect for STATUS_APPLIED). Subclasses:
  - `ApplyStatusGameplayEffect`: `status`, `duration` (−1 = its own).
  - `DealDamageGameplayEffect`: `base_damage`, `ad_ratio` (the source's), `damage_type` (MAGIC default), extra `tags`; a `proc` hit (`HitPipeline.make_proc()`): can't crit, triggers no on-hit and no HIT rules.
  - `KnockbackGameplayEffect`: `distance_px`, `duration`; away from the source, dash-cancelable; nothing without a source.
  - `HealGameplayEffect`: `amount` + `max_health_ratio` × max health (`Unit.heal()`, green number).
  - ABILITIES.md adds `ModifyCooldownGameplayEffect`, `RestoreResourceGameplayEffect`, `CastAbilityGameplayEffect` and `RemoveStatusesByTagGameplayEffect`.
- There's no "play sound" GameplayEffect: a rule makes a sound only through the status it applies or the proc hit it causes (AUDIO.md).
- Built triggers (4 of the 8): `HIT`, `UNIT_DIED`, `STATUS_APPLIED` (C11), `ABILITY_CAST` (ABILITIES AB8). The other 4, `IMPACT`, `HAZARD_ENTERED`, `HAZARD_EXITED` and `HAZARD_OVERLAP`, come with WORLD_INTERACTION's impacts and Hazards (approved there by Ryan, 2026-09-30). Effects hit one unit; area effects ("explode on death") come later.
- Demo (sandbox only): `res://data/reactions/reaction_shatter.tres` (HIT on a `stun`-tagged target → a 30 MAGIC proc tagged `shatter`, the attacker's rule, chain_limit 1), given to the player by the `SandboxReactions` node in `sandbox.tscn` (`res://scripts/rooms/sandbox_reactions.gd`, source `&"sandbox_demo"`). room_01 has none.

### Stats
`incoming_damage`, `damage_increase`, `on_hit_damage`, `life_on_hit`, `resource_on_hit` and the `crit_damage` default are in STATS.md (Stat list, Scoped modifiers).

## Architecture / contracts
### Scripts
- **`Events`** (`res://scripts/autoload/events.gd`). Signals (reserved names): `unit_hit(ctx)`, `unit_damaged(ctx)`, `unit_died(unit, ctx)`, `status_applied(unit, status)`, `status_removed(unit, status)` (and `ability_cast`, ABILITIES.md). Existing local signals (`Unit.died`, `Unit.damaged`) stay.
- **`HitPipeline`** (`res://scripts/combat/hit_pipeline.gd`, static functions).
  - `resolve(ctx)`: stages 1–4 (base, stat scaling from the source's StatsComponent, `damage_increase`, crit), then `ctx.target.on_hit(ctx)`. A target without `on_hit()` = `blocked`.
  - The damage type tag is added first; `get_hit_scopes(ctx)` = `hit:<tag>` per hit tag + `target:<tag>` per target status tag (`Unit.get_status_tags()`); `raw = scaled × (1 + damage_increase)` (the source's `get_scoped_stat(&"damage_increase", scopes)`).
  - `roll_crit(ctx, scopes)`: skipped when `can_crit` is false or there's no source; a hit whose `crit_roll` is already decided copies it; otherwise `roll_prd(source, chance)`: chance ≥ 1 always crits, ≤ 0 never rolls, else `min(C × (source.crit_misses + 1), 1)` against `HitPipeline.crit_rng` (seedable), then `Unit.crit_misses` resets on a crit or goes up by 1; `get_prd_constant(chance)` finds C by bisection (cached). A crit multiplies raw by `crit_damage`, sets `is_crit` and adds `&"crit"`. The combo swing, every ability cast and the elite slam share one `CritRoll` per swing or cast.
  - `apply_on_hit(ctx)` (called by `Unit.on_hit`) and `make_proc(source, target, amount)` (a MAGIC `proc` hit that can't crit, proc coefficient 0).
  - Helpers: `get_scaled_damage()`, `get_mitigation_multiplier()`, `mitigate()`.
  - Builders that fill tags, type, ratios and feel: `basic_attack(source, target, swing)`, `from_ability(caster, ability, target, cast)` (ABILITIES.md).
- **`Unit.on_hit(ctx)`**, the same method name interactables use (WORLD_INTERACTION.md). In order:
  1. `blocked` if not alive or invulnerable, or untargetable and the hit isn't a `dot` tick → return (nothing else happens).
  2. `ctx.target_tags` = the target's status tags before the hit. Mitigation by type, then × the target's `incoming_damage` (`taken_damage`).
  3. Shields (`StatusComponent.absorb_damage()`: `ctx.absorbed`), then `health.take_damage()` with the rest (`ctx.health_lost`). `taken_damage` still includes the absorbed part. A killing hit dies here (`_on_died()`: the attack cancelled, the cast interrupted, `status_component.clear()`) and sets `killed`.
  4. `damaged.emit()`, the number and the flash: every hit that gets through flashes and shows its number (`_spawn_hit_number(ctx)`): size by `taken_damage`, crit style if `is_crit`, the DoT style (merged into the target's latest DoT number within 0.3 s) if tagged `dot`, color by damage type (red on the player). Blocked hits show nothing. `Unit.show_heal_number(amount)` shows a green "+N"; `Unit.heal(amount)` heals and shows it for what was actually healed (life on hit, life steal). Health regen doesn't show numbers.
  5. Knockback (`movement.displace(..., dash_cancelable = true)`, even if a shield took all of it; not on an unstoppable target, and not on one the hit killed: `Ability.hit_units()` slides those itself, ABILITIES.md), then statuses (`ctx.statuses`, from `ctx.source`; not on a target the hit killed).
  6. Feel: `GameFeel.play_hit_feel(ctx)`: the hit's tier (a kill uses the kill tier) sets the hitstop and shake; feel NONE plays nothing, so abilities and enemy basic attacks keep their own.
  7. Events: `Events.unit_hit`, `Events.unit_damaged` (when `taken_damage` > 0), `Events.unit_died(self, ctx)` (when `killed`; kill credit = `ctx.source`).
  8. On-hit (only `basic_attack` or `ability` hits, never `proc` or `dot`; a blocked hit has none): `on_hit_damage` × `proc_coefficient` as a MAGIC `proc` hit on the same target, `life_on_hit` × `proc_coefficient` plus `life_steal` × `taken_damage` (basic attacks only, proposed) plus `heal_on_hit_ratio` × `taken_damage` (the hit's ability's kit heal, CHAMPIONS CH5) plus, once per cast, `heal_missing_health_ratio` × the source's missing health (CHAMPIONS CH5b; the cast's first hit that gets through) heal the source with one green number (`Unit.heal()`), `resource_on_hit` × `proc_coefficient` restores its resource. It runs after the events and before post-hit i-frames start, so the i-frames a hit starts never block its own proc.
  9. Post-hit i-frames (a living target with `post_hit_iframes` > 0; not for `dot` ticks or `proc` hits).
- `Unit.take_damage(amount, source)` stays as a wrapper (`Unit.make_hit_context()`): a `HitContext` with `base_damage = amount`, PHYSICAL, `can_crit = false`, feel `NONE` (callers keep their own shake and hitstop), then `on_hit()` directly (the amount is already scaled). `Player`'s "got hit" 2 px shake is a `Player.on_hit` override, so pipeline hits get it too.
- **`StatusComponent`** (`res://scripts/components/status_component.gd`), a child of every Unit (`Unit.status_component`, optional so old scenes still load; `player.tscn` and `slime.tscn` have one, so the elite and dummies too).
  - `apply_status(effect, source = null, duration_override = -1.0) -> bool`: tenacity × (1 − tenacity) for `cc`-tagged statuses only; false for a dead unit, IGNORE while active, or a zero duration. Also `remove_status(id)`, `clear()` (death), queries by id and tag (`has_status`, `has_tag`, `get_tags`, `get_status`, `get_time_left` (−1 = until removed), `get_stacks`, `get_source`...), `blocks_cast()`, `blocks_dash()`.
  - Shields: `absorb_damage(amount) -> float`: the shields expiring soonest go first, "until removed" ones last, ties by status id; returns the amount absorbed. `get_shield(id)`, `get_total_shield()`.
  - Signals `status_applied(effect)` (also on a refresh or a new stack), `status_removed(effect)`, re-emitted on `Events`.
  - While active: the effect's `modifiers` once per stack under `&"status_<id>"`; `blocks_move` / `blocks_attack` as `add_move_lock(id)` / `AutoAttackComponent.add_lock(id)` (the stun's lock id stays `&"stun"`; an attack lock also cancels a windup or swing); `vfx` instanced as a child of the unit. Timers run in `_physics_process` (game time: they follow hitstop and pausing) and treat ≤ 0.0001 s as done.
  - Stack rules as in Data (StatusEffect).
  - DoT: a tick every `tick_interval`, the first one interval after it's applied: a hit through `HitPipeline.resolve()` from the applier (kill credit; null once freed), `base_damage` = (`tick_damage` + `tick_ad_ratio` × the applier's attack_damage when applied) × stacks, `tick_damage_type`, tags `dot` + the status's tags, can't crit, proc coefficient 0 (no on-hit), no post-hit i-frames. `damage_increase` is read live at each tick.
- **Unit** (statuses): `is_stunned()` (a `stun`-tagged status); `is_cast_blocked()` / `is_dash_blocked()` (stunned, or a status with `blocks_cast` / `blocks_dash`; AbilityComponent's `can_cast()` and cast interruption and DashComponent's `can_dash()` use them); `get_status_tags()`. MovementComponent gets `set_status_component()`.
- **`WorldQuery`** (`res://scripts/autoload/world_query.gd`): `has_line_of_sight(from, to, mask = 1)` (world layer 1; units don't block it) and `shape_sweep()`; the rest of its API is WORLD_INTERACTION.md's.
- **`Telegraph`** (`res://scripts/vfx/telegraph.gd`, Node2D): `Telegraph.circle(anchor, center, radius, time, color)` draws a true circle (not squashed, so it matches the hit area) with a faint fill, an outline and a fill that grows until the hit; `finish()` flashes and frees it; `get_progress()`. `Telegraph.line(anchor, start, end, width, time, color)` (ABILITIES AB13, VECTOR casts) draws a band `width` px wide from `start` to `end` whose fill grows along its length (`line_vector`, `width_px`). `Telegraph.cone(anchor, origin, direction, radius, half_angle, time, color)` (ENEMIES_AI AI3d, the enemy library's cleave arc) draws a fan whose fill grows outward (`cone_direction`, `cone_half_angle`). It goes on the room's floor (a child of the room just before `Entities`), under every unit. `THREAT_COLOR` = orange-red (1, 0.35, 0.15). VFX only: the ability's own query decides the hit. ABILITIES AB14: `set_progress(p)`: a telegraph that belongs to a cast is filled by the cast's progress each tick (AbilityComponent calls it) and ignores its own clock; one with no cast keeps its `duration`.

### Changes to existing scripts (additive)
- **AutoAttackComponent, combo mode** (`combo: AttackCombo`, null = LoL mode):
  - `try_swing(direction, dash_strike = false)`, `can_swing()`, `is_swinging()`, `is_in_recovery()`, `cancel_swing()`, `get_combo_index()`, `get_current_swing()`, `get_swing_speed()`, `get_swing_reach_px(swing)`, `is_swing_rooted()` (swinging and walking hasn't ended the root). Signals: `swing_started(index, direction, swing)`, `swing_landed(index, targets)`, `swing_cancelled` (`swing_finished` was deleted 2026-09-29: nothing listened).
  - A swing: move lock `&"attack_swing"` for `duration / speed`; the aim is locked at the start; at `windup / speed` it queries `AbilityUtil.in_cone()` from the feet with reach and arc × (1 + `hit_forgiveness`), keeps targets in line of sight, and runs `HitPipeline` on each. `speed = attack_speed ÷ base attack_speed` (`StatsComponent.get_base_value(&"attack_speed")`). Swing timers don't count the physics frame the swing started in, and treat ≤ 0.0001 s as done, so a 0.3 s swing is exactly 18 frames.
  - The combo index advances when a swing ends; `combo_reset_time` counts from the end of the swing's recovery.
  - `cancel_swing(keep_combo_if_landed = false)`: with the flag and a landed hit, the next swing is the one after it (the dash-strike: the swing it interrupted) and `combo_reset_time` restarts; otherwise no hit and the combo resets. The dash passes the flag; `add_lock(id)` passes it only for the casting lock (`CASTING_LOCK`, a cast the player chose); stuns and other status locks and `cancel()` (death) reset.
  - Basic attack empowers (Iron Resolve) are used up by the first swing that hits anything and apply to every target it hits (ABILITIES.md, Empowers).
  - `reset_attack_timer()` (`Ability.resets_auto_attack`) does nothing in combo mode.
  - An attack press also drops a queued walk-into-range cast (R), like the dash does.
  - Dash-strike: `try_swing(direction, true)` with a combo `dash_strike` swing runs that swing with index −1 (`swing_started` / `swing_landed` report −1; `get_combo_index()` is −1 during it; `is_dash_strike()`), its hits are tagged `dash_strike` as well as `basic_attack`, and when it finishes the next swing is the one it interrupted (a fresh `combo_reset_time` window starts). Cancelling it in its windup resets the combo like any swing.
  - Melee: at swing start a MELEE combo picks the aimed enemy (`get_assist_target()`), snaps the aim and starts the step: `movement.displace(..., step_curve, dash_cancelable = true)` over the windup (÷ combo speed). `step_curve` export = `curve_dash.tres`. `cancel_swing()` ends the step only if it's still the running displacement (`get_displacement_serial()`); a knockback or dash that replaced it stays. `debug_draw`: the assist cone (grey), the snapped aim (white), the aimed enemy (red) and the planned step (yellow), on a child Node2D of the unit.
- **AutoAttackComponent, LoL mode** (enemies): `hit_knockback_px` (slime 12) and `hit_knockback_duration` (0.1 s). `enemy_hit_forgiveness` (0.10): `is_in_range()` uses `attack_range × (1 − forgiveness)`, so the windup starts, and the hit lands, only within it; out of reach when the windup ends = a whiff (`attack_whiffed(target)`; no damage, the attack timer still runs; slimes still lunge). The hit is `make_attack_context(target)` (1.0 × `attack_damage` as `ad_ratio`, PHYSICAL, tagged `basic_attack`, can crit, feel NONE, the push) through `HitPipeline.resolve()`, so the attacker's `damage_increase`, crit and `hit:` / `target:` scopes apply as for a swing (since 2026-09-29; enemies have none yet, so their numbers are unchanged). Basic attack empowers are added with `add_empowers()`; a blocked hit skips their on-hit callbacks. `attack_landed(target, damage)` reports the damage before `damage_increase`, crit and mitigation.
- **PlayerInput**: `attack_pressed` → `player.attack.try_swing(player.get_aim_direction(), dash_strike)`. An ability press allowed during a swing cancels the swing first. Attack and ability legality and the buffer pausing during a swing: MOVEMENT.md, Input buffering and cancels.
- **DashComponent**: `try_dash()` cancels a swing in windup or recovery (not on the hit frame; the hit resolves inside one physics frame, so there's nothing to cancel) with `cancel_swing(true)`. `can_dash()` allows a dash during a dash-cancelable displacement; the dash replaces it.
- **Player**: facing = the swing's aim, locked at swing start, while the swing roots; `State.ATTACK` = the rooted swing, ranked over DISPLACED (its step is a displacement); once walking ends the root, state and facing follow walking. `can_interrupt_swing(slot)` applies `cancels_swing` for both `request_cast()` and the buffer. Swing visuals: the sword pulls back during the windup and a slash the size of the swing's reach and arc plays at the hit (brighter and longer on the finisher; the dash-strike uses the finisher's look). The movement VFX knockback stretch also plays on the step (it reads as a lunge).
- **MovementComponent**: `displace(velocity, duration, curve = null, dash_cancelable = false)`, `is_displacement_dash_cancelable()`, `get_displacement_serial()`, `stop_displacement()` (for a caller's own displacement; no `displacement_finished`). `displace()` is dropped (returns false) if the running displacement still has more distance to cover than the new one's whole distance (`get_displacement_remaining_px()`). `dash()` always replaces. A melee swing step dropped this way has nothing to stop when the swing is cancelled.
- **GameFeel**: `hitstop()` keeps one end time in real time (`Time.get_ticks_msec()`); a new call only extends it if it ends later. `play_hit_feel(ctx)` picks the tier; `hit_feel` and `hitstop_time_scale` are exports.
- **Unit (getting hit)**: `@export var post_hit_iframes: float` (0 = none; `player.tscn` 0.3). A hit that gets through adds `&"hit_iframes"` for that long in game time (it follows hitstop and pausing); DoT ticks don't start it. **Player** blinks while it lasts (`hit_iframes_blink_period` 0.1 s; visual only). Every knockback from `Unit.on_hit` is dash-cancelable, so a unit that can dash (the player) dashes out of it at once; any other displacement still blocks the dash.
- **Enemy**: `_try_cast_ability()` in AGGRO: for each ready slot (q, w, e, r), cast at the player's position if the player is within `cast_range` of the enemy's center and in sight, and the enemy isn't mid-windup; a whiff still lunges. The cast time is the telegraph; the cast roots it (a stun during the cast time interrupts it at once, as for every ability).
- **Ability / CastContext / AbilityComponent**: `Ability.on_cast_started(caster, ctx)` (virtual, called right after `cast_started`) lets an ability show a telegraph during its cast time; it sets `CastContext.telegraph`, and AbilityComponent frees it if the cast is cancelled (dash, move) or interrupted (stun, death). Death ends the cast at once: `Unit._on_died()` calls `AbilityComponent.interrupt_cast()`, which during the cast time frees the telegraph, releases the cast's locks, refunds the cooldown for a living caster and emits `cast_finished` (no `cast_cancelled`; returns false with no cast running or once `execute()` has started). A caster freed without dying frees its telegraph in `NOTIFICATION_PREDELETE`, since its waiting `_do_cast()` never resumes.
- **Knight abilities**: Cleave, Lunge and Judgement hit through `Ability.hit_units()` (`HitPipeline.from_ability()` per target): Cleave's push is its `hit_knockback_px`, applied by `Unit.on_hit()`; Judgement's missing-health bonus is a scaling term and its stun a status of its hit; blocked hits get neither; their shake and hitstop are `hit_shake` / `hit_hitstop`, played once when a hit landed. Iron Resolve's bonus rides the swing's own pipeline hit (an empower). ABILITIES.md.
- **Elite slam** (`res://scripts/abilities/slime/slam.gd`, `res://data/abilities/slime_elite_q_slam.tres`): POINT at the player's position at cast start (cast_range 250 u = 80 px), 0.65 s cast (the telegraph), 72 px circle (hit radius × 0.9, enemy forgiveness), 100 PHYSICAL through `HitPipeline.from_ability()`, 20 px push away from the elite, its own hitstop 0.06 s and 3 px shake when it lands, 4 s cooldown.
- **Elite slime**: `res://scenes/enemies/slime_elite.tscn` inherits `slime.tscn` (purple, ×1.4 body, 19 px collider, an AbilityComponent with the slam); `res://data/units/slime_elite.tres`: 900 health, 30 basic attack damage with a 0.25 s windup, 260 move speed. One (`Elite1`) sits in the sandbox's open top-right corner (784, 112).

## How each edge case is handled (MUST)
| Edge case | Handling |
|---|---|
| On-hit proc on the player | The proc resolves before the hit's post-hit i-frames start, so it lands; it starts none of its own. A proc can't trigger another on-hit (`proc` tag). |
| Stunned mid-swing | A stun adds the `&"stun"` attack lock; `AutoAttackComponent.add_lock()` calls `cancel_swing()`: no hit, root released, combo index back to 0. |
| Dash or cast after the hit | The swing counts: `cancel_swing(true)` sets the next swing as if it had finished (after a finisher: swing 1, with its breather; after a dash-strike: the swing it interrupted) and restarts `combo_reset_time`. In the windup it resets the combo. A stun after the hit still resets it. |
| Hit during i-frames | `Unit.on_hit` returns at step 1 with `blocked = true`: no damage, number, knockback, status, on-hit, events or reaction rules. `take_damage()` does the same through the wrapper. |
| Kill during hitstop | The hit resolves normally; `unit_died` fires at once. The kill hitstop (0.08 s) extends the running one. The death tween runs in scaled time, so it plays out after the freeze. |
| Several hits in the same frame | On enemies all of them resolve in order, each with its own number; hitstop = the longest; shake = the largest (the camera keeps the max). On the player the first hit lands and starts post-hit i-frames, and the rest are blocked. |
| Overlapping hitstops | `GameFeel` keeps one end time and only extends it (the longest wins). |
| Two knockbacks | `displace()` keeps whichever has more distance left to cover (the stronger wins). A stun doesn't stop a knockback (DECISIONS, Movement). |
| Target dies before the swing lands | Swings aren't target-locked: the cone query at the hit moment takes whoever is there; with nobody there the swing whiffs (full animation, no hitstop). Enemy LoL attacks: a dead target cancels the windup. |
| Caster dies or is freed mid-cast | The cast ends at once through `interrupt_cast()`: its telegraph disappears the same frame, no hit lands, `cast_finished` fires once. Freed without dying: the telegraph goes with it (`NOTIFICATION_PREDELETE`). Once `execute()` has started, the effect plays out. |
| Attacker dies mid-swing | `Unit._on_died()` calls `attack.cancel()`, which also cancels the swing: no hit. Hits that already resolved stay. |
| Walls | Swing targets need `WorldQuery.has_line_of_sight(feet → target feet)`. Abilities filter the same way unless `ignores_walls`; UNIT abilities also need line of sight to start the cast. Per attack: League-style enemy attacks with a wall in between whiff; walls block Cleave; Lunge checks sight from the nearest point of its path; the elite slam from its circle's center; Judgement (UNIT) treats out of sight like out of range, so it walks until it can see the target, and a target that goes behind a wall during the cast is missed. |
| Shield absorbs a hit | Knockback and statuses still apply; `taken_damage` still counts for life steal and `unit_damaged`; post-hit i-frames still start; a fully absorbed hit can't kill. The number shows the absorbed part as its own number in `shield_color` (DoT ticks: small, not merged), and the rest (if ≥ 0.5) as usual. |
| DoT ticks can't crit (proposed) | DoT contexts have `can_crit = false`. |
| Melee: target moves or dies during the step | The step's end point is planned at swing start (velocity × windup); it keeps going there. Nothing re-targets; the hit cone at the hit moment takes whoever is there. |
| Melee: several enemies in the assist cone | Smallest angle off the aim wins, then the nearer one. |
| Melee: wall or pillar in the way | `WorldQuery.has_line_of_sight()` rules out enemies behind walls (no pull, no snap). The step itself is a `displace()`: it slides along a wall at an angle and stops on a head-on one. |
| Melee: step would end inside an enemy | The planned step is clamped to the gap between the two units' pathing radii; the unit bodies also collide, so the step stops at its edge and never pushes it. |
| Knockback on the player | The 12 px push (~0.1 s) is a hit knockback: walking waits for it, but a dash replaces it at once (i-frames as usual). Other displacements (Lunge, pulls, knockback from anything but being hit) still block the dash; a press then is buffered and fires as they end. |

## Known bugs
None open.
- ~~**Telegraph left on the floor when its caster dies mid-cast**~~ Fixed 2026-09-27 (the telegraph fix; the fix is Architecture, Ability / CastContext / AbilityComponent; details in CHANGELOG.md).

## Build order (one step per request)
STATS step 7 (the F3 overlay) comes after M1. For every step: no errors; the Knight's 4 abilities, enemies chasing and the HUD still work.

1. **C1 – Hit pipeline.** Built 2026-09-26, see CHANGELOG.md.
2. **C2 – Knight combo.** Built 2026-09-26, see CHANGELOG.md.
- **Melee basic attacks** (between C2 and C3). Built 2026-09-26, see CHANGELOG.md.
3. **C3 – Hit feel.** Built 2026-09-26, see CHANGELOG.md.
4. **C4 – Getting hit.** Built 2026-09-26, see CHANGELOG.md.
5. **C5 – Elite.** Built 2026-09-26, see CHANGELOG.md.
6. **C6 – Damage numbers.** Built 2026-09-26, see CHANGELOG.md.
7. **C7 – Line of sight.** Built 2026-09-26, see CHANGELOG.md.

**Milestone M1 – a one-room fight in the sandbox:** passed Ryan's play test 2026-09-26, see CHANGELOG.md.

8. **C8 – Crits and on-hit.** Built 2026-09-26, see CHANGELOG.md. **Done means** (awaiting play test): the ability numbers are unchanged with no crit or bonuses, and they crit once `crit_chance` > 0.
9. **C9 – Statuses.** Built 2026-09-27, see CHANGELOG.md. **Done means** (awaiting play test): in play nothing changes: Judgement's stun (stars, 0.75 s, no casting or dashing), Iron Resolve's haste (375 → 506.25 for 2 s; it was 560 → 739.6 when C9 was built) and its slow on the empowered swing work as before; the test covers stack rules, tenacity, DoT and events.
10. **C10 – Shields.** Built 2026-09-27, see CHANGELOG.md. **Done means** (awaiting play test): in play nothing changes (nothing gives a shield yet); the test covers absorbing, the order, stacks, numbers, and that an absorbed hit still lands.
- **Fix – Telegraph on caster death** (before C11). Built 2026-09-27, see CHANGELOG.md.
11. **C11 – Reaction rules.** Built 2026-09-27, see CHANGELOG.md. **Done means** (awaiting play test): in room_01 nothing changes; in the sandbox, hitting a stunned enemy (Judgement, then a swing or Cleave) adds a blue 30; the test covers world and unit rules, the three triggers, chains and the four effects.
12. **C12 – Dash-strike.** Built 2026-09-27, see CHANGELOG.md. **Done means** (awaiting play test): dash, then click within 0.15 s (or click during the dash): a heavier thrust with a longer step hits for 96; the next click continues the combo where it was; a later click is a normal swing.
- **A swing counts once its hit has landed** (Rules, Basic attack). Built 2026-09-27, see CHANGELOG.md (awaiting play test).

## Out of scope
Items and affixes (LOOT.md); ability costs, recasts and augments (ABILITIES.md); enemy AI beyond one telegraphed attack (ENEMIES_AI.md); elite modifiers (their format ENEMIES_AI.md's, how many per elite DUNGEONS.md's; "affix" is an item's line); pits; controller support.

## Open questions
- Weapons: a champion's combo will come from its equipped weapon, and its class limits which weapons it can wield (e.g. a bruiser like Darus can't use daggers); bruiser weapons are heavier, diver and rogue weapons snappier. Today the combo comes from the champion (`ChampionData.combo`, copied onto AutoAttackComponent at load; CHAMPIONS.md), and LOOT's weapons don't change it in this build (LOOT.md, Item slots).
- Ranged basic attacks: design later (RANGED combos only get walk-cancel for now).
- What attack_speed means for enemies (AutoAttackComponent).
- Sustain caps (life steal cap? regen during combat?).
- ~~**Poise or flinch** (ENEMIES_AI.md, Interview 8): does a hit interrupt a smart enemy's cast, and what tenacity elites and bosses get?~~ Answered (Ryan, ENEMIES_AI I8, 2026-10-03): **no flinch:** a hit never interrupts an enemy's cast, only a status that blocks casting does (this doc's rule, unchanged); **tenacity** 20% for elites and 40% for bosses, given by their rank at spawn (ENEMIES_AI.md, Poise).
- Healing between rooms (DUNGEONS.md).
- The crit font asset.
- Confirm the armor formula; is penetration needed? (Negative armor is settled: a core rule, Rules, Hits.)
- Life steal: basic attacks only *(proposed; built that way in C8)*, or every hit?
- On-hit damage type: MAGIC *(proposed, built in C8)*, the triggering hit's type, or set per item?
- Which Knight abilities should ignore walls: answered in CHAMPIONS.md *(proposed: none)*.
- Per-swing hit tags *(proposed by AUDIO.md's ring-out example; Ryan, 2026-10-04: noted for later, built when a champion needs it)*: `AttackSwing.hit_tags` (e.g. `finisher`) added to that swing's hits, so a HIT reaction rule can grant something on a particular swing ("the 4th hit grants an empower") with data. Built in Korsavil's K1 (2026-10-04): `finisher` on the last swing of each of her two cycles (her detonation; her 3-swing cycle's since K1).
