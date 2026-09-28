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
- Crits use PRD (pseudo-random distribution, as in League and Dota): the Nth roll since the attacker's last crit crits with chance C × N, where C is picked so the average is exactly `crit_chance` (25% → C 0.0847: 8.5%, 17%, 25%... a crit at the latest on the 12th roll). One roll per swing or ability cast: every enemy it hits crits, or none does, and the counter moves once. Ryan's call (2026-09-26).
- Damage types: PHYSICAL (armor), MAGIC (magic_resist), TRUE (ignores both). Proposed mitigation: damage × 100 / (100 + armor).
- Invulnerability (dash i-frames, post-hit i-frames) blocks the whole hit: damage, knockback, statuses and on-hit.
- Hit tags: basic_attack, ability, proc, dot, crit, the damage type, plus the source ability's tags.
- On-hit: basic attack and ability hits trigger on-hit effects; dot ticks and proc hits never do (loop guard). Each Ability has proc_coefficient (1.0 default, lower for multi-hit or area abilities), which scales on-hit chances and effects. Numbers (on_hit_damage, life_on_hit, resource_on_hit) are stats (STATS.md, built in C8); behaviors are augments or ReactionRules. On-hit damage is a separate MAGIC proc hit *(proposed)*.
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
- A status that blocks casting (stun, silence) applied during a cast time or a charge-up interrupts the cast at once, refunding its cost and cooldown (ABILITIES.md, Casting; built in AB1).
- **Unstoppable** (status tag `unstoppable`): immune to new cc, and applying it removes every cc status; it also blocks knockback from hits (not the unit's own dashes and swing steps). ABILITIES.md; built in AB10.
- **Untargetable** (status tag `untargetable`): the status adds an invulnerability under its id, so every hit is blocked, and `Unit.is_targetable()` is false, so targeting and aggro skip the unit. ABILITIES.md; built in AB10.
- **Empowers** ("your next attack / next ability") are statuses tagged `empower` whose bonus HitPipeline adds into the hit (ABILITIES.md, Empowers); Iron Resolve becomes one in AB10.

### Sustain
- Every champion starts with zero sustain (health_regen 0). Healing comes only from build choices: abilities, passives and items (life on hit, life steal, regen).

### Damage numbers
- Every hit shows a number above the target.
- Crits use a distinct font (proposed) and are larger.
- DoT ticks use a smaller style and are merged per target over a short window so they don't flood the screen.
- Size grows with the amount, in a few discrete pixel-font steps on a log scale, so late-game numbers don't all hit max size.
- Colors: by damage type (FREE, but readable); damage the player takes is red; healing is green; damage a shield absorbed is its own silver-blue number (C10).

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
| `Unit.take_damage(amount, source, highlight)` | Checks alive and invulnerable, lowers health, emits `damaged`, spawns a number, flashes. `Player.take_damage` adds a 2 px shake. Called by `AutoAttackComponent._land_attack`, `cleave.gd`, `lunge.gd`, `judgement.gd` and `Unit._on_hurtbox_hurt`. | **Wrapped** (C1, built): `make_hit_context()` builds a `HitContext` and `on_hit()` runs it from mitigation on. Armor is 0 everywhere, so nothing changes in play. `Player.take_damage`'s override is replaced by a `Player.on_hit` override with the same 2 px shake. Since C8 Cleave, Lunge and Judgement use `HitPipeline.from_ability()` instead; the League-style enemy attack and `_on_hurtbox_hurt` still use `make_hit_context()`. |
| `res://scripts/components/hitbox.gd`, `hurtbox.gd` | Area2D damage on overlap. `player.tscn` and `slime.tscn` have a Hurtbox (0.2 s own invincibility); **no scene has a Hitbox**. | **Kept, dormant.** `Unit._on_hurtbox_hurt` builds a `HitContext` (C1, built; the push is `Hitbox.knockback` px/s × 0.12 s, as before), so a future contact-damage enemy or projectile goes through the pipeline. |
| `Unit.add_invulnerability(id)` | Dash i-frames (`&"dash"`) block `take_damage()` and Hurtbox hits. | **Kept.** `Unit.on_hit` checks it first. Post-hit i-frames add `&"hit_iframes"` (`Unit.HIT_IFRAMES_ID`; C4, built); `has_invulnerability(id)`. |
| `res://scripts/autoload/game_feel.gd` (`GameFeel`) | `hitstop(duration)`: `Engine.time_scale` 0.05 (`hitstop_time_scale`). `shake(amount)`: camera shake in px (the camera keeps the largest). | **Kept, extended** (C3, built): the longest hitstop wins (a later call that ends later extends the running one); `play_hit_feel(ctx)` plays a hit's tier from `hit_feel`; `is_hitstop_active()`, `get_hitstop_left()`. |
| `Unit._flash()` | Body modulate ×3, back to white over `hit_feel.flash_time` (0.12 s before C3). | **Kept**, retuned to 0.06 s for every hit (C3, built). |
| `res://scripts/ui/damage_number.gd` | Label that pops in, rises and fades. Before C6: 2 sizes (10 / 13 px), orange when `highlight`, red on the player, rose 18 px. | **Restyled** (C6, built): look and motion from a `DamageNumberStyle`; kinds DAMAGE / CRIT / DOT / HEAL / SHIELD (C10); `add_amount()` merges DoT ticks. `Unit._spawn_damage_number()` (the old path) is kept but unused until Ryan confirms C6. |
| `Unit.apply_stun()` + `res://scripts/vfx/stun_effect.gd` | A `StunEffect` child node holds `&"stun"` move and attack locks; re-stunning keeps the longer time. `is_stunned()` = has that node. | **Wrapped** (C9, built): `apply_stun(duration, source = null)` applies `status_stun` (tenacity shortens it); the stars moved to `scenes/vfx/stun_stars.tscn`, that status's VFX. `is_stunned()` = any status tagged `stun`. `StunEffect` is kept, used only by a unit without a StatusComponent. |
| `MovementComponent.add_speed_modifier()` | Wrapper over `move_speed` StatModifiers; only the timer is on MovementComponent. | **Wrapped** (C9, built): with a StatusComponent each call applies a copy of `status_slow` (any negative part) or `status_haste` with that id, those `move_speed` modifiers (source `&"status_<id>"`) and that duration (−1 = until removed), REFRESH (the same id replaces); `remove_speed_modifier(id)` removes it. The timer is the StatusComponent's. Without one, the old path runs (the stats test uses it). |
| `MovementComponent.displace()` | A new displacement replaced the running one. | **Changed** (C4, built): the stronger displacement wins; `displace()` returns false when it's dropped. |
| `res://scripts/enemies/enemy.gd` | Wander, aggro, chase, attack. `passive` = training dummy. Aggro on `damaged`. | **Kept.** C5 (built): an enemy with an AbilityComponent (the elite) casts a ready ability when the player is within its `cast_range` and in sight, never mid-windup; a whiff still lunges (C4). |
| `res://scripts/main.gd` | "You died – press Backspace to restart" (`restart`), "Room cleared!". | **Kept.** Already covers "die and restart". |
| `res://scripts/abilities/ability_util.gd` | Cone, segment, circle queries using the target's gameplay radius. | **Kept, extended** (C7, built): `in_sight(from, units)` keeps only the units in line of sight (walls block, units don't; feet to feet). The shape queries themselves still ignore walls; callers filter. |

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
| `tags` | `Array[StringName]` | `&"basic_attack"`, `&"ability"`, `&"proc"`, `&"dot"`, `&"crit"`, `&"physical"` / `&"magic"` / `&"true"`, plus the ability's tags (`from_ability()` adds them since STATS step 6; the Knight's abilities use it since C8). League-style enemy attacks are tagged `basic_attack` too (C8) |
| `can_crit` | `bool` | false for DoT ticks and wrapped `take_damage()` calls |
| `crit_roll` | `HitContext.CritRoll` | shared by the hits of one swing or cast (the first hit rolls, the rest copy it); null = the hit rolls on its own |
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
- `AttackCombo` (Resource, `res://scripts/data/attack_combo.gd`): `attack_style` (`AttackCombo.AttackStyle.MELEE` default / `RANGED`), `swings: Array[AttackSwing]`, `combo_reset_time`, `dash_strike: AttackSwing` (the dash-strike swing, C12; null = dash-strikes use the normal next swing), `hit_forgiveness` (0.10), `speed_scale` (1.0: one knob that scales every swing timing; × attack speed).
  - Melee assist: `assist_range_bonus_px` (40, added to the swing's reach), `assist_angle_deg` (35), `assist_snap_deg` (20), `stop_at_reach_fraction` (0.7).
  - Recovery: `walk_cancels_recovery` (true), `recovery_move_cancel_after` (0.1 s).
- Knight: `res://data/combos/combo_knight.tres` with the three swings from Numbers (0.08 / 0.3 s, 0.08 / 0.3 s, 0.08 / 0.4 s; 1.0 / 1.0 / 1.6; 110° / 110° / 140°; 6 / 6 / 20 px over 0.1 s; LIGHT / LIGHT / HEAVY; steps 6 / 6 / 10 px, pull up to 24 / 24 / 32 px; MELEE with the default assist and recovery settings).

### HitFeel (Resource, `res://scripts/data/hit_feel.gd`; `res://data/hit_feels/hit_feel_default.tres`)
The hit feel per tier (Numbers, "Feel per hit"), held by `GameFeel.hit_feel`: `light_hitstop` 0.03, `heavy_hitstop` 0.06, `kill_hitstop` 0.08 (s); `light_shake` 0, `heavy_shake` 2, `kill_shake` 3 (px); `flash_time` 0.06 s, `flash_modulate` (3, 3, 3). Built in C3.

### DamageNumberStyle (Resource, `res://scripts/data/damage_number_style.gd`; `res://data/damage_number_styles/damage_number_style_default.tres`)
How damage numbers look (built in C6): `size_thresholds` 0 / 100 / 1000 → `font_sizes` 10 / 12 / 14 (steps of 10×, a log scale); crits +3 sizes, their own outline color, a "!" suffix and `crit_font` (null until the asset exists); DoT ticks size 8, merged per target within `dot_merge_window` 0.3 s; colors: physical orange (1, 0.72, 0.35), magic blue (0.55, 0.7, 1), true white, damage the player takes red (1, 0.3, 0.28), healing green (0.4, 1, 0.45), shield-absorbed silver-blue (0.78, 0.84, 0.92) (C10); motion: pop in at 1.35×, rise 12 px, fade over the second half of 0.6 s, ±6 px sideways spread. `get_font_size(amount)`, `get_damage_type_color(type)`.

### New fields on Ability
- `damage_type: HitContext.DamageType` (PHYSICAL; the Knight's descriptions already say physical)
- `proc_coefficient: float` (1.0)
- `cancels_swing: Ability.SwingCancel`: `NEVER`, `AFTER_HIT` (default; the Knight's four abilities use it), `ANYTIME`
- `ignores_walls: bool` (false): true = hits don't need line of sight (e.g. a meteor shower). `filter_by_walls()` / `can_reach_through_walls()` apply it (C7).

### StatusEffect (Resource, `res://scripts/data/status_effect.gd`; files `res://data/statuses/status_<name>.tres`)
- `id: StringName` (`&"stun"`; its modifier source id is `&"status_stun"`, CONVENTIONS), `display_name`
- `tags: Array[StringName]`: `&"cc"`, `&"stun"`, `&"root"`, `&"silence"`, `&"slow"`, `&"buff"`, `&"debuff"`, `&"dot"`, `&"shield"`...
- `duration` (s; −1 = until removed)
- `stack_rule`: `REFRESH_LONGER` (keep the longer remaining time; the stun today), `REFRESH` (restart, with the new numbers and source), `STACK` (add a stack up to `max_stacks`, each with its own time; at max the one closest to running out restarts), `IGNORE`
- `get_source_id()` = `&"status_<id>"`, `is_cc()`, `is_dot()` (built in C9)
- `modifiers: Array[StatModifier]` (slows and hastes are `move_speed` modifiers)
- `blocks_move`, `blocks_attack`, `blocks_cast`, `blocks_dash` (stun: all four; root: move and dash; silence: cast)
- DoT: `tick_interval` (0 = none), `tick_damage`, `tick_ad_ratio`, `tick_damage_type` (MAGIC default). Damage is snapshotted from the applier's stats when applied (a new stack or refresh takes a new snapshot for every stack).
- `shield_amount` (C10, built): damage it absorbs after mitigation and `incoming_damage`, per application (each stack has its own); 0 = not a shield (`is_shield()`). Used up = that stack ends (the status with its last stack). REFRESH restores the full amount, REFRESH_LONGER keeps the bigger one. Template: `data/statuses/status_shield.tres` (100, 3 s, tags `shield` + `buff`, REFRESH).
- `vfx: PackedScene` (visuals only)
- Files (C9): `status_stun.tres` (tags cc / stun / debuff, blocks all four, REFRESH_LONGER, 1.0 s default (`apply_stun()` passes its own), VFX `res://scenes/vfx/stun_stars.tscn`), `status_slow.tres` (cc / slow / debuff, −30% `move_speed`, REFRESH, 1.5 s), `status_haste.tres` (haste / buff, +20% `move_speed`, REFRESH, 2 s).

### ReactionRule and GameplayEffect (`res://scripts/data/`; rules in `res://data/reactions/reaction_<name>.tres`)
- `ReactionRule`: `id`, `trigger` (`IMPACT`, `HIT`, `HAZARD_ENTERED`, `HAZARD_EXITED`, `STATUS_APPLIED`, `UNIT_DIED`, `HAZARD_OVERLAP`), `required_hit_tags`, `required_unit_tags` (the affected unit's status tags), `required_status_tags` (STATUS_APPLIED: the applied status's tags; added in C11), `required_surface_tags`, `min_impact_speed_px`, `chance` (for `HIT`: × the hit's `proc_coefficient`), `effects: Array[GameplayEffect]`, plus (C11):
  - `effect_target`: `AFFECTED` (default) or `OTHER`. Every event has an affected unit and an other unit: HIT = the unit hit / the attacker; UNIT_DIED = the unit that died / the killer; STATUS_APPLIED = the unit that got it / who applied it.
  - `owner_role` (unit rules only): `SOURCE` (default; the owner is the other unit: "when I hit / kill / apply…") or `AFFECTED` ("when I'm hit / die / get…").
  - `chain_limit` (1–5, default 1): how many reactions in a row the rule may take part in; set by the ability, passive or item that grants it. `ReactionRule.MAX_CHAIN` = 5 caps every chain (Ryan, 2026-09-27).
  - `conditions: Array[Condition]` (ABILITIES AB12, not built yet): the shared condition resource (unit state: statuses, health, distance, enemies in range...), all must pass after the tag filters and before `chance`. Specified in ABILITIES.md, Conditions.
- Two kinds of rules, the same Resource (Ryan, 2026-09-27):
  - **World rules** apply to everyone: every `.tres` in `res://data/reactions/world/` (loaded at start), plus `Reactions.add_world_rule(rule, source_id)` / `remove_world_rules_from(source_id)` (rooms, hazards, run modifiers later). Their effects' source is the event's other unit.
  - **Unit rules** belong to one unit, from its items, passives or buffs: `Unit.add_reaction_rule(rule, source_id)`, `remove_reaction_rules_from(source_id)`, `get_reaction_rules()`. Their effects' source is the owner.
- Autoload **`Reactions`** (`res://scripts/autoload/reactions.gd`, C11) listens to `Events.unit_hit`, `unit_died` and `status_applied` and fires every matching rule: trigger, chain depth, all required tags, then `chance` (rolled on `Reactions.rng`, seedable). Unit tags for HIT and UNIT_DIED come from `HitContext.target_tags` (the target's status tags just before the hit, filled in by `Unit.on_hit`; a kill clears the statuses). Because HIT's chance is × `proc_coefficient`, DoT ticks and procs (coefficient 0) never trigger HIT rules.
- Chains: effects run synchronously, so an event they cause is one link deeper (`Reactions.get_chain_depth()`); a rule fires on an event at depth d only if d < min(`chain_limit`, 5). Later consequences (the ticks of a DoT a rule applied) start again at depth 0.
- `GameplayEffect` (base): `apply(target: Unit, source: Unit, trigger_ctx: RefCounted) -> void` (`trigger_ctx`: the HitContext for HIT and UNIT_DIED, the StatusEffect for STATUS_APPLIED). Subclasses (C11):
  - `ApplyStatusGameplayEffect`: `status`, `duration` (−1 = its own).
  - `DealDamageGameplayEffect`: `base_damage`, `ad_ratio` (the source's), `damage_type` (MAGIC default), extra `tags`; a `proc` hit (`HitPipeline.make_proc()`): can't crit, triggers no on-hit and no HIT rules.
  - `KnockbackGameplayEffect`: `distance_px`, `duration`; away from the source, dash-cancelable; nothing without a source.
  - `HealGameplayEffect`: `amount` + `max_health_ratio` × max health (`Unit.heal()`, green number).
  - ABILITIES AB8 (built) adds `ModifyCooldownGameplayEffect`, `RestoreResourceGameplayEffect`, `CastAbilityGameplayEffect` and `RemoveStatusesByTagGameplayEffect`, the trigger `ABILITY_CAST` (an ability's effect started; added last in the enum), `required_ability_scope`, and `HitContext.chain_depth` (a free cast's hits count deeper); specified in ABILITIES.md.
- Only `HIT`, `UNIT_DIED` and `STATUS_APPLIED` are built in C11 (ABILITY_CAST in ABILITIES AB8). `IMPACT` and the hazard triggers come with WORLD_INTERACTION's impacts and Hazards. Effects hit one unit; area effects ("explode on death") come later.
- Demo (sandbox only): `res://data/reactions/reaction_shatter.tres` (HIT on a `stun`-tagged target → a 30 MAGIC proc tagged `shatter`, the attacker's rule, chain_limit 1), given to the player by the `SandboxReactions` node in `sandbox.tscn` (`res://scripts/rooms/sandbox_reactions.gd`, source `&"sandbox_demo"`). room_01 has none.

### New stats (STATS.md; neutral defaults, built in C8)
`incoming_damage` (base 1.0; reductions are negative PERCENT_MULT modifiers, so two 20% reductions give × 0.64), `damage_increase` (0; "increased" damage, 0.2 = +20%, given as FLAT modifiers; read with `hit:<tag>` and `target:<tag>` scopes), `on_hit_damage`, `life_on_hit`, `resource_on_hit` (all 0). `crit_damage` defaults to 1.75. `crit_chance` and `crit_damage` take the same scopes.

## Architecture / contracts
### New scripts
- `res://scripts/autoload/events.gd`, autoload **`Events`** (C1, built). Signals (reserved names): `unit_hit(ctx: HitContext)`, `unit_damaged(ctx: HitContext)`, `unit_died(unit: Unit, ctx: HitContext)`; `status_applied(unit: Unit, status: StatusEffect)` and `status_removed(unit: Unit, status: StatusEffect)` (C9, built). Existing local signals (`Unit.died`, `Unit.damaged`) stay.
- `res://scripts/combat/hit_pipeline.gd`, **`HitPipeline`** (static functions, C1).
  - `static func resolve(ctx: HitContext) -> HitContext`: stages 1–4 (base, stat scaling from the source's StatsComponent, `damage_increase`, crit), then `ctx.target.on_hit(ctx)`. A target without `on_hit()` = `blocked`. Built in C1: base and scaling; C8: `damage_increase` and crit.
  - C8 (built): the damage type tag is added first; `get_hit_scopes(ctx)` = `hit:<tag>` per hit tag + `target:<tag>` per target status tag (`Unit.get_status_tags()`); `raw = scaled × (1 + damage_increase)` (the source's `StatsComponent.get_scoped_stat(&"damage_increase", scopes)`); `roll_crit(ctx, scopes)`: skipped when `can_crit` is false or there's no source; a hit whose `crit_roll` is already decided copies it; otherwise `roll_prd(source, chance)`: chance ≥ 1 always crits, ≤ 0 never rolls, else `min(C × (source.crit_misses + 1), 1)` against `HitPipeline.crit_rng` (seedable), then `Unit.crit_misses` resets on a crit or goes up by 1; `get_prd_constant(chance)` finds C by bisection (cached). A crit multiplies raw by `crit_damage`, sets `is_crit` and adds `&"crit"`. The combo swing, Cleave, Lunge and the elite slam share one `CritRoll` per swing or cast.
  - `static func apply_on_hit(ctx)` (C8, built; called by `Unit.on_hit`) and `static func make_proc(source, target, amount) -> HitContext` (a MAGIC `proc` hit that can't crit, proc coefficient 0).
  - Helpers (C1): `get_scaled_damage(ctx)`, `get_mitigation_multiplier(resistance)`, `mitigate(amount, type, target_stats)`.
  - `static func basic_attack(source: Unit, target: Unit, swing: AttackSwing) -> HitContext` and `static func from_ability(caster: Unit, ability: Ability, target: Unit) -> HitContext`: builders that fill tags, type, ratios and feel.
- `Unit.on_hit(ctx: HitContext) -> void` (C1), the same method name interactables use (WORLD_INTERACTION.md). In order:
  1. `blocked` if not alive or invulnerable → return (nothing else happens).
  2. Mitigation by type, then × the target's `incoming_damage` (C8, built).
  3. Shields (`StatusComponent.absorb_damage()`, C10, built: `ctx.absorbed`), then `health.take_damage()` with the rest (`ctx.health_lost`). `taken_damage` still includes the absorbed part.
  4. Knockback (`movement.displace()`, even if a shield took all of it), then statuses.
  5. `damaged.emit()`, `Events.unit_hit`, `Events.unit_damaged` (when `taken_damage` > 0).
  6. On-hit (only `basic_attack` or `ability` hits, never `proc` or `dot`; a blocked hit has none): `on_hit_damage` × `proc_coefficient` as a MAGIC `proc` hit on the same target, `life_on_hit` × `proc_coefficient` plus `life_steal` × `taken_damage` (basic attacks only, proposed) heal the source with a green number (`Unit.heal()`), `resource_on_hit` × `proc_coefficient` restores its resource. Built in C8 (`HitPipeline.apply_on_hit()`); it runs after the events and before post-hit i-frames start, so the i-frames a hit starts never block its own proc. Procs don't start i-frames.
  7. Death: `Events.unit_died(self, ctx)`; kill credit = `ctx.source`.
  8. Feel: `GameFeel.play_hit_feel(ctx)` (C3, built): the hit's tier (a kill uses the kill tier) sets the hitstop and shake; feel NONE plays nothing, so abilities and enemy basic attacks keep their own. Every hit that gets through flashes and shows its number (`_spawn_hit_number(ctx)`, C6, built): size by `taken_damage`, crit style if `is_crit`, the DoT style (merged into the target's latest DoT number within 0.3 s) if tagged `dot`, color by damage type (red on the player). Blocked hits show nothing. `Unit.show_heal_number(amount)` shows a green "+N"; `Unit.heal(amount)` (C8) heals and shows it for what was actually healed (life on hit, life steal). Health regen doesn't show numbers.
- `Unit.take_damage(amount, source, highlight)` stays, as a wrapper (built in C1 through `Unit.make_hit_context()`): a `HitContext` with `base_damage = amount`, PHYSICAL, `can_crit = false`, feel `NONE` (callers keep their own shake and hitstop), then `on_hit()` directly (the amount is already scaled). `Player`'s "got hit" shake moves to a `Player.on_hit` override so pipeline hits get it too.
- `res://scripts/components/status_component.gd`, **`StatusComponent`** (C9, built), a child of every Unit (`Unit.status_component`, optional so old scenes still load; `player.tscn` and `slime.tscn` have one, so the elite and dummies too).
  - `apply_status(effect: StatusEffect, source: Unit = null, duration_override: float = -1.0) -> bool` (tenacity: × (1 − tenacity) for `cc`-tagged statuses only; false for a dead unit, IGNORE while active, or a zero duration), `remove_status(id)`, `clear()` (death), `has_status(id)`, `has_tag(tag)`, `get_tags()`, `get_status(id)`, `get_status_ids()`, `get_time_left(id)` (−1 = until removed), `get_stacks(id)`, `get_source(id)`, `blocks_cast()`, `blocks_dash()`. `absorb_damage(amount) -> float` (C10, built): the shields expiring soonest go first, "until removed" ones last, ties by status id; returns the amount absorbed. `get_shield(id)`, `get_total_shield()`.
  - Signals `status_applied(effect)` (also on a refresh or a new stack), `status_removed(effect)`, re-emitted on `Events.status_applied(unit, status)` / `status_removed(unit, status)`.
  - While active: the effect's `modifiers` once per stack under `&"status_<id>"`; `blocks_move` / `blocks_attack` as `add_move_lock(id)` / `AutoAttackComponent.add_lock(id)` (the stun's lock id stays `&"stun"`; an attack lock also cancels a windup or swing); `vfx` instanced as a child of the unit. Timers run in `_physics_process` (game time: they follow hitstop and pausing) and treat ≤ 0.0001 s as done.
  - Stack rules: REFRESH_LONGER keeps the longer time; REFRESH replaces effect, source and time; STACK adds a stack with its own time up to `max_stacks`, and at max restarts the stack closest to running out; IGNORE does nothing while active.
  - DoT: a tick every `tick_interval`, the first one interval after it's applied: a hit through `HitPipeline.resolve()` from the applier (kill credit; null once freed), `base_damage` = (`tick_damage` + `tick_ad_ratio` × the applier's attack_damage when applied) × stacks, `tick_damage_type` (MAGIC default), tags `dot` + the status's tags, can't crit, proc coefficient 0 (no on-hit), no post-hit i-frames. `damage_increase` is read live at each tick.
- **Unit** (C9, built): `status_component`; `apply_stun(duration, source = null)`; `is_stunned()` (a `stun`-tagged status); `is_cast_blocked()` / `is_dash_blocked()` (stunned, or a status with `blocks_cast` / `blocks_dash`; AbilityComponent's `can_cast()` and cast interruption and DashComponent's `can_dash()` use them instead of `is_stunned()`); `get_status_tags()` returns the StatusComponent's tags; `on_hit` applies `ctx.statuses` after knockback (from `ctx.source`), none on a blocked hit; death calls `status_component.clear()`. MovementComponent gets `set_status_component()`.
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
  - Dash-strike (C12, built): `try_swing(direction, true)` with a combo `dash_strike` swing runs that swing with index −1 (`swing_started` / `swing_landed` report −1; `get_combo_index()` is −1 during it; `is_dash_strike()`), its hits are tagged `dash_strike` as well as `basic_attack`, and when it finishes the next swing is the one it interrupted (a fresh `combo_reset_time` window starts). Cancelling it resets the combo like any swing. Player: its slash uses the finisher's brighter look.
- **PlayerInput** (C2): `attack_pressed` → `player.attack.try_swing(player.get_aim_direction(), dash_strike)`.
  - Attack is legal when not stunned, casting, dashing or swinging.
  - An ability press during a swing is legal only if its `cancels_swing` allows it at that moment (then the swing is cancelled first).
  - The buffer timer also pauses while a swing plays out, so a press early in a 0.3 s swing isn't lost after 0.15 s.
- **DashComponent** (C2): `try_dash()` cancels a swing in windup or recovery (not on the hit frame; the hit resolves inside one physics frame, so there's nothing to cancel) with `cancel_swing(true)`: after the hit the combo moves on (2026-09-27).
- **AutoAttackComponent** (2026-09-27): `cancel_swing(keep_combo_if_landed = false)`: with the flag and a landed hit, the next swing is the one after it (the dash-strike: the swing it interrupted) and `combo_reset_time` restarts; otherwise the combo resets. `add_lock(id)` passes the flag only for the casting lock (`CASTING_LOCK`, a cast the player chose); stuns and other status locks and `cancel()` (death) reset.
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
- **Unit** (C4, built): `@export var post_hit_iframes: float` (0 = none; `player.tscn` 0.3). A hit that gets through adds `&"hit_iframes"` for that long in game time (it follows hitstop and pausing); DoT ticks don't start it. **Player** blinks while it lasts (`hit_iframes_blink_period` 0.1 s; visual only).
- **Unit / MovementComponent** (C4, built): every knockback from `Unit.on_hit` uses `displace(..., dash_cancelable = true)`, so a unit that can dash (the player) dashes out of it at once. Any other displacement still blocks the dash.
- **Enemy** (C5, built): `_try_cast_ability()` in AGGRO: for each ready slot (q, w, e, r), cast at the player's position if the player is within `cast_range` of the enemy's center and in sight, and the enemy isn't mid-windup. The cast time is the telegraph; the cast roots it (and a stun during the cast time interrupts it at once, as for every ability; ABILITIES AB1).
- **Ability / CastContext / AbilityComponent** (C5, built): `Ability.on_cast_started(caster, ctx)` (virtual, called right after `cast_started`) lets an ability show a telegraph during its cast time; it sets `CastContext.telegraph`, and AbilityComponent frees it if the cast is cancelled (dash, move) or interrupted (stun, death). Death ends the cast at once (telegraph fix, built): `Unit._on_died()` calls `AbilityComponent.interrupt_cast()`, which during the cast time frees the telegraph, releases the cast's locks, refunds the cooldown for a living caster and emits `cast_finished` (no `cast_cancelled`; returns false with no cast running or once `execute()` has started). A caster freed without dying frees its telegraph in `NOTIFICATION_PREDELETE`, since its waiting `_do_cast()` never resumes.
- **Knight abilities** (C8): Cleave, Lunge and Judgement hit through `HitPipeline.from_ability()`; Judgement's missing-health bonus is added to the base damage. Cleave's push and Judgement's stun skip blocked hits. Iron Resolve's bonus rides the swing's own pipeline hit.
- **Elite slam** (`res://scripts/abilities/slime/slam.gd`, `res://data/abilities/slime_elite_q_slam.tres`, C5): POINT at the player's position at cast start (cast_range 250 u = 80 px), 0.65 s cast (the telegraph), 72 px circle (hit radius × 0.9, enemy forgiveness), 100 PHYSICAL through `HitPipeline.from_ability()`, 20 px push away from the elite, its own hitstop 0.06 s and 3 px shake when it lands, 4 s cooldown.
- **Elite slime** (C5): `res://scenes/enemies/slime_elite.tscn` inherits `slime.tscn` (purple, ×1.4 body, 19 px collider, an AbilityComponent with the slam); `res://data/units/slime_elite.tres`: 900 health, 30 basic attack damage with a 0.25 s windup, 260 move speed. One (`Elite1`) sits in the sandbox's open top-right corner (784, 112).

## How each edge case is handled
| Edge case | Handling |
|---|---|
| On-hit proc on the player | The proc resolves before the hit's post-hit i-frames start, so it lands; it starts none of its own. A proc can't trigger another on-hit (`proc` tag). |
| Stunned mid-swing | A stun adds the `&"stun"` attack lock; `AutoAttackComponent.add_lock()` calls `cancel_swing()`: no hit, root released, combo index back to 0. |
| Dash or cast after the hit | The swing counts: `cancel_swing(true)` sets the next swing as if it had finished (after a finisher: swing 1, with its breather; after a dash-strike: the swing it interrupted) and restarts `combo_reset_time`. In the windup it resets the combo. A stun after the hit still resets it. |
| Hit during i-frames | `Unit.on_hit` returns at step 1 with `blocked = true`: no damage, number, knockback, status, on-hit, events or reaction rules. `take_damage()` does the same through the wrapper. |
| Kill during hitstop | The hit resolves normally; `unit_died` fires at once. The kill hitstop (0.08 s) extends the running one. The death tween runs in scaled time, so it plays out after the freeze. |
| Several hits in the same frame | On enemies all of them resolve in order, each with its own number; hitstop = the longest; shake = the largest (the camera already keeps the max). On the player the first hit lands and starts post-hit i-frames, and the rest are blocked. |
| Overlapping hitstops | `GameFeel` keeps one end time and only extends it. |
| Two knockbacks | `displace()` keeps whichever has more distance left to cover (C4). A stun doesn't stop a knockback (DECISIONS, Movement). |
| Target dies before the swing lands | Swings aren't target-locked: the cone query at the hit moment takes whoever is there; with nobody there the swing whiffs (full animation, no hitstop). Enemy LoL attacks: a dead target cancels the windup (existing). |
| Caster dies or is freed mid-cast | The cast ends at once through `interrupt_cast()`: its telegraph disappears the same frame, no hit lands, `cast_finished` fires once. Freed without dying: the telegraph goes with it (`NOTIFICATION_PREDELETE`). Once `execute()` has started, the effect plays out. |
| Attacker dies mid-swing | `Unit._on_died()` calls `attack.cancel()`, which also cancels the swing: no hit. Hits that already resolved stay. |
| Walls | Swing targets need `WorldQuery.has_line_of_sight(feet → target feet)`. Abilities filter the same way unless `ignores_walls`; UNIT abilities also need line of sight to start the cast. Per attack (C7): League-style enemy attacks with a wall in between whiff; walls block Cleave; Lunge checks sight from the nearest point of its path; the elite slam from its circle's center; Judgement (UNIT) treats out of sight like out of range, so it walks until it can see the target, and a target that goes behind a wall during the cast is missed. |
| Shield absorbs a hit | Knockback and statuses still apply; `taken_damage` still counts for life steal and `unit_damaged`; post-hit i-frames still start; a fully absorbed hit can't kill. The number shows the absorbed part as its own number in `shield_color` (DoT ticks: small, not merged), and the rest (if ≥ 0.5) as usual (C10, built). |
| DoT ticks can't crit | DoT contexts have `can_crit = false`. |
| Melee: target moves or dies during the step | The step's end point is planned at swing start (velocity × windup); it keeps going there. Nothing re-targets; the hit cone at the hit moment takes whoever is there. |
| Melee: several enemies in the assist cone | Smallest angle off the aim wins, then the nearer one. |
| Melee: wall or pillar in the way | `WorldQuery.has_line_of_sight()` rules out enemies behind walls (no pull, no snap). The step itself is a `displace()`: it slides along a wall at an angle and stops on a head-on one. |
| Melee: step would end inside an enemy | The planned step is clamped to the gap between the two units' pathing radii; the unit bodies also collide, so the step stops at its edge and never pushes it. |
| Knockback on the player | The 12 px push (~0.1 s) is a hit knockback: walking waits for it, but a dash replaces it at once (i-frames as usual). Other displacements (Lunge, pulls, knockback from anything but being hit) still block the dash; a press then is buffered and fires as they end. |

## Known bugs
None open.
- ~~**Telegraph left on the floor when its caster dies mid-cast**~~ Fixed 2026-09-27 (the telegraph fix in Build order; CHANGELOG.md). Found reading the code while writing AUDIO.md, then reproduced in Godot 4.7.2. `Unit._on_died()` doesn't end the current cast; `AbilityComponent._do_cast()` removes the telegraph only when the cast time ends. The death tween frees the unit after about 0.33 s, and the slam's cast time is 0.65 s, so an elite killed early in its slam is freed before the cast time ends. GDScript can't resume an `await` whose object is gone, so `_remove_telegraph()` never runs (silently: no error was printed), and the telegraph stays on the floor, full, forever. That misleads the player (clarity), and AUDIO A3's wind-up sound, owned by the telegraph, would never stop.

## Build order (one step per request)
Combat starts now, before STATS step 6. Until step 6 adds `id` / `tags` to Ability, hits carry no ability tags. STATS step 6 runs before C8 (C8's `hit:<tag>` scopes need scoped modifiers); STATS step 7 (the F3 overlay) comes after M1.

1. **C1 – Hit pipeline.** `Events`, `HitContext`, `HitPipeline`, `Unit.on_hit`; `take_damage()` and `_on_hurtbox_hurt` wrapped; `damage_type` and `proc_coefficient` on Ability. A test scene `res://scenes/tests/combat_test.tscn` (script in `scripts/tests/`).
   **Done means:** the test passes: mitigation for all three types at 0 / 100 armor, i-frames block everything, the events fire (`incoming_damage` is checked in C8, where the stat is added). In play nothing changes: abilities deal the same numbers and slimes chase and hit as before.
   C1 built 2026-09-26, see CHANGELOG.md.
2. **C2 – Knight combo.** `AttackSwing`, `AttackCombo`, `combo_knight.tres`, the combo mode, PlayerInput/Dash/Player changes, `cancels_swing`, `select` unbound, Iron Resolve through swings.
   **Done means:**
   - A click swings toward the cursor within 0.08 s; three clicks give the three swings (the third wider and stronger); 0.6 s without attacking resets the combo.
   - Each swing roots; a dash during windup or recovery cancels it and resets the combo (since 2026-09-27 a dash after the hit keeps the combo; Rules, Basic attack).
   - A click during a swing queues the next one; Q during a swing's windup waits for the hit, then cuts the recovery (AFTER_HIT).
   - Iron Resolve's next swing slows every slime it hits; a stun mid-swing cancels it.
   - The Knight's abilities, enemies chasing and the HUD still work.
   C2 built 2026-09-26, see CHANGELOG.md.
- **Melee basic attacks** (between C2 and C3): swing step, target pull with aim snap, walk-cancel of the recovery, `attack_style`, minimal `WorldQuery`.
   **Done means:** swinging at empty air moves the Knight forward a few px per swing; aiming roughly at a slime from a bit outside reach pulls the Knight in and the swing connects; aiming 60° away doesn't pull; a slime behind the pillar is never pulled toward; after a swing lands, a direction starts walking almost at once and the next click continues the combo; setting the Knight's combo to RANGED turns off the step, pull and snap (walk-cancel still works); enemies attack exactly as before; the dash, the Knight's 4 abilities and the HUD still work.
   Melee basic attacks built 2026-09-26, see CHANGELOG.md.
3. **C3 – Hit feel.** Feel tiers from `HitContext.feel` (light / heavy / kill), longest-wins hitstop, 0.06 s flash, shake per tier.
   **Done means:** swings 1–2 freeze briefly with no shake; the finisher and kills freeze longer and shake; abilities feel as before.
   C3 built 2026-09-26, see CHANGELOG.md.
4. **C4 – Getting hit.** Post-hit i-frames, 12 px knockback on the player (marked as hit knockback, which a dash replaces), enemy whiffs out of reach, stronger-knockback-wins, slime windup retuned into 0–0.3 s.
   **Done means:** walking out of a slime's lunge avoids it; three slimes hitting at once cost one hit; after a hit the player is safe for 0.5 s (visible; 0.3 s since M1); a hit pushes the player 12 px, and pressing dash during the push dashes at once.
   C4 built 2026-09-26, see CHANGELOG.md.
5. **C5 – Elite.** `slime_elite.tscn` (inherits `slime.tscn`) + `data/units/slime_elite.tres` (starting values: 900 health, 100 damage = 15% of the Knight's 650), a telegraphed slam ability (0.75 s telegraph, about 40 px circle; 0.65 s / 72 px since M1), `Telegraph`, the Enemy cast hook, one elite in the sandbox.
   **Done means:** the elite shows a filling floor circle before each slam; dashing or walking out avoids it; standing in it costs about 15% health.
   C5 built 2026-09-26, see CHANGELOG.md.
6. **C6 – Damage numbers.** 3 log-scale size steps, crit style (placeholder until the font), colors by type, the player's damage red, healing green, DoT merge, rise 12 px / fade 0.6 s.
   **Done means:** finisher numbers are visibly bigger than swings 1–2; the player's damage shows red; nothing overlaps unreadably with 5 slimes.
   C6 built 2026-09-26, see CHANGELOG.md.
7. **C7 – Line of sight.** The filter in swing hits and `AbilityUtil`, `ignores_walls` on Ability (`WorldQuery.has_line_of_sight()` already exists, built with the melee pull).
   **Done means:** swings and Cleave don't hit a dummy behind the sandbox pillar; an ability with `ignores_walls` does.
   C7 built 2026-09-26, see CHANGELOG.md.

**Milestone M1 – a one-room fight in the sandbox:** the Knight fights with the combo, slimes chip, one elite telegraphs a slam, and the player can die ("You died", Backspace restarts) and win ("Room cleared!").
   M1 passed Ryan's play test 2026-09-26, see CHANGELOG.md.

8. **C8 – Crits and on-hit.** Crit (1.75 default), `damage_increase` scopes, `incoming_damage`, the on-hit stats, `proc_coefficient`. Migrate the Knight's 4 abilities from `take_damage()` to `HitPipeline.from_ability()`, so ability hits get crits, `damage_increase`, on-hit and proper tags.
   **Done means:** the ability numbers are unchanged with no crit or bonuses, and they crit once `crit_chance` > 0.
   C8 built 2026-09-26, see CHANGELOG.md.
9. **C9 – Statuses.** `StatusComponent`, `StatusEffect`, `status_stun` / `status_slow` / `status_haste`, the `apply_stun()` and `add_speed_modifier()` wrappers, tenacity, DoT with kill credit.
   **Done means:** in play nothing changes: Judgement's stun (stars, 0.75 s, no casting or dashing), Iron Resolve's haste (560 → 739.6 for 2 s) and its slow on the empowered swing work as before; the test covers stack rules, tenacity, DoT and events.
   C9 built 2026-09-27, see CHANGELOG.md.
10. **C10 – Shields** (shield statuses; absorb order: the one expiring soonest first, proposed).
   **Done means:** in play nothing changes (nothing gives a shield yet); the test covers absorbing, the order, stacks, numbers, and that an absorbed hit still lands.
   C10 built 2026-09-27, see CHANGELOG.md.
- **Fix – Telegraph on caster death** (before C11; Known bugs). A caster that dies (or is freed) mid-cast frees its telegraph at once and its cast ends cleanly: `AbilityComponent.interrupt_cast()`, called by `Unit._on_died()`, and a `NOTIFICATION_PREDELETE` guard (Architecture, Ability / CastContext / AbilityComponent).
   **Done means:** killing the elite at any point of its slam removes the circle at once, with no errors in the output; a stun or dash cancel still removes it as before; the elite's slam, the Knight's abilities, enemies chasing and the HUD still work.
   Telegraph fix built 2026-09-27, see CHANGELOG.md.
11. **C11 – Reaction rules** (`HIT`, `UNIT_DIED`, `STATUS_APPLIED`; the four GameplayEffects). It adds no "play sound" GameplayEffect: a rule makes a sound only through the status it applies or the proc hit it causes (AUDIO.md).
   **Done means:** in room_01 nothing changes; in the sandbox, hitting a stunned enemy (Judgement, then a swing or Cleave) adds a blue 30; the test covers world and unit rules, the three triggers, chains and the four effects.
   C11 built 2026-09-27, see CHANGELOG.md.
12. **C12 – Dash-strike** (answered 2026-09-27, see Rules and Numbers): the Knight's `dash_strike` swing in `combo_knight.tres`, `dash_strike_window` 0.15 s, the combo kept across it.
   **Done means:** dash, then click within 0.15 s (or click during the dash): a heavier thrust with a longer step hits for 96; the next click continues the combo where it was; a later click is a normal swing.
   C12 built 2026-09-27, see CHANGELOG.md.

For every step: no errors; the Knight's 4 abilities, enemies chasing and the HUD still work. If a step needs removing or rewriting existing code, stop and explain why first.

## Out of scope
Items and affixes (LOOT.md); ability costs, recasts and augments (ABILITIES.md); enemy AI beyond one telegraphed attack (ENEMIES_AI.md); elite affixes; pits; controller support.

## Open questions
- Weapons: a champion's combo will come from its equipped weapon, and its class limits which weapons it can wield (e.g. a bruiser like Darus can't use daggers); bruiser weapons are heavier, diver and rogue weapons snappier. Today the combo is set on AutoAttackComponent (LOOT.md / CHAMPIONS.md).
- Ranged basic attacks: design later (RANGED combos only get walk-cancel for now).
- What attack_speed means for enemies (AutoAttackComponent).
- Sustain caps (life steal cap? regen during combat?).
- Healing between rooms (DUNGEONS.md).
- The crit font asset.
- Confirm the armor formula; is penetration needed? Negative armor *(proposed: LoL's 2 − 100 / (100 − armor))*.
- Life steal: basic attacks only *(proposed; built that way in C8)*, or every hit?
- On-hit damage type: MAGIC *(proposed, built in C8)*, the triggering hit's type, or set per item?
- Which Knight abilities should ignore walls: CHAMPIONS.md / ABILITIES.md.
