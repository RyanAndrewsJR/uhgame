extends Node
## Spatial queries, autoloaded as WorldQuery (WORLD_INTERACTION.md). This is
## the only place raycasts are written. Line of sight and a circle sweep
## (projectiles, ABILITIES AB7) exist so far; the rest of the planned API is
## in WORLD_INTERACTION.md.

## Collision layer 1: walls and pillars.
const WORLD_MASK := 1
## push_out() looks in this many directions on each ring (1 px apart).
const PUSH_OUT_DIRECTIONS := 16


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


## Where a circle of `radius` px can stand at or near `target` without
## overlapping anything on `mask`, on the side of `from` (WORLD_INTERACTION.md;
## built in 3D pivot P9 for a knock-up's landing): `target` if it's free,
## else the shortest move that frees it (push_out()), else the first free
## point stepping back toward `from`, else `from`. Units aren't on these
## layers, so they never count.
func resolve_valid_position(target: Vector2, from: Vector2, radius: float, mask: int = WORLD_MASK) -> Vector2:
	if is_point_free(target, radius, mask):
		return target
	var pushed := push_out(target, from, radius, mask)
	if pushed.is_finite():
		return pushed
	var length := target.distance_to(from)
	var step := 2.0
	var travelled := step
	while travelled < length:
		var p := target.move_toward(from, travelled)
		if is_point_free(p, radius, mask):
			return p
		travelled += step
	return from


## True if a circle of `radius` px at `point` overlaps nothing on `mask`.
func is_point_free(point: Vector2, radius: float, mask: int = WORLD_MASK) -> bool:
	var world := get_tree().root.world_2d
	if world == null:
		return true
	var circle := CircleShape2D.new()
	circle.radius = maxf(radius, 0.5)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, point)
	params.collision_mask = mask
	params.collide_with_areas = false
	return world.direct_space_state.intersect_shape(params, 1).is_empty()


## The shortest move (rings 1 px apart, out to twice `radius`) that frees a
## circle of `radius` px at `point` from what it overlaps on `mask`, its
## center crossing nothing on the way; Vector2.INF if there's none (P9 fix,
## 2026-10-03: a knock-up landing on stairs with its body over their side's
## ledge went all the way back along its push). The center decides: if only
## the body overlaps (a ramp's or stairs' side, a cliff's rim beside it), the
## unit stays on the ground its center is over. If the center itself is
## inside (a fence, a ledge's strip), the move never goes farther along the
## push (from `from` to `point`): it comes out on the side it came from. Of
## equally short moves, the one nearest `from`.
func push_out(point: Vector2, from: Vector2, radius: float, mask: int = WORLD_MASK) -> Vector2:
	var world := get_tree().root.world_2d
	if world == null:
		return Vector2.INF
	var space := world.direct_space_state
	var at_center := PhysicsPointQueryParameters2D.new()
	at_center.position = point
	at_center.collision_mask = mask
	var center_inside := not space.intersect_point(at_center, 1).is_empty()
	var push_dir := (point - from).normalized()
	var circle := CircleShape2D.new()
	circle.radius = maxf(radius, 0.5)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.collision_mask = mask
	params.collide_with_areas = false
	var ray := PhysicsRayQueryParameters2D.create(point, point, mask)
	for d in range(1, ceili(circle.radius * 2.0) + 2):
		var best := Vector2.INF
		for i in PUSH_OUT_DIRECTIONS:
			var dir := Vector2.from_angle(TAU * i / PUSH_OUT_DIRECTIONS)
			if center_inside and dir.dot(push_dir) > 0.01:
				continue
			var candidate := point + dir * d
			params.transform = Transform2D(0.0, candidate)
			if not space.intersect_shape(params, 1).is_empty():
				continue
			ray.to = candidate
			if not space.intersect_ray(ray).is_empty():
				continue
			if not best.is_finite() or candidate.distance_squared_to(from) < best.distance_squared_to(from):
				best = candidate
		if best.is_finite():
			return best
	return Vector2.INF
