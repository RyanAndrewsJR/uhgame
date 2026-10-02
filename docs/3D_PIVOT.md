# 3D_PIVOT.md: Evaluating the move from 2D to a fixed-angle 3D view
<!-- Evaluation written 2026-10-01, amended the same day after Ryan's review (terrain, knock-ups, the split spike,
     the generic view mechanism, the test-isolation plan). Nothing here is built. Beyond the Givens, the only thing
     decided is P5's replace of the 10 mouse calls. When Ryan answers the interview, the decisions go to DECISIONS.md
     and the lasting spec to a new docs/3D.md; this doc then becomes the record of how the choice was made. -->

**Read when:** deciding on or building the 2D → 3D view change, running the spikes, or asking how a piece of 2D code maps to 3D.
**Depends on:** CLAUDE.md, VISION.md, CONVENTIONS.md, MOVEMENT.md, COMBAT.md, WORLD_INTERACTION.md, AUDIO.md, ABILITIES.md.
**Used by:** the future `docs/3D.md`, and every doc listed under Doc edits.
**Status:** A1 is the recommendation (Ryan, review 2026-10-01). Ryan answered the interview and approved the ledge layer and the test-isolation fix (second review, 2026-10-01). Next: the "Before P0" fix, then P0a. P0a not started.

## Givens (decided by Ryan; not re-asked here)
- Target: a League/Diablo-style fixed-angle 3D camera. Rotation locked, follows the player. 3D models and lighting. Gameplay stays on a flat ground plane. No player jump.
- Why: the player sees more of the world, and lighting and animation get easier.
- Unchanged: the pillars, game feel, and every gameplay number (League units, STATS.md). Data in Resources, signals up and calls down, the additive change policy, disable before deleting, ask before removing.
- No new name uses the word "proc" (CONVENTIONS.md already defines it).
- **Added 2026-10-01:** real terrain height like Diablo IV (stairs, ramps, hills, plateaus) plus knock-ups. Still no jumping. A melee champion must always be able to answer an elevated enemy.
- **Approved 2026-10-01:** P5's replace of the 10 direct `get_global_mouse_position()` calls in `player.gd` with `get_aim_point()`.
- **Approved 2026-10-01 (second review):** ledges get their own collision layer 11, `ledge` (Elevation 1b); Judgement is not tagged `melee` (Elevation 2); enemies don't knock up the player in v1 (Elevation 1a); the interview answers (Open questions, Interview answers); the "Before P0" test-isolation fix as planned, both replaces included.

## Current code
### Baseline (measured 2026-10-01 on clean `main`, d8429ea)
- `git status`: clean.
- **106 `.gd` files, 26,032 lines.** Game code: 99 files, 14,473 lines. Tests: 7 files, 11,559 lines (6 suites + `hook_vfx_probe.gd`).
- 18 `.tscn`, 96 `.tres`. Only 2 rooms exist (`room_01.tscn`, `sandbox.tscn`).
- **Tests: 1,780 of 1,782 checks pass** (headless, run one after another):

| Suite | Result | Note |
|---|---|---|
| stats | 179 / 179 | |
| combat | 458 / 459 | FAIL "heavy feel: 0.06 s hitstop (got 0.038)": the check reads the clock frames after the hit (Before P0, Problem 2) |
| abilities | 558 / 559 | FAIL "AB1: emitted as cast_mode": Settings reads Ryan's real `user://settings.cfg` (`cast_mode="quick_with_indicator"`), so the first set changes nothing and emits once, not twice (Before P0, Problem 1) |
| audio | 109 / 109 | |
| champions | 168 / 168 | |
| talents | 308 / 308 | |

"Baseline" in the build order means a fully green run after the Before P0 fix: **1,788 of 1,788** (the 1,782 plus that fix's 6 new checks; built 2026-10-01, see CHANGELOG.md).

### Inventory (counted with grep over `game/`, `.godot/` excluded)
Counts are matching lines / files. "Game" = non-test scripts.

| Term | In scripts | In scenes / data | Where |
|---|---|---|---|
| `CharacterBody2D` | 5 / 2 | 4 nodes / 3 scenes | `unit.gd` (base class), `movement_component.gd` (its parent type); `player.tscn`, `slime.tscn`, `stats_test.tscn` (2) |
| `Area2D` | 2 / 2 | 2 / 2 | `hitbox.gd`, `hurtbox.gd`; a `Hurtbox` in `player.tscn` and `slime.tscn`. Dormant: no scene has a Hitbox |
| `CollisionShape2D` (+`CollisionPolygon2D`) | 4 / 3 | 5 / 3 | `hitbox.gd`, test wall builders in `combat_test.gd` and `abilities_test.gd`; player, slime, slime_elite |
| `Node2D` | 76 / 31 | 25 / 13 | everywhere visuals or debug drawing live (see Classification); every room, unit and test root |
| `Camera2D` | 10 / 4 (+1 `get_camera_2d`) | 1 / 1 | `game_camera.gd`, `main.gd`, spy cameras in `combat_test.gd` and `abilities_test.gd`; `game_feel.gd` finds the camera with `get_camera_2d()`; `main.tscn` |
| `TileMapLayer` | 5 / 4 | 2 / 2 | `room.gd`, `main.gd` (camera bounds); comments in `vfx.gd`, `aura.gd`; `room_01.tscn`, `sandbox.tscn` |
| `NavigationServer2D` / `NavigationAgent2D` | 5 / 2 / 0 | 0 | `movement_component.gd` (paths), `auto_attack_component.gd` (closest-point check); `room.gd` bakes a `NavigationRegion2D` + `NavigationPolygon` (5 lines). No NavigationAgent2D anywhere |
| `PhysicsDirectSpaceState2D` | 0 by name; 2 via `direct_space_state` | 0 | `world_query.gd` only (`PhysicsRayQueryParameters2D`, `PhysicsShapeQueryParameters2D`, `cast_motion`). Plus one `RayCast2D` (`enemy.gd` `Sight`, in `slime.tscn`) |
| `Polygon2D` / `Sprite2D` / `AnimatedSprite2D` | 10 / 5, 0, 0 | 10 / 2, 0, 0 | all art is placeholder polygons (`player.tscn` 5, `slime.tscn` 5; `vfx.gd`, `player.gd`, `cleave_wave.gd`, `movement_vfx_component.gd`); **no sprites exist yet**. `Line2D`: 5 / 4 |
| `AudioStreamPlayer2D` | 14 / 2 | 0 | `audio.gd` (the pool), `audio_test.gd`. No `AudioListener2D` node (1 comment) |
| `get_global_mouse_position` | 12 / 2 | 0 | `player.gd` 11, `abilities_test.gd` 1 |
| `Vector2` | 886 / 51 (game 377, tests 509) | 42 lines / 7 scenes, 9 / 6 `.tres` | heaviest: `combat_test` 219, `abilities_test` 215, `movement_component` 50, `movement_vfx_component` 35, `ability_component` 31, `player` 26, `game_camera` 26. The `.tres` hits are Curve points (5) and the TileSet (4), not positions |
| `_px` names | 261 / 43 (game 232, tests 29) | 13 values / 7 files | 34 distinct names (`radius_px` 34×, `range_px` 28×, `knockback_px` 24×, `get_gameplay_radius_px` 23×...). 25 `@export` px fields in 15 scripts; 3 `const *_PX` |
| px literals | `Units.to_px` 50 / 22 (game 46); `Units.to_units` 1 | see Data | `PX_PER_UNIT` exists only in `units.gd`. Bare px numbers in gameplay code are few: 8 px repath, 0.75 px arrival, 2 px nav tolerance (movement, auto-attack); 16 px sword face point and 2–6 px eye/bump offsets (visual) |
| y-sort | 0 in scripts | `y_sort_enabled` on `Entities` in 2 rooms | plus `z_index` 14 / 9 (draw-order fixes: damage numbers 100, health bars 90, VFX 19–21, debug 50–100) |
| also: `global_position` | 551 / 39 (game 142, tests 409) | | |
| also: `_draw()` / `draw_*` / `queue_redraw` | 179 / 21 (game only) | | indicators (`ability.gd` 15), telegraphs 14, UI controls (ability bar 30, passive slot 15, resource bar 8), health bar 7, hover ring, debug draws |
| also: `reset_physics_interpolation` | 11 / 8 | | camera, projectile, `VFX.spawn_scene`, tests |

### Classification (all 99 game scripts; tests below)
**(a) Pure logic, no change (39 files).** Autoloads `events`, `progress`, `reactions`, `settings`; components `health`, `resource`, `stats`, `status`; 25 data scripts (`ability_augment`, `apply_status_gameplay_effect`, `audio_mix`, `champion_data`, `champion_leveling`, `charge_scaling`, `conditional_bonus`, `damage_scaling`, `deal_damage_gameplay_effect`, `gameplay_effect`, `heal_gameplay_effect`, `hit_feel`, `modify_cooldown_gameplay_effect`, `passive`, `remove_statuses_by_tag_gameplay_effect`, `restore_resource_gameplay_effect`, `status_effect`, `stat_definition`, `stat_modifier`, `stat_registry`, `stat_scaling`, `talent`, `talent_requirement`, `toolkit_bundle`, `unit_stats`); `sandbox_abilities`, `sandbox_augments`, `sandbox_reactions`, `sandbox_talents`; `champion_progress`; `ui/hud`. (`hit_feel.gd`'s shake numbers are screen px; they keep working if the 3D camera reads them as screen px. P8 adds one field to `status_effect.gd` and one line to `status_component.gd`.)

**(b) Logic with px / Vector2 math, no 2D node type (31 files).** `ability.gd` (also draws indicators), `ability_util.gd`, `cast_context.gd`; the 5 Knight ability scripts, `slime/slam.gd`, the 8 test abilities; `combat_sounds.gd`, `hit_context.gd`, `hit_pipeline.gd`; `ability_component.gd`, `auto_attack_component.gd` (also one NavigationServer2D query and a debug Node2D); `units.gd`; data `attack_combo`, `attack_swing`, `cast_ability_gameplay_effect`, `condition`, `knockback_gameplay_effect`, `reaction_rule`, `sound_event`; `player_input.gd`. Some create Telegraphs/VFX nodes, but their own math is plain Vector2.

**(c) Bound to a 2D node type or a 2D server (14 files).** `unit.gd` (CharacterBody2D), `player.gd` (mouse, `SwordPivot`, `_draw`), `enemy.gd` (`RayCast2D`), `movement_component.gd` (Node2D; drives the CharacterBody2D; NavigationServer2D), `dash_component.gd` (Node2D only for its debug draw), `hitbox.gd`, `hurtbox.gd` (Area2D), `projectile.gd` (Node2D that is both sim and drawing), `world_query.gd` (the root World2D), `audio.gd` (AudioStreamPlayer2D; listener from the canvas transform), `game_feel.gd` (`get_camera_2d()`), `game_camera.gd` (Camera2D), `room.gd` (TileMapLayer, NavigationRegion2D), `main.gd` (Node2D, Camera2D, TileMapLayer).

**(d) View / visual only (15 files).** World-space: `vfx.gd`, `telegraph.gd`, `aura.gd`, `staggered_mark.gd`, `stun_stars.gd`, `movement_vfx_component.gd`, `damage_number.gd`, `health_bar.gd`, data `damage_number_style.gd` (screen px). Screen-space UI, unaffected by any 3D choice: `ability_bar`, `passive_slot`, `resource_bar`, `hub`, `pause_menu`, `talent_screen`.

**Tests.** 5 suites (`abilities`, `audio`, `champions`, `combat`, `talents`) and `hook_vfx_probe` extend Node2D: class (c). `stats_test.gd` extends Node, but its scene holds two CharacterBody2D.

### Choke points
- **League units → px: yes, one choke point.** `Units.to_px()` is the only conversion; `PX_PER_UNIT` (0.32) appears nowhere else. 46 game call sites in 20 files.
- **px authored directly: named, but scattered.** 25 `@export` `_px` fields in 15 scripts, 13 px values in 7 data/scene files, 3 `const *_PX`, about 6 bare thresholds. The `_px` suffix (CONVENTIONS) makes every one findable.
- **Two kinds of px are mixed today, and 3D splits them.** *Ground px* (ranges, knockback, lunge, radii, sound distance) are distances on the floor. *Screen px* (camera lean 80, edge margin, shake, damage number rise/spread, walk bob, health bar width) are distances on the 640×360 screen. In 2D they are the same scale; with a tilted 3D camera they are not.
- **Mouse aim: a choke point exists but is bypassed.** `Player.get_aim_point()` (`player.gd:588`) returns the mouse, but 10 of the 11 `get_global_mouse_position()` calls in `player.gd` call the mouse directly (routing them through it is approved, P5).
- **Camera:** one class (`GameCamera`), one lookup (`GameFeel.shake()`), one setup (`main.gd`).
- **World queries:** `WorldQuery` (2 methods), 2 navigation calls, 1 RayCast2D. Every hit test is plain math on `global_position` (`AbilityUtil.in_circle / in_cone / along_segment`, edge distances) plus one line-of-sight ray. **The sim is already a flat-plane sim**, which is what League and Diablo compute under their 3D art.
- **Audio:** one place (`Audio` autoload).
- **Drawing:** 179 lines in 21 files; the ground drawings (indicators, telegraphs, hover ring) are the ones a 3D view must show.

### How the code is built today
**Units and their visuals.** A Unit scene is one `CharacterBody2D` root holding both the sim and the visuals:
- Sim children: `CollisionShape2D` (circle at the feet), `Hurtbox` (Area2D, dormant), the components (`StatsComponent`, `StatusComponent`, `HealthComponent`, `ResourceComponent`, `AutoAttackComponent`, `MovementComponent`, `AbilityComponent`, `PlayerInput`, `DashComponent`), `Sight` (enemies).
- Visual children: `Shadow` (Polygon2D), `Body` (Node2D of Polygon2Ds), `SwordPivot/Sword` (Player), `HealthBar` (Node2D `_draw`), `MovementVFXComponent` (deforms `Body` only while a frame draws). A status's VFX scene (`StatusEffect.vfx`: stun stars, staggered mark) is added as a child of the unit by `StatusComponent`.
- **Can the sim be separated from the visuals? Yes, with small work.** The sim never reads visual state back, except in these 6 places:
  1. `Unit._play_death()`: the Unit is freed by the end of the body's death tween (0.33 s), so the free time lives in a visual tween.
  2. `Unit.get_center()` = `global_position + body_center` (a 3/4-view "height" offset, e.g. `(0, -15)`): used by targeting help (`AbilityUtil.nearest_enemy_to`, `Unit.contains_point` for the enemy under the cursor) and by damage number placement.
  3. `Unit._add_number()`: damage numbers are Labels added to the unit's parent Node2D.
  4. `Player._draw()` draws ability indicators through `Ability.draw_indicator()`; tests read `_drawn_indicator_slot` / `_drawn_vector_start`.
  5. `Player.face()` aims from `sword_pivot.global_position` (visual only, but on the player script).
  6. `Projectile` is one Node2D that moves, hits and draws itself.
- The signals a view needs already exist: `died`, `damaged`, `health_changed`, `swing_started / landed / cancelled`, `cast_started / finished`, `dash_started / ended`, `Events.unit_hit`. Facing lives on Player (`facing`, `get_facing_octant()`). The presentation hooks (`cast_anim`, `swing_anim`, `cast_vfx`, `impact_vfx`, `swing_vfx`; ABILITIES AB14) were built for an art pass.

**How tests build scenes.** The 5 Node2D suites instance the real `player.tscn`, `slime.tscn`, `slime_elite.tscn`, `sandbox.tscn`, `hud.tscn`, `hub.tscn` and `pause_menu.tscn` under their own Node2D root; place units with Vector2; build walls from `StaticBody2D` + `RectangleShape2D`; spy on shake with a scripted `Camera2D`; drive input through `Input.action_press()` and `player_input._unhandled_input()`; and wait on physics frames. They touch visuals in few places: damage-number Labels (about 30 lines, combat), `_drawn_*` (8), Telegraph nodes (8), `body`/`modulate` (8), the sword (5). No test instances `main.tscn`.
- **Survive unchanged under A1: all 6 suites,** as long as the unit scenes keep their 2D roots, the 3D view is built by Main (which no test instances), and aiming falls back to the mouse when there is no 3D view (`abilities_test.gd:3502` computes an expected point from `get_global_mouse_position()`).
- **Under A2: none survive unchanged.** Every suite's fixtures (Vector2 positions, 2D walls, Camera2D spies, CharacterBody2D roots) change; 780 test lines carry a 2D marker.

**2D-specific values in `.tres` / `.tscn`.**
- Scenes: 2D node types in `player`, `slime`, `slime_elite`, `main`, both rooms, the two VFX scenes and the test scenes. Values: `body_center` (player `(0, -15)`, slime `(0, -10)`), HealthBar positions (`(0, -44)`, `(0, -32)`), Hurtbox shape offsets, collider radii (11, 14), placeholder polygons, room entity positions and `PlayerSpawn` (px), tile data, `y_sort_enabled`.
- TileSet `dungeon_tileset.tres`: 32 px tiles, square physics polygons on physics layer 0 → collision layer 1. No custom data layers yet.
- Ground px in data (stay valid as sim px under A1): `combo_knight.tres` (`knockback_px` 16/20, `lunge_px` 16/10, `lunge_max_px` 32/32), `knight_q_cleave.tres` (`hit_knockback_px` 17), `slime_elite_q_slam.tres` (`radius_px` 72, `knockback_px` 20, and "{radius_px} px" in its description), `test_q_strike.tres` (description), `sound_slime_elite_slam_telegraph.tres` (`max_distance_px` 640), `talent_knight_whirling_cleave.tres` (stat `hit_knockback_px`), `slime.tscn` (`hit_knockback_px` 12, `walk_bob_px` 0).
- Screen px in data: `hit_feel_default.tres` (shake), `damage_number_style_default.tres` (`rise_px`, `spread_px`), camera exports in `main.tscn`.
- Not spatial: the Curve `.tres` files (their Vector2 are curve points). League units in `UnitStats` and abilities: unaffected by any strategy (Givens).
- Project settings: renderer **Forward Plus**, `d3d12` on Windows, 3D physics engine already **Jolt**, `physics_interpolation` on, stretch `canvas_items`, 2D physics layer names 1–5.

## Goal / feel
- **Proposed scale: 1 m = 1 tile = 32 px = 100 League units.** It falls out of `PX_PER_UNIT` = 0.32. Checks: the Knight's 375 MS = 120 px/s = 3.75 m/s (a jog); the dash 128 px = 4 m; `gameplay_radius` 65 u = 0.65 m. A 1 m grid is also the grid `HeightMapShape3D` uses (Engine facts, 6).
- **Every gameplay number stays as it is.** Under A1 the sim keeps its px values; the view converts them for display only.
- **Smoothness:** no visible stutter walking along the sandbox wall or dashing, at 60 Hz and at Ryan's 144 Hz (the F1 bar, MOVEMENT.md), hitstops included.
- **Walls:** a cutaway height, so walls don't hide the player; a spike variable, default about **1.2 m**.
- **What "see more" costs on screen.** Today the screen shows 20 × 11.25 tiles = 225 tiles² of floor. With an orthographic camera, screen height H = width × 9/16 and floor depth = H / sin(pitch):

| Visible width | Pitch 50° | Pitch 60° | Pitch 70° |
|---|---|---|---|
| 20 m (today's width) | 294 tiles² (+31%) | 260 (+15%) | 239 (+6%) |
| 24 m | 423 (+88%) | 374 (+66%) | 345 (+53%) |
| 28 m | 576 (+156%) | 509 (+126%) | 469 (+109%) |

  A wider view also draws everything smaller: at 24 m, a tile is 26.7 screen px instead of 32 (−17%). Perspective shows more floor at the top of the screen and less at the bottom than this table; a narrow field of view keeps it close to these numbers.
- **Up and down the screen looks slower.** The floor is tilted away, so north–south distances look shorter by sin(pitch): 0.77 at 50°, 0.87 at 60°, 0.94 at 70°. At 60° and today's width, the 128 px dash north covers about 111 screen px, east 128. The numbers don't change; only how they look. (MOVEMENT.md's open question "scale vertical speed for the 3/4 view?" becomes this.)
- **Slopes don't change speed.** The sim is flat, so walking up a ramp takes as long as walking the same map distance on flat floor (League's rule).

## Core rules (hold whichever strategy is chosen)
- **The sim decides, the view shows.** Like VFX and sound events, the 3D view never changes gameplay state.
- **The sim never reads height.** Terrain height lives in the view (Elevation, 1b). The one height-like rule in the sim is the opt-in `elevated` tag (Elevation, 2), which comes from where a unit stands, not from a height.
- **No unanswerable enemy** (Elevation, 3).
- **One mapping.** Sim px ↔ view meters go through one pair of functions next to `Units.to_px()`. No other code multiplies or divides by 32.
- **Positions copy on the physics tick, after the sim.** `WorldView` syncs every view in its own `_physics_process`, with a `process_physics_priority` above every sim node, and 3D physics interpolation smooths the result. Never in `_process` (Engine facts, 3).
- **Additive and switchable.** Until the milestone, the 3D view sits behind a flag on Main; with it off, the game is exactly today's.
- **Headless tests never build the view.** Every existing check keeps running against the same sim.

## Elevation: three kinds
Ryan's givens ask for real terrain height (Diablo IV: stairs, ramps, hills, plateaus) and knock-ups, with no jumping, and a melee champion must always be able to answer an elevated enemy. Under A1 these are three separate things.

### 1a. Airborne (knock-up): a status plus a view-only arc
- **Status** `status_airborne.tres` (proposed): tags `cc`, `airborne`, `debuff`. Blocks moving, attacking, casting and dashing (a hard CC, like the stun). Stack rule REFRESH_LONGER (like the stun). Its duration comes from the hit that applies it (typically 0.4–1.0 s).
- **Tenacity:** doesn't shorten it (the League rule; the arc keeps its shape). Today tenacity shortens every `cc` status (`status_component.gd:77`), so this needs one new StatusEffect field (proposed `ignores_tenacity`, default false).
- **I-frames:** a unit with i-frames (dash, post-hit) blocks the whole hit, so it can't be knocked up (`Unit.on_hit()` returns before statuses). Being airborne gives no i-frames: an airborne unit can be hit again (juggles).
- **Cleanses and unstoppable (Ryan, 2026-10-01: a cleanse does not end a knock-up):** a cleanse and gaining unstoppable both remove `cc` through `StatusComponent.remove_statuses_with_tags()` (the cleanse GameplayEffect; unstoppable's "ends every cc at once", `status_component.gd:87`). That call skips a status marked not cleansable (proposed StatusEffect field `cleansable`, default true; airborne false), so neither ends a knock-up. Unstoppable still refuses a new one (it's `cc`). Gaining unstoppable mid-air following the cleanse rule is an inference from the shared call; Ryan can split them.
- **Not on the player in v1 (design note, Ryan, 2026-10-01):** enemies don't knock up the player in v1. VISION's first decision priority says control is never taken from the player without a clear reason; a knock-up takes all of it. Only telegraphed boss attacks are candidates later (revisit with ENEMIES_AI.md; Q8). The status itself works on any unit (the player's own abilities knock up enemies).
- **Displacement:** airborne itself doesn't move the unit. A knock-back-and-up is one hit carrying both a knockback (the existing `knockback_px`) and `status_airborne`. **While a unit is airborne and displaced, it ignores low obstacles, ledges and pits:** its collision mask drops layers 7 (`low_obstacle`), 11 (`ledge`) and 6 (`pit`; every displacement already drops 6, approved in WORLD_INTERACTION.md). Walls (layer 1) still stop it. So a knock-up can carry an enemy over a fence, off a cliff or into a pit. When the displacement ends: over a pit, the pit rule applies; inside a low obstacle or a ledge's footprint, `WorldQuery.resolve_valid_position()` (planned) puts it on the nearest floor on the side it came from. No fall damage for now (Ryan, 2026-10-01).
- **Dashing out:** a hit's knockback is dash-cancelable today (COMBAT.md); airborne blocks dashing, so a knock-up can't be dashed out of while it lasts.
- **Reaction rules (no new trigger):** `STATUS_APPLIED` with required tag `airborne` ("knocking up an oiled enemy ignites it"); `HIT` rules and `target:airborne` damage scopes read it from `ctx.target_tags` (COMBAT C8 and C11, as built). Landing needs no trigger now; `status_removed` is the reserved event if one is ever needed.
- **View:** the model rises and falls on a curve over the status's actual duration. The apex height and the curve are view data, not StatusEffect fields. The sim never reads the arc.

### 1b. Walkable terrain height: a heightmap the view uses and the sim never reads
- **Source:** per room, from tile data: a height per tile, plus ramp and stair tiles (a TileSet custom data layer or a separate `Height` TileMapLayer; picked in P8). `RoomView` turns it into a heightmap on the tile corners (1 m grid).
- **The view reads it for:** model Y, the camera's height, telegraph decals, projectile height (a projectile's Y moves smoothly from its start height toward the terrain under its target, never below the terrain), and the floor pick (the mouse ray hits terrain geometry on its own view-only 3D physics layer, not a flat plane: a `HeightMapShape3D` or a trimesh of the floor mesh, whichever P0a finds exact).
- **The sim keeps its flat 2D footprint.** Where the height steps without a ramp or stairs (a cliff), the room builder places a **ledge**: a collider on layer 11 (`ledge`), derived once at room load from the tile data. Ledges block walking and dashes, and navigation (the bake parses layer 11 as well as 1), but not projectiles or line of sight (`WorldQuery` and `Sight` mask layer 1 only). Ramps and stairs are plain floor in the sim. Gameplay code never asks for a height.
- **Ledge layer (approved by Ryan 2026-10-01, option b of three; cliffs stop dashes).** Why a layer of its own: a ghosted `dash()` (the dash, Lunge, the test Triple Step) keeps only the walls layer while it runs (`collision_mask & 1`, `movement_component.gd:271`), which WORLD_INTERACTION.md calls correct for pits and low obstacles; on layer 7 a dash would have climbed any cliff. So: layer 11 `ledge` blocks walking and dashes, not projectiles or line of sight; the ghosted dash keeps layers 1 and 11 (bits `1 | 1024`; a one-line replace in P8, approved with this option). Fences and rubble stay on layer 7, crossable by dashes as planned. Airborne units drop layer 11 too (1a). Rejected: (a) dashes cross cliffs; (c) ledges on 7 with dashes blocked by fences too.
- Option for later, not the default: Godot 2D's one-way collision (`CollisionShape2D.one_way_collision`, checked) could make a ledge passable downward only. Walking down a cliff is close to jumping, so it stays off unless Ryan asks.

### 1c. Overlapping floors: separate rooms
- The sim holds one floor per map spot. A bridge with enemies walking under it, a balcony over a hall or a two-story building can't be inside one room under A1. Each floor is its own room, joined by stairs or doors (DUNGEONS.md). **Ryan, 2026-10-01 (Q13): no overlapping floors in one room; separate floors are separate rooms.**

### 2. The default hit rule, and the opt-in `elevated` tag
- **Default:** hits use 2D distance, whatever the terrain. A ledge blocks walking but not projectiles or line of sight. So an enemy standing at a plateau's edge can be hit from below by anything that reaches it, melee included (League's rule: one flat map).
- **Opt-in, for special enemies** (snipers, archers on towers): the tag `elevated`, from `status_elevated` (proposed). A **perch** applies it: an area (Hazard-style Area2D) that gives the status while a unit stands in it and removes it on exit (the approved Hazard spec needs this "while inside" option). The player gets it too when walking up onto the perch.
- **One central filter:** `AbilityUtil.can_reach(attacker, target, hit_tags) -> bool` (proposed): an `elevated` target can't be hit by a hit tagged `melee` unless the attacker is `elevated` too. It is called in two places only: AbilityUtil's target picks (so melee aim help never snaps to a target it can't hit) and `HitPipeline.resolve()` (the last guard: the hit is blocked). Never inside individual abilities.
- **New hit tag `melee`:** the pipeline adds it to MELEE combo swings (`AttackCombo.attack_style`) and to abilities tagged `melee` (a new standard ability tag). The Knight: **Cleave and Lunge get it.** **Judgement doesn't** (Ryan, 2026-10-01): it is ranged-targeted, `targeting` UNIT with `cast_range` 450 u = 144 px = 4.5 m (`knight_r_judgement.tres`), a CHANNEL that "walks into range first if needed" (`Ability.Targeting.UNIT`). **Cleave Wave doesn't:** it's a projectile (tags `core`, `projectile`; `cast_range` 700 u = 224 px = 7 m, `knight_q_cleave_wave.tres`), which an item's REPLACE (`augment_cleave_wave`) puts on Q.

### 3. Design rule: no unanswerable enemy
- Every elevated enemy has at least one of: a **walk-up route** (ramp or stairs to its perch), a **pull or grapple answer** (an ability that brings it down or the player up), a **ranged answer** (an ability without the `melee` tag that reaches it from floor the player can walk to), or a **dead zone** near its base (it can't attack units closer than a set distance to its perch).
- Every champion has at least one answer to every elevated enemy; a walk-up route counts.
- **The Knight's answers:** walk-up routes (always, where the room has one); **Judgement** (needs walkable floor within 450 u / 4.5 m of the perched enemy, since it walks into range and then channels; on the ultimate's cooldown); **Cleave Wave** (needs the item that gives it; a 7 m projectile that passes over ledges). So a perch the Knight should answer without walking up needs reachable floor within 4.5 m of it. He has no pull.
- Each perch placed in a room notes its answers; P8's sandbox perch has all of them, for testing.

### What A1 cannot do (A2 is the escape hatch)
- **Gravity:** nothing falls by physics. A knock-up over a cliff lands where its 2D displacement ends; falling damage exists only if a rule says so.
- **Height-dependent hit rules** beyond the `elevated` tag: a high-ground bonus, or a parapet that blocks shots from below but not from above. The sim would have to read height.
- **Arcing projectiles over walls:** an arc is only a look. In the sim a projectile either `ignores_walls` or stops at the wall.
- **Overlapping floors inside one room**, or walking under a bridge.
- **True 3D line of sight.**
If the game needs any of these, A2 (a full 3D port) is the escape hatch, and everything the view layer builds carries over.

## Data (Resources)
- **Unchanged:** every `UnitStats`, `Ability`, `AttackCombo`, `StatusEffect`, `ReactionRule`, `SoundEvent`, `HitFeel`, `DamageNumberStyle`, `Talent`, `ChampionData` value.
- **Proposed new data (names to confirm against CONVENTIONS in P1):**
  - The camera's look as a Resource: projection, pitch, visible width, field of view, follow smoothing, shake scale, wall cutaway height. One `.tres` in a new `data/views/` subfolder.
  - The 3D look of a champion: a `model_scene: PackedScene` field on `ChampionData` (champions stay data). Enemies: the same as an export on the enemy scene.
  - `status_airborne.tres` and `status_elevated.tres` in `data/statuses/`; the StatusEffect fields `ignores_tenacity` (default false) and `cleansable` (default true).
  - Collision layer 11, `ledge` (project settings layer name; WORLD_INTERACTION.md's table).
  - Terrain: height and ramp/stair tile data (Elevation, 1b). Room geometry stays in the TileSet if Ryan picks tile-built rooms (Q7; the advisor default).
  - View data for the airborne arc (apex height, Curve in `data/curves/`).

## Architecture / contracts
### Engine facts (verified 2026-10-01)
Sources: the API dumped by the local binary (`Godot_v4.7.2-stable_win64_console.exe --doctool`, version `4.7.2.stable.official.ed1daf0bf`) and the class reference text at the `4.7.2-stable` tag of the Godot repository (`doc/classes/*.xml`). "Spike checks" marks what the reference doesn't state.

1. **2D physics nodes in a tree with 3D nodes: works.** CanvasItem: "properties like transform, modulation, and visibility are only propagated to *direct* CanvasItem child nodes. If there is a non-CanvasItem node in between... the CanvasItem nodes below will have an independent position." A Node2D under a Node3D is therefore a top-level 2D node of its viewport's World2D (`Viewport.world_2d`); its physics lives in that World2D's space.
   - Hiding the 2D world without touching its code: `CanvasItem.visibility_layer` + `Viewport.canvas_cull_mask`. "A Viewport will render a CanvasItem if it and all its parents share a layer with the Viewport's canvas cull mask." Visibility layers are not inherited. So one layer on the room root hides the whole room from the screen.
   - The reference ties no physics behavior to visibility (nothing in CollisionObject2D, CollisionShape2D or Area2D). Spike checks that a hidden CharacterBody2D still collides.
   - `WorldQuery` reads `get_tree().root.world_2d`, so the sim must stay in the root viewport's World2D.
   - Showing ground drawings in 3D: a `SubViewport` can be given the root's `world_2d` (the property is settable) and its own `canvas_cull_mask`, then shown on a floor quad. Sharing a World2D between viewports is a known pattern, but the reference doesn't describe it. Spike checks. A flat quad can't follow slopes, so P0a compares it with Decals and a heightmap-following mesh.
2. **2D audio without a Camera2D: needs one change.** AudioListener2D: "If there is no active AudioListener2D in the current Viewport, center of the screen will be used as a hearing point." Today that "screen center" follows the Camera2D through the canvas transform (`Audio.get_listener_position()` uses the same formula). With no Camera2D the canvas transform stays identity, so the hearing point would stick at world (320, 180) px. Fix: one `AudioListener2D`, `make_current()`, moved to the camera's floor focus point (in px) every physics tick, and `Audio.get_listener_position()` reads `Viewport.get_audio_listener_2d()` when one is current. Panning stays right because the camera never rotates (screen left/right = sim x). AudioListener3D / AudioStreamPlayer3D exist but aren't needed.
3. **3D physics interpolation: available, and already on.** `physics/common/physics_interpolation`: "the renderer will interpolate the transforms of objects (both physics and non-physics)." `Node3D.get_global_transform_interpolated()` exists. **Node2D and CanvasItem have no interpolated getter in 4.7.2** (API dump). So a 3D node that copies a 2D node's position in `_process` gets the last tick's value and judders at 144 Hz. Hence the core rule: copy in `_physics_process` and let the 3D node interpolate. `reset_physics_interpolation()`: call it "after moving the node"; the notification reaches "the node and all children recursively".
4. **Physics-process order: settable.** `Node.process_physics_priority` works like `process_priority`: "Nodes whose priority value is *lower* call their process callbacks first, regardless of tree order." Every sim node is at the default 0, so `WorldView` at a higher value (e.g. 100) syncs after all of them in the same tick. `SceneTree.node_added` ("Emitted when the node enters this tree") lets `WorldView` see every new sim node.
5. **GridMap vs generated meshes.**
   - **GridMap:** a `MeshLibrary` tile is "a mesh with materials plus optional collision and navigation shapes" (per-item navigation mesh and navigation layers). `bake_navigation` makes a navigation region per cell. It has `collision_layer` / `collision_mask`, `get_used_cells()` / `get_cell_item()`, and `make_baked_meshes()` (lightmap UVs). `cell_size` defaults to 2 m (we'd use 1 m). It "can't be hidden or cull masked based on VisualInstance3D.layers". Its collision and navigation are 3D, so under A1 a script would read its cells and build the 2D colliders and 2D navigation from them.
   - **Generated meshes:** a script reads the existing `TileMapLayer` cells (and the height data) and builds floor, wall, pit, ledge and obstacle meshes (MeshInstance3D / MultiMesh) at load, or in the editor with `@tool`. Authoring stays in the 2D tile editor. This is the advisor default (Q7).
6. **Terrain for the floor pick: `HeightMapShape3D` or a trimesh.** `HeightMapShape3D`: "Grid points are spaced 1 unit apart on the X and Z axes" (our 1 m tile corners). "Holes can be punched through the collision by assigning NAN" (pits), "supported in both GodotPhysics3D and Jolt Physics". It "cannot be used to model overhangs or caves" (consistent with 1c). But a 1 m grid can't hold a vertical cliff (it becomes a 1 m slope between two grid points) or stair steps smaller than a tile, so near those its surface differs from the floor mesh. The alternative is a trimesh: `Mesh.create_trimesh_shape()` gives a `ConcavePolygonShape3D` of the actual floor mesh ("intended to work with static CollisionShape3D nodes"; "its use should generally be limited to level geometry"), exact by construction, slower to query. P0a criterion 3 tests both. Either one sits on a view-only 3D layer; a ray from `Camera3D.project_ray_origin/normal()` into it gives the floor pick.
7. **Other checked facts.**
   - Stretch mode `canvas_items`: "3D is unaffected" (3D renders at the 1280×720 window). `viewport` renders everything, UI included, at 640×360.
   - **New in 4.7:** `Viewport.SCALING_3D_MODE_NEAREST` with `scaling_3d_scale` 0.5 renders 3D at half resolution with a crisp nearest upscale, while `canvas_items` keeps the UI sharp. That is the low-res pixel look in 3D without changing the UI.
   - Camera3D: `projection` (perspective / orthogonal), `fov`, `size` (meters, width or height per `keep_aspect`), `project_ray_origin()` / `project_ray_normal()`, `unproject_position()` (unit → screen, for numbers and health bars).
   - Decal: supported on Forward+ (our renderer); projects onto meshes, so it follows slopes. Label3D and Sprite3D (billboards) exist.
   - NavigationServer2D: `map_get_path(..., navigation_layers)`, `region_set_navigation_layers()` and `link_create()` exist. Under A1 ledges already split the 2D navmesh into islands, so terrain needs no separate maps.
   - `CollisionShape2D.one_way_collision` (+ `one_way_collision_direction`) exists, for the optional downward-only ledge.

### Strategy A1: the sim stays 2D (hidden); a 3D view follows it
- **First-pass scope (the review's numbers):** ~1,450 new lines (floor/wall builder ~200, 3D camera ~260, unit views ~300, ground overlay ~120, screen overlay ~150, mapping ~25, floor pick ~40, `view_test` ~350) + ~130 lines in ~12 existing files + 200–400 for rooftops = **1,780–1,980 lines**.
- **Added by the amendments (estimate ~1,300 lines):** heightmap and terrain floor pick (~250); `RoomView` pits, low obstacles, hazards, ledges and cutaway walls (~250); the generic view mechanism and 5 entity views (~300); airborne (~150); `elevated`, perches and the `melee` tag (~120); more tests (~250).
- **Existing files touched: about 18, ~200 lines.** The first 12 (`main.gd`, `player.gd`, `audio.gd`, `game_feel.gd`, `unit.gd`, `vfx.gd`, `champion_data.gd`, the 2 room scenes, the enemy scenes, `project.godot`), plus `status_effect.gd` and `status_component.gd` (tenacity and cleanse exemptions), `movement_component.gd` (airborne mask; the ghosted dash keeps the ledge layer), `ability_util.gd` and `hit_pipeline.gd` (`can_reach`, `melee`), `room.gd` (ledges on layer 11, the bake parses it), and a `view_scene` on `projectile.gd`, the two status VFX scenes and `aura.gd`.
- **Total with the amendments: about 3,100–3,300 lines**, which is about the low end of A2's range below. **Cost doesn't decide between A1 and A2. P0a is the real gate: if it fails, A2 becomes the real option.**
- **Existing tests affected: 0 of 1,782 expected.** The sim's behavior, scenes and API are unchanged (only additions); the view is built by Main, which no test instances. New suite: `view_test`, plus new checks for airborne, `elevated` and ledges.
- **Main risks:**
  1. Two coordinate spaces (px sim, meter view). Mitigated by one mapping (Core rules) and a round-trip test.
  2. Ordering and interpolation. Mitigated by `WorldView`'s physics priority (Engine facts, 4) and the physics-tick sync; P0a measures it at 144 Hz with hitstop.
  3. Views aren't children of their sim nodes, so a sim node's `reset_physics_interpolation()` doesn't reach its view. Proposal: `WorldView` snaps (and resets) any view whose sim node moved farther in one tick than any displacement can (e.g. 64 px; the dash peaks near 23 px a tick). P0a checks it.
  4. The ground overlay (shared World2D) is unverified and flat. P0a compares it with Decals and a heightmap mesh on a slope; fallback: telegraphs and indicators as 3D meshes (~400 lines).
  5. The 3/4-view tricks become wrong in 3D: `body_center` offsets, the 0.55 squash on the hover ring, `Projectile.DRAW_HEIGHT_PX`, y-sort. They move into the view; targeting help that used `get_center()` gets a screen-space pick instead.
  6. Long term, two worlds to keep in step: every world feature needs its 2D footprint and its 3D look. Mitigated by deriving both from one source per room (tile data, Q7).
  7. A newcomer must learn that the "real" world is the hidden 2D one.
  8. What A1 can't do (Elevation, the list above).

### Strategy A2: full port to 3D nodes and Vector3
- **Files touched:** 59 of 99 game scripts (every class b, c and d), all 7 test files, about 14 of 18 scenes, the TileSet (replaced by a MeshLibrary/GridMap), and the 7 data files that hold px values.
- **Lines (first-pass scope):** 896 game lines and 780 test lines carry a 2D marker. With the rewrites (179 lines of 2D drawing become 3D meshes, `WorldQuery` on 3D queries, navigation baked from 3D geometry, `MovementComponent` on CharacterBody3D, the camera, audio), the estimate is **2,000–3,000 changed lines of game code and 800–1,200 of tests: 2,800–4,200**. The amendments add most of the same feature work (airborne, `elevated`, perches, a look for every entity, room features); terrain height is native in 3D, but slopes bring floor snapping and speed-on-slope work.
- **Tests affected: all 6 suites** (1,782 checks; `stats_test`'s checks are stat math, but its scene's bodies must become 3D). Every px assertion ("steps 16 px", "the dash covers 128 px") is rewritten or converted.
- **Data:** every `_px` field is wrong in meters. Renaming them breaks "don't rename"; keeping px means a px ↔ m layer anyway, the same one A1 needs.
- **Main risks:**
  1. Feel drift: `move_and_slide()` on CharacterBody3D under Jolt is a different solver from 2D (corner catching, sliding, safe margin, and on slopes, speed changes unless corrected). The dash, knockback and swing steps are tuned and tested on the 2D solver.
  2. No stable oracle: the tests are rewritten in the same change as the code they guard.
  3. A long branch that freezes T-M, LOOT L1 and everything else, with large merge conflicts.
  4. It replaces `Unit`'s base class and most components (the change policy's ask-first case, for nearly everything at once).
- **What A2 would buy:** one world, no sync; real 3D rays for height (everything in "What A1 cannot do"); GridMap collision and navigation used directly; physics picking.

### Recommendation: A1 (confirmed by Ryan's review, 2026-10-01)
- **Correction:** the first version of this doc said A1 costs "roughly a quarter of A2". Its own numbers don't support that: for the first-pass scope, A1 is about **40–70% of A2** in lines (1,780–1,980 vs 2,800–4,200; about 55% midpoint to midpoint). With the amendments, A1 is about 3,100–3,300 lines, about A2's low end. **Cost doesn't decide it; P0a does.** If P0a fails, A2 becomes the real option.
- **The real reasons:**
  1. **An unchanged test oracle.** The 1,782 checks keep guarding the same sim while the whole view is built. Under A2 the tests and the code they guard are rewritten together.
  2. **No solver feel drift.** The dash, knockback, swing steps and wall sliding stay on the 2D solver they were tuned and tested on, and slopes can't change speed (Goal / feel).
  3. **Reversible at every step.** Each step sits behind Main's flag; a bad step costs turning it off or one revert, not a rewrite.
- The gameplay is already a flat-plane sim (circles, cones and segments on `global_position` plus one line-of-sight ray). Under 3D art that is how League and Diablo work too, so the 2D sim is not a stopgap.
- Escape hatch: if the game ever needs what A1 can't do (Elevation, the list), A2 reuses the whole view layer.

### A1's shape (proposed names; checked against CONVENTIONS in P1, nothing named yet)
- **Vocabulary to add:** **sim** (the gameplay world: the 2D nodes, in px, the source of truth), **view** (the 3D presentation; never changes gameplay state), **floor pick** (the point on the terrain under the cursor), **projection** (perspective or orthographic), **airborne** (knocked up: a status, Elevation 1a), **terrain height** (the view's heightmap, 1b), **ledge** (a cliff edge: a collider on layer 11 `ledge`, 1b), **perch** (an area that makes units `elevated`, 2), **elevated** (the tag, 2). "Level" stays reserved for the champion level and `StatsComponent.set_level()`.
- **Mapping:** `Units.PX_PER_METER` (32.0) with `px_to_m()`, `m_to_px()`, `to_view(p: Vector2, height_m := 0.0) -> Vector3`, `to_sim(p: Vector3) -> Vector2`. A `_m` suffix for meters, as `_px` is for pixels.
- **`WorldView`** (Node3D under Main): environment, lights, camera, the room's look, and every view. `process_physics_priority` above every sim node (e.g. 100); one loop in its `_physics_process` syncs all views after the sim has moved.
- **The generic view mechanism.** A sim node that has a look joins the group `&"view_source"` (like `navigation_source`) and has a `view_scene: PackedScene`. `WorldView` listens to `SceneTree.node_added`, instances the view scene under itself and calls `setup(sim_node)`. The view root extends `EntityView` (Node3D): `sync()` follows the sim node (position through `Units.to_view()`, height from the terrain, facing if the node has one); `on_sim_exited()` runs when the sim node leaves the tree (default: free; a unit finishes its death, a projectile plays its impact). Covered this way:
  - units: `UnitView` extends `EntityView`; `view_scene` from `ChampionData.model_scene` or the enemy scene's export (unit scenes stay untouched until then);
  - projectiles (`Projectile.view_scene`, a default bolt tinted by the ability's `icon_color`);
  - auras (`VFX.aura()` passes one), status VFX (`stun_stars.tscn`, `staggered_mark.tscn` declare theirs; `StatusComponent` already adds them as unit children, so `node_added` sees them);
  - pickups (LOOT.md) and hazards (WORLD_INTERACTION.md) when they're built;
  - presentation hooks: `VFX.spawn_scene()` accepts a scene with a Node3D root and places it through `WorldView`.
  - Without a `WorldView` (every test), nothing spawns: the group and the property do nothing.
- **`RoomView`:** builds the room's look from tile data: floor (with terrain height from P8), cutaway walls (height from the camera Resource, default 1.2 m), pits (holes), low obstacles, ledge faces, and the view-only pick collider for the floor pick (P0a's choice). Hazards get their look through the generic mechanism.
- **`GameCamera3D`** (Camera3D), **`GroundOverlay`** (or Decals, per P0a), **`ScreenOverlay`** (CanvasLayer for damage numbers and health bars, placed with `unproject_position()`).
- **`Main.use_3d_view`** (export, off until the milestone). Canvas visibility layer 2 = "sim" (hidden from the screen), layer 3 = "ground overlay".
- **New subfolders:** `scripts/view/`, `scenes/view/`, `art/models/`, `data/views/` (inside existing top-level folders, so no new top-level folder).

## Build order (proposed; not started)
Every step: Ryan runs `git status` first; the six suites stay at the baseline (all green after "Before P0"), plus `view_test` from P2 on.

**Before P0: a fully green baseline (test isolation).** Planned and approved 2026-10-01, both replaces included, with two additions from Ryan: `_ensure_loaded()` must not latch while there is no current scene, and the real `settings.cfg` is backed up before the cast-mode verification and restored afterward. Two problems, fixed separately.

*Problem 1: the Settings checks read and write Ryan's real `user://settings.cfg`.*
- Cause: `Settings._ready()` loads `user://settings.cfg` with no test-scene guard (`Progress` got one in T4). `abilities_test.gd` (`_test_cast_mode()`, about lines 372–414) sets the cast mode, reads `Settings.SAVE_PATH` to check the saved word, and restores the mode. `audio_test.gd` does the same for volumes (lines 51–52 and 89; the volume checks around 341–361 read `Settings.SAVE_PATH`). So both suites read and write the real file; AB1 fails because the real file already says `quick_with_indicator`. Audio passes only because all of Ryan's volumes are at 100.
- Change, mirroring `Progress` (`progress.gd`: `TEST_SCENES_DIR`, `saving_enabled`, `save_path`, `is_test_scene()`, `_ensure_loaded()`):
  1. `settings.gd`: add `const TEST_SCENES_DIR := "res://scenes/tests/"`, `var saving_enabled := true`, `var save_path: String = SAVE_PATH`, `is_test_scene()` (same body as Progress's), and a private `_ensure_loaded()` that runs once: in a test scene it turns saving off (no read, no write; the defaults stay in memory), otherwise it loads `save_path`. Every getter and setter calls `_ensure_loaded()` first. `load_settings()` and `save_settings()` use `save_path` and do nothing while saving is off. `SAVE_PATH` stays as the default. **Replaced behavior (needs OK):** `_ready()` stops loading the file itself.
  2. `audio.gd`, `_ready()`: `_apply_bus_volumes()` becomes `_apply_bus_volumes.call_deferred()`. Autoloads are ready before the first scene exists, so `is_test_scene()` can't tell yet; deferred, the first Settings read happens once the scene is current (the same moment `Progress` relies on). In play, the saved volumes apply at the end of the first frame instead of during startup, before anything plays. **A one-line replace (needs OK).** **As built: not made; skipped for good (Ryan, 2026-10-01).** Measured while building (a scratch project, Godot 4.7.2): `current_scene` is already set when the autoloads run `_ready()`, both for the main scene and for a scene passed on the command line (how the tests run). So Audio's first Settings read already tells a test run apart and the premise of this replace was wrong. Settings warns once if it's ever read with no current scene (it doesn't latch then).
  3. `abilities_test.gd`, `_test_cast_mode()`: start from a known value (`Settings.set_cast_mode(QUICK)` before connecting the listener), so two emissions are certain. The three save checks switch to a scratch file, exactly like `talents_test.gd`'s `_test_progress_saving_guard()` (lines 928–957): set `Settings.save_path = "user://abilities_test_settings.cfg"` and `saving_enabled = true`, read `Settings.save_path` instead of `SAVE_PATH`, then restore both and delete the file.
  4. `audio_test.gd`, `_test_volumes()`: the same scratch-file pattern for "saved as a whole percent in [audio]".
  5. New checks (abilities AB1): "in a scene under res://scenes/tests/: Settings saving is off" (`[is_test_scene(), saving_enabled] == [true, false]`); "the cast mode starts at the default, QUICK, whatever the real file says" (read in the suite's `_ready()` before any section changes it; on Ryan's machine the real file says `quick_with_indicator`, so this proves the file wasn't read); "the real path stays user://settings.cfg".
- How to verify:
  1. Record the real file's hash (Git Bash: `md5sum "$APPDATA/Godot/app_userdata/uhgame/settings.cfg"`).
  2. Run all six suites headless, one after another: abilities and audio 0 failed (plus the new checks), the rest unchanged.
  3. The hash is unchanged (no write).
  4. With Ryan's OK: back up the real file, set its `cast_mode` to `"quick"`, run abilities again (still green: no read), restore the backup.
  5. Play (F5): the pause menu shows Ryan's saved cast mode and volumes; changing one still saves (it survives a restart).

*Problem 2: the C12 hitstop check reads the clock late.*
- Cause: `combat_test.gd:2610` already has a tolerance (0.06 ± 0.02), but it reads `GameFeel.get_hitstop_left()` (real seconds left) after `_record_hits()` has waited for the swing's recovery. Every real frame since the hit is subtracted from the reading: 0.038 on this run, worse when the machine is busy. The C3 checks avoid this by reading the value inside `swing_landed`, the physics frame of the hit (`_hitstop_at_hit`, lines 629–636).
- Change (test only; no game code):
  1. `_test_c12_data_and_hit()`: read the hitstop at the hit with a `swing_landed` reader like C3's, and check `_check_near("heavy feel: 0.06 s hitstop (read at the hit)", _hitstop_at_hit, 0.06, 0.005)`. 0.005 covers `Time.get_ticks_msec()`'s 1 ms steps, the same tolerance as lines 663 and 665.
  2. The same fragility in `_test_longest_hitstop()` (lines 666–669): two fixed 0.05 s real-time waits against a 0.08 s hitstop; one frame slower than 30 ms fails "still frozen at 0.05 s". Measure instead of assuming: take `t0` with `Time.get_ticks_usec()` right after `hitstop(0.08)`. After the first wait, check "time left = 0.08 − elapsed" (± 0.005), and "still frozen" only when elapsed < 0.075. Then wait frame by frame until it ends and check its length is 0.08 s ± (0.005 + the longest frame seen while waiting): a hitstop can only end on a frame boundary, so one frame is the honest tolerance. Then `Engine.time_scale` is 1.0 again.
- How to verify: run combat 5 times in a row, then once while the other five suites run in parallel (the load that broke it): 0 failures every time, with the same number of checks.
- **Done means:** all six suites green, 1,782 of 1,782 plus the new checks, and the real `settings.cfg` untouched. That is the baseline every later step keeps.
- **Rollback:** revert the commit.
- **Built 2026-10-01, see CHANGELOG.md** (1,788 of 1,788). **Passed** Ryan's F5 check 2026-10-01. The Audio replace (Problem 1, item 2) is skipped (Ryan, 2026-10-01).

**P0 is two throwaway spikes, time-boxed, with no code reuse.** Each starts on its own fresh branch from `main` and is never merged; P0b doesn't build on P0a, and P2+ is written fresh from the doc, never copied from either spike. Time box: about 2 sessions each (one build request plus Ryan's check is a session). If a box runs out, we stop and decide with what we have; we don't extend it silently.

0. **P0a Go / no-go (`spike/3d-p0a`).** One question: can A1 work? Pass criteria, all measured:
   1. **A hidden CharacterBody2D still collides:** a scripted input run along the sandbox's long wall gives identical positions, frame for frame, with the 2D world visible and hidden.
   2. **No stutter at 144 Hz, hitstop included:** walking the long wall, dashing, and a heavy hit's hitstop; the model's on-screen position never jumps or steps back (outside the hitstop near-freeze), no pop when the hitstop ends; a scripted teleport shows no streak (risk 3).
   3. **Floor-pick error < 1 px in both projections, on slopes too:** markers at known sim positions on flat floor, a ramp, stairs, a plateau and next to a cliff; each is projected to the screen, picked back through the terrain (not a flat plane), and compared in sim px; at the screen center and the four corners. **Two pick colliders are tested:** a `HeightMapShape3D`, and a view-only trimesh built from the actual floor mesh (`Mesh.create_trimesh_shape()`). Stairs are steps and cliffs are vertical, which a 1 m height grid can't hold exactly (Engine facts, 6). Keep whichever is exact; if both are, the faster.
   4. **Telegraph and hit agree on a slope:** the elite's slam circle on the ramp drawn three ways (Decal, the shared-World2D overlay, a mesh following the heightmap); the drawn edge vs the true hit edge (unprojected) within 1 px. The winner becomes P7's method.
   5. **Frame time:** under 6.9 ms per frame (144 Hz) on Ryan's PC with the sandbox's units, and with 30 capsule enemies (a big fight) and 50 (the peak; Q14).
   6. **Terrain proof:** a ramp, a stair set and a plateau from tile data; the model's Y follows the heightmap with no pops at tile borders; a ledge (layer 11) blocks walking and the dash but not a projectile (the Bolt test ability) or line of sight (`has_line_of_sight()` across it is true); a fence-like block on layer 7 still lets the dash through.
   - **Go** = all six pass (for 4, at least one method passes). **No-go** = stop and re-plan (A2, or stay 2D).
   - **Tests:** the six suites on the spike branch stay at the baseline (proof the spike didn't touch the sim). **Rollback:** delete the branch.
1. **P0b Feel (`spike/3d-p0b`, fresh from `main`).** One question: what should it look like? Toggles: orthographic / perspective, pitch 50 / 60 / 70°, visible width 20 / 24 / 28 m, 3D render 640×360 nearest vs 1280×720, wall height (0.6 / 1.2 / 2.4 m cutaway), **fading tall buildings and plateaus** that stand between the camera and the player (on / off; walls cut down is a separate toggle), smooth turning vs 8 directions. **One real rigged model** from a free CC0 pack (for example KayKit's adventurers or a Quaternius pack; the licence is checked and Ryan approves the download first) with idle, run and attack driven by the existing signals (moving → run, `swing_started` → attack, else idle). **Done means:** Ryan answers the camera and art questions from what he saw. **Rollback:** delete the branch.
2. **P1 Decisions and docs.** Ryan's answers → DECISIONS.md rows; `docs/3D.md` written from this doc; the Doc edits below. **Done means:** Ryan approves 3D.md. **Tests:** none (docs only). **Rollback:** revert the docs commit.
3. **P2 Scaffolding (no visible change).** The mapping in `units.gd`, the folders, an empty `WorldView` scene (with its physics priority), `Main.use_3d_view` (off), `view_test` (mapping round trip; floor pick on a fixed camera). **Done means:** `view_test` passes; the game is exactly today's with the flag off. **Rollback:** revert the commit (new files plus one export).
4. **P3 Room look and light.** `RoomView` builds floors, cutaway walls, pits, low obstacles and ledge faces from tile data (flat until P8), plus environment, a directional light and shadows. Flag on: the 2D world is hidden from the screen (layer 2 + the root's cull mask), not from physics. **Done means:** the sandbox shows the lit 3D room, and walking and collisions are exactly as before. **Rollback:** flag off, or revert.
5. **P4 Camera and listener.** `GameCamera3D` with all of `GameCamera`'s behavior (lock on Y, hold C, edge and arrow pan, aim lean with dead zone, curve and hold time, room bounds, shake through `GameFeel.shake()`, `snap_to_target()` with interpolation resets), its look from the camera Resource; the AudioListener2D follows the focus. **Done means:** Ryan's camera checklist (MOVEMENT.md, Architecture 4) feels the same; sounds pan and fade with distance. **Rollback:** flag.
6. **P5 Aim.** `Player.get_aim_point()` returns the floor pick when a view exists, else the mouse as today; the 10 direct mouse calls in `player.gd` go through it (**approved 2026-10-01**). The enemy under the cursor is picked in screen space. **Done means:** every Knight ability and the VECTOR test abilities land where the cursor touches the floor, in both projections; **when the cursor is over an enemy, the aim is that enemy's feet** (its `global_position`). **Rollback:** flag (the fallback path is today's code).
7. **P6 Views.** The generic view mechanism (`view_source`, `EntityView`) and `UnitView` with placeholder models: position, facing, hit flash (from `damaged`), death (from `died`, finishing after the Unit is freed), dash ghosting, walk bob, swing and cast poses from the existing signals and presentation hooks; then projectile, aura and status-VFX views. The 2D `Body` stays, hidden. **Done means:** a 144 Hz play test with no stutter; the Knight's combo, Lunge and Judgement read; slimes, the elite, Iron Resolve's aura, the stun stars and the staggered mark all show. **Rollback:** flag.
8. **P7 Floor and floating UI.** Telegraphs, indicators and hover rings on the floor (the method P0a picked); damage numbers and health bars on `ScreenOverlay`; `VFX.spawn_scene()` accepts 3D presentation-hook scenes; `Unit._add_number()` gets the overlay path while the old path stays. **Done means:** the elite slam's fill matches its hit; numbers read well at the chosen size. **Rollback:** flag.
9. **P8 Terrain and airborne.** Built from Elevation 1–3: height and ramp/stair tile data and the heightmap (view only); ledges derived at load on layer 11 (`ledge`), with the navigation bake parsing layers 1 and 11; the ghosted dash keeps layers 1 and 11 (approved one-line replace, `movement_component.gd:271`); `status_airborne` (with `ignores_tenacity` and `cleansable` false), the airborne mask rule (drops 6, 7 and 11) and landing; `status_elevated`, perches, the `melee` tag (Cleave, Lunge, MELEE swings; not Judgement or Cleave Wave) and `AbilityUtil.can_reach()` in its two places; the airborne arc in the view. The sandbox gets a ramp, stairs, a plateau, a pit, a fence, and a perch with a sniper dummy that has every answer (walk-up route, walkable floor within 4.5 m for Judgement, a test pull ability, a dead zone); a test knock-up ability (the player's). **Done means:** the Knight walks up and down ramps and stairs; the dash stops at a cliff edge but crosses the fence; a knock-up carries a slime off the plateau (no fall damage) and into the pit (the pit rule); a cleanse doesn't end a knock-up; melee can't hit the perched sniper from below but can from the perch; Judgement reaches it from the floor below (its walk-into-range stops at the nearest reachable spot in range, not on the perch's navigation island); Cleave Wave reaches it; the dead zone works; no enemy knocks up the player. **Tests:** the baseline plus new checks (airborne: tags, blocks, tenacity, cleanse, i-frames, unstoppable, mask; `can_reach`; ledges vs walking, dashes, projectiles and line of sight; Judgement's walk-into-range across a ledge). **Rollback:** revert the step.
10. **P-M Milestone.** The flag defaults to on; the sandbox and `room_01` play fully in 3D; Ryan's feel play test at 144 Hz (dash 128 px = 4 m, Cleave, Lunge, Judgement, the slam, a knock-up, the camera lean, sounds). Only then, asked separately: disable and later delete the 2D placeholder visuals, the old Camera2D node, the flag. **Rollback:** the flag back to off.

Not in this plan: the art pass (real models, animation, lighting mood), which needs Ryan's art answers and gets its own plan.
**Done means (whole pivot):** the game plays in 3D at the chosen angle, with terrain and knock-ups, every feel number unchanged and every existing check still green.

## Doc edits needed (after Ryan's answers, in P1)
| Doc | Change |
|---|---|
| VISION.md | One sentence and Scope (wording below); Cross-cutting: terrain height, knock-ups, perches and "no unanswerable enemy". |
| CLAUDE.md | The game (fixed-angle 3D view); Tech facts ("2D top-down 3/4 view, pixel art" → the sim in 2D px, the view in 3D meters, 1 m = 32 px = 100 u; stretch and 3D scaling settings; physics interpolation in 3D; the sim never reads height; navigation also in `AutoAttackComponent`); Project layout (new subfolders); Architecture (sim vs view, the generic view mechanism); Docs index (+3D.md); Current status. |
| CONVENTIONS.md | Units row (`_m` for meters); vocabulary (sim, view, floor pick, projection, airborne, terrain height, ledge, perch, elevated); reserved names (A1's shape); the group `view_source`; ability tag `melee` (and hit tag `melee`); status tags `airborne`, `elevated`; collision layer 11 `ledge`; visibility layers 2 and 3; "the view never changes gameplay state" next to the VFX rule. |
| MOVEMENT.md | Title drops "2D"; "8-direction sprites" → smooth turning (Q6); Camera (Architecture 4) → GameCamera3D, perspective with a narrow field of view, 60° pitch; F1 → the physics-tick sync rule; Facing and aim → the floor pick (aim at an enemy's feet under the cursor); the dash stops at ledges (layer 11), not fences; the open question on vertical speed → the foreshortening note (accepted, Q11); slopes don't change speed. |
| COMBAT.md | Status effects: `status_airborne` (tags, blocks, no tenacity, i-frames, unstoppable, not cleansable, the dash-cancel exception, not on the player in v1), `ignores_tenacity`, `cleansable`; "tenacity shortens crowd control" gets "except airborne"; the `melee` hit tag (not on Judgement or Cleave Wave) and the `elevated` filter in the hit pipeline; telegraphs (still exact circles; the camera shows them as ellipses; decals on slopes); damage numbers and health bars (screen overlay); hit flash (a 3D material); shake (camera offset in screen px). |
| WORLD_INTERACTION.md | Title drops "2D"; collision layers 1–10 unchanged (sim); **new layer 11 `ledge`** in the table ("cliff edges, derived from terrain height at room load: block walking and dashes, not projectiles or line of sight"), and layer 7 stays fences and rubble; the ghosted-dash note becomes "masks world and ledges while it runs (`collision_mask & (1 | 1024)`): pits, fences and units are ignored"; walking masks gain 11; a new Terrain section (Elevation 1b, 1c, 2, 3, perches, "what A1 cannot do"); the airborne mask rule (drops 6, 7, 11) next to the pit rule; no fall damage; "3/4 depth" (approved 2026-09-30) superseded: depth buffer instead of y-sort, cutaway walls; the Hazard spec gets the "while inside" status option (perches). |
| AUDIO.md | Listener (an AudioListener2D following the camera focus); `max_distance_px` 480/640 was "the screen is 640 wide": re-measure for the new visible width; panning unchanged (the camera never rotates). |
| ABILITIES.md | Indicators on the floor (P0a's method); `Projectile` height in the view and its `view_scene`; presentation hooks accept 3D scenes (`cast_anim` / `swing_anim` drive the model); aim and the VECTOR start point use the floor pick; the standard tag `melee`; knock-up abilities (a knockback plus `status_airborne`). |
| `_TEMPLATE.md` | A new **View** section after "Architecture / contracts": `<!-- How this system looks in 3D: which sim nodes declare a view_scene, what the view shows (model, animation, decal, overlay, sound), which signals drive it, and its debug_draw. The view never changes gameplay state. "None" if it has no look. -->` |
| PROMPTS.md | Its "Design a new system" interview gets a matching question: "What does it look like in 3D? Which parts need a model, a floor decal or an overlay, and what drives them?" (PROMPTS.md is Ryan's playbook; Claude hasn't read it, per CLAUDE.md, so where the question goes is set when it's edited.) |
| UI.md (future) | Implication: a 3D paper-doll preview (the champion's model in the inventory and the hub, in its own SubViewport and own 3D world, showing equipped items); the screen overlay's numbers and bars move under UI.md. |
| ENEMIES_AI.md (future) | Implications: elevated archers and snipers (perches, dead zones, target choice through `can_reach`); the `Sight` ray stays on layer 1, so ledges don't block sight; navigation per height comes free, because ledges split the 2D navmesh into islands (a perched unit paths only on its island; with no route to the player it holds or repositions); no unanswerable enemy as an AI design check. |
| DECISIONS.md | A new "3D view" section: the pivot and its givens (2026-10-01), the added terrain givens, A1 vs A2 and the corrected cost (P0a is the gate), the scale, P5's approved replace, the ledge layer 11, Judgement not `melee`, no enemy knock-ups on the player in v1, every interview answer, the order of work. (The test-isolation fix gets its own row when it's built.) |
| `docs/3D.md` (new) | The lasting spec: sim/view split, mapping, camera, `RoomView`, the generic view mechanism, overlays, Elevation 1–3, build steps. Written from `_TEMPLATE.md`. |
| Also touched lightly | CHAMPIONS.md (`ChampionData.model_scene`), LOOT.md (pickups declare a `view_scene`; their Area2D stays in the sim), STATS.md (no change). |

**VISION, proposed one sentence:** "A fixed-angle 3D action looter under a League/Diablo-style camera, where you pick a champion with a League-style kit, move and fight with Hades-level precision, and dive through Diablo-style dungeons collecting gear that changes *how your abilities play*, not just how big the numbers are."
**VISION, proposed Scope "In":** "single-player; a fixed-angle 3D view (the camera follows the player and never rotates); gameplay decided on a flat floor, while the terrain shows real height (stairs, ramps, hills, plateaus); knock-ups; no jumping; floors that overlap are separate rooms; 3D models rendered at 640×360 for a pixel look, with real lighting; multiple champions (Knight first), hand-made rooms stitched into dungeons, gear with affixes and augments."

## Open questions
### Interview for Ryan (plain language)
1. **How steep is the camera?** Steep, looking mostly down (you see the floor clearly and walls hide little; League feels like this), medium (Diablo IV), or lower (more dramatic and the buildings look tall, but walls hide more and "up the screen" looks slower). The P0b spike lets you flip between 50°, 60° and 70°.
2. **Should far things look smaller?** "Perspective" is a real camera: the top of the screen is a bit smaller, hills and plateaus look tall, it feels more 3D (League and Diablo work this way). "Flat" (orthographic) keeps every size and distance the same everywhere on screen, like a board game seen at an angle; skill-shot ranges read the same in every corner. The spike has a toggle.
3. **How much more of the world?** Today you see 20 × 11 tiles. A little more (about +25%), a lot more (+50–100%), or a zoom you control with the mouse wheel? More world also means everything is drawn smaller.
4. **What should it look like?**
   - (a) Smooth 3D models at full resolution (League, Diablo IV).
   - (b) 3D models drawn at the old low resolution, so it still looks like pixel art, with real lighting.
   - (c) Pixel-art sprites standing in a lit 3D world (Octopath Traveler's "HD-2D").
   - (d) 3D models turned into sprite sheets ahead of time (how Hades and Diablo II made their characters).
   - "Easier animation" mostly comes with (a) and (b): one model animates in every direction; (c) still needs every direction drawn by hand.
5. **Who makes the 3D art?** You, bought or free asset packs, or a commission? Until then, are grey boxes and capsules OK?
6. **Turning:** should characters turn smoothly to any angle (natural for models), or snap to 8 directions like the old sprite plan?
7. **How do you want to build rooms?** Keep painting flat tiles (now with a height per tile, plus ramp and stair tiles) and let the game build the 3D room, or build rooms in 3D from a kit of blocks, like Lego or Minecraft (you see the real room while building, but it's more work per room)?
8. **Height, enemies up high, and knock-ups.** The proposed rules, in short:
   - **Most of the time, height is looks.** Cliffs and ledges stop walking, but not arrows, spells or sight; if you're close enough on the map, you hit, melee included. Ramps and stairs take you up and down, at normal speed. OK?
   - **Special "perched" enemies** (a sniper on a tower) are the exception: melee can't reach them from below. For each one, the room gives at least one answer: a way to walk up, a pull or grapple, a ranged ability that reaches it from below, or a blind spot right below where it can't shoot you. The Knight's answers: walking up; **Judgement** (it isn't melee: you target the enemy and it walks you into range, 4.5 m, so the room needs floor you can reach within 4.5 m of the perch); **Cleave Wave** when an item gives it (a 7 m wave that flies over ledges). He has no pull.
   - **Knock-ups:** a knocked-up enemy can't act until it lands; tenacity doesn't make it shorter (League's rule); dashing doesn't get you out. Should a cleanse (an item or ability that removes crowd control) end a knock-up? League says no.
   - **Enemies knocking you up:** proposed none in v1 (you never lose control without a clear reason); only telegraphed boss attacks might, later. OK?
   - **Can a dash climb a cliff?** Today your dash (and Lunge) passes over anything low, like fences. If cliff edges count as "low", a dash would take you up or down any cliff. Proposed: cliffs stop dashes, fences don't (Elevation 1b, option b).
   - **Knocking enemies off things:** a knock-up can carry an enemy over a ledge or a pit. One falling into a pit dies (the existing pit rule). One knocked off a cliff just lands below with no extra damage, unless you want "fall damage" as a rule.
9. **Things in front of you.** Walls can always be cut down low (about 1.2 m) so they never hide you. Tall things that aren't walls, like a building or a plateau between the camera and you: should they fade out while you're behind them (Diablo), stay solid and show your outline through them, or stay solid with nothing (keep the camera steep enough that it rarely matters)? P0b has a fade toggle so you can see it.
10. **Lighting mood:** dark dungeons lit by torches (Diablo), or bright and easy to read (League)? Readability (telegraphs, enemies) stays first either way (VISION, decision priorities).
11. **"Up the screen looks slower."** With a tilted camera, walking or dashing up and down the screen looks 6–23% shorter than sideways, depending on the angle (the game numbers don't change). OK as is, or should we prefer a steeper camera to keep it small?
12. **When?** Before or after the T-M play test? LOOT L1 (item data and rolling) doesn't touch the view, so it can go either side.
13. **Floors on top of each other.** Do you need fights where one floor is above another in the same room: a bridge with enemies walking under it, a balcony over a hall, a two-story building? A1 can't do that inside one room; it can as separate rooms joined by stairs or a door.
14. **Big fights.** In the biggest fights, how many enemies should be on screen at once: about 10, 30, or 100 and more (Diablo-style hordes)? It sets the P0a stress test and the art budget per enemy.

### Interview answers (Ryan, 2026-10-01)
Q1–12: "use the advisor defaults"; Q8, Q13 and Q14 answered in his own words. These go to DECISIONS.md in P1. P0b can still change the look answers (1–4, 6, 9) once Ryan has seen them.

| Q | Answer |
|---|---|
| 1 | 60° pitch |
| 2 | Perspective with a narrow field of view |
| 3 | About +50% view (at 60°, roughly 23 m wide) |
| 4 | (b) low-res 3D: 3D models rendered at 640×360 with real lighting |
| 5 | Asset packs, with capsules until the art pass |
| 6 | Smooth turning |
| 7 | Tile-built rooms, with the 3D generated from them |
| 8 | The terrain and knock-up rules as written (Elevation 1–3). A cleanse does **not** end a knock-up. Cliffs stop dashes (ledges on layer 11). No fall damage for now. Enemies don't knock up the player in v1 (the design note, 1a); telegraphed boss knock-ups stay a question for ENEMIES_AI.md |
| 9 | Cutaway walls (the advisor default, given before Q9 was reworded); whether tall buildings and plateaus also fade is decided from P0b's toggle |
| 10 | Readable lighting |
| 11 | Accept the foreshortening |
| 12 | T-M play test first |
| 13 | No overlapping floors in one room; separate floors are separate rooms |
| 14 | About 30 enemies in a big fight, 50 at the peak (P0a's stress test uses both) |

### Technical (Claude answers these in the spikes, not Ryan)
- Does a SubViewport sharing the root's World2D render the overlay correctly, and is it cheap enough? Decal vs overlay vs heightmap mesh on a slope (P0a, 4).
- Does a hidden CharacterBody2D still collide? (Expected yes; P0a, 1.)
- Does the physics-tick sync after the sim remove all stutter at 144 Hz, with hitstop (`Engine.time_scale` 0.05)? Does the teleport snap threshold (risk 3) catch every teleport without false snaps during dashes?
- Floor-pick accuracy on terrain near the screen edges, `HeightMapShape3D` vs a trimesh of the floor mesh at stairs and cliffs (P0a, 3); what happens above the horizon at a low pitch.
- Which tile data carries height (a custom data layer vs a `Height` TileMapLayer), and does deriving ledges at load stay exact at diagonal cliff corners?

### Doc conflicts found (to settle in P1)
- The Givens conflict with VISION.md ("2D pixel art at 640×360", the one sentence), CLAUDE.md Tech facts ("2D top-down 3/4 view. Pixel art"), MOVEMENT.md ("The plan is 8-direction sprites") and WORLD_INTERACTION.md "3/4 depth" (y-sort, approved 2026-09-30). These docs stay as they are until Ryan answers; the edits are listed above.
- ~~Ryan's amendment put ledges on layer 7, but the ghosted dash ignores layer 7 by design, so dashes would climb cliffs.~~ Resolved 2026-10-01: ledges get layer 11 (Elevation 1b); layer 7 stays as WORLD_INTERACTION.md planned it.
- WORLD_INTERACTION.md's layer table ends at 10 and its ghosted-dash note says the dash masks world only; both change with layer 11 (Doc edits). Its approved Hazard spec ("entering applies its status") needs a "while inside" option for perches.
- COMBAT.md says tenacity shortens crowd control and a cleanse removes `cc`; airborne is the first exception to both.
- CLAUDE.md says AI pathing uses NavigationServer2D "in `MovementComponent`"; `AutoAttackComponent` also queries it (a closest-point check). Minor; fix with the CLAUDE.md edit.
