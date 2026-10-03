class_name GameCamera3D
extends Camera3D
## The game camera in 3D (docs/3D.md, GameCamera3D; MOVEMENT.md, Architecture
## 4): a fixed-angle camera with the CameraLook (projection, field of view,
## pitch, visible width) that follows its target, the player's view:
##   Y          - toggle locked / unlocked
##   Hold C     - center on your character while held (camera_center)
##   Unlocked:  move the mouse to a screen edge, or use the arrow keys, to pan
## Locked, it leans toward the mouse (the aim lean: dead zone, curve, easing,
## full while the player aims, casts or swings). Also GameFeel.shake().
## Since the cleanup's C1 (Ryan, 2026-10-03) it computes all of this itself,
## tuned on its CameraLook; the 2D GameCamera only runs in the 2D game (the
## flag off). The lean, pan and shake are in screen px of the 640x360 canvas,
## so the same share of the screen moves this camera as moved the 2D one.
## Bounds: the focus (where the camera looks, after the lean or a pan) never
## leaves the room's floor; near an edge the void past the walls shows (Ryan,
## P4).
## It carries the AudioListener2D: positional sounds are heard from the
## focus (in px), and Audio scales their reach and panning to this view.
## Placed by code every frame, so physics interpolation is off (3D.md, Engine
## facts); it follows the target's interpolated transform.

## Before WorldView's fade (20), which looks from this camera.
const PROCESS_PRIORITY := 10
## The debug drawing's canvas layer (CameraLook.debug_draw), over the HUD.
const DEBUG_LAYER := 90

@export var look: CameraLook = preload("res://data/camera_looks/camera_look_default.tres")

## What the camera follows: a Node3D at the player's feet (the player's
## UnitView). Freed (the player died): the camera holds.
var target: Node3D
## The player whose aiming makes the lean full (its public state). null: no
## lean at all (a camera with no player only follows).
var player: Player
## The room's floor in meters (x and z as a Rect2); the focus stays inside.
## Empty: no bounds.
var bounds_m: Rect2 = Rect2()
var listener: AudioListener2D
## Locked follows the target (and leans); unlocked pans. Y toggles it.
var locked: bool = true
## The shake's offset this frame (screen px), from GameFeel.shake().
var shake_offset_px: Vector2 = Vector2.ZERO

var _goal: Vector3 = Vector3.ZERO    # where the camera is heading (the target plus the lean, or the panned spot)
var _focus: Vector3 = Vector3.ZERO   # where it looks now: _goal, smoothed
var _shake_amount: float = 0.0
var _lead: Vector2 = Vector2.ZERO          # current lean (eased), screen px
var _lead_target: Vector2 = Vector2.ZERO   # lean it's easing toward
var _aim_hold_left: float = 0.0            # full-lean time left after aiming
var _debug_canvas: Node2D


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


## GameFeel.shake(): the strongest running shake wins; it decays by the
## look's shake_decay_px a second (real time).
func shake(amount: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)


## Jumps to the target with no lean and no smoothing (the scene's start, a
## teleport). Its view snaps on its own (WorldView).
func snap_to_target() -> void:
	_lead = Vector2.ZERO
	_lead_target = Vector2.ZERO
	_aim_hold_left = 0.0
	if _target_valid():
		_goal = clamp_focus(_target_feet(), bounds_m)
	_focus = _goal
	_place()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"camera_toggle_lock"):
		locked = not locked


func _process(delta: float) -> void:
	# Real (unscaled) time for the lean, panning and shake, so hitstop doesn't
	# freeze them. The follow smoothing uses game time: the 2D camera's
	# smoothing ran on physics ticks, which hitstop all but stops.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	var centering := Input.is_action_pressed(&"camera_center")
	if _target_valid() and (locked or centering):
		# Holding camera_center centers exactly; plain locked mode leans. A
		# lean of `lead` screen px puts the target `lead` px off the center:
		# the focus is the floor point that the target's spot (center - lead)
		# maps to, from the other side. Not target + screen_to_floor(lead): up
		# and down the screen aren't symmetric in perspective (3 px off at
		# 48 px).
		if locked and not centering and player != null:
			_update_lead(real_delta)
		else:
			_lead = Vector2.ZERO
			_lead_target = Vector2.ZERO
		_goal = clamp_focus(_target_feet() - screen_to_floor(-_lead), bounds_m)
	elif not locked and not centering:
		var pan := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
		pan += _edge_pan_direction()
		if pan != Vector2.ZERO:
			_goal = clamp_focus(_goal + screen_to_floor(pan.limit_length(1.0) * look.edge_pan_speed_px * real_delta), bounds_m)
	_update_shake(real_delta)
	var rate := _follow_rate()
	_focus = _goal if is_inf(rate) else _focus.lerp(_goal, 1.0 - exp(-rate * delta))
	_place()
	_update_debug_draw()


## Full lean toward the mouse (screen px), before the context scale and
## easing. Zero inside the dead zone oval, then the look's aim_lead_curve up
## to aim_lead_full_at. Measured in screen space, so moving the camera doesn't
## feed back into it.
func get_aim_lead() -> Vector2:
	if look.aim_lead_px <= 0.0:
		return Vector2.ZERO
	var vp := get_viewport()
	var rect := vp.get_visible_rect()
	var n := (vp.get_mouse_position() - rect.get_center()) / (rect.size * 0.5)
	var r := n.length()
	if r <= look.aim_lead_dead_zone:
		return Vector2.ZERO
	var t := clampf((r - look.aim_lead_dead_zone) / maxf(look.aim_lead_full_at - look.aim_lead_dead_zone, 0.001), 0.0, 1.0)
	var amount := look.aim_lead_curve.sample(t) if look.aim_lead_curve else t
	var dir := n / r
	return Vector2(dir.x * look.aim_lead_px, dir.y * look.aim_lead_px * look.aim_lead_y_scale) * amount


## The lean the camera is using right now (screen px, after easing).
func get_current_lead() -> Vector2:
	return _lead


func _update_lead(delta: float) -> void:
	if _is_player_aiming():
		_aim_hold_left = look.aim_lead_hold_time
	else:
		_aim_hold_left = maxf(_aim_hold_left - delta, 0.0)
	var context_scale := 1.0 if _aim_hold_left > 0.0 else look.aim_lead_idle_scale
	_lead_target = get_aim_lead() * context_scale + _get_move_lead()
	_lead = _lead.lerp(_lead_target, 1.0 - exp(-look.aim_lead_smoothing * delta))


## Full lean while the player aims or casts an ability (or winds up a basic
## attack), read through Player's public state.
func _is_player_aiming() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return player.aiming_slot != &"" \
		or player.is_in_state(Player.State.CASTING) \
		or player.is_in_state(Player.State.ATTACK)


func _get_move_lead() -> Vector2:
	if look.move_lead_px <= 0.0 or player == null or not is_instance_valid(player):
		return Vector2.ZERO
	var dir := player.movement.get_move_direction()
	return Vector2(dir.x * look.move_lead_px, dir.y * look.move_lead_px * look.aim_lead_y_scale)


func _update_shake(real_delta: float) -> void:
	if _shake_amount > 0.0:
		_shake_amount = move_toward(_shake_amount, 0.0, look.shake_decay_px * real_delta)
		shake_offset_px = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amount
	else:
		shake_offset_px = Vector2.ZERO


## How far the floor under a point `offset_px` away from the screen's center
## (in the 640x360 canvas px, the space of the lean, pan and shake) lies from
## the floor under the center, at the focus height. The same share of the
## screen as in 2D: 80 px sideways = 80/640 of 28 m = 3.5 m; up the screen,
## more floor per px (perspective at 50°).
func screen_to_floor(offset_px: Vector2) -> Vector3:
	if offset_px == Vector2.ZERO:
		return Vector3.ZERO
	# Without the shake: v_offset moves the camera along its tilted up axis,
	# off its usual height (0.3% off at a 4 px shake).
	var shake_now := Vector2(h_offset, v_offset)
	h_offset = 0.0
	v_offset = 0.0
	var center := get_viewport().get_visible_rect().get_center()
	var delta := _floor_under(center + offset_px) - _floor_under(center)
	h_offset = shake_now.x
	v_offset = shake_now.y
	return delta


## As screen_to_floor(), but the point `offset_px` from the center is taken on
## the plane `drop_m` below the focus (P9: floor lower than the focus is seen
## farther; FloorOverlay's window covers it). Relative to the floor under the
## center at the focus height. Shake aside.
func screen_to_floor_below(offset_px: Vector2, drop_m: float) -> Vector3:
	var shake_now := Vector2(h_offset, v_offset)
	h_offset = 0.0
	v_offset = 0.0
	var center := get_viewport().get_visible_rect().get_center()
	var origin := project_ray_origin(center + offset_px)
	var normal := project_ray_normal(center + offset_px)
	var plane_y := _focus.y - drop_m
	var p := Vector3(origin.x, plane_y, origin.z) if absf(normal.y) < 0.0001 else origin + normal * ((plane_y - origin.y) / normal.y)
	var delta := p - _floor_under(center)
	h_offset = shake_now.x
	v_offset = shake_now.y
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
	if look.follow_smoothing_speed <= 0.0:
		return INF
	return follow_rate_per_second(look.follow_smoothing_speed, Engine.physics_ticks_per_second)


func _place() -> void:
	var size := get_viewport().get_visible_rect().size
	look.apply(self, _focus, size.x / size.y)
	# The shake's offset is in canvas px; the same share of the screen here.
	# h_offset and v_offset shift the camera in its own plane.
	var k := meters_per_screen_px(look, size.x)
	h_offset = shake_offset_px.x * k
	v_offset = -shake_offset_px.y * k
	if listener:
		listener.global_position = Units.to_sim(_focus)
	Audio.distance_scale = view_distance_scale(look, size.x)


func _target_valid() -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree()


func _target_feet() -> Vector3:
	return target.get_global_transform_interpolated().origin


## The mouse at a window edge (within the look's edge_margin_px canvas px)
## pans that way, only while the window has focus.
func _edge_pan_direction() -> Vector2:
	var vp := get_viewport()
	if not vp.get_window().has_focus():
		return Vector2.ZERO
	var rect := vp.get_visible_rect()
	var m := vp.get_mouse_position()
	if not rect.grow(1.0).has_point(m):
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if m.x <= rect.position.x + look.edge_margin_px:
		dir.x -= 1
	elif m.x >= rect.end.x - look.edge_margin_px:
		dir.x += 1
	if m.y <= rect.position.y + look.edge_margin_px:
		dir.y -= 1
	elif m.y >= rect.end.y - look.edge_margin_px:
		dir.y += 1
	return dir


# --- Debug (CameraLook.debug_draw) ----------------------------------------------

func _update_debug_draw() -> void:
	if not look.debug_draw:
		if _debug_canvas:
			_debug_canvas.get_parent().queue_free()
			_debug_canvas = null
		return
	if _debug_canvas == null:
		var layer := CanvasLayer.new()
		layer.name = "CameraDebug"
		layer.layer = DEBUG_LAYER
		add_child(layer)
		_debug_canvas = Node2D.new()
		_debug_canvas.draw.connect(_draw_debug)
		layer.add_child(_debug_canvas)
	_debug_canvas.queue_redraw()


## On the screen: the dead zone oval around its center (white), and from the
## player's feet the lean it's easing toward (yellow) and the one it uses
## (green). The 2D camera's debug drawing, in screen space.
func _draw_debug() -> void:
	var rect := get_viewport().get_visible_rect()
	var c := rect.get_center()
	var half := rect.size * 0.5
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		pts.append(c + Vector2(cos(a) * half.x, sin(a) * half.y) * look.aim_lead_dead_zone)
	_debug_canvas.draw_polyline(pts, Color(1, 1, 1, 0.35), 1.0)
	var feet := unproject_position(_target_feet()) if _target_valid() else c
	_debug_canvas.draw_line(feet, feet + _lead_target, Color(1, 0.8, 0.2, 0.9), 1.0)
	_debug_canvas.draw_circle(feet + _lead_target, 2.5, Color(1, 0.8, 0.2, 0.9))
	_debug_canvas.draw_circle(feet + _lead, 2.0, Color(0.3, 1, 0.6, 0.9))
