# DECISIONS.md: Design Decisions Log

**Read when:** before proposing changes to an existing design, or when asked why something works the way it does.
**Depends on:** nothing. **Used by:** every doc.

## How to use
- One row per decision: date (YYYY-MM-DD), the decision, and why.
- Add new decisions to the matching system section (add a section if none fits). If a decision changes how a system works, also update that system's doc.
- Never delete a row. When a decision is reversed, strike it through (`~~text~~`), add "superseded YYYY-MM-DD, see below", and add the new decision as its own row.
- Don't re-suggest anything that is rejected or superseded here unless Ryan reopens it.

## General
| Date | Decision | Why |
|---|---|---|
| 2026-09-24 | Changes are additive to the reference build in `game/`. Remove or replace code only when it directly blocks a feature, and only with Ryan's OK. Disable before deleting. | The reference build works. Building on it keeps existing features (Knight abilities, enemies, HUD) working after every change. |
| 2026-09-24 | Docs live in `uhgame/docs/`, and CLAUDE.md is the only root brief. | CLAUDE.md is read at the start of every task, so it holds only what's true for every task; system details are read only when a task needs them. |
| 2026-09-24 | Claude may touch the files the current build step lists, not only the files Ryan names; anything else still needs asking first. VISION.md and CONVENTIONS.md are in the CLAUDE.md Docs index. | Build steps already list the files they need, so asking again for each one only slows things down. Both docs existed but weren't in the index Claude reads first. |
| 2026-09-24 | Decisions are recorded here, grouped by system, and also in the affected system doc when they change how it works. CLAUDE.md's "Current status" is overwritten each session (Now / Last 3 done / Next), not appended to. | Keeps CLAUDE.md short (under 150 lines) while the full decision history stays in one place. |
| 2026-09-25 | Order of work: Movement step 8 (pits) → STATS build steps → then the Future docs in their listed order (CLAUDE.md). | STATS.md is already written, so its build steps come before writing COMBAT.md. |

## Conventions
| Date | Decision | Why |
|---|---|---|
| 2026-09-25 | Ability `id` format is `<champion>_<ability>` with no slot (`knight_lunge`). The .tres filenames keep the slot (`knight_e_lunge.tres`). | Ids survive slot swaps; filenames stay as they are. |
| 2026-09-25 | Move lock, speed modifier and invulnerability ids name their owner (`&"dash"`, `&"iron_resolve_slow"`). The `<kind>_<name>` rule applies to modifier and status source ids (e.g. `&"status_haste"`, which replaces `&"buff_haste"` in STATS.md). Existing ids don't change. | Matches the existing code; `<kind>_<name>` is for sources that get removed as a group. |
| 2026-09-25 | `PlayerInput` (reads input) and `SurfaceTags` (data only) are exceptions to the `Component` suffix, next to `Hitbox` / `Hurtbox`. | Neither is a component in the usual sense, and `PlayerInput` already exists. |

## Movement
| Date | Decision | Why |
|---|---|---|
| 2026-09-24 | Switched from point-and-click to WASD. | Hades-style feel is the goal. |
| 2026-09-24 | Movement steps 1 (input map) and 2 (WASD walking) ship together as step 1. | After the input step alone the player had no walk input (right-click move is unbound). |
| 2026-09-24 | MovementComponent priority is displacement > move lock > walking. MOVEMENT.md was corrected to match the code. | Knockback must still move a stunned or casting unit, and Lunge moves the Knight during its own cast lock. |
| 2026-09-24 | The player opts out of steering with `use_steering = false`; `avoidance_enabled` is not reused for this. | Turning `avoidance_enabled` off would also make other units stop steering around the player. |
| 2026-09-24 | Knight base move speed is 560 (≈179 px/s). Soft cap thresholds are scaled ×560/345 (357 / 674 / 795) and exported on MovementComponent. Chosen over raising `Units.PX_PER_UNIT`. | 345 (110 px/s) is too slow for Hades pace (about 6 s to cross the screen), and LoL's caps would squash 560 to 510. Raising `PX_PER_UNIT` would also enlarge every range. |
| 2026-09-24 | Movement step 3 is only facing and aim. | The nearest-enemy fallback for UNIT abilities already exists in `Player.cast_ability()`. |
| 2026-09-24 | Esc cancels an aimed ability; right mouse now casts W. Trial `cast_mode = QUICK` after step 1. | Right mouse moved to `ability_w`, and Esc is good enough for now. QUICK may feel more Hades-like. |
| 2026-09-24 | WASD input cancels a queued targeted cast that is walking the player into range. | Same as a LoL move order. Otherwise the Knight walks off toward the target again after the keys are released. |
| 2026-09-24 | The player keeps Godot's default `wall_min_slide_angle` (15°). | At 0°, near-head-on pushes shot the player sideways along walls. |
| 2026-09-24 | ~~Facing priority: casting (aim locked at cast start) > attack windup (target) > aiming an ability (cursor) > walking (move direction); standing still keeps the last facing. SELF casts don't change facing.~~ Superseded 2026-09-25, see below. | MOVEMENT.md says facing follows the aim while attacking or casting. Locking it at cast start keeps the sword and sprite pointing where the ability actually goes, and following the cursor while aiming shows where it will go. |
| 2026-09-24 | Camera aim lead scales with the mouse's distance from the screen center (up to `aim_lead` at the edge; ~~24 px~~ superseded 2026-09-24, see below), measured in screen space. Holding C centers with no lead. | A fixed lead in the aim direction would jump when the cursor crosses the player, and using the mouse's world position would feed back into itself as the camera moves. |
| 2026-09-24 | Player states are worked out each physics frame from the components (priority STUNNED > DASH > CASTING > DISPLACED > ATTACK > MOVE > IDLE) and only describe what's happening; the components keep driving behavior. They live in player.gd. | Additive: no existing logic moves into a state machine, so abilities, locks and auto-attacks behave exactly as before. |
| 2026-09-24 | Added a `DISPLACED` state (knockback or pull while not casting), beyond MOVEMENT.md's original six. Holding a direction counts as `MOVE`. | Knockback isn't a stun (you can still cast) and isn't idle (you can't walk). Treating held input as MOVE avoids a one-frame IDLE after every cast. |
| 2026-09-24 | ~~`aim_lead` default raised from 24 to 64 px.~~ Superseded 2026-09-25, see below. | At 24 px the lean was too subtle to notice in play testing. |
| 2026-09-24 | The dash is a new `DashComponent` on the Player. Its tunables are exports on the node; the charge count is `UnitStats.dash_charges`. | Keeps dash logic out of player.gd, and any Unit can get a dash later. dash_charges is a stat in STATS.md, so it lives on UnitStats. |
| 2026-09-24 | Dash i-frames are a Unit-level invulnerability (`add_invulnerability(id)`) that blocks `take_damage()` and Hurtbox hits, not just the Hurtbox. | Enemy basic attacks call `take_damage()` directly, so Hurtbox-only i-frames wouldn't stop them. |
| 2026-09-24 | Dash charges come back one at a time, counted only while not dashing. End-lag locks walking only; a dash can chain in during it. | Matches "each recharges in ~0.35 s" and "chainable if a charge is available" in MOVEMENT.md. |
| 2026-09-24 | No dash while stunned, casting or already displaced. A dash cancels a basic attack windup and a queued walk-into-range cast. | Which abilities can be dash-cancelled is decided per ability in step 7 (MOVEMENT.md). The dash is the player's own move, like WASD. |
| 2026-09-24 | Input buffer holds one press at a time (newest wins) for 0.15 s. The timer pauses while a dash or cast is playing out, not during stuns or cooldowns. | Last-input-wins is predictable; mashing doesn't queue a chain of actions. Pausing during dashes and casts means a press made during one always fires when it ends, even if it lasts longer than 0.15 s. |
| 2026-09-24 | No casting while dashing; a Q/W/E/R press mid-dash is buffered and fires when the dash ends. | Casting during a dash (e.g. Lunge) would replace the dash's displacement and end its ghosting and i-frames early. |
| 2026-09-24 | Each ability opts into dash-cancelling its cast time with `Ability.dash_cancelable` (off for all Knight abilities). A cancel refunds the cooldown; `execute()` can't be cancelled. | MOVEMENT.md: "each ability decides". Off by default keeps current behavior; the refund matches how a stun interrupt already works. |
| 2026-09-24 | Dash-strike: an `attack` press that fires within 0.1 s after a dash ends emits `PlayerInput.attack_pressed(dash_strike = true)`. It's only a hook; nothing attacks until COMBAT. | Gives COMBAT a ready flag without deciding attack behavior now. |
| 2026-09-24 | `facing` and the aim helpers live on Player for now, not on Unit. | Only the player needs them so far (sprites, dash direction). They can move to Unit if enemies get directional sprites. |
| 2026-09-25 | Feel pass F1: 2D physics interpolation on, `snap_2d_transforms_to_pixel` off. | Measured on-screen shake at 144 fps went from 5.4 px to 0.04 px. Keeping snapping left a 0.86 px shake; Ryan picked whatever feels most like Hades. Art stays sharp (nearest filtering); sprites can sit half a game pixel off the grid. |
| 2026-09-25 | Physics stays at 60 Hz. | Interpolation already makes motion smooth at any refresh rate. 120 Hz would halve the ≤16.7 ms display delay but double physics cost, which matters for Diablo-size enemy crowds. Revisit if the dash feels laggy. |
| 2026-09-25 | Camera: `process_callback` = Physics in `main.tscn`; follow logic stays in `_process`; `snap_to_target()` resets interpolation (before `reset_smoothing()` and after the first physics tick). | Godot forces physics mode under interpolation and warns otherwise. Moving the follow logic measured no smoother. Without the resets the camera slides in from the corner at scene start. |
| 2026-09-25 | Any teleport (respawn, blink) must call `reset_physics_interpolation()` on the moved node. | With interpolation on, an instant move otherwise shows as a slide. |
| 2026-09-25 | Feel pass F2: displacements follow a progress `Curve` (normalized, so the distance is always exactly velocity × duration). `displace()` without a curve uses `knockback_curve`; `dash()` without a curve stays constant speed. Curves live in `data/curves/`; the defaults are set in the scripts. | Knockback should ease everywhere by default, while any dash caller keeps today's behavior unless it opts in. Normalizing means a hand-edited curve can't change distances. |
| 2026-09-25 | Dash curve = ease-out quad (first frame ≈1356 px/s, 2× average); knockback curve = ease-out cubic (3× average at the start). | Starting shapes from the F2 spec: a burst that eases out, with knockback settling faster. |
| 2026-09-25 | `carry_into_run` (default on): if a direction is held when a dash ends, walking starts at full speed and `end_lag` is skipped. `end_lag` only applies when no direction is held. | Keeping end-lag would put a 0.05 s stop between the dash and running, which the F2 "Done" rules out. When you stop, end-lag still plants the landing. |
| 2026-09-25 | Lunge uses `curve_dash` too (set in `knight_e_lunge.tres`). | Its hits are found along the start-to-end segment, so the speed profile doesn't change what it hits. |
| 2026-09-25 | Feel pass F4 (camera aim lead rework) runs before F3. `aim_lead` stays 64 px but is now only the horizontal maximum; vertical = 0.6 × that. Planned: dead zone 0.35 (oval), ease-in quad response to full at 0.9, its own easing (4.0/s, follow stays 10), full lead only while aiming or casting (0.3 otherwise), optional `move_lead_px` (0). | Play testing: the camera moved with every cursor movement, and 64 px vertically is over a third of the 360 px half-screen. The lead should help aim at enemies just off screen, not follow the mouse. |
| 2026-09-25 | Facing priority: casting (aim locked at cast start) > attack windup (target) > dashing (dash direction) > aiming an ability (cursor) > walking (move direction); standing still keeps the last facing. SELF casts don't change facing. | Matches MOVEMENT.md and `Player._update_facing()`: step 6 added dashing to the order, which the 2026-09-24 row didn't include. |
| 2026-09-25 | `dash()` and `displace()` slide along walls (`move_and_slide()`); they don't stop at them. Docs that said "stops at walls" were corrected. | That's what the code does. Only a near-head-on hit (within `wall_min_slide_angle`) stops. |
| 2026-09-25 | Keyboard and mouse only for now; no gamepad. Also in VISION.md, Scope. | Ryan's call. Mouse aim is built into facing, abilities and the camera lead. |

## Stats
| Date | Decision | Why |
|---|---|---|
| 2026-09-24 | Stat data stays in LoL units, converted with `Units.to_px()`. | Existing convention. |
| 2026-09-24 | One StatsComponent for every Unit. Champions are data, not subclasses. Stats change only through source-tagged modifiers. | No player-only stat code, and removing an item or ending a buff removes exactly what it added (STATS.md). |
| 2026-09-24 | move_speed soft caps carry over into StatsComponent scaled, not unchanged. Per-unit threshold overrides carry over too. | Follows the Knight 560 move speed decision (Movement). |
| 2026-09-25 | STATS step 4 migrates every `stats.` read found in the code (Unit, AutoAttackComponent, AbilityComponent's ability_haste, DashComponent's dash_charges, Ability.get_damage, main.gd's HUD line); the list is in STATS.md. | The old list missed DashComponent, AbilityComponent and main.gd. |
| 2026-09-25 | The `attack_speed` stat's base is `UnitStats.base_attack_speed`. `attack_speed_cap` is a per-unit maximum for `attack_speed`, not a stat. | Keeps the existing UnitStats fields; the cap is identity data like `attack_windup`. |

## Combat
| Date | Decision | Why |
|---|---|---|
| 2026-09-24 | `attack` vs `select` (both on left mouse) is resolved during the COMBAT work. | No double-fire yet: `select` only acts while attack-move is armed (unbound A key), and nothing reads `attack`. |
| 2026-09-24 | The Knight's basic attacks stay dormant until COMBAT.md gives `attack` a reader. Enemies keep attacking. | Their only triggers (right-click, A-click) are unbound. A temporary left-click attack would reopen the `attack`/`select` overlap. |

## World Interaction
| Date | Decision | Why |
|---|---|---|
| 2026-09-24 | Abilities request movement through MovementComponent methods and never set position or velocity themselves. | Each movement method defines how it starts, what ends it, and what happens at walls and units, and a stun ends any of them (WORLD_INTERACTION.md). |
| 2026-09-25 | Movement methods emit `Events.unit_impacted(ImpactContext)` when a displacement hits a wall or unit. Wall-slam stuns are ReactionRules (CONVENTIONS.md worked example), not surface-tag code in movement. Whether `bounce` is movement or a GameplayEffect is open. | One impact event lets any rule react, instead of hard-coding wall behavior per tag. |
| 2026-09-25 | Interactables get `on_hit(ctx: HitContext)` instead of `on_ability_hit(caster, ability, ctx: CastContext)`. `HitContext` gets a nullable `ability` field. | Basic attacks, hazards and knockback can break or trigger things too, not only abilities. |

## Enemies
| Date | Decision | Why |
|---|---|---|
| 2026-09-24 | Training dummies are an Enemy with `passive = true` (no wander, aggro, or attacks), not a subclass. | Additive, default behavior unchanged, and it keeps the Unit → Player / Enemy hierarchy flat. |
| 2026-09-24 | Slimes keep the LoL soft cap thresholds (220 / 415 / 490) as overrides in `slime.tscn`. | Keeps enemy speed unchanged (the scaled low cap would lift 285 to 321). Enemy speeds get retuned in ENEMIES_AI.md. |

## Testing
| Date | Decision | Why |
|---|---|---|
| 2026-09-24 | The sandbox runs through `scenes/sandbox_main.tscn` (inherits `main.tscn`, with the sandbox as `room_scene`). room_01 stays the default game. | No edits to `main.tscn` or `main.gd`. |
| 2026-09-24 | Sandbox pieces that need unbuilt systems (pits, hazards, grappleable walls) are added with those systems. | They depend on TileSet custom data, collision layer 6, and `Hazard`, which don't exist yet. |
| 2026-09-25 | CONVENTIONS.md, Testing describes the sandbox as it is now and points to MOVEMENT.md, Testing. The F3 stat overlay is planned (STATS.md step 7) and needs a new input action when it's built. | The old text described a pit, hazards and an F3 overlay that don't exist yet. |
