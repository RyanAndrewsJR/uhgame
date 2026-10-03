class_name GameCamera3D
extends Camera3D
## The game camera in 3D (docs/3D.md, GameCamera3D; MOVEMENT.md, Architecture
## 4): a fixed-angle camera with the CameraLook (projection, field of view,
## pitch, visible width) that follows its target, the player's view, with
## GameCamera's behaviors: Y locks and unlocks, hold C to center, edge and
## arrow pan while unlocked, the aim lean, room bounds, shake.
## Until the 2D camera goes (P-M, asked separately), GameCamera stays the one
## place those are tuned and computed. This camera reads its lock, its lean
## and its shake offset (both in screen px, so the same share of the screen
## moves this camera), and uses its pan speed, edge margin and follow
## smoothing.
## Bounds: the focus (where the camera looks, after the lean or a pan) never
## leaves the room's floor; near an edge the void past the walls shows (Ryan,
## P4).
## It carries the AudioListener2D: positional sounds are heard from the
## focus (in px), and Audio scales their reach and panning to this view.
## Placed by code every frame, so physics interpolation is off (3D.md, Engine
## facts); it follows the target's interpolated transform.

## After GameCamera (0), so this frame's lean and shake are read; before
## WorldView's fade (20), which looks from this camera.
const PROCESS_PRIORITY := 10

@export var look: CameraLook = preload("res://data/camera_looks/camera_look_default.tres")

## What the camera follows: a Node3D at the player's feet (P3's stand-in
## capsule until P6's UnitView). Freed (the player died): the camera holds.
var target: Node3D
## The 2D camera whose lock, lean, shake and pan settings this one uses.
## null: always locked, no lean, no shake.
var source: GameCamera
## The room's floor in meters (x and z as a Rect2); the focus stays inside.
## Empty: no bounds.
var bounds_m: Rect2 = Rect2()
var listener: AudioListener2D

var _goal: Vector3 = Vector3.ZERO    # where the camera is heading (the target plus the lean, or the panned spot)
var _focus: Vector3 = Vector3.ZERO   # where it looks now: _goal, smoothed


func _init() -> void:
	name = "GameCamera3D"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_priority = PROCESS_PRIORITY
	near = 0.5
	far = 200.0


func _ready() -> void:
	listener = AudioListener2D.new()
	listener.name = "Listener"
	add_child(listener)
	listener.make_current()


func _exit_tree() -> void:
	Audio.distance_scale = 1.0


## Where the camera looks now (m): the floor point at the screen's center,
## shake aside.
func get_focus() -> Vector3:
	return _focus


## Jumps to the target with no lean and no smoothing (the scene's start, a
## teleport). Its view snaps on its own (WorldView).
func snap_to_target() -> void:
	if _target_valid():
		_goal = clamp_focus(_target_feet(), bounds_m)
	_focus = _goal
	_place()


func _process(delta: float) -> void:
	# Real (unscaled) time for panning, like GameCamera, so hitstop doesn't
	# freeze it. The follow smoothing uses game time: GameCamera's smoothing
	# runs on physics ticks, which hitstop all but stops.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	var locked := source.locked if source else true
	var centering := Input.is_action_pressed(&"camera_center")
	if _target_valid() and (locked or centering):
		# Holding camera_center centers exactly; plain locked mode leans. As in
		# 2D, a lean of `lead` screen px puts the target `lead` px off the
		# center: the focus is the floor point that the target's spot
		# (center - lead) maps to, from the other side. Not target +
		# screen_to_floor(lead): up and down the screen aren't symmetric in
		# perspective (3 px off at 48 px).
		var lead := source.get_current_lead() if source and locked and not centering else Vector2.ZERO
		_goal = clamp_focus(_target_feet() - screen_to_floor(-lead), bounds_m)
	elif not locked and not centering:
		var pan := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
		pan += _edge_pan_direction()
		if pan != Vector2.ZERO and source:
			_goal = clamp_focus(_goal + screen_to_floor(pan.limit_length(1.0) * source.edge_pan_speed * real_delta), bounds_m)
	var rate := _follow_rate()
	_focus = _goal if is_inf(rate) else _focus.lerp(_goal, 1.0 - exp(-rate * delta))
	_place()


## How far the floor under a point `offset_px` away from the screen's center
## (in the 640x360 canvas px, the space of GameCamera's lean, pan and shake)
## lies from the floor under the center, at the focus height. The same share
## of the screen as in 2D: 80 px sideways = 80/640 of 28 m = 3.5 m; up the
## screen, more floor per px (perspective at 50°).
func screen_to_floor(offset_px: Vector2) -> Vector3:
	if offset_px == Vector2.ZERO:
		return Vector3.ZERO
	# Without the shake: v_offset moves the camera along its tilted up axis,
	# off its usual height (0.3% off at a 4 px shake).
	var shake := Vector2(h_offset, v_offset)
	h_offset = 0.0
	v_offset = 0.0
	var center := get_viewport().get_visible_rect().get_center()
	var delta := _floor_under(center + offset_px) - _floor_under(center)
	h_offset = shake.x
	v_offset = shake.y
	return delta


## The floor point (at the focus height) under a canvas point. The camera only
## ever moves sideways at a fixed height above the focus, so the difference of
## two of these doesn't depend on where it is.
func _floor_under(screen_pos: Vector2) -> Vector3:
	var origin := project_ray_origin(screen_pos)
	var normal := project_ray_normal(screen_pos)
	if absf(normal.y) < 0.0001:
		return Vector3(origin.x, _focus.y, origin.z)
	return origin + normal * ((_focus.y - origin.y) / normal.y)


## Meters per canvas px at the focus: the visible width over the canvas's.
static func meters_per_screen_px(p_look: CameraLook, canvas_width: float) -> float:
	return p_look.visible_width_m / canvas_width


## The view's width over the 2D screen's, for Audio.distance_scale: 28 m is
## 896 px, so 1.4 on a 640 px wide canvas.
static func view_distance_scale(p_look: CameraLook, canvas_width: float) -> float:
	return Units.m_to_px(p_look.visible_width_m) / canvas_width


## The focus kept on the room's floor (bounds in meters, x and z).
static func clamp_focus(p: Vector3, p_bounds_m: Rect2) -> Vector3:
	if p_bounds_m.size == Vector2.ZERO:
		return p
	return Vector3(clampf(p.x, p_bounds_m.position.x, p_bounds_m.end.x), p.y,
		clampf(p.z, p_bounds_m.position.y, p_bounds_m.end.y))


## Camera2D's smoothing moves (speed × tick) of the way on each physics tick;
## this is the same pace as a per-second rate for frame-rate independent
## smoothing (speed 10 at 60 ticks: 10.94 per second).
static func follow_rate_per_second(smoothing_speed: float, ticks_per_second: int) -> float:
	var step := clampf(smoothing_speed / float(ticks_per_second), 0.0, 0.999)
	return -log(1.0 - step) * ticks_per_second


func _follow_rate() -> float:
	if source == null or not source.position_smoothing_enabled:
		return INF
	return follow_rate_per_second(source.position_smoothing_speed, Engine.physics_ticks_per_second)


func _place() -> void:
	var size := get_viewport().get_visible_rect().size
	look.apply(self, _focus, size.x / size.y)
	# GameFeel's shake moves GameCamera's offset (canvas px); the same share of
	# the screen here. h_offset and v_offset shift the camera in its own plane.
	var shake := source.offset if source else Vector2.ZERO
	var k := meters_per_screen_px(look, size.x)
	h_offset = shake.x * k
	v_offset = -shake.y * k
	if listener:
		listener.global_position = Units.to_sim(_focus)
	Audio.distance_scale = view_distance_scale(look, size.x)


func _target_valid() -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree()


func _target_feet() -> Vector3:
	return target.get_global_transform_interpolated().origin


## As GameCamera's: the mouse at a window edge (within source.edge_margin
## canvas px) pans that way, only while the window has focus.
func _edge_pan_direction() -> Vector2:
	if source == null:
		return Vector2.ZERO
	var vp := get_viewport()
	if not vp.get_window().has_focus():
		return Vector2.ZERO
	var rect := vp.get_visible_rect()
	var m := vp.get_mouse_position()
	if not rect.grow(1.0).has_point(m):
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if m.x <= rect.position.x + source.edge_margin:
		dir.x -= 1
	elif m.x >= rect.end.x - source.edge_margin:
		dir.x += 1
	if m.y <= rect.position.y + source.edge_margin:
		dir.y -= 1
	elif m.y >= rect.end.y - source.edge_margin:
		dir.y += 1
	return dir
