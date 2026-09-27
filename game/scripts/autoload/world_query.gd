extends Node
## Spatial queries, autoloaded as WorldQuery (WORLD_INTERACTION.md). This is
## the only place raycasts are written. Line of sight and a circle sweep
## (projectiles, ABILITIES AB7) exist so far; the rest of the planned API is
## in WORLD_INTERACTION.md.

## Collision layer 1: walls and pillars.
const WORLD_MASK := 1


## True if nothing on `mask` (default: the world layer, i.e. walls) lies on
## the straight line from `from` to `to`. Units are never on layer 1, so they
## don't block it.
func has_line_of_sight(from: Vector2, to: Vector2, mask: int = WORLD_MASK) -> bool:
	var world := get_tree().root.world_2d
	if world == null:
		return true
	var query := PhysicsRayQueryParameters2D.create(from, to, mask)
	return world.direct_space_state.intersect_ray(query).is_empty()


## Moves a circle of `radius` px from `from` to `to` and returns where it
## first touches something on `mask` (default: walls): {position (the circle's
## center where it stops), fraction (0-1 of the way)}. Empty if the way is
## clear. Prevents tunneling: a fast projectile can't skip a thin wall.
func shape_sweep(from: Vector2, to: Vector2, radius: float, mask: int = WORLD_MASK) -> Dictionary:
	var world := get_tree().root.world_2d
	if world == null or from.is_equal_approx(to):
		return {}
	var circle := CircleShape2D.new()
	circle.radius = maxf(radius, 0.5)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, from)
	params.motion = to - from
	params.collision_mask = mask
	var result := world.direct_space_state.cast_motion(params)
	if result.is_empty() or result[0] >= 1.0:
		return {}
	return {"position": from + (to - from) * result[0], "fraction": result[0]}
