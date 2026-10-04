# WORLD_INTERACTION.md: Abilities vs. the World

**Read when:** abilities touch the world (grapples, blinks, dashes into walls, knockback into terrain), or the task involves collision layers, tile tags, interactables (puzzle elements included), hazards, pits, destructibles or kill credit.
**Depends on:** CLAUDE.md, MOVEMENT.md.
**Used by:** DUNGEONS (puzzle elements as interactables with element rules, plates and signature hazards as Hazards, breakable walls as destructibles, doors, pits and pit-drops), 3D.md (footprints on these layers), COMBAT (reaction triggers), LOOT (pickups on layer 9, destructibles' drops), ENEMIES_AI (sight through WorldQuery, ambush triggers, a dodge's free-floor check).

## Current code
- Rooms are `res://scenes/rooms/room_XX.tscn`, each with a `Tiles` TileMapLayer (`dungeon_tileset.tres`, 32 px, physics layer 0 → collision layer 1 "world"), an `Entities` node, and a `PlayerSpawn` marker.
- **Built in 3D pivot P8 (3D.md, Rooms):** new rooms are built in 3D as layouts. Each blocking asset carries a `Footprint` (wall, low obstacle, pit or ledge), and at load the layout makes the same kind of 2D `Room` the game plays in: colliders on these layers, `Entities` from sim markers, the navigation bake (walls, pits, low obstacles and ledges carved). Footprints get `SurfaceTags` when that exists (Surface tags; not built). Everything below applies to both kinds of room. Tile rooms stay for the test fixtures.
- Levels are hand-made rooms stitched together. DUNGEONS.md (written 2026-10-03): a dungeon's wings are runs of hand-built spaces over floors, each floor its own sim room (or rooms) joined by stairs, ladders, lifts or pit-drops with a fade; doors, arenas and floor links live there.
- `Hitbox` and `Hurtbox` Areas already exist. Hitboxes sit on the owner's attack layer and carry `damage` and `knockback`. No scene uses a Hitbox yet; hits go through the hit pipeline (COMBAT.md).

## Core principle: three layers, one job each
1. **Physics layers** answer *what collides with what*.
2. **Surface tags** answer *what a surface means for gameplay* (grappleable, destructible...).
3. **Ability → movement bridge**: abilities never set position or velocity themselves. They call MovementComponent methods (`dash`, `displace`, `leap` (LOOT L6), `blink` (ABILITIES AB15), and later `pull_to`, `orbit`, `tether`).

Example: an Akshan-style swing is an ability that asks `WorldQuery` for a grappleable wall, then calls `movement.orbit(...)`.

## Collision layers (1–7 and 11 are named in `project.godot`; add the others as systems need them)
| # | Name | What's on it | Status |
|---|---|---|---|
| 1 | world | walls, pillars (tiles with collision) | exists |
| 2 | player | player body | exists |
| 3 | enemies | enemy bodies | exists |
| 4 | player_attack | player hitboxes and projectiles | exists |
| 5 | enemy_attack | enemy hitboxes and projectiles | exists |
| 6 | pit | chasms (`Pits` TileMapLayer): block walking only, not dashes, other displacements (knockback, blink, pull, swing) or projectiles | planned; a layout's pit footprints are on it since P8 and carved from the navigation, but nothing masks it until the pit step (Ryan, 2026-10-03) |
| 7 | low_obstacle | fences, rubble: block walking, not projectiles | exists (3D pivot P8: a layout's low-obstacle footprints; the fence in the room kit) |
| 8 | interactable | chests, doors, shrines, NPC talk zones; with DUNGEONS: checkpoints, levers, braziers, statues, collectibles opened like chests | planned |
| 9 | pickup | dropped loot, gold, potions; with DUNGEONS: collectibles picked up like loot | built (LOOT L7, 2026-10-04): `Pickup` on it, `PickupComponent` masks it |
| 10 | hazard | traps, damaging floors; with DUNGEONS: pressure plates, each theme's signature hazards, "dark rooms" *(proposed there)* | planned |
| 11 | ledge | cliff edges, derived from the walkable ground at room load (3D.md, Terrain and height): block walking and dashes, not projectiles or line of sight | exists (3D pivot P9: `RoomLayout.derive_ledges()`, one `Ledges` body per room built in 3D; Ryan, 2026-10-01) |

Planned: walking masks world, pit, low_obstacle, ledge, and the other team's bodies. As it is today: the player's and the slimes' bodies both mask 1095 (world, player, enemies, low_obstacle since P8, ledge since P9; Ryan 2026-10-03: fences block walking now, pits wait for their step), so units also collide with their own team (the pit layer isn't masked yet). A low obstacle or a ledge also stops `displace()` (knockback, swing steps), which keeps the unit's mask, unless the unit is knocked up (Knocked up, below). **A ghosted `dash()` (the dash, Lunge) masks world and ledges while it runs** (`MovementComponent.GHOST_KEEP_MASK`, `1 | 1024`; built in P9, the approved one-line replace of `collision_mask & 1`): cliffs stop it; pits, fences and units don't. `displace()` keeps the unit's own mask (minus the pit layer once pits exist: Pits and movement types).

## Surface tags
- **Tiles:** add TileSet **custom data layers** to `dungeon_tileset.tres` with bools `grappleable`, `destructible`, `bounce`, `wall_slam`, and set them per tile.
- **Non-tile bodies** (crates, doors, pillars placed as scenes): a `SurfaceTags` node (`res://scripts/components/surface_tags.gd`) with the same `@export` flags.
- **Layout assets (3D.md, Rooms):** the flags are set on the asset's `Footprint`, and the body the layout generates for it gets a `SurfaceTags` with them, so `WorldQuery` reads them like any non-tile body.
- Plain wall default: grappleable = true, everything else false.
- `WorldQuery` hides the difference: for a TileMapLayer hit it gets the cell via `get_coords_for_body_rid()` and reads the tile data. For anything else it reads `SurfaceTags`.

## WorldQuery (autoload, `res://scripts/autoload/world_query.gd`)
This is the only place raycasts are written, with one exception today: each Enemy's own `Sight` RayCast2D (`slime.tscn`, mask 1, used by `enemy.gd` `_can_see_player()` for aggro), older than WorldQuery; it moves into `has_line_of_sight()` when ENEMIES_AI.md reworks aggro (written 2026-10-03: its AI2; sight stays on layer 1, so ledges don't block it; the `Sight` node stays until Ryan OKs removing it). It's built on `PhysicsDirectSpaceState2D` (`intersect_ray`, `intersect_shape`, `cast_motion`). No `debug_draw` yet (How to answer, below, asks for one): add it with the next query.
Built:
- `has_line_of_sight(from, to, mask = 1)`: walls only; units don't block it. The melee target pull and every hit (COMBAT.md: basic attacks never hit through walls; abilities unless `ignores_walls`).
- `shape_sweep(from, to, radius, mask = 1)`: the first block along the path (prevents tunneling; projectiles, ABILITIES.md). A circle through `cast_motion`; returns {position (the circle's center where it stops), fraction} or {} when clear.

Planned:
- `raycast_terrain(from, dir, max_dist_px) -> Dictionary {position, normal, collider, tags}` (empty if nothing hit)
- `find_grapple_point(from, dir, max_dist_px)`: the first world hit must be `grappleable`, otherwise empty
- `resolve_valid_position(target, from, radius, mask)`: if a circle of `radius` at `target` overlaps something on `mask`, moves it the shortest way out with `push_out(point, from, radius, mask)`. Its center never crosses anything, and with the center inside, the move never goes farther from `from`. Failing that, it steps back toward `from` until it doesn't overlap. Built minimal in 3D pivot P9 for a knock-up's landing, with `is_point_free()`; `push_out()` is the fix after P9's check (3D.md, Built in P9, Landing). A blink's use (walls only; pits are valid endpoints: a displacement that ends over one follows the pit rule, Pits and movement types) comes with the blink.
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

### Puzzle elements (DUNGEONS.md, Puzzles and secrets; Ryan 2026-10-03: one framework on tags, ReactionRules and Events, no parallel system; the shape *(proposed there)*)
A puzzle element (a brazier, a lever, a plate, a cracked wall, a collapsing bridge, a statue, a locked door) is an interactable as above, with two additions:
- **a state** (`StringName`: `&"off"`, `&"lit"`, `&"broken"`...), shown by its view;
- **element rules:** `ReactionRule`s the element holds, matched against its own events by the matcher `Reactions` already runs for world and unit rules (a third kind of rule): `HIT` with `required_hit_tags` (a `fire` hit lights a brazier), `IMPACT` with `min_impact_speed_px` (a knocked body slams a switch), `HAZARD_ENTERED` / `HAZARD_EXITED` (a plate), and a new ninth trigger, `INTERACTED` (`on_interact()`: F on the element; the other unit is the player who pressed). Their effects are the existing GameplayEffects plus one new kind, `SetWorldStateGameplayEffect`, which sets a world state of the run that doors, bridges, quests and the codex read through a new `Condition.Kind.WORLD_STATE`.
- *(proposed there)* The base class is `Interactable` (`res://scripts/interactables/interactable.gd`), holding `interaction_tags`, `state` and `rules`.
- **What the four puzzle kinds need from this doc:**
  - **pressure plates** are Hazard-style areas (Hazards: a tag such as `plate` and the "while inside" option, no status needed); `required_unit_tags` on the rule can ask for a knocked enemy (`displaced`);
  - **breakable walls** hiding secrets are destructibles (`hits_to_break`, navigation updated when they break), each with a clue in sight (DUNGEONS.md);
  - **collapsing bridges** need pits: the bridge's floor gives way under its pit footprint after a delay, so they wait for the pit step;
  - **doors** shut until their conditions pass: a body on layer 1 while shut, the navigation updated as a destructible's.
- **Never kit-locked** (DUNGEONS.md): a combat-linked puzzle on the main path always has a way every champion can do (a torch to carry fire from, a lever beside the plate).

## Pits and movement types (approved by Ryan 2026-09-30; ready to build, not yet in a build order: Movement step 8 was removed 2026-09-25. DUNGEONS.md lists the pit step before its D1: every wing has pits)
- `Unit` gets a movement type enum, `enum MovementType { GROUND, FLYING }` with `@export var movement_type`. FLYING ignores the pit layer and never falls.
- One rule for all units: any displacement (dash, knockback, blink, swing) that ends with the unit's feet **8 px or more** inside a pit makes it fall. Less than 8 px snaps it back to the edge.
- **Every displacement ignores the pit layer while it runs**, the exemption a ghosted `dash()` already has: `displace()` (knockback, swing steps), `blink()`, `pull_to()` and `orbit()` take layer 6 out of the unit's `collision_mask` when they start and put it back when they end (any way they end), keeping every other bit (so knockback still slides along walls and stops on units). Otherwise a pit edge would stop the unit like a wall and no push could ever carry it the 8 px the rule needs. `blink()`'s endpoint check (`resolve_valid_position`) resolves walls only and leaves pits to the 8 px rule, for the same reason. Walking keeps the pit layer: a unit never walks into a pit.
- **The player falls:** takes 5% of max health (can't drop below 1 health), then respawns on the last safe tile (the last floor tile the player stood fully on).
- **An enemy falls:** it dies, the kill goes to whoever caused the displacement (Kill credit), and its drops land on the nearest walkable point outside the pit (a room built in 3D has no tiles; (LOOT sync, approved 2026-10-03) `WorldQuery.push_out()`, LOOT.md, Pickups). **Bosses never fall;** they snap to the edge.
- Pit tiles have no navigation polygon, so enemies never path into them. (Today `Room._bake_navigation()` only carves colliders on layer 1 from the `navigation_source` group, so whatever builds pits has to add them to that bake.)
- Pits get their own TileMapLayer, `Pits`, with physics on layer 6. Floor and walls stay on `Tiles`. **In a layout** (3D.md, Rooms) a pit is an asset (a hole in the floor) whose `Footprint` is kind PIT (layer 6); the bake leaves it out the same way.
- **Pit-drops are not pits** *(proposed in DUNGEONS.md)*: a pit-drop that leads to a wing's lower floor is a `FloorLink` (kind `DROP`), not a pit footprint. The party goes down with a fade and takes no damage; an enemy knocked into one falls as into a pit (it dies, kill credit as above). Every other pit keeps the rules above.
- **Knocked up** (3D.md, Terrain and height 1a): an airborne, displaced unit also drops the low-obstacle and ledge layers (7, 11), so a knock-up can carry an enemy over a fence, off a cliff or into a pit (the pit rule applies where it lands). Inside a low obstacle or a ledge's footprint, `resolve_valid_position()` puts it on the nearest floor on the side it came from; a body only overlapping one (its center clear) stays on the ground its center is over (the P9 fix). No fall damage for now (Ryan, 2026-10-01).
- **Leaping** (3D.md, Leaps; Ryan, 2026-10-03): a champion's own leap goes over everything, walls and pits included, and lands on the nearest walkable floor of the room to its aimed point, so it never lands in a pit (a pit isn't walkable floor).

## Hazards (approved by Ryan 2026-09-30)
A `Hazard` is an Area2D scene on layer 10 with:
- `tags` (e.g. `&"oil"`, `&"fire"`)
- `source`: the Unit that made it, or null = the environment
- team filter (default: affects everyone)
- `tick_interval` = 0.5 s
- `lifetime` (-1 = permanent)
- `arm_time`: a telegraph before it activates. Default 0.5 s for enemy- and trap-made hazards, 0 for player-made ones.

Entering applies its status; re-entering refreshes it instead of stacking. It emits `hazard_entered` / `hazard_exited`. Timed traps are Hazards with an on/off cycle.
- **Themes** (DUNGEONS.md, Themes; Ryan 2026-10-03): each wing theme has 2–3 signature hazards (blood pools that heal enemies, sunlight shafts, glyph traps...) plus the shared basics (fire, oil, pits). A signature hazard is data on this Hazard (its tags, its status, its reaction rules), never code per wing, and shows its telegraph during `arm_time` like every hazard. Darkness or weather that changes play is a Hazard with a status too; the view only shows it.
- **Ambush triggers** (ENEMIES_AI.md, Spawning; *proposed there*): an `Ambush`'s trigger is a region the party enters, a Hazard-style area on layer 10 with no status (like a plate), and/or Conditions on world states (DUNGEONS.md: a chest opened, a lever pulled). Its enemies then emerge after a floor telegraph, aggroed at once. No new trigger kind: the ambush listens to its own area, as a perch does.
- **"While inside" option** (for perches, 3D.md, Terrain and height 2): the status lasts while the unit stays inside and is removed when it leaves, instead of running its own duration. A perch is a Hazard-style area giving `status_elevated` this way. In a layout, hazards and perches are placed with sim markers; their look comes through the view mechanism. **Built for perches in 3D pivot P9** (`Perch`, `scripts/world/perch.gd`, `scenes/world/perch.tscn`): standing inside means the unit's feet (its position) are inside, so a unit pressed against the cliff below never counts; the Hazard itself isn't built.

## Knockback (approved by Ryan 2026-09-30)
- New stat `knockback_resistance`, 0–1, scales displacement distance by (1 − value). Bosses have 1. (Row in STATS.md.)
- A displaced unit that hits another unit emits `unit_impacted` with that unit as the collider, so rules can make chain hits.
- `ImpactContext` carries the impact speed, so rules can set thresholds.
- Two knockbacks at once: the stronger wins (COMBAT.md; built in COMBAT C4): `displace()` is dropped (returns false) when the running displacement has more distance left than the new one's whole distance.

## Reaction triggers *(specified in COMBAT.md, ReactionRule)*
`ReactionRule.Trigger` has 8: `IMPACT`, `HIT`, `HAZARD_ENTERED`, `HAZARD_EXITED`, `STATUS_APPLIED`, `UNIT_DIED`, `HAZARD_OVERLAP` (hazard meets hazard, e.g. fire + oil), `ABILITY_CAST` (ABILITIES.md). 4 are built (`HIT`, `UNIT_DIED`, `STATUS_APPLIED`, `ABILITY_CAST`); the 4 world ones (`IMPACT` and the three hazard triggers) are approved (Ryan, 2026-09-30) and get built with impacts and Hazards here. The same list is in CONVENTIONS.md, Extension pattern 1. *(proposed in DUNGEONS.md)* A ninth, `INTERACTED` (F on an interactable), comes with the puzzle elements (Interactables, Puzzle elements); it joins this list and CONVENTIONS' when Ryan approves the name.

## Destructibles (approved by Ryan 2026-09-30)
- `hits_to_break` (default 1). Any `HitContext` counts.
- Drops come from a loot table (LOOT.md).
- Navigation updates in their area when they break.
- **Secrets** (DUNGEONS.md): a breakable wall hiding a secret is a destructible with an element rule; its break sets a world state (a found secret, saved). It always has a small clue in sight first (a crack, a draft, a stain, a note).
- A grapple hooked to one detaches when it breaks, with the same tangent dash as a manual detach (300 u / 96 px over 0.15 s; the Grapple Swing example below), not a dead stop: the swing's momentum carries on, the player stays in control, and a break reads the same as letting go. A detach dash that ends over a pit follows the pit rule, as a manual one does.

## Kill credit (approved by Ryan 2026-09-30)
- `HitContext`, `ImpactContext` and `Hazard` all carry a source Unit.
- When the environment kills something (pit, wall slam, hazard), credit goes to whoever caused the displacement or owns the hazard; null = the environment.
- On-kill effects and drops use this.

## 3/4 depth (approved by Ryan 2026-09-30; the draw order is superseded by the 3D view)
- The `Entities` node is y-sorted (already true in `sandbox.tscn`, and `room.gd` expects it). In the 3D view the depth buffer orders everything, so y-sort only matters for the 2D game until the milestone.
- Colliders sit at the feet (the player's already does).
- ~~Units behind tall walls get a silhouette (later).~~ In 3D, walls, buildings and plateaus marked to fade fade (dithered) while they stand between the camera and the player (Ryan after P0b, 2026-10-02; 3D.md).
- `low_obstacle` never blocks projectiles.

## Terrain (3D.md, Terrain and height)
The sim stays a flat floor; height is the view's. In short:
- Real terrain height (stairs, ramps, hills, plateaus) comes from the layout's walkable ground. Ramps and stairs are plain floor in the sim, and slopes don't change speed.
- Where the ground steps by more than 0.3 m with no ramp or stairs, a **ledge** (layer 11) is made at load. It blocks walking, dashes and navigation, not projectiles or line of sight (`WorldQuery` and `Sight` mask layer 1 only).
- Overlapping floors (a bridge over enemies, a balcony) are separate rooms joined by stairs or doors.
- Perches and the `elevated` tag, knock-ups (airborne), "no unanswerable enemy", and what this approach can't do (gravity, high-ground bonuses, arcs over walls, true 3D line of sight): 3D.md.

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
- ~~**Doors, room locking and room transitions** belong in DUNGEONS.md.~~ Answered in DUNGEONS.md (2026-10-03): doors that open on conditions (`Door`), arenas that seal their doors until cleared (`Arena`), and floor links between a wing's floors with a fade (`FloorLink`: stairs, ladders, lifts, pit-drops). Its shapes and names are *(proposed)* there.
- ~~The *(proposed)* sections above await Ryan's OK~~: approved 2026-09-30 (Pits and movement types with the pit-layer exemption for every displacement; Hazards, Knockback, Reaction triggers, Destructibles with the tangent-dash detach, Kill credit, 3/4 depth). Pits still need a place in a build order.
- **A build slot for the world pieces** (DUNGEONS.md, Build order, Before D1): its D1 needs interactables (layer 8), Hazards (layer 10 and the three hazard triggers), `IMPACT` and `ImpactContext`, destructibles, `SurfaceTags` on footprints, and the pit step. None has a place in a build order yet; where they go, and in what order, is Ryan's call.
