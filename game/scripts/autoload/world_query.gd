extends Node
## Spatial queries, autoloaded as WorldQuery (WORLD_INTERACTION.md). This is
## the only place raycasts are written. Only line of sight exists so far;
## the rest of the planned API is in WORLD_INTERACTION.md.

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
