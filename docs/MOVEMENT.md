# MOVEMENT.md: Player Movement (Hades-style)

**Read when:** the task involves player movement, dash, input, the input map, buffering, facing/aim, camera follow, or the LoL-era systems that WASD replaced.
**Depends on:** CLAUDE.md (change policy).
**Used by:** abilities (movement methods), COMBAT.md (locks, slows, knockback, i-frames, the buffer during swings), WORLD_INTERACTION.md, ARCHETYPES.md (the Assassin's dash and its deflect window).
**Synced 2026-10-07 with ARCHETYPES.md** (the Assassin's dash, the deflect window, the rebuffed attack lock).

## Current code
| File | Role |
|---|---|
| `res://scripts/components/movement_component.gd` | Shared by all Units. Enemies walk with `move_to()` (NavigationServer2D pathing, steering); the player with `set_input_direction()`. Move locks, speed modifiers with soft caps, `displace()`, `dash()`. Speed is the `move_speed` stat (STATS.md). `add_speed_modifier()` is a wrapper: on a unit with a StatusComponent it applies a slow or haste status (COMBAT C9); without one it adds StatModifiers and keeps the timer itself. |
| `res://scripts/player/player_input.gd` | `PlayerInput`, child of Player. Reads WASD, dash and attack each physics frame; owns the input buffer. |
| `res://scripts/components/dash_component.gd` | `DashComponent`, child of Player. The dash. PROTOTYPE additions (2026-10-07; behind `DeflectComponent.deflect_test_enabled`, off in shipped config): `add_refund_charge()`, `has_refund()`, `get_refund_left()` (a deflect's refunded charge), and `get_recharge_time()` (the deflect's 1.5 s test recharge while the flag is on, else `charge_recharge_time`). `DeflectComponent` (`res://scripts/components/deflect_component.gd`) opens its window on `dash_started` (ARCHETYPES.md, Current code). |
| `res://scripts/player/player.gd` | Q/W/E/R casting, facing and aim, player states. (The dormant LoL right-click orders were deleted 2026-09-29.) |
| `res://scripts/camera/game_camera_3d.gd` | Locked follow with aim lead; unlocked edge pan; shake; room bounds, tuned on `CameraLook` (3D.md). The 2D `game_camera.gd` did this until the 3D pivot's cleanup C1 and was deleted in C3. |
| ~~`res://scripts/vfx/movement_vfx_component.gd`~~ | `MovementVFXComponent`, the 2D movement feedback visuals (F3): off under the 3D view since the cleanup's C2, deleted in C3 (2026-10-03). The dash afterimages are `UnitView`'s (3D.md); the dust waits for the art pass. |

Visuals were Polygon2D placeholders (`Body`, `SwordPivot`) until the 3D pivot's cleanup C3 deleted them. ~~The plan is 8-direction sprites.~~ With the 3D view each unit gets a model that turns smoothly to its facing (3D.md; Ryan, Q6, confirmed in P0b 2026-10-02).

**Player size** (`player.tscn`, `knight.tres`):
- Collider: `CircleShape2D`, radius **11 px** (22 px wide), centered on the feet (the Player's origin). Set in the scene, not from stats. Collision layer 2, mask 7 (world, player, enemies).
- `gameplay_radius` = 65 u ≈ 20.8 px: ranges, clicking on the unit, the hover ring. `pathing_radius` = 35 u ≈ 11.2 px: `MovementComponent.radius_px` (steering).
- A 1-tile corridor is **32 px** wide, which leaves 5 px on each side of the collider.

## Target feel
Instant and precise, never floaty. The player steers directly with almost no momentum. Treat the numbers as starting points.

| Property | Value |
|---|---|
| Move speed | **375 LoL units = 120 px/s** (Knight, `knight.tres`; 560 until 2026-09-28). See Speed and soft caps. |
| Time to full speed | 0.05 s (`input_accel_time`) |
| Time to stop | 0.04 s (`input_decel_time`), no visible slide |
| Direction change | instant, no turn-around slowdown |
| Diagonals | input vector normalized |
| Walls | slide smoothly, never catch on tile corners |
| Other units | the player collides but is **never steered or pushed aside**; steering stays for enemies ("deflect" is the Assassin's mechanic since 2026-10-07: ARCHETYPES.md) |
| Slopes | **don't change speed**: the sim is flat, so a ramp takes as long as the same map distance on flat floor (League's rule; 3D.md) |

**Corner forgiveness** *(proposed, build later)*: while walking, if a tile corner blocks the player by 6 px or less on the side, nudge them around it at walk speed.

## Input and legacy systems
### Input map
Only keys that physically collided with WASD changed. Action names never change. Keyboard and mouse only for now; no gamepad.

| Action | Key | Notes |
|---|---|---|
| `move_up` / `move_down` / `move_left` / `move_right` | W / S / A / D | new |
| `dash` | Space | new |
| `attack` | Left mouse | new; the basic attack combo (COMBAT.md) |
| `interact` | F | new; nothing reads it yet |
| `ability_q` / `ability_e` / `ability_r` | Q / E / R | unchanged |
| `ability_w` | Right mouse | was W |
| `camera_center` | C | was Space |
| `restart`, `camera_toggle_lock`, `camera_left/right/up/down` | Backspace, Y, arrow keys | unchanged |
| `ability_companion` | Tab | planned (COMPANIONS.md, CO3): the companion's command, the fifth ability slot. Tab was unbound (checked 2026-10-03). Godot's built-in `ui_focus_next` also uses Tab, only to move focus in menus; CO3 checks that Alt+Tab never casts the command |

The LoL actions `move` / `stop` / `attack_move` (were right mouse / S / A) and `select` (was left mouse, unbound since COMBAT C2) were deleted 2026-09-29, with their code (LoL-era systems, below).

### LoL-era systems
| System | Status |
|---|---|
| `MovementComponent.move_to()` pathing and steering | Kept. Enemies use it, and so does R walking the Knight into range. |
| `player.gd` right-click move, attack-move, stop, select; `AutoAttackComponent.attack_move()` | Deleted 2026-09-29 (dormant since step 1; movement steps passed Ryan's play test). |
| `click_marker.gd` and main.gd's marker wiring | Deleted 2026-09-29 with right-click move. |
| `player.gd` League-style windup handlers (sword pull-back and slash on `windup_started` / `attack_landed`, the ATTACK state and facing from a League windup) | Deleted 2026-09-29: dormant since COMBAT C2 (the Knight only swings the combo). `Player.State.ATTACK` is the rooted combo swing only. |
| `game_camera.gd` lock toggle, edge pan, shake, bounds | Kept. Aim lead added (Architecture, 4). Replaced by `GameCamera3D` in the 3D pivot's cleanup C1, deleted in C3 (2026-10-03). |
| `AbilityComponent` Q/W/E/R slots | Unchanged. W is on right mouse. |
| Aim cancel (`player.gd`) | Right mouse used to cancel an aimed ability; it now casts W. Esc (`ui_cancel`) cancels. Esc while not aiming opens the pause menu (`main.gd`, `PauseMenu`); an Esc that cancels an aim is marked handled, so it doesn't also pause. |
| `AutoAttackComponent` | Kept. Enemies use its League-style attack. The Knight uses its combo mode (COMBAT C2): left mouse swings toward the cursor. The Knight's League-style orders (right-click, A-click) were deleted 2026-09-29. |
| `enemy.gd` | Kept. `passive` export turns an enemy into a training dummy: no wander, aggro, or attacks. |
| `Ability.get_damage()` | Kept. Reads the caster's StatsComponent (`get_stat()`, scoped params) since STATS step 4; now `get_damage_against(caster, null)` (ABILITIES.md). |

## Speed and soft caps
- The Knight's base `move_speed` is **375** (Ryan, 2026-09-28; it was 560, and 345 before that).
- The soft cap thresholds were scaled for 560 (560 / 345 ≈ 1.623) and stay as they are with the Knight at 375 (Ryan, 2026-09-28: slows on the Knight are softened). They are `@export`s on `MovementComponent`:

| Export | LoL original | Scaled default | Rule |
|---|---|---|---|
| `soft_cap_low` | 220 | 357 | below: the shortfall counts ×0.5 |
| `soft_cap_high` | 415 | 674 | above: the excess counts ×0.8 |
| `soft_cap_max` | 490 | 795 | above: the excess counts ×0.5 |

- Computed as "threshold + excess × factor", so the curve is continuous for any thresholds; the LoL originals give exactly the old numbers. `get_move_speed()` uses the exports; the static `apply_soft_caps()` stays as the LoL reference.
- Examples: Knight 375 → 375 (120 px/s). With Iron Resolve (+35%): 506.25, inside the caps (162 px/s). A 30% slow: raw 262.5 is under the low cap, so it ends at 309.75 (99 px/s): at 375 every slow is softened.
- **Slimes keep the LoL thresholds** (220 / 415 / 490) as overrides in `slime.tscn`, so they move exactly as before (the scaled low cap would lift 285 to 321). Enemy speeds get retuned in ENEMIES_AI.md.

## Facing and aim
- Units don't rotate. `Player.facing` (unit vector) is the look direction. The 3D view turns the model smoothly toward it (3D.md, `UnitView`); `get_facing_octant()` (0 = right, clockwise: 2 = down, 4 = left, 6 = up) stays for code that wants 8 steps.
- Facing priority, updated each physics frame:
  1. **Casting:** toward the cast's aim, locked at cast start (DIRECTION/POINT: the aim point; UNIT: the target). SELF casts don't change facing.
  2. **Attacking:** a combo swing's aim, locked at swing start, while the swing roots (COMBAT C2).
  3. **Dashing:** the dash direction.
  4. **Aiming an ability** (hold-to-aim): toward the cursor. (The 2D sword followed it too, until the 3D pivot's cleanup C3.)
  5. **Walking:** the move direction.
  6. **Standing still:** keeps the last facing.
- `Player.get_aim_point()` = `get_global_mouse_position()`. `Player.get_aim_direction()` is the unit vector from the player's feet (where abilities cast from) to it, or `facing` when the cursor is on the player.
- **With the 3D view (3D.md, P5):** `get_aim_point()` returns the floor pick (the walkable ground under the cursor), or an enemy's feet when the cursor is over its model; without a view (every test) it stays the mouse. The 10 direct mouse calls in `player.gd` go through it (approved 2026-10-01). Built in P5 (2026-10-02, see CHANGELOG.md); past the walkable ground (the void, a wall cell) the aim is the ray's point on the floor plane, so it still points the cursor's way.
- UNIT abilities also accept the enemy nearest the cursor within `target_forgiveness` (`Player.cast_ability()`). Clicking an enemy still works.

## Dash
- Space calls `DashComponent.try_dash()` from PlayerInput.
- 128 px (`dash_distance` = 400 u, 4 m in the 3D view) over `dash_duration` = 0.18 s, bursting and then easing out (`dash_curve`, F2), through `MovementComponent.dash()` (passes through units; `move_and_slide()`, so it slides along walls instead of stopping, and only a near-head-on dash stops).
- **Cliffs stop it, fences don't** (3D.md, built in P9: `MovementComponent.GHOST_KEEP_MASK`): the ghosted dash masks walls and ledges (`collision_mask & (1 | 1024)`; layer 11 `ledge`), so it stops at a cliff edge but still crosses fences, rubble and pits (Ryan, 2026-10-01).
- Direction: toward the cursor at the moment Space is pressed (`Player.get_aim_direction()`). A buffered dash keeps the direction from its press, even if the cursor moves before it fires. `PlayerInput.dash_toward_cursor = false` brings back the old rule: the held input direction, or `facing` with no input (DECISIONS.md, 2026-09-26).
- **The player chooses** between the two in the Esc pause menu ("Dash direction: Cursor / Move keys (WASD)"; default Cursor). The choice lives in `Settings` (`get_dash_direction()`, `DashDirection.CURSOR` / `MOVE_KEYS`), is saved to `user://settings.cfg`, and applies at once, even mid-run: PlayerInput copies it into `dash_toward_cursor` at start and on `Settings.setting_changed`, so an Inspector value there only lasts until then.
- The run-on after the dash (`carry_into_run`) still follows the held WASD direction, so dashing one way while holding another runs off in the held direction.
- I-frames for the whole dash via `Unit.add_invulnerability(&"dash")`: every hit is blocked in `Unit.on_hit()` (damage, knockback, statuses, on-hit), Hurtbox hits and `take_damage()` included. This sits on Unit, not only the Hurtbox, because enemy basic attacks and abilities don't use a Hurtbox (they go through the hit pipeline). The body turns half see-through.
- Charges: the `dash_charges` stat (base `UnitStats.dash_charges`, default 1, read through StatsComponent). One charge returns every `charge_recharge_time` = 0.35 s, one at a time, counted only while not dashing.
- **The Assassin's dash** (ARCHETYPES.md, Assassin; Ryan, 2026-10-07; planned, built for Korsavil in ARCHETYPES AR5): one charge, 25% longer (500 u = 160 px over the same 0.18 s), recharging in **1.2 s** (tuned between 0.8 and 1.5 s in AR5). The Knight keeps 0.35 s: an Assassin's recharge must be well above it, or a whiffed dash would cost nothing. From its start the dash opens a **deflect window** of 0.2 s, a timer of its own beside the i-frames: a deflectable enemy hit inside it is deflected instead of only dodged, and the first deflect of a streak gives the charge back for 3 s (the refund). Everything else about the dash is unchanged (i-frames for its whole length, the curve, the cancels). Korsavil's second charge (her passive's +1 `dash_charges`, CHAMPIONS.md) goes (D11).
  - *Today (PROTOTYPE, 2026-10-07):* the window is 0.15 s on the Knight's dash, behind `DeflectComponent.deflect_test_enabled` (off in shipped config), which also sets the 1.5 s test recharge; it goes for the Knight in AR6 (disabled, not deleted).
- Exit: if a direction is held when the dash ends, the player runs on at full speed (`carry_into_run`, default true) and `end_lag` is skipped. Otherwise `end_lag` = 0.05 s of locked walking follows, which plants the stop. A dash can chain in during end-lag if a charge is left.
- Not allowed (`DashComponent.can_dash()`) while dead, dash-blocked (stunned, or a status with `blocks_dash` such as a root; `Unit.is_dash_blocked()`), already dashing, out of charges, or displaced (knockback, pulls, Lunge's own dash). Exception: a dash-cancelable displacement (a melee swing step; knockback from being hit, COMBAT C4) doesn't block the dash; the dash replaces it. While casting (a charge-up or a vector aim included), only during the cast time and only if the ability is `dash_cancelable` (then the dash cancels the cast); never once `execute()` has started. A press that isn't allowed is buffered. Starting a dash cancels a basic attack swing (windup: the combo resets; recovery, after the hit: the combo moves on, COMBAT.md; the hit itself happens inside one frame) and cancels a queued walk-into-range cast.
- Pits: not scheduled (step 8 was removed 2026-09-25). If they come back, the dash crosses them and the fall rule is in WORLD_INTERACTION.md, Pits and movement types (approved 2026-09-30, with every displacement ignoring the pit layer while it runs).

## Input buffering and cancels
- **Buffer** (`PlayerInput`, `buffer_time` = 0.15 s): a `dash`, `attack` or Q/W/E/R press that isn't allowed yet fires as soon as it is.
  - One buffered press at a time; a newer press replaces an older one.
  - The timer pauses while a dash, a cast, a basic attack swing or a swing's breather (`pause_after`, COMBAT.md) is playing out, so a press during one fires the moment it ends (a click early in a swing queues the next swing; a click in the finisher's breather fires when it ends). It doesn't pause for stuns or cooldowns.
  - When a press is allowed: dash = `DashComponent.can_dash()`. Ability = `can_cast(slot)` and not dashing (no casting mid-dash). Attack = not stunned, casting or dashing, and `AutoAttackComponent.can_swing()` (not swinging, not in a breather, no attack lock). An ability during a swing only if its `cancels_swing` allows it right now (`Player.can_interrupt_swing()`; COMBAT.md).
  - Q/W/E/R go through `Player.request_cast(slot)`: cast now if allowed, otherwise buffer.
- **Rebuffed** (ARCHETYPES.md, Rebuffed; Ryan, 2026-10-07; planned, ARCHETYPES AR3): when an enemy Assassin's Riposte Stance deflects a champion's swing, the swing is cancelled, the combo goes back to swing 1, and attacking is locked for 0.4 s (`status_rebuffed`, not `cc`). Dashing, moving and casting stay allowed. *(proposed)* The buffer treats it like any attack lock: it doesn't pause for it, so an attack pressed in the lock's last 0.15 s fires when it ends.
- **Dash cancels:** every basic attack swing roots for its whole duration (move lock `&"attack_swing"`), and a dash cancels it in its windup or its recovery; after the swing's hit has landed the combo moves on instead of resetting (COMBAT.md, Basic attack). Each ability decides whether a dash cancels its cast time with `Ability.dash_cancelable` (default off for all Knight abilities). A cancelled cast releases its locks at once, refunds the cooldown, and emits `AbilityComponent.cast_cancelled` then `cast_finished`. The effect (`execute()`) can't be cancelled once it starts.
- **Basic attack swings** (COMBAT.md, Melee basic attacks): a swing roots, but a melee swing steps forward (or is pulled toward an aimed enemy) during its windup, and after the hit a movement press or held direction ends the root once `recovery_move_cancel_after` (0.1 s) has passed. The swing still runs out its duration, so the next swing waits.
- **Movement during casts** (`roots_during_cast`, `cast_move_speed_multiplier`, `cancel_on_move`, `dash_cancelable`, `cancels_swing`): moved to ABILITIES.md, Rules, Movement during casts.
- **Dash-strike hook:** when an `attack` press fires, PlayerInput emits `attack_pressed(dash_strike)`. `dash_strike` is true within `dash_strike_window` = 0.15 s after a dash ended (`DashComponent.get_time_since_dash_end()`; COMBAT C12). An attack pressed mid-dash fires as the dash ends, so it counts. PlayerInput then calls `AutoAttackComponent.try_swing(aim, dash_strike)`; the dash-strike swing is COMBAT.md's.

## Architecture (additive: see the Change policy in CLAUDE.md)
1. **PlayerInput** (child of Player, runs before MovementComponent): each physics frame produces `move_dir` and `aim_point`, calls `movement.set_input_direction()`, and runs the input buffer (dash, attack, buffered Q/W/E/R). Holding a direction, dashing or attacking (a swing that starts, COMBAT C2) cancels a queued walk-into-range cast (like a LoL move order). player.gd's `_unhandled_input` still reads Q/W/E/R and calls `request_cast()`.
2. **MovementComponent** (shared; additions only):
   - `set_input_direction(dir)`: speed ramps over `input_accel_time` / `input_decel_time`, direction changes instantly. A non-zero direction cancels any `move_to()` order.
   - `use_steering` (the player sets it false). Not `avoidance_enabled`: that flag also makes other units ignore this one, so slimes would stop steering around the player. `use_steering = false` only skips this unit's own steering.
   - Walls: diagonal input slides along a wall at close to full speed (Godot's floating-mode slide). Input within 15° of straight into a wall doesn't slide (Godot's default `wall_min_slide_angle`, kept: at 0° near-head-on pushes shot sideways). With 8-way keys this only shows on rounded corners.
   - `displace()` and `dash()` take an optional progress curve (F2); `displace()` also takes `dash_cancelable` (the unit may dash out of it, COMBAT.md). `set_input_speed_to_max()`.
   - **Priority: displacement > move lock > walking.** A displacement runs even while a move lock is held (knockback moves a stunned unit; Lunge moves during its own cast lock). New movement methods (`blink`, `pull_to`, `orbit`...) follow the same order.
3. **Player states** (`Player.State`): worked out every physics frame from the components, highest priority first. They describe what's happening; the components still drive behavior. `Player.state`, `is_in_state()`, `state_changed(from, to)`; `debug_draw` on the Player shows the state name.

   | State | When |
   |---|---|
   | `STUNNED` | `is_stunned()` |
   | `DASH` | the player's own dash (`DashComponent`) |
   | `CASTING` | `abilities.casting`, including Lunge's dash and R's cast. Instant casts (Iron Resolve) don't show. |
   | `ATTACK` | a basic attack swing while it roots (windup and recovery). Ranked above DISPLACED, because a melee swing's step is a displacement. Once walking ends the recovery early, the state is MOVE. |
   | `DISPLACED` | pushed by something else (knockback, pull). |
   | `MOVE` | walking or holding a direction; also R walking into range |
   | `IDLE` | none of the above |

   While dead, the state stops updating.
4. **Camera** (`game_camera.gd`, since the 3D pivot's cleanup C1 `game_camera_3d.gd`; aim lead reworked in F4): while locked, the camera leans toward the cursor, but only once the cursor leaves a dead zone.
   - **In 3D (3D.md, P4):** `GameCamera3D` shows the game through a fixed-angle camera: perspective, 30° field of view, 50° pitch, 28 m wide (`CameraLook`; Ryan after P0b, 2026-10-02). Everything below carries over: the lean is measured in screen space, so the same share of the screen moves the 3D focus; lock, centering, edge pan, bounds, shake and `snap_to_target()` work as here. North–south distances look 23% shorter than east–west at 50° (accepted, Q11). Built in P4 (2026-10-02, see CHANGELOG.md). `GameCamera3D` reads this camera's lock, lean, shake and pan settings, so they're still tuned here. Two differences:
     - **Bounds:** in 3D they keep the camera's focus on the room's floor, and the void past the walls shows near an edge (Ryan, P4). The view is about the sandbox's size, so the 2D rule below would freeze it.
     - **The lean:** it puts the Knight exactly the lean's screen px off the center, as here.
     - **Since the cleanup's C1** (2026-10-03): `GameCamera3D` computes all of this itself, and the numbers below live on `CameraLook` (`data/camera_looks/camera_look_default.tres`; Ryan's pick), the same values. Three px names gained the suffix there: `aim_lead` is `aim_lead_px`, `edge_pan_speed` is `edge_pan_speed_px`, `edge_margin` is `edge_margin_px`; `shake_decay` is `shake_decay_px`, and the follow smoothing is `follow_smoothing_speed`. `GameCamera` runs only in the 2D game (the flag off) until the cleanup's C3 deletes it.
   - **Target lean:** zero inside `aim_lead_dead_zone` = 0.35 of the half-screen (an oval: x and y each divided by their own half-size). From there to `aim_lead_full_at` = 0.9 it follows `aim_lead_curve` (`curve_camera_lead.tres`, linear). Full lean is `aim_lead` = 80 px sideways and 80 × `aim_lead_y_scale` (0.6) = 48 px vertically (while not aiming: 40 px / 24 px).
   - **Context:** full lean while the player aims (`aiming_slot`), casts (CASTING) or winds up a basic attack (ATTACK), and for `aim_lead_hold_time` = 0.75 s after; otherwise × `aim_lead_idle_scale` = 0.5. Read through Player's public state; the camera only knows its `target`.
   - **Easing:** the lean eases toward its target at `aim_lead_smoothing` = 4.0 per second (frame-rate independent, real time so hitstop doesn't freeze it). The follow smoothing stays at 10 and also acts on the lean, so a full swing settles in about 0.7 s.
   - `move_lead_px` = 0 (off): an optional extra lean in the walking direction, eased the same way.
   - `get_aim_lead()` returns the target lean (dead zone and curve, before context and easing); `get_current_lead()` returns the eased lean.
   - Holding C centers with no lean and resets it; `snap_to_target()` resets it too. Room bounds still clamp, so there's no sideways lean near a room's left or right edge. The camera runs in physics process mode because physics interpolation is on (F1).
   - **Aim drift (accepted):** the world under a still cursor slides whenever the lean changes. Full lean starts when you begin aiming, so while you hold an ability still, the spot under the cursor can move up to 80 px sideways / 48 px vertically over about 0.7 s, and a POINT ability like Lunge lands where the cursor is at release. Accepted because the indicator always shows the true landing spot (clarity), and the lean only grows outside the dead zone and while aiming. Revisit if play testing shows mis-aims.
   - `debug_draw` on the Camera: the dead zone oval (white), the target lean (yellow) and the current lean (green). In 3D: `debug_draw` on `CameraLook` draws the same on the screen.
5. **Signals:** `Player.state_changed(from, to)`; `DashComponent.dash_started(direction)`, `dash_ended`, `charges_changed(charges, max)` (`debug_draw` on DashComponent shows charge pips); `PlayerInput.attack_pressed(dash_strike)`; `AbilityComponent.cast_cancelled(slot, ability)`. `fell_in_pit` only if pits come back.

## Feel pass
Goal: closer to Hades. Dashes and knockback burst and then ease out, frames are smooth, and movement has visible weight. Every number is a starting point and must be an `@export` or live in a .tres. Built in the order F1 → F2 → F4 → F3 (2026-09-25, see CHANGELOG.md); each step's "Done means" is its pending play test. For every F step, the Knight's 4 abilities, enemies chasing and the HUD still work.

### F1: Smooth frames
- `project.godot`: `physics/common/physics_interpolation` on; `rendering/2d/snap/snap_2d_transforms_to_pixel` off. Physics stays at 60 Hz. (Godot turns `physics_jitter_fix` off by itself when interpolation is on.)
- Camera (the 2D `GameCamera`, deleted in the 3D pivot's cleanup C3; `GameCamera3D` follows in `_process` with its own interpolation off, 3D.md): `process_callback` = Physics on the Camera node in `main.tscn` (Godot forces this when interpolation is on and warns otherwise). The follow logic in `game_camera.gd` stays in `_process`.
- `GameCamera.snap_to_target()` calls `reset_physics_interpolation()` before `reset_smoothing()`, and again after the first physics tick. Without it the camera slides in from the top-left corner at every scene start.
- **Teleports:** anything that moves a node instantly (respawn, blink) must call `reset_physics_interpolation()` on it, or it visibly slides to the new spot.
- Sprites can sit half a game pixel off the tile grid. They stay sharp (nearest filtering).
- Known limit: the screen shows each physics state up to one tick (≤16.7 ms) later than without interpolation.
- **Done means:** walking along the sandbox's long wall and dashing back and forth show no visible stutter at 60 Hz or at Ryan's monitor refresh rate (144 Hz; **180 Hz** since P0a measured it, 2026-10-01: a 5.6 ms frame budget), and the pixel art stays crisp.
- **In 3D (3D.md):** the same bar. The view copies every position on the physics tick, after the sim (`WorldView`, priority 100), and 3D physics interpolation smooths it; the camera follows the player view's interpolated transform in `_process`. P0a measured it at 180 Hz with hitstop: no step back, no pop.

### F2: Displacement curves (ease out instead of constant speed)
- A displacement follows a progress `Curve` (x = time 0–1, y = share of the distance covered 0–1). Each physics frame it moves `total_offset × (p(now) − p(previous frame))` through `move_and_slide()`. The total distance stays exactly velocity × duration; only the speed profile changes.
- Progress is normalized (`(p(t) − p(0)) / (p(1) − p(0))`), so a hand-edited curve that doesn't run exactly 0 → 1 still covers the full distance.
- `curve = null` means different things: `dash(..., curve = null)` = constant speed; `displace(..., curve = null)` = `knockback_curve`. So knockback eases by default and dash callers opt in.
- **Curves** are .tres files in `data/curves/` (`curve_dash.tres`, `curve_knockback.tres`). Starting shapes: dash = ease-out quad (peak speed 2× the average: 128 px / 0.18 s = 711 px/s average, about 1422 px/s at the very start; the first physics frame averages 1356 px/s (measured, F2), easing to 0); knockback = ease-out cubic (hard burst, fast settle).
- **Defaults** set in the scripts, so every unit gets them: `MovementComponent.knockback_curve` = `curve_knockback.tres`, `DashComponent.dash_curve` = `curve_dash.tres`. Lunge's `dash_curve` is set in `knight_e_lunge.tres`.
- **Callers:** Cleave's knockback (17 px over 0.1 s) and Hurtbox knockback (`Unit._on_hurtbox_hurt`) use `knockback_curve`. The dash and Lunge use `curve_dash`.
- **Lunge:** its hits don't depend on its speed: they're found along the segment from the start point to the end point after the dash. Its afterimages (spawned every 2 physics frames) bunch toward the slow end.
- **Speed graph:** `debug_draw` on MovementComponent draws the actual distance moved per physics frame (so walls show), over `debug_graph_time` = 1 s, scaled to `debug_graph_max_speed_px` = 1500 px/s, above the unit.
- Stuns, walls and `displacement_finished` behave exactly as they did with constant speed.
- **Done means:** the dash still covers exactly 128 px (the cracked tiles); the speed graph shows a burst and then an ease-out; there's no visible pause between the dash and running; knockback on slimes bursts and then settles.

### F4: Camera aim lead rework (runs before F3)
- The camera spec (dead zone, curve, y scale, easing, context, hold time, `move_lead_px`, aim drift, debug draw) is Architecture, 4 (Camera).
- **Done means:** moving the cursor inside the dead zone doesn't move the camera; flicking the cursor corner to corner moves the camera over about half a second, with no whip; walking without aiming barely leans; holding an aimed ability toward an off-screen dummy leans fully; F1 smoothness is unchanged.

### F3: Movement feedback (VFX only, never changes gameplay state)
**Deleted in the 3D pivot's cleanup C3 (2026-10-03)** with the 2D bodies it deformed: the 3D view's dash afterimages are `UnitView`'s (same numbers); the stretches, squashes and dust wait for the art pass. What F3 built:
- `MovementVFXComponent`, the last child of `player.tscn` and `slime.tscn`. `enabled` turns everything off; every number is an export (groups Dash, Walking, Displacement, Dust). It reads the components' signals and public state and never changes gameplay state. Dust uses its own random generator, so slime wander rolls don't change. It works on today's Polygon2D placeholders and on 8-direction sprites later.
- **How the Body is deformed:** only while the frame is drawn. It applies the deformation on `RenderingServer.frame_pre_draw` and undoes it on `frame_post_draw`, so code that writes `body.scale` / `body.position` (player flip and bob, slime squash, death tweens) never sees it, and player.gd, enemy.gd and unit.gd are unchanged. While enabled, the Body's own physics interpolation is off, or the deformation only shows partly; the unit itself stays interpolated, so F1 smoothness is unchanged. Deformation pivots on the feet (`deform_pivot`), so the feet stay on the shadow. The Shadow and the sword are never deformed.
- **Dash:** stretch 1.25 × 0.8 (along × across the dash) held 0.06 s, eases back over 0.08 s; squash 0.9 × 1.1 when the dash ends, held 0.05 s, eases back over 0.08 s. 4 afterimages 0.03 s apart (the first at the start point), each fading over 0.15 s: flat cyan silhouettes (`afterimage_color`, 50%) drawn as one shape (a CanvasGroup), so they can't be mistaken for the half see-through player; `afterimage_silhouette = false` gives tinted copies instead. Each is placed where the unit was at the start of its physics frame, so it never shows up ahead of the player. They're copies of the Body, so sprites work too (as a still frame). A dust puff (6 specks flying 14 px back, flattened ×0.5 onto the floor, 0.3 s) at the start.
- **Walking:** a 1 px bob, one per 40 px walked (3 a second at the Knight's 120 px/s; about 4 when hasted by Iron Resolve, 162 px/s). While enabled it replaces player.gd's 2 px bob (`replace_existing_bob`). Reversal dust: a turn of more than 135°, after the old direction reached 90 px/s, within 0.1 s of walking it (so letting go and pressing the other way counts), at most every 0.15 s. With 8-way keys a full reversal counts; exactly 135° (right → down-left) doesn't.
- **Knockback:** any displacement that isn't the unit's own dash (knockback, pulls, Lunge, swing steps) stretches along the push by 1 + 0.0005 × speed (px/s), up to 1.3; across = 1 / along. Cleave's knockback (407 px/s peak) gives 1.2; Lunge starts at 1.3 and eases out with its speed. It reads `is_displaced()` and the unit's velocity every frame instead of a new signal, so MovementComponent is unchanged.
- **Slimes:** walk bob and reversal dust off (they have their own hop); knockback stretch on.
- **Pixel snapping:** the squash doesn't jitter. `snap_2d_transforms_to_pixel` is off since F1, so the deformation scales smoothly (edges move in half-game-pixel steps at 1280×720). With 8-direction pixel sprites, a non-integer scale draws some art pixels one screen pixel wider than others for the ~0.15 s an effect lasts: the normal look of squash and stretch on pixel art. If it shows, pick stretch values that land on whole pixels or turn the deformation off for that unit.
- **Done means:** the effects are visible but never hide where the player actually is, and turning the toggle off gives exactly the visuals from before F3.

## Build order (one step per request)
1. Input map + WASD walking (step 2 merged into it). Built 2026-09-25, see CHANGELOG.md.
2. *(merged into step 1)*
3. Facing and aim. Built 2026-09-25, see CHANGELOG.md.
4. Camera aim lead. Built 2026-09-25, see CHANGELOG.md.
5. Player states. Built 2026-09-25, see CHANGELOG.md.
6. Dash with charges, i-frames, end-lag and chaining. Built 2026-09-25, see CHANGELOG.md.
7. Input buffer, dash cancels (`Ability.dash_cancelable`), and the dash-strike hook. Built 2026-09-25, see CHANGELOG.md.
- **Feel pass F1 → F2 → F4 → F3.** Built 2026-09-25, see CHANGELOG.md.
8. *(removed 2026-09-25)* Pit crossing and fall/respawn is no longer planned (DECISIONS.md, Movement). The unscheduled design stays in WORLD_INTERACTION.md, Pits and movement types.

Steps 1 and 3–7 passed Ryan's play test (2026-09-29, see CHANGELOG.md).

## Testing
- `res://scenes/sandbox_main.tscn` (open it, press F6) runs `main.tscn` with `res://scenes/rooms/sandbox.tscn` as the room. room_01 stays the default game.
- Sandbox test spots: open floor (start/stop), a long wall (sliding), a single pillar, an L-corner, a diagonal stair-step wall (corner catching), a 1-tile corridor and a 2-tile gap, and two cracked floor tiles 128 px apart (dash length).
- Three passive training dummies (`Enemy.passive = true`) and two normal slimes in a pen (chase test).
- One elite slime (`slime_elite.tscn`) in the open top-right corner: it casts a telegraphed slam at the player (COMBAT C5).
- The camera can only lean sideways in the middle third of the sandbox (room bounds). `debug_draw` on the Camera node (in `main.tscn`) shows the dead zone and the lean. In 3D the bounds keep the focus on the floor instead, and `debug_draw` is on `CameraLook`.

## Open questions
- **Clicks on the HUD:** PlayerInput reads `attack` from the Input state, so a click on the ability bar also swings; the bar's `MOUSE_FILTER_STOP` doesn't block that. Fix when the HUD gets clickable parts (UI.md).
- ~~Should the vertical speed be scaled (e.g. 0.9×) for the 3/4 view? Default: no.~~ Answered by the 3D pivot: no. Under the tilted 3D camera, north–south distances look 23% shorter at 50° pitch; the numbers stay, the foreshortening is accepted (Q11; 3D.md).
- **Aim zoom (parked until the first long-range champion):** while aiming an ability, zoom out just enough to show its full range, keeping the cursor lean as is. The Knight's ranges (96–180 px) already fit on screen, so it would barely show today. Costs to weigh then: a zoom between 1.0 and 0.5 draws art pixels at uneven sizes (at 0.8 they're 1.6 screen px), and zooming around the screen center moves the world under a still cursor (about 36 px at the edge at 0.9, 80 px at 0.8) unless it zooms around the cursor. Alternative with neither cost: while aiming, lean just far enough that the ability's full range is on screen.
