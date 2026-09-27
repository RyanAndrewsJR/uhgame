# ABILITIES.md: The Ability Framework, Cast Styles, Costs, Recasts, Projectiles and Augments

**Read when:** the task involves abilities, casting, cast styles, charge-up, damage scalings, tooltips, ability tags, costs, cooldowns, charges, recasts, projectiles, augments, forms or empowers.
**Depends on:** CLAUDE.md, CONVENTIONS.md (names, tags, reserved names), STATS.md (scoped params, `get_param()`, ResourceComponent, ability haste), COMBAT.md (HitPipeline, HitContext, statuses, ReactionRule and GameplayEffect, telegraphs), MOVEMENT.md (the input buffer, the dash, facing), WORLD_INTERACTION.md (WorldQuery, movement methods, Hazards), AUDIO.md (ability hooks).
**Used by:** CHAMPIONS (kits; passives are built on this toolkit), LOOT (items: scoped modifiers and augments), ENEMIES_AI (enemies cast through the same AbilityComponent), UI (tooltips, the ability bar), DUNGEONS (run modifiers that grant rules or augments).

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
- A cast happens when: the ability is ready (cooldown done or a charge available), the caster can pay its cost, and no status blocks casting.
- At cast start: pay the cost, show the telegraph, play `cast_sound`, fire the "on cast" trigger (augments, rules). The cooldown (or a charge) starts at cast start for INSTANT and CHANNEL, and at release for CHARGE_UP.
- A cast cancelled (dash, move, Esc or overhold CANCEL_REFUND during a charge-up) or interrupted (stun, death) before its effect refunds its cost and cooldown/charge. Once `execute()` starts, nothing is refunded.
- A stun (or any status that blocks casting) applied during the cast time or a charge-up interrupts the cast at once (Ryan's pick). This resolves COMBAT.md's open question. AbilityComponent listens to its unit's `StatusComponent.status_applied`; a unit without a StatusComponent (none today) still gets the old check at the end of the cast time.
- The cast movement rules (`roots_during_cast`, `cast_move_speed_multiplier`, `cancel_on_move`, `dash_cancelable`, `cancels_swing`) move here from MOVEMENT.md unchanged (Movement during casts, below); MOVEMENT.md keeps a one-line pointer. They also govern walking while charging up.
- **Free casts** (`CastAbilityGameplayEffect`): a free cast triggered at a cast's start (the ABILITY_CAST trigger) waits until that cast's effect starts (the end of its cast time), then runs at once, with no cast time of its own, no slot, no locks, no cost and no cooldown. Anything that blocks casting (stun) and death block it; if the triggering cast is cancelled or interrupted first, it's dropped. A free cast from any other trigger (HIT, UNIT_DIED...) runs at once. Free casts are chain-limited like C11 rules (`chain_limit`, `ReactionRule.MAX_CHAIN` 5).

### Movement during casts (moved from MOVEMENT.md, unchanged)
Per ability; the defaults keep every Knight ability as it was.
- `roots_during_cast` (default on): the cast locks walking (`&"casting"`) until it finishes.
- `cast_move_speed_multiplier` (default 1.0): with `roots_during_cast` off, walking speed during the cast is multiplied by this. It's a `PERCENT_MULT` `move_speed` StatModifier, source `&"ability_casting"`, removed when the cast finishes, is interrupted or is cancelled. Soft caps still apply after it: for the Knight, 0.75 gives exactly 420 u (134 px/s), 0.5 gives 318 u (102 px/s, not 90), and 0 still walks at 57 px/s.
- `cancel_on_move` (default off): a movement key pressed **after** the cast starts cancels it during its cast time, exactly like the dash cancel (locks released, cooldown refunded, `cast_cancelled` then `cast_finished`; `execute()` can't be cancelled). Keys already held when the cast started don't count; letting go and pressing again does. PlayerInput notes a `move_*` press in `_unhandled_input` only if a cast is already running (input events arrive in order, so Q then D in the same frame counts), and calls `AbilityComponent.try_cancel_cast_on_move()` in `_physics_process`, before MovementComponent, so the new key moves that same frame.
- **`cancel_on_move` wins:** the cast always roots for its cast time (the player stops, and any `move_to` order is dropped), even if `roots_during_cast` is off, and the multiplier is ignored. It's a channel: stand still, move to cancel. With `cast_time` = 0 there's nothing to cancel.
- `dash_cancelable` (default off for all Knight abilities): a dash during the cast time cancels the cast (locks released at once, cooldown refunded, `cast_cancelled` then `cast_finished`). Off: the dash press is buffered until the cast is done.
- `cancels_swing` (`NEVER` / `AFTER_HIT` default / `ANYTIME`): whether the press can cut a basic attack swing (COMBAT.md). Otherwise it waits for the swing to end (input buffer).
- Facing stays locked to the cast's aim while walking during a cast (MOVEMENT.md, Facing and aim). SELF casts have no aim, so facing follows walking.

### Cast styles (per ability, `cast_style`)
- INSTANT (default): press to cast after the cast time.
- CHARGE_UP: hold the key to charge, release to fire at the cursor's position at release. The cast context carries `charge` (0 at a tap, 1 at full). Each ability lists which params grow with the charge (e.g. `cast_range` from 40% to 100%, `base_damage` from 50% to 100%) with an optional curve; the full value is the normal param after modifiers, so items raise both ends. The indicator is always shown while charging and grows with it. After full charge, the player may keep holding for `overhold_time`; then the ability does its overhold behavior: FIRE (default) or CANCEL_REFUND, per ability.
- CHANNEL: the caster stands still through the cast time; moving cancels it (refunded); the effect comes at the end. This is today's `cancel_on_move`, formalized (Judgement). A lasting channelled effect (a drain, a held beam) comes later with SUSTAINED.
- Later (not built now): TOGGLE, SUSTAINED (held stream), VECTOR (click-drag).

### Cast mode (player setting)
- Cast mode is a player setting in Settings and the pause menu, like dash direction: QUICK (cast at the cursor on press; default, Ryan's pick) or QUICK_WITH_INDICATOR (hold to aim, release to cast). Esc cancels an aim, as today.
- Cast mode only applies to INSTANT abilities. CHARGE_UP always uses hold-and-release and CHANNEL always casts on press, whatever the setting.

### Damage scalings (League ratios)
- An ability's damage is `base_damage` plus a list of scaling terms, each "ratio × a stat", read from the caster (attack_damage, bonus attack damage = final − base, ability_power, max_health, bonus health, armor, magic_resist...) or from the target (max health, missing health, current health). `ap_ratio` is supported.
- The existing `base_damage` / `ad_ratio` keep working (`ad_ratio` becomes one term, wrapped, not rewritten). Judgement's missing-health bonus moves into data.
- Scalings are scoped params, so items can raise a ratio.

### Tooltips from data
- Each ability's description is a template with placeholders (`{damage}`, `{cooldown}`, `{cost}`, `{range}`, `{charges}`, each scaling term, charge-up min–max) filled from `get_param()` with haste, modifiers and augments applied, damage colored by type (League style). It's a function other code can call; where the HUD shows it is UI.md.

### Standard tags (listed in CONVENTIONS.md)
- Exactly one role tag per ability, following Diablo 4's categories: `generator`, `core`, `defensive`, `mobility`, `ultimate` (Diablo's "basic" is `generator` here, so it can't be confused with the basic attack).
- Plus shape tags (`area`, `projectile`, `line`, `cone`, `dash`), style tags (`charge_up`, `channel`) and element tags (`fire`, `cold`, `lightning`, `poison`, `shadow`, `holy`; the list is an open question).
- Scoped modifiers use them ("+20% damage to core abilities").

### Costs and resources
- Every champion has a resource type: MANA, ENERGY, FURY or NONE (Ryan's pick: NONE is allowed, cooldowns only). The Knight's real type is decided in CHAMPIONS.md. NONE = the unit has no ResourceComponent; such a unit pays no costs.
- An ability's `resource_cost` is a scoped param (items can reduce it). A CHARGE_UP ability pays when charging starts.
- Not enough resource: the cast fails with a clear cue; the press is not buffered.
- Generators and spenders: `resource_on_hit` (exists) lets basic attacks build a resource that abilities spend.
- The HUD resource bar is added now (something spends it).

### Charges and recasts
- `max_charges` (default 1). Each charge recharges over the cooldown, one at a time. Items can add charges (scoped param). "Charges" (stored casts) are not the same as "charge-up" (hold to power a cast).
- `recast_count` (default 0) and `recast_window`: pressing the slot again inside the window casts the next part; the cast context says which part. The cooldown starts when the last part is used or the window ends (League style, Ryan's pick). The first part costs `resource_cost`; every later part costs `recast_resource_cost` (default 0, one scoped param for all later parts; Ryan's pick).

### Ultimates
- Per champion: the ultimate uses a cooldown (League) or a meter charged by dealing and taking damage (Hades), Ryan's pick. The Knight uses a cooldown. The meter is designed in CHAMPIONS.md; this doc only needs the slot to support "ready when the meter is full" instead of a cooldown (`ready_mode` METER, reserved here, built with the meter).

### Projectiles
- A shared projectile piece: speed, range, width, pierce count (0 = stops on the first hit), blocked by walls (unless `ignores_walls`), one crit roll per cast shared by every projectile of that cast, its hits through `HitPipeline.from_ability()`. Projectile count and speed are scoped params, so "+1 projectile" is an item modifier.
- A projectile keeps flying if its caster dies. While the caster exists, kill credit is the caster's. Once the caster is freed, the projectile uses the damage it snapshotted when fired and its hits have no source (no kill credit, no crit, no on-hit), like a DoT whose applier is gone (DECISIONS, Combat, C9).

### Augments
- An `AbilityAugment` targets an ability id or tag (like scoped modifiers) and is added and removed by source id (items, passives, buffs).
- Kinds: FLAG (the ability script checks it: "Lunge now stuns"; an ability lists the flags it supports, and an unsupported flag is an error), EVENT (extra effects on cast / hit / kill; built on C11 reaction rules plus a new ABILITY_CAST trigger from `Events.ability_cast`, which is already a reserved name; "on end" comes when something needs it, with a new `ability_finished` event), REPLACE (the slot uses a variant Ability while equipped; the cooldown carries over; it may change the cast style).
- The same augment from two sources doesn't stack; only one REPLACE per ability (a second is disabled and its tooltip says why). Ryan's picks.
- Augments are read at cast start: removing one mid-cast doesn't change that cast.
- Tooltips and indicators show the augmented ability.
- Forms/stances *(proposed)*: one source can REPLACE several slots at once (League's Nidalee and Jayce, Diablo 4 Druid shapeshifts); the REPLACE mechanism supports multi-slot sets and a status that grants and removes them.

### New GameplayEffects (for augments, passives and items; each takes a source id)
- `ModifyCooldownGameplayEffect`: reduce by seconds or percent, or reset (League kill resets, Diablo "cooldown reduced when…").
- `RestoreResourceGameplayEffect`.
- `CastAbilityGameplayEffect`: a free cast of an ability or a variant from a source: no cost, no cooldown, chain-limited like C11 rules (Diablo's "also casts"); timing per the free cast rule (Casting).
- `RemoveStatusesByTagGameplayEffect` (cleanse).

### Unstoppable and untargetable (status rules; COMBAT.md's status section gets them too)
- Status tag `unstoppable`: immune to new cc and removes cc when applied (Diablo 4's core defensive, League's Olaf R). It also blocks knockback from hits (Diablo 4; Ryan's pick). It doesn't affect the unit's own dashes and swing steps.
- Status tag `untargetable`: can't be hit or targeted, through the existing invulnerability mechanism (League's Fizz E), plus `Unit.is_targetable()`, which targeting (UNIT abilities, the target forgiveness pick, enemy aggro and League-style attack targets) checks.

### Empowers ("your next attack / next ability")
- An empower is a StatusEffect tagged `empower` with `empower_*` fields: what consumes it (the next basic attack swing that hits, or the next ability cast) and, for abilities, which ones (a scope); a bonus base damage and AD ratio; statuses to apply to what it hits. HitPipeline adds the bonus into the hit itself, so it crits with the hit and applies to every enemy that swing or cast hits. It's consumed once per swing or cast. Extra behavior rides the status's `reaction_rules`. Iron Resolve's next-attack modifier becomes the first example, kept as a thin wrapper (change policy); Iron Resolve plays exactly as today. This resolves COMBAT.md's "your next <ability>" open question.

### Ability ranks
- Deferred until the run-structure decision. When they come, they're StatModifiers with source `rank` on the ability's params, so nothing needs restructuring.

## The toolkit (every ability is built from these)
Targeting and indicators; cast styles; shapes (cone, line, circle, line of sight); the hit (`HitPipeline.from_ability` with scalings, knockback, statuses, feel, crit roll per cast); statuses (incl. unstoppable, untargetable, empowers); movement methods (dash, displace; blink and pull_to when first needed); projectiles; ground areas (player-made Hazards, WORLD_INTERACTION.md); telegraphs; reaction rules and GameplayEffects granted by abilities; tooltips; sounds and VFX hooks.
- The toolkit must also work for passives (CHAMPIONS.md) and items (LOOT.md): empowers, the ABILITY_CAST trigger, projectiles, augments and the new GameplayEffects take a source id and never assume they come from an ability slot.

| Piece | Where it lives | What it's for | Passives and items use it as-is: how the source is carried |
|---|---|---|---|
| Targeting and indicators | `Ability.targeting`, `Ability.draw_indicator()` (override per shape), `Ability.get_charged_param()` | where a cast goes; the aim shape the player sees | through an Ability resource (a hidden variant cast by `CastAbilityGameplayEffect`); an item never needs an indicator of its own |
| Cast styles, costs, charges, recasts | `AbilityComponent` + fields on `Ability` | when and how often a slot fires | slots only; items change them through scoped modifiers (`StatsComponent.add_modifier()`, `source_id`) and REPLACE augments (`add_augment(augment, source_id)`) |
| Shapes and sight | `AbilityUtil` (`in_cone`, `along_segment`, `in_circle`, `in_sight`, `nearest_enemy_to`), `WorldQuery.has_line_of_sight()` | who's inside an area | static functions: any caller with a caster Unit |
| The hit | `HitPipeline.from_ability(caster, ability, target)` (+ `cast` from AB6), `make_proc()`, `DealDamageGameplayEffect` | damage, crits, mitigation, on-hit, knockback, statuses | the hit's `source` is a Unit (kill credit); an item's damage is a rule's `DealDamageGameplayEffect` (source = the rule's owner) or a free cast |
| Damage scalings | `DamageScaling` Resources on `Ability.scalings`; `ad_ratio`, `ap_ratio` | League ratios | scoped modifiers raise a term's ratio (`scope` `ability:<id>` / `tag:<tag>`, `source_id` the item's) |
| Statuses | `StatusComponent.apply_status(effect, source)`, `StatusEffect` | buffs, debuffs, cc, shields, DoT | the applier is a Unit; the status's own modifiers, rules and augments go under `&"status_<id>"` |
| Empowers | `StatusEffect.empower_*` fields, read by `HitPipeline` | "your next attack / next ability" | any source that applies the status: an ability, a passive's rule, an item's rule (`ApplyStatusGameplayEffect`) |
| Unstoppable, untargetable, cleanse | status tags `unstoppable` / `untargetable`; `RemoveStatusesByTagGameplayEffect` | defensive moments | statuses applied by anything; the cleanse is a GameplayEffect in a rule |
| Movement methods | `MovementComponent.dash()`, `displace()` (later `blink()`, `pull_to()`) | abilities never set position themselves (WORLD_INTERACTION.md) | any caller; displacements carry no source id (kill credit for impacts is WORLD_INTERACTION's) |
| Projectiles | `Projectile` (`res://scripts/abilities/projectile.gd`), `Projectile.fire()` | skillshots, waves, bolts | fired with an Ability resource and a `CastContext` whose `source_id` names the item or passive (free casts set it) |
| Ground areas | `Hazard` *(proposed, WORLD_INTERACTION.md)* | fire trails, oil pools | a Hazard's `source` Unit; planned there |
| Telegraphs | `Telegraph.circle()`, `Ability.on_cast_started()`, `CastContext.telegraph` | the floor warning during a cast time | through an ability's cast |
| Reaction rules and GameplayEffects | `Unit.add_reaction_rule(rule, source_id)`, `Reactions.add_world_rule(rule, source_id)`; trigger ABILITY_CAST; the four new effects | "when X, do Y" | `source_id` on add, removed with `remove_reaction_rules_from(source_id)` |
| Augments | `AbilityAugment`, `AbilityComponent.add_augment(augment, source_id)` / `remove_augments_from(source_id)`; `StatusEffect.augments` | behavior changes and forms | `source_id` on add; a status's augments use `&"status_<id>"` |
| Tooltips | `Ability.get_tooltip(caster)`, `get_tooltip_plain(caster)` | what the player reads | shows augment lines with their source's text |
| Sounds and VFX | `Ability.cast_sound` / `hit_sound` / `telegraph_sound` / `ready_sound` / `charge_sound` (AUDIO.md); `VFX` static helpers | feedback only; never gameplay state | fields on the Ability or status the source grants |

## Ability spec sheet
Every new ability is written from this sheet first (it replaces WORLD_INTERACTION.md's template, which now points here). Fields match `Ability`; leave a line out when it's the default.
```
Name / Champion / Slot / id:
Role tag / other tags:
Cast style: INSTANT / CHARGE_UP (charge_time, overhold_time, overhold, charge-scaled params) / CHANNEL
Targeting: SELF / DIRECTION / POINT / UNIT
Cost: resource_cost (recast_resource_cost)       Cooldown: __ s      Charges: max_charges
Recasts: recast_count, recast_window, what each part does
Cast time: __ s      Range: cast_range __ u (__ px)
Movement during the cast: roots_during_cast, cast_move_speed_multiplier, cancel_on_move, dash_cancelable, cancels_swing, resets_auto_attack
Damage: base_damage, ad_ratio, ap_ratio, scalings, damage_type, proc_coefficient, ignores_walls
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

### Example: Knight Q, Cleave (as the code and data are today, plus the AB2 tags and template)
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
  3. One CritRoll for the cast; each target: HitPipeline.from_ability() then resolve().
  4. Each hit that wasn't blocked: a 17 px push away from the Knight (knockback 170 px/s × 0.1 s, knockback_curve).
  5. Anything hit: shake 3 px, hitstop 0.05 s (its own feel; COMBAT.md).
Supported augment flags: none yet. (AB-M's wave is a REPLACE: knight_cleave_wave, variant_of knight_cleave.)
Sounds: cast_sound sound_knight_cleave_cast; hit_sound none (HitFeel's light tier plays)
Walls: blocked (COMBAT C7): an enemy behind the pillar isn't hit.
Stunned mid-cast: interrupted at once, no hit, cooldown refunded (AB1).
Caster dies mid-cast: interrupt_cast(), no hit. Mid-effect: the effect is one frame; it resolves.
Tooltip template: "Sweep your sword in a wide arc in front of you, dealing {damage} physical damage ({base_damage} {ratios}) and knocking enemies back."
  (Today's description says 70 base; the data is 80. The template fixes the mismatch.)
Extra tunables: cone_half_angle_deg 60, knockback 170 (px/s for 0.1 s)
```

## Numbers (TARGET: start, range)
- Player cast times: movement and quick strikes 0.0–0.1 s; strikes 0.15–0.3 s; ultimates up to 0.5 s.
- Cooldowns: non-ultimate abilities 3–10 s; ultimates 30–60 s (shorter than League, for run pacing).
- Charge-up: time to full 1.5 s (0.5–3); overhold 2 s after full (1–4); a tap gives charge 0 (the listed minimums); walking while charging per ability (e.g. `cast_move_speed_multiplier` 0.6).
- `recast_window` 3 s (1–6).
- Charges: recharge time = the ability's cooldown.
- Costs (placeholder until CHAMPIONS.md): mana abilities 30–80 of a 300 pool (6/s regen); fury abilities spend what basic attacks build.
- Fail cue: the resource bar flashes 0.2 s.
- For CHAMPIONS.md: two Knight numbers sit outside these ranges today and are left as they are until then: Judgement's 1.5 s channel (ultimates ≤ 0.5 s) and its 5 s cooldown (it inherits the default; ultimates 30–60 s).

## HUD feedback (minimal, inside the steps that add each feature)
- Charge count on the slot, a recast window timer, a charge-up bar, and fail cues by reason: not ready, not enough resource (the resource bar flashes), silenced.

## Current code
What exists today and what happens to each piece (see Build order for when).

| Code | What it does today | Status |
|---|---|---|
| `res://scripts/abilities/ability.gd` (`Ability`, Resource) | `id`, `tags`, `display_name`, `description` (plain text), `icon_color`; `targeting` (SELF / DIRECTION / POINT / UNIT); `cooldown`, `cast_time`, `cast_range`, `resets_auto_attack`, `roots_during_cast`, `dash_cancelable`, `cast_move_speed_multiplier`, `cancel_on_move`, `cancels_swing`; `base_damage`, `ad_ratio`, `damage_type`, `proc_coefficient`, `ignores_walls`; four sound fields (AUDIO A3). `get_param(caster, param)` (scoped modifiers, STATS step 6), `get_modifier_scopes()`, `get_damage(caster)` (base + ad_ratio × AD), `filter_by_walls()`, `can_reach_through_walls()`, virtual `execute()`, `on_cast_started()`, `draw_indicator()`. | **Kept and extended** (Data). No field is renamed; `description` becomes the tooltip template (plain text without placeholders still works). |
| `res://scripts/abilities/cast_context.gd` (`CastContext`) | `slot`, `point`, `direction`, `target`, `telegraph`. | **Extended** (Data). |
| `res://scripts/components/ability_component.gd` (`AbilityComponent`) | Four slots (`q`, `w`, `e`, `r` exports; `SLOTS`); one cooldown per slot (`_cooldown_left`, haste through `get_cooldown_duration()`); `try_cast()` (targeting, the UNIT walk-into-range `_pending`, line of sight); `_do_cast()`: cooldown at cast start, `&"casting"` attack lock (and move lock if rooted), the cast move speed modifier, `cast_sound`, `cast_started`, `on_cast_started()` + telegraph sound, the cast time as an `await` on a game-time timer, a stun/death check **at the end** of the cast time (refund), `execute()`, then cleanup and `cast_finished`. `_cast_serial` stops a cancelled `_do_cast()`. `try_cancel_cast()` (dash), `try_cancel_cast_on_move()`, `interrupt_cast()` (death), `cooldown_finished` + `ready_sound`, `cast_failed(slot, reason)` with `"not ready"`, `"busy"`, `"no target"`. | **Extended** (Architecture). The end-of-cast-time check stays as a safety net; AB1 adds the at-once stun interrupt. |
| `res://scripts/abilities/ability_util.gd` (`AbilityUtil`) | `enemies_of`, `in_cone`, `along_segment`, `in_circle`, `in_sight`, `nearest_enemy_to`. | **Kept.** AB10: `enemies_of()` skips untargetable units. AB7 adds a team-based query for projectiles whose caster is gone. |
| `knight/cleave.gd` (Q) | Cone from the feet, one crit roll, `from_ability()` per target, 17 px push unless blocked, shake 3 / hitstop 0.05. Custom cone indicator. | **Kept.** Tags and template in AB2. Rebuilt from toolkit pieces only in AB11 (asks first). |
| `knight/iron_resolve.gd` (W) | SELF, 0 s cast. `add_speed_modifier(&"iron_resolve", …)` (+35% for 2 s, a `status_haste` copy since C9); `attack.add_next_attack_modifier(&"iron_resolve", get_damage(caster), on_hit, 4.0)`: the next swing that hits adds the bonus (50 + 50% AD, snapshotted at cast) to its own hit, and `on_hit` per target applies the slow (`iron_resolve_slow`, −40% for 1.5 s) plus VFX, shake 2.5 and hitstop 0.04. An aura VFX while the modifier is up. | **Wrapped** in AB10: `add_next_attack_modifier()` becomes a thin wrapper that applies an empower status (Empowers); the script is unchanged. |
| `knight/lunge.gd` (E) | POINT, 0.05 s cast, `movement.dash()` at 1400 u/s with `dash_curve`, afterimages, then every enemy along the start–end capsule (80 u wide) in sight from the nearest point of the path, one crit roll, `from_ability()`. | **Kept.** First FLAG in AB-M (`lunge_stuns`). |
| `knight/judgement.gd` (R) | UNIT, 1.5 s cast with `cancel_on_move` (a channel), walks into range and sight first. `get_missing_health_bonus(target)` = (max − current) × `missing_health_ratio` (0.2) is added to the hit's `base_damage` before `resolve()`; stun 0.75 s unless blocked; its own feel. | **Changed in AB2**: the bonus becomes a `DamageScaling` term (TARGET_MISSING_HEALTH 0.2) in `knight_r_judgement.tres`; the `hit.base_damage +=` line goes (it would double the bonus); `get_missing_health_bonus()` stays as a wrapper that reads the term; the unused `missing_health_ratio` export was deleted at the start of AB3 (after AB2 passed). `cast_style` CHANNEL in AB1. |
| `slime/slam.gd` (elite Q) | POINT at the player's position, a telegraph circle during the 0.65 s cast, then a circle query from its center, one crit roll, 20 px push. | **Kept.** Tags in AB2 (`core`, `area`). |
| `HitPipeline.from_ability(caster, ability, target)` | Fills tags (the ability's), damage type, `base_damage` / `ad_ratio` params, `proc_coefficient`, `hit_sound`. | **Extended**: the scaling terms and `ap_ratio` (AB2, built); an optional `cast: CastContext = null` for the charge (AB6); empower bonuses (AB10). |
| `StatsComponent.get_ability_param(ability, param)` | Reads the base with `ability.get(param)`, applies scoped modifiers, never below 0, cached. | **Extended** (AB2): reads the base with `ability.get_base_param(param)`, so scaling-term ratios are params too. |
| `ResourceComponent` (`Unit.resource_pool`) | `try_spend()`, `restore()`, `can_afford()`, regen, `resource_changed`, `depleted`. `ResourceType` MANA / ENERGY / FURY. The Knight: MANA 300, 6/s. Nothing spends it; no HUD bar. | **Kept.** AB3 spends it and adds the bar. NONE = no ResourceComponent. |
| `AutoAttackComponent.add_next_attack_modifier(id, bonus, on_hit, duration)`, `has_next_attack_modifier(id)` | Iron Resolve's empower, used up by the first swing that hits. | **Wrapped** (AB10, Empowers). |
| `res://scripts/player/player.gd` | `CastMode` enum (`QUICK_WITH_INDICATOR`, `QUICK`), `@export var cast_mode` = `QUICK_WITH_INDICATOR`; `_on_ability_pressed()` (instant for QUICK or SELF, otherwise aim: `aiming_slot`), `_on_ability_released()` (casts the aimed slot; `is_action_released` works for W on right mouse too), Esc cancels an aim (marked handled), `request_cast()` (cast now or buffer), `can_interrupt_swing()`, `cast_ability()` (target forgiveness). | **Extended**: cast mode from Settings (AB1, default QUICK), CHARGE_UP press/release (AB6), recasts (AB5). |
| `res://scripts/ui/ability_bar.gd` | Four slots, a cooldown sweep and seconds, an aiming border, a hover tooltip drawn with `draw_string` from `ability.description` and the cooldown after haste. | **Extended**: plain tooltip from the template (AB2), fail cues (AB3), charge count (AB4), recast timer (AB5), charge-up bar (AB6). |
| `Events` | `unit_hit`, `unit_damaged`, `unit_died`, `status_applied`, `status_removed`. `ability_cast` is reserved, not declared. | **Extended** (AB8): `ability_cast(unit, ability, ctx)`. |
| `ReactionRule`, `Reactions` | Triggers built: HIT, UNIT_DIED, STATUS_APPLIED; unit and world rules by source id; chains to `MAX_CHAIN` 5. | **Extended** (AB8): trigger ABILITY_CAST, `required_ability_scope`. |

## Data (Resources)
Names checked against CONVENTIONS.md (reserved names, vocabulary). `AbilityAugment` was already reserved; the new names are listed there too. Every new field defaults to a value that keeps today's behavior.

Audio hooks: see AUDIO.md (`charge_sound` is added there for CHARGE_UP).

### New fields on Ability (`res://scripts/abilities/ability.gd`)
| Field | Type | Default | Step | Notes |
|---|---|---|---|---|
| `cast_style` | `Ability.CastStyle` | `INSTANT` | AB1 | `INSTANT`, `CHARGE_UP`, `CHANNEL`. CHANNEL behaves as `cancel_on_move` on (the bool stays and still works: `is_channel()` = CHANNEL or `cancel_on_move`). Judgement's .tres gets CHANNEL. |
| `ap_ratio` | `float` | 0 | AB2 | × `ability_power`, stage 2 like `ad_ratio` (HitContext already has `ap_ratio`). |
| `scalings` | `Array[DamageScaling]` | `[]` | AB2 | every other ratio (below). |
| `resource_cost` | `float` | 0 | AB3 | scoped param. |
| `max_charges` | `int` | 1 | AB4 | scoped param, rounded down, min 1. |
| `recast_count` | `int` | 0 | AB5 | extra parts after the first. |
| `recast_window` | `float` | 3.0 | AB5 | seconds; scoped param. |
| `recast_resource_cost` | `float` | 0 | AB5 | each later part; scoped param. |
| `charge_time` | `float` | 1.5 | AB6 | seconds to full charge; scoped param. |
| `overhold_time` | `float` | 2.0 | AB6 | seconds held after full; scoped param. |
| `overhold` | `Ability.Overhold` | `FIRE` | AB6 | `FIRE`, `CANCEL_REFUND`. |
| `charge_scalings` | `Array[ChargeScaling]` | `[]` | AB6 | the params that grow with the charge. |
| `charge_sound` | `SoundEvent` | null | AB6 | a loop on the caster while charging (AUDIO.md). |
| `projectile_speed` | `float` | 1200 | AB7 | LoL units/s (384 px/s); scoped param. Export group "Projectile"; read only by abilities that fire projectiles. |
| `projectile_width` | `float` | 60 | AB7 | LoL units, full width (19 px). |
| `projectile_count` | `int` | 1 | AB7 | scoped param. |
| `projectile_spread_deg` | `float` | 15 | AB7 | angle between neighboring projectiles of one cast. |
| `projectile_pierce` | `int` | 0 | AB7 | 0 = stops on the first hit; scoped param. Its range is `cast_range`. |
| `supported_flags` | `Array[StringName]` | `[]` | AB8 | FLAG augments this script checks (e.g. `&"lunge_stuns"`). |
| `variant_of` | `StringName` | `&""` | AB8 | for a REPLACE variant: the id of the ability it replaces. `get_modifier_scopes()` adds `ability:<variant_of>`, so item numbers on Cleave carry to its variant. |
| `ready_mode` | `Ability.ReadyMode` | `COOLDOWN` | reserved (CHAMPIONS) | `COOLDOWN`, `METER`: the slot is ready when the unit's meter is full. Not built until the meter is. |

Tags (`tags`, existing) get the standard tags in AB2 (placeholder roles; the real ones are CHAMPIONS.md's): Cleave `core`, `area`, `cone`; Iron Resolve `defensive`, `buff`; Lunge `mobility`, `dash`, `movement`; Judgement `ultimate`, `channel`; the slam `core`, `area`. Existing tags stay (don't rename). A style tag is written in the data and must match `cast_style` (the test checks it).

`description` (existing) is the tooltip template.

New methods (AB2 unless marked): `get_role() -> StringName` (the one role tag; `push_warning` once if there are zero or several), `get_base_param(param) -> float` (an `@export` of that name, else a scaling term with that `param`; else `push_error` and 0), `get_charged_param(caster, param, charge := -1.0) -> float` (AB6; −1 = the caster's current charge while it's charging this ability, else 1), `get_scaling(param) -> DamageScaling`, `get_scaling_damage(caster, target) -> float`, `get_damage_against(caster, target) -> float` (base + ratios + terms: what a hit would deal before crit and mitigation; AB6 adds `charge := 1.0`; Judgement's own override was removed in AB2, the base method gives the same number), `get_damage(caster)` (= `get_damage_against(caster, null)`), `get_tooltip(caster) -> String` (BBCode), `get_tooltip_plain(caster) -> String`, `is_channel() -> bool` (AB1).

### DamageScaling (Resource, `res://scripts/data/damage_scaling.gd`; inline in the ability's .tres)
| Field | Type | Notes |
|---|---|---|
| `param` | `StringName` | the term's param id, e.g. `&"target_missing_health_ratio"`. Its ratio is read through `get_param(caster, param)`, so scoped modifiers raise it. Must not match an `@export` on the ability (`push_error`). |
| `ratio` | `float` | the base ratio (0.2 = 20%). |
| `of` | `DamageScaling.Of` | `CASTER_STAT` (the caster's `stat`, final value), `CASTER_BONUS_STAT` (final − `get_base_value()`: League's "bonus"), `TARGET_MAX_HEALTH`, `TARGET_MISSING_HEALTH`, `TARGET_CURRENT_HEALTH`. |
| `stat` | `StringName` | for the CASTER kinds: a registered stat (`attack_damage`, `ability_power`, `max_health`, `armor`, `magic_resist`...). |
| `label` | `String` | tooltip text for the stat ("bonus AD", "of the target's missing health"); empty = generated from `of` and `stat`. |

`ad_ratio` and `ap_ratio` are the two built-in terms (`CASTER_STAT` on `attack_damage` / `ability_power`); they keep their HitContext stage-2 path. The tooltip lists them first, then `scalings` in order.
Judgement (AB2): `param` `&"target_missing_health_ratio"`, `ratio` 0.2, `of` TARGET_MISSING_HEALTH.

### ChargeScaling (Resource, `res://scripts/data/charge_scaling.gd`; inline)
- `param: StringName` (e.g. `&"cast_range"`, `&"base_damage"`, a scaling term's param), `min_fraction: float` (0.4 = 40% of the full value at charge 0), `curve: Curve` (x = charge 0–1, y = 0–1 progress from min to full; null = linear).
- `get_charged_param(caster, param, charge)` = full × lerp(`min_fraction`, 1, curve(charge)), where full = `get_param(caster, param)`. A param not listed = full at every charge.

### CastContext (new fields)
| Field | Type | Default | Notes |
|---|---|---|---|
| `ability` | `Ability` | | the ability being cast (the variant if a REPLACE is active) |
| `charge` | `float` | 1.0 | CHARGE_UP: 0–1 at release; every other cast 1.0 (so charged params are full) |
| `part` | `int` | 0 | recast part: 0 = the first cast, 1 = the first recast... |
| `flags` | `Array[StringName]` | `[]` | the FLAG augments active at cast start; `has_flag(flag) -> bool` |
| `empowers` | `Array[StatusEffect]` | `[]` | ability empowers consumed by this cast (AB10) |
| `is_free` | `bool` | false | a free cast (`CastAbilityGameplayEffect`) |
| `source_id` | `StringName` | `&""` | who granted a free cast (`item_…`, `passive_…`, `status_…`); empty for a slot cast |
| `chain_depth` | `int` | 0 | the reaction chain depth a free cast was triggered at |

### AbilityAugment (Resource, `res://scripts/data/ability_augment.gd`; files `res://data/augments/augment_<name>.tres`)
| Field | Type | Notes |
|---|---|---|
| `id` | `StringName` | e.g. `&"lunge_stuns"`. For FLAG it's the flag the script checks. Two sources with the same id = one augment. |
| `kind` | `AbilityAugment.Kind` | `FLAG`, `EVENT`, `REPLACE` |
| `scope` | `StringName` | `&"ability:knight_lunge"` or `&"tag:area"` (the modifier scope strings). REPLACE needs an `ability:` scope. |
| `rules` | `Array[ReactionRule]` | EVENT: added as unit rules while active |
| `replacement` | `Ability` | REPLACE: the variant (its `variant_of` = the replaced id) |
| `display_name`, `description` | `String` | the tooltip line ("Lunge stuns for 0.5 s.") |

### ReactionRule (additions, `res://scripts/data/reaction_rule.gd`)
- Trigger `ABILITY_CAST` (AB8): from `Events.ability_cast(unit, ability, ctx)`. The affected unit is the cast's target (`ctx.target`; null for non-UNIT casts), the other unit is the caster, so a unit rule with `owner_role` SOURCE (default) means "when I cast", and `effect_target` OTHER hits the caster. `trigger_ctx` = the CastContext. Effects that need an affected unit do nothing when it's null.
- `required_ability_scope: StringName` (`&""` = any): `ability:<id>` / `tag:<tag>`, matched against the event's ability scopes (`get_modifier_scopes()`): ABILITY_CAST's ability, HIT's and UNIT_DIED's `HitContext.ability` (null never matches a non-empty scope).

### New GameplayEffects (`res://scripts/data/`, subclasses of `GameplayEffect`; AB8)
All take the usual `apply(target, source, trigger_ctx)`; the source id is the rule's (the rule was added with one).
- `ModifyCooldownGameplayEffect`: `ability_scope` (`&""` = every slot), `mode` (`REDUCE_SECONDS`, `REDUCE_PERCENT` (of the time left), `RESET`), `amount`. Acts on `target`'s AbilityComponent, on each slot whose active ability matches.
- `RestoreResourceGameplayEffect`: `amount` + `max_resource_ratio` × max resource, on `target.resource_pool` (nothing without one).
- `CastAbilityGameplayEffect`: `ability: Ability` (any Ability resource, e.g. a hidden variant); `target` casts it for free (`AbilityComponent.try_cast_free()`); the aim comes from `trigger_ctx`: a CastContext → its `point`, `direction`, `target`; a HitContext → the hit unit's position (`target` = that unit); otherwise the caster's facing. `CastContext.source_id` = the rule's source id.
- `RemoveStatusesByTagGameplayEffect`: `tags: Array[StringName]`; removes every status on `target` carrying any of them (a cleanse is `[&"cc"]`). New `StatusComponent.remove_statuses_with_tags(tags) -> int`.

### StatusEffect (additions, `res://scripts/data/status_effect.gd`)
- `reaction_rules: Array[ReactionRule]` (AB8): unit rules on the unit while the status is active, source `&"status_<id>"`.
- `augments: Array[AbilityAugment]` (AB9): augments on the unit's AbilityComponent while active, source `&"status_<id>"`. A form is a status tagged `form` whose augments REPLACE several slots *(proposed)*.
- Empower fields (AB10); a status is an empower when `empower_consumed_by` isn't NONE (and it's tagged `empower`):
  - `empower_consumed_by: StatusEffect.EmpowerTrigger`: `NONE` (default), `BASIC_ATTACK_HIT` (the next swing that hits anything), `ABILITY_CAST` (the next ability cast that matches `empower_scope`)
  - `empower_scope: StringName` (`&""` = any ability; `ability:<id>` / `tag:<tag>`)
  - `empower_base_damage`, `empower_ad_ratio` (the source's AD, at the hit): added to every hit of that swing or cast
  - `empower_statuses: Array[StatusEffect]`: applied to every enemy that swing or cast hits (through `HitContext.statuses`)
- Status tags used by rules here: `empower`, `unstoppable`, `untargetable`, `form`.

### Settings (AB1)
- Key `&"cast_mode"`, saved as a word (`quick` / `quick_with_indicator`), default `quick`. `get_cast_mode() -> Player.CastMode`, `set_cast_mode(value)`; `setting_changed` as usual. It reuses `Player.CastMode` (no second enum).
- PauseMenu: "Cast mode: Quick / Hold to aim".

### Test and sandbox data
- `res://scenes/tests/abilities_test.tscn` + `scripts/tests/abilities_test.gd` (AB1): PASS/FAIL per check, headless exit code = failures, like the stats and combat tests.
- Test abilities (champion `test`): `scripts/abilities/test/`, `data/abilities/test_<slot>_<name>.tres`: `test_triple_step` (a 3-part recast, AB5, built: `test/triple_step.gd`, `test_q_triple_step.tres`: DIRECTION, a 150 u (48 px) step at 1200 u/s with the dash curve, the last part 1.5× as far, `recast_count` 2, `recast_window` 3 s, cooldown 4 s, tags `mobility` `dash`), `test_charged_line` (a Xerath-style line, AB6), `test_bolt` (a projectile, AB7).
- `SandboxAbilities` node in `sandbox.tscn` (`res://scripts/rooms/sandbox_abilities.gd`, source `&"sandbox_demo"`, AB3): `demo_costs` (on) and `costs` (ability id → cost: Cleave 30, Iron Resolve 40, Lunge 50, Judgement 80), given as scoped FLAT `resource_cost` modifiers so the bar and the fail cue can be played; room_01 has none. AB4: `demo_charges` (on) and `extra_charges` (ability id → extra charges: Lunge +1), scoped FLAT `max_charges`. AB5 (built): `test_q: Ability` (null = the Knight's Q; set to a test ability in the Inspector to put it on Q in the sandbox).
- AB-M: `knight/cleave_wave.gd` + `knight_q_cleave_wave.tres` (id `knight_cleave_wave`, `variant_of` `knight_cleave`); augments `augment_lunge_stuns.tres`, `augment_cleave_wave.tres`, `augment_judgement_reset.tres`, `augment_cleave_casts_lunge.tres`; a `SandboxAugments` node (`res://scripts/rooms/sandbox_augments.gd`) holding four fake items (source ids `item_test_<name>`), toggled with the number keys 1–4 read as raw keys in that sandbox-only script (no input action).

## Architecture / contracts
### AbilityComponent (additions; the existing API keeps working)
Per-slot state: charges and the recharge timer (the existing `_cooldown_left` is the recharge timer), the recast part and window, and the slot's state at cast start (for refunds). One cast or charge-up at a time, as today (`casting`, `casting_slot`).

Queries:
- `get_ability(slot)`: the **active** ability (the REPLACE variant if one is active, else the export). `get_base_ability(slot)`: the export. The HUD, Player and the tooltip read `get_ability()`.
- `is_ready(slot)`: charges > 0 (METER later). With `max_charges` 1 that's exactly today's "cooldown done".
- `can_cast(slot)` (unchanged meaning, plus a recast window counts as ready), `can_afford(slot)`, `get_fail_reason(slot) -> String` (`""` = can cast).
- `get_charges(slot)`, `get_max_charges(slot)`; `get_cooldown_left(slot)` = time until the next charge; `get_cooldown_fraction(slot)` (the sweep; the HUD draws it dark only at 0 charges).
- `get_recast_part(slot)` (the next part, 0 = no sequence going), `get_recast_time_left(slot)`, `get_recast_window(slot)` (the full window, for the HUD), `get_slot_cost(slot)` (the next press's cost) (AB5, built).
- `is_charging()`, `get_charge()` (0–1), `get_charge_hold_time()`.
- `get_augments(slot) -> Array[AbilityAugment]` (active on that slot's ability), `get_disabled_augments(slot) -> Array[Dictionary]` (`{augment, reason}`).
- `get_slots_matching(scope) -> Array[StringName]`.

Commands:
- AB3 (built): `get_cost(ability)`, `can_afford(slot)`, `get_fail_reason(slot)` (order: blocked → `"silenced"`, on cooldown → `"not ready"`, casting → `"busy"`, cost → `"not enough resource"`), `fail_cast(slot, reason)` (emits `cast_failed` for a press the Player or the buffer refuses), constants `FAIL_NOT_READY`, `FAIL_BUSY`, `FAIL_NO_TARGET`, `FAIL_NO_RESOURCE`, `FAIL_SILENCED`. The cost is paid in `_do_cast()` and refunded by `_cancel_cast()`, `interrupt_cast()` and the end-of-cast-time interrupt; `can_cast()` still ignores the cost.
- `try_cast(slot, aim, target_unit)`: as today, plus: a recast part when the slot's window is open; `"not enough resource"` fails (not buffered) and `"silenced"` (blocked by a status) fails. Fail reasons (`cast_failed(slot, reason)`, strings as today): `"not ready"`, `"busy"`, `"no target"`, `"not enough resource"`, `"silenced"`.
- `try_start_charge(slot, aim) -> bool`, `release_charge(aim)`, `try_cancel_charge() -> bool` (Esc; refund).
- `reduce_cooldown(slot, seconds)`, `reduce_cooldown_percent(slot, fraction)` (of the time left), `reset_cooldown(slot)` (all charges back, timer 0; `cooldown_finished` fires if the slot had 0 charges).
- `add_augment(augment, source_id)`, `remove_augments_from(source_id)`.
- `try_cast_free(ability, ctx, source_id) -> bool` (Free casts, below).
- `interrupt_cast()` (existing): also ends a charge-up, and refunds the cost as well as the charge.

Signals (new): `charges_changed(slot, charges, max_charges)`, `charge_started(slot, ability)`, `charge_released(slot, ability, charge)`, `recast_window_started(slot, part, time)`, `recast_window_finished(slot)`, `augments_changed(slot)`. `cooldown_finished(slot, ability)` now fires when a slot goes from 0 charges to 1 (with `max_charges` 1: exactly as today), so `ready_sound` pings when the slot becomes castable.

### The cast flow (INSTANT and CHANNEL), in order
1. `try_cast()`: the active ability; an open recast window makes this the next part. Ready (a charge, or a recast part), `can_cast`, `can_afford` (`resource_cost` for part 0, `recast_resource_cost` after; a unit without `resource_pool` always affords). Targeting as today; a UNIT cast walking into range pays nothing until it starts.
2. Note what a refund must give back: the charge taken (step 5) and the cost (step 4).
3. Snapshot the augments: `ctx.ability`, `ctx.flags` (active FLAG augments this ability supports).
4. Pay the cost (`resource_pool.try_spend()`).
5. Part 0 without recasts: take a charge; if the recharge timer isn't running, start it (`get_cooldown_duration()`: scoped `cooldown`, then haste). With recasts: take the charge, but its recharge starts when the sequence ends (Charges and recasts, below).
6. Locks and walking as today (`&"casting"`; CHANNEL = `cancel_on_move` rules).
7. `cast_sound`, `cast_started`, `on_cast_started()` (telegraph) and its `telegraph_sound`.
8. `Events.ability_cast(unit, ability, ctx)` (AB8): ABILITY_CAST rules fire now; free casts they trigger are queued on this cast.
9. The cast time. A stun (any `blocks_cast` status) applied now interrupts at once (StatusComponent's `status_applied`, AB1): `interrupt_cast()` gives the charge back and refunds the cost; queued free casts are dropped. A dash or move cancel works the same way (`_cancel_cast()`).
10. Effect start: consume ability empowers (`ctx.empowers`, AB10), run the queued free casts, then `execute()`. Nothing is refunded from here.
11. Cleanup as today; `cast_finished`. A recast ability opens (or closes) its window here.

### CHARGE_UP flow
1. Press → `Player` calls `request_charge(slot)` → `try_start_charge(slot, aim)`: ready, `can_cast`, `can_afford` as above (a swing is cut per `cancels_swing`). Saves the slot state, snapshots the augments, **pays the cost**, sets `casting` / `casting_slot`, adds the `&"casting"` attack lock and the walking rules (`roots_during_cast`, `cast_move_speed_multiplier`, `cancel_on_move`, `dash_cancelable` all apply while charging), starts `charge_sound` (`Audio.play_on(…, unit)`), `charge_started`.
2. Each physics frame (game time: hitstop and pause stop it): hold time += delta; `charge` = min(hold / `charge_time`, 1). At full, the overhold timer runs; at `overhold_time` → FIRE (release at the cursor) or CANCEL_REFUND (refund like a cancel). While charging, Player also checks `Input.is_action_pressed()` for the slot's action each frame; not held = released (covers a release lost to a focus change).
3. Release → `release_charge(aim)`: `ctx.charge` = the charge; `ctx.point` / `direction` from the cursor at release (POINT clamps to the **charged** `cast_range`); stop `charge_sound`; take the charge and start the cooldown (the cast starts now); then steps 7–11 of the cast flow (`cast_sound` at release; `cast_time` usually 0).
4. Esc, a dash on a `dash_cancelable` ability, a move press on a `cancel_on_move` one, a stun or death during the charge: cancel or interrupt, full refund (cost and charge), `charge_sound` stops.
5. UNIT targeting isn't supported for CHARGE_UP (`push_error` on load).

### Charges and recasts
- Recharge (AB4, built): while `charges < max_charges`, the timer counts down one cooldown (`get_cooldown_duration()` at the moment it starts); at 0, +1 charge and, if still below max, it starts again. A cast takes a charge and starts the timer only if none is running and the slot is now below max. A lower max (an item removed) leaves extra charges until they're spent, with no timer; a higher max starts recharging (like DashComponent). A slot starts full the first time it's asked. `get_cooldown_left()` is the time to the next charge. `cooldown_finished` (and the ready ping) fire only when a slot goes from 0 charges to 1. A refund gives back the one charge the cast took: back at max the timer stops (with 1 charge: the old cooldown refund), below max a running recharge keeps its progress.
- Recasts (AB5, built): part 0 takes a charge; its recharge doesn't start. The sequence exists from part 0's cast start (`_recast[slot]` = next part, window time, the ability), so `is_ready()` is true and `get_recast_part()` is 1 even during part 0's cast time (a press then is buffered and fires as part 1). When part 0's effect finishes, the window opens (`recast_window`, game time; `recast_window_started`). A press on the slot inside the window casts part 1 (no charge needed, `recast_resource_cost`; `get_slot_cost()` / `can_afford()` use the next part's cost), and so on up to `recast_count`. The window doesn't run while one of the slot's parts is being cast and restarts after each part. The sequence ends (`recast_window_finished`) when the last part finishes or the window runs out; the next physics frame the recharge starts. A refunded part 0 never starts its sequence; a refunded later part gives back its cost and keeps the window time it had. A recast ability should have `max_charges` 1; with more, the recharge timer pauses during a sequence.

### Input (Player, PlayerInput)
- `_on_ability_pressed(slot)` by the active ability's `cast_style`: INSTANT → QUICK: `request_cast()`; QUICK_WITH_INDICATOR: aim (`aiming_slot`), release casts (SELF casts at once, as today). CHANNEL → `request_cast()` on press. CHARGE_UP → `request_charge(slot)` (start now, or buffer). A press while the slot's recast window is open → `request_cast()` (the next part), whatever the style.
- `_on_ability_released(slot)`: the aimed slot casts (as today); the charging slot releases.
- Keys and right mouse (W) arrive the same way: `ability_q` / `ability_w` / `ability_e` / `ability_r` in `_unhandled_input` with `is_action_pressed` / `is_action_released`, which work for mouse buttons too.
- Cast mode: Player copies `Settings.get_cast_mode()` into `cast_mode` at start and on `Settings.setting_changed` (like `dash_toward_cursor`), so the Inspector value only lasts until then. A switch mid-aim doesn't touch the aim in progress.
- The buffer (MOVEMENT.md) is unchanged except: a press on an ability that's ready and not blocked but can't be afforded fails at once and isn't buffered (`Player.request_cast()`, AB3; a press that is also blocked or on cooldown is buffered as before and, if it runs out, shows that reason); a buffered CHARGE_UP press starts charging when it fires; if its key was already released by then it fires as a tap (charge 0) *(proposed; Open questions)*.

### Damage: where each term enters the pipeline
- `HitPipeline.from_ability(caster, ability, target)` (AB2): `base_damage` = the `base_damage` param + `get_scaling_damage(caster, target)` (every `scalings` term, evaluated now: caster stats, target health); `ad_ratio` / `ap_ratio` = the params (stage 2 multiplies them by the source's stats, as before). AB6 adds an optional `cast: CastContext = null` (charged params from `cast.charge`), and AB10 reads ability empowers from `cast.empowers`. So the order stays base → scaling → `damage_increase` → crit → mitigation (COMBAT.md), and every term crits.
- Tooltips use `get_damage_against(caster, null)`: target terms are 0 there and shown as text ("+20% of the target's missing health").

### Tooltips
- `get_tooltip(caster) -> String` (BBCode) fills `description`:
  - `{damage}`: the current total without a target (base + ratios with the caster's stats), rounded, colored by damage type (the default `DamageNumberStyle`'s `get_damage_type_color()`, loaded from `Ability.DAMAGE_NUMBER_STYLE_PATH`); `{base_damage}`; `{ratios}`: "+70% AD +20% of the target's missing health": `ad_ratio`, `ap_ratio` (zero ones left out), then each term (`DamageScaling.get_label()`), each with its current ratio. The Knight's templates read "{damage} physical damage ({base_damage} {ratios})" → "125 physical damage (80 +70% AD)".
  - `{cooldown}` (after scoped modifiers and haste), `{range}` (`cast_range`), `{cast_time}` (AB2); `{cost}` (AB3), `{charges}` (AB4), `{recast_window}` (AB5), `{charge_time}` (AB6).
  - `{<param>}`: any ability param by name, a scaling term's param included; `{<param>%}` shows it as a percent (0.35 → "35%"). Numbers show up to 2 decimals without trailing zeros (3, 1.5, 0.75), percents up to 1. `{<param>_min}` (AB6) for a charge-scaled param's value at charge 0 (a CHARGE_UP tooltip reads "{range_min}–{range}").
  - Then one line per active augment (its `description`) and one per disabled one ("disabled: another replacement is active").
  - An unknown placeholder stays as written, with a `push_warning` once per ability.
- `get_tooltip_plain(caster)`: the same without BBCode; the ability bar's existing `draw_string` tooltip uses it (AB2). A colored tooltip is UI.md's.
- A plain description without placeholders is returned as is.

### Events and the ABILITY_CAST trigger (AB8)
- `Events.ability_cast(unit: Unit, ability: Ability, ctx: CastContext)` (reserved name): emitted at cast start (flow step 8), at release for CHARGE_UP, for each recast part, and for free casts when they run. Not for a cast that's refused, still walking into range, or only charging.
- `Reactions` listens: trigger ABILITY_CAST, `required_ability_scope`, the unit tags of the affected unit, chance (not × `proc_coefficient`), chain depth.

### Free casts (`try_cast_free(ability, ctx, source_id)`)
- Refused (false) if the unit is dead or `is_cast_blocked()`.
- If the reaction that asked for it is running inside a cast's step 8 (`Events.ability_cast` from a cast in its cast time), it's queued on that cast and runs at step 10, or is dropped if that cast is cancelled or interrupted. Otherwise it runs now.
- Running: `ctx.is_free`, `ctx.source_id`, the augments snapshotted, `cast_sound`, `Events.ability_cast` at the depth it was triggered from + 1 (`ctx.chain_depth`; `Reactions` evaluates it at that depth even when it runs later, so a queued chain still stops at `chain_limit` / 5), then `execute()` at once. No cast time, no cost, no charge, no cooldown, no slot, no locks, no `cast_started`; it doesn't touch `casting` (it may run while another cast's effect runs).

### Augments (AB8)
- `add_augment(augment, source_id)`: stored with its source. The same `id` from several sources counts once (it stays while any source has it).
- FLAG: active on each ability its `scope` matches. An ability that doesn't list the flag in `supported_flags`: `push_error` once, and the flag is ignored for that ability.
- EVENT: while active, each rule is added as a unit rule under `&"augment_<id>"` (one copy however many sources have it); a rule with an empty `required_ability_scope` gets the augment's `scope` (a duplicated rule, so the shared .tres isn't changed).
- REPLACE: the first active REPLACE for an ability (in the order added) wins; any other is disabled, with its reason for the tooltip. Removing the winner activates the next one. Per-slot state (charges, recharge timer) carries over; the recast window stays with the ability that opened it.
- Forms *(proposed, AB9)*: a StatusEffect tagged `form` with several REPLACE augments; applying a `form` status removes any other `form` status on the unit (one form at a time).
- `augments_changed(slot)` fires on every change, for the HUD and tooltips.

### Empowers (AB10)
- Basic attacks: `HitPipeline.basic_attack()` reads the source's `BASIC_ATTACK_HIT` empowers once per swing (AutoAttackComponent snapshots them at the hit moment); each target's hit gets `empower_base_damage` + `empower_ad_ratio` × AD and `empower_statuses`, and the tag `empowered`. When the swing's hit lands on anyone, those statuses are removed (consumed).
- Abilities: at effect start (flow step 10) the caster's `ABILITY_CAST` empowers whose `empower_scope` matches go into `ctx.empowers` and are removed; `from_ability(…, cast)` adds them to every hit of that cast. Free casts consume them too.
- `add_next_attack_modifier(id, bonus_damage, on_hit, duration)` becomes a thin wrapper: it applies a runtime empower status (id = the modifier's id, tags `empower` + `buff`, `BASIC_ATTACK_HIT`, `empower_base_damage` = `bonus_damage`, that duration) and keeps `on_hit` as a per-target callback AutoAttackComponent calls when the empower is consumed (Iron Resolve's slow, VFX, shake, hitstop). `has_next_attack_modifier(id)` = `has_status(id)`. `iron_resolve.gd` is unchanged; the numbers and feel are the same.

### Unstoppable and untargetable (AB10)
- `StatusComponent.apply_status()`: a `cc`-tagged status on a unit tagged `unstoppable` returns false. Applying a status tagged `unstoppable` first removes every `cc` status on the unit (`remove_statuses_with_tags([&"cc"])`).
- `Unit.on_hit()`: an `unstoppable` target skips the hit's knockback (step 4); the hit still lands. `KnockbackGameplayEffect` is skipped too (it's knockback from another unit's rule) *(proposed)*. The unit's own `dash()` and swing steps are unaffected.
- A status tagged `untargetable` adds an invulnerability under its status id while active (hits blocked as today). `Unit.is_targetable()` = alive and not `untargetable`. Checked by: UNIT targeting in `try_cast()` ("no target") and the pending walk-into-range (dropped), `Player.cast_ability()`'s forgiveness pick, `AbilityUtil.enemies_of()`, enemy aggro and League-style attack targets (they drop the target).

### Projectile (AB7; `res://scripts/abilities/projectile.gd`, `class_name Projectile`, Node2D)
- `static func fire(caster: Unit, ability: Ability, cast: CastContext, origin: Vector2, direction: Vector2) -> Array[Projectile]`: `projectile_count` projectiles `projectile_spread_deg` apart, centered on `direction`; all share one `HitContext.CritRoll`. Params are read once at fire, charged by `cast.charge`: speed, `cast_range` (the distance), width, pierce. Added to the caster's room (like Telegraph), under units' y-sort.
- Each physics frame (game time) it moves speed × delta. Walls: the swept segment against world layer 1 (`WorldQuery.shape_sweep()`, built in AB7 per WORLD_INTERACTION.md's planned API) ends it at the wall, unless `ignores_walls`. Units: enemies of its team touching the swept capsule (`AbilityUtil`, team-based), each unit at most once per projectile, nearest first; each hit through `from_ability(caster, ability, unit, cast)`; after `projectile_pierce` + 1 hits it ends. Ends at `cast_range`.
- Caster gone: at fire it snapshots the caster-side damage (base + caster terms + AD/AP). While the caster is valid, hits use the live path above; once it's freed, hits use the snapshot with no source.
- Visual: a drawn shape in `icon_color` (VFX only); `debug_draw` shows the swept capsule. Hits carry the ability's tags (`projectile`).

### HUD (ability bar and hud)
- AB2: tooltip from `get_tooltip_plain()`.
- AB3 (built): the resource bar (`res://scripts/ui/resource_bar.gd`, added by `hud.gd`'s `setup_abilities()` only when the player has a `resource_pool`): a 132 × 4 px bar just under the ability bar (the health readout is text at the top, so the bar sits with the slots), colored by `resource_type` (mana blue, energy yellow, fury red), the current amount beside it; it blinks for 0.2 s on `"not enough resource"`. On the slots: a red flash (0.2 s) on `"not ready"` or `"silenced"`; a grey tint while the player can't cast (stunned, silenced); a blue tint while the slot's cost can't be paid. The tooltip header shows "Cost N" when the cost is above 0. A cue shows when a press is dropped: `"not enough resource"` at once (never buffered), any other reason when its buffer runs out (`PlayerInput` → `AbilityComponent.fail_cast(slot, get_fail_reason(slot))`).
- AB4 (built): the charge count (small number, bottom right) on a slot with `max_charges` > 1 (or extra charges left over); the dark sweep and seconds only at 0 charges, otherwise the initials and a 2 px bar along the bottom that fills as the next charge comes back; "N charges" in the tooltip header.
- AB5 (built): while a recast window is open, the slot shows its initials (not the sweep), a gold border and a 3 px gold bar along the bottom that shrinks as the window runs out.
- AB6: a charge-up bar on the slot (fills to full, then shows the overhold running out); the indicator grows with the charge.

### Where each AUDIO.md hook fires (abilities)
| Hook | Fires | Played by |
|---|---|---|
| `cast_sound` | cast flow step 7; CHARGE_UP at release; each recast part; free casts when they run | AbilityComponent (`Audio.play_on(…, unit)`) |
| `hit_sound` | via `HitContext.hit_sound` from `from_ability()`, once per cast (projectiles: once per cast too, the same key) | CombatSounds |
| `telegraph_sound` | after `on_cast_started()` sets a telegraph | Telegraph |
| `ready_sound` | `cooldown_finished`: a slot going from 0 charges to 1 (not on a refund; not when a recast sequence ends with charges left) | AbilityComponent |
| `charge_sound` | a loop from `charge_started` to release, cancel or interrupt | AbilityComponent (`play_on`, stopped by handle) |

## How each edge case is handled
| Edge case | Handling |
|---|---|
| A recast pressed during the cast time | The slot is casting, so the press is buffered (the buffer pauses during casts) and fires as the next part the moment the cast finishes and the window opens. |
| A charge refunded on cancel | Cancel and interrupt give back the charge the cast took (and the cost). Back at max, the recharge timer stops; below max, a recharge that was already running keeps its progress (time that passed during the cast time isn't lost). A refund never pings `ready_sound`. |
| An augment removed mid-cast | The cast keeps what it snapshotted at its start (`ctx.ability`, `ctx.flags`); the change applies from the next cast. The removed augment's EVENT rules are gone at once, so they can't fire later in that cast. |
| A REPLACE equipped while the slot is on cooldown | The slot's charges and recharge timer carry over; the variant is ready when the slot would have been. |
| A REPLACE equipped mid-charge-up or mid-cast | The running cast or charge finishes as the old ability (snapshotted). The slot shows the variant afterwards. An open recast window stays with the old ability until it closes. |
| A form swap mid-cast | Same as a REPLACE: the running cast keeps its ability; cooldowns are per slot, so they carry across forms (separate per-form cooldowns: Open questions). |
| Cost paid, then the cast interrupted | Refunded (Rules, Casting). Even if that pushes the pool above what it was (regen meanwhile), it's clamped to max. |
| Resource drained during a cast or charge-up | Nothing: the cost was paid at the start. |
| A charge-up released during a swing, dash or stun | Can't happen as such: charging holds the attack lock (no swing starts); a dash either cancels the charge (`dash_cancelable`, refunded) or waits (buffered) until after the release; a stun interrupts the charge at once (refunded). A release after a cancel or interrupt is ignored. |
| Overhold | After full charge the overhold timer runs `overhold_time`; then FIRE releases at the cursor, or CANCEL_REFUND cancels with a full refund. The charge-up bar shows it running out. |
| Cast mode switched mid-aim | The aim in progress finishes as it started (release casts); the new mode applies to the next press. |
| A projectile whose caster dies | It keeps flying. Kill credit is the caster's while it exists; once it's freed, snapshot damage and no source (Rules, Projectiles). |
| Two sources of the same augment | Counted once; it stays until the last source is removed. Its EVENT rules are added once. |
| An unsupported FLAG | `push_error` once when it's added; ignored for that ability (the tooltip doesn't list it). |
| An empower granted by a passive or item | The same status, applied by whatever the source is (a passive's rule, an item's `ApplyStatusGameplayEffect`); consumption doesn't care who applied it. Its bonus AD ratio reads the attacker's AD, not the applier's. |
| Unstoppable applied while stunned | Applying it removes every `cc` status at once (the stun ends, its locks go); new cc is refused while it lasts. |
| A CastAbility effect chaining into itself | Each free cast emits `ability_cast` one chain link deeper (even when queued); rules stop at their `chain_limit`, and nothing passes `MAX_CHAIN` 5. |
| A cooldown reset on a slot that's mid-cast | INSTANT and CHANNEL took their charge at cast start, so a reset gives it back now; the slot is castable once the cast finishes. Mid-charge-up or mid-recast-window, no cooldown is running yet: the reset restores any missing charges and has nothing else to act on. |
| A free cast triggered at cast start, then that cast is cancelled or interrupted | Dropped with it; nothing ran. |
| A free cast when the caster is stunned or dead at its run time | Refused (the rule's effect does nothing). |
| A stun during the cast time of an enemy's telegraphed ability | Interrupted at once: the telegraph and its wind-up go the same frame, cooldown refunded (AB1). |
| A cast refused for "not enough resource" | The resource bar flashes; the press isn't buffered, so it won't fire when mana regenerates. |
| An untargetable enemy under the cursor for a UNIT cast | Not a target: "no target", or the next targetable one within `target_forgiveness`. A target that turns untargetable mid-cast: the hit is blocked (invulnerable), so the cast misses. |
| `max_charges` lowered while charges are stored | Extra charges stay until spent; the recharge runs only below the new max. |

## Build order (one step per request)
Every step: with no cast style changes, scalings beyond today's, costs, charges, recasts or augments set, the game plays exactly as before, and the Knight's abilities, enemies chasing and the HUD still work. The two intended changes are in AB1 (QUICK cast mode by default; a stun mid-cast interrupts at once). Build logs go in `docs/CHANGELOG.md` (an Abilities section); this doc keeps one line per built step.

1. **AB1 – Cast style, the stun interrupt, cast mode.** The cast rules moved here (done with this doc). `Ability.cast_style` (INSTANT default; CHANNEL behaves as `cancel_on_move`), `is_channel()`; Judgement's .tres gets CHANNEL (its `cancel_on_move` stays on). AbilityComponent interrupts a cast at once when a `blocks_cast` status is applied during the cast time. `Settings` cast mode (default QUICK) + the pause menu option; Player copies it. `abilities_test.tscn` created.
   **Done means:** the test passes: a stun 0.1 s into Judgement ends the cast at once with the cooldown refunded; a stun on the elite mid-slam removes the telegraph that frame; CHANNEL on an ability with `cancel_on_move` off cancels on a new move press; the setting saves and loads. In play: Q/E cast on press; switching to "Hold to aim" in the pause menu brings back hold-and-release; Judgement still cancels when you move; everything else plays as before.
   AB1 built 2026-09-26, see CHANGELOG.md.
2. **AB2 – Damage scalings, tooltips, tags.** `DamageScaling`, `ap_ratio`, `scalings`, `get_base_param()` (StatsComponent reads it), `from_ability()` with the terms; Judgement's missing health into data; `get_tooltip()` / `get_tooltip_plain()`; the Knight's descriptions become templates; the ability bar tooltip uses the plain one; the standard tags on the Knight's abilities and the slam; `get_role()`.
   **Done means:** Judgement deals exactly the same on a dummy at 100% and 50% health as before; a scoped modifier on `target_missing_health_ratio` raises it; tooltips show the same numbers as the hits, and change when a fake +AD modifier is added and removed; Cleave's tooltip says 80; hits carry the new tags; every ability has exactly one role tag.
   AB2 built 2026-09-27, see CHANGELOG.md.
3. **AB3 – Costs, the resource bar, fail cues.** `resource_cost`, pay and refund, `"not enough resource"` (not buffered) and `"silenced"` fail reasons, the HUD resource bar and the fail cues; `SandboxAbilities` with `demo_costs`.
   **Done means:** the test covers paying, refunds on cancel and interrupt, not buffering, and a unit without a pool casting free. In room_01 the Knight's abilities stay free (the bar stays full). In the sandbox, casting spends mana, the bar drains and regenerates, and a cast without enough mana flashes the bar and doesn't fire later.
   AB3 built 2026-09-27, see CHANGELOG.md.
4. **AB4 – Charges.** `max_charges`, the recharge, `charges_changed`, `cooldown_finished` on 0 → 1, the charge count on the slot.
   **Done means:** with `max_charges` 1 everything is as before (the test compares cooldown timing); a scoped +1 `max_charges` on Lunge gives two Lunges back to back, recharging one at a time, with the count on the slot; removing it keeps the extra charge until spent.
   AB4 built 2026-09-27, see CHANGELOG.md.
5. **AB5 – Recasts.** `recast_count`, `recast_window`, `recast_resource_cost`, `ctx.part`, the window and its HUD timer; `test_triple_step` (three short steps).
   **Done means:** the test covers parts, the window pause during a part, the cooldown starting when the last part is used or the window ends, and a buffered recast during a cast time. In the sandbox (`test_q`), Q three times steps three times, the slot shows the window, and the cooldown starts after the third step or 3 s.
   AB5 built 2026-09-27, see CHANGELOG.md.
6. **AB6 – Charge-up.** `CHARGE_UP`, `charge_time`, `overhold_time`, `overhold`, `ChargeScaling`, `get_charged_param()`, the growing indicator, the charge-up bar, `charge_sound`; `test_charged_line` (a Xerath-style line: range 40% → 100%, damage 50% → 100%, walking at 0.6 while charging).
   **Done means:** the test covers tap = charge 0 values, full charge, overhold FIRE and CANCEL_REFUND, the cost at charge start, the cooldown at release, and the refunds (Esc, stun). In the sandbox the line's indicator grows while Q is held, release fires it at the cursor, and a tap fires a short weak one.
7. **AB7 – Projectiles.** `Projectile`, the projectile params, `WorldQuery.shape_sweep()`; `test_bolt`.
   **Done means:** the test covers pierce 0 and 2, walls, one crit roll per cast, a scoped +1 `projectile_count` giving two bolts, and a caster freed mid-flight (snapshot, no source). In the sandbox the bolt flies, stops at the pillar, and hits a dummy behind a slime only with pierce.
8. **AB8 – Augments and the new GameplayEffects.** `AbilityAugment` (FLAG, EVENT, REPLACE), `supported_flags`, `variant_of`, `Events.ability_cast`, the ABILITY_CAST trigger, `required_ability_scope`, free casts (queued to effect start), `StatusEffect.reaction_rules`; `ModifyCooldown`, `RestoreResource`, `CastAbility`, `RemoveStatusesByTag`. A fake item test like STATS': equipping changes behavior, unequipping restores exactly.
   **Done means:** the test covers each kind, the duplicate and second-REPLACE rules, a mid-cast removal, an unsupported flag, a queued free cast dropped on interrupt, a chain stopping at its limit, and each effect. In play nothing changes (no augments are given).
9. **AB9 – Forms** *(proposed)*: `StatusEffect.augments`, one `form` status at a time, multi-slot REPLACE from one status.
   **Done means:** a test form status swaps Q and E, removing it restores them, and cooldowns carry across.
10. **AB10 – Empowers, unstoppable, untargetable.** The `empower_*` fields, the `empowered` hit tag, Iron Resolve through the `add_next_attack_modifier()` wrapper; `unstoppable` (cc immunity and removal, no knockback from hits), `untargetable` (`is_targetable()`), the cleanse.
    **Done means:** Iron Resolve plays exactly as before (the same bonus, crit with the swing, slow and feel on every enemy the swing hits); the same empower applied from a fake passive source (`passive_test`) works the same; an ability empower is consumed by the next matching cast only; unstoppable removes a stun and blocks slows and knockback; an untargetable dummy can't be Judgement's target.
11. **AB11 – The Knight's 4 abilities rebuilt from toolkit pieces only.** This replaces working code: plan it and ask Ryan before doing it.
    **Done means:** (decided when planned) each ability plays and numbers exactly as before.

**Milestone AB-M – augment playground:** in the sandbox, `SandboxAugments` with 4 fake items that visibly change the Knight: Lunge stuns (FLAG), Cleave becomes a projectile wave (REPLACE), a Judgement kill resets its cooldown (EVENT + ModifyCooldown), casting Cleave also casts a free Lunge-style dash (CastAbility, at Cleave's effect start). Keys 1–4 equip and unequip them; the tooltips show each change; unequipping restores the Knight exactly.

## Out of scope
Passives themselves and champion kits (CHAMPIONS.md: a Passive bundles stat modifiers, unit reaction rules, statuses, empowers and an optional script, all under a source id like `passive_knight`, built on this toolkit); items and affix rolls (LOOT.md); enemy AI choosing abilities (ENEMIES_AI.md); ability ranks and leveling (waits for the run-structure decision, VISION.md); summons; ability slot swapping (VISION.md, open question 5); TOGGLE, SUSTAINED and VECTOR cast styles; the ultimate meter (CHAMPIONS.md).

## Open questions
- Ultimate meter details (CHAMPIONS.md).
- Ability ranks / leveling (after run structure).
- Which Knight abilities ignore walls (CHAMPIONS.md).
- The element tag list.
- Can a recast part be dash-cancelled separately?
- Resource-type rhythms (energy regen rate, fury decay out of combat): here or CHAMPIONS.md?
- Charge-up and the input buffer: a press buffered during a swing or dash whose key is already released when it fires: a tap (charge 0), or dropped? *(proposed: a tap)*
- Forms: shared per-slot cooldowns (today's proposal) or separate cooldowns per form (Jayce)?
- The "on end" augment event (`ability_finished`): when something needs it.
- Does `KnockbackGameplayEffect` count as knockback that unstoppable blocks? *(proposed: yes)*
