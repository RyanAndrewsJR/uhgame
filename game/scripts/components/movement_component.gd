class_name MovementComponent
extends Node2D
## Unit movement for a CharacterBody2D parent: League-style pathing for
## enemies (and R walking the Knight into range), Hades-style direct control
## for the player (set_input_direction()), and displacements for both.
##
## - move_to(point) paths around walls using the navigation map; a point
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
##   LoL's 220 / 415 / 490 scaled x560/345, kept for the 375 Knight; see
##   MOVEMENT.md). With a StatsComponent (set_stats_component(), done by
##   Unit) the speed is its move_speed stat. add_speed_modifier() is a thin
##   wrapper: with a StatusComponent (COMBAT C9) it applies a slow or haste
##   status; with only a StatsComponent it adds StatModifiers under the
##   modifier's id and keeps the timer here (STATS.md step 4). Without
##   either, base_move_speed and the modifiers here are used as before.
## - Move locks (cast times, attack windups, stuns) pause movement but keep
##   the move order, so you carry on to your destination afterwards.
## - displace() pushes the unit (knockbacks, melee swing steps) and dash()
##   moves it (the player's dash, Lunge); both override walking.
##   A displacement follows a progress Curve (x = time 0-1, y = share of the
##   distance 0-1): burst then ease out. The total distance is always
##   velocity x duration; only the speed profile changes (MOVEMENT.md F2).
## - leap() (LOOT L6; 3D.md, Leaps) sends the unit through the air to a
##   point: over everything, landing on the nearest walkable floor of its
##   room; nothing interrupts it.
## - blink() (ABILITIES AB15, Blinks) moves the unit to a point at once, by
##   the same landing rule; over walls unless told to stop at them.
## - set_input_direction(dir) is Hades-style direct control (the player's
##   WASD): a short ramp up and down, instant turning, sliding along walls.
##   While a direction is held it replaces any move_to() order.
## - Priority: displacement > move lock > walking (input or path).

signal destination_reached
signal order_cancelled
signal displacement_finished
## A blink moved the unit from `from` to `to` at once (ABILITIES AB15): the
## view snaps (UnitView).
signal blinked(from: Vector2, to: Vector2)

const STEER_ANGLES := [0.0, 15.0, -15.0, 30.0, -30.0, 45.0, -45.0, 65.0, -65.0, 90.0, -90.0, 120.0, -120.0]
const STEER_SPEEDS := [1.0, 0.5]
## How much of the speed beyond each soft cap threshold counts (LoL rules).
const SOFT_CAP_LOW_FACTOR := 0.5
const SOFT_CAP_HIGH_FACTOR := 0.8
const SOFT_CAP_MAX_FACTOR := 0.5
## Templates for add_speed_modifier() once statuses exist (COMBAT C9).
## A ghosted dash keeps walls (layer 1) and ledges (11): cliffs stop it;
## pits, low obstacles and units don't (3D.md, Terrain and height 1b).
const GHOST_KEEP_MASK := 1 | (1 << 10)
## While a unit is airborne and displaced (a knock-up), it ignores pits (6),
## low obstacles (7) and ledges (11); walls still stop it (3D.md, Airborne).
const AIRBORNE_IGNORED_MASK := (1 << 5) | (1 << 6) | (1 << 10)
## Where an airborne displacement may not end: inside a wall, a low obstacle
## or a ledge. It lands back toward where it started instead.
const LANDING_BLOCKING_MASK := 1 | (1 << 6) | (1 << 10)
## Where a leap may not land (LOOT L6; 3D.md, Leaps): the knock-up's layers and
## pits (6), which aren't walkable floor.
const LEAP_BLOCKING_MASK := LANDING_BLOCKING_MASK | (1 << 5)
## A blink that stops at walls (ABILITIES AB15) sweeps this small core from
## the unit to find the first wall, like AB13's VECTOR start clamp.
const BLINK_WALL_CORE_PX := 2.0

const STATUS_SLOW: StatusEffect = preload("res://data/statuses/status_slow.tres")
const STATUS_HASTE: StatusEffect = preload("res://data/statuses/status_haste.tres")

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
var _status: StatusComponent         # set: speed modifiers are statuses (COMBAT C9)
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
var _displace_from: Vector2 = Vector2.ZERO   # where the running displacement started
var _displace_dash_cancelable: bool = false
var _displace_serial: int = 0   # bumped by every displacement start
## A leap (LOOT L6): the running displacement is one, the body's mask while
## it runs is 0 (this saved one comes back when it lands), and its two ends.
var _leaping: bool = false
var _leap_saved_mask: int = -1
var _leap_from: Vector2 = Vector2.ZERO
var _leap_to: Vector2 = Vector2.ZERO

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
		_debug_line.visibility_layer |= FloorOverlay.DRAWING_VISIBILITY_BIT   # shows on the 3D floor (the cleanup's C2)
		add_child(_debug_line)
	if debug_draw_path or debug_draw:
		visibility_layer |= FloorOverlay.DRAWING_VISIBILITY_BIT   # (its child line needs it too)
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
## the speed; with no curve, knockback_curve is used. dash_cancelable: the
## unit may dash during it, and the dash replaces it (a melee swing step, a
## hit's knockback; COMBAT.md). Otherwise a displacement blocks the dash.
## The stronger displacement wins (COMBAT.md): if the running one still has
## more distance to cover than this one's whole distance, this one is
## dropped. Nothing interrupts a leap (LOOT L6): dropped while one runs.
## Returns true if this displacement started.
func displace(velocity: Vector2, duration: float, curve: Curve = null, dash_cancelable: bool = false) -> bool:
	if _leaping:
		return false
	if is_displaced() and get_displacement_remaining_px() > velocity.length() * duration:
		return false
	_end_ghost()
	_start_displacement(velocity, duration, curve if curve != null else knockback_curve)
	_displace_dash_cancelable = dash_cancelable
	return true


## Distance the running displacement still has to cover, in px (0 if none).
## Walls it may still hit aren't counted.
func get_displacement_remaining_px() -> float:
	if not is_displaced():
		return 0.0
	var done := _displacement_progress(_displace_elapsed / _displace_duration)
	return _displace_offset.length() * (1.0 - done)


## Dash at `velocity` (average) for `duration` seconds. Ghosted by default:
## passes through other units, low obstacles and pits; walls and ledges
## still block it, and it slides along them (move_and_slide). `curve` shapes
## the speed; null = constant speed. Await `displacement_finished` to know
## when it's over. Not while a leap runs (LOOT L6), nor while the unit is
## rooted or stunned (is_dash_blocked(); roots are roots, 2026-10-04): ignored.
func dash(velocity: Vector2, duration: float, ghosted: bool = true, curve: Curve = null) -> void:
	if _leaping or is_dash_blocked():
		return
	_end_ghost()
	_start_displacement(velocity, duration, curve)
	if ghosted:
		_ghost_saved_mask = body.collision_mask
		body.collision_mask = body.collision_mask & GHOST_KEEP_MASK  # walls and ledges only (3D pivot P9; approved 2026-10-01)


func _end_ghost() -> void:
	if _ghost_saved_mask >= 0:
		body.collision_mask = _ghost_saved_mask
		_ghost_saved_mask = -1


func is_displaced() -> bool:
	return _displace_time > 0.0


## True while the unit is knocked up (its status tag &"airborne"), or while
## its own leap runs (LOOT L6; no status: a leap isn't crowd control).
func is_airborne() -> bool:
	return _leaping or (_status != null and _status.has_tag(&"airborne"))


# --- Leaps (LOOT L6; 3D.md, Leaps) ------------------------------------------------

## The leap: a straight move at a steady speed over `duration` to where a leap
## aimed at `to_px` lands (get_leap_landing(): the nearest walkable floor of
## the unit's room), colliding with nothing on the way (units, fences,
## ledges, pits and walls: the body's mask is 0 until it lands), with
## is_airborne() true while it runs. No status, no i-frames: the ability that
## leaps roots its caster. While it runs, no other displacement or dash starts
## (displace() and dash() are dropped). A leap to where the unit stands is a
## hop in place. Returns the landing point; is_leaping() turns false and
## displacement_finished is emitted when it lands. Refused while the unit is
## rooted or stunned (is_dash_blocked(); roots are roots, 2026-10-04): no
## leap starts, and it returns where the unit stands.
func leap(to_px: Vector2, duration: float) -> Vector2:
	if is_dash_blocked():
		return body.global_position
	var from := body.global_position
	var landing := get_leap_landing(to_px)
	var time := maxf(duration, 0.0001)
	_end_leap_mask()
	_end_ghost()
	_start_displacement((landing - from) / time, time, null)
	_leaping = true
	_leap_from = from
	_leap_to = landing
	_leap_saved_mask = body.collision_mask
	body.collision_mask = 0
	return landing


## Where a leap aimed at `to_px` lands: `to_px` itself when the body fits
## there (no wall, low obstacle, ledge or pit under it) on the floor of the
## unit's room; otherwise the nearest walkable floor of that room (the closest
## point of its navigation region, which the walls, fences, ledges, pits and
## the room's edge carve), freed of anything the body still overlaps
## (WorldQuery.resolve_valid_position()). A unit outside a Room (or before
## its navigation is ready) gets resolve_valid_position() alone, back toward
## the unit.
func get_leap_landing(to_px: Vector2) -> Vector2:
	var radius := _body_radius()
	var room := _find_room()
	var map := body.get_world_2d().navigation_map if body.is_inside_tree() else RID()
	if room == null or room.nav_region == null or not map.is_valid() or NavigationServer2D.map_get_iteration_id(map) == 0:
		return WorldQuery.resolve_valid_position(to_px, body.global_position, radius, LEAP_BLOCKING_MASK)
	var on_floor := NavigationServer2D.region_get_closest_point(room.nav_region.get_rid(), to_px)
	# The navigation keeps nav_agent_radius from everything it carves, so a
	# spot that close to it is still on the room's floor.
	if to_px.distance_to(on_floor) <= room.nav_agent_radius + 0.5 and WorldQuery.is_point_free(to_px, radius, LEAP_BLOCKING_MASK):
		return to_px
	return WorldQuery.resolve_valid_position(on_floor, on_floor, radius, LEAP_BLOCKING_MASK)


## True while the unit's own leap runs.
func is_leaping() -> bool:
	return _leaping


## The running leap's start and landing points, its length and its seconds
## left (for the view's arc; Vector2.ZERO / 0 when no leap runs).
func get_leap_from() -> Vector2:
	return _leap_from if _leaping else Vector2.ZERO


func get_leap_to() -> Vector2:
	return _leap_to if _leaping else Vector2.ZERO


func get_leap_duration() -> float:
	return _displace_duration if _leaping else 0.0


func get_leap_time_left() -> float:
	return _displace_time if _leaping else 0.0


## The leap is over: the body's mask comes back, and if something now stands
## where it landed (a door shut), it's moved the shortest way out.
func _end_leap() -> void:
	_end_leap_mask()
	_leaping = false
	var here := body.global_position
	var landed := WorldQuery.resolve_valid_position(here, _leap_to, _body_radius(), LEAP_BLOCKING_MASK)
	if landed != here:
		body.global_position = landed


func _end_leap_mask() -> void:
	if _leap_saved_mask >= 0:
		body.collision_mask = _leap_saved_mask
		_leap_saved_mask = -1


# --- Blinks (ABILITIES AB15, Blinks; 3D.md, 1e) -------------------------------------

## The blink: the unit is at once where a blink aimed at `to_px` lands
## (get_blink_landing()): no travel, no status, no i-frames, no hits. It ends
## the unit's own running displacement first (a dash, a knockback, a swing
## step; displacement_finished is emitted, so a dash ends as usual). A move
## order re-paths from the new spot; held input keeps walking. The body's
## physics interpolation is reset and `blinked` is emitted for the view.
## Refused (false, nothing moves) during a leap, a knock-up (is_airborne())
## and while dash-blocked (a root or a stun; League's roots stop Flash).
func blink(to_px: Vector2, through_walls: bool = true) -> bool:
	if is_airborne() or is_blink_blocked():
		return false
	var from := body.global_position
	var landing := get_blink_landing(to_px, through_walls)
	if is_displaced():
		_displace_time = 0.0
		_displace_dash_cancelable = false
		body.velocity = Vector2.ZERO
		_end_ghost()
		displacement_finished.emit()
	body.global_position = landing
	body.reset_physics_interpolation()
	if _has_order:
		_compute_path(_destination)
	blinked.emit(from, landing)
	return true


## True while a status holds the unit where it stands: a root or a stun (the
## statuses that block dashing; Unit.is_dash_blocked()). Roots are roots
## (Ryan, 2026-10-04): the unit's own dashes, leaps and blinks are refused
## then, as walking is; forced movement (a knockback, a pull) still moves it,
## and one already running finishes.
func is_dash_blocked() -> bool:
	return _status != null and (_status.has_tag(&"stun") or _status.blocks_dash())


## True while a blink would be refused for a status (is_dash_blocked()). A
## leap and a knock-up refuse it too (is_airborne()).
func is_blink_blocked() -> bool:
	return is_dash_blocked()


## Where a blink aimed at `to_px` would land (for indicators and AI plans).
## Over walls (`through_walls`): the leap's rule, get_leap_landing(): the
## aimed spot when the body fits there on the room's floor, else the nearest
## walkable floor of the room. Stopping at walls: the aim is first cut at the
## first wall (layer 1) on the straight line from the unit (a small core
## swept, as AB13's VECTOR start is, so a unit already touching a wall can
## still blink away from it); fences, ledges and pits are still crossed. Then
## the same rule, and never out of sight of where it started (else back
## toward the unit).
func get_blink_landing(to_px: Vector2, through_walls: bool = true) -> Vector2:
	if through_walls:
		return get_leap_landing(to_px)
	var from := body.global_position
	var point := to_px
	var wall := WorldQuery.shape_sweep(from, to_px, BLINK_WALL_CORE_PX)
	if not wall.is_empty():
		point = wall.position
	var landing := get_leap_landing(point)
	if not WorldQuery.has_line_of_sight(from, landing):
		landing = WorldQuery.resolve_valid_position(point, from, _body_radius(), LEAP_BLOCKING_MASK)
	return landing


## The Room the unit is in (its nearest Room ancestor), or null.
func _find_room() -> Room:
	var node := body.get_parent()
	while node != null:
		if node is Room:
			return node
		node = node.get_parent()
	return null


## An airborne displacement ended: inside a low obstacle or a ledge's
## footprint, the unit lands on the nearest free floor back toward where the
## displacement started (WorldQuery.resolve_valid_position()). No fall damage
## (Ryan, 2026-10-01). Pits wait for the pit step.
func _land() -> void:
	var here := body.global_position
	var landed := WorldQuery.resolve_valid_position(here, _displace_from, _body_radius(), LANDING_BLOCKING_MASK)
	if landed != here:
		body.global_position = landed


## The body's collision circle (px), else the pathing radius.
func _body_radius() -> float:
	for child in body.get_children():
		var shape := child as CollisionShape2D
		if shape and shape.shape is CircleShape2D:
			return (shape.shape as CircleShape2D).radius
	return radius_px


## True while the running displacement was started with dash_cancelable.
func is_displacement_dash_cancelable() -> bool:
	return is_displaced() and _displace_dash_cancelable


## Changes every time a displacement (dash, knockback, step) starts. A caller
## keeps it to tell later whether the running displacement is still its own.
func get_displacement_serial() -> int:
	return _displace_serial


## Ends the running displacement where the unit is now. Only for a caller
## ending its own displacement (check get_displacement_serial() first): it
## doesn't emit displacement_finished, so it must not be used on a dash (or a
## leap; one stopped anyway lands where it is, LOOT L6).
func stop_displacement() -> void:
	if not is_displaced():
		return
	_displace_time = 0.0
	_displace_dash_cancelable = false
	body.velocity = Vector2.ZERO
	_end_ghost()
	if _leaping:
		_leap_to = body.global_position
		_end_leap()


func _start_displacement(velocity: Vector2, duration: float, curve: Curve) -> void:
	_displace_serial += 1
	_displace_from = body.global_position if body else Vector2.ZERO
	_displace_dash_cancelable = false
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


## Speed modifiers become statuses from now on (COMBAT C9): each one is a
## status_slow / status_haste copy with this id. Ones added before this move
## over with their time left.
func set_status_component(status: StatusComponent) -> void:
	_status = status
	for id: StringName in _modifiers.keys():
		var mod: Dictionary = _modifiers[id]
		remove_speed_modifier(id)
		add_speed_modifier(id, mod.flat, mod.percent, mod.time_left)


## percent: 0.2 = +20% MS, -0.3 = 30% slow. duration < 0 = until removed.
## Re-adding an id replaces it. With a StatusComponent (C9) it is a status:
## a copy of status_slow (any negative part; tagged cc, so tenacity shortens
## it) or status_haste, with this id, these move_speed modifiers and this
## duration (source &"status_<id>"). Otherwise, with a StatsComponent the
## modifier lives there (source_id = id) and only the timer is kept here.
func add_speed_modifier(id: StringName, flat: float = 0.0, percent: float = 0.0, duration: float = -1.0) -> void:
	if _status != null:
		_status.apply_status(_make_speed_status(id, flat, percent, duration))
		return
	_modifiers[id] = {"flat": flat, "percent": percent, "time_left": duration}
	if _stats != null:
		_stats.remove_modifiers_from(id)
		_add_speed_stat_modifiers(id, flat, percent)


func remove_speed_modifier(id: StringName) -> void:
	if _status != null:
		_status.remove_status(id)
	_modifiers.erase(id)
	if _stats != null:
		_stats.remove_modifiers_from(id)


## The status add_speed_modifier() applies (see there).
func _make_speed_status(id: StringName, flat: float, percent: float, duration: float) -> StatusEffect:
	var template: StatusEffect = STATUS_SLOW if (percent < 0.0 or flat < 0.0) else STATUS_HASTE
	var effect: StatusEffect = template.duplicate()
	effect.id = id
	effect.display_name = String(id)
	effect.duration = duration if duration >= 0.0 else -1.0
	effect.stack_rule = StatusEffect.StackRule.REFRESH   # the same id replaces, as before C9
	var mods: Array[StatModifier] = []
	if flat != 0.0:
		mods.append(StatModifier.create(&"move_speed", StatModifier.Type.FLAT, flat, &""))
	if percent != 0.0:
		mods.append(StatModifier.create(&"move_speed", StatModifier.Type.PERCENT_ADD, percent, &""))
	effect.modifiers = mods
	return effect


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
		# Knocked up (3D.md, Airborne): over pits, fences and cliffs; walls still stop it.
		var airborne := is_airborne()
		var mask := body.collision_mask
		if airborne:
			body.collision_mask = mask & ~AIRBORNE_IGNORED_MASK
		body.move_and_slide()
		body.collision_mask = mask
		if _displace_time <= 0.0:
			body.velocity = Vector2.ZERO
			_end_ghost()
			if _leaping:
				_end_leap()   # LOOT L6: its own landing (picked when it started)
			elif airborne:
				_land()
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
