class_name MovementComponent
extends Node2D
## League-of-Legends-style unit movement for a CharacterBody2D parent.
##
## - move_to(point) paths around walls using the navigation map; clicking
##   inside a wall walks to the closest reachable spot.
## - Instant top speed and instant turning, no acceleration or sliding,
##   and stops exactly on the destination.
## - Units block each other. Local steering looks ahead and picks a nearby
##   direction that won't collide, so units flow smoothly around each other
##   (moving ones too) instead of bumping and getting stuck. Everyone prefers
##   passing on the right, so two units walking head-on don't "dance".
## - Movement speed is in LoL units (345 = typical champion) with LoL's
##   rules: flat bonuses, then % bonuses (additive), then only the strongest
##   slow, then the soft caps (thresholds are exports; the defaults are
##   LoL's 220 / 415 / 490 scaled x560/345 for Hades pace, see MOVEMENT.md).
##   With a StatsComponent (set_stats_component(), done by Unit) the speed is
##   its move_speed stat, and add_speed_modifier() is a thin wrapper that
##   adds StatModifiers under the modifier's id and keeps only the timer here
##   (STATS.md step 4). Without one, base_move_speed and the modifiers here
##   are used as before.
## - Move locks (cast times, attack windups, stuns) pause movement but keep
##   the move order, so you carry on to your destination afterwards.
## - displace() pushes the unit (knockbacks, dashes) and overrides walking.
##   A displacement follows a progress Curve (x = time 0-1, y = share of the
##   distance 0-1): burst then ease out. The total distance is always
##   velocity x duration; only the speed profile changes (MOVEMENT.md F2).
## - set_input_direction(dir) is Hades-style direct control (the player's
##   WASD): a short ramp up and down, instant turning, sliding along walls.
##   While a direction is held it replaces any move_to() order.
## - Priority: displacement > move lock > walking (input or path).

signal destination_reached
signal order_cancelled
signal displacement_finished

const STEER_ANGLES := [0.0, 15.0, -15.0, 30.0, -30.0, 45.0, -45.0, 65.0, -65.0, 90.0, -90.0, 120.0, -120.0]
const STEER_SPEEDS := [1.0, 0.5]
## How much of the speed beyond each soft cap threshold counts (LoL rules).
const SOFT_CAP_LOW_FACTOR := 0.5
const SOFT_CAP_HIGH_FACTOR := 0.8
const SOFT_CAP_MAX_FACTOR := 0.5

## Base movement speed in LoL units. Only used without a StatsComponent;
## Units take move_speed from their UnitStats through StatsComponent.
@export var base_move_speed: float = 345.0
## Collision/steering radius in pixels. Unit sets this from its stats.
@export var radius_px: float = 11.0

@export_group("Input movement")
## Seconds from standing still to full speed with set_input_direction().
@export var input_accel_time: float = 0.05
## Seconds from full speed to a stop when the input is released.
@export var input_decel_time: float = 0.04

@export_group("Soft caps")
## Below this speed (LoL units) only half the shortfall counts. LoL: 220.
@export var soft_cap_low: float = 357.0
## Above this, the excess counts x0.8. LoL: 415.
@export var soft_cap_high: float = 674.0
## Above this, the excess counts x0.5. LoL: 490.
@export var soft_cap_max: float = 795.0

@export_group("Steering")
@export var avoidance_enabled: bool = true
## When false, this unit never swerves around others on its own (the
## player: WASD must never be deflected). Unlike avoidance_enabled, the unit
## still takes part in avoidance, so other units keep steering around it.
@export var use_steering: bool = true
## How far ahead (seconds) units look to dodge each other. Higher = earlier,
## wider swerves; lower = tighter, later swerves.
@export var avoidance_time_horizon: float = 0.6
## Extra space (px) kept between units when steering around them.
@export var avoidance_margin: float = 2.0

@export_group("Displacement")
## Speed profile used by displace() when no curve is passed (knockback).
## null = constant speed.
@export var knockback_curve: Curve = preload("res://data/curves/curve_knockback.tres")

@export_group("Debug")
## Draws the current path. Handy while tuning.
@export var debug_draw_path: bool = false
## Draws a graph of the last debug_graph_time seconds of speed (px/s) above
## the unit. Handy while tuning displacement curves.
@export var debug_draw: bool = false
## Speed (px/s) at the top of the graph.
@export var debug_graph_max_speed_px: float = 1500.0
## Seconds of history shown in the graph.
@export var debug_graph_time: float = 1.0

var body: CharacterBody2D

var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _has_order: bool = false
var _destination: Vector2 = Vector2.ZERO
var _move_dir: Vector2 = Vector2.ZERO

var _locks: Dictionary = {}          # id -> true
var _modifiers: Dictionary = {}      # id -> {flat, percent, time_left}
var _stats: StatsComponent = null    # set by Unit; null = standalone speed math

var _displace_velocity: Vector2 = Vector2.ZERO
var _displace_time: float = 0.0      # seconds left
var _displace_duration: float = 0.0
var _displace_elapsed: float = 0.0
var _displace_offset: Vector2 = Vector2.ZERO   # total distance = velocity x duration
var _displace_curve: Curve = null
var _curve_start: float = 0.0
var _curve_end: float = 1.0
var _ghost_saved_mask: int = -1

var _stuck_time: float = 0.0
var _repath_time: float = 0.0
var _steer_side: float = 0.0         # side we last swerved to (hysteresis)

var _input_dir: Vector2 = Vector2.ZERO       # held direction, length <= 1
var _input_last_dir: Vector2 = Vector2.ZERO  # keeps sliding this way while stopping
var _input_speed_px: float = 0.0             # current input walking speed

var _debug_line: Line2D
var _speed_samples: Array[Vector2] = []   # (time, speed px/s) for debug_draw
var _last_pos: Vector2 = Vector2.INF
var _clock: float = 0.0


func _ready() -> void:
	body = get_parent() as CharacterBody2D
	assert(body != null, "MovementComponent must be a child of a CharacterBody2D")
	add_to_group(&"steering_units")
	if debug_draw_path:
		_debug_line = Line2D.new()
		_debug_line.width = 1.0
		_debug_line.default_color = Color(0.4, 1.0, 0.5, 0.6)
		_debug_line.top_level = true
		_debug_line.z_index = 50
		add_child(_debug_line)
	if debug_draw:
		z_index = 60


func set_radius(px: float) -> void:
	radius_px = px


## Stop taking part in steering (e.g. when dead); others ignore us too.
func disable_avoidance() -> void:
	avoidance_enabled = false
	remove_from_group(&"steering_units")


# --- Orders -----------------------------------------------------------------

func move_to(target: Vector2) -> void:
	var previous := _destination
	var had_order := _has_order
	_compute_path(target)
	# Re-issuing (nearly) the same order, e.g. while chasing, keeps the
	# "am I stuck?" timer running so we still notice being blocked.
	if not had_order or previous.distance_to(_destination) > 8.0:
		_stuck_time = 0.0
	_has_order = true
	_repath_time = 0.0
	_update_debug_line()


func stop() -> void:
	var had_order := _has_order
	_clear_order()
	if had_order:
		order_cancelled.emit()


func is_moving() -> bool:
	return _has_order and can_move()


func has_order() -> bool:
	return _has_order


func get_destination() -> Vector2:
	return _destination


## Direction the unit is currently walking in (zero when standing still).
func get_move_direction() -> Vector2:
	return _move_dir


# --- Input movement (WASD) ------------------------------------------------------

## Direct control. `dir` is the held direction (length 0..1, zero = let go).
## Call every physics frame. A non-zero direction cancels any move_to() order.
func set_input_direction(dir: Vector2) -> void:
	_input_dir = dir.limit_length(1.0)
	if _input_dir != Vector2.ZERO and _has_order:
		stop()


func get_input_direction() -> Vector2:
	return _input_dir


## True while walking from input, including the short stop after letting go.
func is_input_moving() -> bool:
	return _input_speed_px > 0.0


# --- Locks (cast times, windups, stuns, roots) --------------------------------

func add_move_lock(id: StringName) -> void:
	_locks[id] = true


func remove_move_lock(id: StringName) -> void:
	_locks.erase(id)


func can_move() -> bool:
	return _locks.is_empty()


# --- Displacement (knockbacks, dashes) ----------------------------------------

## Push the unit: it covers velocity x duration in total. `curve` shapes
## the speed; with no curve, knockback_curve is used.
func displace(velocity: Vector2, duration: float, curve: Curve = null) -> void:
	_end_ghost()
	_start_displacement(velocity, duration, curve if curve != null else knockback_curve)


## Dash at `velocity` (average) for `duration` seconds. Ghosted by default:
## passes through other units; walls still block it, and it slides along
## them (move_and_slide). `curve` shapes the speed; null = constant speed.
## Await `displacement_finished` to know when it's over.
func dash(velocity: Vector2, duration: float, ghosted: bool = true, curve: Curve = null) -> void:
	_end_ghost()
	_start_displacement(velocity, duration, curve)
	if ghosted:
		_ghost_saved_mask = body.collision_mask
		body.collision_mask = body.collision_mask & 1  # walls only


func _end_ghost() -> void:
	if _ghost_saved_mask >= 0:
		body.collision_mask = _ghost_saved_mask
		_ghost_saved_mask = -1


func is_displaced() -> bool:
	return _displace_time > 0.0


func _start_displacement(velocity: Vector2, duration: float, curve: Curve) -> void:
	_displace_velocity = velocity
	_displace_time = duration
	_displace_duration = maxf(duration, 0.0001)
	_displace_elapsed = 0.0
	_displace_offset = velocity * duration
	_displace_curve = curve
	if curve != null:
		_curve_start = curve.sample(0.0)
		_curve_end = curve.sample(1.0)


## Share of the distance covered at time share t (0-1). Normalized so a
## curve that doesn't run exactly 0 -> 1 still covers the full distance.
func _displacement_progress(t: float) -> float:
	if _displace_curve == null or absf(_curve_end - _curve_start) < 0.0001:
		return t
	return (_displace_curve.sample(t) - _curve_start) / (_curve_end - _curve_start)


## Start input walking at full speed right away, e.g. running out of a dash.
func set_input_speed_to_max() -> void:
	if _input_dir == Vector2.ZERO:
		return
	_input_last_dir = _input_dir.normalized()
	_input_speed_px = Units.to_px(get_move_speed()) * _input_dir.length()


# --- Movement speed ---------------------------------------------------------

## Movement speed comes from this unit's StatsComponent from now on (the
## move_speed stat, soft caps included).
func set_stats_component(stats: StatsComponent) -> void:
	_stats = stats
	for id: StringName in _modifiers.keys():
		_add_speed_stat_modifiers(id, _modifiers[id].flat, _modifiers[id].percent)


## percent: 0.2 = +20% MS, -0.3 = 30% slow. duration < 0 = until removed.
## Re-adding an id replaces it. With a StatsComponent the modifier lives there
## (source_id = id) and only the timer is kept here.
func add_speed_modifier(id: StringName, flat: float = 0.0, percent: float = 0.0, duration: float = -1.0) -> void:
	_modifiers[id] = {"flat": flat, "percent": percent, "time_left": duration}
	if _stats != null:
		_stats.remove_modifiers_from(id)
		_add_speed_stat_modifiers(id, flat, percent)


func remove_speed_modifier(id: StringName) -> void:
	_modifiers.erase(id)
	if _stats != null:
		_stats.remove_modifiers_from(id)


func _add_speed_stat_modifiers(id: StringName, flat: float, percent: float) -> void:
	var mods: Array[StatModifier] = []
	if flat != 0.0:
		mods.append(StatModifier.create(&"move_speed", StatModifier.Type.FLAT, flat, id))
	if percent != 0.0:
		mods.append(StatModifier.create(&"move_speed", StatModifier.Type.PERCENT_ADD, percent, id))
	_stats.add_modifiers(mods)


## Final movement speed in LoL units, after bonuses, slows and soft caps.
func get_move_speed() -> float:
	if _stats != null:
		return _stats.get_stat(&"move_speed")
	var flat := 0.0
	var bonus_percent := 0.0
	var strongest_slow := 0.0
	for mod in _modifiers.values():
		flat += mod.flat
		if mod.percent >= 0.0:
			bonus_percent += mod.percent
		else:
			strongest_slow = maxf(strongest_slow, -mod.percent)
	var raw := (base_move_speed + flat) * (1.0 + bonus_percent) * (1.0 - clampf(strongest_slow, 0.0, 0.99))
	return get_soft_capped_speed(raw)


## Soft caps with this unit's thresholds, written as "threshold + excess x
## factor" so the curve stays continuous for any values. With the LoL
## thresholds (220 / 415 / 490) this equals apply_soft_caps() exactly.
func get_soft_capped_speed(raw: float) -> float:
	if raw > soft_cap_max:
		var at_max := soft_cap_high + (soft_cap_max - soft_cap_high) * SOFT_CAP_HIGH_FACTOR
		return at_max + (raw - soft_cap_max) * SOFT_CAP_MAX_FACTOR
	if raw > soft_cap_high:
		return soft_cap_high + (raw - soft_cap_high) * SOFT_CAP_HIGH_FACTOR
	if raw < soft_cap_low:
		return soft_cap_low - (soft_cap_low - raw) * SOFT_CAP_LOW_FACTOR
	return raw


static func apply_soft_caps(raw: float) -> float:
	if raw > 490.0:
		return raw * 0.5 + 230.0
	if raw > 415.0:
		return raw * 0.8 + 83.0
	if raw < 220.0:
		return raw * 0.5 + 110.0
	return raw


# --- Update -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_modifiers(delta)
	if debug_draw:
		_record_speed(delta)

	if _displace_time > 0.0:
		# Move by this frame's share of the curve. The shares add up to exactly
		# the total offset, so dashes land exactly (walls aside).
		var t0 := _displace_elapsed / _displace_duration
		_displace_elapsed = minf(_displace_elapsed + delta, _displace_duration)
		_displace_time = _displace_duration - _displace_elapsed
		var t1 := _displace_elapsed / _displace_duration
		var step := _displace_offset * (_displacement_progress(t1) - _displacement_progress(t0))
		_move_dir = Vector2.ZERO
		body.velocity = step / delta
		body.move_and_slide()
		if _displace_time <= 0.0:
			body.velocity = Vector2.ZERO
			_end_ghost()
			if _has_order:
				_compute_path(_destination)  # Re-path from where we got pushed to.
			displacement_finished.emit()
		return

	if _input_dir != Vector2.ZERO or _input_speed_px > 0.0:
		_walk_from_input(delta)
		return

	if not _has_order or not can_move():
		_move_dir = Vector2.ZERO
		body.velocity = Vector2.ZERO
		return

	var speed := Units.to_px(get_move_speed())
	var step := speed * delta
	var pos := body.global_position

	# Skip waypoints we're already on, or will pass this frame.
	while _path_index < _path.size() - 1 and pos.distance_to(_path[_path_index]) <= step:
		_path_index += 1

	var to_next := _path[_path_index] - pos
	var dist := to_next.length()
	var arriving := _path_index == _path.size() - 1 and dist <= step

	var desired: Vector2
	if arriving:
		desired = to_next / delta  # Land exactly on the destination.
	elif dist > 0.001:
		desired = to_next / dist * speed
	else:
		desired = Vector2.ZERO

	var velocity := desired
	if avoidance_enabled and use_steering and not arriving:
		velocity = _steer(desired)
	if velocity.length() > 0.01:
		_move_dir = velocity.normalized()

	var before := body.global_position
	body.velocity = velocity
	body.move_and_slide()

	if body.global_position.distance_to(_destination) < 0.75:
		_clear_order()
		destination_reached.emit()
		return

	# Blocked (e.g. someone is standing on our destination): give up quickly
	# once we're close, or after a while otherwise.
	var moved := body.global_position.distance_to(before)
	if moved < step * 0.15:
		_stuck_time += delta
		var near := body.global_position.distance_to(_destination) < radius_px * 3.0
		if (near and _stuck_time > 0.15) or _stuck_time > 0.8:
			stop()
			return
	else:
		_stuck_time = maxf(_stuck_time - delta, 0.0)

	# Re-path now and then, so we don't follow a stale path after swerving.
	_repath_time += delta
	if _repath_time > 0.4:
		_repath_time = 0.0
		_compute_path(_destination)

	_update_debug_line()


## Hades-style walking from set_input_direction(): the speed ramps up over
## input_accel_time and down over input_decel_time, but the direction changes
## instantly. Never steered; move_and_slide() slides along walls.
func _walk_from_input(delta: float) -> void:
	if not can_move():
		_input_speed_px = 0.0
		_move_dir = Vector2.ZERO
		body.velocity = Vector2.ZERO
		return
	var max_speed := Units.to_px(get_move_speed())
	if _input_dir != Vector2.ZERO:
		_input_last_dir = _input_dir.normalized()
		var target := max_speed * _input_dir.length()
		if _input_speed_px > target:
			_input_speed_px = target  # Slows apply at once.
		else:
			var accel := max_speed / maxf(input_accel_time, 0.001)
			_input_speed_px = move_toward(_input_speed_px, target, accel * delta)
	else:
		var decel := max_speed / maxf(input_decel_time, 0.001)
		_input_speed_px = move_toward(_input_speed_px, 0.0, decel * delta)
	_move_dir = _input_last_dir if _input_speed_px > 0.0 else Vector2.ZERO
	body.velocity = _input_last_dir * _input_speed_px
	body.move_and_slide()


## Picks the velocity closest to `desired` that won't run into another unit
## within the look-ahead time, sampling directions that fan out from the
## desired one at full and half speed.
func _steer(desired: Vector2) -> Vector2:
	if desired == Vector2.ZERO:
		return desired
	var pos := body.global_position
	var desired_speed := desired.length()
	var look := desired_speed * avoidance_time_horizon + radius_px * 4.0
	var neighbors: Array[MovementComponent] = []
	for node in get_tree().get_nodes_in_group(&"steering_units"):
		var other := node as MovementComponent
		if other == self or not other.avoidance_enabled:
			continue
		if pos.distance_to(other.body.global_position) < look + other.radius_px:
			neighbors.append(other)
	if neighbors.is_empty():
		_steer_side = 0.0
		return desired

	var base_angle := desired.angle()
	var best := desired
	var best_cost := INF
	var best_side := 0.0
	var best_ttc := INF
	for spd_mult: float in STEER_SPEEDS:
		for deg: float in STEER_ANGLES:
			var a := deg_to_rad(deg)
			var cand := Vector2.from_angle(base_angle + a) * desired_speed * spd_mult
			var ttc := _time_to_collision(cand, neighbors)
			var cost := absf(a) * 0.9 + (1.0 - spd_mult) * 0.9
			if ttc < avoidance_time_horizon:
				cost += (avoidance_time_horizon - ttc) / avoidance_time_horizon * 6.0 + 0.5
			var side := signf(deg)
			# Prefer passing on the right, and stick with the side we picked.
			if side < 0.0:
				cost += 0.05
			if _steer_side != 0.0 and side != 0.0 and side != _steer_side:
				cost += 0.4
			if cost < best_cost:
				best_cost = cost
				best = cand
				best_side = side
				best_ttc = ttc
	# Every option would push straight into someone: wait instead.
	if best_ttc <= 0.0:
		return Vector2.ZERO
	if best_side != 0.0:
		_steer_side = best_side
	elif best_ttc >= avoidance_time_horizon:
		_steer_side = 0.0
	return best


## Seconds until we'd touch a neighbor if we moved at `vel` (INF if not
## within reach; 0 if already touching and still closing in).
func _time_to_collision(vel: Vector2, neighbors: Array[MovementComponent]) -> float:
	var pos := body.global_position
	var best := INF
	for other in neighbors:
		var rel_pos := other.body.global_position - pos
		var rel_vel := vel - other.body.velocity
		var r := radius_px + other.radius_px + avoidance_margin
		var dist_sq := rel_pos.length_squared()
		if dist_sq < r * r:
			if rel_vel.dot(rel_pos) > 0.0:
				return 0.0  # Overlapping and closing in.
			continue
		var a := rel_vel.length_squared()
		var b := rel_pos.dot(rel_vel)
		if a < 0.0001 or b <= 0.0:
			continue  # Not approaching.
		var c := dist_sq - r * r
		var disc := b * b - a * c
		if disc < 0.0:
			continue  # Passes by without touching.
		var t := (b - sqrt(disc)) / a
		if t < best:
			best = t
	return best


func _compute_path(target: Vector2) -> void:
	var map := body.get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(map) == 0:
		# Navigation isn't ready yet (first frame). Walk straight there.
		_path = PackedVector2Array([target])
		_destination = target
	else:
		_destination = NavigationServer2D.map_get_closest_point(map, target)
		_path = NavigationServer2D.map_get_path(map, body.global_position, _destination, true)
		if _path.is_empty():
			_path = PackedVector2Array([_destination])
	_path_index = 0


func _tick_modifiers(delta: float) -> void:
	for id in _modifiers.keys():
		var mod: Dictionary = _modifiers[id]
		if mod.time_left < 0.0:
			continue
		mod.time_left -= delta
		if mod.time_left <= 0.0:
			remove_speed_modifier(id)


func _clear_order() -> void:
	_has_order = false
	_path = PackedVector2Array()
	_path_index = 0
	_move_dir = Vector2.ZERO
	body.velocity = Vector2.ZERO
	_update_debug_line()


func _update_debug_line() -> void:
	if _debug_line == null:
		return
	if not _has_order:
		_debug_line.clear_points()
		return
	var pts := PackedVector2Array([body.global_position])
	for i in range(_path_index, _path.size()):
		pts.append(_path[i])
	_debug_line.points = pts


# --- Debug speed graph --------------------------------------------------------

func _record_speed(delta: float) -> void:
	_clock += delta
	var pos := body.global_position
	if _last_pos != Vector2.INF:
		_speed_samples.append(Vector2(_clock, pos.distance_to(_last_pos) / delta))
	_last_pos = pos
	while not _speed_samples.is_empty() and _speed_samples[0].x < _clock - debug_graph_time:
		_speed_samples.pop_front()
	queue_redraw()


func _draw() -> void:
	if not debug_draw or _speed_samples.size() < 2:
		return
	var w := 60.0
	var h := 30.0
	var origin := Vector2(-w * 0.5, -60.0)   # bottom-left of the graph
	draw_rect(Rect2(origin - Vector2(0, h), Vector2(w, h)), Color(0, 0, 0, 0.45))
	var pts := PackedVector2Array()
	for s in _speed_samples:
		var x := origin.x + (1.0 - (_clock - s.x) / debug_graph_time) * w
		var y := origin.y - clampf(s.y / debug_graph_max_speed_px, 0.0, 1.0) * h
		pts.append(Vector2(x, y))
	draw_polyline(pts, Color(0.4, 1.0, 0.6), 1.0)
	var last := _speed_samples[_speed_samples.size() - 1].y
	draw_string(ThemeDB.fallback_font, origin + Vector2(0, -h - 2), "%d px/s" % roundi(last),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.8))
