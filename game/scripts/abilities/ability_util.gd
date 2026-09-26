class_name AbilityUtil
## Hit-detection helpers for abilities. Shapes use each target's gameplay
## radius, so big monsters are easier to hit, like in LoL.


static func enemies_of(caster: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var u := node as Unit
		if u and u.is_alive() and caster.is_enemy_of(u):
			out.append(u)
	return out


## Enemies inside a cone starting at `origin`, pointing along `dir`.
static func in_cone(caster: Unit, origin: Vector2, dir: Vector2, range_px: float, half_angle: float) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in enemies_of(caster):
		var to := u.global_position - origin
		var d := to.length()
		var r := u.get_gameplay_radius_px()
		if d - r > range_px:
			continue
		if d <= r:
			out.append(u)  # Standing on top of us.
			continue
		var slack := asin(clampf(r / d, 0.0, 1.0))
		if absf(dir.angle_to(to)) <= half_angle + slack:
			out.append(u)
	return out


## Enemies touching a capsule from a to b.
static func along_segment(caster: Unit, a: Vector2, b: Vector2, half_width_px: float) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in enemies_of(caster):
		var closest := Geometry2D.get_closest_point_to_segment(u.global_position, a, b)
		if closest.distance_to(u.global_position) <= half_width_px + u.get_gameplay_radius_px():
			out.append(u)
	return out


static func in_circle(caster: Unit, center: Vector2, radius_px: float) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in enemies_of(caster):
		if u.global_position.distance_to(center) <= radius_px + u.get_gameplay_radius_px():
			out.append(u)
	return out


## Only the units in line of sight from `from` (walls block it, units don't;
## feet to feet). COMBAT C7: attacks never hit through walls.
static func in_sight(from: Vector2, units: Array[Unit]) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if WorldQuery.has_line_of_sight(from, u.global_position):
			out.append(u)
	return out


## The enemy nearest to `point` within `max_dist_px` (for forgiving clicks).
static func nearest_enemy_to(caster: Unit, point: Vector2, max_dist_px: float) -> Unit:
	var best: Unit = null
	var best_d := INF
	for u in enemies_of(caster):
		var d := minf(point.distance_to(u.get_center()), point.distance_to(u.global_position)) - u.get_gameplay_radius_px()
		if d <= max_dist_px and d < best_d:
			best = u
			best_d = d
	return best
