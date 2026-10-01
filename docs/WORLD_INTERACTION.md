# WORLD_INTERACTION.md: Abilities vs. the World (2D)

**Read when:** abilities touch the world (grapples, blinks, dashes into walls, knockback into terrain), or the task involves collision layers, tile tags, or interactables.
**Depends on:** CLAUDE.md, MOVEMENT.md.

## Current code
- Rooms are `res://scenes/rooms/room_XX.tscn`, each with a `Tiles` TileMapLayer (`dungeon_tileset.tres`, 32 px, physics layer 0 → collision layer 1 "world"), an `Entities` node, and a `PlayerSpawn` marker.
- Levels are hand-made rooms stitched together (DUNGEONS.md, when it exists).
- `Hitbox` and `Hurtbox` Areas already exist. Hitboxes sit on the owner's attack layer and carry `damage` and `knockback`. No scene uses a Hitbox yet; hits go through the hit pipeline (COMBAT.md).

## Core principle: three layers, one job each
1. **Physics layers** answer *what collides with what*.
2. **Surface tags** answer *what a surface means for gameplay* (grappleable, destructible...).
3. **Ability → movement bridge**: abilities never set position or velocity themselves. They call MovementComponent methods (`dash`, `displace`, and later `blink`, `pull_to`, `orbit`, `tether`).

Example: an Akshan-style swing is an ability that asks `WorldQuery` for a grappleable wall, then calls `movement.orbit(...)`.

## Collision layers (1–5 exist; add 6+ as systems need them)
| # | Name | What's on it | Status |
|---|---|---|---|
| 1 | world | walls, pillars (tiles with collision) | exists |
| 2 | player | player body | exists |
| 3 | enemies | enemy bodies | exists |
| 4 | player_attack | player hitboxes and projectiles | exists |
| 5 | enemy_attack | enemy hitboxes and projectiles | exists |
| 6 | pit | chasms (`Pits` TileMapLayer): block walking only, not dashes, other displacements (knockback, blink, pull, swing) or projectiles | planned |
| 7 | low_obstacle | fences, rubble: block walking, not projectiles | planned |
| 8 | interactable | chests, doors, shrines, NPC talk zones | planned |
| 9 | pickup | dropped loot, gold, potions | planned |
| 10 | hazard | traps, damaging floors | planned |

Planned: walking masks world, pit, low_obstacle, and the other team's bodies. As it is today: the player's and the slimes' bodies both mask 7 (world, player, enemies), so units also collide with their own team (pit and low_obstacle don't exist yet). A ghosted `dash()` (the dash, Lunge) masks world only while it runs (`collision_mask & 1`), which is correct: pits and units are ignored during a dash; `displace()` keeps the unit's own mask (minus the pit layer once pits exist: Pits and movement types).

## Surface tags
- **Tiles:** add TileSet **custom data layers** to `dungeon_tileset.tres` with bools `grappleable`, `destructible`, `bounce`, `wall_slam`, and set them per tile.
- **Non-tile bodies** (crates, doors, pillars placed as scenes): a `SurfaceTags` node (`res://scripts/components/surface_tags.gd`) with the same `@export` flags.
- Plain wall default: grappleable = true, everything else false.
- `WorldQuery` hides the difference: for a TileMapLayer hit it gets the cell via `get_coords_for_body_rid()` and reads the tile data. For anything else it reads `SurfaceTags`.

## WorldQuery (autoload, `res://scripts/autoload/world_query.gd`)
This is the only place raycasts are written, with one exception today: each Enemy's own `Sight` RayCast2D (`slime.tscn`, mask 1, used by `enemy.gd` `_can_see_player()` for aggro), older than WorldQuery; it moves into `has_line_of_sight()` when ENEMIES_AI.md reworks aggro. It's built on `PhysicsDirectSpaceState2D` (`intersect_ray`, `intersect_shape`, `cast_motion`). No `debug_draw` yet (How to answer, below, asks for one): add it with the next query.
Built:
- `has_line_of_sight(from, to, mask = 1)`: walls only; units don't block it. The melee target pull and every hit (COMBAT.md: basic attacks never hit through walls; abilities unless `ignores_walls`).
- `shape_sweep(from, to, radius, mask = 1)`: the first block along the path (prevents tunneling; projectiles, ABILITIES.md). A circle through `cast_motion`; returns {position (the circle's center where it stops), fraction} or {} when clear.

Planned:
- `raycast_terrain(from, dir, max_dist_px) -> Dictionary {position, normal, collider, tags}` (empty if nothing hit)
- `find_grapple_point(from, dir, max_dist_px)`: the first world hit must be `grappleable`, otherwise empty
- `resolve_valid_position(target, from)`: if an endpoint is in a wall, returns the nearest valid floor point on the caster's side (pits are valid endpoints: a displacement that ends over one follows the pit rule, Pits and movement types)
- `get_units_in_radius(center, r, team_filter)`

## Ability movement (MovementComponent methods)
Existing: `displace(velocity, duration, curve, dash_cancelable)`, `dash(velocity, duration, ghosted, curve)`, `stop_displacement()` (a caller ending its own displacement, e.g. a stunned melee swing step).
To add when the first ability needs them:
- `blink(target)`: instant, uses `resolve_valid_position`
- `pull_to(point, speed)`: hook pulls the unit to a point
- `tether(anchor, max_length)`: free movement clamped to a radius around the anchor
- `orbit(anchor, radius, angular_speed, dir_sign, max_angle)`: the swing

*(approved by Ryan 2026-09-30, not built)* Movement methods will emit `Events.unit_impacted(ImpactContext)` when a displacement hits a wall or a unit; neither the signal nor `ImpactContext` exists yet (DECISIONS.md, World Interaction, 2026-09-25). Wall-slam stuns will be `ReactionRule`s (trigger `IMPACT`, surface tag `wall_slam`), as in the CONVENTIONS.md worked example. Whether `bounce` is movement or an effect is an open question.
`dash()` and `displace()` move with `move_and_slide()`, so a dash or knockback into a wall slides along it (like walking) instead of stopping; only a near-head-on hit stops.
Each movement method defines how it starts, what ends it, and what happens on hitting a wall or a unit. A stun doesn't end a displacement that's already running (knockback still moves a stunned unit; DECISIONS.md, Movement); it only stops the unit from starting new ones. They emit the existing `displacement_finished` signal.

## Interactables
Scripts go in `res://scripts/interactables/`, scenes in `res://scenes/interactables/`.
- `interaction_tags: Array[StringName]`, e.g. `&"pullable"`, `&"breakable"`, `&"ignitable"`
- `on_hit(ctx: HitContext)`: any hit, so basic attacks, hazards and knockback can break or trigger things too, not only abilities. `ctx.ability` is null when no ability caused the hit.
- `on_interact(player: Player)` for the F key

Abilities check tags; they never check class names.

## Pits and movement types (approved by Ryan 2026-09-30; ready to build, not yet in a build order: Movement step 8 was removed 2026-09-25)
- `Unit` gets a movement type enum, `enum MovementType { GROUND, FLYING }` with `@export var movement_type`. FLYING ignores the pit layer and never falls.
- One rule for all units: any displacement (dash, knockback, blink, swing) that ends with the unit's feet **8 px or more** inside a pit makes it fall. Less than 8 px snaps it back to the edge.
- **Every displacement ignores the pit layer while it runs**, the exemption a ghosted `dash()` already has: `displace()` (knockback, swing steps), `blink()`, `pull_to()` and `orbit()` take layer 6 out of the unit's `collision_mask` when they start and put it back when they end (any way they end), keeping every other bit (so knockback still slides along walls and stops on units). Otherwise a pit edge would stop the unit like a wall and no push could ever carry it the 8 px the rule needs. `blink()`'s endpoint check (`resolve_valid_position`) resolves walls only and leaves pits to the 8 px rule, for the same reason. Walking keeps the pit layer: a unit never walks into a pit.
- **The player falls:** takes 5% of max health (can't drop below 1 health), then respawns on the last safe tile (the last floor tile the player stood fully on).
- **An enemy falls:** it dies, the kill goes to whoever caused the displacement (Kill credit), and its drops land on the nearest floor tile. **Bosses never fall;** they snap to the edge.
- Pit tiles have no navigation polygon, so enemies never path into them. (Today `Room._bake_navigation()` only carves colliders on layer 1 from the `navigation_source` group, so whatever builds pits has to add them to that bake.)
- Pits get their own TileMapLayer, `Pits`, with physics on layer 6. Floor and walls stay on `Tiles`.

## Hazards (approved by Ryan 2026-09-30)
A `Hazard` is an Area2D scene on layer 10 with:
- `tags` (e.g. `&"oil"`, `&"fire"`)
- `source`: the Unit that made it, or null = the environment
- team filter (default: affects everyone)
- `tick_interval` = 0.5 s
- `lifetime` (-1 = permanent)
- `arm_time`: a telegraph before it activates. Default 0.5 s for enemy- and trap-made hazards, 0 for player-made ones.

Entering applies its status; re-entering refreshes it instead of stacking. It emits `hazard_entered` / `hazard_exited`. Timed traps are Hazards with an on/off cycle.

## Knockback (approved by Ryan 2026-09-30)
- New stat `knockback_resistance`, 0–1, scales displacement distance by (1 − value). Bosses have 1. (Row in STATS.md.)
- A displaced unit that hits another unit emits `unit_impacted` with that unit as the collider, so rules can make chain hits.
- `ImpactContext` carries the impact speed, so rules can set thresholds.
- Two knockbacks at once: the stronger wins (COMBAT.md; built in COMBAT C4): `displace()` is dropped (returns false) when the running displacement has more distance left than the new one's whole distance.

## Reaction triggers *(specified in COMBAT.md, ReactionRule)*
`ReactionRule.Trigger` has 8: `IMPACT`, `HIT`, `HAZARD_ENTERED`, `HAZARD_EXITED`, `STATUS_APPLIED`, `UNIT_DIED`, `HAZARD_OVERLAP` (hazard meets hazard, e.g. fire + oil), `ABILITY_CAST` (ABILITIES.md). 4 are built (`HIT`, `UNIT_DIED`, `STATUS_APPLIED`, `ABILITY_CAST`); the 4 world ones (`IMPACT` and the three hazard triggers) are approved (Ryan, 2026-09-30) and get built with impacts and Hazards here. The same list is in CONVENTIONS.md, Extension pattern 1.

## Destructibles (approved by Ryan 2026-09-30)
- `hits_to_break` (default 1). Any `HitContext` counts.
- Drops come from a loot table (LOOT.md).
- Navigation updates in their area when they break.
- A grapple hooked to one detaches when it breaks, with the same tangent dash as a manual detach (300 u / 96 px over 0.15 s; the Grapple Swing example below), not a dead stop: the swing's momentum carries on, the player stays in control, and a break reads the same as letting go. A detach dash that ends over a pit follows the pit rule, as a manual one does.

## Kill credit (approved by Ryan 2026-09-30)
- `HitContext`, `ImpactContext` and `Hazard` all carry a source Unit.
- When the environment kills something (pit, wall slam, hazard), credit goes to whoever caused the displacement or owns the hazard; null = the environment.
- On-kill effects and drops use this.

## 3/4 depth (approved by Ryan 2026-09-30)
- The `Entities` node is y-sorted (already true in `sandbox.tscn`, and `room.gd` expects it).
- Colliders sit at the feet (the player's already does).
- Units behind tall walls get a silhouette (later).
- `low_obstacle` never blocks projectiles.

## Ability spec template
Moved to ABILITIES.md, Ability spec sheet (its "World" line covers the world query, movement method, what ends it, and hitting a wall or an enemy, as in the worked example below).

## Worked example: Grapple Swing (Akshan-style)
```
Targeting: DIRECTION   cast_range: 600 u (192 px)   cast_time: 0.05   roots_during_cast: n
Casts: 1 = fire hook along aim | 2 = shoot nearest enemy (signal stub) | 3 or dash = detach
World query: find_grapple_point(pos, aim_dir, to_px(cast_range))
  miss / non-grappleable -> hook retracts, 50% cooldown refund
Movement: orbit(anchor, radius = hook distance clamped 150-600 u,
                angular_speed = to_px(1000) / radius_px rad/s (~320 px/s tangential),
                dir_sign = side of the anchor the aim passed, max_angle = 360°)
Ends when: max_angle reached, cast 3, dash, or stun
Hits wall: stop, 0.1 s slide
Hits enemy: stop, emit swing_interrupted(enemy)
Detach: dash along the tangent, 300 u (96 px) over 0.15 s
```

## How to answer on these tasks
- Update the layer and tag tables here when adding layers or tags, and give me the editor steps (Project Settings → Layer Names → 2D Physics).
- Reusable spatial logic goes in `WorldQuery`, not in the ability.
- Every new query or movement method gets a debug draw behind `debug_draw`.
- Call out edge cases: tile corners, thin walls, an anchor very close to the unit, a hooked wall getting destroyed, swinging over a pit.

## Open questions
- **Bounce:** is `bounce` a movement behavior (MovementComponent reflects the displacement) or a GameplayEffect?
- **Readability (art):** how grappleable, `wall_slam` and destructible surfaces look different from plain walls. Every hazard and trap shows a telegraph during its `arm_time`.
- **Doors, room locking and room transitions** belong in DUNGEONS.md.
- ~~The *(proposed)* sections above await Ryan's OK~~: approved 2026-09-30 (Pits and movement types with the pit-layer exemption for every displacement; Hazards, Knockback, Reaction triggers, Destructibles with the tangent-dash detach, Kill credit, 3/4 depth). Pits still need a place in a build order.
