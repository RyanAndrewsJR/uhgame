extends Camera2D
## LoL-style camera.
##   Y          - toggle locked / unlocked
##   Hold Space - center on your character while held
##   Unlocked:  move the mouse to a screen edge, or use the arrow keys, to pan
## Also handles screen shake (GameFeel.shake()).
## Locked: leans toward the mouse (aim lead, MOVEMENT.md F4). No lean while
## the cursor is inside a dead zone; the lean eases in and out at its own
## rate, and is full only while the player aims or casts.

@export var target: Node2D
@export var locked: bool = true
@export var edge_pan_speed: float = 420.0
## Distance from the window edge (in screen pixels of the 640x360 view)
## that starts edge panning.
@export var edge_margin: float = 6.0
@export var shake_decay: float = 30.0
## How far (px) the locked camera leans sideways toward the mouse at most.
## 0 = off.
@export var aim_lead: float = 80.0

@export_group("Aim lead")
## No lean while the cursor is inside this share of the half-screen,
## measured as an oval (x and y each divided by their own half-size).
@export var aim_lead_dead_zone: float = 0.35
## Share of the half-screen where the lean reaches full.
@export var aim_lead_full_at: float = 0.9
## Lean between the dead zone edge (x = 0) and aim_lead_full_at (x = 1).
## null = linear.
@export var aim_lead_curve: Curve = preload("res://data/curves/curve_camera_lead.tres")
## Vertical lean = aim_lead x this (the screen is 16:9).
@export var aim_lead_y_scale: float = 0.6
## How fast the lean eases toward its target, per second
## (frame-rate independent). The player follow keeps its own smoothing.
@export var aim_lead_smoothing: float = 4.0
## Lean scale while the player isn't aiming or casting.
@export var aim_lead_idle_scale: float = 0.5
## Keep the full lean this many seconds after the last aim or cast, so it
## doesn't swing back and forth between casts.
@export var aim_lead_hold_time: float = 0.75
## Extra lean (px) in the walking direction. 0 = off. Try 12-16.
@export var move_lead_px: float = 0.0

@export_group("Debug")
## Draws the dead zone oval, the target lean and the current lean.
@export var debug_draw: bool = false

## Bounds the camera may show, set by Main from the room size.
var bounds: Rect2 = Rect2()

var _shake_amount: float = 0.0
var _lead: Vector2 = Vector2.ZERO          # current lean (eased)
var _lead_target: Vector2 = Vector2.ZERO   # lean it's easing toward
var _aim_hold_left: float = 0.0            # full-lean time left after aiming


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 10.0


func shake(amount: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)


func snap_to_target() -> void:
	if target:
		_lead = Vector2.ZERO
		_lead_target = Vector2.ZERO
		_aim_hold_left = 0.0
		global_position = _clamp_to_bounds(target.global_position)
		# Physics interpolation is on (MOVEMENT.md F1): without these resets the
		# camera slides in from its old spot. The reset must come before
		# reset_smoothing(), and once more after the first physics tick.
		reset_physics_interpolation()
		reset_smoothing()
		_reset_after_physics_tick.call_deferred()


func _reset_after_physics_tick() -> void:
	await get_tree().physics_frame
	if target:
		global_position = _clamp_to_bounds(target.global_position)
	reset_physics_interpolation()
	reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle_lock"):
		locked = not locked


func _process(delta: float) -> void:
	# Real (unscaled) delta so hit-stop doesn't freeze camera panning.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)

	var centering := Input.is_action_pressed("camera_center")
	if target and (locked or centering):
		# Holding camera_center centers exactly; plain locked mode leans.
		if locked and not centering:
			_update_lead(real_delta)
		else:
			_lead = Vector2.ZERO
			_lead_target = Vector2.ZERO
		global_position = _clamp_to_bounds(target.global_position + _lead)
	else:
		var pan := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
		pan += _edge_pan_direction()
		if pan != Vector2.ZERO:
			global_position = _clamp_to_bounds(global_position + pan.limit_length(1.0) * edge_pan_speed * real_delta)

	if _shake_amount > 0.0:
		_shake_amount = move_toward(_shake_amount, 0.0, shake_decay * real_delta)
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amount
	else:
		offset = Vector2.ZERO
	if debug_draw:
		queue_redraw()


## Full lean toward the mouse, before the context scale and easing. Zero
## inside the dead zone oval, then aim_lead_curve up to aim_lead_full_at.
## Measured in screen space, so moving the camera doesn't feed back into it.
func get_aim_lead() -> Vector2:
	if aim_lead <= 0.0:
		return Vector2.ZERO
	var vp := get_viewport()
	var rect := vp.get_visible_rect()
	var n := (vp.get_mouse_position() - rect.get_center()) / (rect.size * 0.5)
	var r := n.length()
	if r <= aim_lead_dead_zone:
		return Vector2.ZERO
	var t := clampf((r - aim_lead_dead_zone) / maxf(aim_lead_full_at - aim_lead_dead_zone, 0.001), 0.0, 1.0)
	var amount := aim_lead_curve.sample(t) if aim_lead_curve else t
	var dir := n / r
	return Vector2(dir.x * aim_lead, dir.y * aim_lead * aim_lead_y_scale) * amount


## The lean the camera is using right now (after easing).
func get_current_lead() -> Vector2:
	return _lead


func _update_lead(delta: float) -> void:
	if _is_target_aiming():
		_aim_hold_left = aim_lead_hold_time
	else:
		_aim_hold_left = maxf(_aim_hold_left - delta, 0.0)
	var context_scale := 1.0 if _aim_hold_left > 0.0 else aim_lead_idle_scale
	_lead_target = get_aim_lead() * context_scale + _get_move_lead()
	_lead = _lead.lerp(_lead_target, 1.0 - exp(-aim_lead_smoothing * delta))


## Full lean while the player aims or casts an ability (or winds up a basic
## attack). Read through Player's public state; other targets never aim.
func _is_target_aiming() -> bool:
	var player := target as Player
	if player == null:
		return false
	return player.aiming_slot != &"" \
		or player.is_in_state(Player.State.CASTING) \
		or player.is_in_state(Player.State.ATTACK)


func _get_move_lead() -> Vector2:
	var unit := target as Unit
	if move_lead_px <= 0.0 or unit == null:
		return Vector2.ZERO
	var dir := unit.movement.get_move_direction()
	return Vector2(dir.x * move_lead_px, dir.y * move_lead_px * aim_lead_y_scale)


func _draw() -> void:
	if not debug_draw:
		return
	# The camera sits at the view center (before smoothing and offset), so
	# draw relative to the actual screen center.
	var c := get_screen_center_position() - global_position
	var half := get_viewport_rect().size * 0.5 / zoom
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		pts.append(c + Vector2(cos(a) * half.x, sin(a) * half.y) * aim_lead_dead_zone)
	draw_polyline(pts, Color(1, 1, 1, 0.35), 1.0)
	var player_pos := target.global_position - global_position if target else c
	draw_line(player_pos, player_pos + _lead_target, Color(1, 0.8, 0.2, 0.9), 1.0)
	draw_circle(player_pos + _lead_target, 2.5, Color(1, 0.8, 0.2, 0.9))
	draw_circle(player_pos + _lead, 2.0, Color(0.3, 1, 0.6, 0.9))


func _edge_pan_direction() -> Vector2:
	var vp := get_viewport()
	if not vp.get_window().has_focus():
		return Vector2.ZERO
	var rect := vp.get_visible_rect()
	var m := vp.get_mouse_position()
	if not rect.grow(1.0).has_point(m):
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if m.x <= rect.position.x + edge_margin:
		dir.x -= 1
	elif m.x >= rect.end.x - edge_margin:
		dir.x += 1
	if m.y <= rect.position.y + edge_margin:
		dir.y -= 1
	elif m.y >= rect.end.y - edge_margin:
		dir.y += 1
	return dir


func _clamp_to_bounds(p: Vector2) -> Vector2:
	if bounds.size == Vector2.ZERO:
		return p
	var half := get_viewport_rect().size * 0.5 / zoom
	var min_p := bounds.position + half
	var max_p := bounds.end - half
	# If the room is smaller than the screen on an axis, center on that axis.
	var x := bounds.get_center().x if min_p.x > max_p.x else clampf(p.x, min_p.x, max_p.x)
	var y := bounds.get_center().y if min_p.y > max_p.y else clampf(p.y, min_p.y, max_p.y)
	return Vector2(x, y)
