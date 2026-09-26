# MOVEMENT.md: Player Movement (Hades-style, 2D)

**Read when:** the task involves player movement, dash, input, the input map, buffering, facing/aim, camera follow, or the LoL-era systems that WASD replaced.
**Depends on:** CLAUDE.md (change policy).
**Used by:** abilities (movement methods), COMBAT (locks, slows, knockback, i-frames), WORLD_INTERACTION.md.

## Current code
| File | Role |
|---|---|
| `res://scripts/components/movement_component.gd` | Shared by all Units. Enemies walk with `move_to()` (NavigationServer2D pathing, steering). The player walks with `set_input_direction()`. Also move locks, speed modifiers with soft caps, `displace()`, `dash()`. |
| `res://scripts/player/player_input.gd` | `PlayerInput`, child of Player. Reads WASD, dash and attack each physics frame; owns the input buffer. |
| `res://scripts/components/dash_component.gd` | `DashComponent`, child of Player. The dash. |
| `res://scripts/player/player.gd` | Q/W/E/R casting, facing and aim, player states. The LoL right-click orders are still there, dormant. |
| `res://scripts/camera/game_camera.gd` | Locked follow with aim lead; unlocked edge pan; shake; room bounds. |

Visuals are Polygon2D placeholders (`Body`, `SwordPivot`). The plan is **8-direction sprites**.

**Player size** (`player.tscn`, `knight.tres`):
- Collider: `CircleShape2D`, radius **11 px** (22 px wide), centered on the feet (the Player's origin). Set in the scene, not from stats. Collision layer 2, mask 7 (world, player, enemies).
- `gameplay_radius` = 65 u ≈ 20.8 px: ranges, clicking on the unit, the hover ring. `pathing_radius` = 35 u ≈ 11.2 px: `MovementComponent.radius_px` (steering).
- A 1-tile corridor is **32 px** wide, which leaves 5 px on each side of the collider.

## Target feel
Instant and precise, never floaty. The player steers directly with almost no momentum. Treat the numbers as starting points.

| Property | Value |
|---|---|
| Move speed | **560 LoL units ≈ 179 px/s** (Knight, `knight.tres`). See Speed and soft caps. |
| Time to full speed | 0.05 s (`input_accel_time`) |
| Time to stop | 0.04 s (`input_decel_time`), no visible slide |
| Direction change | instant, no turn-around slowdown |
| Diagonals | input vector normalized |
| Walls | slide smoothly, never catch on tile corners |
| Other units | the player collides but is **never steered/deflected**; steering stays for enemies |

**Corner forgiveness** *(proposed, build later)*: while walking, if a tile corner blocks the player by 6 px or less on the side, nudge them around it at walk speed.

## Input and legacy systems
### Input map
Only keys that physically collided with WASD changed. Action names never change. Keyboard and mouse only for now; no gamepad.

| Action | Key | Notes |
|---|---|---|
| `move_up` / `move_down` / `move_left` / `move_right` | W / S / A / D | new |
| `dash` | Space | new |
| `attack` | Left mouse | new; PlayerInput only emits `attack_pressed` (no attack yet, see Open questions) |
| `interact` | F | new; nothing reads it yet |
| `ability_q` / `ability_e` / `ability_r` | Q / E / R | unchanged |
| `ability_w` | Right mouse | was W |
| `camera_center` | C | was Space |
| `move` / `stop` / `attack_move` | none | were right mouse / S / A. Actions and code stay, dormant. |
| `select`, `restart`, `camera_toggle_lock`, `camera_left/right/up/down` | Left mouse, Backspace, Y, arrow keys | unchanged |

### LoL-era systems
| System | Status |
|---|---|
| `MovementComponent.move_to()` pathing and steering | Kept. Enemies use it, and so does R walking the Knight into range. |
| `player.gd` right-click move, attack-move, stop | Dormant: their keys are unbound. |
| `click_marker.gd` | Dormant with right-click move. |
| `game_camera.gd` lock toggle, edge pan, shake, bounds | Kept. Aim lead added (see Architecture). |
| `AbilityComponent` Q/W/E/R slots | Unchanged. W is on right mouse. |
| Aim cancel (`player.gd`) | Right mouse used to cancel an aimed ability; it now casts W. Esc (`ui_cancel`) cancels. |
| `AutoAttackComponent` | Kept until COMBAT.md. The Knight's basic attacks are dormant (right-click and A-click were their only triggers); enemies still attack. |
| `enemy.gd` | Kept. `passive` export turns an enemy into a training dummy: no wander, aggro, or attacks. |
| `Ability.get_damage()` reading `caster.stats` | Kept until STATS.md step 4 puts StatsComponent behind the same values. |

## Speed and soft caps
- The Knight's base `move_speed` is **560** (was 345).
- The soft cap thresholds are scaled by the same ratio (560 / 345 ≈ 1.623) and are `@export`s on `MovementComponent`:

| Export | LoL original | Scaled default | Rule |
|---|---|---|---|
| `soft_cap_low` | 220 | 357 | below: the shortfall counts ×0.5 |
| `soft_cap_high` | 415 | 674 | above: the excess counts ×0.8 |
| `soft_cap_max` | 490 | 795 | above: the excess counts ×0.5 |

- Computed as "threshold + excess × factor", so the curve is continuous for any thresholds; the LoL originals give exactly the old numbers. `get_move_speed()` uses the exports; the static `apply_soft_caps()` stays as the LoL reference.
- Examples: Knight 560 → 560 (179 px/s). With Iron Resolve (+35%): raw 756 → 740 (237 px/s).
- **Slimes keep the LoL thresholds** (220 / 415 / 490) as overrides in `slime.tscn`, so they move exactly as before (the scaled low cap would lift 285 to 321). Enemy speeds get retuned in ENEMIES_AI.md.

## Facing and aim
- Units don't rotate. `Player.facing` (unit vector) is the look direction; the animation layer will pick one of 8 sprites with `get_facing_octant()` (0 = right, clockwise: 2 = down, 4 = left, 6 = up).
- Facing priority, updated each physics frame:
  1. **Casting:** toward the cast's aim, locked at cast start (DIRECTION/POINT: the aim point; UNIT: the target). SELF casts don't change facing.
  2. **Attack windup:** toward the target.
  3. **Dashing:** the dash direction.
  4. **Aiming an ability** (hold-to-aim): toward the cursor. The sword follows the cursor too.
  5. **Walking:** the move direction.
  6. **Standing still:** keeps the last facing.
- `Player.get_aim_point()` = `get_global_mouse_position()`. `Player.get_aim_direction()` is the unit vector from the player's feet (where abilities cast from) to it, or `facing` when the cursor is on the player.
- UNIT abilities also accept the enemy nearest the cursor within `target_forgiveness` (`Player.cast_ability()`). Clicking an enemy still works.

## Dash
- Space calls `DashComponent.try_dash()` from PlayerInput.
- 128 px (`dash_distance` = 400 u) over `dash_duration` = 0.18 s, bursting and then easing out (`dash_curve`, F2), through `MovementComponent.dash()` (passes through units; `move_and_slide()`, so it slides along walls instead of stopping, and only a near-head-on dash stops).
- Direction: the held input direction; with no input, `facing`.
- I-frames for the whole dash via `Unit.add_invulnerability(&"dash")`: `take_damage()` and Hurtbox hits (damage and knockback) are ignored. This sits on Unit, not only the Hurtbox, because enemy basic attacks call `take_damage()` directly. The body turns half see-through.
- Charges: `UnitStats.dash_charges` (default 1). One charge returns every `charge_recharge_time` = 0.35 s, one at a time, counted only while not dashing.
- Exit: if a direction is held when the dash ends, the player runs on at full speed (`carry_into_run`, F2). Otherwise `end_lag` = 0.05 s of locked walking follows. A dash can chain in during end-lag if a charge is left.
- Not allowed while stunned or already displaced (dashing, knockback), or while casting unless the ability is `dash_cancelable` (then the dash cancels the cast). A press that isn't allowed is buffered (see below). Starting a dash cancels a basic attack windup and a queued walk-into-range cast.
- Crosses pits (step 8). Ending over a pit follows the fall rule in WORLD_INTERACTION.md, Pits and movement types *(proposed: 8 px or more inside falls, less snaps back; the player takes 5% of max health, min 1 left, and respawns on the last safe tile)*.

## Input buffering and cancels
- **Buffer** (`PlayerInput`, `buffer_time` = 0.15 s): a `dash`, `attack` or Q/W/E/R press that isn't allowed yet fires as soon as it is.
  - One buffered press at a time; a newer press replaces an older one.
  - The timer pauses while a dash or a cast is playing out, so a press during one fires the moment it ends. It doesn't pause for stuns or cooldowns.
  - When a press is allowed: dash = `DashComponent.can_dash()`. Ability = `can_cast(slot)` and not dashing (no casting mid-dash). Attack = not stunned, casting or dashing.
  - Q/W/E/R go through `Player.request_cast(slot)`: cast now if allowed, otherwise buffer.
- **Dash cancels:** attack recovery (backswing) never locks movement, so a dash already cancels it. Each ability decides whether a dash cancels its cast time with `Ability.dash_cancelable` (default off for all Knight abilities). A cancelled cast releases its locks at once, refunds the cooldown, and emits `AbilityComponent.cast_cancelled` then `cast_finished`. The effect (`execute()`) can't be cancelled once it starts.
- **Dash-strike hook:** when an `attack` press fires, PlayerInput emits `attack_pressed(dash_strike)`. `dash_strike` is true if it's within `dash_strike_window` = 0.1 s after a dash ended (`DashComponent.get_time_since_dash_end()`). An attack pressed mid-dash fires as the dash ends, so it counts. Nothing listens yet; COMBAT.md hooks in.

## Architecture (additive: see the Change policy in CLAUDE.md)
1. **PlayerInput** (child of Player, runs before MovementComponent): each physics frame produces `move_dir` and `aim_point`, calls `movement.set_input_direction()`, and runs the input buffer (dash, attack, buffered Q/W/E/R). Holding a direction or dashing cancels a queued walk-into-range cast (like a LoL move order). player.gd's `_unhandled_input` still reads Q/W/E/R and calls `request_cast()`.
2. **MovementComponent** (shared; additions only):
   - `set_input_direction(dir)`: speed ramps over `input_accel_time` / `input_decel_time`, direction changes instantly. A non-zero direction cancels any `move_to()` order.
   - `use_steering` (the player sets it false). Not `avoidance_enabled`: that flag also makes other units ignore this one, so slimes would stop steering around the player. `use_steering = false` only skips this unit's own steering.
   - Soft cap exports (see Speed and soft caps).
   - Walls: diagonal input slides along a wall at close to full speed (Godot's floating-mode slide). Input within 15° of straight into a wall doesn't slide (Godot's default `wall_min_slide_angle`, kept: at 0° near-head-on pushes shot sideways). With 8-way keys this only shows on rounded corners.
   - Displacements follow a progress curve (F2): `displace(velocity, duration, curve = null)` (null = `knockback_curve`), `dash(velocity, duration, ghosted = true, curve = null)` (null = constant speed), `set_input_speed_to_max()`.
   - **Priority: displacement > move lock > walking.** A displacement runs even while a move lock is held (knockback moves a stunned unit; Lunge moves during its own cast lock). New movement methods (`blink`, `pull_to`, `orbit`...) follow the same order.
3. **Player states** (`Player.State`): worked out every physics frame from the components, highest priority first. They describe what's happening; the components still drive behavior. `Player.state`, `is_in_state()`, `state_changed(from, to)`; `debug_draw` on the Player shows the state name.

   | State | When |
   |---|---|
   | `STUNNED` | `is_stunned()` |
   | `DASH` | the player's own dash (`DashComponent`) |
   | `CASTING` | `abilities.casting`, including Lunge's dash and R's cast. Instant casts (Iron Resolve) don't show. |
   | `DISPLACED` | pushed by something else (knockback, pull). Added beyond the original list. |
   | `ATTACK` | basic attack windup (dormant until COMBAT) |
   | `MOVE` | walking or holding a direction; also R walking into range |
   | `IDLE` | none of the above |

   While dead, the state stops updating.
4. **Camera** (`game_camera.gd`; aim lead reworked in F4): while locked, the camera leans toward the cursor, but only once the cursor leaves a dead zone.
   - **Target lean:** zero inside `aim_lead_dead_zone` = 0.35 of the half-screen (an oval: x and y each divided by their own half-size). From there to `aim_lead_full_at` = 0.9 it follows `aim_lead_curve` (`curve_camera_lead.tres`, linear: the lean grows evenly with distance). Full lean is `aim_lead` = 80 px sideways and 80 × `aim_lead_y_scale` (0.6) = 48 px vertically (while not aiming: 40 px / 24 px). After play testing, `aim_lead` went 64 → 80 px, the curve ease-in quad → linear, and the idle scale 0.3 → 0.5.
   - **Context:** full lean while the player aims (`aiming_slot`), casts (CASTING) or winds up a basic attack (ATTACK), and for `aim_lead_hold_time` = 0.75 s after; otherwise × `aim_lead_idle_scale` = 0.5. Read through Player's public state; the camera only knows its `target`.
   - **Easing:** the lean eases toward its target at `aim_lead_smoothing` = 4.0 per second (frame-rate independent, real time so hitstop doesn't freeze it). The follow smoothing stays at 10 and also acts on the lean, so a full swing settles in about 0.7 s.
   - `move_lead_px` = 0 (off): an optional extra lean in the walking direction, eased the same way.
   - `get_aim_lead()` returns the target lean (dead zone and curve, before context and easing); `get_current_lead()` returns the eased lean.
   - Holding C centers with no lean and resets it; `snap_to_target()` resets it too. Room bounds still clamp, so there's no sideways lean near a room's left or right edge. The camera runs in physics process mode because physics interpolation is on (F1).
   - `debug_draw` on the Camera: the dead zone oval (white), the target lean (yellow) and the current lean (green).
5. **Signals:** `Player.state_changed(from, to)`; `DashComponent.dash_started(direction)`, `dash_ended`, `charges_changed(charges, max)` (`debug_draw` on DashComponent shows charge pips); `PlayerInput.attack_pressed(dash_strike)`; `AbilityComponent.cast_cancelled(slot, ability)`. Planned: `fell_in_pit` (step 8).

## Feel pass
Movement works but feels robotic: displacements run at constant speed and there's no on-screen feedback. Goal: closer to Hades. Dashes and knockback burst and then ease out, frames are smooth, and movement has visible weight. Every number here is a starting point and must be an `@export` or live in a .tres. Runs before step 8 (see Build order). For every F step, the Knight's 4 abilities, enemies chasing, and the HUD still work.

### F1: Smooth frames
- **Problem:** physics runs at 60 Hz with no physics interpolation, `snap_2d_transforms_to_pixel` is on, and the camera uses position smoothing (speed 10). At 179 px/s the player moves about 3 px per tick, which stutters, especially on monitors above 60 Hz.
- **Scope:** investigate and recommend one option among 2D physics interpolation, the camera's process callback, the physics tick rate, and pixel snapping.
- **Done means:** walking along the sandbox's long wall and dashing back and forth show no visible stutter at 60 Hz or at Ryan's monitor refresh rate (144 Hz), and the pixel art stays crisp.
- **Built** (awaiting play test):
  - `project.godot`: `physics/common/physics_interpolation` on; `rendering/2d/snap/snap_2d_transforms_to_pixel` off. Physics stays at 60 Hz. (Godot turns `physics_jitter_fix` off by itself when interpolation is on.)
  - Camera: `process_callback` = Physics on the Camera node in `main.tscn`. Godot forces this when interpolation is on and prints a warning otherwise. The follow logic in `game_camera.gd` stays in `_process`; moving it to `_physics_process` measured no smoother.
  - `GameCamera.snap_to_target()` calls `reset_physics_interpolation()` before `reset_smoothing()`, and again after the first physics tick. Without it the camera slides in from the top-left corner at every scene start.
  - **Teleports:** anything that moves a node instantly (respawn, blink) must call `reset_physics_interpolation()` on it, or it visibly slides to the new spot.
  - Measured with Godot's movie recorder, walking at full speed (on-screen shake of the player, screen px; 2 screen px = 1 game px): before 5.4 at 144 fps (the player moved on only 42% of frames); after 0.04 at 60, 75, 144, 165 and 240 fps. The world scrolls with about 0.2–0.9 px of unevenness, which is rounding to whole screen pixels. Keeping snapping on with interpolation left a 0.86 px shake at 144 fps.
  - Sprites can now sit half a game pixel off the tile grid. They stay sharp (nearest filtering; no blended colors in test captures).
  - Known limit: the screen shows each physics state up to one tick (≤16.7 ms) later than before.

### F2: Displacement curves (ease out instead of constant speed)
- **MovementComponent:** a displacement follows a progress `Curve` (x = time 0–1, y = share of the distance covered 0–1). Each physics frame it moves `total_offset × (p(now) − p(previous frame))` through `move_and_slide()`. The total distance stays exactly velocity × duration, so current distances don't change; only the speed profile does.
- **Additive API:** an optional `curve: Curve = null` parameter on `displace()` and `dash()`. `null` = linear, today's behavior.
- **Curves** are .tres files in `data/curves/` (`curve_dash.tres`, `curve_knockback.tres`), editable in the Inspector's curve editor. Starting shapes: dash = ease-out quad (peak speed about 2× average, roughly 1420 px/s on the first frame, easing to 0); knockback = ease-out cubic (hard burst, fast settle).
- **Knockback default:** MovementComponent gets a `knockback_curve` export, used when `displace()` is called without a curve. The F2 plan lists which existing callers that changes.
- **Lunge:** a curve export on its Ability, set to `curve_dash.tres`. The F2 plan says whether Lunge's hit logic depends on constant speed.
- **Dash exit:** a `carry_into_run` export on DashComponent (default true). If a direction is held when the dash ends, walking starts at full speed instead of ramping up from 0. The F2 plan recommends how this interacts with `end_lag` (0.05 s of locked walking after a dash).
- **Debug:** `debug_draw` on MovementComponent draws a graph of the last 1 s of speed (px/s) above the unit.
- Stuns, walls and `displacement_finished` behave exactly as they do now.
- **Done means:** the dash still covers exactly 128 px (the cracked tiles); the speed graph shows a burst and then an ease-out; there's no visible pause between the dash and running; knockback on slimes bursts and then settles.
- **Built** (awaiting play test):
  - `null` means different things on the two methods: `dash(..., curve = null)` = constant speed; `displace(..., curve = null)` = `knockback_curve`. So knockback eases by default and existing dash callers can opt in.
  - Progress is normalized (`(p(t) − p(0)) / (p(1) − p(0))`), so a hand-edited curve that doesn't run exactly 0 → 1 still covers the full distance.
  - Defaults are set in the scripts, so every unit gets them: `MovementComponent.knockback_curve` = `curve_knockback.tres` (ease-out cubic), `DashComponent.dash_curve` = `curve_dash.tres` (ease-out quad). Lunge's `dash_curve` is set in `knight_e_lunge.tres`.
  - Callers whose speed profile changes: Cleave's knockback (`cleave.gd`, 17 px over 0.1 s) and Hurtbox knockback (`Unit._on_hurtbox_hurt`, no Hitbox uses it yet) now use `knockback_curve`. The dash and Lunge use `curve_dash`. Distances are unchanged.
  - Lunge's hits don't depend on its speed: they're found along the segment from the start point to the end point after the dash. Only its afterimages (spawned every 2 physics frames) now bunch toward the slow end.
  - **Dash exit:** if a direction is held when the dash ends, walking starts at full speed and `end_lag` is skipped. If no direction is held, `end_lag` (0.05 s) still locks walking, which plants the stop.
  - **Speed graph:** `debug_draw` on MovementComponent draws the actual distance moved per physics frame (so walls show), over `debug_graph_time` = 1 s, scaled to `debug_graph_max_speed_px` = 1500 px/s.
  - Measured: the dash covers 128.0 px in 11 frames at 1356 → 1225 → 1093 → … → 171 → 42 px/s, then runs on at 179 px/s the very next frame. Cleave knocks a dummy 17 px at 407 → 269 → 160 → 79 → 27 → 3 px/s. Lunge still covers 128 px and hits. A dash into the pillar stops exactly as before.

### F4: Camera aim lead rework (runs before F3)
- **Problem (play testing):** the locked camera moves too much when the cursor moves. The lead should help aim at enemies slightly off screen, not follow every mouse movement. Causes in the current code:
  - No dead zone: any cursor movement shifts the camera.
  - The lead is 64 px on both axes, but the screen is 640×360, so vertically it's over a third of the half-screen.
  - The lead uses the same position smoothing (10) as the player follow, so it can't be slower without making the follow laggy.
  - The lead is measured in screen space, so when the camera leans, the world point under a still cursor slides.
- **Changes** (all `@export` on GameCamera, additive; `aim_lead` keeps its name and meaning as the horizontal maximum):
  1. **Dead zone:** no lead while the cursor is inside `aim_lead_dead_zone` = 0.35 of the half-screen, measured as an oval (x and y each divided by their own half-size).
  2. **Response:** from the dead zone edge to `aim_lead_full_at` = 0.9, the lead follows a Curve (`data/curves/curve_camera_lead.tres`, ease-in quad). Full lead beyond that.
  3. `aim_lead_y_scale` = 0.6 for the vertical lead.
  4. The lead eases toward its target at its own rate, `aim_lead_smoothing` = 4.0 per second (frame-rate independent). The follow smoothing stays at 10.
  5. **Context:** full lead while the player is aiming or casting an ability (and in ATTACK once COMBAT exists); `aim_lead_idle_scale` = 0.3 otherwise. Read through the Player's public state (`Player.state` / `is_in_state()`, `aiming_slot`). No new coupling beyond the camera's existing target.
  6. `move_lead_px` = 0 (off): an optional lean in the walking direction, blended the same way. Try 12–16.
  - Holding C still centers with no lead. Shake, bounds and `snap_to_target()` behave as now.
  - `debug_draw` on GameCamera: the dead zone oval, the target lead, and the current lead.
- **Done means:**
  - Moving the cursor inside the dead zone doesn't move the camera.
  - Flicking the cursor corner to corner moves the camera over about half a second, with no whip.
  - Walking without aiming barely leans; holding an aimed ability toward an off-screen dummy leans fully.
  - F1 smoothness is unchanged (no new stutter).
  - The Knight's abilities, enemies chasing and the HUD still work.
- **Built** (awaiting play test). Additions agreed with Ryan: `aim_lead_hold_time` = 0.75 s (full lean stays this long after the last aim or cast, so it doesn't swing back between casts, and so QUICK cast mode still gets it); `aim_lead_smoothing` stays 4.0.
- **Aim drift (accepted):** the world under a still cursor still slides whenever the lean changes. Full lean starts when you begin aiming, so while you hold an ability still, the spot under the cursor can move up to 80 px sideways / 48 px vertically over about 0.7 s (64 / 38 px when first measured), and a POINT ability like Lunge lands where the cursor is at release. Accepted because the indicator always shows the true landing spot (clarity), and the lean only grows outside the dead zone and while aiming. Revisit if play testing shows mis-aims.
- Measured at 144 fps with `aim_lead` = 64 px, before it was raised to 80 (camera movement = how far the world under a still cursor slides, game px; lean amounts now scale by 80/64 = 1.25, timings don't change):

  | Test | Today | F4 idle | F4 aiming |
  |---|---|---|---|
  | Cursor center → right edge, held still | 64 px, 90% in 0.23 s, peak 648 px/s | 19 px, 0.69 s, 72 px/s | 64 px, 0.68 s, 144 px/s |
  | Cursor center → bottom edge | 64 px, 0.22 s | 11.5 px, 0.67 s | 38 px, 0.68 s |
  | Small moves inside the dead zone | 12–16 px each | 0 | 0 |
  | Flick corner to corner | 128 px diagonal, 0.22 s, peak 1274 px/s | 31 px, 0.68 s | 105 px, 0.69 s, peak 260 px/s |
  | Walking shake (F1 metric) | 0.03 px | 0.03 px | – |

### F3: Movement feedback (VFX only, never changes gameplay state)
- **Dash:** stretch the Body along the dash direction (1.25 × 0.8) for 0.06 s, then ease back; squash it slightly (0.9 × 1.1) for 0.05 s when the dash ends; spawn 3–4 afterimages about 0.03 s apart, each fading over 0.15 s; a small dust puff at the start.
- **Walking:** a 1 px bob at a rate tied to speed, and a dust puff on a sharp direction reversal (more than 135°).
- **Knockback:** any displaced unit stretches along the push direction, scaled by its current speed.
- **Structure:** one reusable node in `scripts/vfx/`, named per CONVENTIONS. It listens to MovementComponent and DashComponent signals, has an on/off toggle, and exports every value. It must work on today's Polygon2D placeholders and on 8-direction sprites later. The F3 plan says whether pixel snapping makes the squash look jittery at 640×360.
- **Done means:** the effects are visible but never hide where the player actually is, and turning the toggle off gives exactly today's visuals.

## Build order (one step per request)
1. **Built** (awaiting play test): input map + WASD walking, done together (after the input map alone the player had no walk input). PlayerInput, `set_input_direction()`, `use_steering = false` on the player, Knight 560 move speed, scaled soft cap exports, LoL threshold overrides on `slime.tscn`.
2. *(merged into step 1)*
3. **Built** (awaiting play test): facing and aim.
4. **Built** (awaiting play test): camera aim lead.
5. **Built** (awaiting play test): player states.
6. **Built** (awaiting play test): dash with charges, i-frames, end-lag and chaining.
7. **Built** (awaiting play test): input buffer, dash cancels (`Ability.dash_cancelable`), and the dash-strike hook.
- **Feel pass F1 → F2 → F4 → F3** (see Feel pass) comes here, before step 8. F4 runs before F3. F1, F2 and F4 are built (awaiting play test).
8. Pit crossing and fall/respawn (needs the pit layer; spec in WORLD_INTERACTION.md, Pits and movement types, still *proposed*). The respawn is a teleport: call `reset_physics_interpolation()` on the player and snap the camera (see F1).

**Done means:** no errors; WASD works in play mode; the Knight's 4 abilities, enemies chasing, and the HUD still work as before. Exception (decided): the Knight's basic attacks stay dormant until COMBAT gives `attack` a reader.
If a step needs removing or rewriting existing code, stop and explain why before doing it.

## Testing
- `res://scenes/sandbox_main.tscn` (open it, press F6) runs `main.tscn` with `res://scenes/rooms/sandbox.tscn` as the room. room_01 stays the default game.
- Sandbox test spots: open floor (start/stop), a long wall (sliding), a single pillar, an L-corner, a diagonal stair-step wall (corner catching), a 1-tile corridor and a 2-tile gap, and two cracked floor tiles 128 px apart (dash length).
- Three passive training dummies (`Enemy.passive = true`) and two normal slimes in a pen (chase test).
- The camera can only lean sideways in the middle third of the sandbox (room bounds). `debug_draw` on the Camera node (in `main.tscn`) shows the dead zone and the lean.

## Open questions
- **`attack` vs `select` on left mouse:** both are bound to left mouse. No double-fire yet: `select` only acts while attack-move is armed (unbound A key), and `attack` only emits `attack_pressed`, which nothing listens to. Resolve in the COMBAT work. PlayerInput reads `attack` from the Input state, so a click on the ability bar also counts as an attack press; the bar's `MOUSE_FILTER_STOP` doesn't block that.
- **`cast_mode`:** hold-to-aim (`QUICK_WITH_INDICATOR`, current) vs `QUICK`. Try `QUICK` in play testing.
- Should the vertical speed be scaled (e.g. 0.9×) for the 3/4 view? Default: no.
- **Movement during basic attacks** (root, slow, or a step forward) and **during casts** (slow %). Decided in COMBAT.
- **Reacting to being hit:** knockback distance, and how long the player loses control. Decided in COMBAT.
- *(proposed)* Corner forgiveness: 6 px side tolerance, nudge at walk speed (see Target feel).
- *(proposed)* Pit falls for the dash: see WORLD_INTERACTION.md, Pits and movement types.
- **Aim zoom (parked until the first long-range champion):** while aiming an ability, zoom out just enough to show its full range, keeping the cursor lean as is. The Knight's ranges (96–180 px) already fit on screen, so it would barely show today. Costs to weigh then: a zoom between 1.0 and 0.5 draws art pixels at uneven sizes (at 0.8 they're 1.6 screen px), and zooming around the screen center moves the world under a still cursor (about 36 px at the edge at 0.9, 80 px at 0.8) unless it zooms around the cursor. Alternative with neither cost: while aiming, lean just far enough that the ability's full range is on screen.
