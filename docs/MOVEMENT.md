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

## Input and legacy systems
### Input map
Only keys that physically collided with WASD changed. Action names never change.

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
- 128 px (`dash_distance` = 400 u) over `dash_duration` = 0.18 s at constant speed, through `MovementComponent.dash()` (passes through units, stops at walls).
- Direction: the held input direction; with no input, `facing`.
- I-frames for the whole dash via `Unit.add_invulnerability(&"dash")`: `take_damage()` and Hurtbox hits (damage and knockback) are ignored. This sits on Unit, not only the Hurtbox, because enemy basic attacks call `take_damage()` directly. The body turns half see-through.
- Charges: `UnitStats.dash_charges` (default 1). One charge returns every `charge_recharge_time` = 0.35 s, one at a time, counted only while not dashing.
- End-lag: `end_lag` = 0.05 s of locked walking after a dash. A dash can chain in during end-lag if a charge is left.
- Not allowed while stunned or already displaced (dashing, knockback), or while casting unless the ability is `dash_cancelable` (then the dash cancels the cast). A press that isn't allowed is buffered (see below). Starting a dash cancels a basic attack windup and a queued walk-into-range cast.
- Crosses pits (step 8). If the dash ends over a pit: small damage, then respawn at the last safe tile.

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
4. **Camera:** `aim_lead` = 64 px (0 = off). While locked, the camera leans toward the mouse by `aim_lead` × the mouse's distance from the screen center (as a fraction of half the screen, capped at 1). Screen space, so camera movement doesn't feed back into it; position smoothing eases it in. Holding C centers with no lead. Room bounds still clamp, so there's no sideways lead near a room's left or right edge.
5. **Signals:** `Player.state_changed(from, to)`; `DashComponent.dash_started(direction)`, `dash_ended`, `charges_changed(charges, max)` (`debug_draw` on DashComponent shows charge pips); `PlayerInput.attack_pressed(dash_strike)`; `AbilityComponent.cast_cancelled(slot, ability)`. Planned: `fell_in_pit` (step 8).

## Build order (one step per request)
1. **Built** (awaiting play test): input map + WASD walking, done together (after the input map alone the player had no walk input). PlayerInput, `set_input_direction()`, `use_steering = false` on the player, Knight 560 move speed, scaled soft cap exports, LoL threshold overrides on `slime.tscn`.
2. *(merged into step 1)*
3. **Built** (awaiting play test): facing and aim.
4. **Built** (awaiting play test): camera aim lead.
5. **Built** (awaiting play test): player states.
6. **Built** (awaiting play test): dash with charges, i-frames, end-lag and chaining.
7. **Built** (awaiting play test): input buffer, dash cancels (`Ability.dash_cancelable`), and the dash-strike hook.
8. Pit crossing and fall/respawn (needs the pit layer, see WORLD_INTERACTION.md).

**Done means:** no errors; WASD works in play mode; the Knight's 4 abilities, enemies chasing, and the HUD still work as before. Exception (decided): the Knight's basic attacks stay dormant until COMBAT gives `attack` a reader.
If a step needs removing or rewriting existing code, stop and explain why before doing it.

## Testing
- `res://scenes/sandbox_main.tscn` (open it, press F6) runs `main.tscn` with `res://scenes/rooms/sandbox.tscn` as the room. room_01 stays the default game.
- Sandbox test spots: open floor (start/stop), a long wall (sliding), a single pillar, an L-corner, a diagonal stair-step wall (corner catching), a 1-tile corridor and a 2-tile gap, and two cracked floor tiles 128 px apart (dash length).
- Three passive training dummies (`Enemy.passive = true`) and two normal slimes in a pen (chase test).
- The camera can only lean sideways in the middle third of the sandbox (room bounds).

## Open questions
- **`attack` vs `select` on left mouse:** both are bound to left mouse. No double-fire yet: `select` only acts while attack-move is armed (unbound A key), and `attack` only emits `attack_pressed`, which nothing listens to. Resolve in the COMBAT work. PlayerInput reads `attack` from the Input state, so a click on the ability bar also counts as an attack press; the bar's `MOUSE_FILTER_STOP` doesn't block that.
- **`cast_mode`:** hold-to-aim (`QUICK_WITH_INDICATOR`, current) vs `QUICK`. Try `QUICK` in play testing.
- Should the vertical speed be scaled (e.g. 0.9×) for the 3/4 view? Default: no.
