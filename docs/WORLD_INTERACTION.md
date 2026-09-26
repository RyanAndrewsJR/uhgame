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
| 6 | pit | chasms (`Pits` TileMapLayer): block walking, not dashing or projectiles | planned |
| 7 | low_obstacle | fences, rubble: block walking, not projectiles | planned |
| 8 | interactable | chests, doors, shrines, NPC talk zones | planned |
| 9 | pickup | dropped loot, gold, potions | planned |
| 10 | hazard | traps, damaging floors | planned |

Walking masks world, pit, low_obstacle, and the other team's bodies. `dash()` currently masks world only (`collision_mask & 1`), which is correct: pits and units are ignored during a dash.

## Surface tags
- **Tiles:** add TileSet **custom data layers** to `dungeon_tileset.tres` with bools `grappleable`, `destructible`, `bounce`, `wall_slam`, and set them per tile.
- **Non-tile bodies** (crates, doors, pillars placed as scenes): a `SurfaceTags` node (`res://scripts/components/surface_tags.gd`) with the same `@export` flags.
- Plain wall default: grappleable = true, everything else false.
- `WorldQuery` hides the difference: for a TileMapLayer hit it gets the cell via `get_coords_for_body_rid()` and reads the tile data. For anything else it reads `SurfaceTags`.

## WorldQuery (autoload, `res://scripts/autoload/world_query.gd`)
This is the only place raycasts are written. It's built on `PhysicsDirectSpaceState2D` (`intersect_ray`, `intersect_shape`, `cast_motion`).
**Built so far:** only `has_line_of_sight(from, to, mask = 1)` (walls only; units don't block it), for the melee target pull (COMBAT.md). The rest below is planned.
- `raycast_terrain(from, dir, max_dist_px) -> Dictionary {position, normal, collider, tags}` (empty if nothing hit)
- `find_grapple_point(from, dir, max_dist_px)`: the first world hit must be `grappleable`, otherwise empty
- `resolve_valid_position(target, from)`: if an endpoint is in a wall or pit, returns the nearest valid floor point on the caster's side
- `shape_sweep(from, to, radius, mask)`: the first block along the path (prevents tunneling)
- `has_line_of_sight(a, b)`: built (melee pull, then every hit in COMBAT C7: basic attacks never hit through walls; abilities unless `ignores_walls`)
- `get_units_in_radius(center, r, team_filter)`

## Ability movement (MovementComponent methods)
Existing: `displace(velocity, duration, curve, dash_cancelable)`, `dash(velocity, duration, ghosted, curve)`, `stop_displacement()` (a caller ending its own displacement, e.g. a stunned melee swing step).
To add when the first ability needs them:
- `blink(target)`: instant, uses `resolve_valid_position`
- `pull_to(point, speed)`: hook pulls the unit to a point
- `tether(anchor, max_length)`: free movement clamped to a radius around the anchor
- `orbit(anchor, radius, angular_speed, dir_sign, max_angle)`: the swing

Movement methods emit `Events.unit_impacted(ImpactContext)` when a displacement hits a wall or a unit. Wall-slam stuns are `ReactionRule`s (trigger `IMPACT`, surface tag `wall_slam`), as in the CONVENTIONS.md worked example. Whether `bounce` is movement or an effect is an open question.
`dash()` and `displace()` move with `move_and_slide()`, so a dash or knockback into a wall slides along it (like walking) instead of stopping; only a near-head-on hit stops.
Each movement method defines how it starts, what ends it, and what happens on hitting a wall or a unit. A stun doesn't end a displacement that's already running (knockback still moves a stunned unit; DECISIONS.md, Movement); it only stops the unit from starting new ones. They emit the existing `displacement_finished` signal.

## Interactables
Scripts go in `res://scripts/interactables/`, scenes in `res://scenes/interactables/`.
- `interaction_tags: Array[StringName]`, e.g. `&"pullable"`, `&"breakable"`, `&"ignitable"`
- `on_hit(ctx: HitContext)`: any hit, so basic attacks, hazards and knockback can break or trigger things too, not only abilities. `ctx.ability` is null when no ability caused the hit.
- `on_interact(player: Player)` for the F key

Abilities check tags; they never check class names.

## Pits and movement types *(proposed; not scheduled: Movement step 8 was removed 2026-09-25)*
- `Unit` gets a movement type enum, `enum MovementType { GROUND, FLYING }` with `@export var movement_type`. FLYING ignores the pit layer and never falls.
- One rule for all units: any displacement (dash, knockback, blink, swing) that ends with the unit's feet **8 px or more** inside a pit makes it fall. Less than 8 px snaps it back to the edge.
- **The player falls:** takes 5% of max health (can't drop below 1 health), then respawns on the last safe tile (the last floor tile the player stood fully on).
- **An enemy falls:** it dies, the kill goes to whoever caused the displacement (Kill credit), and its drops land on the nearest floor tile. **Bosses never fall;** they snap to the edge.
- Pit tiles have no navigation polygon, so enemies never path into them. (Today `Room._bake_navigation()` only carves colliders on layer 1 from the `navigation_source` group, so whatever builds pits has to add them to that bake.)
- Pits get their own TileMapLayer, `Pits`, with physics on layer 6. Floor and walls stay on `Tiles`.

## Hazards *(proposed)*
A `Hazard` is an Area2D scene on layer 10 with:
- `tags` (e.g. `&"oil"`, `&"fire"`)
- `source`: the Unit that made it, or null = the environment
- team filter (default: affects everyone)
- `tick_interval` = 0.5 s
- `lifetime` (-1 = permanent)
- `arm_time`: a telegraph before it activates. Default 0.5 s for enemy- and trap-made hazards, 0 for player-made ones.

Entering applies its status; re-entering refreshes it instead of stacking. It emits `hazard_entered` / `hazard_exited`. Timed traps are Hazards with an on/off cycle.

## Knockback *(proposed)*
- New stat `knockback_resistance`, 0–1, scales displacement distance by (1 − value). Bosses have 1. (Row in STATS.md.)
- A displaced unit that hits another unit emits `unit_impacted` with that unit as the collider, so rules can make chain hits.
- `ImpactContext` carries the impact speed, so rules can set thresholds.
- Two knockbacks at once: the stronger wins (COMBAT.md; built in COMBAT C4): `displace()` is dropped (returns false) when the running displacement has more distance left than the new one's whole distance.

## Reaction triggers *(specified in COMBAT.md, ReactionRule)*
`IMPACT`, `HIT`, `HAZARD_ENTERED`, `HAZARD_EXITED`, `STATUS_APPLIED`, `UNIT_DIED`, `HAZARD_OVERLAP` (hazard meets hazard, e.g. fire + oil). Also listed as planned in CONVENTIONS.md, Extension pattern 1.

## Destructibles *(proposed)*
- `hits_to_break` (default 1). Any `HitContext` counts.
- Drops come from a loot table (LOOT.md).
- Navigation updates in their area when they break.
- A grapple hooked to one detaches when it breaks.

## Kill credit *(proposed)*
- `HitContext`, `ImpactContext` and `Hazard` all carry a source Unit.
- When the environment kills something (pit, wall slam, hazard), credit goes to whoever caused the displacement or owns the hazard; null = the environment.
- On-kill effects and drops use this.

## 3/4 depth *(proposed)*
- The `Entities` node is y-sorted (already true in `sandbox.tscn`, and `room.gd` expects it).
- Colliders sit at the feet (the player's already does).
- Units behind tall walls get a silhouette (later).
- `low_obstacle` never blocks projectiles.

## Ability spec template (matches the fields on `Ability`)
```
Name / Champion / Slot:
Targeting: SELF / DIRECTION / POINT / UNIT
cooldown: __s   cast_time: __s   cast_range: __ u   roots_during_cast: y/n   resets_auto_attack: y/n
base_damage: __   ad_ratio: __   (ap_ratio once STATS adds ability_power)
Casts: (what each press does, incl. recasts)
World query:
Movement method:
Ends when:
Hits wall:
Hits enemy:
Stunned mid-ability:
Extra tunables:
```

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
- *(proposed)* Pits and movement types: GROUND/FLYING, the 8 px fall rule, player fall (5% max health, min 1, respawn on last safe tile), enemy fall (dies, kill credit, drops to nearest floor; bosses snap), no nav on pits, `Pits` TileMapLayer on layer 6.
- *(proposed)* Hazards: fields and defaults (layer 10, source, team filter, 0.5 s tick, lifetime, arm_time 0.5 s / 0 s), refresh on re-entry, timed traps as on/off Hazards.
- *(proposed)* Knockback: `knockback_resistance` 0–1 (bosses 1), unit-on-unit impacts, impact speed on ImpactContext.
- *(proposed)* Reaction triggers: the seven listed above.
- *(proposed)* Destructibles: `hits_to_break` 1, any HitContext, loot table drops, nav update, grapple detaches.
- *(proposed)* Kill credit: source Unit on HitContext, ImpactContext and Hazard; environment kills credit the displacer or hazard owner.
- *(proposed)* 3/4 depth: y-sorted Entities, colliders at the feet, silhouettes later, `low_obstacle` never blocks projectiles.
