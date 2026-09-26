# WORLD_INTERACTION.md: Abilities vs. the World (2D)

**Read when:** abilities touch the world (grapples, blinks, dashes into walls, knockback into terrain), or the task involves collision layers, tile tags, or interactables.
**Depends on:** CLAUDE.md, MOVEMENT.md.

## Current code
- Rooms are `res://scenes/rooms/room_XX.tscn`, each with a `Tiles` TileMapLayer (`dungeon_tileset.tres`, 32 px, physics layer 0 → collision layer 1 "world"), an `Entities` node, and a `PlayerSpawn` marker.
- Levels are hand-made rooms stitched together (DUNGEONS.md, when it exists).
- `Hitbox` and `Hurtbox` Areas already exist. Hitboxes sit on the owner's attack layer and carry `damage` and `knockback`.

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
| 6 | pit | chasms: block walking, not dashing or projectiles | planned |
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
- `raycast_terrain(from, dir, max_dist_px) -> Dictionary {position, normal, collider, tags}` (empty if nothing hit)
- `find_grapple_point(from, dir, max_dist_px)`: the first world hit must be `grappleable`, otherwise empty
- `resolve_valid_position(target, from)`: if an endpoint is in a wall or pit, returns the nearest valid floor point on the caster's side
- `shape_sweep(from, to, radius, mask)`: the first block along the path (prevents tunneling)
- `has_line_of_sight(a, b)`
- `get_units_in_radius(center, r, team_filter)`

## Ability movement (MovementComponent methods)
Existing: `displace(velocity, duration)`, `dash(velocity, duration, ghosted)`.
To add when the first ability needs them:
- `blink(target)`: instant, uses `resolve_valid_position`
- `pull_to(point, speed)`: hook pulls the unit to a point
- `tether(anchor, max_length)`: free movement clamped to a radius around the anchor
- `orbit(anchor, radius, angular_speed, dir_sign, max_angle)`: the swing

Knockback into a wall reads the surface tags: `bounce` ricochets, `wall_slam` stuns.
Each movement method defines how it starts, what ends it, and what happens on hitting a wall or a unit. A stun ends any of them immediately. They emit the existing `displacement_finished` signal.

## Interactables
Scripts go in `res://scripts/interactables/`, scenes in `res://scenes/interactables/`.
- `interaction_tags: Array[StringName]`, e.g. `&"pullable"`, `&"breakable"`, `&"ignitable"`
- `on_ability_hit(caster: Unit, ability: Ability, ctx: CastContext)`
- `on_interact(player: Player)` for the F key

Abilities check tags; they never check class names.

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
