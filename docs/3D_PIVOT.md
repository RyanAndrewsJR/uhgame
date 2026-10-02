# 3D_PIVOT.md: Evaluating the move from 2D to a fixed-angle 3D view
<!-- Evaluation written 2026-10-01. Nothing here is built and nothing is decided beyond the Givens.
     When Ryan answers the interview, the decisions go to DECISIONS.md and the lasting spec to a new docs/3D.md;
     this doc then becomes the record of how the choice was made. -->

**Read when:** deciding on or building the 2D → 3D view change, running the spike, or asking how a piece of 2D code maps to 3D.
**Depends on:** CLAUDE.md, VISION.md, CONVENTIONS.md, MOVEMENT.md, COMBAT.md, WORLD_INTERACTION.md, AUDIO.md, ABILITIES.md.
**Used by:** the future `docs/3D.md`, and every doc listed under Doc edits.
**Status:** waiting for Ryan's answers (Open questions, Interview). No step started.

## Givens (decided by Ryan; not re-asked here)
- Target: a League/Diablo-style fixed-angle 3D camera. Rotation locked, follows the player. 3D models and lighting. Gameplay stays on a flat ground plane. No player jump. Some terrain verticality (e.g. enemies on rooftops).
- Why: the player sees more of the world, and lighting and animation get easier.
- Unchanged: the pillars, game feel, and every gameplay number (League units, STATS.md). Data in Resources, signals up and calls down, the additive change policy, disable before deleting, ask before removing.
- No new name uses the word "proc" (CONVENTIONS.md already defines it).

## Current code
### Baseline (measured 2026-10-01 on clean `main`, d8429ea)
- `git status`: clean.
- **106 `.gd` files, 26,032 lines.** Game code: 99 files, 14,473 lines. Tests: 7 files, 11,559 lines (6 suites + `hook_vfx_probe.gd`).
- 18 `.tscn`, 96 `.tres`. Only 2 rooms exist (`room_01.tscn`, `sandbox.tscn`).
- **Tests: 1,780 of 1,782 checks pass** (headless, run one after another):

| Suite | Result | Note |
|---|---|---|
| stats | 179 / 179 | |
| combat | 458 / 459 | FAIL "heavy feel: 0.06 s hitstop (got 0.038)": the known real-time hitstop timing check that also fails on clean HEAD |
| abilities | 558 / 559 | FAIL "AB1: emitted as cast_mode": the test assumes the saved cast mode isn't QUICK_WITH_INDICATOR; Ryan's `user://settings.cfg` has `cast_mode="quick_with_indicator"`, so the first set changes nothing and emits once, not twice. A test-isolation issue, not a code bug |
| audio | 109 / 109 | |
| champions | 168 / 168 | |
| talents | 308 / 308 | |

"Baseline" in the build order below means these numbers: 1,780 pass, and these same 2 fail.

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
**(a) Pure logic, no change (39 files).** Autoloads `events`, `progress`, `reactions`, `settings`; components `health`, `resource`, `stats`, `status`; 25 data scripts (`ability_augment`, `apply_status_gameplay_effect`, `audio_mix`, `champion_data`, `champion_leveling`, `charge_scaling`, `conditional_bonus`, `damage_scaling`, `deal_damage_gameplay_effect`, `gameplay_effect`, `heal_gameplay_effect`, `hit_feel`, `modify_cooldown_gameplay_effect`, `passive`, `remove_statuses_by_tag_gameplay_effect`, `restore_resource_gameplay_effect`, `status_effect`, `stat_definition`, `stat_modifier`, `stat_registry`, `stat_scaling`, `talent`, `talent_requirement`, `toolkit_bundle`, `unit_stats`); `sandbox_abilities`, `sandbox_augments`, `sandbox_reactions`, `sandbox_talents`; `champion_progress`; `ui/hud`. (`hit_feel.gd`'s shake numbers are screen px; they keep working if the 3D camera reads them as screen px.)

**(b) Logic with px / Vector2 math, no 2D node type (31 files).** `ability.gd` (also draws indicators), `ability_util.gd`, `cast_context.gd`; the 5 Knight ability scripts, `slime/slam.gd`, the 8 test abilities; `combat_sounds.gd`, `hit_context.gd`, `hit_pipeline.gd`; `ability_component.gd`, `auto_attack_component.gd` (also one NavigationServer2D query and a debug Node2D); `units.gd`; data `attack_combo`, `attack_swing`, `cast_ability_gameplay_effect`, `condition`, `knockback_gameplay_effect`, `reaction_rule`, `sound_event`; `player_input.gd`. Some create Telegraphs/VFX nodes, but their own math is plain Vector2.

**(c) Bound to a 2D node type or a 2D server (14 files).** `unit.gd` (CharacterBody2D), `player.gd` (mouse, `SwordPivot`, `_draw`), `enemy.gd` (`RayCast2D`), `movement_component.gd` (Node2D; drives the CharacterBody2D; NavigationServer2D), `dash_component.gd` (Node2D only for its debug draw), `hitbox.gd`, `hurtbox.gd` (Area2D), `projectile.gd` (Node2D that is both sim and drawing), `world_query.gd` (the root World2D), `audio.gd` (AudioStreamPlayer2D; listener from the canvas transform), `game_feel.gd` (`get_camera_2d()`), `game_camera.gd` (Camera2D), `room.gd` (TileMapLayer, NavigationRegion2D), `main.gd` (Node2D, Camera2D, TileMapLayer).

**(d) View / visual only (15 files).** World-space: `vfx.gd`, `telegraph.gd`, `aura.gd`, `staggered_mark.gd`, `stun_stars.gd`, `movement_vfx_component.gd`, `damage_number.gd`, `health_bar.gd`, data `damage_number_style.gd` (screen px). Screen-space UI, unaffected by any 3D choice: `ability_bar`, `passive_slot`, `resource_bar`, `hub`, `pause_menu`, `talent_screen`.

**Tests.** 5 suites (`abilities`, `audio`, `champions`, `combat`, `talents`) and `hook_vfx_probe` extend Node2D: class (c). `stats_test.gd` extends Node, but its scene holds two CharacterBody2D.

### Choke points
- **League units → px: yes, one choke point.** `Units.to_px()` is the only conversion; `PX_PER_UNIT` (0.32) appears nowhere else. 46 game call sites in 20 files.
- **px authored directly: named, but scattered.** 25 `@export` `_px` fields in 15 scripts, 13 px values in 7 data/scene files, 3 `const *_PX`, about 6 bare thresholds. The `_px` suffix (CONVENTIONS) makes every one findable.
- **Two kinds of px are mixed today, and 3D splits them.** *Ground px* (ranges, knockback, lunge, radii, sound distance) are distances on the floor. *Screen px* (camera lean 80, edge margin, shake, damage number rise/spread, walk bob, health bar width) are distances on the 640×360 screen. In 2D they are the same scale; with a tilted 3D camera they are not.
- **Mouse aim: a choke point exists but is bypassed.** `Player.get_aim_point()` (`player.gd:588`) returns the mouse, but 10 of the 11 `get_global_mouse_position()` calls in `player.gd` call the mouse directly.
- **Camera:** one class (`GameCamera`), one lookup (`GameFeel.shake()`), one setup (`main.gd`).
- **World queries:** `WorldQuery` (2 methods), 2 navigation calls, 1 RayCast2D. Every hit test is plain math on `global_position` (`AbilityUtil.in_circle / in_cone / along_segment`, edge distances) plus one line-of-sight ray. **The sim is already a flat-plane sim**, which is what League and Diablo compute under their 3D art.
- **Audio:** one place (`Audio` autoload).
- **Drawing:** 179 lines in 21 files; the ground drawings (indicators, telegraphs, hover ring) are the ones a 3D view must show.

### How the code is built today (task 3)
**Units and their visuals.** A Unit scene is one `CharacterBody2D` root holding both the sim and the visuals:
- Sim children: `CollisionShape2D` (circle at the feet), `Hurtbox` (Area2D, dormant), the components (`StatsComponent`, `StatusComponent`, `HealthComponent`, `ResourceComponent`, `AutoAttackComponent`, `MovementComponent`, `AbilityComponent`, `PlayerInput`, `DashComponent`), `Sight` (enemies).
- Visual children: `Shadow` (Polygon2D), `Body` (Node2D of Polygon2Ds), `SwordPivot/Sword` (Player), `HealthBar` (Node2D `_draw`), `MovementVFXComponent` (deforms `Body` only while a frame draws).
- **Can the sim be separated from the visuals? Yes, with small work.** The sim never reads visual state back, except in these 6 places:
  1. `Unit._play_death()`: the Unit is freed by the end of the body's death tween (0.33 s), so the free time lives in a visual tween.
  2. `Unit.get_center()` = `global_position + body_center` (a 3/4-view "height" offset, e.g. `(0, -15)`): used by targeting help (`AbilityUtil.nearest_enemy_to`, `Unit.contains_point` for the enemy under the cursor) and by damage number placement.
  3. `Unit._add_number()`: damage numbers are Labels added to the unit's parent Node2D.
  4. `Player._draw()` draws ability indicators through `Ability.draw_indicator()`; tests read `_drawn_indicator_slot` / `_drawn_vector_start`.
  5. `Player.face()` aims from `sword_pivot.global_position` (visual only, but on the player script).
  6. `Projectile` is one Node2D that moves, hits and draws itself.
- The signals a view needs already exist: `died`, `damaged`, `health_changed`, `swing_started / landed / cancelled`, `cast_started / finished`, `dash_started / ended`, `Events.unit_hit`. Facing lives on Player (`facing`, `get_facing_octant()`). The presentation hooks (`cast_anim`, `swing_anim`, `cast_vfx`, `impact_vfx`, `swing_vfx`; ABILITIES AB14) were built for an art pass.

**How tests build scenes.** The 5 Node2D suites instance the real `player.tscn`, `slime.tscn`, `slime_elite.tscn`, `sandbox.tscn`, `hud.tscn`, `hub.tscn` and `pause_menu.tscn` under their own Node2D root; place units with Vector2; build walls from `StaticBody2D` + `RectangleShape2D`; spy on shake with a scripted `Camera2D`; drive input through `Input.action_press()` and `player_input._unhandled_input()`; and wait on physics frames. They touch visuals in few places: damage-number Labels (about 30 lines, combat), `_drawn_*` (8), Telegraph nodes (8), `body`/`modulate` (8), the sword (5). No test instances `main.tscn`.
- **Survive unchanged under A1 (below): all 6 suites,** as long as the unit scenes keep their 2D roots, the 3D view attaches from outside (Main), and aiming falls back to the mouse when there is no 3D view (`abilities_test.gd:3502` computes an expected point from `get_global_mouse_position()`).
- **Under A2: none survive unchanged.** Every suite's fixtures (Vector2 positions, 2D walls, Camera2D spies, CharacterBody2D roots) change; 780 test lines carry a 2D marker.

**2D-specific values in `.tres` / `.tscn`.**
- Scenes: 2D node types in `player`, `slime`, `slime_elite`, `main`, both rooms, the two VFX scenes and the test scenes. Values: `body_center` (player `(0, -15)`, slime `(0, -10)`), HealthBar positions (`(0, -44)`, `(0, -32)`), Hurtbox shape offsets, collider radii (11, 14), placeholder polygons, room entity positions and `PlayerSpawn` (px), tile data, `y_sort_enabled`.
- TileSet `dungeon_tileset.tres`: 32 px tiles, square physics polygons on physics layer 0 → collision layer 1.
- Ground px in data (stay valid as sim px under A1): `combo_knight.tres` (`knockback_px` 16/20, `lunge_px` 16/10, `lunge_max_px` 32/32), `knight_q_cleave.tres` (`hit_knockback_px` 17), `slime_elite_q_slam.tres` (`radius_px` 72, `knockback_px` 20, and "{radius_px} px" in its description), `test_q_strike.tres` (description), `sound_slime_elite_slam_telegraph.tres` (`max_distance_px` 640), `talent_knight_whirling_cleave.tres` (stat `hit_knockback_px`), `slime.tscn` (`hit_knockback_px` 12, `walk_bob_px` 0).
- Screen px in data: `hit_feel_default.tres` (shake), `damage_number_style_default.tres` (`rise_px`, `spread_px`), camera exports in `main.tscn`.
- Not spatial: the Curve `.tres` files (their Vector2 are curve points). League units in `UnitStats` and abilities: unaffected by any strategy (Givens).
- Project settings: renderer **Forward Plus**, `d3d12` on Windows, 3D physics engine already **Jolt**, `physics_interpolation` on, stretch `canvas_items`, 2D physics layer names 1–5.

## Goal / feel
- **Proposed scale: 1 m = 1 tile = 32 px = 100 League units.** It falls out of `PX_PER_UNIT` = 0.32. Checks: the Knight's 375 MS = 120 px/s = 3.75 m/s (a jog); the dash 128 px = 4 m; `gameplay_radius` 65 u = 0.65 m.
- **Every gameplay number stays as it is.** Under A1 the sim keeps its px values; the view converts them for display only.
- **Smoothness:** no visible stutter walking along the sandbox wall or dashing, at 60 Hz and at Ryan's 144 Hz (the F1 bar, MOVEMENT.md).
- **What "see more" costs on screen.** Today the screen shows 20 × 11.25 tiles = 225 tiles² of floor. With an orthographic camera, screen height H = width × 9/16 and floor depth = H / sin(pitch):

| Visible width | Pitch 50° | Pitch 60° | Pitch 70° |
|---|---|---|---|
| 20 m (today's width) | 294 tiles² (+31%) | 260 (+15%) | 239 (+6%) |
| 24 m | 423 (+88%) | 374 (+66%) | 345 (+53%) |
| 28 m | 576 (+156%) | 509 (+126%) | 469 (+109%) |

  A wider view also draws everything smaller: at 24 m, a tile is 26.7 screen px instead of 32 (−17%). Perspective shows more floor at the top of the screen and less at the bottom than this table.
- **Up and down the screen looks slower.** The floor is tilted away, so north–south distances look shorter by sin(pitch): 0.77 at 50°, 0.87 at 60°, 0.94 at 70°. At 60° and today's width, the 128 px dash north covers about 111 screen px, east 128. The numbers don't change; only how they look. (MOVEMENT.md's open question "scale vertical speed for the 3/4 view?" becomes this.)

## Core rules (hold whichever strategy is chosen)
- **The sim decides, the view shows.** Like VFX and sound events, the 3D view never changes gameplay state.
- **One mapping.** Sim px ↔ view meters go through one pair of functions next to `Units.to_px()`. No other code multiplies or divides by 32.
- **Positions copy on the physics tick.** A view node copies its unit in `_physics_process`, after the sim has moved, and 3D physics interpolation smooths it. Never in `_process` (Engine facts, 3).
- **Additive and switchable.** Until the milestone, the 3D view sits behind a flag on Main; with it off, the game is exactly today's.
- **Headless tests never build the view.** Every existing check keeps running against the same sim.

## Data (Resources)
- **Unchanged:** every `UnitStats`, `Ability`, `AttackCombo`, `StatusEffect`, `ReactionRule`, `SoundEvent`, `HitFeel`, `DamageNumberStyle`, `Talent`, `ChampionData` value.
- **Proposed new data (names to confirm against CONVENTIONS in P1):**
  - The camera's look as a Resource: projection, pitch, visible width, follow smoothing, shake scale. One `.tres` in a new `data/views/` subfolder.
  - The 3D model of a champion: a `model_scene: PackedScene` field on `ChampionData` (champions stay data). Enemies: the same field as an export on the enemy scene.
  - Room geometry: either the existing TileSet (walls raised by code) or a 3D `MeshLibrary` + `GridMap` per room (Interview, question 7).

## Architecture / contracts
### Engine facts (verified 2026-10-01)
Sources: the API dumped by the local binary (`Godot_v4.7.2-stable_win64_console.exe --doctool`, version `4.7.2.stable.official.ed1daf0bf`) and the class reference text at the `4.7.2-stable` tag of the Godot repository (`doc/classes/*.xml`). "Spike checks" marks what the reference doesn't state.

1. **2D physics nodes in a tree with 3D nodes: works.** CanvasItem: "properties like transform, modulation, and visibility are only propagated to *direct* CanvasItem child nodes. If there is a non-CanvasItem node in between... the CanvasItem nodes below will have an independent position." A Node2D under a Node3D is therefore a top-level 2D node of its viewport's World2D (`Viewport.world_2d`); its physics lives in that World2D's space.
   - Hiding the 2D world without touching its code: `CanvasItem.visibility_layer` + `Viewport.canvas_cull_mask`. "A Viewport will render a CanvasItem if it and all its parents share a layer with the Viewport's canvas cull mask." Visibility layers are not inherited. So one layer on the room root hides the whole room from the screen.
   - The reference ties no physics behavior to visibility (nothing in CollisionObject2D, CollisionShape2D or Area2D). Spike checks that a hidden CharacterBody2D still collides.
   - `WorldQuery` reads `get_tree().root.world_2d`, so the sim must stay in the root viewport's World2D.
   - Showing ground drawings in 3D: a `SubViewport` can be given the root's `world_2d` (the property is settable) and its own `canvas_cull_mask`, then shown on a floor quad. Sharing a World2D between viewports is a known pattern, but the reference doesn't describe it. Spike checks.
2. **2D audio without a Camera2D: needs one change.** AudioListener2D: "If there is no active AudioListener2D in the current Viewport, center of the screen will be used as a hearing point." Today that "screen center" follows the Camera2D through the canvas transform (`Audio.get_listener_position()` uses the same formula). With no Camera2D the canvas transform stays identity, so the hearing point would stick at world (320, 180) px. Fix: one `AudioListener2D`, `make_current()`, moved to the camera's floor focus point (in px) every physics tick, and `Audio.get_listener_position()` reads `Viewport.get_audio_listener_2d()` when one is current. Panning stays right because the camera never rotates (screen left/right = sim x). AudioListener3D / AudioStreamPlayer3D exist but aren't needed.
3. **3D physics interpolation: available, and already on.** `physics/common/physics_interpolation`: "the renderer will interpolate the transforms of objects (both physics and non-physics)." `Node3D.get_global_transform_interpolated()` exists. **Node2D and CanvasItem have no interpolated getter in 4.7.2** (API dump). So a 3D node that copies a 2D node's position in `_process` gets the last tick's value and judders at 144 Hz. Hence the core rule: copy in `_physics_process` and let the 3D node interpolate. `reset_physics_interpolation()`: call it "after moving the node"; the notification reaches "the node and all children recursively".
4. **GridMap vs generated meshes.**
   - **GridMap:** a `MeshLibrary` tile is "a mesh with materials plus optional collision and navigation shapes" (per-item navigation mesh and navigation layers). `bake_navigation` makes a navigation region per cell. It has `collision_layer` / `collision_mask`, `get_used_cells()` / `get_cell_item()`, and `make_baked_meshes()` (lightmap UVs). `cell_size` defaults to 2 m (we'd use 1 m). It "can't be hidden or cull masked based on VisualInstance3D.layers". Its collision and navigation are 3D, so under A1 a script would read its cells and build the 2D colliders and 2D navigation from them. Upside: rooms built and seen in 3D in the editor, several heights native (rooftops).
   - **Generated meshes:** a script reads the existing `TileMapLayer` cells and builds floor and wall meshes (MeshInstance3D / MultiMesh) at load (or in the editor with `@tool`). Authoring stays in the 2D tile editor; the 3D look is only seen when running (or via the tool script). Cheapest for the spike; weak for buildings and rooftops.
5. **Other checked facts.**
   - Stretch mode `canvas_items`: "3D is unaffected" (3D renders at the 1280×720 window). `viewport` renders everything, UI included, at 640×360.
   - **New in 4.7:** `Viewport.SCALING_3D_MODE_NEAREST` with `scaling_3d_scale` 0.5 renders 3D at half resolution with a crisp nearest upscale, while `canvas_items` keeps the UI sharp. That is the low-res pixel look in 3D without changing the UI.
   - Camera3D: `projection` (perspective / orthogonal), `size` (meters, width or height per `keep_aspect`), `project_ray_origin()` / `project_ray_normal()` (mouse → floor), `unproject_position()` (unit → screen, for numbers and health bars).
   - Decal: supported on Forward+ (our renderer). Label3D and Sprite3D (billboards) exist.
   - NavigationServer2D: `map_get_path(..., navigation_layers)`, `region_set_navigation_layers()` and `link_create()`, so the 2D sim can keep a separate walk graph per height (rooftops) and stairs as links.

### Strategy A1: the sim stays 2D (hidden); a 3D view follows it
- **New files (estimate ~1,450 lines + scenes and models):** the floor/wall builder (~200), the 3D camera with every `GameCamera` behavior plus the projection toggle (~260), per-unit views with placeholder models and animation from existing signals (~300), the ground overlay for indicators and telegraphs (~120), the screen overlay for damage numbers and health bars (~150), the mapping in `units.gd` (~25), the mouse → floor pick (~40), a new `view_test` suite (~350).
- **Existing files touched: about 12, ~130 lines:** `main.gd` (~40: build the view behind a flag, hide the 2D world, the listener), `player.gd` (~25: `get_aim_point()` returns the floor pick when a view exists; its 10 direct mouse calls route through it), `audio.gd` (~10), `game_feel.gd` (~5: shake reaches a 3D camera too; the Camera2D path stays for tests), `unit.gd` (~10: optional overlay path for numbers), `vfx.gd` (~10: `spawn_scene()` accepts 3D presentation-hook scenes), `champion_data.gd` (+2), the 2 room scenes (a visibility layer), the enemy scenes (model export), `project.godot` (3D scaling settings, layer names).
- **Rooftops (P8):** +200–400 lines across `movement_component.gd`, `world_query.gd`, `room.gd`, depending on Ryan's rooftop rule.
- **Existing tests affected: 0 of 1,782 expected.** The sim, its scenes and its API are unchanged; the view attaches from Main, which no test instances. One new suite.
- **Main risks:**
  1. Two coordinate spaces (px sim, meter view). Mitigated by one mapping (Core rules) and a round-trip test.
  2. Ordering and interpolation: a view that syncs before the sim moves lags a tick; one that syncs in `_process` judders (Engine facts, 3). Mitigated by the core rule; the spike measures it at 144 Hz.
  3. The sim has no height. Rooftops need an explicit elevation rule (collision, navigation, line of sight). A2 would need the same rules, since gameplay stays on a flat plane either way.
  4. The ground overlay (shared World2D) is unverified. Fallback: redraw telegraphs and indicators as 3D meshes (~400 lines).
  5. The 3/4-view tricks become wrong in 3D: `body_center` offsets, the 0.55 squash on the hover ring, `Projectile.DRAW_HEIGHT_PX`, y-sort. They move into the view; targeting help that used `get_center()` gets a screen-space pick instead.
  6. Long term, two worlds to keep in step: every new world feature (pits, hazards, destructibles, buildings) needs its 2D collision and its 3D look. Mitigated by building one from the other (one source of truth per room).
  7. A newcomer must learn that the "real" world is the hidden 2D one.

### Strategy A2: full port to 3D nodes and Vector3
- **Files touched:** 59 of 99 game scripts (every class b, c and d), all 7 test files, about 14 of 18 scenes, the TileSet (replaced by a MeshLibrary/GridMap), and the 7 data files that hold px values.
- **Lines:** 896 game lines and 780 test lines carry a 2D marker. With the rewrites (179 lines of 2D drawing become 3D meshes, `WorldQuery` on 3D queries, navigation baked from 3D geometry, `MovementComponent` on CharacterBody3D, the camera, audio), the estimate is **2,000–3,000 changed lines of game code and 800–1,200 of tests**.
- **Tests affected: all 6 suites** (1,782 checks; `stats_test`'s checks are stat math, but its scene's bodies must become 3D). Every px assertion ("steps 16 px", "the dash covers 128 px") is rewritten or converted.
- **Data:** every `_px` field is wrong in meters. Renaming them breaks "don't rename"; keeping px means a px ↔ m layer anyway, the same one A1 needs.
- **Main risks:**
  1. Feel drift: `move_and_slide()` on CharacterBody3D under Jolt is a different solver from 2D (corner catching, sliding, safe margin). The dash, knockback and swing steps are tuned and tested on the 2D solver.
  2. No stable oracle: the tests are rewritten in the same change as the code they guard.
  3. A long branch that freezes T-M, LOOT L1 and everything else, with large merge conflicts.
  4. It replaces `Unit`'s base class and most components (the change policy's ask-first case, for nearly everything at once).
- **What A2 would buy:** one world, no sync; real 3D rays for height (line of sight over a parapet); GridMap collision and navigation used directly; physics picking.

### Recommendation: A1
- The gameplay is already a flat-plane sim (circles, cones, segments on `global_position` plus one line-of-sight ray). Under 3D art that is how League and Diablo work too, so the 2D sim is not a stopgap.
- "Every gameplay number stays" is guaranteed by construction: the sim and its 1,782 checks don't change.
- It is additive (behind a flag), reversible at every step, and costs roughly a quarter of A2.
- Escape hatch: the view layer A1 builds (camera, models, overlays, lights) is the same work A2 would need, so if verticality ever outgrows "rooftops as areas" (e.g. arcing projectiles, multi-floor fights), a later port reuses it.

### A1's shape (proposed names; checked against CONVENTIONS in P1, nothing named yet)
- Vocabulary to add: **sim** (the gameplay world: the 2D nodes, in px, the source of truth), **view** (the 3D presentation; never changes gameplay state), **floor pick** (the point on the floor under the cursor), **elevation** (how high a walkable area is: 0 = floor, 1 = a rooftop; never "level", which means the champion level or `StatsComponent.set_level()`), **projection** (perspective or orthographic).
- `Units.PX_PER_METER` (32.0) with `px_to_m()`, `m_to_px()`, `to_view(p: Vector2, height_m := 0.0) -> Vector3`, `to_sim(p: Vector3) -> Vector2`. A `_m` suffix for meters, as `_px` is for pixels.
- `WorldView` (Node3D under Main: environment, lights, camera, the room's look), `RoomView` (builds a room's 3D look), `GameCamera3D` (Camera3D), `UnitView` (Node3D following one Unit; created by `WorldView` for every member of the `units` group, so unit scenes stay untouched), `GroundOverlay` (the SubViewport sharing the sim's World2D, shown on the floor), `ScreenOverlay` (CanvasLayer for damage numbers and health bars).
- `Main.use_3d_view` (export, off until the milestone). Canvas visibility layer 2 = "sim" (hidden from the screen), layer 3 = "ground overlay".
- New subfolders: `scripts/view/`, `scenes/view/`, `art/models/`, `data/views/` (inside existing top-level folders, so no new top-level folder).

## Build order (proposed; not started)
Every step: Ryan runs `git status` first; the six suites stay at baseline (1,780 pass, the same 2 fail), plus `view_test` from P2 on.

0. **P0 Spike (throwaway).** On a branch `spike/3d-view` that is never merged. Quick and dirty: the sandbox room raised from its tiles (floor quads, 2 m wall boxes) plus one 3 m building with a slime dummy standing on its roof (look only); a grey capsule per unit following the hidden 2D sim on the physics tick; a Camera3D following the Knight with keys to **toggle orthographic / perspective**, cycle pitch 50 / 60 / 70° and visible width 20 / 24 / 28 m, and toggle 3D render resolution 640×360 nearest vs 1280×720; the mouse floor pick driving the Knight's aim; the elite's telegraph and the Knight's indicators on the floor through the shared-World2D overlay (Decal as a second try); an AudioListener2D at the camera focus.
   - Measures: frame time at 144 Hz; stutter walking the long wall and dashing; floor-pick error (target < 1 px) at screen center and corners in both projections; telegraph vs hit alignment; whether a hidden CharacterBody2D still collides.
   - **Done means:** Ryan plays it and answers the camera and art questions from what he saw; the measurements go into this doc.
   - **Tests:** the six suites on the spike branch stay at baseline (proof the spike didn't touch the sim).
   - **Rollback:** delete the branch. `main` never changes.
1. **P1 Decisions and docs.** Ryan's answers → DECISIONS.md rows; `docs/3D.md` written from this doc; the Doc edits below. **Done means:** Ryan approves 3D.md. **Tests:** none (docs only). **Rollback:** revert the docs commit.
2. **P2 Scaffolding (no visible change).** The mapping in `units.gd`, the folders, an empty `WorldView` scene, `Main.use_3d_view` (off), `view_test` (mapping round trip; floor pick on a fixed camera). **Done means:** `view_test` passes; the game is byte-for-byte today's with the flag off. **Rollback:** revert the commit (new files plus one export).
3. **P3 Room look and light.** `RoomView` builds floors and walls (from tiles or GridMap, per the interview); environment, a directional light, shadows. Flag on: the 2D world is hidden from the screen (layer 2 + the root's cull mask), not from physics. **Done means:** the sandbox shows the lit 3D room and walking and collisions are exactly as before. **Rollback:** flag off, or revert.
4. **P4 Camera and listener.** `GameCamera3D` with all of `GameCamera`'s behavior (lock on Y, hold C, edge and arrow pan, aim lean with dead zone, curve and hold time, room bounds, shake through `GameFeel.shake()`, `snap_to_target()` with interpolation resets), its look from the camera Resource; the AudioListener2D follows the focus. **Done means:** Ryan's camera checklist (MOVEMENT.md, Architecture 4) feels the same; sounds pan and fade with distance. **Rollback:** flag.
5. **P5 Aim.** `Player.get_aim_point()` returns the floor pick when a view exists, else the mouse as today; the 10 direct mouse calls in `player.gd` go through it (**a replace: needs Ryan's OK**); the enemy under the cursor is picked in screen space. **Done means:** every Knight ability and the VECTOR test abilities land where the cursor touches the floor, in both projections. **Rollback:** flag (the fallback path is today's code).
6. **P6 Unit views.** `UnitView` per unit with placeholder models: position, facing, hit flash (from `damaged`), death (from `died`, detached so it outlives the freed Unit), dash ghosting, walk bob, swing and cast poses from the existing signals and presentation hooks. The 2D `Body` stays, hidden. **Done means:** a 144 Hz play test with no stutter; the Knight's combo, Lunge and Judgement read; slimes and the elite read. **Rollback:** flag.
7. **P7 Floor and floating UI.** Telegraphs, indicators and hover rings on the floor (`GroundOverlay`, or 3D meshes if P0 rejected it); damage numbers and health bars on `ScreenOverlay`; `VFX.spawn_scene()` accepts 3D presentation-hook scenes; `Unit._add_number()` gets the overlay path while the old path stays. **Done means:** the elite slam's fill matches its hit; numbers read well at the chosen size. **Rollback:** flag.
8. **P8 Elevation (rooftops).** Ryan's rooftop rule: an `elevation` on Unit, walk collision and navigation per elevation (`navigation_layers`), the line-of-sight rule in `WorldQuery`, the 3D look; the sandbox gets a building with a rooftop enemy. **Done means:** the rule plays as 3D.md describes. **Tests:** baseline plus new checks. **Rollback:** revert the step.
9. **P-M Milestone.** The flag defaults to on; the sandbox and `room_01` play fully in 3D; Ryan's feel play test at 144 Hz (dash 128 px = 4 m, Cleave, Lunge, Judgement, the slam, the camera lean, sounds). Only then, asked separately: disable and later delete the 2D placeholder visuals, the old Camera2D node, the flag. **Rollback:** the flag back to off.

Not in this plan: the art pass (real models, animation, lighting mood), which needs Ryan's art answers and gets its own plan.
**Done means (whole pivot):** the game plays in 3D at the chosen angle with every feel number and every existing check unchanged.

## Doc edits needed (after Ryan's answers, in P1)
| Doc | Change |
|---|---|
| VISION.md | One sentence and Scope (wording below); Cross-cutting: "Rooms can have raised areas (rooftops, ledges) that enemies use; the player never jumps." |
| CLAUDE.md | The game (fixed-angle 3D view); Tech facts ("2D top-down 3/4 view, pixel art" → the sim in 2D px, the view in 3D meters, 1 m = 32 px = 100 u; stretch and 3D scaling settings; physics interpolation in 3D; navigation also in `AutoAttackComponent`); Project layout (new subfolders); Architecture (sim vs view); Docs index (+3D.md); Current status. |
| CONVENTIONS.md | Units row (`_m` for meters); vocabulary (sim, view, floor pick, elevation, projection); reserved names (A1's shape); visibility layers 2 and 3; "the view never changes gameplay state" next to the VFX rule. |
| MOVEMENT.md | Title drops "2D"; "8-direction sprites" → the art answer; Camera (Architecture 4) → GameCamera3D, projection, pitch; F1 → the physics-tick sync rule; Facing and aim → the floor pick; the open question on vertical speed → the foreshortening note. |
| COMBAT.md | Telegraphs (still exact circles; the camera shows them as ellipses); damage numbers and health bars (screen overlay); hit flash (a 3D material); shake (camera offset in screen px); dormant Hurtbox offsets. |
| WORLD_INTERACTION.md | Title drops "2D"; collision layers unchanged (sim); a new Elevation section (the rooftop rule); "3/4 depth" (approved 2026-09-30) superseded: depth buffer instead of y-sort, wall fade or silhouettes per the interview; tile tags → wherever room geometry lives. |
| AUDIO.md | Listener (an AudioListener2D following the camera focus); `max_distance_px` 480/640 was "the screen is 640 wide": re-measure for the new visible width; panning unchanged (the camera never rotates). |
| ABILITIES.md | Indicators drawn on the floor overlay; `Projectile` height in the view; presentation hooks accept 3D scenes (`cast_anim` / `swing_anim` drive the model); aim and the VECTOR start point use the floor pick. |
| DECISIONS.md | A new "3D view" section: the pivot and its givens (2026-10-01), A1 vs A2, scale, projection and pitch, art direction, the rooftop rule, the room source of truth, the order of work. |
| `docs/3D.md` (new) | The lasting spec: sim/view split, mapping, camera, room building, unit views, overlays, elevation, build steps. Written from `_TEMPLATE.md`. |
| Also touched lightly | CHAMPIONS.md (`ChampionData.model_scene`), LOOT.md (pickup look only; its Area2D pickups stay in the sim), STATS.md (no change). |

**VISION, proposed one sentence:** "A fixed-angle 3D action looter, played on a flat floor under a League/Diablo-style camera, where you pick a champion with a League-style kit, move and fight with Hades-level precision, and dive through Diablo-style dungeons collecting gear that changes *how your abilities play*, not just how big the numbers are."
**VISION, proposed Scope "In":** "single-player; a fixed-angle 3D view (the camera follows the player and never rotates; gameplay on a flat floor; raised areas such as rooftops; no jumping); [art style from the interview, e.g. 'low-poly 3D rendered at 640×360 for a pixel look']; multiple champions (Knight first), hand-made rooms stitched into dungeons, gear with affixes and augments."

## Open questions
### Interview for Ryan (plain language)
1. **How steep is the camera?** Steep, looking mostly down (you see the floor clearly and walls hide little; League feels like this), medium (Diablo IV), or lower (more dramatic and the buildings look tall, but walls hide more and "up the screen" looks slower). The spike lets you flip between 50°, 60° and 70°.
2. **Should far things look smaller?** "Perspective" is a real camera: the top of the screen is a bit smaller, rooftops look tall, it feels more 3D (League and Diablo work this way). "Flat" (orthographic) keeps every size and distance the same everywhere on screen, like a board game seen at an angle; skill-shot ranges read the same in every corner. The spike has a toggle.
3. **How much more of the world?** Today you see 20 × 11 tiles. A little more (about +25%), a lot more (+50–100%), or a zoom you control with the mouse wheel? More world also means everything is drawn smaller.
4. **What should it look like?**
   - (a) Smooth 3D models at full resolution (League, Diablo IV).
   - (b) 3D models drawn at the old low resolution, so it still looks like pixel art, with real lighting.
   - (c) Pixel-art sprites standing in a lit 3D world (Octopath Traveler's "HD-2D").
   - (d) 3D models turned into sprite sheets ahead of time (how Hades and Diablo II made their characters).
   - "Easier animation" mostly comes with (a) and (b): one model animates in every direction; (c) still needs every direction drawn by hand.
5. **Who makes the 3D art?** You, bought asset packs, or a commission? Until then, are grey boxes and capsules OK?
6. **Turning:** should characters turn smoothly to any angle (natural for models), or snap to 8 directions like the old sprite plan?
7. **How do you want to build rooms?** Keep painting flat tiles and let the game raise the walls (fast; simple shapes), or build rooms in 3D from a kit of blocks, like Lego or Minecraft (you see the real room while building; rooftops and stairs are natural; more work per room)?
8. **The rooftop rule.** When an enemy stands on a roof:
   - (a) Height is only looks: the roof is a place you can't walk, but anything that reaches the spot hits the enemy, melee included (the League way: everything is on one flat map).
   - (b) Melee can't reach up; ranged attacks and abilities can.
   - (c) You can climb up by stairs or ladders (still no jumping); melee only works at the same height.
   - (d) Rooftop enemies can't be hit at all until you get up there or out of their sight, like turrets.
   - And: can enemies jump down to you? Can you knock an enemy off a roof (does it get hurt or die, like a pit)?
9. **Walls in front of you.** When you walk behind a tall wall or building: fade it out (Diablo), show your outline through it, or keep the camera steep enough that it rarely happens?
10. **Lighting mood:** dark dungeons lit by torches (Diablo), or bright and easy to read (League)? Readability (telegraphs, enemies) stays first either way (VISION, decision priorities).
11. **"Up the screen looks slower."** With a tilted camera, walking or dashing up and down the screen looks 6–23% shorter than sideways, depending on the angle (the game numbers don't change). OK as is, or should we prefer a steeper camera to keep it small?
12. **When?** Before or after the T-M play test? LOOT L1 (item data and rolling) doesn't touch the view, so it can go either side. Suggested: T-M first (it's already next), then the P0 spike, with L1 whenever you like.

### Technical (Claude answers these in the spike, not Ryan)
- Does a SubViewport sharing the root's World2D render the overlay correctly, and is it cheap enough? (Engine facts, 1.)
- Does a hidden CharacterBody2D still collide? (Expected yes.)
- Does the view sync order (physics tick, after `MovementComponent`) remove all stutter at 144 Hz? Does hitstop (`Engine.time_scale`) behave with 3D interpolation?
- Floor-pick accuracy in perspective near the screen edges; what happens above the horizon at a low pitch.
- Decal vs a floor quad for telegraphs that must wrap onto raised floors.

### Doc conflicts found (to settle in P1)
- The Givens conflict with VISION.md ("2D pixel art at 640×360", the one sentence), CLAUDE.md Tech facts ("2D top-down 3/4 view. Pixel art"), MOVEMENT.md ("The plan is 8-direction sprites") and WORLD_INTERACTION.md "3/4 depth" (y-sort, approved 2026-09-30). These docs stay as they are until Ryan answers; the edits are listed above.
- CLAUDE.md says AI pathing uses NavigationServer2D "in `MovementComponent`"; `AutoAttackComponent` also queries it (a closest-point check). Minor; fix with the CLAUDE.md edit.
