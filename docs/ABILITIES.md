# ABILITIES.md: The Ability Framework, Cast Styles, Costs, Recasts, Projectiles and Augments

**Read when:** the task involves abilities, casting, cast styles, charge-up, damage scalings, tooltips, ability tags, costs, cooldowns, charges, recasts, projectiles, augments, forms, empowers, conditions or blinks.
**Depends on:** CLAUDE.md, CONVENTIONS.md (names, tags, reserved names), STATS.md (scoped params, `get_param()`, ResourceComponent, ability haste), COMBAT.md (HitPipeline, HitContext, statuses, ReactionRule and GameplayEffect, telegraphs), MOVEMENT.md (the input buffer, the dash, facing), WORLD_INTERACTION.md (WorldQuery, movement methods, Hazards), AUDIO.md (ability hooks).
**Used by:** CHAMPIONS (kits; passives are built on this toolkit), LOOT (items: scoped modifiers and augments), ENEMIES_AI (enemies cast through the same AbilityComponent), UI (tooltips, the ability bar), DUNGEONS (run modifiers that grant rules or augments), COMPANIONS (a companion's command in the fifth slot; abilities that consume the companion).

## How to read this doc
Same as COMBAT.md: MUST (never change without asking Ryan), TARGET (start value and allowed range), FREE (your call; tiebreaker: VISION.md's decision priorities).

## Player experience
Every champion's kit reads at a glance and feels instant: press, and it goes where you aimed. Some abilities ask for more: hold to charge a shot that reaches farther and hits harder, stand still to channel. Abilities chain into swings and dashes. Costs and cooldowns make each cast a choice, not a spam button. Gear doesn't just make abilities bigger; it changes what they do: Lunge starts stunning, Cleave becomes a wave, a kill resets your ultimate. Two runs with the same champion can play very differently.

## References
- League of Legends. Take: one clear identity per kit (passive, three abilities, an ultimate); costs by resource type; cooldowns and ability haste; damage ratios (AD, bonus AD, AP, % health); tooltips that show real numbers; recasts; charges; charge-up abilities (Xerath Q, Varus Q, Vi Q: hold to grow range and damage, release to fire); skillshots with exact indicators; empowered next attacks (Sheen-style); cooldown resets on kills; unstoppable and untargetable moments; forms (Nidalee, Jayce); animation cancels. Don't take: point-and-click targeting as the default, very long ultimate cooldowns.
- Hades. Take: near-instant casts; boons that transform an ability's behavior (our augments); two effects combining into a third (our reaction rules); an ultimate charged by fighting (an option per champion).
- Diablo 4. Take: skill categories (basic, core, defensive, mobility, ultimate) that builds focus on (our role tags; "basic" is called `generator` here); generators and spenders (basic attacks build a resource, abilities spend it); legendary aspects that change a skill's behavior (augments), including "also casts X" and "cooldown reduced when…"; "+x% to tagged skills" (scoped modifiers); Unstoppable as a core defensive; shapeshifting forms. Don't take: skills gated behind stat checks.

## Principles
1. Instant response: a legal press casts (or starts charging) on that frame, or fires from the input buffer the moment it becomes legal.
2. What you see is what you get: the indicator, the telegraph and the tooltip show the real numbers (after modifiers, augments and the current charge-up).
3. Every ability is built from shared pieces (the toolkit); a new ability is a short script plus a .tres, written from the ability spec sheet.
4. Items change numbers through scoped StatModifiers and behavior through augments, both source-tagged, so unequipping restores everything exactly.
5. Costs, cooldowns and charges make casts decisions; nothing refunds or free-casts without a clear reason the player can read.
6. One set of rules for every Unit: enemies cast through the same AbilityComponent.

## Rules (MUST unless marked proposed)
### Casting
- A cast happens when: the ability is ready (cooldown done or a charge available), the caster can pay its cost, no status blocks casting, and its conditions pass (Conditions).
- At cast start: pay the cost, show the telegraph, play `cast_sound`. The cooldown (or a charge) starts at cast start for INSTANT and CHANNEL, and at release for CHARGE_UP and VECTOR.
- A cast cancelled (dash, move, Esc or overhold CANCEL_REFUND during a charge-up or a vector aim) or interrupted (stun, death) before its effect refunds its cost and cooldown/charge. Once `execute()` starts, nothing is refunded.
- A stun (or any status that blocks casting) applied during the cast time, a charge-up or a vector aim interrupts the cast at once (Ryan's pick). AbilityComponent listens to its unit's `StatusComponent.status_applied`; a unit without a StatusComponent (none today) still gets the old check at the end of the cast time.
- The cast movement rules (Movement during casts, below) also govern walking while charging up or aiming a vector.
- **The "on cast" trigger fires when the effect starts** (Ryan, AB8): `Events.ability_cast` / ABILITY_CAST come after the cast time for INSTANT and CHANNEL, after the release windup for CHARGE_UP and VECTOR, at each recast part's effect, and when a free cast runs; never for a cast cancelled or interrupted before its effect (so a "restore on cast" rule can't pay out for a cast that was refunded). `cast_started` stays at cast start for sounds and telegraphs.
- **Cast progress** (AB14, Ryan 2026-09-29): every cast time runs on the cast's progress from 0 to 1, not on a countdown: each physics tick (game time) it grows by delta ÷ `cast_time` × the **cast speed** (`AbilityComponent.get_cast_speed()`, 1.0 for now). The effect starts on the tick progress reaches 1, whatever real time that took. This covers INSTANT and CHANNEL cast times, the release windup of CHARGE_UP and VECTOR, and enemy casts; a telegraph that belongs to a cast fills with its progress. Cast speed never touches cooldowns (`ability_haste` stays the cooldown stat). Details: Architecture, Cast progress and presentation hooks.
- **Free casts** (`CastAbilityGameplayEffect`, `CastContext.is_free`): no cost, no cooldown started, no charge used; no cast time (the effect runs at once); they don't root the caster, don't lock the slot and don't interrupt a cast already in progress; they aim at the triggering cast's aim point and target (a hit: the unit hit), or the caster's current aim if there isn't one. A dead or cast-blocked unit refuses them. Since ABILITY_CAST fires at the effect start, a free cast it triggers runs right then; nothing is queued. Free casts are chain-limited like reaction rules (`chain_limit`, `ReactionRule.MAX_CHAIN` 5), their hits included (`HitContext.chain_depth`). They don't use up ability empowers.

### Movement during casts
Moved here from MOVEMENT.md unchanged (MOVEMENT.md keeps a pointer). Per ability; the defaults keep every Knight ability as it was.
- `roots_during_cast` (default on): the cast locks walking (`&"casting"`) until it finishes.
- `cast_move_speed_multiplier` (default 1.0): with `roots_during_cast` off, walking speed during the cast is multiplied by this. It's a `PERCENT_MULT` `move_speed` StatModifier, source `&"ability_casting"`, removed when the cast finishes, is interrupted or is cancelled. Soft caps still apply after it: for the Knight (375 since 2026-09-28), 0.75 gives 319 u (102 px/s; raw 281 is under the low cap), 0.6 gives 291 u (93 px/s), 0.5 gives 272 u (87 px/s, not 60), and 0 still walks at 57 px/s.
- `cancel_on_move` (default off): a movement key pressed **after** the cast starts cancels it during its cast time, exactly like the dash cancel (locks released, cooldown refunded, `cast_cancelled` then `cast_finished`; `execute()` can't be cancelled). Keys already held when the cast started don't count; letting go and pressing again does. PlayerInput notes a `move_*` press in `_unhandled_input` only if a cast is already running (input events arrive in order, so Q then D in the same frame counts), and calls `AbilityComponent.try_cancel_cast_on_move()` in `_physics_process`, before MovementComponent, so the new key moves that same frame.
- **`cancel_on_move` wins:** the cast always roots for its cast time (the player stops, and any `move_to` order is dropped), even if `roots_during_cast` is off, and the multiplier is ignored. It's a channel: stand still, move to cancel. With `cast_time` = 0 there's nothing to cancel.
- `dash_cancelable` (default off for all Knight abilities): a dash during the cast time cancels the cast (locks released at once, cooldown refunded, `cast_cancelled` then `cast_finished`). Off: the dash press is buffered until the cast is done.
- `cancels_swing` (`NEVER` / `AFTER_HIT` default / `ANYTIME`): whether the press can cut a basic attack swing (COMBAT.md). Otherwise it waits for the swing to end (input buffer).
- Facing stays locked to the cast's aim while walking during a cast (MOVEMENT.md, Facing and aim). SELF casts have no aim, so facing follows walking.

### Cast styles (per ability, `cast_style`)
- INSTANT (default): press to cast after the cast time.
- CHARGE_UP: hold the key to charge, release to fire at the cursor's position at release. The cast context carries `charge` (0 at a tap, 1 at full). Each ability lists which params grow with the charge (e.g. `cast_range` from 40% to 100%, `base_damage` from 50% to 100%) with an optional curve; the full value is the normal param after modifiers, so items raise both ends. The indicator is always shown while charging and grows with it. After full charge, the player may keep holding for `overhold_time`; then the ability does its overhold behavior: FIRE (default) or CANCEL_REFUND, per ability.
  - Release windup (Xerath Q style): for CHARGE_UP, `cast_time` is the delay after release (the cast starts at release, so no separate field). On release the aim and the charge lock at the release point, the indicator stays visible (locked, no longer following the cursor), `cast_sound` plays, and after `cast_time` the effect runs (damage, VFX, hit sounds). During it the cast movement rules apply, `dash_cancelable` and stuns work like any cast time, and a cancel or interrupt refunds the cost and the cooldown. The indicator clears when the effect runs or the cast ends any other way. An enemy's release windup shows its telegraph (`on_cast_started()`), like the slam's cast time.
  - Every way a charge-up ends (its effect starting after release, overhold FIRE or CANCEL_REFUND, Esc, a stun, a dash, a move on a channel, death, the slot swapped by a REPLACE, a lost key release) goes through one end-charge path, which clears the indicator, the charge bar and `charge_sound`.
- CHANNEL: the caster stands still through the cast time; moving cancels it (refunded); the effect comes at the end. This is `cancel_on_move`, formalized (Judgement). A lasting channelled effect (a drain, a held beam) isn't a cast style: statuses, auras and reaction rules (Not planned, below).
- VECTOR (AB13; League's Viktor E, Rumble R): press the key to drop a start point at the cursor (clamped to `cast_range` from the caster, and to the last valid spot short of a wall), hold and move the mouse to aim, release to cast from the start point toward the cursor. The aim locks at release.
  - The line is `vector_length` long from the start point; the cursor beyond it only sets the direction. The cast carries the start point, direction and end point, so shapes and ground areas can use the line (a laser, a wall of fire, a line of spears).
  - Tap: if the cursor is less than `vector_min_drag_px` from the start point at release, the direction is from the caster through the start point (League's default).
  - It uses the CHARGE_UP hold/release path and its release windup (`cast_time` after release, aim locked, indicator stays); cancels and interrupts work exactly as for CHARGE_UP. Its `charge` is always 1; `overhold_time` counts from the press as a hold limit (then `overhold`: FIRE or CANCEL_REFUND).
  - Indicator: a start marker plus a line preview, shown from the press until the release windup ends.
  - Every recast part of a VECTOR ability is aimed the same way (a CHARGE_UP recast part still casts at once).
  - The enemy AI places the start point and direction itself (no mouse), with the usual telegraph during the cast time.
  - Walking while aiming follows the cast movement rules: the test ability walks at `cast_move_speed_multiplier` 0.6; a kit can still root fully with `roots_during_cast`.
- Not planned: TOGGLE and SUSTAINED. Always-on and "while X" effects use statuses, auras and reaction rules (items, passives). Revisit only if a champion needs one.

### Cast mode (player setting)
- Cast mode is a player setting in Settings and the pause menu, like dash direction: QUICK (cast at the cursor on press; default, Ryan's pick) or QUICK_WITH_INDICATOR (hold to aim, release to cast). Esc cancels an aim.
- Cast mode only applies to INSTANT abilities. CHARGE_UP and VECTOR always use hold-and-release and CHANNEL always casts on press, whatever the setting.

### Damage scalings (League ratios)
- An ability's damage is `base_damage` plus a list of scaling terms, each "ratio × a stat", read from the caster (attack_damage, bonus attack damage = final − base, ability_power, max_health, bonus health, armor, magic_resist...) or from the target (max health, missing health, current health). `ap_ratio` is supported.
- `base_damage` / `ad_ratio` keep working (`ad_ratio` is one term, wrapped, not rewritten). Judgement's missing-health bonus is in data (a `DamageScaling` term).
- Scalings are scoped params, so items can raise a ratio.
- **Adaptive** (planned, COMPANIONS.md; League's adaptive force): a term on the higher of the caster's `attack_damage` and `ability_power` (`DamageScaling.Of.CASTER_ADAPTIVE`). The final values are compared, a tie goes to AD, and the hit's damage type follows (PHYSICAL from AD, MAGIC from AP). A companion's command scales this way, so one companion fits AD and AP champions (Ryan, 2026-10-03).

### Tooltips from data
- Each ability's description is a template with placeholders (`{damage}`, `{cooldown}`, `{cost}`, `{range}`, `{charges}`, each scaling term, charge-up min–max) filled from `get_param()` with haste, modifiers and augments applied, damage colored by type (League style). It's a function other code can call; where the HUD shows it is UI.md. A talent that reshapes the ability can replace the whole template while it's on (TALENTS T3b: `Talent.ability_description`, `AbilityComponent.get_description_override()`); a scaling term at 0 is left out of `{ratios}`.

### Standard tags (listed in CONVENTIONS.md)
- Exactly one role tag per ability, following Diablo 4's categories: `generator`, `core`, `defensive`, `mobility`, `ultimate` (Diablo's "basic" is `generator` here, so it can't be confused with the basic attack).
- **`companion`** (planned, COMPANIONS.md): the sixth role, for a companion's command only. A command carries no other tag except a style tag its cast style needs, and its modifier scopes are only `ability:<its id>` (`get_modifier_scopes()`), so no `tag:` modifier from an item, talent or sigil reaches it.
- Plus shape tags (`area`, `projectile`, `line`, `cone`, `dash`, `leap` (LOOT L6), `blink` (AB15)), style tags (`charge_up`, `channel`, `vector`; each must match the ability's `cast_style`) and element tags (`fire`, `cold`, `lightning`, `poison`, `shadow`, `holy`; the list is an open question).
- **`melee`** (built with the 3D terrain, 3D.md P9; the tag is in Cleave's and Lunge's data, and HitPipeline adds it to a MELEE combo's swings): the ability's hits can't reach an `elevated` target from below (COMBAT.md, Hits). The Knight: Cleave and Lunge get it; Judgement doesn't (UNIT-targeted, walks into range) and neither does Cleave Wave (a projectile).
- **Knock-ups** (planned, 3D.md, Terrain and height 1a): an ability knocks up by giving its hit a knockback (`knockback_px`) and `status_airborne` among its statuses; no new field. Enemies don't knock up the player in v1.
- Scoped modifiers use them ("+20% damage to core abilities").

### Costs and resources
- Every champion has a resource type: MANA, ENERGY, FURY or NONE (Ryan's pick: NONE is allowed, cooldowns only). The Knight's is FURY (CHAMPIONS.md, which also owns the resource-type rhythms: fury starting empty and decaying out of combat). NONE = the unit has no ResourceComponent; such a unit pays no costs.
- An ability's `resource_cost` is a scoped param (items can reduce it). A CHARGE_UP ability pays when charging starts.
- Not enough resource: the cast fails with a clear cue; the press is not buffered.
- Generators and spenders: `resource_on_hit` lets basic attacks build a resource that abilities spend.
- The HUD shows a resource bar (HUD, below).

### Charges and recasts
- `max_charges` (default 1). Each charge recharges over the cooldown, one at a time. Items can add charges (scoped param). "Charges" (stored casts) are not the same as "charge-up" (hold to power a cast).
- `recast_count` (default 0) and `recast_window`: pressing the slot again inside the window casts the next part; the cast context says which part. The cooldown starts when the last part is used or the window ends (League style, Ryan's pick). The first part costs `resource_cost`; every later part costs `recast_resource_cost` (default 0, one scoped param for all later parts; Ryan's pick).

### Blinks (Ryan, 2026-10-04; built in AB15)
A **blink** moves a unit to a point instantly: no travel, no time in the air (League's Flash, Ezreal's E, LeBlanc's return). It's a toolkit piece many mechanics will use (Ryan): abilities, enemy elite modifiers (ENEMIES_AI's Teleporting), ALLIES' catch-up teleport. A dash travels along the ground (`dash()`) and a leap flies over everything (`leap()`, 3D.md, Leaps); a blink skips the space between.
- **MUST (Ryan, 2026-10-04):**
  - **Over walls by default**, with a switch per ability to stop at walls instead (`through_walls`). Over walls, it crosses everything a leap does. Stopping at walls, it ends at the last free spot short of a wall (layer 1) on the straight line from the unit; it still crosses fences, ledges and pits, as a teleport would.
  - **It lands on the nearest walkable floor of the unit's room**, by the leap's rule (`MovementComponent.get_leap_landing()`: the aimed spot when the body fits there, else the nearest point of the room's navigation, freed of what the body overlaps). So a blink never ends inside a wall, a fence or a pit, or outside the room. Stopping at walls, it also never ends out of sight of where it started.
  - **Homeward Greaves' return is a blink** (LOOT.md): an instant blink back to where the Lunge started, instead of the L6 dash.
- **The rest** *(proposed, 2026-10-04; Ryan reviews it before AB15)*:
  - `MovementComponent.blink(to_px: Vector2, through_walls: bool = true) -> bool` moves the body at once and returns false if refused. It also calls `reset_physics_interpolation()` (CLAUDE.md, teleports) and emits the new signal `blinked(from: Vector2, to: Vector2)` for the view.
    - It ends the unit's own running displacement first: a dash (its ghost mask comes back), a knockback, a swing step.
    - A move order re-paths from the new spot, and held input keeps walking.
    - **Refused** (no move, returns false) during a leap, during a knock-up (`is_airborne()`; the arc keeps its shape), and while dash-blocked (a root or a stun; League's roots stop Flash). An ability that blinks checks this in `can_cast_custom()`, so a rooted press fails with its cue instead of spending the cast.
  - `MovementComponent.get_blink_landing(to_px, through_walls := true)`: where a blink would land, for indicators and AI plans.
  - **No status, no i-frames, no hits.** An ability that damages on arrival calls `hit_units()` after it, as Judgement Leap does after its leap.
  - **Ability tag `blink`** (a shape tag, like `dash` and `leap`): `tag:blink` scopes reach it, and an ABILITY_CAST rule can answer "when you blink". There's no blink event of its own.
  - **Enemies may blink** (unlike the leap): a blink moves only its user and isn't crowd control on anyone. The view_test guard on `leap()` stays; there's none on `blink()`.
  - **Level design** (3D.md, 1e): a wall thinner than a blink's range doesn't keep a blinker out, as for leaps. Gated spaces are separate rooms or out of range.

### Ultimates
- Per champion: the ultimate uses a cooldown (League) or a meter charged by dealing and taking damage (Hades), Ryan's pick. The Knight uses a cooldown (Judgement: 30 s, CHAMPIONS.md). The meter is designed in CHAMPIONS.md when a champion first uses one; this doc only needs the slot to support "ready when the meter is full" instead of a cooldown (`ready_mode` METER, reserved here, built with the meter).

### Projectiles
- A shared projectile piece: speed, range, width, pierce count (0 = stops on the first hit), blocked by walls (unless `ignores_walls`), one crit roll per cast shared by every projectile of that cast, its hits through `HitPipeline.from_ability()`. Projectile count and speed are scoped params, so "+1 projectile" is an item modifier.
- A projectile keeps flying if its caster dies. While the caster exists, kill credit is the caster's. Once the caster is freed, the projectile uses the damage it snapshotted when fired and its hits have no source (no kill credit, no crit, no on-hit), like a DoT whose applier is gone (DECISIONS, Combat, C9).
- **In 3D (3D.md, P6):** a projectile declares a `view_scene` (default: a bolt tinted by the ability's `icon_color`). Its height is the view's: it moves smoothly from its start height toward the terrain under its target, never below the terrain; `Projectile.DRAW_HEIGHT_PX` (the 2D 3/4 offset) isn't used by the view. Projectiles fly over ledges (the sim ignores height).

### In the 3D view (3D.md; the view never changes gameplay state)
- **Indicators** draw on the floor: the Player's `_draw()` (and `Ability.draw_indicator()` / `draw_vector_indicator()`) goes into `FloorOverlay`, so the indicator lies on the ground, follows slopes, and still shows exactly where the cast lands.
- **Aim:** the cursor's floor pick, or an enemy's feet when the cursor is over its model (MOVEMENT.md, Facing and aim). A VECTOR's start point is the floor pick at the press. An ability that can consume the companion (planned, COMPANIONS.md) also picks the companion's model; an enemy under the cursor wins.
- **Presentation hooks** drive the 3D model: `UnitView` positions the clip named by `cast_anim` (or a swing's `swing_anim`) by the cast's or swing's progress (`get_cast_progress()`, `get_swing_progress()`), so a strike lands on the effect at any cast or attack speed. `cast_vfx` / `impact_vfx` accept scenes with a Node3D root (`VFX.spawn_scene()`, P7). The 2D `Body/AnimationPlayer` path went with the 2D bodies (3D pivot cleanup C3, 2026-10-03): the clips are only the model's.

### Augments
- An `AbilityAugment` targets an ability id or tag (like scoped modifiers) and is added and removed by source id (items, passives, buffs).
- Kinds: FLAG (the ability script checks it: "Lunge now stuns"; an ability lists the flags it supports; an unsupported flag with an exact `ability:<id>` scope is an error, while a `tag:` scoped one is simply ignored by abilities that don't support it), EVENT (extra effects on cast / hit / kill; reaction rules plus the ABILITY_CAST trigger from `Events.ability_cast`; "on end" comes when something needs it, with a new `ability_finished` event), REPLACE (the slot uses a variant Ability while equipped; the cooldown carries over; it may change the cast style).
- The same augment from two sources doesn't stack; only one REPLACE per ability (a second is disabled and its tooltip says why). Ryan's picks.
- Augments are read at cast start: removing one mid-cast doesn't change that cast.
- Tooltips and indicators show the augmented ability.
- Forms/stances: one source can REPLACE several slots at once (League's Nidalee and Jayce, Diablo 4 Druid shapeshifts): a status tagged `form` holding several REPLACE augments grants them while active and removes them when it ends; one form at a time.

### New GameplayEffects (for augments, passives and items; each takes a source id)
- `ModifyCooldownGameplayEffect`: reduce by seconds or percent, or reset (League kill resets, Diablo "cooldown reduced when…"). REDUCE_PERCENT is a percent of the remaining cooldown. RESET on a slot with charges finishes the current recharge (+1 charge), not a full refill. While a recast window is open (the cooldown hasn't started), it does nothing. An empty scope ("every slot") never reaches the companion slot (planned, COMPANIONS.md).
- `RestoreResourceGameplayEffect`.
- `CastAbilityGameplayEffect`: a free cast of an ability or a variant from a source (Diablo's "also casts"); Casting, Free casts.
- `RemoveStatusesByTagGameplayEffect` (cleanse).

### Unstoppable and untargetable (status rules; also in COMBAT.md's status section)
- Status tag `unstoppable`: immune to new cc and removes cc when applied (Diablo 4's core defensive, League's Olaf R). It also blocks knockback from hits (Diablo 4; Ryan's pick). It doesn't affect the unit's own dashes and swing steps.
- Status tag `untargetable`: can't be hit or targeted (League's Fizz E): new hits and new statuses from other units are blocked, but damage over time already applied keeps ticking (the League rule; Ryan, AB10). `Unit.is_targetable()` is what targeting (UNIT abilities, the target forgiveness pick, enemy aggro and League-style attack targets) checks; projectiles fly through.
- Enemies and an untargetable player (Ryan, AB10): no new aggro; an enemy already aggroed keeps aggro and keeps chasing, but stops attacking (a windup is cancelled) until the player is targetable again. Untargetable windows are short (0.5–2 s), and a frozen enemy looks broken.

### Empowers ("your next attack / next ability")
- An empower is a StatusEffect tagged `empower` with `empower_*` fields: what consumes it (the next basic attack swing that hits, or the next ability cast) and, for abilities, which ones (a scope); a bonus base damage and AD ratio; statuses to apply to what it hits. HitPipeline adds the bonus into the hit itself, so it crits with the hit and applies to every enemy that swing or cast hits. It's consumed once per swing or cast; free casts never consume one (Ryan, AB10). Extra behavior rides the status's `reaction_rules`. Iron Resolve's is the first example (`empower_iron_resolve`); `add_next_attack_modifier()` stays as a thin wrapper (change policy).

### Ability ranks
- None, in any form (decided 2026-09-29). There is no ability-rank mechanic: what would have been ranks is fully replaced by the talent tree (TALENTS.md), a deliberate, capped choice made at the hub, not an automatic per-level upgrade. In-run power comes from loot (VISION.md, Game structure).

### Data or script (the rule every ability, passive and item follows)
- ABILITIES should express most League of Legends / Diablo 4 abilities with data plus a short script. If 2+ abilities, passives or items would use something, it's data (a toolkit piece); a one-off goes in the ability's own script, which still uses the full architecture (cooldown, cost, recasts, HUD, tooltips, augments, sounds).
- Unique state is modeled as statuses, so data conditions can read it (League style: Lee Sin's Q2 works because Q1 marks the target with a status).

### Conditions
- One condition system for the whole game: the `Condition` resource. `ReactionRule` has a `conditions` list next to its existing tag filters (additive). Abilities, conditional bonuses, augments, passives, items and later the enemy AI all use the same resource. Never two parallel condition systems.
- Starting condition kinds (small on purpose; CHAMPIONS.md and LOOT.md may add more later, additively):
  - SELF_HAS_STATUS (tag, min stacks)
  - TARGET_HAS_STATUS (tag, min stacks): covers "marked" (Lee Sin Q2), stack counts (Kalista E), "crowd controlled" (the `cc` tag)
  - SELF_HEALTH_PERCENT (above / below)
  - TARGET_HEALTH_PERCENT (above / below): executes, Diablo's "injured" / "healthy"
  - TARGET_DISTANCE (closer / farther than X): Diablo's "close" / "distant"
  - ENEMIES_IN_RANGE (at least N within X; optionally only enemies with a status tag: "a marked enemy within range", Lee Sin's Q2 recast)
  - RESOURCE_AT_LEAST (N)
  - LAST_PART_HIT (the previous recast part hit something)
  - CONSUMES_COMPANION (planned, COMPANIONS.md: this cast is consuming the caster's companion; a devour's payoff bonus)
  - Planned by ENEMIES_AI.md (2026-10-03; *proposed* names), for the AI's use rules: THREATENED (an attack coming at self lands within N seconds), TARGET_WHIFFED (the target's punish window is open and at least N seconds long), RESPECT (the brain's respect above or below N). They read the brain's `SituationContext`, passed as an optional last argument; anywhere without one they're false.
- Each condition has a "not" toggle (`negate`). A list of conditions means all must pass (AND). No OR and no nesting; that's what scripts are for.
- "Target" means the unit hit, for hit-time checks. For cast checks: a UNIT ability's chosen target; otherwise the enemy nearest the cursor within cast range. No target = every TARGET_ condition fails, even when negated. In a reaction rule, "self" is the unit the effects come from (the rule's source) and "target" the effect target.
- Where conditions plug into an ability:
  1. `cast_conditions`: all must pass to start a cast.
  2. `recast_conditions`: all must pass to use the next recast part.
  3. Conditional bonuses: a list of {conditions, param changes (StatModifiers: add or multiply, so tooltips can show them), statuses to apply to each unit the effect hits, statuses to apply to the caster}. Checked at the moment the effect happens (cast or hit), not earlier.
- Custom check: an Ability script can override a virtual custom check; it's ANDed with the data conditions. This is the escape hatch for one-off logic.
- Feedback: when a cast or recast condition fails, the slot shows as unavailable (greyed, League style) and pressing it plays the fail cue with reason "condition"; nothing is spent and the press isn't buffered. A condition can carry a short fail text for later UI (e.g. "No marked target").
- Named 0–1 scaling inputs: CastContext carries named values from 0 to 1. Charge is the first one; `CastContext.charge` keeps working exactly as it is (a thin wrapper, change policy). Any charge-style scaling can read any named input through its optional curve. Built in: `charge`, `self_missing_health`, `target_missing_health`, `target_distance` (distance ÷ cast range), `vector_drag` (a VECTOR cast's drag length ÷ `vector_length`; AB13); an ability script can set any other (e.g. stack count ÷ max stacks).
- Conditions work outside ability slots (passives, items, enemy AI), like the rest of the toolkit: a condition is a pure check on units, and whatever holds it (a rule, an augment, a status, an item) is added and removed by its source id.

### What the AI uses an ability for (ENEMIES_AI.md, written 2026-10-03; Ryan's enemy decisions; names *(proposed there)*)
- **Each ability carries what it's for, as data:** `ai_uses`, a list of `AIUse`: an intent tag (`poke`, `gap_close`, `escape`, `defend`, `punish`, `finish`, `zone`, and ALLIES' effect tags `damage`, `heal`, `shield`, `buff`, `cc`), use rules (the shared `Condition`s, all of which must pass) and a weight. A brain picks the ability the moment calls for, not whatever is ready: a caster's shield has only a `defend` use with THREATENED, so it never goes up "just because". An ability with no `ai_uses` counts as one `damage` use with no rules.
- **The data says what for and when; the ability's `get_ai_plan()` (ALLIES.md) says how and how good.** Intent tags aren't ability tags: they never enter scopes or hit tags.
- **Respect:** what a champion has ready holds smart enemies back. An ability's weight in it is `respect_value`, derived from its role tag and whether it crowd-controls unless authored (ENEMIES_AI.md, Respect); never from damage numbers.
- **What enemies can dodge** (elites and bosses; ENEMIES_AI.md, Dodging): only what a person could see coming in time, read through `get_effect_area()`: skillshot projectiles by their travel time, charge-ups while held and in their release windup, VECTOR lines in their release windup, POINT and area casts with a long enough cast time. Never UNIT-targeted abilities (Judgement), casts faster than the reaction plus a sidestep (Cleave, Lunge, swings) or the dash.

## The toolkit (every ability is built from these)
Targeting and indicators; cast styles; shapes (cone, line, circle, line of sight); the hit (`HitPipeline.from_ability` with scalings, knockback, statuses, feel, crit roll per cast); statuses (incl. unstoppable, untargetable, empowers); movement methods (dash, displace, leap (LOOT L6), blink (AB15); pull_to when first needed); projectiles; ground areas (player-made Hazards, WORLD_INTERACTION.md); telegraphs; reaction rules and GameplayEffects granted by abilities; conditions; tooltips; sounds and VFX hooks.
- The toolkit must also work for passives (CHAMPIONS.md) and items (LOOT.md): empowers, the ABILITY_CAST trigger, projectiles, augments and the new GameplayEffects take a source id and never assume they come from an ability slot.

| Piece | Where it lives | What it's for | Passives and items use it as-is: how the source is carried |
|---|---|---|---|
| Targeting and indicators | `Ability.targeting`, `Ability.draw_indicator()` (override per shape), `Ability.draw_vector_indicator()` (VECTOR), `Ability.get_charged_param()` | where a cast goes; the aim shape the player sees | through an Ability resource (a hidden variant cast by `CastAbilityGameplayEffect`); an item never needs an indicator of its own |
| Cast styles, costs, charges, recasts | `AbilityComponent` + fields on `Ability` | when and how often a slot fires | slots only; items change them through scoped modifiers (`StatsComponent.add_modifier()`, `source_id`) and REPLACE augments (`add_augment(augment, source_id)`) |
| Shapes and sight | `AbilityUtil` (`in_cone`, `along_segment`, `in_circle`, `in_sight`, `nearest_enemy_to`, `nearest_enemy_in_range`), `WorldQuery.has_line_of_sight()` | who's inside an area (a VECTOR line: `along_segment()` from `vector_start` to `vector_end`, `vector_width` wide) | static functions: any caller with a caster Unit |
| The hit | `Ability.hit_units()` (one crit roll per cast, the cast's context, `hit_knockback_px`, statuses on the hit; optional `damage_ratio` for a share of the damage and `crit_roll` to share a roll with an earlier call of the same cast, TALENTS T3), `HitPipeline.from_ability()`, `make_proc()`, `DealDamageGameplayEffect` | damage, crits, mitigation, on-hit, knockback, statuses | the hit's `source` is a Unit (kill credit); an item's damage is a rule's `DealDamageGameplayEffect` (source = the rule's owner) or a free cast |
| A pull | `Ability.pull_airborne(caster, target, to, duration)` (LOOT L5): `status_airborne` from the caster for `duration`, and a straight move to `to` over that time, crossing fences, ledges and pits (walls stop it), with the knock-up's landing. False if the target refuses airborne (unstoppable, untargetable), is already there, or a stronger displacement runs | moving another unit toward a point without a hit | Chains of Judgement's drag (`judgement.gd`); the AB11 guard keeps `displace()` out of the Knight's scripts |
| A leap | `MovementComponent.leap(to_px, duration)` (LOOT L6; 3D.md, Leaps): the caster through the air to the nearest walkable floor of its room (`get_leap_landing()`), over everything, colliding with nothing, `is_airborne()` while it runs, no status, no i-frames, uninterruptible; poll `is_leaping()` | sending the caster to a point (tag the ability `leap`) | The Last Verdict's Judgement Leap (`judgement_leap.gd`); view_test checks it's the only caller |
| A blink | `MovementComponent.blink(to_px, through_walls := true)` (AB15; Blinks, above): the unit to a point at once, on the nearest walkable floor of its room, over walls unless `through_walls` is off; no status, no i-frames; refused during a leap, a knock-up or a root; `get_blink_landing()` for indicators and plans; the `blinked` signal for the view | moving a unit to a point instantly (tag the ability `blink`) | Homeward Greaves' return (`lunge.gd`), the test blink; later ENEMIES_AI's Teleporting elites and ALLIES' catch-up teleport |
| Damage scalings | `DamageScaling` Resources on `Ability.scalings`; `ad_ratio`, `ap_ratio` | League ratios | scoped modifiers raise a term's ratio (`scope` `ability:<id>` / `tag:<tag>`, `source_id` the item's) |
| Statuses | `StatusComponent.apply_status(effect, source)`, `StatusEffect` | buffs, debuffs, cc, shields, DoT | the applier is a Unit; the status's own modifiers, rules and augments go under `&"status_<id>"` |
| Empowers | `StatusEffect.empower_*` fields, read by `HitPipeline` | "your next attack / next ability" | any source that applies the status: an ability, a passive's rule, an item's rule (`ApplyStatusGameplayEffect`) |
| Unstoppable, untargetable, cleanse | status tags `unstoppable` / `untargetable`; `RemoveStatusesByTagGameplayEffect` | defensive moments | statuses applied by anything; the cleanse is a GameplayEffect in a rule |
| Movement methods | `MovementComponent.dash()`, `displace()`, `leap()` (LOOT L6), `blink()` (AB15) (later `pull_to()`) | abilities never set position themselves (WORLD_INTERACTION.md) | any caller; displacements carry no source id (kill credit for impacts is WORLD_INTERACTION's) |
| Projectiles | `Projectile` (`res://scripts/abilities/projectile.gd`), `Projectile.fire()` | skillshots, waves, bolts | fired with an Ability resource and a `CastContext` whose `source_id` names the item or passive (free casts set it) |
| Ground areas | `Hazard` *(proposed, WORLD_INTERACTION.md)* | fire trails, oil pools | a Hazard's `source` Unit; planned there |
| Telegraphs | `Telegraph.circle()`, `Telegraph.line()` (AB13), `Ability.on_cast_started()`, `CastContext.telegraph` | the floor warning during a cast time | through an ability's cast |
| Reaction rules and GameplayEffects | `Unit.add_reaction_rule(rule, source_id)`, `Reactions.add_world_rule(rule, source_id)`; trigger ABILITY_CAST; the four new effects | "when X, do Y" | `source_id` on add, removed with `remove_reaction_rules_from(source_id)` |
| Augments | `AbilityAugment`, `AbilityComponent.add_augment(augment, source_id)` / `remove_augments_from(source_id)`; `StatusEffect.augments` | behavior changes and forms | `source_id` on add; a status's augments use `&"status_<id>"` |
| Tooltips | `Ability.get_tooltip(caster)`, `get_tooltip_plain(caster)` | what the player reads | shows augment lines with their source's text |
| Sounds, feel and VFX | `Ability.cast_sound` / `hit_sound` / `telegraph_sound` / `ready_sound` / `charge_sound` (AUDIO.md); `Ability.hit_shake` / `hit_hitstop` + `play_hit_feel(hits)` (once per cast, only when a hit landed); `VFX` static helpers; the presentation hooks `cast_vfx` / `impact_vfx` / `cast_anim` (AB14, empty = nothing) | feedback only; never gameplay state | fields on the Ability or status the source grants; an item's active ability is an Ability, so it has the same hooks |
| Cast progress | `CastContext.progress`, `AbilityComponent.get_cast_progress()` / `get_cast_speed()` (AB14) | the cast time as 0–1 progress × cast speed; telegraphs and `cast_anim` follow it | any cast through AbilityComponent (a free cast has no cast time: progress 1 at once) |
| Conditions | `Condition` (`res://scripts/data/condition.gd`), `Condition.is_met()`; `Ability.cast_conditions` / `recast_conditions` / `conditional_bonuses` (`ConditionalBonus`); `ReactionRule.conditions`; `Ability.can_cast_custom()` | "only when…", "bonus if…" | a condition is a pure check (`is_met(self_unit, target, cast)`), so it needs no source id itself: a passive or item puts it in the rule, augment or status it grants, which is added and removed by the source id as usual; the enemy AI calls `is_met()` directly |
| Named scaling inputs | `CastContext.get_input()` / `set_input()`; `ChargeScaling.input`; `Ability.get_effect_param()` | "stronger the more / less…" | carried by the cast (`CastContext`), whoever granted it |

## Ability spec sheet
Every new ability is written from this sheet first (it replaces WORLD_INTERACTION.md's template, which now points here). Fields match `Ability`; leave a line out when it's the default.
```
Name / Champion / Slot / id:
Role tag / other tags:
Cast style: INSTANT / CHARGE_UP (charge_time, overhold_time, overhold, charge-scaled params) / CHANNEL / VECTOR (cast_range = start range, vector_length, vector_width, vector_min_drag_px, overhold_time as the hold limit)
Targeting: SELF / DIRECTION / POINT / UNIT (VECTOR: POINT)
Cost: resource_cost (recast_resource_cost)       Cooldown: __ s      Charges: max_charges
Recasts: recast_count, recast_window, what each part does
Cast time: __ s      Range: cast_range __ u (__ px)
Movement during the cast: roots_during_cast, cast_move_speed_multiplier, cancel_on_move, dash_cancelable, cancels_swing, resets_auto_attack
Damage: base_damage, ad_ratio, ap_ratio, scalings, damage_type, proc_coefficient, ignores_walls
Cast conditions: (Condition kinds, AND; "not"; fail text) + custom check, if any
Recast conditions: (per the next part) + custom check, if any
Conditional bonuses: {conditions → param changes, statuses on targets, statuses on self}, checked at cast / hit
Named scaling inputs: which params scale by which input (charge, self_missing_health, target_missing_health, target_distance, vector_drag, script-set), min fraction, curve
Heal on hit: heal_on_hit_ratio (× damage taken by each enemy hit, CHAMPIONS CH5) or heal_missing_health_ratio (× the caster's missing health, once per cast, CH5b), its named-input scaling (input, curve)
Presentation hooks: cast_vfx, impact_vfx, cast_anim (AB14; the VFX hooks empty until the art pass; since 3D pivot P6 the Knight's cast_anim names his placeholder model's clips, 3D.md, Animation)
What it does, step by step:
Supported augment flags:
Sounds (AUDIO.md): cast_sound, hit_sound, telegraph_sound, ready_sound, charge_sound
Walls:
World (abilities that touch it; WORLD_INTERACTION.md): world query, movement method, ends when, hits wall, hits enemy
Stunned mid-cast:
Caster dies mid-cast / mid-effect:
Tooltip template:
Extra tunables:
```

### Example: Knight Q, Cleave (as the code and data are today)
```
Name / Champion / Slot / id: Cleave / Knight / Q / knight_cleave  (knight_q_cleave.tres, knight/cleave.gd)
Role tag / other tags: core (placeholder; the real role is CHAMPIONS.md's) / area, cone
Cast style: INSTANT
Targeting: DIRECTION
Cost: 0 (until CHAMPIONS.md)      Cooldown: 3 s      Charges: 1
Recasts: none
Cast time: 0.2 s      Range: cast_range 300 u (96 px; the default, not set in the .tres) = the cone's reach
Movement during the cast: roots, multiplier 1.0, cancel_on_move off, dash_cancelable off, cancels_swing AFTER_HIT, resets_auto_attack on (does nothing in combo mode)
Damage: base_damage 80, ad_ratio 0.7, PHYSICAL, proc_coefficient 1.0, blocked by walls
What it does, step by step:
  1. Cast start: cast_sound; the Knight is rooted 0.2 s.
  2. Effect: a slash VFX; every enemy in a cone from the Knight's feet along the aim, reach 96 px,
     half-angle 60° (cone_half_angle_deg), each target's gameplay radius counted (AbilityUtil.in_cone),
     keeping those in line of sight (filter_by_walls).
  3. hit_units(): one CritRoll for the cast; each target: HitPipeline.from_ability(…, ctx) then resolve().
  4. Each hit that wasn't blocked: a 17 px push away from where the Knight stands (hit_knockback_px 17 over
     hit_knockback_duration 0.1 = 170 px/s × 0.1 s, the target's knockback_curve), applied by Unit.on_hit()
     (unstoppable blocks it); a target the hit kills still slides 17 px (hit_units()).
  5. A hit landed: shake 3 px, hitstop 0.05 s, once (hit_shake / hit_hitstop, play_hit_feel(); COMBAT.md).
Supported augment flags: none yet. (AB-M's wave is a REPLACE: knight_cleave_wave, variant_of knight_cleave.)
Sounds: cast_sound sound_knight_cleave_cast; hit_sound none (HitFeel's light tier plays)
Walls: blocked (COMBAT C7): an enemy behind the pillar isn't hit.
Stunned mid-cast: interrupted at once, no hit, cooldown refunded.
Caster dies mid-cast: interrupt_cast(), no hit. Mid-effect: the effect is one frame; it resolves.
Tooltip template: "Sweep your sword in a wide arc in front of you, dealing {damage} physical damage ({base_damage} {ratios}) and knocking enemies back."
Extra tunables: cone_half_angle_deg 60. (The old `knockback` export was deleted after AB-M passed, 2026-09-28.)
```

## Numbers (TARGET: start, range)
- Player cast times: movement and quick strikes 0.0–0.1 s; strikes 0.15–0.3 s; ultimates up to 0.5 s.
- Cooldowns: non-ultimate abilities 3–10 s; ultimates 30–60 s (shorter than League, for run pacing); a companion's command 25–50 s, never shortened by ability haste (Ryan, 2026-10-03; COMPANIONS.md).
- Charge-up: time to full 1.5 s (0.5–3); overhold 2 s after full (1–4); a tap gives charge 0 (the listed minimums); walking while charging per ability (e.g. `cast_move_speed_multiplier` 0.6).
- Charge-up release windup (`cast_time` on a CHARGE_UP ability): 0.3 s (0.15–0.5). The default stays 0 (no windup); the test Charged Line uses 0.3 s.
- VECTOR (AB13, all placeholders until a champion uses one): start range (`cast_range`) 500 u (160 px), `vector_length` 500 u (160 px), `vector_width` 75 u (24 px), `vector_min_drag_px` 8 px (4–16), release windup 0.2 s (0.1–0.3), hold limit (`overhold_time`) 2 s, walking while aiming (`cast_move_speed_multiplier`) 0.6 (0.5–0.6); a full root only through `roots_during_cast`.
- `recast_window` 3 s (1–6).
- Charges: recharge time = the ability's cooldown.
- Costs: mana abilities 30–80 of a 300 pool (6/s regen) (a placeholder range until a mana champion exists); fury abilities spend what basic attacks build (the Knight's numbers: CHAMPIONS.md, Fury).
- Fail cue: the resource bar flashes 0.2 s.
- Judgement (CHAMPIONS.md, decided 2026-09-29): a 0.75 s channel and a 30 s cooldown, changed in CHAMPIONS CH4 (built 2026-09-29). The 0.75 s channel stays above the 0.5 s ultimate cast-time guide (Ryan's call).

## HUD feedback (minimal, inside the steps that add each feature)
- Charge count on the slot, a recast window timer, a charge-up bar, and fail cues by reason: not ready, not enough resource (the resource bar flashes), silenced, condition. Details: Architecture, HUD. Since CHAMPIONS CH6: a gold outline on a slot while a bonus with only caster-side conditions is live, and a tick on the resource bar at each `RESOURCE_AT_LEAST` threshold with a glow at or above it (CHAMPIONS.md, Readable kit HUD).

## Current code
What each piece does now (details in Data and Architecture).

| Code | What it does now |
|---|---|
| `res://scripts/abilities/ability.gd` (`Ability`, Resource) | The fields in Data plus the older ones (`id`, `tags`, `display_name`, `description` = the tooltip template (plain text without placeholders still works), `icon_color`, `targeting` SELF / DIRECTION / POINT / UNIT, `cooldown`, `cast_time`, `cast_range`, `resets_auto_attack`, the Movement during casts fields, `base_damage`, `ad_ratio`, `damage_type`, `proc_coefficient`, `ignores_walls`, the sound fields). `get_param()`, `get_modifier_scopes()`, `get_damage()`, `filter_by_walls()`, `can_reach_through_walls()`, `hit_units()`, `pull_airborne()` (LOOT L5), `play_hit_feel()`, `get_vector_direction()`, `get_vector_tap_direction()`; virtual `execute()`, `on_cast_started()`, `draw_indicator()`, `draw_vector_indicator()`, `get_ai_vector()`, `can_cast_custom()`. No field was renamed. |
| `res://scripts/abilities/cast_context.gd` (`CastContext`) | `slot`, `point`, `direction`, `target`, `telegraph`, plus the fields in Data (the three vector fields since AB13). |
| `res://scripts/components/ability_component.gd` (`AbilityComponent`) | Four slots (`q`, `w`, `e`, `r` exports; `SLOTS`) with charges, recasts, charge-ups and VECTOR aims (the same hold path), augments, conditions (Architecture). `_do_cast()` runs the cast flow; the cast time runs on cast progress (AB14: `_advance_cast_time()`, deferred each physics tick; the old game-time timer was deleted after the AB14 play test), and `cast_vfx` / `cast_anim` play at cast start; `_cast_serial` stops a cancelled `_do_cast()`; a stun/death check at the end of the cast time stays as a safety net behind the at-once stun interrupt. `try_cancel_cast()` (dash), `try_cancel_cast_on_move()`, `interrupt_cast()` (death). |
| `res://scripts/abilities/ability_util.gd` (`AbilityUtil`) | `enemies_of`, `enemies_of_team`, `in_cone`, `along_segment`, `along_segment_of_team`, `in_circle`, `in_sight`, `nearest_enemy_to`, `nearest_enemy_in_range`. `enemies_of()` and `enemies_of_team()` skip untargetable units; the `_of_team` versions work for projectiles whose caster may be gone. |
| `knight/cleave.gd` (Q) | Built from toolkit pieces: `in_cone()` + `filter_by_walls()`, `hit_units()` (the push is `hit_knockback_px` 17 over 0.1 s in the .tres), `play_hit_feel()` (`hit_shake` 3, `hit_hitstop` 0.05). The slash VFX and cone indicator are its own. The old `knockback` export is deleted (2026-09-28, after AB-M passed). |
| `knight/iron_resolve.gd` (W) | SELF, 0 s cast. Applies a haste status `iron_resolve` (+35% for 2 s, built from its exports like the old speed wrapper's) and an empower status `empower_iron_resolve` (50 + 50% AD snapshotted at cast = 82, 4 s) whose `empower_statuses` carry the slow `iron_resolve_slow` (−40% for 1.5 s, from the Knight). Its per-enemy VFX, shake 2.5 and hitstop 0.04 are its own through `AutoAttackComponent.set_empower_on_hit()`. An aura VFX while the empower is up. It calls neither `add_speed_modifier()` nor `add_next_attack_modifier()` (both stay as wrappers for other callers). |
| `knight/lunge.gd` (E) | POINT, 0.05 s cast, a conditional bonus with no conditions that applies Staggered to every enemy it hits (CHAMPIONS CH4), `movement.dash()` at 1400 u/s with `dash_curve`, afterimages, then every enemy along the start–end capsule (80 u wide) in sight from the nearest point of the path, through `hit_units()` (so a free Lunge's hits keep their chain depth) and `play_hit_feel()` (`hit_shake` 2.5). The first FLAG (AB-M): `lunge_stuns` stuns each enemy it hits for `flag_stun_duration` 0.5 s (a `status_stun` copy passed to `hit_units()` as a status of the hit). |
| `knight/cleave_wave.gd` (Q variant, AB-M) | `knight_q_cleave_wave.tres`, id `knight_cleave_wave`, `variant_of` `knight_cleave` (the `augment_cleave_wave` REPLACE puts it on Q). A small slash, then `Projectile.fire()` along the aim: 700 u (224 px), 900 u/s (288 px/s), 150 u (48 px) wide, pierce 20, 80 + 70% AD PHYSICAL, blocked by walls; a crescent `Polygon2D` rides on the projectile (visual only). Cleave's 0.2 s cast and 3 s cooldown; tags `core` `projectile`. |
| `knight/judgement.gd` (R) | UNIT, 0.75 s CHANNEL, 30 s cooldown (CHAMPIONS CH4) (`cancel_on_move` stays on), walks into range and sight first. Its missing-health bonus is a `DamageScaling` term (TARGET_MISSING_HEALTH 0.2) in `knight_r_judgement.tres` (the old `get_missing_health_bonus()` wrapper was deleted 2026-09-29). `hit_units()` with the stun as a status of the hit (a `status_stun` copy for `stun_duration` 0.75 s, applied after the damage from the Knight), `play_hit_feel()` (`hit_shake` 6, `hit_hitstop` 0.09). CH4: `stun_duration` is read with `get_effect_param()`, so its Fury bonus (RESOURCE_AT_LEAST 60: +0.5 s stun, +30% damage) reaches it; a hit that lands with that bonus consumes all the caster's Fury (`consume_resource_on_bonus`). |
| `slime/slam.gd` (elite Q) | POINT at the player's position, a telegraph circle during the 0.65 s cast, then a circle query from its center, its own crit roll per cast and 20 px push. Tags `core`, `area`. Moves to `hit_units()` when next touched (so does `test_strike`). |
| `HitPipeline.from_ability(caster, ability, target, cast)` | Fills tags (the ability's), damage type, `base_damage` + scaling terms, `ad_ratio` / `ap_ratio`, `proc_coefficient`, `hit_sound`; with a cast: charged and bonus params (`get_effect_param()`), empowers, `chain_depth`. |
| `StatsComponent.get_ability_param(ability, param)` | Reads the base with `ability.get_base_param(param)` (so scaling-term ratios are params too), applies scoped modifiers, never below 0, cached. |
| `ResourceComponent` (`Unit.resource_pool`) | `try_spend()`, `restore()`, `can_afford()`, regen, `resource_changed`, `depleted`. `ResourceType` MANA / ENERGY / FURY; NONE = no ResourceComponent. The Knight: MANA 300, 6/s until CHAMPIONS CH3 makes it FURY (CHAMPIONS.md, Fury). Abilities spend it (`resource_cost`); the HUD resource bar shows it. |
| `AutoAttackComponent.add_next_attack_modifier(id, bonus, on_hit, duration)`, `has_next_attack_modifier(id)` | **Wrapped:** applies an empower status `empower_<id>` (Architecture, Empowers); does nothing on a unit without a StatusComponent (the old dictionary was deleted 2026-09-29; every Unit scene has one). |
| `res://scripts/player/player.gd` | `CastMode` enum (`QUICK_WITH_INDICATOR`, `QUICK`), `@export var cast_mode` = `QUICK`, copied from Settings (Architecture, Input). `_on_ability_pressed()` / `_on_ability_released()` by cast style (hold-to-aim `aiming_slot`, CHARGE_UP press/release, recasts); `is_action_released` works for W on right mouse too. Esc cancels an aim or a charge-up (marked handled). `request_cast()` / `request_charge()` (cast now or buffer), `can_interrupt_swing()`, `cast_ability()` (target forgiveness), the indicator (`draw_vector_indicator()` for a VECTOR aim; `_drawn_vector_start` for tests), `set_aim_hint()` each physics frame. |
| `res://scripts/ui/ability_bar.gd` | Four slots, the cooldown sweep and seconds, the aiming border, the plain tooltip from the template, fail cues, the grey and blue tints, the charge count, the recast timer, the charge-up bar (Architecture, HUD). CHAMPIONS CH6: `has_live_bonus(slot)` and its gold outline. |
| `Events` | `unit_hit`, `unit_damaged`, `unit_died`, `status_applied`, `status_removed`, `ability_cast(unit, ability, ctx)`. |
| `res://scripts/enemies/enemy.gd`, `res://scripts/vfx/telegraph.gd` | AB13: the enemy AI casts a VECTOR ability with `get_ai_vector()` + `try_cast_vector()`; `Telegraph.line()` (a band that fills along its length) next to `circle()`. The AI skips a slot whose `get_fail_reason()` isn't empty (a failing condition, a cost) and tries the next one (2026-09-29). |
| `ReactionRule`, `Reactions` | Triggers HIT, UNIT_DIED, STATUS_APPLIED, ABILITY_CAST; `required_ability_scope`; `conditions`; unit and world rules by source id; chains to `MAX_CHAIN` 5. |

## Data (Resources)
Names checked against CONVENTIONS.md (reserved names, vocabulary). Every new field defaults to a value that keeps the old behavior.

Audio hooks: see AUDIO.md (`charge_sound` is added there for CHARGE_UP).

### New fields on Ability (`res://scripts/abilities/ability.gd`)
| Field | Type | Default | Notes |
|---|---|---|---|
| `cast_style` | `Ability.CastStyle` | `INSTANT` | `INSTANT`, `CHARGE_UP`, `CHANNEL`, `VECTOR` (AB13; added last in the enum). CHANNEL behaves as `cancel_on_move` on (the bool stays and still works: `is_channel()` = CHANNEL or `cancel_on_move`). Judgement's .tres has CHANNEL. A VECTOR ability's `targeting` is POINT (anything else: `push_error` when its aim starts). |
| `ap_ratio` | `float` | 0 | × `ability_power`, stage 2 like `ad_ratio`. |
| `scalings` | `Array[DamageScaling]` | `[]` | every other ratio (below). |
| `hit_knockback_px` | `float` | 0 | push on each unit `hit_units()` hits, away from where the caster stands; a scoped param. `Unit.on_hit()` applies it (blocked hits and unstoppable units aren't pushed); a unit the hit kills still slides. |
| `hit_knockback_duration` | `float` | 0.1 | seconds the push takes (the target's `knockback_curve`). |
| `hit_shake` / `hit_hitstop` | `float` | 0 | export group "Feel": the cast's shake (px) and hitstop (s), played once by `play_hit_feel(hits)` when at least one hit landed. |
| `resource_cost` | `float` | 0 | scoped param. |
| `max_charges` | `int` | 1 | scoped param, rounded down, min 1. |
| `recast_count` | `int` | 0 | extra parts after the first. |
| `recast_window` | `float` | 3.0 | seconds; scoped param. |
| `recast_resource_cost` | `float` | 0 | each later part; scoped param. |
| `charge_time` | `float` | 1.5 | seconds to full charge; scoped param. |
| `overhold_time` | `float` | 2.0 | seconds held after full; scoped param. |
| `overhold` | `Ability.Overhold` | `FIRE` | `FIRE`, `CANCEL_REFUND`. |
| `charge_scalings` | `Array[ChargeScaling]` | `[]` | the params that grow with the charge (or another named input). |
| `charge_sound` | `SoundEvent` | null | a loop on the caster while charging (AUDIO.md). |
| `projectile_speed` | `float` | 1200 | LoL units/s (384 px/s); scoped param. Export group "Projectile"; read only by abilities that fire projectiles. |
| `projectile_width` | `float` | 60 | LoL units, full width (19 px). |
| `projectile_count` | `int` | 1 | scoped param. |
| `projectile_spread_deg` | `float` | 15 | angle between neighboring projectiles of one cast. |
| `projectile_pierce` | `int` | 0 | 0 = stops on the first hit; scoped param. Its range is `cast_range`. |
| `vector_length` | `float` | 500 | AB13, export group "Vector": LoL units (160 px), the line's length from the start point; scoped param. Read only by VECTOR abilities; the start range is `cast_range`. |
| `vector_width` | `float` | 75 | LoL units (24 px), the line's full width (the indicator; shapes and ground areas that use the line). |
| `vector_min_drag_px` | `float` | 8 | a drag shorter than this at release is a tap (the direction is caster → start point). |
| `supported_flags` | `Array[StringName]` | `[]` | FLAG augments this script checks (e.g. `&"lunge_stuns"`). |
| `variant_of` | `StringName` | `&""` | for a REPLACE variant: the id of the ability it replaces. `get_modifier_scopes()` adds `ability:<variant_of>`, so item numbers on Cleave carry to its variant. |
| `ready_mode` | `Ability.ReadyMode` | `COOLDOWN` | `COOLDOWN`, `METER`: the slot is ready when the unit's meter is full. Reserved (CHAMPIONS); not built until the meter is. |
| `cast_conditions` | `Array[Condition]` | `[]` | all must pass to start a cast (part 0). |
| `recast_conditions` | `Array[Condition]` | `[]` | all must pass to use the next recast part. |
| `conditional_bonuses` | `Array[ConditionalBonus]` | `[]` | checked at the effect (cast or hit); see ConditionalBonus. |
| `cast_vfx` | `PackedScene` | null | AB14, export group "Presentation": a VFX scene played at cast start. null = nothing (Architecture, Cast progress and presentation hooks). |
| `impact_vfx` | `PackedScene` | null | AB14: played on each unit a hit of this ability gets through to. null = nothing. |
| `cast_anim` | `StringName` | `&""` | AB14: a clip of the caster's 3D model, positioned by cast progress (`UnitView`; on the 2D `Body/AnimationPlayer` until the 3D pivot's cleanup C3). Empty (or no such clip) = nothing. |
| `heal_on_hit_ratio` | `float` | 0 | CHAMPIONS CH5, export group "Sustain": heals the caster for this × the damage taken by each unit a hit of this ability gets through to (`HitPipeline.apply_on_hit()`, `Unit.heal()`). A scoped param, and a named-input scaling may shape it (the Knight's Cleave: `self_missing_health` through a curve). A kit mechanic, not the `life_steal` stat (CHAMPIONS.md, Sustain). |
| `heal_missing_health_ratio` | `float` | 0 | CHAMPIONS CH5b, export group "Sustain": heals the caster for this × their missing health, once per cast, on the cast's first hit that gets through (`HitPipeline.apply_on_hit()`, `Unit.heal()`; `HitContext.cast`, `CastContext.missing_health_healed`). A scoped param, shaped like `heal_on_hit_ratio`. The Knight's Cleave uses this one (0.55 through a curve on `self_missing_health`); its `heal_on_hit_ratio` is 0. |
| `can_consume_companion` | `bool` | false | planned (COMPANIONS.md, CO4): the cast may be aimed at the caster's own companion, which it then consumes at the effect start. The ability keeps its full use on enemies (consuming is never mandatory). |
| `companion_imprint_time` | `float` | 45 | planned (CO4): seconds a companion this ability consumes stays an imprint (TARGET 30–60). |
| `ai_uses` | `Array[AIUse]` | `[]` | planned (ENEMIES_AI.md, AI1): what the AI uses this ability for and when (What the AI uses an ability for). Empty = one `damage` use with no rules. |
| `respect_value` | `float` | −1 | planned (ENEMIES_AI.md, AI1): this ability's weight in enemies' respect; −1 = derived from its role tag and crowd control. |

Tags (`tags`, existing) carry the standard tags (placeholder roles until CHAMPIONS.md; CHAMPIONS.md keeps the Knight's as they are *(proposed)*): Cleave `core`, `area`, `cone` (and `melee` since 3D pivot P9); Iron Resolve `defensive`, `buff`; Lunge `mobility`, `dash`, `movement` (and `melee`); Judgement `ultimate`, `channel`; the slam `core`, `area`. Existing tags stay (don't rename). A style tag is written in the data and must match `cast_style` (the test checks it).

`description` (existing) is the tooltip template.

New methods:
- `get_role()`: the one role tag; `push_warning` once if there are zero or several.
- `get_base_param(param)`: an `@export` of that name, else a scaling term with that `param`; else `push_error` and 0.
- `has_param(param)`: the same test without an error; static `is_base_param(param)`: a number `@export` of the Ability base class. StatsComponent validates `ability:` / `tag:` scoped modifier keys with them (STATS.md).
- `get_charged_param(caster, param, charge := -1.0)`: −1 = the caster's current charge while it's charging this ability, else 1.
- `get_scaling(param)`, `get_scaling_damage(caster, target, charge, cast)`.
- `get_damage_against(caster, target, charge := 1.0)`: base + ratios + terms at that charge: what a hit would deal before crit and mitigation. `get_damage(caster)` = `get_damage_against(caster, null)`.
- `get_tooltip(caster)` (BBCode), `get_tooltip_plain(caster)`, `is_channel()`.
- `can_cast_custom(caster, ctx) -> bool` (virtual, true by default; the script's one-off check, ANDed with `cast_conditions` or `recast_conditions` by `ctx.part`), `get_custom_fail_text()` (virtual, "" by default).
- `get_effect_param(caster, param, cast, target = null)`: the param after scoped modifiers, its named-input scaling from `cast`, and every conditional bonus whose conditions pass now for that target (Architecture, Conditions).
- `get_conditions_for_part(part)`, `get_active_bonuses(caster, cast, target)`, `needs_condition_target()`.
- AB13: `get_vector_direction(caster, start, aim)` (start → aim for a drag of at least `vector_min_drag_px`, else `get_vector_tap_direction(caster, start)`: caster → start, or the caster's `facing` when the start is on it, right for a unit without one); `draw_vector_indicator(canvas, caster, start, aim)` (virtual; the default draws the start range, a start marker and the line `vector_length` × `vector_width` along `get_vector_direction()`, tap fallback included); `get_ai_vector(caster, target) -> Dictionary` (virtual, `{start, direction}` for the enemy AI; the default: start at the target, direction caster → target).
- Planned (ENEMIES_AI.md, AI1; ALLIES.md): `get_ai_plan(caster, situation) -> CastPlan` (virtual; where to aim and how good; the shared default aims at the target where it stands and wraps `get_ai_vector()`), and `get_effect_area(caster, ctx) -> Dictionary` (virtual; where a cast in progress will land, as a circle, cone or segment in px, from the ability's tags and params by default), which enemy perception reads for party casts and the ally brain for enemy casts.

### DamageScaling (Resource, `res://scripts/data/damage_scaling.gd`; inline in the ability's .tres)
| Field | Type | Notes |
|---|---|---|
| `param` | `StringName` | the term's param id, e.g. `&"target_missing_health_ratio"`. Its ratio is read through `get_param(caster, param)`, so scoped modifiers raise it. Must not match an `@export` on the ability (`push_error`). |
| `ratio` | `float` | the base ratio (0.2 = 20%). |
| `of` | `DamageScaling.Of` | `CASTER_STAT` (the caster's `stat`, final value), `CASTER_BONUS_STAT` (final − `get_base_value()`: League's "bonus"), `TARGET_MAX_HEALTH`, `TARGET_MISSING_HEALTH`, `TARGET_CURRENT_HEALTH`; planned: `CASTER_ADAPTIVE` (the higher of the caster's final `attack_damage` and `ability_power`, a tie going to AD; the hit's damage type follows; `stat` unused; COMPANIONS.md). |
| `stat` | `StringName` | for the CASTER kinds: a registered stat (`attack_damage`, `ability_power`, `max_health`, `armor`, `magic_resist`...). |
| `label` | `String` | tooltip text for the stat ("bonus AD", "of the target's missing health"); empty = generated from `of` and `stat`. |

`ad_ratio` and `ap_ratio` are the two built-in terms (`CASTER_STAT` on `attack_damage` / `ability_power`); they keep their HitContext stage-2 path. The tooltip lists them first, then `scalings` in order.
Judgement: `param` `&"target_missing_health_ratio"`, `ratio` 0.2, `of` TARGET_MISSING_HEALTH.

### ChargeScaling (Resource, `res://scripts/data/charge_scaling.gd`; inline)
- `param: StringName` (e.g. `&"cast_range"`, `&"base_damage"`, a scaling term's param), `min_fraction: float` (0.4 = 40% of the full value at input 0), `curve: Curve` (x = input 0–1, y = 0–1 progress from min to full; null = linear).
- `input: StringName = &"charge"`: the named input it reads (0–1). The class keeps its name; with another input it's a named-input scaling ("stronger the more / less…").
- `get_charged_param(caster, param, charge)` = full × lerp(`min_fraction`, 1, curve(charge)), where full = `get_param(caster, param)`. A param not listed = full at every charge. It reads only `charge` scalings; `get_effect_param()` reads every input from the cast.

### Condition (Resource, `res://scripts/data/condition.gd`; inline in the .tres that uses it, or `res://data/conditions/condition_<name>.tres` when shared)
| Field | Type | Default | Used by | Notes |
|---|---|---|---|---|
| `kind` | `Condition.Kind` | `SELF_HAS_STATUS` | all | see below |
| `negate` | `bool` | false | all | the "not" toggle. Doesn't flip a TARGET_ kind with no target (that fails either way). |
| `status_tag` | `StringName` | `&""` | SELF_HAS_STATUS, TARGET_HAS_STATUS, ENEMIES_IN_RANGE | a status tag; stacks are summed over every status with it (`StatusComponent.get_tag_stacks()`). ENEMIES_IN_RANGE: empty = any enemy. |
| `min_stacks` | `int` | 1 | SELF_HAS_STATUS, TARGET_HAS_STATUS | |
| `comparison` | `Condition.Comparison` | `AT_LEAST` | the *_HEALTH_PERCENT kinds, TARGET_DISTANCE | `AT_LEAST` (≥: above, farther), `LESS_THAN` (<: below, closer) |
| `value` | `float` | 0 | the *_HEALTH_PERCENT kinds (0–1 of max health), TARGET_DISTANCE (LoL units, edge to edge), RESOURCE_AT_LEAST (the amount) | |
| `count` | `int` | 1 | ENEMIES_IN_RANGE | at least this many |
| `radius` | `float` | 300 | ENEMIES_IN_RANGE | LoL units from the self unit's feet, each enemy's gameplay radius counted |
| `fail_text` | `String` | `""` | all | short text for later UI ("No marked target") |

Kinds (`Condition.Kind`):
- `SELF_HAS_STATUS`, `TARGET_HAS_STATUS`: the unit has at least `min_stacks` stacks of statuses tagged `status_tag`.
- `SELF_HEALTH_PERCENT`, `TARGET_HEALTH_PERCENT`: current ÷ max health compared with `value`.
- `TARGET_DISTANCE`: edge distance from self to target (LoL units) compared with `value`.
- `ENEMIES_IN_RANGE`: at least `count` living enemies of self within `radius` (and tagged `status_tag` if set); counts `AbilityUtil.enemies_of()`, so untargetable enemies don't count.
- `RESOURCE_AT_LEAST`: self's `resource_pool.current` ≥ `value`; a unit without a pool fails.
- `LAST_PART_HIT`: in a recast sequence, the previous part hit something (reads `cast`); false anywhere else.
- `CONSUMES_COMPANION` (planned, COMPANIONS.md; appended to the enum): the cast is consuming self's companion (`cast.consumes_companion`, which the consume at the effect start leaves true only if the companion was out); false without a cast.

Methods: `is_met(self_unit, target, cast = null)` (the kind's check, then `negate`; a TARGET_ kind with no valid target is false either way), `is_target_kind()`; static `all_met(conditions, self_unit, target, cast)` (AND; an empty list passes), `first_failed(...)` (for the fail text), `any_target_kind(conditions)`.
Planned (ENEMIES_AI.md, AI1–AI6): the kinds `THREATENED`, `TARGET_WHIFFED` and `RESPECT` (appended; `value` is seconds for the first two and 0–1 for RESPECT, with `comparison`), and an optional last argument `situation: SituationContext` on `is_met()`, `all_met()` and `first_failed()`; the three kinds read it and are false without it; every other kind ignores it.

### ConditionalBonus (Resource, `res://scripts/data/conditional_bonus.gd`; inline)
| Field | Type | Notes |
|---|---|---|
| `conditions` | `Array[Condition]` | all must pass, checked at the effect (cast-time params: the cast's target; hit-time: the unit hit) |
| `modifiers` | `Array[StatModifier]` | param changes: `stat` = the ability param (`base_damage`, `radius`, `ad_ratio`, a scaling term's param...), `type` FLAT / PERCENT_ADD / PERCENT_MULT, the same math as scoped modifiers; `scope` and `source_id` are ignored |
| `target_statuses` | `Array[StatusEffect]` | applied to each unit the effect hits (through `HitContext.statuses`) |
| `self_statuses` | `Array[StatusEffect]` | applied to the caster when the effect starts |
| `description` | `String` | the tooltip line ("+50% radius against stunned enemies") |

### CastContext (new fields)
| Field | Type | Default | Notes |
|---|---|---|---|
| `ability` | `Ability` | | the ability being cast (the variant if a REPLACE is active) |
| `charge` | `float` | 1.0 | a property over `inputs[&"charge"]`: CHARGE_UP 0–1 at release; every other cast 1.0 (so charged params are full) |
| `part` | `int` | 0 | recast part: 0 = the first cast, 1 = the first recast... |
| `flags` | `Array[StringName]` | `[]` | the FLAG augments active at cast start; `has_flag(flag)` |
| `empowers` | `Array[StatusEffect]` | `[]` | ability empowers consumed by this cast; always empty for a free cast |
| `is_free` | `bool` | false | a free cast (`CastAbilityGameplayEffect`) |
| `source_id` | `StringName` | `&""` | who granted a free cast (`item_…`, `passive_…`, `status_…`); empty for a slot cast |
| `chain_depth` | `int` | 0 | the reaction chain depth a free cast was triggered at |
| `inputs` | `Dictionary` (StringName → float 0–1) | `{charge: 1.0}` | the named scaling inputs; `get_input(name, default := 0.0)`, `set_input(name, value)` (clamped 0–1) |
| `last_part_hit` | `bool` | false | in a recast sequence, whether the previous part hit something (LAST_PART_HIT) |
| `sequence` | `Dictionary` | `{}` | LOOT L6: shared by every part of one recast sequence (AbilityComponent keeps part 0's with the sequence), so part 0 can leave something for later parts (Lunge's return reads `&"start"`); a cast outside a sequence has its own |
| `vector_start` | `Vector2` | | AB13, VECTOR casts: the start point (world space, clamped). `point` = the same spot and `direction` = caster → it, their usual meanings |
| `vector_direction` | `Vector2` | | AB13: the line's unit direction (start → the release cursor, or the tap fallback) |
| `vector_end` | `Vector2` | | AB13: `vector_start` + `vector_direction` × `vector_length` (px) |
| `progress` | `float` | 0.0 | AB14: the cast time's progress, 0 at cast start (at release for CHARGE_UP and VECTOR) to 1 at the effect start; 1 for a cast with no cast time and for a free cast. Scripts, telegraphs and `cast_anim` read it. |
| `target` | (existing) | | for a non-UNIT cast, AbilityComponent fills it with the condition target when conditions or bonuses need one (Architecture, Conditions) |
| `consumes_companion` | `bool` | false | planned (COMPANIONS.md, CO4): the press aimed this cast at the caster's companion (an ability with `can_consume_companion`); a UNIT ability then needs no unit target |

### AbilityAugment (Resource, `res://scripts/data/ability_augment.gd`; files `res://data/augments/augment_<name>.tres`)
| Field | Type | Notes |
|---|---|---|
| `id` | `StringName` | e.g. `&"lunge_stuns"`. For FLAG it's the flag the script checks. Two sources with the same id = one augment. |
| `kind` | `AbilityAugment.Kind` | `FLAG`, `EVENT`, `REPLACE` |
| `scope` | `StringName` | `&"ability:knight_lunge"` or `&"tag:area"` (the modifier scope strings). REPLACE needs an `ability:` scope. |
| `rules` | `Array[ReactionRule]` | EVENT: added as unit rules while active |
| `replacement` | `Ability` | REPLACE: the variant (its `variant_of` = the replaced id) |
| `display_name`, `description` | `String` | the tooltip line ("Lunge stuns for 0.5 s.") |
| `name_suffix` | `String` | a sigil's part of an item's name ("Storms" → "Iron Helm of Storms"; LOOT.md, The sigil pool; added in LOOT L4). Empty for every other augment. |

### ReactionRule (additions, `res://scripts/data/reaction_rule.gd`)
- Trigger `ABILITY_CAST` (added last in the enum): from `Events.ability_cast(unit, ability, ctx)`. The affected unit is the cast's target (`ctx.target`; null for non-UNIT casts without a condition target), the other unit is the caster, so a unit rule with `owner_role` SOURCE (default) means "when I cast", and `effect_target` OTHER hits the caster. `trigger_ctx` = the CastContext. Effects that need an affected unit do nothing when it's null.
- `required_ability_scope: StringName` (`&""` = any): `ability:<id>` / `tag:<tag>`, matched against the event's ability scopes (`get_modifier_scopes()`): ABILITY_CAST's ability, HIT's and UNIT_DIED's `HitContext.ability` (null never matches a non-empty scope).
- `conditions: Array[Condition]` (export group "Conditions", after the existing tag filters, which stay as they are): all must pass after the tag filters and before `chance` is rolled. Self = the unit the effects come from (the rule's owner, or for a world rule the event's other unit); target = the effect target (`effect_target`). `cast` = the trigger's CastContext when there is one (ABILITY_CAST), else null.

### StatusComponent (additions)
- `get_tag_stacks(tag) -> int`: the stacks of every active status carrying `tag`, summed (a status without stacks counts 1). What SELF_ / TARGET_HAS_STATUS read.
- `remove_statuses_with_tags(tags) -> int` (the cleanse), `get_empowers(trigger)` (the active empowers used up by `trigger`, in the order applied).

### New GameplayEffects (`res://scripts/data/`, subclasses of `GameplayEffect`)
All take the usual `apply(target, source, trigger_ctx)`; the source id is the rule's (the rule was added with one).
- `ModifyCooldownGameplayEffect`: `ability_scope` (`&""` = every slot of the champion's four; planned: never the companion slot, COMPANIONS.md), `mode` (`REDUCE_SECONDS`, `REDUCE_PERCENT` (of the time left), `RESET` (finishes the current recharge: +1 charge)), `amount`. Acts on `target`'s AbilityComponent, on each slot whose ability (what a press casts) matches; only a running cooldown changes (nothing while ready or while a recast window is open).
- `RestoreResourceGameplayEffect`: `amount` + `max_resource_ratio` × max resource, on `target.resource_pool` (nothing without one).
- `CastAbilityGameplayEffect`: `ability: Ability` (any Ability resource, e.g. a hidden variant); `target` casts it for free (`AbilityComponent.try_cast_free(ability, aim, target, source_id)`); the aim comes from `trigger_ctx`: a CastContext → its `point` and `target`; a HitContext → the hit unit (its position, and it's the target); otherwise the caster's current aim (`get_aim_point()` if it has one, else ahead of its facing). `CastContext.source_id` = the source id of the rule that fired (`Reactions.get_current_source_id()`, e.g. `&"augment_<id>"` for an EVENT augment's rule).
- `RemoveStatusesByTagGameplayEffect`: `tags: Array[StringName]`; removes every status on `target` carrying any of them (a cleanse is `[&"cc"]`).

### StatusEffect (additions, `res://scripts/data/status_effect.gd`)
- `reaction_rules`: unit rules on the unit while the status is active, source `&"status_<id>"` (added in `_start()`, removed in `_stop()`). Typed `Array[Resource]`: MovementComponent preloads status .tres files while scripts compile, and a `ReactionRule` type there pulled GameplayEffect and Unit into that preload cycle.
- `augments`: AbilityAugment resources on the unit's AbilityComponent while active, source `&"status_<id>"` (added in `_start()`, removed in `_stop()`; nothing on a unit without an AbilityComponent). Typed `Array[Resource]`, for the same preload cycle. A REFRESH of the same status keeps its augments (no remove and re-add, so the slots don't flicker). A form is a status tagged `form` (`is_form()`) whose augments REPLACE several slots.
- Empower fields (export group "Empower"); a status is an empower when `empower_consumed_by` isn't NONE (`is_empower()`; tag it `empower` too):
  - `empower_consumed_by: StatusEffect.EmpowerTrigger`: `NONE` (default), `BASIC_ATTACK_HIT` (the next swing that hits anything), `ABILITY_CAST` (the next ability cast that matches `empower_scope`, started by the player or the AI; never a free cast)
  - `empower_scope: StringName` (`&""` = any ability; `ability:<id>` / `tag:<tag>`)
  - `empower_base_damage`, `empower_ad_ratio` (the source's AD, at the hit): added to every hit of that swing or cast
  - `empower_statuses`: applied to every enemy that swing or cast hits (through `HitContext.statuses`). Typed `Array[Resource]`: a typed array of its own class made the script reference itself, reported as leaked resources at exit.
- Status tags used by rules here: `empower`, `unstoppable`, `untargetable`, `form`.

### Settings
- Key `&"cast_mode"`, saved as a word (`quick` / `quick_with_indicator`), default `quick`. `get_cast_mode() -> Player.CastMode`, `set_cast_mode(value)`; `setting_changed` as usual. It reuses `Player.CastMode` (no second enum).
- PauseMenu: "Cast mode: Quick / Hold to aim".

### Test and sandbox data
- `res://scenes/tests/abilities_test.tscn` + `scripts/tests/abilities_test.gd`: PASS/FAIL per check, headless exit code = failures, like the stats and combat tests.
- Test abilities (champion `test`): `scripts/abilities/test/`, `data/abilities/test_<slot>_<name>.tres`:
  - `test_triple_step` (`test/triple_step.gd`, `test_q_triple_step.tres`): a 3-part recast. DIRECTION, a 150 u (48 px) step at 1200 u/s with the dash curve, the last part 1.5× as far, `recast_count` 2, `recast_window` 3 s, cooldown 4 s, tags `mobility` `dash`.
  - `test_charged_line` (`test/charged_line.gd`, `test_q_charged_line.tres`): a Xerath-style line. CHARGE_UP, DIRECTION, `cast_range` 1100 u (440 at a tap), 80 base + 60% AD MAGIC (half at a tap: `base_damage` and `ad_ratio` at `min_fraction` 0.5), 80 u wide, blocked by walls, one crit roll, `charge_time` 1.5 s, `overhold_time` 2 s, FIRE, a 0.3 s release windup (`cast_time`), walking at 0.6, `dash_cancelable`, cooldown 3 s, tags `core` `line` `charge_up`.
  - `test_bolt` (`test/bolt.gd`, `test_q_bolt.tres`): a projectile. DIRECTION, 0.1 s cast, `cast_range` 900 u (288 px), 50 + 50% AD PHYSICAL, 1200 u/s, 60 u wide, 1 projectile, pierce 0, cooldown 1 s, tags `core` `projectile`.
  - `test_strike` (`test/strike.gd`, `test_q_strike.tres`): POINT, 0.2 s cast, `cast_range` 300 u, a 40 px circle at the point, 40 + 50% AD, cooldown 2 s, tags `core` `area`, `supported_flags` `test_strike_stuns` (each unit hit is also stunned 0.5 s). The AB8 tests build their augments and fake items in code.
  - `test_nova` (`test/nova.gd`, `test_q_nova.tres`): a circle around the caster (`radius` 200 u); `cast_conditions` SELF_HAS_STATUS `test_focus` with a fail text; a conditional bonus of +50% `radius` while ENEMIES_IN_RANGE ≥ 2; damage scaling by `self_missing_health`.
  - `test_mark_strike` (`test/mark_strike.gd`, `test_q_mark_strike.tres`): part 0 hits and applies `status_test_mark`; `recast_conditions` ENEMIES_IN_RANGE with tag `test_mark` and LAST_PART_HIT; part 1 strikes the marked enemy.
  - Test statuses `status_test_focus.tres` (tag `test_focus`, on the caster) and `status_test_mark.tres` (tag `test_mark`, on a target); a fake item `res://data/reactions/reaction_test_execute.tres` (not in `world/`, so it's only on a unit that's given it; HIT, the attacker's rule, `conditions` TARGET_HEALTH_PERCENT < 0.3 → a 30 proc hit), source `item_test_execute`.
- AB13: `test_vector_line` (`test/vector_line.gd`, `test_q_vector_line.tres`): a Viktor E-style line. VECTOR, POINT, `cast_range` 500 u (160 px start range), `vector_length` 500 u (160 px), `vector_width` 75 u (24 px), `vector_min_drag_px` 8, a 0.2 s release windup (`cast_time`), `overhold_time` 2 s FIRE, `roots_during_cast` off and `cast_move_speed_multiplier` 0.6 (aiming slows, doesn't root), `dash_cancelable`, `hit_shake` 2.5 and `hit_hitstop` 0.04, 60 + 50% AD MAGIC on every enemy along the line (`along_segment()`, in sight from the start point, one hit each through `hit_units()`), cooldown 3 s, tags `core` `line` `vector`. All numbers are placeholders.
- AB13: `test_vector_wall` (`test/vector_wall.gd`, `test_w_vector_wall.tres`), an enemy test ability: VECTOR, POINT, the same range, length and width, a 0.7 s cast time with a `Telegraph.line()`, 100 PHYSICAL along the line (in sight from the start point, through `hit_units()`), `resets_auto_attack` off, `hit_shake` 3 and `hit_hitstop` 0.06 (the slam's), cooldown 6 s, tags `core` `line` `vector`; its `get_ai_vector()` lays the line across the elite → player direction, centered on the player (a wall across the escape path). The start is clamped to `cast_range` as at a press, so with the player near the edge of the range the wall sits a little toward the elite (at 160 px it still covers the player). Put on the sandbox elite's W by `SandboxAbilities.test_elite_w`, which `sandbox.tscn` sets. The sandbox's `test_q` is empty since AB-M (set it to `test_vector_line` in the Inspector to try the line).
- 3D pivot P9: `test_uppercut` (`test/uppercut.gd`, `test_w_uppercut.tres`), the player's test knock-up: DIRECTION, a 2 m cone (`cast_range` 200 u, 50° half-angle), 30 + 30% AD physical, `hit_knockback_px` 64 over 0.25 s and `status_airborne` for `airborne_duration` (0.75 s) on every enemy hit, tags `core` `area` `cone` `melee`, cooldown 2 s, 0.15 s cast. On W in the 3D sandbox only (`SandboxAbilities.test_w`); not part of any kit.
- AB15 *(proposed, 2026-10-04)*: `test_blink` (`test/blink.gd`, `test_q_blink.tres`), the player's test blink:
  - POINT, `cast_range` 400 u (128 px, Flash's), no cast time, cooldown 1 s, no damage, tags `mobility` `blink`.
  - A `through_walls` export (on); `test_q_blink_sight.tres` is the same with it off.
  - `can_cast_custom()` fails while the caster is dash-blocked (fail text "Rooted").
  - Its indicator: the range and the landing circle where it would really land (`get_blink_landing()`).
  - In both sandboxes, **B** casts it for free toward the cursor, and **Shift+B** casts the stop-at-walls one: new `SandboxAbilities` exports `test_blink` and `test_blink_sight`, raw keys in that sandbox-only script, as SandboxAugments reads 1–4; B is unbound elsewhere (checked 2026-10-04). Not part of any kit.
- `SandboxAbilities` node in `sandbox.tscn` (`res://scripts/rooms/sandbox_abilities.gd`, source `&"sandbox_demo"`): `demo_costs` (on) and `costs` (ability id → cost: Cleave 30, Iron Resolve 40, Lunge 50, Judgement 80), given as scoped FLAT `resource_cost` modifiers so the bar and the fail cue can be played; `demo_charges` (on by default; off in `sandbox.tscn` since TALENTS T2, so Twin Lunge's charge reads cleanly; the code stays) and `extra_charges` (ability id → extra charges: Lunge +1), scoped FLAT `max_charges`; `test_q: Ability` (null = the Knight's Q; set a test ability in the Inspector to put it on Q in the sandbox); AB13: `test_elite_w: Ability` (null = none; puts an ability on the sandbox elite `Elite1`'s W); 3D pivot P9: `test_w: Ability` (null = the Knight's W; the 3D sandbox `sandbox_3d.tscn` sets the test Uppercut). room_01 has none.
- AB-M (built 2026-09-28): `knight/cleave_wave.gd` + `knight_q_cleave_wave.tres` (id `knight_cleave_wave`, `variant_of` `knight_cleave`); augments `augment_lunge_stuns.tres`, `augment_cleave_wave.tres`, `augment_judgement_reset.tres`, `augment_cleave_casts_lunge.tres`; a `SandboxAugments` node (`res://scripts/rooms/sandbox_augments.gd`) holding four fake items (source ids `item_test_<name>`), toggled with the number keys 1–4 read as raw keys in that sandbox-only script (no input action).
  - The augments (`res://data/augments/`): `lunge_stuns` (FLAG, `ability:knight_lunge`); `cleave_wave` (REPLACE, `ability:knight_cleave` → `knight_q_cleave_wave.tres`); `judgement_reset` (EVENT, `ability:knight_judgement`: a UNIT_DIED rule, owner SOURCE, effect target OTHER, `ModifyCooldownGameplayEffect` RESET on `ability:knight_judgement`); `cleave_casts_lunge` (EVENT, `ability:knight_cleave`: an ABILITY_CAST rule, effect target OTHER, `CastAbilityGameplayEffect` with `knight_e_lunge.tres` itself, so the free Lunge goes to Cleave's aim point, clamped to Lunge's range, and carries Lunge's flags: with `lunge_stuns` on, it stuns too). Both EVENT rules take the augment's scope, and the wave's scopes include `ability:knight_cleave` (`variant_of`), so the wave also casts the free Lunge.
  - `SandboxAugments`: `items: Array[AbilityAugment]` (keys 1–4 in order; `sandbox.tscn` lists the four), `show_list` (on: a small list at the top right, "1  Lunge stuns  ON"); `toggle(index)`, `is_equipped(index)`, static `get_source_id(augment)` (`&"item_test_<augment id>"`). A new Knight (a reload) starts with nothing equipped. The sandbox's `test_q` is empty for AB-M (the wave replaces Cleave only).

## Architecture / contracts
### AbilityComponent (additions; the existing API keeps working)
Per-slot state: charges and the recharge timer (`_cooldown_left` is the recharge timer), the recast part and window, and the slot's state at cast start (for refunds). One cast or charge-up at a time (`casting`, `casting_slot`).

**The companion slot** (planned, COMPANIONS.md, CO3): a fifth slot, `&"companion"` (export `companion: Ability`), holds the chosen companion's command, cast with Tab (`ability_companion`). It has the same per-slot state, cast flow, buffer and fail cues as Q/W/E/R. `SLOTS` stays the champion's four, so code that means the champion's slots keeps meaning them (talent groups, the resource bar's thresholds); an `ALL_SLOTS` adds it where every slot is meant (cooldowns, casting, `get_all_abilities()`, `get_slots_matching()`). `get_cooldown_duration()` takes a `companion`-role ability's `cooldown` without ability haste (Ryan, 2026-10-03: the command's 25–50 s cooldown is the companion's own).

Queries:
- `get_ability(slot)`: the **active** ability (the recast sequence's, else the winning REPLACE variant, else the export); the HUD, Player and the tooltip read it. `get_base_ability(slot)`: the export. `get_all_abilities()`: every slot's export and every augment's REPLACE variant, each once (StatsComponent's scoped key check).
- `is_ready(slot)`: charges > 0 (METER later); a recast window counts as ready. With `max_charges` 1 that's exactly "cooldown done".
- `can_cast(slot)` (ignores the cost and the conditions; the input buffer uses it), `can_afford(slot)`, `get_fail_reason(slot, aim, target)` (`""` = can cast; order: blocked → `"silenced"`, on cooldown → `"not ready"`, casting → `"busy"`, cost → `"not enough resource"`, conditions → `"condition"`).
- Charges: `get_charges()`, `get_max_charges()`, `get_cooldown_left()` (time until the next charge), `get_cooldown_fraction()` (the sweep).
- Recasts: `get_recast_part()` (the next part, 0 = no sequence going), `get_recast_time_left()`, `get_recast_window()`, `get_slot_cost()` (the next press's cost).
- Charge-up (and the VECTOR hold, which uses the same path): `is_charging()`, `get_charge()` (0–1), `get_overhold_left()`, `get_charge_ability()`, `get_locked_charge_aim()`, `has_charge_indicator()`. AB13: `get_vector_start()` (the start point while a VECTOR aim or its release windup is going; `Vector2.INF` otherwise).
- Augments: `get_augments(slot)`, `get_disabled_augments(slot)` (`{augment, reason}`), `get_flags(ability)`, `get_augment_tooltip_lines(ability)`, `get_slots_matching(scope)`.
- Conditions: `conditions_pass()`, `get_condition_fail_text()`, `get_aim_hint()`.
- Cast progress (AB14): `get_cast_progress()` (the cast in progress, 0–1; 0 with none), `get_cast_speed(ability)` (1.0 for now).

Commands:
- `try_cast(slot, aim, target_unit)`: a recast part when the slot's window is open; fail reasons through `cast_failed(slot, reason)`: `"not ready"`, `"busy"`, `"no target"`, `"not enough resource"`, `"silenced"`, `"condition"` (constants `FAIL_NOT_READY`, `FAIL_BUSY`, `FAIL_NO_TARGET`, `FAIL_NO_RESOURCE`, `FAIL_SILENCED`, `FAIL_CONDITION`). `fail_cast(slot, reason)` emits `cast_failed` for a press the Player or the buffer refuses. The cost is paid in `_do_cast()` and refunded by `_cancel_cast()`, `interrupt_cast()` and the end-of-cast-time interrupt.
- `try_start_charge(slot, aim)`, `release_charge(aim)`, `try_cancel_charge()` (Esc; refund), `set_charge_aim(aim)`: CHARGE_UP and VECTOR.
- AB13: `try_cast_vector(slot, start, direction) -> bool`: casts a VECTOR ability at once with a given start (clamped as at a press) and direction, for the enemy AI and tests (VECTOR flow).
- `reduce_cooldown(slot, seconds)`, `reduce_cooldown_percent(slot, fraction)` (of the time left), `reset_cooldown(slot)` (finishes the current recharge: +1 charge; `cooldown_finished` fires if the slot had 0 charges). All three do nothing while no cooldown runs (ready, or a recast window open); a recharge that finishes goes through `_finish_recharge()`, the same code as the timer.
- `add_augment(augment, source_id)`, `remove_augments_from(source_id)`, `try_cast_free(ability, aim, target, source_id)`, `set_aim_hint(point)`.
- `interrupt_cast()`: also ends a charge-up, and refunds the cost as well as the charge.

Signals: `charges_changed(slot, charges, max_charges)`, `charge_started(slot, ability)`, `charge_released(slot, ability, charge)`, `charge_ended(slot, ability)`, `recast_window_started(slot, part, time)`, `recast_window_finished(slot)`, `augments_changed(slot)`, `cast_failed(slot, reason)`. `cooldown_finished(slot, ability)` fires when a slot goes from 0 charges to 1 (with `max_charges` 1: when the cooldown ends), so `ready_sound` pings when the slot becomes castable.

### The cast flow (INSTANT and CHANNEL), in order
1. `try_cast()`: the active ability; an open recast window makes this the next part. Ready (a charge, or a recast part), `can_cast`, `can_afford` (`resource_cost` for part 0, `recast_resource_cost` after; a unit without `resource_pool` always affords), conditions. Targeting as before; a UNIT cast walking into range pays nothing until it starts.
2. Note what a refund must give back: the charge taken (step 5) and the cost (step 4).
3. Snapshot the augments: `ctx.ability`, `ctx.flags` (active FLAG augments this ability supports).
4. Pay the cost (`resource_pool.try_spend()`).
5. Part 0 without recasts: take a charge; if the recharge timer isn't running, start it (`get_cooldown_duration()`: scoped `cooldown`, then haste). With recasts: take the charge, but its recharge starts when the sequence ends.
6. Locks and walking (`&"casting"`; CHANNEL = `cancel_on_move` rules).
7. `cast_sound`, `cast_started`, `on_cast_started()` (telegraph) and its `telegraph_sound`; `cast_vfx` and `cast_anim` (AB14; nothing while empty).
8. (No event here: ABILITY_CAST fires at the effect start, step 10.)
9. The cast time, as cast progress from 0 to 1 (AB14; Cast progress and presentation hooks, below). A stun (any `blocks_cast` status) applied now interrupts at once (StatusComponent's `status_applied`): `interrupt_cast()` gives the charge back and refunds the cost; no ABILITY_CAST fires. A dash or move cancel works the same way (`_cancel_cast()`).
10. Effect start: read `self_missing_health` again (CHAMPIONS CH5), consume ability empowers (`ctx.empowers`; not for a free cast; before `ability_cast`, so a rule granting the next one on cast doesn't feed this cast), planned (COMPANIONS CO4): consume the companion if `ctx.consumes_companion` (it turns false if the companion isn't out), apply passing bonuses' `self_statuses`, `Events.ability_cast(unit, ability, ctx)` (ABILITY_CAST rules fire now, free casts they trigger run at once), then `execute()`. Nothing is refunded from here.
11. Cleanup; `cast_finished`. A recast ability opens (or closes) its window here.

### CHARGE_UP flow
1. Press → `Player._on_ability_pressed()` → `request_charge(slot)` (the same rules as `request_cast()`: "not enough resource" and "condition" fail at once, otherwise charge now if `can_cast`, not dashing and `can_interrupt_swing`, else buffer) → `try_start_charge(slot, aim)`: `get_fail_reason()` as a cast (a swing is cut by the `&"casting"` attack lock). It **pays the cost**, sets `casting` / `casting_slot` and `is_charging()`, and sets up the cast's locks and walking rules through `_begin_cast_locks(ability, true)` (the same code a cast uses; a charge-up that roots roots for the whole hold). No charge or cooldown is taken. Starts `charge_sound` (`Audio.play_on(…, unit)`), `charge_started`. `try_start_charge()` on anything that isn't a CHARGE_UP part 0 is a plain `try_cast()`.
2. Each physics frame (`_update_charge()`, game time: hitstop and pause stop it): hold += delta; `get_charge()` = min(hold / `charge_time`, 1). At `charge_time` + `overhold_time` → FIRE (`release_charge()` at `_charge_aim`, which the Player keeps on the cursor with `set_charge_aim()` each frame) or CANCEL_REFUND (a cancel). While a charge the Player started is going, the Player checks `Input.is_action_pressed()` for the slot's action each physics frame; not held = released (covers a release lost to a focus change). Only a charge the Player's key started is released this way.
3. Release (`Player._on_ability_released()` → `release_charge(aim)`): the phase goes from HOLDING to RELEASED: the aim and charge lock (`get_charge()` returns the locked charge), `charge_sound` stops, `charge_released`; `ctx.charge` = the charge, `ctx.point` / `direction` from the release aim (POINT clamps to the **charged** `cast_range`); then `_do_cast(…, precharged = true)`: the charge is taken and the cooldown starts (the cast starts now), the cost and locks aren't redone, `cast_sound`, `cast_started`, the release windup (`cast_time`), and at effect start `_end_charge()` then `execute()`.
4. Esc (`try_cancel_charge()`, marked handled so it doesn't pause; while holding or in the release windup), a dash on a `dash_cancelable` ability, a move press on a channel, a stun or death (holding or in the windup): cancel or interrupt, refunded (the cost; after release also the charge and the cooldown). A cancelled or interrupted charge emits `cast_cancelled` / `cast_finished` like a cast.
- **The end-charge path:** `_end_charge()` is the only place a charge-up ends: the phase back to NONE, `charge_sound` stopped, `charge_ended(slot, ability)`. `_cancel_cast()`, `interrupt_cast()`, the end-of-cast-time interrupt and the effect start all call it. The Player redraws on `charge_ended` (and, as a safety net, the frame its indicator slot goes empty); the ability bar redraws every frame and draws the charge bar only while holding. The charge-up keeps its own ability from the press (`get_charge_ability()`, `_cast_ability`), so a REPLACE swapping the slot mid-charge doesn't change what's charging.
5. UNIT targeting isn't supported for CHARGE_UP (`push_error` when a charge starts).
6. `try_cast()` on a CHARGE_UP ability (an enemy, a free cast) casts it at once at full charge (`ctx.charge` 1).
7. A buffered CHARGE_UP press fires through `Player.start_buffered_ability()`: it starts charging, and if the key isn't held any more it releases at once, a tap (charge 0) *(proposed; Open questions)*.
8. The indicator: `Player.get_indicator_slot()` is the aimed slot, or the charge-up's slot from the press until its effect starts (`has_charge_indicator()`); the Player draws that ability's indicator at `get_indicator_aim()` (the cursor while holding, the locked aim in the release windup), points the sword there and shows the cross cursor. `draw_indicator()` reads `get_charged_param(caster, &"cast_range")`: the current charge's range while holding, the locked charge's in the windup.
9. Hits: an ability script passes its `ctx` to `HitPipeline.from_ability(caster, self, target, ctx)` so damage, ratios and scaling terms use `ctx.charge`.

### VECTOR flow
(AB13.) The CHARGE_UP flow above, through the same methods, signals and end path (they keep their charge-up names), with these differences:
1. **Press** → `Player._on_ability_pressed()` → `request_charge(slot)` → `try_start_charge(slot, aim)`: the same checks, cost paid now, cast locks and walking rules (`_begin_cast_locks(ability, true)`), `charge_sound` if the ability sets one, `charge_started`. Also for a recast part (part > 0) of a VECTOR ability: every part is aimed (a CHARGE_UP part still goes to `try_cast()`). It also places the **start point** (`_vector_start`, `get_vector_start()`): the aim clamped to `cast_range` from the caster, then, unless the ability `ignores_walls`, to the last valid spot on the line from the caster (`WorldQuery.shape_sweep(caster, clamped point, 2 px core, world layer 1)`), so a cursor inside a wall or out of line of sight puts the start at the wall's face (`_clamp_vector_start()`, `VECTOR_WALL_RADIUS_PX`). The start stays where it was placed while the caster walks. The press's condition check looks for the condition target near the start point too (only when the ability needs one).
2. **Holding** (`_update_charge()`): the Player keeps `set_charge_aim()` on the cursor. `get_charge()` is 1 (a VECTOR cast isn't a charge-up; `ctx.charge` is 1.0, so charged params are full). `charge_time` counts as 0: after `overhold_time` from the press the `overhold` behavior runs (FIRE at the current cursor, or CANCEL_REFUND). "Key not held" = released, as for CHARGE_UP.
3. **Release** → `release_charge(aim)`: the aim locks; `_make_context()` at the start point, then `_fill_vector()` from `_vector_start` and the release aim:
   - drag = aim − start. At least `vector_min_drag_px` long: `vector_direction` = its direction and `vector_drag` = min(drag length ÷ `vector_length` (px), 1). Shorter (a **tap**): `vector_direction` = caster → start (the caster's `facing` if the start is on the caster) and `vector_drag` 0.
   - `vector_end` = `vector_start` + `vector_direction` × `vector_length` (px); the cursor beyond it only sets the direction.
   - `point` = `vector_start` and `direction` = caster → start (their usual meanings), so the condition target is the enemy nearest the start point within `cast_range`.
   - Then, as CHARGE_UP: the charge (stored cast) is taken and the cooldown starts, `cast_sound`, `cast_started`, `on_cast_started()` (a telegraph), the release windup (`cast_time`), and at effect start `_end_charge()` then `execute()`.
4. **Cancels and interrupts**: exactly CHARGE_UP's (Esc, a dash on a `dash_cancelable` ability, a move press on a channel, a stun, death, overhold CANCEL_REFUND), refunded, through `_end_charge()`, which also forgets `_vector_start`. So every exit clears the indicator.
5. **The indicator**: from the press until the effect starts (`has_charge_indicator()`), the Player draws `ability.draw_vector_indicator(self, self, get_vector_start(), get_indicator_aim())` instead of `draw_indicator()` for a VECTOR ability: following the cursor while holding, locked during the release windup. The Player faces `get_indicator_aim()` and points the sword there, as for a charge-up.
6. **Without a mouse**:
   - `try_cast()` on a VECTOR ability (a free cast, or a hold-to-aim release whose slot became VECTOR) casts at once as a tap (`_make_cast_context()`, shared with `try_cast_free()`): start = the aim clamped as at a press, direction = caster → start, `vector_drag` 0.
   - `try_cast_vector(slot, start, direction)`: casts at once with that start (clamped as at a press) and direction, `vector_drag` 1 (no drag to measure; full, like an input without a cast). The usual checks and cost; the cast time as usual.
   - Enemy AI: `Enemy._try_cast_ability()` calls `try_cast_vector(slot, v.start, v.direction)` with `v = ability.get_ai_vector(unit, player)` for a VECTOR ability (after `set_aim_hint()`, as for any ability). The ability's `on_cast_started()` shows a `Telegraph.line()` during the cast time; a stun or death removes it the same frame, as for the slam. (ENEMIES_AI.md: the enemy brain replaces this naive loop, which stays behind `Enemy.naive_casting` until the milestone; the brain casts through the same `try_cast_vector()`, aimed by `get_ai_plan()`, whose default wraps `get_ai_vector()`.)
7. **Hits and ground areas** use the three vector fields: e.g. `AbilityUtil.along_segment(caster, vector_start, vector_end, width)` for a line of hits; a ground area (a wall of fire) along the same segment.
8. **Named input** `vector_drag` is filled at release (step 3) and read like any other (`ChargeScaling.input`, `get_effect_param()`).

### Charges and recasts
- Recharge: while `charges < max_charges`, the timer counts down one cooldown (`get_cooldown_duration()` at the moment it starts); at 0, +1 charge and, if still below max, it starts again. A cast takes a charge and starts the timer only if none is running and the slot is now below max. A lower max (an item removed) leaves extra charges until they're spent, with no timer; a higher max starts recharging (like DashComponent). A slot starts full the first time it's asked. `cooldown_finished` (and the ready ping) fire only when a slot goes from 0 charges to 1. A refund gives back the one charge the cast took: back at max the timer stops, below max a running recharge keeps its progress. The HUD draws the sweep dark only at 0 charges.
- Recasts: part 0 takes a charge; its recharge doesn't start. The sequence exists from part 0's cast start (`_recast[slot]` = next part, window time, the ability, `last_part_hit`), so `is_ready()` is true and `get_recast_part()` is 1 even during part 0's cast time (a press then is buffered and fires as part 1). When part 0's effect finishes, the window opens (`recast_window`, game time; `recast_window_started`). A press on the slot inside the window casts part 1 (no charge needed, `recast_resource_cost`; `get_slot_cost()` / `can_afford()` use the next part's cost), and so on up to `recast_count`. The window doesn't run while one of the slot's parts is being cast and restarts after each part. The sequence ends (`recast_window_finished`) when the last part finishes or the window runs out; the next physics frame the recharge starts. A refunded part 0 never starts its sequence; a refunded later part gives back its cost and keeps the window time it had. A recast ability should have `max_charges` 1; with more, the recharge timer pauses during a sequence (Homeward Lunge with Twin Lunge, LOOT L6: each charge its own sequence). Part 0's `CastContext.sequence` dictionary is kept with the sequence and handed to every later part (LOOT L6).

### Cast progress and presentation hooks (AB14)
Ryan, 2026-09-29. Two goals: a future cast-speed stat or item plugs into one place without touching the cast flow again, and the art/VFX/animation pass is pure data (filling the hook fields), with animations that can't drift from the mechanical timer.

**Cast progress**
- One path for every cast time: the INSTANT and CHANNEL cast time (flow step 9), the release windup of CHARGE_UP and VECTOR (`cast_time` after release), each recast part's cast time, enemy casts (the slam, the vector wall). Judgement's channel (0.75 s from CHAMPIONS CH4) is the first case that matters.
- AbilityComponent keeps the cast's progress (`_cast_ctx.progress`, `get_cast_progress()`), 0 at cast start (at release for CHARGE_UP and VECTOR). Each physics tick it takes delta × `get_cast_speed(ability)` off the cast's seconds left, and progress = 1 − seconds left ÷ `cast_time`. Game time, so hitstop slows it and the pause menu stops it, exactly as the old game-time timer did.
- The effect starts (flow step 10) on the tick the seconds left reach 0 or below, whatever real time that took. Progress is then exactly 1.
- **The same frame as the old timer, by construction** (built 2026-09-29, measured in Godot 4.7.2): the tick runs deferred from `_physics_process()` (`_advance_cast_time()`), so it runs after every node's physics that frame, where SceneTreeTimers were counted. A cast started anywhere in a frame's node pass counts that frame; a cast started between frames (an input event) or at another cast's end counts from the next one, as the timer did. The countdown takes the same float steps as the timer (seconds left − delta × cast speed). Built that way in AB14, it also kept the timer's float residue: a cast time that is an exact number of ticks (0.05, 0.1, 0.2, 0.3, 1.5 s) took one tick more than nominal (0.2 s = 13 ticks). **AB14b** (Ryan, 2026-09-29) removed that extra tick: the countdown is done within `CAST_TIME_EPSILON` (0.0001 s) of 0, as the swings' `SWING_TIME_EPSILON`, so every cast time takes its nominal tick count rounded up (0.05 / 0.1 / 0.2 / 0.3 / 1.5 s = 3 / 6 / 12 / 18 / 90 ticks); 0.65 and 0.7 s (39 and 42) were already on time and didn't move. The frame rules above (which frame a cast counts from) are unchanged.
- `cast_time` 0: progress is 1 at once and the effect runs in the same call, as today. A free cast has no cast time: progress 1.
- **Cast speed:** `get_cast_speed(ability) -> float` returns 1.0 (hardcoded). It's the only place a future cast-speed stat or cast-speed item plugs in, and it's read every tick, so a change mid-cast applies from that tick with no restart. It never touches cooldowns: `ability_haste` stays the cooldown stat (`get_cooldown_duration()`), unchanged. A cast speed of 0 or less is treated as 1.0 (`push_error` once), so a cast can never hang.
- Cancels and interrupts don't change: a dash or move cancel, a stun or death stops the cast where it is (`_cast_serial`), refunds as before, and the progress is dropped with the cast. `cast_started` stays at cast start, ABILITY_CAST at the effect start.
- The waiting `_do_cast()` keeps its shape: instead of awaiting a `create_timer()`, it awaits the internal signal `_cast_time_elapsed`, emitted when the seconds left reach 0 and also by a cancel or interrupt (`_stop_cast_time()`, right after the serial is bumped), so a waiting cast always resumes and sees its serial changed.
- **The old path** (the `create_timer()` wait behind `use_cast_progress`) was deleted after Ryan's AB14 play test passed (2026-09-29), as approved; the abilities test keeps checking every cast against the old timer's arithmetic (its tick count computed from `cast_time`).
- **Telegraphs follow the cast.** A telegraph that belongs to a cast (`CastContext.telegraph`, set in `on_cast_started()`) fills with that cast's progress: AbilityComponent calls `Telegraph.set_progress(progress)` at cast start (0) and each tick, and a driven telegraph ignores its own clock (`is_driven()`). Read during a physics frame, `get_progress()` is the exact value; while drawing it's interpolated between the last two ticks, so it fills smoothly at any refresh rate. It's exactly full at the hit. A telegraph with no cast keeps its own clock (`duration`). `slam.gd` and `vector_wall.gd` don't change.
- **Not on cast progress** (they aren't casts): cooldowns and recharges (they count down from a duration fixed when they start; progress-based cooldowns, so a haste change reaches a running cooldown, are an open item, DECISIONS.md, Abilities), recast windows, status durations (a future duration stat scales them when applied, like tenacity), Fury's out-of-combat delay and decay (CHAMPIONS.md), displacements (their own normalized speed curves), swings (their own speed, `attack_speed`, COMBAT.md). The charge-up hold (`charge_time`) still counts seconds; it takes cast speed when a champion first has a charge-up (Open questions).

**Presentation hooks**
- Three fields on every Ability (export group "Presentation"): `cast_vfx` (`PackedScene`, null), `impact_vfx` (`PackedScene`, null), `cast_anim` (`StringName`, empty). Empty = the dispatch call returns at once: no node, no visual, no cost. Hooks are VFX only; they never change gameplay state (CONVENTIONS).
- `cast_vfx`: `Ability.play_cast_vfx(caster, ctx)` at cast start, before `cast_started` (flow step 7; CHARGE_UP and VECTOR at release, with `cast_sound`; each recast part; a free cast when it runs). It instances the scene next to the caster (the caster's parent, the room's `Entities`), at the caster's feet, rotated to `ctx.direction`, and calls `setup(caster, ctx)` on its root if the root has one. Every hook scene goes through one helper, `VFX.spawn_scene(scene, anchor, pos, angle, setup_args)` (null scene = nothing).
- `impact_vfx`: `Ability.play_impact_vfx(caster, target, hit)` once for each unit whose hit got through (not blocked): in `Ability.hit_units()` and in `Projectile` hits. At the target's feet, rotated caster → target; `setup(caster, hit)` if the root has one. Abilities that don't use `hit_units()` yet (the slam, `test_strike`) get it when they move to `hit_units()`.
- `cast_anim`: the 3D view plays it on the caster's model (`UnitView`; 3D.md, Animation): from the clip's start to its strike frame by the cast's progress, so the strike lands on the effect start whatever the cast speed, then its follow-through; a cast with no cast time leads by a fixed time (`instant_cast_lead`). No such clip or an empty name = nothing. A free cast plays no `cast_anim` (it runs alongside the unit's own cast). Until the 3D pivot's cleanup C3, AbilityComponent also played it on a 2D `Body/AnimationPlayer` (seeked to progress × its length each tick, stopped by a cancel); no unit ever had one, and it went with the 2D bodies.
- Basic attack swings have the same trio, named for swings (COMBAT.md, AttackSwing): `swing_vfx`, `impact_vfx`, `swing_anim`, timed by the swing's own speed (`attack_speed`), not cast speed.
- Items (Ryan, 2026-09-29, for LOOT.md): an item's active ability is an Ability cast through AbilityComponent, so it inherits the hooks and cast speed with no extra work. Stat-only items need only an icon. A pickup / equip VFX hook (`item_vfx`, empty by default) was planned as LOOT.md's; (LOOT sync, approved 2026-10-03) not needed: a drop's look is its view (`PickupView`) and its rarity's drop sound, and equip feedback is UI.md's. Not part of AB14 or CHAMPIONS CH1–CH5.

### Input (Player, PlayerInput)
- `_on_ability_pressed(slot)` by the active ability's `cast_style`: INSTANT → QUICK: `request_cast()`; QUICK_WITH_INDICATOR: aim (`aiming_slot`), release casts (SELF casts at once). CHANNEL → `request_cast()` on press. CHARGE_UP and VECTOR → `request_charge(slot)` (start now, or buffer). A press while the slot's recast window is open → `request_cast()` (the next part), whatever the style, except a VECTOR ability's next part → `request_charge(slot)` (AB13: every part is aimed).
- `_on_ability_released(slot)`: the aimed slot casts; the charging (or vector-aiming) slot releases.
- A buffered VECTOR press fires through `Player.start_buffered_ability()` like a CHARGE_UP one: the start point goes where the cursor is when it fires, and if the key isn't held any more it releases at once on its own start point (a tap: `_release_charge(get_vector_start())`).
- Keys and right mouse (W) arrive the same way: `ability_q` / `ability_w` / `ability_e` / `ability_r` in `_unhandled_input` with `is_action_pressed` / `is_action_released`, which work for mouse buttons too. Planned (COMPANIONS CO3): `ability_companion` (Tab) for the companion slot, through `Player.ABILITY_ACTIONS`.
- Cast mode: Player copies `Settings.get_cast_mode()` into `cast_mode` at start and on `Settings.setting_changed` (like `dash_toward_cursor`), so the Inspector value only lasts until then. A switch mid-aim doesn't touch the aim in progress.
- The buffer (MOVEMENT.md) is unchanged except: a press on an ability that's ready and not blocked but can't be afforded, or fails its conditions, fails at once and isn't buffered (`Player.request_cast()` / `request_charge()`); a press that is also blocked or on cooldown is buffered as before and, if it runs out, shows that reason; a buffered CHARGE_UP press starts charging when it fires (step 7 above).

### Damage: where each term enters the pipeline
- `HitPipeline.from_ability(caster, ability, target, cast)`: `base_damage` = the `base_damage` param + `get_scaling_damage()` (every `scalings` term, evaluated now: caster stats, target health); `ad_ratio` / `ap_ratio` = the params (stage 2 multiplies them by the source's stats). With a cast: charged and bonus params per target (`get_effect_param()`), ability empowers from `cast.empowers`, `cast.chain_depth`. So the order stays base → scaling → `damage_increase` → crit → mitigation (COMBAT.md), and every term crits.
- Tooltips use `get_damage_against(caster, null)`: target terms are 0 there and shown as text ("+20% of the target's missing health").

### Tooltips
- `get_tooltip(caster)` (BBCode) fills `description`:
  - `{damage}`: the current total without a target (base + ratios with the caster's stats), rounded, colored by damage type (the default `DamageNumberStyle`'s `get_damage_type_color()`, loaded from `Ability.DAMAGE_NUMBER_STYLE_PATH`); `{base_damage}`; `{ratios}`: "+70% AD +20% of the target's missing health": `ad_ratio`, `ap_ratio` (zero ones left out), then each term (`DamageScaling.get_label()`), each with its current ratio. The Knight's templates read "{damage} physical damage ({base_damage} {ratios})" → "125 physical damage (80 +70% AD)".
  - `{cooldown}` (after scoped modifiers and haste), `{range}` (`cast_range`), `{cast_time}`, `{cost}`, `{charges}`, `{recast_window}`, `{charge_time}`.
  - `{<param>}`: any ability param by name, a scaling term's param included; `{<param>%}` shows it as a percent (0.35 → "35%"). Numbers show up to 2 decimals without trailing zeros (3, 1.5, 0.75), percents up to 1. `{<param>_min}` for a charge-scaled param's value at charge 0 (a CHARGE_UP tooltip reads "{range_min}–{range}").
  - Then one line per conditional bonus (its `description`), then one line per active augment (its `description`) and one per disabled one ("disabled: another replacement is active").
  - An unknown placeholder stays as written, with a `push_warning` once per ability.
- `get_tooltip_plain(caster)`: the same without BBCode; the ability bar's `draw_string` tooltip uses it. A colored tooltip is UI.md's.
- A plain description without placeholders is returned as is.

### Events and the ABILITY_CAST trigger
- `Events.ability_cast(unit, ability, ctx)` (reserved name): emitted when the effect starts (flow step 10): after the cast time, after a CHARGE_UP's release windup, at each recast part's effect, and when a free cast runs. Not for a cast that's refused, still walking into range, only charging, or cancelled / interrupted before its effect.
- `Reactions` listens: trigger ABILITY_CAST, `required_ability_scope`, the unit tags of the affected unit, conditions, chance (not × `proc_coefficient`), chain depth. It keeps the source id of the rule whose effects are running (`get_current_source_id()`, read from `Unit.get_reaction_rule_entries()` and the world rules) and offers `run_at_depth(depth, callable)`. HIT and UNIT_DIED events count at the deeper of the current depth and `HitContext.chain_depth`.

### Free casts (`try_cast_free(ability, aim, target, source_id)`)
- Refused (false) if the unit is dead or `is_cast_blocked()`.
- Runs at once: a context from the aim (`_make_context()` with no slot: SELF / POINT / DIRECTION as usual, the given target kept), `ctx.is_free`, `ctx.source_id`, the FLAG augments snapshotted, `ctx.chain_depth` = `Reactions.get_chain_depth()` (inside a rule's effects that is already one link deeper); then `cast_sound`, bonus `self_statuses`, `Events.ability_cast` at that depth (`Reactions.run_at_depth()`), then `execute()` (not awaited). No cast time, cost, charge, cooldown, slot, locks, `cast_started` or empowers used up; it doesn't touch `casting`, so it never interrupts a cast in its cast time.
- Its hits carry the depth: `HitPipeline.from_ability()` copies `cast.chain_depth` to `HitContext.chain_depth` (a projectile's no-source hits too), so "on hit, also cast" can't loop through later hits.

### Augments
- `add_augment(augment, source_id)`: stored with its source. The same `id` from several sources counts once (it stays while any source has it).
- FLAG: active on each ability its `scope` matches that lists it in `supported_flags` (`get_flags(ability)`; the cast reads them into `ctx.flags` when its context is made). An exact-scope (`ability:<id>`) FLAG on an ability that doesn't list it: `push_error` once and ignored; a `tag:` scoped one is ignored silently by the abilities that don't support it.
- EVENT: while active, each rule is added as a unit rule under `&"augment_<id>"` (one copy however many sources have it); a rule with an empty `required_ability_scope` gets the augment's `scope` (a duplicated rule, so the shared .tres isn't changed; `conditions` ride along).
- REPLACE: the first active REPLACE for an ability (in the order added) wins; any other is disabled, with its reason for the tooltip (`get_disabled_augments(slot)`). Removing the winner activates the next one. The q / w / e / r exports never change; `get_ability(slot)` is what a press casts. So per-slot state (charges, recharge timer) carries over, a running cast or charge-up finishes as the ability it started with (`_cast_ability`, `_charge_ability`), and the recast window stays with the ability that opened it. A walk-into-range cast whose slot now casts another ability is dropped.
- Forms: a StatusEffect tagged `form` with several REPLACE augments (one per swapped ability); applying a `form` status that isn't already on removes any other `form` status on the unit first (StatusComponent; one form at a time). Everything else is REPLACE as above: the exports never change, cooldowns are per slot, a running cast keeps its ability.
- An augment can later get its own `conditions` field without restructuring.
- `augments_changed(slot)` fires on every change, for the HUD and tooltips.

### Empowers
- Basic attacks: AutoAttackComponent reads the unit's `BASIC_ATTACK_HIT` empowers once per swing, at the hit moment; `HitPipeline.add_empowers(ctx, empowers)` gives each target's hit `empower_base_damage` (into `base_damage`, so it crits with the swing), `empower_ad_ratio` (into `ad_ratio`: the attacker's AD at the hit) and `empower_statuses` and the tag `empowered`. When the swing hits anyone, those statuses are removed (consumed) before the hits resolve, so a rule on that hit can grant the next one. A swing that hits nothing keeps them. The League-style attack (enemies) adds the same empowers to its hit.
- Abilities: at effect start (flow step 10) the caster's `ABILITY_CAST` empowers whose `empower_scope` matches go into `ctx.empowers` and are removed (`_use_up_ability_empowers()`); `from_ability(…, cast)` adds them to every hit of that cast; a projectile whose caster is freed keeps the empower's damage in its snapshot. Free casts don't use them up: a free cast leaves the empower for the next real cast.
- `add_next_attack_modifier(id, bonus_damage, on_hit, duration)` is a thin wrapper: it applies a runtime empower status (id `&"empower_<id>"`, `AutoAttackComponent.get_empower_status_id(id)`, so an `iron_resolve` empower doesn't replace the haste status `iron_resolve`; tags `empower` + `buff`, `BASIC_ATTACK_HIT`, `empower_base_damage` = `bonus_damage`, that duration, REFRESH) and registers `on_hit` through `set_empower_on_hit()`. `has_next_attack_modifier(id)` = `has_status(&"empower_<id>")`; `is_empowered()` = any basic attack empower. On a unit without a StatusComponent it does nothing (the old dictionary path was deleted 2026-09-29).
- `AutoAttackComponent.set_empower_on_hit(status_id, on_hit)`: the per-target callback for a basic attack empower status already on the unit; called for each enemy whose hit got through when a swing uses the empower up, forgotten when the status ends. For feel and VFX that belong to an ability's script (Iron Resolve's); gameplay goes in the empower's data.

### Unstoppable and untargetable
- `StatusComponent.apply_status()`: a `cc`-tagged status on a unit tagged `unstoppable` returns false (slows are `cc`, so `add_speed_modifier()` slows are refused too; hastes aren't). Applying a status tagged `unstoppable` first removes every `cc` status on the unit (`remove_statuses_with_tags([&"cc"])`). `Unit.is_unstoppable()`.
- `Unit.on_hit()`: an `unstoppable` target skips the hit's knockback (step 5, COMBAT.md, `Unit.on_hit(ctx)`); the hit still lands. `KnockbackGameplayEffect` is skipped too (it's knockback from another unit's rule). The unit's own `dash()` and swing steps are unaffected.
- Untargetable (`Unit.is_untargetable()`): `Unit.on_hit()` blocks every hit except damage-over-time ticks (tagged `dot`), so a DoT applied before keeps ticking; Hurtbox hits are blocked too. It isn't an invulnerability id, since those block DoT ticks. `StatusComponent.apply_status()` refuses statuses from other units while the unit is untargetable (a status from the unit itself or from the environment, source null, still applies).
- `Unit.is_targetable()` = alive and not `untargetable`. Checked by: UNIT targeting in `try_cast()` ("no target") and the pending walk-into-range (dropped), the Player's enemy under the cursor and `target_forgiveness` pick, `AbilityUtil.enemies_of()` (every shape query and swing) and `enemies_of_team()` (projectiles fly through), and AutoAttackComponent's attack targets (dropped; a windup is cancelled).
- Enemy AI (`Enemy`): `_can_see_player()` is false for an untargetable player (no new aggro). In AGGRO with an untargetable player, `_chase_untargetable()`: keep aggro, cancel the attack (and its windup), keep chasing (`move_to` the player every 0.1 s), cast nothing new (a cast already going finishes); the frame the player is targetable again it attacks as usual. The leash still applies.

### Projectile (`res://scripts/abilities/projectile.gd`, `class_name Projectile`, Node2D)
- `static func fire(caster, ability, cast, origin, direction) -> Array[Projectile]`: `projectile_count` projectiles `projectile_spread_deg` apart, centered on `direction`; all share one `HitContext.CritRoll`. Params are read once at fire with `get_effect_param()` (the cast's charge and other named inputs, and its conditional bonuses for the cast's target): speed, `cast_range` (the distance), width, pierce, count, spread. Added next to the caster (its parent, the room's y-sorted `Entities`), so it outlives the caster; it travels on the feet line and is drawn 10 px above it.
- Each physics frame (game time) it moves speed × delta. Walls: its core (a 2 px circle, `WALL_RADIUS_PX`, so a wide projectile doesn't catch corners it visibly clears) swept against world layer 1 (`WorldQuery.shape_sweep()`) ends it at the wall, unless `ignores_walls`. Units: enemies of its team touching the swept capsule (`along_segment_of_team()`, team-based so it works without the caster), each unit at most once per projectile, nearest first; each hit through `from_ability(caster, ability, unit, cast)`; after `projectile_pierce` + 1 hits it ends. Ends at `cast_range`.
- Caster gone: at fire it snapshots the caster-side damage (base + caster terms + AD/AP + ability empowers). While the caster is valid, hits use the live path above; once it's freed, hits use the snapshot plus the target terms, with no source, `can_crit` false, no conditional bonuses, and the ability's tags.
- Visual: a drawn shape in `icon_color` (VFX only); `debug_draw` shows the swept capsule. Hits carry the ability's tags (`projectile`).

### Conditions
- **The condition target.** UNIT abilities: `ctx.target` (the chosen target). Others: the living enemy nearest the aim point within the ability's `cast_range` of the caster (`AbilityUtil.nearest_enemy_in_range(caster, aim, range_px)`), or none. Hit-time checks (bonuses) use the unit hit. `_make_context()` fills `ctx.target` with it for non-UNIT casts when the ability has any TARGET_ condition, any conditional bonus, or a named-input scaling on `target_distance` (`needs_condition_target()`), so scripts and bonuses see the same unit. A free cast given a target (the unit hit, the triggering cast's target) keeps that one. For the HUD's preview of a UNIT ability (no target chosen yet), the condition target near the aim hint stands in; the Player's press uses the same pick as `cast_ability()` (the enemy under the cursor, else `target_forgiveness`).
- **The aim hint.** `set_aim_hint(point)`: the Player sets it to the cursor every physics frame; the enemy AI to its target's position before it asks `can_cast()`. Conditions checked outside a press (the HUD's grey preview) use it; `get_fail_reason()` without an aim uses it.
- **Where they're evaluated:**
  - `get_fail_reason(slot)`: the last check, after blocked / not ready / busy / cost: `cast_conditions` (part 0) or `recast_conditions` (a later part) with `Condition.all_met(…, unit, target, ctx)` plus `ability.can_cast_custom(unit, ctx)` → `"condition"`. `try_cast()`, `try_start_charge()` and the HUD all go through it, so a failed press spends nothing. `conditions_pass(slot, aim, target)` is that last check alone (the Player's press calls it directly).
  - `get_condition_fail_text(slot)`: the first failed condition's `fail_text`, else the script's `get_custom_fail_text()`, else "".
  - `Player.request_cast()` / `request_charge()`: a press that's ready and not blocked but fails its conditions fails at once with `"condition"` and isn't buffered (like "not enough resource").
  - Recast parts: `recast_conditions` are checked when the next part is pressed; failing them doesn't end the window (it runs out normally, then the cooldown starts).
  - Conditional bonuses: `get_effect_param(caster, param, cast, target)` = `get_param()` × its named-input scaling (`ChargeScaling` with `input`, value `cast.get_input(input)`) × every `ConditionalBonus` whose `conditions` pass right now for `target` (null = the cast's `ctx.target`), their `modifiers` applied with the StatModifier formula on top of the scoped and scaled value (a second layer: (value + flat) × (1 + Σ add) × Π(1 + mult), never below 0). Without a cast, named inputs count full (1), like a cast without a charge; `target_missing_health` always comes from the target. `HitPipeline.from_ability()` uses it per unit hit for `base_damage`, `ad_ratio`, `ap_ratio` and scaling-term ratios when it's given the cast (every toolkit hit), and appends each passing bonus's `target_statuses` to `HitContext.statuses`; without a cast it keeps the old path (charge params, no bonuses). A script reads cast-time params (a radius, a range) with it in `execute()`. At effect start (flow step 10) AbilityComponent applies each passing bonus's `self_statuses` to the caster (a free cast's effect start too).
  - Reaction rules: `Reactions._fire()` checks `rule.conditions` after the tag filters, before `chance`. A HIT rule's conditions see the target after the hit (`Events.unit_hit` fires once the damage is taken), so "below 30%" includes that hit's damage.
  - `get_charge_scaling()` / `get_charged_param()` read only `charge` scalings, so a scaling on another input never changes indicators, tooltips or `get_damage()` (they show the plain values).
- **Named inputs.** AbilityComponent fills the built-ins when the cast starts (at release for CHARGE_UP and VECTOR): `charge`, `vector_drag` (VECTOR only; VECTOR flow), `self_missing_health` ((max − current) ÷ max of the caster), read again at the effect start (flow step 10; CHAMPIONS CH5, Ryan 2026-09-29: a hit taken during the cast time counts; one value for every hit of the effect), `target_distance` (edge distance to the condition target ÷ cast range, 0 with no target). `target_missing_health` is per target, so `get_effect_param()` computes it at the hit (with no target: 0). A script may `set_input()` anything else before it reads params.
- **LAST_PART_HIT.** The recast sequence's `last_part_hit` is reset when a part starts; AbilityComponent listens to `Events.unit_hit` and sets it when a hit's `source` is this unit and its `ability` is the sequence's ability (so a projectile from the previous part that lands later still counts, until the next part starts). `_make_context()` copies it into `CastContext.last_part_hit` (false outside a recast, and false for part 0).
- **Tooltips.** Each conditional bonus adds its `description` as a line (always; whether to show them only while active is an open question). `{…}` placeholders keep showing the plain values (no bonus).
- **Scripts.** New ability scripts read with `get_effect_param()` anything a conditional bonus could change; `get_param()` stays for old code (CONVENTIONS.md).
- **Toolkit reads through `get_effect_param()`** (since 2026-09-29): the projectile params (`Projectile.fire()`), `vector_length` and every `cast_range` read in AbilityComponent (range checks, the condition target, the POINT clamp, which comes after the condition target and inputs so a bonus for the target counts, the VECTOR start clamp), `hit_knockback_px` (per unit hit, in `hit_units()`), Lunge's `flag_stun_duration`, `vector_width` in the test abilities. Still `get_param()`: cooldowns, costs, charges, the recast window and charge-up times (slot bookkeeping), the indicators (`draw_indicator()`, `draw_vector_indicator()`: no cast yet), the enemy AI's range check, `get_ai_vector()`.

### HUD (ability bar and hud)
- The ability bar's tooltip is `get_tooltip_plain()`.
- Planned (COMPANIONS CO3): a fifth slot labeled "Tab", right of R with a gap, only while a companion is chosen: the command's cooldown, the imprint's time left, and a tooltip with the companion's quirks and passives.
- The resource bar (`res://scripts/ui/resource_bar.gd`, added by `hud.gd`'s `setup_abilities()` only when the player has a `resource_pool`): a 132 × 4 px bar just under the ability bar (the health readout is text at the top, so the bar sits with the slots), colored by `resource_type` (mana blue, energy yellow, fury red), the current amount beside it; it blinks for 0.2 s on `"not enough resource"`. CHAMPIONS CH6: `get_thresholds()` (every `RESOURCE_AT_LEAST` in the slotted abilities) drawn as ticks, `is_glowing()` as a bright outline.
- Slot cues: a red flash (0.2 s) on `"not ready"`, `"silenced"` or `"condition"`; a grey tint while the player can't cast (stunned, silenced) or while `get_fail_reason(slot) == "condition"` (so it un-greys the frame the condition passes and the slot is ready; `is_condition_greyed(slot)` for tests); a blue tint while the slot's cost can't be paid. The fail text isn't shown yet (UI.md). A cue shows when a press is dropped: `"not enough resource"` and `"condition"` at once (never buffered), any other reason when its buffer runs out (`PlayerInput` → `AbilityComponent.fail_cast(slot, get_fail_reason(slot))`).
- Tooltip header: "Cooldown Ns", "Cost N" when the cost is above 0, "N charges" when `max_charges` > 1.
- Charges: the charge count (small number, bottom right) on a slot with `max_charges` > 1 (or extra charges left over); the dark sweep and seconds only at 0 charges, otherwise the initials and a 2 px bar along the bottom that fills as the next charge comes back.
- Recasts: while a recast window is open, the slot shows its initials (not the sweep), a gold border and a 3 px gold bar along the bottom that shrinks as the window runs out.
- Charge-up: a 3 px bar just above the slot: white, filling while held; once full, orange, shrinking as the overhold runs out; gone at release. The indicator grows with the charge, stays locked during the release windup, and goes when the effect runs or the charge-up ends any other way.
- VECTOR (AB13): the same bar shows only its orange part (the charge is 1 from the press), shrinking as the hold limit runs out. The indicator: VECTOR flow, step 5.

### Where each AUDIO.md hook fires (abilities)
| Hook | Fires | Played by |
|---|---|---|
| `cast_sound` | cast flow step 7; CHARGE_UP and VECTOR at release; each recast part; free casts when they run | AbilityComponent (`Audio.play_on(…, unit)`) |
| `hit_sound` | via `HitContext.hit_sound` from `from_ability()`, once per cast (CombatSounds' once per source, sound and frame; a projectile's hits that land in different frames each play it) | CombatSounds |
| `telegraph_sound` | after `on_cast_started()` sets a telegraph | Telegraph |
| `ready_sound` | `cooldown_finished`: a slot going from 0 charges to 1 (not on a refund; not when a recast sequence ends with charges left) | AbilityComponent |
| `charge_sound` | a loop from `charge_started` to release, cancel or interrupt (a VECTOR ability may set one for its aim) | AbilityComponent (`play_on`, stopped by handle) |

## How each edge case is handled
| Edge case | Handling |
|---|---|
| A recast pressed during the cast time | The slot is casting, so the press is buffered (the buffer pauses during casts) and fires as the next part the moment the cast finishes and the window opens. |
| A charge refunded on cancel | Cancel and interrupt give back the charge the cast took (and the cost). Back at max, the recharge timer stops; below max, a recharge that was already running keeps its progress. A refund never pings `ready_sound`. |
| An augment removed mid-cast | The cast keeps what it snapshotted at its start (`ctx.ability`, `ctx.flags`); the change applies from the next cast. The removed augment's EVENT rules are gone at once, so they can't fire later in that cast. |
| A REPLACE equipped while the slot is on cooldown | The slot's charges and recharge timer carry over; the variant is ready when the slot would have been. |
| A REPLACE equipped mid-charge-up or mid-cast | The running cast or charge finishes as the old ability (snapshotted). The slot shows the variant afterwards. An open recast window stays with the old ability until it closes. |
| A form swap mid-cast | Same as a REPLACE: the running cast keeps its ability; cooldowns are per slot, so they carry across forms (separate per-form cooldowns: Open questions). |
| A second form applied | The first form is removed (its slots go back), then the new one's REPLACEs go on. A status that isn't a form never removes one. |
| The same form re-applied | Its stack rule as usual; its augments stay on (a REFRESH doesn't remove and re-add them), so the slots and a pending walk-into-range cast are untouched. |
| A form ends (runs out, removed, death) | Its augments go with it; the slots cast their own abilities again, with whatever cooldown was running. |
| Cost paid, then the cast interrupted | Refunded, clamped to max (regen meanwhile). |
| Resource drained during a cast or charge-up | Nothing: the cost was paid at the start. |
| A charge-up released during a swing, dash or stun | Can't happen as such: charging holds the attack lock (no swing starts); a dash either cancels the charge (`dash_cancelable`, refunded) or waits (buffered) until after the release; a stun interrupts the charge at once (refunded). A release after a cancel or interrupt is ignored. |
| Overhold | After full charge the overhold timer runs `overhold_time`; then FIRE releases at the cursor (then its release windup), or CANCEL_REFUND cancels with a full refund. The charge-up bar shows it running out. Either way it goes through the end-charge path. |
| A charge-up ended by anything but a normal release (overhold, dash, stun, move, death, Esc, a lost key release) | The one end-charge path (`_end_charge()`, `charge_ended`) clears the indicator, the charge bar and the sound; the Player redraws on the signal. |
| A stun or dash during the release windup | Like any cast time: interrupted or cancelled (`dash_cancelable`), the cost, the charge and the cooldown refunded, no effect, the indicator gone. |
| Cursor moved during the release windup | Nothing: the aim and the charge locked at release; the indicator stays where it was released. |
| The slot swapped (REPLACE) mid-charge | The charge-up keeps the ability it started with; releasing fires that one, and the slot shows the new one afterwards. |
| Pressing a slot whose condition fails | `get_fail_reason()` returns `"condition"`: the fail cue plays, nothing is spent (no cost, charge or cooldown) and the press isn't buffered. |
| A condition that becomes true mid-cooldown | The slot shows its cooldown as usual; when it's ready, the grey preview re-checks every frame, so it un-greys the frame both hold. |
| A conditional bonus whose condition changes between cast and hit | Checked at the moment of the effect: cast-time params when the script reads them in `execute()`, hit params per unit when that hit is built (a projectile's at its hit). The state at the cast doesn't matter. |
| A condition reading a status that expires mid-cast | Cast conditions are checked once, when the cast (or part) starts; the cast goes on if the status expires in the cast time. A bonus reading it is checked at the effect, so the expired status gives no bonus. |
| A recast condition failing for the whole recast window | Presses fail with `"condition"`; the window runs out normally and the cooldown starts. |
| TARGET_ conditions with no valid target | False, even when negated (no enemy near the aim within range, a dead target, or a UNIT cast without one). A cast needing one fails with `"condition"`. |
| Enemy abilities using conditions | Allowed: the same `get_fail_reason()`; the enemy AI sets the aim hint to its target first (ENEMIES_AI.md chooses when to try: an ability's `ai_uses` and their use rules, then its `get_ai_plan()`). |
| A reaction rule's condition with no target (a world rule whose effect target is gone) | The rule doesn't fire (Reactions already skips a missing target; TARGET_ conditions are false). |
| Cast mode switched mid-aim | The aim in progress finishes as it started (release casts); the new mode applies to the next press. |
| A projectile whose caster dies | It keeps flying. Kill credit is the caster's while it exists; once it's freed, snapshot damage and no source (Rules, Projectiles). |
| Two sources of the same augment | Counted once; it stays until the last source is removed. Its EVENT rules are added once. |
| An unsupported FLAG | `push_error` once when it's added; ignored for that ability (the tooltip doesn't list it). |
| An empower granted by a passive or item | The same status, applied by whatever the source is (a passive's rule, an item's `ApplyStatusGameplayEffect`); consumption doesn't care who applied it. Its bonus AD ratio reads the attacker's AD, not the applier's. |
| Unstoppable applied while stunned | Applying it removes every `cc` status at once (the stun ends, its locks go); new cc is refused while it lasts. |
| A CastAbility effect chaining into itself | Each free cast emits `ability_cast` one chain link deeper, and its hits carry that depth (`HitContext.chain_depth`); rules stop at their `chain_limit`, and nothing passes `MAX_CHAIN` 5. |
| A cooldown reset on a slot that's mid-cast | INSTANT and CHANNEL took their charge at cast start, so a reset gives it back now; the slot is castable once the cast finishes. Mid-charge-up or mid-recast-window no cooldown is running yet, so the reset does nothing (`reset_cooldown()` only acts on a running recharge; the AB8 test checks the recast window case). |
| A cast cancelled or interrupted before its effect | No ABILITY_CAST fires, so nothing it would have triggered (a restore, a free cast) happens; the cost and charge are refunded as usual. |
| A free cast during another cast's cast time | It runs at once alongside it: the other cast isn't interrupted, nothing is spent, no slot or lock is touched. |
| A free cast when the caster is stunned or dead at its run time | Refused (the rule's effect does nothing). |
| A stun during the cast time of an enemy's telegraphed ability | Interrupted at once: the telegraph and its wind-up go the same frame, cooldown refunded. |
| A cast refused for "not enough resource" | The resource bar flashes; the press isn't buffered, so it won't fire when mana regenerates. |
| An untargetable enemy under the cursor for a UNIT cast | Not a target: "no target", or the next targetable one within `target_forgiveness`. A target that turns untargetable mid-cast: the hit is blocked, so the cast misses. |
| A DoT on a unit that turns untargetable | It keeps ticking (ticks are tagged `dot` and pass the untargetable check); new hits and new statuses from other units are blocked. |
| The player turns untargetable while enemies attack | New enemies don't aggro; aggroed ones cancel their windup, drop the attack target and keep chasing; they attack again the frame it ends. |
| A free cast while an ability empower is up | The free cast doesn't use it; the next cast the player or AI starts that matches does. |
| A rule that grants an ability empower on cast | The cast that triggered it doesn't use it (empowers are used up before `ability_cast`); the next matching cast does. |
| `max_charges` lowered while charges are stored | Extra charges stay until spent; the recharge runs only below the new max. |
| A VECTOR press during a swing or a dash (AB13) | The CHARGE_UP buffer rule: buffered; when it fires, the start point goes where the cursor is then, and if the key was already let go it releases at once as a tap. |
| Focus lost or the cursor leaving the window mid-aim | As for CHARGE_UP, "key not held" is a release: the vector fires from its start toward the last cursor position the window saw (Godot stops updating the mouse position outside the window). |
| Released with the cursor exactly on the start point | Shorter than `vector_min_drag_px`: a tap (direction caster → start, `vector_drag` 0). If the start is also on the caster (a start point clamped to 0 by a wall at the caster's feet), the direction is the caster's `facing`. |
| The cursor inside a wall or out of line of sight at the press | The start point is clamped to the last valid spot on the line from the caster (the wall's face); an `ignores_walls` ability keeps the clamped cursor. |
| A VECTOR recast part | Every part is pressed, dragged and released like part 0 (its own start point and line), costing `recast_resource_cost`. The recast window doesn't run while a part is aimed or cast. |
| A REPLACE that makes the slot VECTOR mid-aim | A hold already going (charge-up or vector) keeps its own ability. A hold-to-aim INSTANT aim (QUICK_WITH_INDICATOR) whose slot became VECTOR casts the VECTOR ability on release as a tap (`try_cast()`). The next press aims a vector. |
| A free cast (CastAbility) of a VECTOR ability | Casts at once: start = the triggering cast's aim point (a hit: the unit hit), clamped as at a press; direction = caster → that point; `vector_drag` 0. No hold, no indicator. |
| A stun, dash, Esc or death during a vector aim or its release windup | Exactly as for a charge-up: interrupted or cancelled, refunded, and the one end path clears the start marker and the line. |
| Hitstop or the pause menu during a cast time (AB14) | Cast progress advances in game time: hitstop slows it, the pause stops it, as the old timer did. The telegraph and `cast_anim` follow the same progress, so they stay in step. |
| Cast speed changes mid-cast (AB14, once something changes it) | Read every tick: the rest of the cast runs at the new speed; progress already made is kept. The telegraph and `cast_anim` follow the progress, so nothing desyncs. |
| A cast cancelled or interrupted with a `cast_anim` playing (AB14) | The animation stops with the cast (the same frame the telegraph goes). |
| A hook scene missing or empty (AB14) | Nothing happens (null / empty name / no such clip on the model). A hook never blocks or delays the cast. |

## Build order (one step per request)
Every step: with no cast style changes, scalings, costs, charges, recasts, augments, conditions or VECTOR abilities set, the game plays exactly as before, and the Knight's abilities, enemies chasing and the HUD still work. Build logs go in `docs/CHANGELOG.md` (an Abilities section); this doc keeps one line per built step.

1. **AB1 – Cast style, the stun interrupt, cast mode.** Built 2026-09-26, see CHANGELOG.md.
2. **AB2 – Damage scalings, tooltips, tags.** Built 2026-09-27, see CHANGELOG.md.
3. **AB3 – Costs, the resource bar, fail cues.** Built 2026-09-27, see CHANGELOG.md.
4. **AB4 – Charges.** Built 2026-09-27, see CHANGELOG.md.
5. **AB5 – Recasts.** Built 2026-09-27, see CHANGELOG.md.
6. **AB6 – Charge-up.** Built 2026-09-27, see CHANGELOG.md.
7. **AB7 – Projectiles.** Built 2026-09-27, see CHANGELOG.md.
8. **AB8 – Augments and the new GameplayEffects.** Built 2026-09-27, see CHANGELOG.md.
9. **AB9 – Forms.** Built 2026-09-27, see CHANGELOG.md.
10. **AB10 – Empowers, unstoppable, untargetable.** Built 2026-09-27, see CHANGELOG.md.
11. **AB11 – The Knight's 4 abilities rebuilt from toolkit pieces only.** Built 2026-09-27, see CHANGELOG.md.
12. **AB12 – Conditions.** Built 2026-09-27, passed Ryan's play test 2026-09-28, see CHANGELOG.md.

13. **AB13 – VECTOR cast style.** `Ability.CastStyle.VECTOR`, `vector_length` / `vector_width` / `vector_min_drag_px`, the start point (range and wall clamp), the tap fallback, `CastContext.vector_start` / `vector_direction` / `vector_end`, the `vector_drag` input, VECTOR through the CHARGE_UP hold/release path (`get_vector_start()`, aimed recast parts, the hold limit), `draw_vector_indicator()`, `try_cast_vector()`, `get_ai_vector()` and the Enemy hook, `Telegraph.line()`; `test_vector_line`, `test_vector_wall`, `SandboxAbilities.test_elite_w` (Data, Test and sandbox data). Built 2026-09-28, see CHANGELOG.md.
    **Done means** (awaiting play test): the test ability works with a drag and with a tap; every cancel and interrupt clears the indicator; an enemy test ability uses a vector with a telegraph; with no VECTOR ability equipped, the game plays exactly as before.

14. **AB14 – Cast progress and presentation hooks** (Ryan, 2026-09-29; before CHAMPIONS CH1). Built 2026-09-29, see CHANGELOG.md.
    **Done means** (passed Ryan's play test, 2026-09-29): every cast lands its effect on the same physics frame as with the old timer (measured flag on vs off before the deletion; now checked against the timer's arithmetic from each `cast_time`, including casts started mid-frame, between frames and at another cast's end); telegraphs are exactly full at the hit; with every hook empty nothing changes on screen; filled test hooks each fire once at their moment and animations follow progress; the game plays exactly as before. The old timer path was then deleted (see CHANGELOG.md).

    **AB14b – Remove the old timer's extra tick** (Ryan, 2026-09-29; its own small step after CHAMPIONS CH1). A cast time that is an exact number of ticks lands on that tick (0.2 s = 12 ticks, not 13): the countdown treats a remainder within a small epsilon of 0 as done, as the swings do. Every other cast is unchanged. Built 2026-09-29, see CHANGELOG.md.
    **Done means** (passed Ryan's play test, 2026-09-29): the abilities test's timing checks expect the nominal tick count (`_ab14_timer_ticks()` without the float residue) and pass; casts with 0.65 or 0.7 s land on the same frame as before; Ryan's play test: the affected casts (every cast time that is an exact number of ticks, such as Cleave's 0.2 s and Lunge's 0.05 s) feel the same or snappier.

15. **AB15 – Blinks** (Ryan, 2026-10-04; before LOOT L7). `MovementComponent.blink()`, `get_blink_landing()` and the `blinked` signal (Blinks); the tag `blink`; the view's snap and look (3D.md, 1e); Homeward Greaves' return as a blink (`lunge.gd`, `knight_e_lunge_return.tres`; LOOT.md); `test_blink` and `test_blink_sight` on B / Shift+B in both sandboxes (Test and sandbox data).
    **Done means:**
    - **Landing:** on free floor, exactly where aimed, the same tick. Over a wall, a fence, a ledge (onto the plateau and off it) and a pit. Aimed into a wall, a pit or past the room's floor: the nearest walkable floor (the leap's rule).
    - **Stopping at walls (`through_walls` off):** stops short of a wall in the way, still crosses a fence, a ledge and a pit, and never ends out of sight of its start.
    - **Other movement:** it ends the unit's running dash or knockback. It's refused during a leap, a knock-up and a root. It gives no status and no i-frames.
    - **The view:** no slide (even under WorldView's 64 px snap); onto a plateau at once; an afterimage at the start and a flash at the arrival; the camera glides.
    - **Homeward Greaves:** the return blinks back to the exact start at once (also after walking behind a wall) and hits nothing. Tackle, Twin Lunge, Long Lunge and Quick Footing work as in L6. A rooted recast fails with its cue and the window keeps running.
    - **Tests and play test:** every existing test passes (L6's return checks updated to the blink). Ryan's play test: the return reads as a blink, and the test blink feels right.

**Milestone AB-M – augment playground** (after AB13): in the sandbox, `SandboxAugments` with 4 fake items that visibly change the Knight: Lunge stuns (FLAG), Cleave becomes a projectile wave (REPLACE), a Judgement kill resets its cooldown (EVENT + ModifyCooldown), casting Cleave also casts a free Lunge-style dash (CastAbility, at Cleave's effect start). Built 2026-09-28, see CHANGELOG.md.
    **Done means** (passed Ryan's play test, 2026-09-28): keys 1–4 equip and unequip them; the tooltips show each change; unequipping restores the Knight exactly.

## Later toolkit pieces (build when a champion needs one)
Not build steps. Each is data once 2+ kits use it (Data or script, above).
- Ground areas with a "unit entered" event that says whether the unit was displaced into it (Hazards, WORLD_INTERACTION.md).
- A held status: cc that pins a unit to an anchor (blocked by unstoppable), plus a holding status with stacks on the caster.
- Displace with a max distance, an optional speed Curve (.tres) and a "landed" signal (early on walls).
- Example use: capture-and-throw abilities (Tahm Kench, Singed E style).

## Out of scope
Passives themselves and champion kits (CHAMPIONS.md: a Passive bundles stat modifiers, unit reaction rules, statuses, empowers and an optional script, all under a source id like `passive_knight`, built on this toolkit); items and affix rolls (LOOT.md); enemy AI choosing abilities (ENEMIES_AI.md, written 2026-10-03: the brain, intents, use rules; this doc keeps only the fields it adds to Ability and Condition); ability ranks (none, replaced by talents: Ability ranks); talents (TALENTS.md, built on augments); summons; ability slot swapping by the player (decided no, 2026-09-29: slots are fixed, VISION.md, Build variety; REPLACE augments and forms still change what's active in a slot); TOGGLE and SUSTAINED cast styles (not planned: Cast styles); the ultimate meter (CHAMPIONS.md).

## Open questions
- **Blinks** (2026-10-04; Ryan's three calls are in Blinks): Claude's proposals there are for Ryan to review before AB15:
  - the API and the `blinked` signal;
  - it ends the unit's own displacement, and is refused during a leap, a knock-up or a root (checked in `can_cast_custom()`);
  - no status, i-frames or hits;
  - the tag `blink`, with no event of its own;
  - enemies may blink;
  - the view's snap, afterimage and flash, with the camera gliding (3D.md, 1e);
  - the test blink on B / Shift+B.
- Should a root also block the dashes (Lunge, Triple Step) as it will block blinks? *(proposed: not now; with ENEMIES_AI's roots, when a root first comes from an enemy)*
- Ultimate meter details (CHAMPIONS.md, when a champion first uses one).
- The element tag list.
- Can a recast part be dash-cancelled separately?
- AB14: should the charge-up hold (`charge_time`) also run at cast speed? *(proposed: yes, when a champion first has a charge-up)*
- ~~AB14: keep or remove the old timer's extra tick~~: answered (Ryan, 2026-09-29): remove it, as its own small step (AB14b, Build order) after CHAMPIONS CH1, so each play test checks one change.
- Resource-type rhythms: answered, CHAMPIONS.md owns them (fury: Fury section there). Which Knight abilities ignore walls: answered in CHAMPIONS.md *(proposed: none)*.
- Charge-up and the input buffer: a press buffered during a swing or dash whose key is already released when it fires: a tap (charge 0), or dropped? *(proposed: a tap; built that way)*
- Forms: shared per-slot cooldowns (built in AB9) or separate cooldowns per form (Jayce)?
- The "on end" augment event (`ability_finished`): when something needs it.
- Conditions: will we ever need OR, or do scripts cover it?
- Do conditional bonuses show in tooltips always, or only while active? *(AB12 starts with always)*
